# RC7.10.2 — Finalisation de l’architecture i18n

## A. Architecture avant / après et cartographie

### Avant

`lib/l10n/app_localizations.dart` était déjà l’unique passerelle : son delegate chargeait
`assets/i18n/en.json` ou `fr.json`. Il n’existe aucun ARB, aucune sortie `gen_l10n` et aucun
autre service de traduction. Le défaut retournait toutefois la clé technique, le delegate
ne définissait pas le repli régional/inconnu et `SystemCatalogs.label` pouvait retourner
l’identifiant. La recherche n’indexait que la langue active. Enfin, la fiche vêtement
utilisait encore `StyleCatalog.displayName`, donc les textes français historiques de
`StyleTaxonomy`.

Cartographie des consommateurs inspectés :

- `StyleCatalog` localise les styles système à la frontière de présentation et conserve les
  styles personnels tels quels ; `CategoryCatalog`, `MaterialCatalog` et `ColorCatalog` sont
  les trois listes de `SystemCatalogs` (il n’existe pas de classes/catalogues concurrents) ;
- `GarmentDetailScreen`, `GarmentFormScreen`, `StyleLibraryScreen` et `StyleDetailScreen` sont
  les surfaces directes des catalogues ;
- Scanner et import construisent/normalisent des `Garment`, sans charger de traduction ;
- Daily et Agenda consomment des recommandations et messages, sans catalogue parallèle ;
- WardrobeGPT reçoit `languageCode` dans `PromptBuilder`, tandis que les données structurées
  restent canoniques ;
- `RecommendationEngine` compare des valeurs normalisées et des `styleId`, jamais un libellé
  obtenu depuis `AppLocalizations`.

Les chaînes visibles génériques restent historiquement dans les widgets (notamment formulaire,
scanner, Daily, Agenda et assistant). Elles ne constituent pas un deuxième catalogue métier ;
leur migration complète est distincte de la sécurisation des quatre catalogues. Les points où
un identifiant canonique pouvait sortir étaient `SystemCatalogs.label`, le détail et les chips
de compatibilité de `GarmentDetailScreen`. Ils sont maintenant fermés.

### Après

`AppLocalizations` reste l’unique loader et charge les deux ressources une seule fois par
résolution de locale. Il conserve la ressource active, l’anglais de secours et les ressources
de recherche. `MaterialApp` applique explicitement la même résolution. Toute traduction
manquante suit le repli anglais puis un texte propre fourni par le consommateur ; jamais la clé.
`SystemCatalogs.label` termine sur « Unknown/Inconnu », pas sur l’ID.

## B. Preuve d’un système unique

Les seules ressources sont `assets/i18n/en.json` et `fr.json`, toutes deux déclarées par le
même répertoire d’assets. Le seul appel à `rootBundle.loadString('assets/i18n/…')` est dans
`AppLocalizations`. L’audit échoue si un second loader apparaît dans `lib`. Il n’y a ni ARB,
ni package de localisation tiers, ni dictionnaire Dart concurrent.

## C. Flux contractuel

```text
SQLite / sauvegarde / réponse structurée IA
  → identifiant canonique (quiet_luxury, merino_wool, tops…)
  → StyleCatalog ou SystemCatalogs
  → AppLocalizations.catalogEntry(...)
  → nom/description/synonymes localisés
  → Text / Dropdown / Chip
```

Le sens inverse ne sert qu’à l’entrée compatible : les anciens alias sont normalisés vers un
ID. Les moteurs, la base et le LLM ne reçoivent jamais un libellé traduit en remplacement de
l’ID. Un changement de locale ne modifie donc ni base, ni cache IA, ni modèle métier : la
reconstruction Flutter recalcule seulement la vue localisée.

## D. Politique de fallback des locales

- `fr_FR`, `fr_CA` et toute variante `fr_*` → `fr` ;
- `en_GB`, `en_US` et toute variante `en_*` → `en` ;
- toute langue inconnue ou locale absente → `en`, langue par défaut.

La règle est portée par `AppLocalizations.resolveLocale` et réutilisée par le delegate et
`MaterialApp.localeResolutionCallback`.

## E. Politique de fallback des traductions

Ordre strict : ressource de langue active → ressource anglaise → texte utilisateur propre
(`Unknown`, `—` ou fallback contextuel). Une clé (`style.old_money`), un chemin de ressource ou
un ID (`old_money`) ne sont jamais employés comme fallback d’affichage. L’audit impose la parité
des chemins et un `name` non vide pour chaque entrée des quatre catalogues.

## F. Recherche multilingue

`StyleCatalog.normalize` ignore casse, accents, `_`, `-` et espaces répétés. L’index associe
le texte visible, les synonymes et les noms/synonymes de **toutes** les ressources au même style
canonique. « Old Money », « Luxe discret » et « Quiet Luxury » peuvent donc retrouver leur ID
sans indexer directement cet ID. Ajouter une langue enrichit automatiquement cet index via sa
ressource.

## G. Valeurs personnelles

`LibraryStyle.localized` retourne immédiatement tout style personnel. Les sous-catégories et
autres termes appris sont conservés et affichés exactement comme saisis (« Saharienne » reste
« Saharienne »). Pas de traduction automatique, pas d’interprétation et pas de migration.

## H. Écrans réellement branchés

La bibliothèque et le détail des styles utilisent la vue `localized`. La fiche vêtement utilise
maintenant la même vue pour le panneau d’aide, les relations et les chips de compatibilité. Le
formulaire consomme encore ses listes historiques pour préserver le contrat de données RC7.10.1.
Scanner/import, Daily, Agenda et WardrobeGPT ne résolvent pas directement d’ID de style dans un
widget ; leurs valeurs structurées restent canoniques. WardrobeGPT transmet en plus la langue
active via le service de prompt. Aucun des moteurs interdits n’a été modifié.

## I. Audit ajouté

`tool/i18n_audit.dart` vérifie : locales attendues, JSON valide, parité intégrale des clés,
présence des catalogues style/catégorie/matière/couleur, noms propres non vides, second loader,
comparaison probable sur un libellé et rendu probable d’un identifiant canonique. Il est prévu
comme garde CI et doit évoluer avec la liste explicite de locales.

## J. Fichiers modifiés

Passerelle et résolution (`app_localizations.dart`, `app.dart`), fallback catalogue
(`system_catalogs.dart`), recherche (`style_repository.dart`), fiche vêtement, ressources JSON,
audit, tests de contrat et ce rapport.

## K. Tests adaptés

Le contrat couvre désormais les variantes régionales, la langue inconnue, la parité complète
des ressources, la couverture des styles, les anciens alias et la persistance inchangée d’un
`styleId`. Conformément à la consigne RC, aucun test, build ou analyse n’a été exécuté.

## L. Limites avant RC7.11

- migrer les textes génériques de tous les écrans vers la passerelle sans confondre ce chantier
  avec les catalogues métier ;
- canoniser le formulaire historique catégories/matières seulement quand les dépendances
  thermiques accepteront ces IDs, afin de ne pas introduire une migration implicite ;
- étendre explicitement `supportedLocales` et l’audit lors de l’ajout réel d’une ressource ;
- connecter le réglage de langue si un sélecteur utilisateur est ajouté. Cela ne demandera
  aucune modification des moteurs ou des modèles persistés.
