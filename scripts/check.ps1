$ErrorActionPreference = "Stop"

function Get-DockerCommand {
  $docker = Get-Command docker -ErrorAction SilentlyContinue
  if ($docker) {
    return $docker.Source
  }

  $defaultDockerPath = "C:\Program Files\Docker\Docker\resources\bin\docker.exe"
  if (Test-Path -LiteralPath $defaultDockerPath) {
    return $defaultDockerPath
  }

  return $null
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $root
try {
  Write-Host "==> Server lint"
  npm run lint:server

  Write-Host "==> Client Drift codegen"
  Push-Location (Join-Path $root "apps/client_flutter")
  try {
    dart run build_runner build --delete-conflicting-outputs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  } finally {
    Pop-Location
  }

  Write-Host "==> Client analyze"
  npm run analyze:client

  Write-Host "==> Server and client tests"
  npm run test

  $dockerCommand = Get-DockerCommand
  if ($dockerCommand) {
    Write-Host "==> Docker Compose config"
    & $dockerCommand compose config | Out-Null
  } else {
    Write-Warning "Docker CLI not found; skipping docker compose config. Install Docker Desktop to validate self-hosting locally."
  }

  Write-Host "==> Check complete"
} finally {
  Pop-Location
}