[CmdletBinding()]
param(
  [string]$ContentBundlePath,
  [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$clientDir = Join-Path $root "apps\client_flutter"
$assetPath = Join-Path $clientDir "assets\bundled_content.json"
$gradleInitScript = Join-Path $PSScriptRoot "gradle-repositories.init.gradle"
$gradleUserHome = if ($env:GRADLE_USER_HOME) { $env:GRADLE_USER_HOME } else { Join-Path $env:USERPROFILE ".gradle" }
$installedGradleInitScript = Join-Path $gradleUserHome "init.d\dnd-table-tool-repositories.init.gradle"
$defaultBundlePath = Join-Path $root "private-imports\phb-2024-v2-bundle.json"
$ContentBundlePath = if ($ContentBundlePath) { $ContentBundlePath } else { $defaultBundlePath }
$OutputDirectory = if ($OutputDirectory) { $OutputDirectory } else { Join-Path $root "dist\android" }

if (-not (Test-Path -LiteralPath $ContentBundlePath)) {
  $bundleBuilder = Join-Path $PSScriptRoot "build-private-content-bundle.ps1"
  & $bundleBuilder -OutputPath $ContentBundlePath
  if ($LASTEXITCODE -ne 0) {
    throw "Private content bundle generation failed"
  }
}

if (-not (Test-Path -LiteralPath $assetPath)) {
  throw "Bundled content placeholder was not found: $assetPath"
}

if (-not (Test-Path -LiteralPath $gradleInitScript)) {
  throw "Gradle repository initialization script was not found: $gradleInitScript"
}

$originalAsset = [System.IO.File]::ReadAllBytes($assetPath)
$hadExistingGradleInitScript = Test-Path -LiteralPath $installedGradleInitScript
$originalGradleInitScript = if ($hadExistingGradleInitScript) {
  [System.IO.File]::ReadAllBytes($installedGradleInitScript)
} else {
  $null
}
try {
  Copy-Item -LiteralPath $ContentBundlePath -Destination $assetPath -Force
  New-Item -ItemType Directory -Path (Split-Path -Parent $installedGradleInitScript) -Force | Out-Null
  Copy-Item -LiteralPath $gradleInitScript -Destination $installedGradleInitScript -Force

  Push-Location $clientDir
  try {
    flutter build apk --release
  } finally {
    Pop-Location
  }

  $apk = Join-Path $clientDir "build\app\outputs\flutter-apk\app-release.apk"
  if (-not (Test-Path -LiteralPath $apk)) {
    throw "Flutter did not produce a release APK."
  }

  New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
  $destination = Join-Path $OutputDirectory "dnd-table-tool-0.1-private-test.apk"
  Copy-Item -LiteralPath $apk -Destination $destination -Force
  $hash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
  Write-Host "APK: $destination"
  Write-Host "SHA256: $hash"
} finally {
  [System.IO.File]::WriteAllBytes($assetPath, $originalAsset)
  if ($hadExistingGradleInitScript) {
    [System.IO.File]::WriteAllBytes($installedGradleInitScript, $originalGradleInitScript)
  } elseif (Test-Path -LiteralPath $installedGradleInitScript) {
    Remove-Item -LiteralPath $installedGradleInitScript -Force
  }
}
