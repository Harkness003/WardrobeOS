# WardrobeOS — Sprint 4.1, étape 1

## Livré

- Modèle `Garment` enrichi : style, occasion, état, prix/date d’achat, nombre de ports, dernier port, taille, coupe et composition.
- Base SQLite passée en version 2.
- Migration non destructive de la table `garments` : les pièces déjà enregistrées sont conservées.
- Index SQLite supplémentaires pour préparer l’historique d’utilisation.
- Recherche étendue au style et à l’occasion.
- Depuis l’onglet Dressing, le bouton Ajouter propose désormais :
  - Scanner un vêtement ;
  - Ajout manuel.
- Après un scan enregistré, la liste du dressing se recharge automatiquement.

## Vérification

Le code a été contrôlé structurellement dans l’environnement de génération. Flutter/Dart n’y étant pas installé, la commande `flutter analyze` n’a pas pu être exécutée ici.

## Étape suivante

Formulaire complet d’ajout/édition et fiche vêtement enrichie utilisant les nouveaux champs.
