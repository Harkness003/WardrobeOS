# RC7.11 — Mode développeur et centre de diagnostic

## A. Architecture avant / après

Avant RC7.11, les erreurs étaient transformées localement en messages d’interface et les moteurs conservaient quelques états propres (`DailyBrief.state`, `AgendaGenerationReport`, `GoogleCalendarSyncState`, métriques d’import), sans vue transversale. Après RC7.11, tous les producteurs publient vers `DiagnosticService`, bus unique désactivé par défaut. Le centre lit ce bus, filtre ses entrées et exporte sa représentation anonymisée. Aucun moteur métier ni algorithme de recommandation n’est remplacé.

## Cartographie vérifiée avant modification

| Domaine | Point d’entrée réellement utilisé | Erreurs / état déjà disponibles | État utile au diagnostic |
|---|---|---|---|
| Scanner | `ScannerScreen.analyze`, file `GarmentAnalysisQueue`, `GarmentVisionAnalyzer.analyzeQuick` | `GarmentAnalysisException`, validation et décision scanner | photos, quick, décision, enrichissement, thermique, durées |
| Import rapide | `WardrobeImportService.enqueue` puis `_process` | `WardrobeImportStatus`, `userMessage`, `timings`, `metrics` | file, quick, création, enrichment, revue |
| WardrobeGPT | `AssistantService.generateMessageStream` | `LlmException`, intention et diagnostic de génération | intention, contexte, propositions, fournisseur |
| Tenues | `OutfitGenerationEngine.generate` | `OutfitGenerationDiagnostic` et raisons utilisateur | contexte, candidats, compatibilité, résultat |
| Recommandation | `RecommendationEngine.recommend` | `RecommendationResult` | scores, règles éliminatoires et rotation |
| Daily Brief | `DailyBriefService.watch/build` | `DailyBriefState`, `detail`, météo optionnelle | météo, contexte dressing, génération, recommandation |
| Agenda | `AgendaService.proposeDay/proposePeriod` | `AgendaGenerationReport`, échecs par jour | événements, calendrier actif, météo, propositions |
| Google Calendar | `GoogleCalendarService.refresh` | `GoogleCalendarSyncState` et `GoogleCalendarStatus` | connexion, calendriers sélectionnés, événements, date |
| Weather | `CachedWeatherService.getCurrentWeather` | cache, erreurs API/localisation | ville, température, source et cache |
| Backup | `BackupService.createBackup/writeBackup`, `BackupController` | avertissements, manifeste et résultat utilisateur | taille, vêtements, photos manquantes, durée |
| Dressing | `WardrobeController.load/create/update/delete` | `loading`, `error`, liste locale | compte et opération |
| Base locale | singleton `DatabaseService`, opérations SQLite/export/restore | exceptions SQLite remontées aux contrôleurs | schéma, compte, durée, opération |

## B–E. Service, instrumentation, pipelines et informations visibles

`DiagnosticService` définit les dix modules, quatre niveaux (`INFO`, `WARNING`, `ERROR`, `SUCCESS`), une FIFO indépendante de 100 entrées par module, le filtrage, la purge et l’export. Il ne construit aucune entrée lorsqu’il est désactivé. Les cartes montrent état, résumé orienté métier, durée, raison, avertissement, date, version, source et détails autorisés.

Les premiers producteurs branchés sont Daily (`Weather → WardrobeContext → Generation → Recommendation → Résultat`), import/scanner progressif (`Photo → Quick → Création → Enrichment → Thermal`), WardrobeGPT (`Intention → WardrobeContext → OutfitGeneration → Résultat`), Weather et Backup (`Base locale → Collecte → Archive`). Les modules Agenda, Google Calendar, Tenues et Base locale ont dès maintenant leurs sections dédiées dans le modèle et l’écran ; leur instrumentation exhaustive reste une limite ci-dessous.

## F. Protection des données sensibles

La protection est centralisée et s’applique à la publication **et** à l’export : liste de clés interdites, masquage des jetons Bearer, clés usuelles et chemins privés, conversion des exceptions techniques en raison métier. Les photos, contenu des prompts, e-mails/comptes, coordonnées, tokens OAuth et clés API ne sont jamais inclus. Les producteurs ne doivent publier que des agrégats.

## G. Export

« Exporter un rapport » produit du JSON lisible (version du rapport et de l’application, plateforme, date, diagnostics, états et timings) puis le copie dans le presse-papiers. Le rapport respecte les filtres actifs et rappelle sa politique de confidentialité. Il ne contient aucun média.

## H. Fichiers modifiés

- `lib/core/diagnostics/diagnostic_service.dart` : modèle, bus, FIFO, filtre, purge, anonymisation et export.
- `lib/features/developer/developer_diagnostics_screen.dart` : centre de diagnostic.
- `lib/core/settings/app_settings.dart`, `lib/features/profile/profile_screen.dart` : activation et visibilité conditionnelle.
- services Daily, Weather, Backup, Import et Assistant : publication uniquement.
- `test/core/diagnostics/diagnostic_service_test.dart` : contrat du service.

## I. Tests ajoutés

Les tests couvrent : désactivation, FIFO, filtres, purge et suppression des données sensibles dans l’export. Conformément à la consigne RC7.11, ils n’ont pas été exécutés.

## J. Limites restantes

- L’historique est conservé pendant la vie du processus ; une persistance chiffrée inter-session n’est pas ajoutée afin de ne pas créer un nouveau stockage de données potentiellement sensibles.
- Agenda, Google Calendar, scanner unitaire, `WardrobeController` et `DatabaseService` disposent de sections mais demandent encore des points de publication exhaustifs.
- L’export est copié dans le presse-papiers plutôt qu’écrit dans un chemin privé ; un partage natif pourra être ajouté quand une dépendance de partage sera validée.
