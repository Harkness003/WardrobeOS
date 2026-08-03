# Sprint 5.18 — Wardrobe Intelligence Engine

## Architecture

Le moteur est un composant Dart pur situé dans `lib/core/wardrobe_intelligence`.
Il ne dépend ni de Flutter, ni d’un widget, ni de la base de données. Ses appelants
lui transmettent simplement une collection de `Garment`. Le résultat immuable peut
ainsi être consommé par WardrobeGPT, les recommandations, l’agenda, le voyage, les
achats, les notifications, les statistiques ou de futurs objectifs.

## API publique

- `WardrobeIntelligenceEngine.analyze(Iterable<Garment>)` produit un rapport complet.
- `WardrobeIntelligenceEngine(rules:, clock:)` permet d’ajouter/remplacer les règles
  et d’injecter une horloge déterministe.
- `WardrobeIntelligenceReport` expose distributions, pièces peu portées, groupes de
  doublons, manques, score explicable et insights structurés.
- `WardrobeGapRule.evaluate(WardrobeRuleContext)` est le point d’extension des règles.
- `wardrobe_intelligence.dart` constitue le barrel d’import public.

## Indicateurs

Les distributions des catégories, couleurs, styles, saisons et matières contiennent
les effectifs connus, inconnus et la part de chaque valeur. L’analyse détecte aussi
les pièces sous-utilisées quand des données de port existent, les rôles similaires,
les besoins non couverts et la faible couverture des fortes chaleurs.

Le score sur 100 détaille cinq composantes pondérées : diversité des catégories,
diversité des couleurs, couverture saisonnière, couverture des besoins et redondance
des rôles. Chaque composante fournit sa valeur, son poids et une explication.

## Règles livrées

Les règles par défaut détectent l’absence de vêtement de pluie, une couverture hiver
insuffisante, l’absence de chaussures habillées, le manque de couleurs neutres et
les groupes trop similaires. Elles sont centralisées dans
`wardrobe_intelligence_rules.dart` et implémentent toutes le même contrat.

## Limitations

- La qualité dépend de la complétude et de la normalisation des métadonnées existantes.
- Les seuils sont des valeurs par défaut génériques, sans profil utilisateur, climat
  local, profession ou fréquence réelle des occasions.
- Un doublon est une similarité de rôle fondée sur les métadonnées, pas une identité
  visuelle calculée à partir des images.
- Les pièces peu portées ne sont produites que si le dressing contient au moins une
  donnée de port ; l’âge de possession n’est pas encore pris en compte.
- Le moteur ne persiste pas les rapports et ne déclenche aucune fonctionnalité future.
