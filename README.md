# WardrobeOS v0.3 — Premium UI

Cette version améliore directement le prototype Android existant.

## Nouveautés
- nouveau tableau de bord premium ;
- animations entre les onglets ;
- thème clair et sombre ;
- dressing avec recherche et filtres réellement interactifs ;
- favoris sur les vêtements ;
- transition Hero vers la fiche vêtement ;
- générateur de tenues avec état vide et résultats simulés ;
- WardrobeGPT avec suggestions et conversation simulée ;
- scanner IA avec validation de la photo, suggestions modifiables et messages
  adaptés aux erreurs de connexion, de clé et de qualité d’image ;
- wishlist avec suppression par glissement ;
- nombreux retours visuels et messages d'action.

## Mise à jour de ton projet existant

Le plus simple :

1. Décompresse cette archive.
2. Copie le nouveau fichier `lib/main.dart` dans ton projet actuel et remplace l'ancien.
3. Copie aussi `pubspec.yaml`.
4. Dans le terminal du projet :

```bash
flutter pub get
flutter run
```

Pendant que l'application est déjà lancée, tu peux remplacer les fichiers puis taper `R` dans le terminal pour un redémarrage complet.

## Projet neuf

Le script `INITIALISER_WARDROBEOS.bat` peut toujours générer le dossier Android si nécessaire.

## Scanner IA

Le scanner conserve d’abord une copie locale de la photo, vérifie son format et
ses dimensions, puis envoie une version réduite à OpenAI Vision. La réponse est
normalisée et validée avant d’être appliquée aux champs encore vides. Aucun
vêtement n’est enregistré sans confirmation de l’utilisateur et la photo
temporaire est supprimée si l’écran est quitté.

La clé OpenAI est saisie dans **Profil** et stockée dans le stockage sécurisé de
l’appareil. Elle ne doit jamais être ajoutée au code, aux journaux ou aux
sauvegardes.

### Checklist de recette du scanner

- [ ] photo nette, éclairée et contenant un seul vêtement ;
- [ ] photo sombre, floue, surexposée ou vêtement trop petit ;
- [ ] photo contenant plusieurs vêtements principaux ;
- [ ] détection de couleur, matière, motif et logo visible ;
- [ ] analyse, correction manuelle, ajout, modification et suppression ;
- [ ] double appui, fermeture pendant l’analyse et rotation de l’écran ;
- [ ] mode hors ligne, délai dépassé, clé absente/invalide et quota atteint ;
- [ ] sauvegarde puis restauration du vêtement et de sa photo ;
- [ ] installation et lancement de l’APK Android de débogage.
