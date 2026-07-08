$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location (Join-Path $root "apps/server_nest")
try {
  npm run start:dev
} finally {
  Pop-Location
}