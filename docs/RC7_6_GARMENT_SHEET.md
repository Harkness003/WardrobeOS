# RC7.6 — fiche vêtement

## Parcours réellement branché

`MainShell` affiche `WardrobeScreen`. Un appui sur une carte appelle `_openDetail`, qui pousse
`GarmentDetailScreen`. Son action **Modifier** pousse le `GarmentFormScreen` partagé avec
l'ajout manuel et la validation du brouillon scanner. L'enregistrement reste transactionnel et
explicite via `WardrobeController.save`; l'écran de détail recharge ensuite l'instance persistée.

## Présentation

Le premier niveau contient la photo principale, le nom, la marque lorsqu'elle existe, la catégorie,
la sous-catégorie, la couleur et la matière, puis les actions Modifier et Compléter automatiquement.
Les données secondaires sont repliées par défaut dans Analyse de l'IA, Propriétés thermiques,
Historique, Photos complémentaires et Notes et informations avancées. Une section conditionnelle
n'est pas construite quand sa donnée source est absente. L'état des tuiles est conservé par
`PageStorageKey` pendant la consultation.

Styles est désormais présenté comme une compatibilité estimée dans Analyse de l'IA. Occasions
n'est plus édité dans la fiche principale. Les valeurs existantes restent intactes. Les consommateurs
runtime encore dépendants sont `WardrobeAiContextService` (contexte IA) et `RecommendationEngine`
(score de compatibilité); leur comportement n'est pas modifié dans RC7.6.

## Édition, normalisation et catalogues

Il existe un seul champ **Sous-catégorie** : une saisie libre avec suggestions système et personnelles.
Une valeur hors catalogue reste affichée et persistée. Le dépôt central `PersonalCatalogRepository`
apprend les sous-catégories, marques, matières et couleurs acceptées. La table personnelle est séparée
des constantes système; sa clé normalisée empêche les doublons de casse et d'espacement.

Le normaliseur de persistance retire les espaces périphériques, compacte les espaces et applique une
majuscule initiale aux classifications. Les marques déjà en casse mixte et les acronymes courts sont
préservés; une marque entièrement en capitales est recassée mot par mot. Les compositions ne subissent
qu'une normalisation d'espaces afin de préserver acronymes et pourcentages. Les chaînes vides, longues,
technical/JSON et erreurs évidentes ne sont pas apprises.

La sauvegarde automatique n'est pas activée : le formulaire reconstruit aussi le profil thermique et
manipule la photo, donc une écriture à chaque frappe créerait des recalculs et courses inutiles. Le
bouton explicite est conservé, avec un retour discret « Modifications enregistrées ». Les occasions,
`StyleAnalysis`, `ThermalProfile` et champs IA sans rapport sont conservés lors d'une édition.

**Compléter automatiquement** sélectionne le premier domaine réellement absent (catégorie,
composition, style ou thermique), réutilise le service de réanalyse ciblée et conserve les protections
de conflit utilisateur. Sans photo, l'action indique qu'une photo exploitable est nécessaire.

## Limites assumées

RC7.6 ne change ni la taxonomie/bibliothèque de styles, ni le modèle ou moteur thermique, ni le moteur
de génération de tenues. L'import rapide futur devra appeler le même normaliseur et le même dépôt de
catalogue personnel. Une sauvegarde automatique pourra être envisagée après séparation des champs
simples, du recalcul thermique et du cycle de vie des photos.
