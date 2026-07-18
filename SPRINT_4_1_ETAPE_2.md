# WardrobeOS — Sprint 4.1 Étape 2

## Contenu

- Formulaire d'ajout et d'édition entièrement enrichi.
- Champs pris en charge : style, occasion, état, prix d'achat, date d'achat, taille, coupe, composition et notes.
- Conservation du compteur de ports et de la dernière date de port lors d'une édition.
- Validation du nom et du prix.
- Gestion améliorée de la photo : appareil photo, galerie et suppression.
- Fiche vêtement réorganisée en sections : informations, achat, utilisation et notes.
- Affichage du coût par port lorsque les données le permettent.
- Bouton de port visible mais volontairement non actif avant l'étape 3, qui ajoutera l'historique des ports.

## Test conseillé

1. Lancer `flutter pub get`.
2. Lancer `flutter analyze`.
3. Ajouter une nouvelle pièce avec tous les champs.
4. Fermer puis relancer l'application et vérifier la persistance.
5. Modifier la pièce et vérifier que les informations sont conservées.
