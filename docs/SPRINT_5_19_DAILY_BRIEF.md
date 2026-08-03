# Sprint 5.19 — Daily Brief

## Architecture

L'accueil consomme désormais un `DailyBrief`, modèle immuable constitué d'une
liste ordonnée de cartes typées. Chaque carte porte une priorité et ses données
de présentation. Cette structure permet de masquer, réordonner ou enregistrer
de nouveaux types de cartes sans déplacer de logique métier dans les widgets.

`DailyBriefService` est la façade de composition. Elle réutilise :

- `RecommendationEngine` pour classer les pièces selon la saison et la météo ;
- `WardrobeIntelligenceEngine` pour choisir une observation quotidienne ;
- `MemoryService` pour récupérer l'objectif actif ;
- `AssistantService` / WardrobeGPT pour le conseil personnalisé ;
- `WeatherService`, dont les erreurs restent non bloquantes.

Le service limite volontairement le résultat à cinq cartes. L'entretien et
l'objectif sont conditionnels. L'observation est stable pendant une journée et
tourne au fil des jours parmi les insights existants.

## Interface

Le tableau de bord rend les cartes sans effectuer de calcul métier. La tenue
expose ses pièces, son score, une justification détaillée et les propositions
alternatives. Le pull-to-refresh reconstruit le brief. Une indisponibilité météo
ou WardrobeGPT masque seulement la carte concernée.

## Évolutivité

La personnalisation future pourra filtrer et trier `DailyBrief.cards` selon une
configuration persistée. L'ajout d'une carte se limite à un type, son modèle,
sa composition dans le service et son rendu indépendant.

## Validation

Conformément aux contraintes du sprint, aucune commande Flutter, aucun build et
aucun test n'ont été exécutés.
