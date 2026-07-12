param(
  [int]$Port = 5173,
  [switch]$ReplaceExisting
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$clientDir = Join-Path $root "apps/client_flutter"
$webDir = Join-Path $clientDir "build/web"

$listeners = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($listeners) {
  if (-not $ReplaceExisting) {
    throw "Port $Port is already in use. Re-run with -ReplaceExisting to stop the existing local preview."
  }

  $listeners |
    Select-Object -ExpandProperty OwningProcess -Unique |
    Where-Object { $_ -ne 0 } |
    ForEach-Object {
      if (Get-Process -Id $_ -ErrorAction SilentlyContinue) {
        Stop-Process -Id $_ -Force
      }
    }
}

$resolvedClientDir = (Resolve-Path $clientDir).Path
if (Test-Path $webDir) {
  $resolvedWebDir = (Resolve-Path $webDir).Path
  if (-not $resolvedWebDir.StartsWith($resolvedClientDir, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove unexpected web build directory: $resolvedWebDir"
  }
  Remove-Item -LiteralPath $resolvedWebDir -Recurse -Force
}

Push-Location $clientDir
try {
  flutter build web --release --pwa-strategy=none
} finally {
  Pop-Location
}

$serviceWorkerPath = Join-Path $webDir "flutter_service_worker.js"
if (Test-Path $serviceWorkerPath) {
  Remove-Item -LiteralPath $serviceWorkerPath -Force
}

if (-not (Test-Path (Join-Path $webDir "index.html"))) {
  throw "Flutter web build did not produce build/web/index.html."
}

Write-Host "Serving Flutter web preview at http://localhost:$Port"
python (Join-Path $PSScriptRoot "static_preview_server.py") --port $Port --directory $webDir
