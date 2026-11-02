# Run in PowerShell from the repository root, with Flutter on PATH.
$ErrorActionPreference = 'Stop'
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter was not found on PATH. Install or update Flutter and Android Studio first.'
}
$info = flutter --version
Write-Output $info
Write-Host 'Requires Flutter 3.47+ because dart_pdf_editor 10 requires it.'
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
dart run tool/generate_tie_dye_icons.dart
if ($LASTEXITCODE -ne 0) { throw 'Frog launcher icon generation failed' }
Write-Host 'Dependencies and launcher icons are ready. Run: flutter analyze; flutter test; flutter run'
