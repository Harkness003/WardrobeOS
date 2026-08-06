# RC7.12 — Centre d’actions : cartographie et architecture

## A. Cartographie avant modification

| Producteur | Événements/états existants | Durée | Persistance | Action utilisateur réelle |
|---|---|---|---|---|
| Scanner unitaire | résultat, analyse complémentaire, rejet/échec dans l’état de l’écran; diagnostics scanner | temporaire | la fiche validée est en base, le déroulé ne l’est pas | corriger une analyse incertaine; reprendre une photo rejetée |
| Import Dressing | `WardrobeImportEvent` (`importFinished`, `needsReview`, `analysisFailed`, `enrichmentFinished`) et statuts des tâches | durable | oui, table `wardrobe_import_tasks` | vérifier une fiche, réessayer un échec, ouvrir un import terminé |
| `WardrobeController` | chargement, erreur, mutations et `notifyListeners` | temporaire (projection de la base) | vêtements/mutations en base | une erreur de chargement peut être réessayée; les succès ne demandent rien |
| Backup | `busy`, `result`, `resultIsError`, destination/manifest; diagnostics | temporaire | archive externe uniquement | conserver/constater le succès ou relancer l’échec |
| Daily | flux `DailyBrief`, états `emptyWardrobe`, `insufficientWardrobe`, `noProposal`, `weatherError`, `available`; diagnostics | temporaire | non | météo indisponible seulement si une relance est possible; les cartes sont du contenu, pas des actions |
| WardrobeGPT | résultat/flux, erreurs fournisseur et diagnostics | temporaire | mémoire utilisateur persistée, réponses non persistées | aucune action globale stable; la reconnexion API reste dans les réglages |
| Agenda | `error`, états par jour, rapports, conflits levés par le service | mixte | tenues planifiées en base; erreurs temporaires | résoudre un conflit ou réessayer une génération |
| Google Calendar | connexion et calendriers sélectionnés persistés; cache, `syncState`, message d’échec temporaires | mixte | authentification/sélection persistées, cache mémoire | réessayer ou reconnecter après échec de synchronisation |
| `DiagnosticService` | bus opt-in borné à 50 entrées/module | temporaire | non | aucune : outil développeur et historique technique, donc explicitement exclu de l’inbox |
| Météo | cache et requête en vol; diagnostic succès/échec | temporaire | non | réessayer l’actualisation lorsqu’elle bloque une expérience |
| Réanalyse | candidats calculés, propositions et conflits de champs | mixte | versions/snapshots en base, proposition temporaire | lancer la réanalyse, accepter/refuser les changements et résoudre les conflits |

Cette distinction empêche d’utiliser le journal de diagnostic comme système de notifications. Un succès sans choix utile, un état de chargement ou une conversation ne devient pas une carte.

## B. Architecture avant/après

**Avant :** chaque écran observe directement son contrôleur, affiche localement message, dialogue ou état; l’import possède déjà un flux et des tâches persistées; les diagnostics constituent un bus technique séparé.

**Après :** un unique `ActionCenterService`, instancié au niveau du shell, écoute les états déjà calculés. Il projette des `ActionCenterItem` groupés, ordonnés et actionnables. Il ne lit pas la base, ne poll pas et ne remplace ni les contrôleurs ni `DiagnosticService`. L’écran `Actions` est une vue de cette projection.

## C–H. Contrat du centre

- **Service unique :** modèle commun `kind`, `priority`, `count`, texte orienté solution et libellé principal.
- **Événements branchés dans RC7.12 :** tâches/flux persistés d’Import Dressing et résultats existants de `BackupController`.
- **Regroupement :** une carte par statut fonctionnel (`à vérifier`, `échoué`, `terminé`), jamais une carte par photo.
- **Priorités :** urgent (import impossible), haute (correction ou sauvegarde échouée), normale (action standard), basse (succès à constater/ouvrir).
- **Actions directes :** `Corriger/Ouvrir` ouvre le dressing, `Réessayer` relance toutes les tâches échouées ou la sauvegarde, `Ignorer` retire la carte.
- **Disparition :** la projection se recalcule sur `ChangeNotifier`; une tâche relancée quitte immédiatement le groupe échec. Les actions ponctuelles peuvent être ignorées et l’ignorance est réversible par snackbar `Annuler`.
- **Absence de duplication :** les succès et échecs de sauvegarde se remplacent; les tâches import ignorées sont identifiées par leur identifiant existant.

## I. Optimisations UX réalisées

- entrée `Actions` dans la navigation principale et état vide compact;
- cartes sans menu secondaire, boutons intégrés et texte proposant la suite;
- tri stable par priorité, icône sémantique et compteur groupé;
- snackbar d’annulation pour l’action réversible `Ignorer`;
- `Semantics` avec région active pour l’état vide et description complète de chaque carte; composants Material accessibles au clavier, à TalkBack et à VoiceOver;
- aucune section vide, aucun pourcentage de confiance et aucun historique technique dans le centre;
- aucun modal ajouté.

## J. Fichiers modifiés

- `lib/features/action_center/action_center_service.dart`
- `lib/features/action_center/action_center_screen.dart`
- `lib/features/shell/main_shell.dart`
- `docs/RC7_12_ACTION_CENTER.md`

## K. Tests adaptés

Aucun test n’a été exécuté, conformément à la consigne RC7.12. La validation à prévoir couvre : regroupement des tâches restaurées, tri des priorités, relance groupée, remplacement succès/échec backup, disparition à la résolution, annulation d’un masquage, sémantique et navigation clavier.

## L. Limites avant RC7.13

- Brancher, uniquement à partir de leurs états existants, les échecs Google Calendar/météo et les erreurs Agenda; aucune API d’événement applicatif stable n’est actuellement exposée pour tous ces modules.
- Publier les candidats et conflits de réanalyse lorsqu’un flux existant durable sera disponible; ne pas déclencher un scan de la garde-robe depuis le centre.
- Relier la correction à la première fiche concernée plutôt qu’à la liste du dressing lorsque la navigation ciblée exposera ce contrat.
- Internationaliser les nouveaux libellés lors du prochain passage catalogue; cette tranche conserve la langue actuelle de la navigation.
- La liste des imports terminés repose sur les tâches persistées existantes. Une politique de résolution métier explicite permettra ensuite de les retirer après ouverture sans transformer le centre en historique.
