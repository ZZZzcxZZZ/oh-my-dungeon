[CmdletBinding()]
param(
  [string]$Version = "0.1.0",
  [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$OutputDirectory = if ($OutputDirectory) { $OutputDirectory } else { Join-Path $root "dist" }
$packageName = "ohmydungeon-server-linux-$Version"
$staging = Join-Path $OutputDirectory $packageName
$archive = Join-Path $OutputDirectory "$packageName.tar.gz"

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
if (Test-Path -LiteralPath $staging) {
  Remove-Item -LiteralPath $staging -Recurse -Force
}
if (Test-Path -LiteralPath $archive) {
  Remove-Item -LiteralPath $archive -Force
}

New-Item -ItemType Directory -Path $staging -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $root "docker-compose.yml") -Destination $staging
Copy-Item -LiteralPath (Join-Path $root ".env.example") -Destination $staging
Copy-Item -LiteralPath (Join-Path $root ".dockerignore") -Destination $staging
Copy-Item -LiteralPath (Join-Path $root "infra\linux-server\start.sh") -Destination $staging
Copy-Item -LiteralPath (Join-Path $root "infra\linux-server\stop.sh") -Destination $staging
Copy-Item -LiteralPath (Join-Path $root "infra\linux-server\README.md") -Destination $staging

$serverSource = Join-Path $root "apps\server_nest"
$serverDestination = Join-Path $staging "apps\server_nest"
New-Item -ItemType Directory -Path $serverDestination -Force | Out-Null
$serverBuildInputs = @(
  "Dockerfile",
  "package-lock.json",
  "package.json",
  "prisma.config.ts",
  "prisma",
  "src",
  "tsconfig.build.json",
  "tsconfig.json",
  # 离线 Prisma 引擎: Dockerfile 构建期依赖, 必须随包分发.
  "engines"
)
foreach ($input in $serverBuildInputs) {
  Copy-Item -LiteralPath (Join-Path $serverSource $input) -Destination $serverDestination -Recurse -Force
}

$stagedSource = Join-Path $serverDestination "src"
$stagedSourcePath = (Resolve-Path -LiteralPath $stagedSource).Path
$serverDestinationPath = (Resolve-Path -LiteralPath $serverDestination).Path
if (-not $stagedSourcePath.StartsWith("$serverDestinationPath\")) {
  throw "Refusing to remove files outside the package staging directory."
}
Get-ChildItem -LiteralPath $stagedSourcePath -Filter "*.spec.ts" -Recurse |
  ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }

& tar.exe -a -c -f $archive -C $OutputDirectory $packageName
if ($LASTEXITCODE -ne 0) {
  throw "tar.exe failed while creating the Linux server package."
}

$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
Write-Host "Package: $archive"
Write-Host "SHA256: $hash"
