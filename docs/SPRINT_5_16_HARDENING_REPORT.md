# Sprint 5.16 — rapport de durcissement et d’intégration

## Périmètre et méthode

L’audit a porté sur les modèles persistés, le scanner OpenAI, WardrobeGPT, la
météo, les contrôleurs et les écrans. Il privilégie les suppressions sûres et
les protections aux frontières (réseau, JSON et base locale). Aucun comportement
métier ni dépendance n’a été ajouté.

## Architecture

### Suppressions et responsabilités

- L’ancienne pile WardrobeGPT (`builders`, anciens modèles de contexte/requête/
  réponse et `WardrobeGptService`) a été supprimée. Elle n’était plus appelée par
  l’application et simulait une réponse sans interroger le fournisseur. La pile
  active reste `AssistantService` → contexte structuré → outils/recommandation →
  prompt → `LlmProvider`.
- Les trois tests qui validaient exclusivement cette implémentation morte ont été
  supprimés avec elle. Les tests de la pile active restent en place.
- Le parsing IA demeure concentré dans `GarmentAnalysisResult`; les widgets ne
  reconstruisent pas les métadonnées Expert.

### Regard critique

`AssistantService` conserve encore l’état du dernier intent, des derniers outils
et candidats. Cet état facilite l’affichage actuel, mais couple une requête à la
suivante et compliquerait deux conversations simultanées. À terme, un résultat
de génération immuable serait plus simple qu’un service stateful.

## Performance et mémoire

- Le scanner ne journalise plus le corps HTTP ni le JSON complet. Cela évite une
  copie console coûteuse, la fuite potentielle de données d’image/analyse et le
  bruit en production.
- Le cache météo utilise un instantané local cohérent et retourne directement le
  résultat calculé, sans assertion de nullité.
- L’appel météo a désormais une limite de 15 secondes : une requête réseau ne
  peut plus rester suspendue indéfiniment.
- Le client HTTP créé par le scanner possède déjà `close()`. Son cycle de vie est
  correctement relié au `dispose` du scanner, mais les clients météo et LLM ne
  partagent pas encore un contrat commun de fermeture. C’est une dette mémoire à
  traiter sans multiplier les méthodes ad hoc.

## Scanner

- Les traces temporaires de statut, réponse brute et résultat parsé ont été
  retirées.
- Les erreurs HTTP transitoires et timeouts restent retentés au plus selon
  `maxRetries`; les erreurs métier et JSON ne déclenchent pas un second appel
  OpenAI inutile.
- La préparation de la nouvelle image reste effectuée une fois avant la boucle de
  retry. Les photos précédentes ne sont pas retraitées à chaque retry.

### Limites constatées

Le payload multi-photo réencode toutes les photos historiques à chaque appel.
C’est nécessaire avec l’API stateless actuelle, mais devient coûteux sur une
longue conversation. Avant d’ajouter un cache complexe, il faut limiter le
nombre de vues conservées selon leur apport réel (face, dos, étiquette) et
mesurer la taille des requêtes.

## WardrobeGPT

- Deux chaînes parallèles de contexte et de prompt coexistaient. La chaîne factice
  a été supprimée; la chaîne active centralise le contexte, les outils, la
  recommandation et le streaming.
- La météo et le calendrier sont déjà récupérés avec une dégradation gracieuse :
  leur indisponibilité n’empêche pas une réponse de l’assistant.
- `generateMessage` concatène encore tous les fragments du streaming. C’est
  acceptable pour les consommateurs non streamés, mais peut doubler la mémoire
  d’une réponse longue. Les interfaces devraient privilégier le stream et ne
  garder cette méthode que pour les usages qui exigent une chaîne complète.

## Modèles et JSON

- `Garment.fromMap` ignore maintenant les colonnes texte de type inattendu, les
  listes JSON invalides et les dates invalides. Les champs obligatoires absents
  reçoivent une valeur neutre, ce qui permet de charger une ancienne ligne
  partielle sans crash.
- `Outfit`, `OutfitItem` et `WearHistory` tolèrent les valeurs absentes, les types
  numériques SQLite compatibles et les dates invalides.
- L’époque Unix sert uniquement de sentinelle stable pour une date persistée
  obligatoire mais illisible. Elle évite de fabriquer une date « maintenant »
  différente à chaque lecture.
- La réponse météo vérifie que la racine JSON est bien un objet avant tout cast.

### Dette restante

- `WeatherData.fromOpenMeteoJson` est volontairement strict sur les champs exigés
  par le fournisseur. L’assistant absorbe l’échec, mais l’écran météo doit
  continuer à afficher son état d’erreur plutôt que des mesures inventées.
- `DatabaseService.importData` contient encore des assertions de présence sur les
  collections de sauvegarde. Le service de restauration valide actuellement le
  document avant cet appel, mais la frontière serait plus robuste si le dépôt
  acceptait directement des listes vides.
- Plusieurs `!` restent dans les widgets après des gardes locales. Ils ne sont pas
  tous dangereux, mais remplacer progressivement les lectures répétées par des
  variables promues rendrait les invariants plus lisibles.

## UX et audit fonctionnel

### Parcours

Le parcours scanner est déjà orienté vers une seule photo et ne demande une vue
supplémentaire que lorsqu’elle améliore un champ ciblé. Aucun écran n’a été
supprimé sans données d’usage : confondre simplification et retrait arbitraire
aurait dégradé la compatibilité.

### Informations à questionner

- Les champs `composition`, matière estimée et conseils d’entretien se
  chevauchent. La composition déclarée par l’utilisateur/étiquette doit rester
  la source de vérité; l’estimation IA ne devrait être affichée que comme telle,
  sans demander une deuxième saisie.
- Saison, plage de température, pluie et chaleur décrivent le même axe
  d’utilisation. Les températures et compatibilités peuvent être proposées par
  l’IA puis corrigées, plutôt que toutes exigées manuellement.
- Style, style principal et styles secondaires sont historiquement redondants.
  Une migration progressive vers principal + secondaires permettrait de ne plus
  stocker `style`, tout en continuant à le lire pour les anciennes fiches.
- `descriptionIA`, résumé stylistique et verdict risquent de répéter le même
  contenu. Les écrans devraient vérifier par mesure d’usage lequel aide vraiment
  la décision avant de conserver les trois.
- Le prix, la taille, la date d’achat et les notes ne sont pas déductibles de
  façon fiable depuis une photo et doivent rester facultatifs, jamais bloquants.

## Opportunités proposées

1. Introduire un unique codec tolérant pour les primitives SQLite (texte, nombre,
   booléen et date) puis l’utiliser dans tous les modèles; éviter toutefois une
   hiérarchie de sérialisation abstraite.
2. Rendre le résultat `AssistantService` immuable (texte/stream, intent, outils,
   candidats) afin de supprimer son état de « dernière requête ».
3. Mesurer le taux d’utilisation des métadonnées Expert avant de supprimer des
   champs. Une suppression guidée par intuition risquerait de perdre une donnée
   difficile à recalculer.
4. Centraliser la propriété et la fermeture des clients HTTP au niveau de la
   composition de l’application.
5. Ajouter, lors d’un prochain sprint autorisant les tests, des cas de propriétés
   manquantes, mauvais types, JSON tronqué, timeout et annulation pendant une
   réanalyse. Le durcissement ne sera complet qu’avec ces tests de frontières.
