param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]] $ComposeArgs
)

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

  throw "Docker CLI not found. Install Docker Desktop or add docker to PATH."
}

if (-not $ComposeArgs -or $ComposeArgs.Count -eq 0) {
  throw "Missing docker compose arguments."
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$dockerCommand = Get-DockerCommand

Push-Location $root
try {
  & $dockerCommand compose @ComposeArgs
} finally {
  Pop-Location
}
