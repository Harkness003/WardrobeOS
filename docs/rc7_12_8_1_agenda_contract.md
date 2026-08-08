# RC7.12.8.1 — contrat règles Agenda

Les règles sont évaluées **par occurrence (règle activée × jour généré)** sur
la tenue effectivement sélectionnée. `rulesSatisfied`, `rulesUnsatisfied` et
`rulesNotApplicable` sont les sommes hebdomadaires de ces occurrences.
`ruleConflict` vaut vrai si au moins une contradiction structurelle est trouvée
et `conflictCount` compte les contradictions, sans identifiant de vêtement ni
paramètre privé.

L'ordre de priorité est : contraintes techniques, choix/verrous explicites,
règles personnalisées bloquantes, stratégie Agenda, préférences souples. Un
verrou de catégorie opposé à `refreshCategory` ou `alternateCategory` est un
conflit. L'absence d'alternative dans le dressing est seulement `unsatisfied` :
la tenue valide reste utilisable.

WardrobeGPT Agenda read : **COMPLETE**.

WardrobeGPT Agenda write : **DEFERRED until canonical assistant write-action
contract**. Le contrat `AssistantTool.getData` est en lecture seule ; ajouter
une écriture spécifique à Agenda créerait une architecture conversationnelle
parallèle et un parseur NLP local.
