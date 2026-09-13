[CmdletBinding()]
param(
  [string]$ContentBundlePath,
  [string]$OutputDirectory,
  # Build flags forwarded to `flutter build apk`.
  #
  # The private test APK is a distribution build: it must embed the bundled default
  # server (`BundledDefaultServerSeeder`), otherwise the installed app starts with no
  # server profile at all and the user has to add the address by hand. The seeder is
  # gated behind `BUNDLED_DEFAULT_SERVER` (see docs/README.md 13.3), and the address
  # default lives in `bundled_default_server_seeder.dart`
  # (`DEFAULT_SERVER_BASE_URL`, overridable with a second `--dart-define`).
  [string[]]$BuildArgs = @(
    '--release',
    '--dart-define=BUNDLED_DEFAULT_SERVER=true'
  )
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$clientDir = Join-Path $root "apps\client_flutter"
$assetPath = Join-Path $clientDir "assets\bundled_content.json"
$gradleInitScript = Join-Path $PSScriptRoot "gradle-repositories.init.gradle"
$gradleUserHome = if ($env:GRADLE_USER_HOME) { $env:GRADLE_USER_HOME } else { Join-Path $env:USERPROFILE ".gradle" }
$installedGradleInitScript = Join-Path $gradleUserHome "init.d\ohmydungeon-repositories.init.gradle"
$defaultBundlePath = Join-Path $root "private-imports\private-test-all-bundle.json"
$ContentBundlePath = if ($ContentBundlePath) { $ContentBundlePath } else { $defaultBundlePath }
$OutputDirectory = if ($OutputDirectory) { $OutputDirectory } else { Join-Path $root "dist\android" }

if (-not (Test-Path -LiteralPath $ContentBundlePath)) {
  throw "Private aggregate bundle was not found. Run scripts/build_private_client.ps1 once or provide -ContentBundlePath."
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
    flutter build apk @BuildArgs
  } finally {
    Pop-Location
  }

  $apk = Join-Path $clientDir "build\app\outputs\flutter-apk\app-release.apk"
  if (-not (Test-Path -LiteralPath $apk)) {
    throw "Flutter did not produce a release APK."
  }

  New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
  $destination = Join-Path $OutputDirectory "ohmydungeon-0.1-private-test.apk"
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
