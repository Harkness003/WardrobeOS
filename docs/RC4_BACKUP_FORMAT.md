# RC4 — contrat de sauvegarde et restauration

WardrobeOS produit un seul format de sauvegarde : une archive ZIP avec un
`manifest.json` de format `WardrobeOS Backup` et de schéma `4`. Aucun ancien
JSON ou ancien schéma ZIP n'est accepté.

## Contenu

Le manifeste contient la version de l'application, la date UTC, la version du
schéma, le nombre de vêtements et de photos, le nombre de lignes par section et
un SHA-256 pour chaque fichier. Les sections persistées sont :

- `garments` (incluant `StyleAnalysis`, `ThermalProfile` et les descripteurs
  `GarmentPhoto`) ;
- `outfits` et `outfitItems` ;
- `wearHistory` ;
- `userMemories`, `userMemoryRevisions`, `personalGoals` et `styleProfiles` ;
- `plannedOutfits` ;
- `wishlist`, réservée afin qu'une restauration vide explicitement cette
  section lorsqu'elle deviendra persistée.

Une section vide reste présente : son absence ne peut ainsi pas être confondue
avec l'ordre de conserver les données locales actuelles. Les images sont dans
`photos/<garment-id>/`; leurs chemins archivés ne sont jamais des chemins
locaux. Chaque descripteur conserve son identifiant, son type, sa date et son
éventuel type sémantique.

## Validation et atomicité

Avant toute écriture en base, l'import contrôle le ZIP, le manifeste, la version,
toutes les sections, les compteurs, les empreintes, les descripteurs photo et
la présence exacte des images référencées. Une image absente ou illisible rend
la sauvegarde entière invalide. Les nouvelles images locales sont supprimées
si leur copie ou la transaction de base échoue.

La base est remplacée dans une transaction unique. L'interface affiche le
fichier, la date et les sections détectées, puis exige une confirmation
explicite. Après succès, les caches Dressing, Tenues et Agenda utilisés par le
shell sont rechargés ; les services Daily relisent leurs sources à la demande.

## Exclusions volontaires en RC4

- la wishlist n'a encore aucune persistance métier ;
- le thème est un réglage de session non persisté ;
- la localisation est gérée par son propre stockage de préférences et reste
  hors du périmètre pour ne pas coupler le format de dressing à ce service ;
- les secrets (notamment la clé API) ne sont jamais exportés.

RC5 pourra faire évoluer la bibliothèque de styles et le polish UX, mais devra
incrémenter ce contrat si le contenu persistant change.
