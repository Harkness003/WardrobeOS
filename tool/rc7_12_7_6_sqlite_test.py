#!/usr/bin/env python3
"""SQLite contract tests for the Agenda v14 migration (no Flutter/Dart needed)."""

import sqlite3
import unittest


OUTFITS = """CREATE TABLE IF NOT EXISTS outfits(
 id TEXT PRIMARY KEY, name TEXT NOT NULL, season TEXT,
 favorite INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL,
 updated_at TEXT NOT NULL, times_worn INTEGER NOT NULL DEFAULT 0,
 last_worn TEXT)"""
ITEMS = """CREATE TABLE IF NOT EXISTS outfit_items(
 outfit_id TEXT NOT NULL, garment_id TEXT NOT NULL,
 PRIMARY KEY(outfit_id, garment_id),
 FOREIGN KEY(outfit_id) REFERENCES outfits(id) ON DELETE CASCADE,
 FOREIGN KEY(garment_id) REFERENCES garments(id) ON DELETE CASCADE)"""
PLANS = """CREATE TABLE IF NOT EXISTS planned_outfits(
 id TEXT PRIMARY KEY, planned_date TEXT NOT NULL UNIQUE,
 outfit_id TEXT NOT NULL, origin TEXT, strategy TEXT, status TEXT,
 justification TEXT, weather_summary TEXT, event_id TEXT, event_title TEXT,
 reuse_kind TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
 wear_recorded_at TEXT,
 FOREIGN KEY(outfit_id) REFERENCES outfits(id) ON DELETE CASCADE)"""


def base():
    db = sqlite3.connect(":memory:")
    db.execute("PRAGMA foreign_keys=ON")
    db.execute("CREATE TABLE garments(id TEXT PRIMARY KEY)")
    db.execute("INSERT INTO garments VALUES ('garment-1')")
    return db


def migrate_v14(db):
    for statement in (OUTFITS, ITEMS, PLANS):
        db.execute(statement)
    db.execute("CREATE INDEX IF NOT EXISTS idx_planned_outfits_date "
               "ON planned_outfits(planned_date)")
    db.commit()


def persist(db, outfit_id="agenda-1", date="2026-08-03T00:00:00.000"):
    with db:
        db.execute("INSERT INTO outfits(id,name,created_at,updated_at) VALUES(?,?,?,?)",
                   (outfit_id, "Agenda", date, date))
        db.execute("INSERT INTO outfit_items VALUES(?,?)", (outfit_id, "garment-1"))
        values = (f"plan-{date}", date, outfit_id, date, date)
        changed = db.execute("UPDATE planned_outfits SET id=?,outfit_id=?,created_at=?,updated_at=? "
                             "WHERE planned_date=?",
                             (values[0], outfit_id, date, date, date)).rowcount
        if not changed:
            db.execute("INSERT INTO planned_outfits"
                       "(id,planned_date,outfit_id,created_at,updated_at) VALUES(?,?,?,?,?)", values)


def persist_with_garment(db, garment_id, outfit_id="agenda-invalid"):
    """Mirrors the real transaction while allowing an intentional bad FK."""
    with db:
        db.execute("INSERT INTO outfits(id,name,created_at,updated_at) VALUES(?,?,?,?)",
                   (outfit_id, "Agenda", "x", "x"))
        db.execute("INSERT INTO outfit_items VALUES(?,?)", (outfit_id, garment_id))
        db.execute("INSERT INTO planned_outfits"
                   "(id,planned_date,outfit_id,created_at,updated_at) VALUES(?,?,?,?,?)",
                   (f"plan-{outfit_id}", outfit_id, outfit_id, "x", "x"))


class AgendaSqliteContractTest(unittest.TestCase):
    def test_fresh_database_persist_and_reload(self):
        db = base()
        migrate_v14(db)
        persist(db)
        self.assertEqual(db.execute("SELECT COUNT(*) FROM outfits").fetchone()[0], 1)
        self.assertEqual(db.execute("SELECT COUNT(*) FROM outfit_items").fetchone()[0], 1)
        self.assertEqual(db.execute("SELECT outfit_id FROM planned_outfits").fetchone()[0], "agenda-1")

    def test_historical_database_migrates_non_destructively(self):
        db = base()
        db.execute(OUTFITS)
        db.execute("INSERT INTO outfits(id,name,created_at,updated_at) VALUES('old','Old','x','x')")
        migrate_v14(db)
        persist(db)
        self.assertEqual(db.execute("SELECT COUNT(*) FROM outfits").fetchone()[0], 2)

    def test_same_date_is_updated_without_replace(self):
        db = base()
        migrate_v14(db)
        persist(db, "agenda-1")
        persist(db, "agenda-2")
        self.assertEqual(db.execute("SELECT COUNT(*) FROM planned_outfits").fetchone()[0], 1)
        self.assertEqual(db.execute("SELECT outfit_id FROM planned_outfits").fetchone()[0], "agenda-2")

    def test_planned_outfit_failure_rolls_back_outfit_and_items(self):
        db = base()
        db.execute(OUTFITS)
        db.execute(ITEMS)
        db.commit()
        with self.assertRaises(sqlite3.OperationalError):
            persist(db)  # historical failure: planned_outfits does not exist
        self.assertEqual(db.execute("SELECT COUNT(*) FROM outfits").fetchone()[0], 0)
        self.assertEqual(db.execute("SELECT COUNT(*) FROM outfit_items").fetchone()[0], 0)

    def test_invalid_garment_fk_rolls_back_all_three_tables(self):
        db = base()
        migrate_v14(db)
        before = tuple(db.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
                       for table in ("outfits", "outfit_items", "planned_outfits"))
        with self.assertRaises(sqlite3.IntegrityError):
            persist_with_garment(db, "missing-garment")
        after = tuple(db.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
                      for table in ("outfits", "outfit_items", "planned_outfits"))
        self.assertEqual(after, before)

    def test_legacy_case_sensitive_garment_identity_persists(self):
        db = base()
        migrate_v14(db)
        legacy_id = "legacy-private-id"
        db.execute("INSERT INTO garments VALUES (?)", (legacy_id,))
        db.commit()
        persist_with_garment(db, legacy_id, "agenda-legacy")
        self.assertEqual(db.execute(
            "SELECT garment_id FROM outfit_items WHERE outfit_id='agenda-legacy'"
        ).fetchone()[0], legacy_id)


if __name__ == "__main__":
    unittest.main()
