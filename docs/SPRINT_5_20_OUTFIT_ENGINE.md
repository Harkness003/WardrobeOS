# Sprint 5.20 — Outfit Engine

## Architecture

`Outfit` est désormais l'objet métier central d'une tenue. Il conserve ses
champs persistés historiques et porte en plus des vêtements groupés par
catégorie, un score explicable et une justification. La collection par
catégorie autorise naturellement la superposition.

`OutfitEngine` constitue l'API publique : `generateBestOutfit`,
`generateAlternatives`, `scoreOutfit`, `explainOutfit` et `validateOutfit`.
Il délègue les compatibilités au `RecommendationEngine` existant afin de ne
pas dupliquer les règles de style, météo, température et formalité.

L'adaptateur historique de l'assistant continue d'exposer les candidats et le
résultat de recommandation précédents, tout en ajoutant la tenue composée dans
`OutfitRecommendationResult.outfit`. Cette évolution est donc additive.

## Extensibilité

Les champs historiques de port et de favori restent disponibles sur `Outfit`.
La persistance actuelle n'est pas modifiée : date de port, fréquence, archive
et notation pourront être regroupées dans une évolution dédiée sans activer
ces fonctionnalités dans ce sprint.

## Variantes

Les variantes remplacent une seule catégorie (chaussures, veste, manteau ou
accessoire), conservent toutes les autres pièces puis recalculent score et
justification via la même API centrale.
