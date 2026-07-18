#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter n'est pas accessible dans le PATH."
  echo "Installe Flutter, lance 'flutter doctor', puis relance ce script."
  exit 1
fi

echo "[1/4] Vérification de Flutter..."
flutter --version
echo "[2/4] Génération des fichiers Android..."
flutter create --platforms=android --org com.wardrobeos --project-name wardrobeos .
echo "[3/4] Récupération des dépendances..."
flutter pub get
echo "[4/4] Vérification du projet..."
flutter analyze
echo "WardrobeOS est prêt."
