$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "Flutter n'est pas accessible dans le PATH." -ForegroundColor Red
    Write-Host "Installe Flutter, lance 'flutter doctor', puis relance ce script."
    exit 1
}

Write-Host "[1/4] Verification de Flutter..."
flutter --version

Write-Host "[2/4] Generation des fichiers Android..."
flutter create --platforms=android --org com.wardrobeos --project-name wardrobeos .

Write-Host "[3/4] Recuperation des dependances..."
flutter pub get

Write-Host "[4/4] Verification du projet..."
flutter analyze

Write-Host ""
Write-Host "WardrobeOS est pret." -ForegroundColor Green
Write-Host "Ouvre ce dossier dans Android Studio, démarre un émulateur, puis clique sur Run."
