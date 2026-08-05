# RC6.7 — Intégration Google Calendar dans Agenda

## Architecture retenue

Le flux conserve l'abstraction existante : `AgendaService` dépend uniquement de `CalendarService`, et `GoogleCalendarService` devient une implémentation lecture seule de cette abstraction.

```text
Agenda
 ↓
CalendarService
 ↓
GoogleCalendarService
```

La logique Google reste limitée à l'authentification, la récupération, la sélection et le cache des calendriers. La conversion métier événement → contraintes tenue est isolée dans `CalendarEventContextMapper`, puis l'agenda appelle toujours `OutfitGenerationEngine` avec l'événement réel, la météo et le dressing.

## Flux utilisateur

1. L'utilisateur ouvre la section calendrier dans Agenda.
2. L'état de connexion Google, les calendriers actifs et la dernière synchronisation sont affichés.
3. Après connexion OAuth côté plateforme, l'application sauvegarde uniquement l'état de connexion et le jeton d'accès dans le stockage sécurisé déjà utilisé par l'app.
4. L'utilisateur sélectionne les calendriers à prendre en compte.
5. Une synchronisation initiale ou manuelle remplit le cache local.
6. Agenda lit les événements depuis `CalendarService`, enrichit le contexte via la météo et le dressing, puis génère les propositions avec `OutfitGenerationEngine`.

## Gestion des états

- Non connecté : message clair invitant à connecter Google Calendar.
- Permission refusée : état dédié sans exception brute.
- Aucun calendrier sélectionné : état explicite demandant de choisir au moins un calendrier.
- Erreur réseau Google : le cache local reste utilisable si disponible et un message compréhensible est exposé.

## Limites restantes avant RC7

- Brancher le vrai déclenchement OAuth natif/web sur le bouton de connexion.
- Persister la sélection des calendriers au-delà de la session si le stockage sécurisé doit aussi couvrir ce choix.
- Ajouter une interface complète de sélection multi-calendriers.
- Ajouter une stratégie de renouvellement de jeton selon le mécanisme OAuth retenu par plateforme.
