# Sprint Daily Brief — fiabilité et chargement progressif

## Périmètre

Ce sprint ne modifie ni WardrobeGPT, ni le scanner, ni l’Agenda. Le Daily Brief
ne sollicite plus WardrobeGPT : ses conseils courts sont dérivés localement de
la tenue et de la météo facultative.

## Fondations et fraîcheur des données

`DailyBriefService` utilise désormais le chemin unique suivant :

1. `WardrobeAiContextService.build()` relit le dressing courant ;
2. le `PersonalizationSnapshot` est converti en `RecommendationPreferences` ;
3. `OutfitGenerationEngine` classe les pièces à partir de `StyleAnalysis` et
   `effectiveThermalProfile` ;
4. la météo, lancée en parallèle, enrichit ensuite le contexte si elle arrive.

Aucune copie du dressing n’est conservée dans l’écran. Un pull-to-refresh crée
un nouveau flux et relit donc immédiatement les ajouts et modifications. Les
analyses stylistiques et profils thermiques persistés dans les vêtements sont
réutilisés par le moteur ; aucun scan ni recalcul d’analyse n’est déclenché.

## Chargement et états

La structure et l’état « Chargement du dressing… » sont rendus dès la première
frame. Le flux publie ensuite :

- une tenue et les observations disponibles dès la lecture du contexte ;
- une version enrichie lorsque la météo est disponible ;
- aucun second état si la météo échoue.

Les quatre issues sont explicites : chargement, tenue disponible, aucune
recommandation et erreur avec action de relance. La carte tenue limite le titre,
l’explication et les chips à deux lignes/trois pièces ; l’explication complète
reste dans la bottom sheet « Pourquoi ? ».

## Temps de chargement avant / après

La comparaison du chemin critique est la suivante :

| Mesure | Avant | Après |
| --- | --- | --- |
| Premier rendu utile de la page | après dressing + météo + mémoire + analyse + appel GPT | première frame (structure + état explicite) |
| Première tenue | après météo et GPT | après une seule lecture du contexte dressing/mémoire |
| Météo indisponible | attente de l’échec avant composition | hors chemin critique, tenue déjà publiée |
| Accès dressing au démarrage du Daily | chargement du contrôleur puis nouvelle lecture du contexte | une lecture via `WardrobeAiContextService` |
| Appel réseau de conseil | un appel GPT | aucun |

Les valeurs en millisecondes doivent être relevées sur appareil cible (base et
réseau représentatifs) : le conteneur de validation ne fournit pas de SDK
Flutter. Le gain structurel est néanmoins déterministe : la météo et le conseil
réseau ont été retirés du chemin critique, et une lecture dressing redondante a
été supprimée.

## Validation et suite avant le sprint Agenda

Les tests automatisés couvrent la météo absente, l’émission progressive et la
relecture d’une fiche récemment modifiée. Les dressings vide/réduit sont gérés
par un état dédié et le moteur borné en `O(n log n)` reste adapté aux grands
dressings.

À finaliser avant le sprint Agenda :

- relever P50/P95 sur un appareil avec dressing réduit et important ;
- ajouter un test widget golden sur petit écran et avec noms très longs ;
- décider si occasion et formalité de l’Agenda doivent, au sprint suivant,
  compléter `RecommendationContext` sans rendre l’Agenda bloquant ;
- observer la pertinence des règles de conversion des souvenirs en matières à
  éviter et étendre leur taxonomie avec des champs structurés si nécessaire.
