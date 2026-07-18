[CmdletBinding()]
param(
  [string]$SourceDirectory,
  [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$SourceDirectory = if ($SourceDirectory) {
  $SourceDirectory
} else {
  Join-Path $root 'private-imports\phb-2024-v2'
}
$OutputPath = if ($OutputPath) {
  $OutputPath
} else {
  Join-Path $root 'private-imports\phb-2024-v2-bundle.json'
}
$manifestPath = Join-Path $SourceDirectory 'manifest.json'
$entriesDirectory = Join-Path $SourceDirectory 'entries'

if (-not (Test-Path -LiteralPath $manifestPath)) {
  throw "Private content manifest was not found: $manifestPath"
}
if (-not (Test-Path -LiteralPath $entriesDirectory)) {
  throw "Private content entries were not found: $entriesDirectory"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$entryFiles = @(Get-ChildItem -LiteralPath $entriesDirectory -Filter '*.json' -File | Sort-Object Name)
if ($entryFiles.Count -ne [int]$manifest.entryCount) {
  throw "Entry count mismatch: manifest=$($manifest.entryCount), files=$($entryFiles.Count)"
}

$entries = foreach ($file in $entryFiles) {
  $entry = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
  $cleanEntry = [ordered]@{}
  foreach ($property in $entry.PSObject.Properties) {
    if (-not $property.Name.StartsWith('_')) {
      $cleanEntry[$property.Name] = $property.Value
    }
  }
  $cleanEntry
}

$bundle = [ordered]@{
  formatVersion = $manifest.formatVersion
  id = $manifest.id
  name = $manifest.name
  version = $manifest.version
  locale = $manifest.locale
  system = $manifest.system
  entryCount = $entries.Count
  entries = $entries
}
$json = $bundle | ConvertTo-Json -Depth 100 -Compress
$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
[System.IO.File]::WriteAllText(
  $OutputPath,
  $json,
  [System.Text.UTF8Encoding]::new($false)
)

$roundTrip = Get-Content -LiteralPath $OutputPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ([int]$roundTrip.entryCount -ne $entryFiles.Count) {
  throw "Generated private content bundle failed round-trip validation"
}

Write-Host "Private content bundle: $OutputPath"
Write-Host "Entries: $($entryFiles.Count)"
