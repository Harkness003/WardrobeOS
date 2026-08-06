# RC7.8.1 — Alignement de l’import rapide

## Contrats IA avant/après

| Phase | Avant RC7.8.1 | Après RC7.8.1 | Destination / consommateur |
|---|---|---|---|
| Quick | nom, catégorie, type précis, couleur principale, marque visible, qualité/confiances | inchangé | identité minimale de `Garment`, revue de confiance et photo principale |
| Enrichment essentiel | matière, compositions, saison, style, occasions, compatibilité, plus tout le schéma du scanner détaillé | matière, compositions lisibles, épaisseur, doublure, coupe, construction, longueur, ouverture, caractéristiques physiques visibles, qualité/confiances | champs objectifs de `Garment`, historique d’analyse et `ThermalProfileCalculator` v3 |
| Enrichment secondaire | analyse stylistique longue obligatoire dans le schéma | absent du chemin d’import rapide | aucun ; le scanner détaillé conserve son contrat séparé |

La saison, les occasions et le registre stylistique ne sont ni demandés ni
persistés par l’import rapide. L’entretien et l’état ne sont pas demandés : une
seule vue générale ne fournit pas de preuve fiable, et leur ajout alourdirait
l’appel sans consommateur propre au flux massif.

## ThermalProfile v3

La fiche créée après quick appelle `ThermalProfileCalculator` avec la catégorie
et la sous-catégorie. Après enrichment, le calcul est complété avec matière,
composition, épaisseur, doublure, coupe, construction, longueur, ouverture et
caractéristiques détectées. Le calculateur produit le modèle courant v3, sans
température ni saison. `thermalProfile` et chacun des champs utilisateur qui
alimentent le calcul sont protégés avant fusion ; une correction utilisateur
n’est donc pas écrasée.

## SQLite

- Version réellement déclarée avant RC7.8 (`86683f4^`) : **1**.
- Version actuelle : **2**. Elle est nouvelle et monotone.
- Installation neuve : `onCreate` crée le schéma canonique, puis
  `wardrobe_import_tasks` avec `CREATE TABLE IF NOT EXISTS`.
- Installation existante v1 : `onUpgrade`, lorsque `oldVersion < 2`, crée la
  même table sans modifier les tables existantes.

## Capture ImagePicker mesurée

Le parcours réel reste : appui → ouverture de la caméra native ImagePicker →
capture ou validation native imposée par l’application caméra du système →
retour à `WardrobeImportScreen` → copie persistante → mise en file → bouton
réactivé dans `finally` → nouvel appui pour rouvrir la caméra. L’application
n’ajoute aucun écran de validation. Une annulation native renvoie `null` avant
la persistance et avant `enqueue`, donc ne crée aucune tâche. Le seul délai
applicatif entre deux ouvertures est la copie locale et la mise en file ;
l’analyse IA est asynchrone.

`GarmentCapture` isole désormais cette remise de contrôle native. Un futur
aperçu `CameraController` pourra implémenter ce contrat, mais exigera encore la
gestion du cycle de vie caméra, des permissions, de l’orientation, du flash, de
la mise au point et de la prévisualisation continue. Aucun mode vidéo n’est
introduit.

## Coût IA évité

L’enrichment essentiel conserve un seul appel et la même photo compressée, mais
supprime du prompt et du schéma les taxonomies de saisons, styles, associations
de couleurs, bas, chaussures, occasions, conseils, verdict et demande de photo
complémentaire. Une fiche à forte confiance n’attend donc aucune analyse de
style secondaire. Le gain exact en jetons dépend du vêtement et du fournisseur ;
le dépôt ne fabrique pas de chiffre sans télémétrie de tokens.
