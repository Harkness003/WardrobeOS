# Sprint 5.18 — Mémoire et personnalité de WardrobeGPT

## Architecture livrée

La personnalisation est isolée dans `lib/features/assistant/memory`. Les modèles
sont indépendants des widgets et toutes leurs propriétés métier facultatives ont
des valeurs neutres. `MemoryRepository` permet de remplacer SQLite sans modifier
WardrobeGPT ; `DatabaseMemoryRepository` fournit la persistance locale actuelle.

`MemoryService` expose la mémoire déclarative, les objectifs et le profil de
style. `BehavioralObservationService` est une entrée distincte : chaque nouvel
indice augmente ou diminue graduellement la confiance, sans jamais transformer
une observation en fait déclaré. Les modifications d'une mémoire sont conservées
dans une table de révisions, tandis qu'une suppression efface aussi son historique.

## Modèles et données

- `UserMemory` distingue explicitement déclaration et observation, avec confiance,
  nombre d'indices, statut et dates de création/mise à jour.
- `PersonalGoal` porte priorité et cycle de vie (actif, atteint, suspendu, abandonné).
- `StyleProfile` reste indépendant du dressing. Coupes, formalité, couleurs, styles
  et contraintes sont tous optionnels.
- `ProbabilisticStyleAnalysis` prépare morphologie et colorimétrie avec confiance,
  date et indicateur de correction utilisateur. Une analyse ne peut être enregistrée
  dans le modèle sans le consentement correspondant.
- `PersonalizationSnapshot` constitue la vue en lecture injectée dans WardrobeGPT.
- `ProactiveInsight` est le contrat futur des initiatives ; aucun planificateur ni
  aucune notification automatique ne sont activés dans ce sprint.

La base passe en version 9 et crée quatre tables additives. Les profils existants
restent valides : aucune nouvelle colonne n'est requise dans une table historique.
Les sauvegardes incluent les nouvelles données, tout en acceptant les sauvegardes
version 1 qui n'ont pas encore ces sections.

## Adaptation de WardrobeGPT

Le contexte de l'assistant charge facultativement un instantané de personnalisation.
Une indisponibilité de cette mémoire ne bloque pas une réponse. Le prompt distingue
les préférences déclarées, prioritaires, des hypothèses comportementales avec leur
confiance et leurs indices. Il ajoute objectifs et profil lorsque présents.

La personnalité système exige désormais une réponse honnête, argumentée et
bienveillante, mais non complaisante. WardrobeGPT peut contredire l'utilisateur en
expliquant pourquoi. Les analyses morphologiques et colorimétriques doivent toujours
être formulées comme probabilistes.

## Points d'extension

- Brancher une extraction structurée et confirmée des déclarations depuis une
  conversation avant d'appeler `MemoryService.remember`.
- Alimenter `BehavioralObservationService` depuis les acceptations/refus de tenues,
  les ports et les choix récurrents.
- Implémenter des analyseurs de morphologie/colorimétrie derrière des interfaces
  dédiées, seulement après recueil explicite du consentement.
- Produire des `ProactiveInsight` et ajouter ultérieurement arbitrage, fréquence,
  canal et opt-in avant toute notification.
- Ajouter une interface de gestion où l'utilisateur peut consulter, corriger et
  supprimer chaque mémoire, objectif et analyse.

## Limitations

- Aucune extraction automatique depuis le texte libre n'est activée : cela évite
  de mémoriser silencieusement une phrase ambiguë.
- Les observations doivent encore être émises par les futurs points d'intégration
  produit ; le moteur d'évolution est prêt mais ne devine rien seul.
- Aucune analyse d'image morphologique ou colorimétrique n'est réalisée.
- Aucune notification proactive n'est générée.
- La suppression de mémoire est définitive ; l'historique sert à comprendre les
  modifications, pas à restaurer une donnée que l'utilisateur a demandé d'oublier.
