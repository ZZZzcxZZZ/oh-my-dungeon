$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $root
try {
  Write-Host "==> Installing server dependencies"
  npm --prefix apps/server_nest install

  Write-Host "==> Generating Prisma client"
  npm --prefix apps/server_nest run prisma:generate

  Write-Host "==> Installing Flutter dependencies"
  Push-Location apps/client_flutter
  try {
    flutter pub get
  } finally {
    Pop-Location
  }

  Write-Host "==> Bootstrap complete"
} finally {
  Pop-Location
}