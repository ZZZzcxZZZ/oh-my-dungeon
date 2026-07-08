$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $root
try {
  Write-Host "==> Server lint"
  npm run lint:server

  Write-Host "==> Client analyze"
  npm run analyze:client

  Write-Host "==> Server and client tests"
  npm run test

  if (Get-Command docker -ErrorAction SilentlyContinue) {
    Write-Host "==> Docker Compose config"
    docker compose config | Out-Null
  } else {
    Write-Warning "Docker CLI not found; skipping docker compose config. Install Docker Desktop to validate self-hosting locally."
  }

  Write-Host "==> Check complete"
} finally {
  Pop-Location
}