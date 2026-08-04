# Audit et architecture du contexte IA

## État avant cette modification

- **WardrobeGPT** construisait ses statistiques et son historique depuis un
  `WardrobeController` longue durée. Une fois `loading == false`, un nouvel
  appel ne rechargeait pas la base. Les outils dressing et le moteur de
  recommandation réutilisaient la même liste en mémoire.
- **Daily Brief** recevait une liste de vêtements fournie par le widget du
  tableau de bord. Cette copie était cohérente au chargement de l'écran, mais
  sa fraîcheur dépendait du cycle de vie de ce contrôleur. Son conseil GPT
  déclenchait en plus le flux WardrobeGPT, avec son propre cache en mémoire.
- **Agenda** relisait déjà `DatabaseService.getGarments()` pour générer une
  proposition. Il constituait toutefois son contexte séparément, sans contrat
  commun avec les autres fonctions IA.
- **Transmission au modèle** : le prompt WardrobeGPT ne contenait que des
  compteurs. Un outil ajoutait catégories, couleurs et quelques identifiants,
  tandis que le moteur de recommandation transmettait des candidats. Aucun
  payload unique ne décrivait toutes les fiches, leur provenance ou la règle
  de priorité entre mémoire et dressing.
- Les vêtements avaient déjà un identifiant UUID stable, stocké comme clé
  primaire SQLite. Aucun nouveau champ ni aucune migration n'étaient donc
  nécessaires.

Le risque principal était une réponse fondée sur la liste d'un contrôleur
encore vivant après une modification du dressing. Les différents chemins
pouvaient aussi fournir au modèle des représentations partielles et
contradictoires.

## Architecture retenue

`WardrobeAiContextService` est désormais l'unique fabrique du snapshot métier
destiné aux fonctions intelligentes. Chaque appel relit les vêtements dans la
base, sans cache. La mémoire est chargée séparément et reste facultative ; elle
n'est jamais fusionnée dans une fiche vêtement.

Le snapshot conserve les objets `Garment` pour les moteurs déterministes et
expose parallèlement des `AiGarmentContext` sérialisables pour les prompts.
Chaque valeur est étiquetée `user`, `aiAnalysis` ou `calculated`. Les champs
modifiables dans la fiche sont considérés comme autoritatifs après
enregistrement, y compris lorsqu'ils provenaient initialement d'une suggestion
IA. L'identifiant transmis est la clé primaire existante et permet toujours de
retrouver la fiche courante.

WardrobeGPT, Daily Brief, Agenda et la source de candidats de recommandation
utilisent ce service dans la composition de production. Les signatures
historiques gardent un repli pour les tests et les intégrations existantes,
afin de préserver la compatibilité.

## Prochains sprints

1. Persister une provenance par champ et l'instant de dernière correction
   utilisateur. La présente classification explicite le contrat, mais les
   anciennes lignes ne permettent pas de reconstruire leur historique exact.
2. Ajouter une table de propositions d'analyse versionnées (`model`, prompt,
   confiance, avant/après) avant d'autoriser la réanalyse d'une fiche.
3. Implémenter une validation de fusion qui applique automatiquement les
   valeurs calculées, propose les changements IA et bloque les champs corrigés
   par l'utilisateur jusqu'à confirmation explicite.
4. Faire relire également les tenues depuis la base dans le snapshot central,
   puis supprimer les replis sur contrôleurs lorsque les appelants historiques
   auront migré.
5. Ajouter un mécanisme de budget/taille de prompt pour les très grands
   dressings, sans réintroduire de cache de vérité métier.
