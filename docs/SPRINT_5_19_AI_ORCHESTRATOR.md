# Sprint 5.19 — IA Orchestrator

## Composants livrés

- `AiOrchestrator` planifie, ordonne et agrège les exécutions sans logique métier.
- `AiEngine` est le contrat indépendant des moteurs. `CallbackAiEngine` adapte les services existants sans les coupler.
- `AiOrchestrationCache` abstrait le cache ; `MemoryAiOrchestrationCache` fournit l'implémentation initiale remplaçable.
- `AiOrchestrationLogger` réutilise `dart:developer` et journalise chaque décision, son état et sa raison.
- `createWardrobeAiOrchestrator` constitue le pipeline standard à partir de callbacks injectés.

## Pipeline et dépendances

Le graphe déclaré est :

`Scanner → Fusion → Analyse stylistique → Wardrobe Intelligence → Recommendation Engine → WardrobeGPT`.

Les dépendances imposent l'ordre, mais ne forcent pas le recalcul d'un prédécesseur lors d'une mise à jour incrémentale. Une demande explicite d'un résultat inclut en revanche ses dépendances. Chaque moteur reçoit uniquement les résultats de ses prédécesseurs via `AiEngineContext` et ne connaît aucun autre service.

## Planification et optimisations

Les champs `changedFields` sont comparés aux invalidations déclaratives de chaque moteur. Ainsi, `comment` n'invalide aucun moteur, `photo` déroule tout le pipeline et `material` évite le scanner et la fusion. `requestedEngines` permet de demander explicitement une sortie. Un `cacheFingerprint` stable réutilise les résultats par moteur et retourne l'état `upToDate` au lieu de recalculer.

Le résultat agrégé conserve, pour chaque moteur, les états `success`, `error`, `skipped`, `upToDate` ou `pending`, la raison, la durée, la valeur éventuelle et l'erreur. Une erreur est isolée : les branches indépendantes poursuivent leur exécution ; seules les étapes sélectionnées dépendant du résultat en échec restent en attente.

## Extensibilité

Agenda, voyage, achat, notifications, calendrier et garde-robe capsule peuvent être enregistrés comme nouveaux `AiEngine`, avec leurs dépendances et champs invalidants, sans modifier l'orchestrateur. Le cache et le logger sont eux aussi injectables.

## Limitations restantes

- Le cache fourni est en mémoire : une implémentation persistante devra être injectée pour survivre au redémarrage.
- La composition est prête à recevoir les services actuels, mais son branchement aux flux UI est volontairement laissé au composition root afin de ne pas ajouter de logique métier aux widgets.
- La politique de fingerprint et l'expiration relèvent de l'appelant ou d'une future implémentation de cache persistante.
- Le pipeline est séquentiel ; des branches indépendantes pourront être parallélisées ultérieurement sans changer les contrats.
