@echo off
setlocal
cd /d "%~dp0"

where flutter >nul 2>nul
if errorlevel 1 (
  echo.
  echo ERREUR : Flutter n'est pas accessible dans le PATH.
  echo Installe Flutter puis relance ce fichier.
  echo Verification conseillee : flutter doctor
  echo.
  pause
  exit /b 1
)

echo [1/4] Verification de Flutter...
flutter --version
if errorlevel 1 goto :error

echo [2/4] Generation des fichiers Android...
flutter create --platforms=android --org com.wardrobeos --project-name wardrobeos .
if errorlevel 1 goto :error

echo [3/4] Recuperation des dependances...
flutter pub get
if errorlevel 1 goto :error

echo [4/4] Verification du projet...
flutter analyze
if errorlevel 1 (
  echo.
  echo Le projet a ete genere, mais Flutter Analyze a signale un probleme.
  echo Ouvre le dossier dans Android Studio pour consulter le detail.
  pause
  exit /b 1
)

echo.
echo WardrobeOS est pret.
echo Dans Android Studio :
echo 1. File ^> Open
echo 2. Selectionne ce dossier WardrobeOS
echo 3. Demarre un emulateur
echo 4. Clique sur Run
echo.
pause
exit /b 0

:error
echo.
echo Une erreur est survenue pendant l'initialisation.
pause
exit /b 1
