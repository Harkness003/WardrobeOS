# RC7.10 — Compatibilités stylistiques

## A. Flux stylistique avant / après

### Cartographie avant

1. Le scanner Vision produisait un `styleSummary` textuel, intégré aux détails du vêtement.
2. `StyleClassifier` ramenait ces indices à un `suggestedRegister` obligatoire et à quelques `suggestedSecondaryStyles`.
3. `Garment.effectiveStyleAnalysis` exposait `register` comme vérité principale persistée.
4. `GarmentDetailScreen` affichait une compatibilité principale puis des styles secondaires et son correcteur imposait un menu « Style principal ».
5. Le contexte de WardrobeGPT publiait `styleRegister` et `secondaryStyles` ; le prompt ne lui interdisait pas d'inventer un registre.
6. `RecommendationEngine` réunissait déjà registre et styles secondaires dans un ensemble, mais traitait toute présence de manière binaire. `OutfitGenerationEngine` consommait ce résultat en aval.
7. `StyleCatalog` était l'unique catalogue, mais ne contenait que douze entrées système.

### Flux après

1. Le prompt scanner demande les **registres naturellement compatibles**, sans vainqueur, et limite les réponses au catalogue.
2. Le classificateur normalise les indices en plusieurs `StyleCompatibility` expliquées, notées et assorties d'une confiance.
3. `StyleAnalysis.compatibilities` choisit la couche utilisateur si elle existe, sinon la couche suggérée ; les anciens champs restent lisibles pour migration et pour les consommateurs non modifiés.
4. Le contexte IA transmet la liste structurée `styleCompatibilities` et sa provenance.
5. WardrobeGPT reçoit l'ordre de raisonner sur cette liste et de ne jamais citer un registre absent.
6. `RecommendationEngine` compare les scores partagés et utilise le meilleur degré de compatibilité plutôt que le premier style.
7. La fiche affiche « Compatible avec », permet l'ajout et le retrait sans désigner de style principal, et conserve ces choix comme préférences utilisateur.
8. `OutfitGenerationEngine` n'est pas modifié.

## B. Catalogue final

Le catalogue système unique couvre : Décontracté, Chic décontracté, Habillé, Sport, Technique, Minimaliste, Workwear, Streetwear, Preppy, Vintage, Rock, Plein air, Business, Business Casual, Old Money, Quiet Luxury, Ivy League, Techwear, Heritage, Military, Utility, Gorpcore, Scandinave, Japandi, Japanese Americana, French Chic, Parisien, Élégance italienne, Méditerranéen, Dark Academia, Light Academia, Classique moderne, Contemporain, Rétro, Y2K, Années 90, Années 80, Bohème, Boho Chic, Western, Punk, Grunge, Romantique, Avant-Garde, Artisanal, Sport Chic, Athleisure, Tennis, Golf, Running, Cyclisme, Nautique, Resort, Beachwear, Soirée, Black Tie, Cocktail, Cérémonie, Invité de mariage, Voyage, Luxe, Créateur, Monochrome, Color Blocking et Normcore.

Chaque entrée possède un identifiant stable, un nom utilisateur, une définition, une description courte, des caractéristiques, couleurs, matières, occasions, pièces typiques et styles proches. Les styles personnels restent dans le même `StyleCatalog` et ne modifient jamais ses entrées système.

## C. Structure de `StyleAnalysis`

`StyleCompatibility` contient `styleId`, `score` (0 à 1), `justification` et `confidence` optionnelle. `StyleAnalysis` sépare `suggestedCompatibilities` de `userCompatibilities`. Une liste utilisateur vide est significative : elle mémorise le retrait de toutes les compatibilités. Le format JSON v2 conserve également les anciens champs afin de décoder les données v1.

## D. Compatibilités au lieu d'un style unique

Une Oxford reçoit notamment Ivy League, Old Money, Business Casual et Quiet Luxury avec des raisons distinctes. Aucun élément n'est déclaré « style principal ». Les accesseurs historiques `register` et `secondaryStyles` subsistent uniquement pour compatibilité descendante, notamment avec `OutfitGenerationEngine` explicitement hors périmètre.

## E. Affichage utilisateur

La fiche montre toutes les puces sous « Compatibilités estimées » et la section IA affiche « Compatible avec » avec score et justification. Un appui sur une puce ouvre toujours la fiche descriptive. L'éditeur est une liste de cases sans sélection principale obligatoire.

## F. Impact sur `RecommendationEngine`

Le moteur construit une table `styleId -> score`. Un style demandé reçoit le score déclaré ; entre deux pièces, le meilleur score moyen d'un registre partagé est utilisé. Les préférences évaluent également le score et non la position dans une liste. Les explications continuent de nommer uniquement un registre réellement partagé.

## G. Impact sur WardrobeGPT

Le contexte remplace les champs principal/secondaires par les compatibilités structurées avec score, justification et confiance. Le prompt autorise une phrase nuancée (« fonctionne avec Old Money mais aussi Business Casual ») et interdit tout registre absent de l'analyse du vêtement.

## H. Apprentissage utilisateur

Une correction produit un override complet `userCompatibilities`. Les ajouts reçoivent une justification et une confiance utilisateur ; les compatibilités retirées restent absentes après réanalyse grâce à `retainCorrectionsFrom`. Il s'agit d'une préférence propre au vêtement, pas d'une mutation du catalogue système.

## I. Fichiers modifiés

- `lib/models/style_analysis.dart`
- `lib/models/style_classifier.dart`
- `lib/features/styles/style_repository.dart` (catalogue consommé, structure inchangée)
- `lib/features/scanner/ai/openai_garment_vision_analyzer.dart`
- `lib/features/wardrobe/garment_detail_screen.dart`
- `lib/core/ai_context/ai_context.dart`
- `lib/features/assistant/prompt/prompt_section.dart`
- `lib/core/recommendation/recommendation_engine.dart`
- `test/models/style_classifier_test.dart`
- `docs/RC7.10_STYLE_COMPATIBILITIES.md`

## J. Tests adaptés

Le test du classificateur couvre désormais l'Oxford multi-compatible, les scores non nuls et les justifications. Les tests n'ont volontairement pas été exécutés dans ce patch, conformément à la consigne RC7.10.

## K. Limites avant RC7.11

- Les champs historiques restent nécessaires tant que `OutfitGenerationEngine` n'a pas migré vers les scores.
- La sortie Vision conserve `styleSummary` comme transport textuel ; la normalisation déterministe construit ensuite le contrat structuré.
- Les scores sont une heuristique locale et devront être calibrés sur des retours utilisateurs réels.
- Les définitions des nouveaux registres sont cohérentes mais volontairement compactes ; un travail éditorial/localisation supplémentaire pourra enrichir les nuances régionales.
- Les compatibilités utilisateur sont apprises par vêtement, sans modèle transversal de préférences entre vêtements.
