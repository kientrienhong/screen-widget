# One-time setup on Windows: generates the Windows/macOS runner folders with
# `flutter create` (your lib/ and assets/ are left untouched).
# Needs Visual Studio with the "Desktop development with C++" workload.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Host "Flutter is not installed. See https://docs.flutter.dev/get-started/install/windows"
  exit 1
}

flutter config --enable-windows-desktop | Out-Null
flutter create --platforms=macos,windows --project-name screen_widget --org com.harley .
flutter pub get
Write-Host ""
Write-Host "Done. Run the app with:  flutter run -d windows"
Write-Host "Build a release .exe with:  flutter build windows"
