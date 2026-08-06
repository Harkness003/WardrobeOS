# RC7.5 — Audit et contrat du pipeline de scan

## A. Pipeline avant

1. La photo était copiée dans le stockage local puis validée et relue en mémoire.
2. L'appel `analyzeQuick` identifiait le vêtement.
3. Un appel `enrich` complet repartait de la même photo.
4. À chaque photo ajoutée, `analyze()` rappelait d'abord `analyzeQuick`, puis
   `enrich`, en envoyant aussi toutes les images antérieures.
5. La fusion laissait l'enrichissement recalculer l'identité et le moteur
   pouvait demander une nouvelle photo sans limite locale stricte.
6. La fiche n'était ouvrable que dans certains états et tous ses boutons
   étaient bloqués tant que l'analyse tournait.

## B. Pipeline après

`photo locale → validation/préparation → quick → brouillon ouvrable →
enrichissement ciblé asynchrone → décision → zéro ou une photo ciblée → fusion
→ fin`.

Le quick possède l'identité (`suggestedName`, `category`, `preciseType`,
`primaryColor`, `visibleBrand`). L'enrichissement ne complète que les champs
absents explicitement demandés. Une photo complémentaire est un appel
`enrich` ciblé sur ses `targetFields`, avec le résultat précédent en contexte,
mais sans réexpédier les anciennes images. Après cet appel, la condition
d'arrêt locale supprime toute nouvelle demande.

Chaque demande de photo est un contrat comprenant : le type et l'instruction,
la raison métier, et les champs cibles. Sans champ cible consommé, aucun appel
complémentaire n'est lancé.

## C. Appels IA supprimés

- Le second `quick` auparavant déclenché par une photo complémentaire.
- Le second enrichissement complet qui suivait ce `quick`.
- Le renvoi de la photo principale et de toutes les photos précédentes à chaque
  suivi.
- Toute troisième demande et toute boucle de photos complémentaires.
- Le recalcul par enrichissement du nom, de la catégorie, de la sous-catégorie
  et de la couleur.

## D. Appels IA conservés

- Un `analyzeQuick` sur la première photo, limité à l'identité visuelle.
- Un `enrich` asynchrone sur la première photo pour les champs manquants utiles.
- Au maximum un `enrich` ciblé sur une unique photo complémentaire lorsque le
  moteur a fourni une raison et des champs cibles exploitables.

## E. Gains obtenus

- La fiche est disponible dès le quick et son ouverture ne bloque ni n'annule
  l'enrichissement.
- Une photo complémentaire coûte un seul appel ciblé et un seul upload d'image,
  au lieu d'une nouvelle séquence complète et cumulative.
- Les corrections saisies pendant l'attente restent prioritaires et l'identité
  issue du quick reste stable.
- La progression distingue préparation, identification, enrichissement,
  demande complémentaire et fin. Les chronométrages conservent séparément
  préparation/compression, appel IA, parsing, fusion et total pour `quick`,
  `enrichment` et `complementaryPhoto`.
- La file séquentielle accepte déjà des travaux fondés sur des fichiers locaux,
  ce qui limite les appels concurrents et prépare l'import massif.

## F. Limites avant « Importer mon dressing »

- Il reste à créer l'écran de sélection massive, la persistance durable de la
  file et sa reprise après fermeture de l'application.
- La concurrence, la priorité, l'annulation par lot et les politiques de débit
  réseau/API devront être définies.
- La création automatique des brouillons, les doublons de photos, le reporting
  global, les erreurs par vêtement et le budget de coût ne sont pas encore une
  expérience utilisateur de masse.
- La latence du fournisseur IA subsiste ; ce patch la masque par une fiche
  précoce mais ne change ni fournisseur, ni modèle, ni moteur IA.
