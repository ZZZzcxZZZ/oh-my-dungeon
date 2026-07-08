$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location (Join-Path $root "apps/client_flutter")
try {
  flutter run
} finally {
  Pop-Location
}