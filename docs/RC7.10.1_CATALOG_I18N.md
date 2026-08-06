# RC7.10.1 — Architecture i18n des catalogues

## Cartographie avant le patch

`StyleTaxonomy` portait à la fois l'identifiant persistant et les textes français. `StyleCatalog`
exposait ces textes directement à `StyleLibraryScreen`, `StyleDetailScreen`,
`GarmentDetailScreen` et `GarmentFormScreen`. La recherche indexait ces mêmes textes.
`StyleAnalysis`, le classifieur, `RecommendationEngine` et `OutfitGenerationEngine` consomment
les identifiants. Le scanner normalise ses réponses avant de construire un `Garment`.
`ThermalProfile` est un modèle calculé, pas un catalogue d'affichage. Les listes de catégories,
sous-catégories et matières étaient locales au formulaire. Les couleurs étaient libres et les
valeurs apprises passent par `PersonalCatalogRepository`.

Les points fragiles étaient donc les usages de `StyleDefinition.name`, les listes françaises du
formulaire, `StyleCatalog.displayName`, et les alias traduits de l'analyse d'intention. Une
traduction de ces valeurs persistées aurait cassé normalisation, comparaison et restauration.

## Architecture après le patch

Le flux de référence est désormais :

```text
Base de données → identifiant canonique → catalogue unique
                  → AppLocalizations → libellé UI
```

`AppLocalizations` charge une ressource par locale. Les ressources de style couvrent nom,
description, définition, caractéristiques, couleurs, matières, pièces, exemples et synonymes.
Les relations restent des identifiants et sont résolues comme tels. `SystemCatalogs` définit les
identifiants canoniques des catégories, matières et couleurs et reconnaît explicitement les
anciens libellés comme alias de lecture. Aucun identifiant existant de `StyleTaxonomy` n'est
modifié et aucune migration de données n'est introduite.

Les catalogues convertis dans cette fondation sont : styles système, catégories système,
matières système et couleurs système. Les sous-catégories sont le prochain consommateur à
basculer sur le même contrat. Les propriétés thermiques restent inchangées conformément au
périmètre RC7.10.1.

## Valeurs personnelles et recherche

`LibraryStyle.localized` retourne immédiatement les styles personnels sans transformation.
De même, `PersonalCatalogRepository` conserve exactement la valeur normalisée apprise : aucune
traduction automatique n'est appliquée à « Saharienne » ou à une autre saisie personnelle.

La recherche de styles construit son index sur la vue localisée (nom, synonymes, définition,
description et caractéristiques), puis retourne l'objet portant le même identifiant canonique.
Changer la locale reconstruit donc implicitement l'index visible sans toucher aux données.

## WardrobeGPT

Le service transmet le code de langue de l'application dans le prompt. Le prompt ordonne au
modèle de répondre dans cette langue tout en conservant les identifiants de catalogue dans les
données structurées. La logique de recommandation et `StyleAnalysis` ne sont pas modifiés.

## Limites avant RC7.11

- Basculer les sous-catégories et le reste des écrans historiques sur `SystemCatalogs` sans
  traduire les valeurs personnelles qui leur sont mêlées.
- Remplacer les derniers textes d'interface génériques (hors catalogues) par des ressources.
- Faire produire au scanner uniquement des identifiants canoniques pour catégories, matières et
  couleurs, tout en conservant ses alias de compatibilité en entrée.
- Localiser les messages de secours de WardrobeGPT ; sa langue de génération est déjà imposée.
- Étendre le catalogue de couleurs libres lorsque la taxonomie produit sera stabilisée.
