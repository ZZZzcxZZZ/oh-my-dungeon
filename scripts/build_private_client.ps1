<#
.SYNOPSIS
  私人测试构建：把 private-imports/phb-2024-v2/ 注入到客户端 assets 后构建。

.DESCRIPTION
  正式构建硬约束（AGENTS.md）：commercial rulebook 不得 commit/seed/进 build artifact。
  本脚本仅供本地私人测试使用，构建产物不得向第三方分发。

  流程：
    1. 检查 private-imports/phb-2024-v2/{manifest.json, entries/*.json} 存在
    2. 合并为单文件 bundle（manifest + entries 数组）
    3. 备份 apps/client_flutter/assets/bundled_content.json
    4. 用 bundle 覆盖 bundled_content.json
    5. 执行 flutter build <target>
    6. finally 块恢复 bundled_content.json 为 "{}"

  正式构建直接用 `flutter build` 即可，bundled_content.json 保持为 "{}"，
  BundledContentInstaller 会自动跳过空 bundle。

.PARAMETER Target
  构建目标：apk / web / windows / linux / macos。默认 apk。

.PARAMETER BuildArgs
  透传给 flutter build 的额外参数，例如 --release / --debug / --split-per-abi。

.EXAMPLE
  .\scripts\build_private_client.ps1
  .\scripts\build_private_client.ps1 -Target web
  .\scripts\build_private_client.ps1 -Target apk -BuildArgs "--release","--split-per-abi"

.NOTES
  提取资料包请先运行：
    python scripts/extract_phb_2024_v2.py
  输出位于 private-imports/phb-2024-v2/（被 .gitignore 排除）。
#>

[CmdletBinding()]
param(
    [ValidateSet('apk', 'web', 'windows', 'linux', 'macos')]
    [string]$Target = 'apk',

    [string[]]$BuildArgs = @('--release')
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path "$PSScriptRoot/.."
$privateImportDir = Join-Path (Join-Path $repoRoot 'private-imports') 'phb-2024-v2'
$manifestPath = Join-Path $privateImportDir 'manifest.json'
$entriesDir = Join-Path $privateImportDir 'entries'
$privateBundlePath = Join-Path (Join-Path $repoRoot 'private-imports') 'phb-2024-v2-bundle.json'
$bundleBuilderPath = Join-Path $PSScriptRoot 'build-private-content-bundle.ps1'

$clientDir = Join-Path (Join-Path $repoRoot 'apps') 'client_flutter'
$bundledContentPath = Join-Path (Join-Path $clientDir 'assets') 'bundled_content.json'
$backupPath = Join-Path (Join-Path $clientDir 'assets') 'bundled_content.json.public-backup'

function Write-Step([string]$msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

function Write-Done([string]$msg) {
    Write-Host "    OK  $msg" -ForegroundColor Green
}

function Write-Fail([string]$msg) {
    Write-Host "    ERR $msg" -ForegroundColor Red
}

# --------------------------------------------------------------------------- #
# 1. 前置检查
# --------------------------------------------------------------------------- #
Write-Step "前置检查"

if (-not (Test-Path $manifestPath)) {
    Write-Fail "manifest 不存在: $manifestPath"
    Write-Host "    请先运行: python scripts/extract_phb_2024_v2.py"
    exit 1
}
if (-not (Test-Path $entriesDir)) {
    Write-Fail "entries 目录不存在: $entriesDir"
    Write-Host "    请先运行: python scripts/extract_phb_2024_v2.py"
    exit 1
}
if (-not (Test-Path $bundledContentPath)) {
    Write-Fail "目标文件不存在: $bundledContentPath"
    Write-Host "    仓库状态异常，bundled_content.json 应被 git 跟踪为 '{}'"
    exit 1
}

$currentBundle = (Get-Content $bundledContentPath -Raw).Trim()
if ($currentBundle -ne '{}') {
    Write-Fail "bundled_content.json 当前不是 '{}'"
    Write-Host "    上一次私人构建可能未正确恢复，请先执行:"
    Write-Host "      git checkout -- apps/client_flutter/assets/bundled_content.json"
    exit 1
}

Write-Done "前置检查通过"

# --------------------------------------------------------------------------- #
# 2. 合并散文件为单文件 bundle
# --------------------------------------------------------------------------- #
Write-Step "合并 manifest + entries/*.json 为单文件 bundle"

& $bundleBuilderPath -SourceDirectory $privateImportDir -OutputPath $privateBundlePath
if ($LASTEXITCODE -ne 0) {
    throw "私人资料包聚合失败"
}
$bundleJson = Get-Content -LiteralPath $privateBundlePath -Raw -Encoding UTF8
$bundle = $bundleJson | ConvertFrom-Json
Write-Done "合并 $($bundle.entryCount) 条条目"

# --------------------------------------------------------------------------- #
# 3. 备份当前 bundled_content.json
# --------------------------------------------------------------------------- #
Write-Step "备份 bundled_content.json"

Copy-Item -Path $bundledContentPath -Destination $backupPath -Force
Write-Done "备份到 $backupPath"

# --------------------------------------------------------------------------- #
# 4. 注入 bundle + 构建 + 恢复（try/finally 保证恢复）
# --------------------------------------------------------------------------- #
$buildSuccess = $false
try {
    Write-Step "注入 bundle 到 bundled_content.json"
    [System.IO.File]::WriteAllText($bundledContentPath, $bundleJson, [System.Text.UTF8Encoding]::new($false))
    $injectedSize = (Get-Item $bundledContentPath).Length
    Write-Done "已注入 $([math]::Round($injectedSize / 1MB, 2)) MB"

    Write-Step "执行 flutter build $Target $($BuildArgs -join ' ')"
    Push-Location $clientDir
    try {
        & flutter build $Target @BuildArgs
        if ($LASTEXITCODE -eq 0) {
            $buildSuccess = $true
            Write-Done "flutter build 成功"
        } else {
            Write-Fail "flutter build 失败 (exit $LASTEXITCODE)"
        }
    }
    finally {
        Pop-Location
    }
}
finally {
    # ----------------------------------------------------------------------- #
    # 5. 恢复 bundled_content.json 为 '{}'
    # ----------------------------------------------------------------------- #
    Write-Step "恢复 bundled_content.json 为 '{}'"
    if (Test-Path $backupPath) {
        Copy-Item -Path $backupPath -Destination $bundledContentPath -Force
        Remove-Item -Path $backupPath -Force
        Write-Done "已恢复"
    } else {
        # 兜底：备份丢失时强制写 '{}'
        [System.IO.File]::WriteAllText($bundledContentPath, '{}', [System.Text.UTF8Encoding]::new($false))
        Write-Done "备份丢失，已强制写入 '{}'"
    }

    # 校验 git 状态干净
    Push-Location $repoRoot
    try {
        $gitDiff = & git status --short -- apps/client_flutter/assets/bundled_content.json
        if ($gitDiff) {
            Write-Fail "恢复后 git 仍有改动，请手动执行: git checkout -- apps/client_flutter/assets/bundled_content.json"
            Write-Host "    git status 输出: $gitDiff" -ForegroundColor Yellow
        } else {
            Write-Done "git 状态干净"
        }
    }
    finally {
        Pop-Location
    }
}

# --------------------------------------------------------------------------- #
# 6. 输出构建产物路径
# --------------------------------------------------------------------------- #
if ($buildSuccess) {
    Write-Step "构建完成"
    $buildDir = Join-Path $clientDir 'build'
    switch ($Target) {
        'apk' {
            $apkPath = Join-Path (Join-Path (Join-Path $buildDir 'app') 'outputs') 'flutter-apk'
            Write-Host "    APK 路径: $(Join-Path $apkPath 'app-release.apk')" -ForegroundColor Green
        }
        'web' {
            Write-Host "    Web 路径: $(Join-Path $buildDir 'web')" -ForegroundColor Green
        }
        'windows' {
            $winPath = Join-Path (Join-Path (Join-Path $buildDir 'windows') 'x64') 'runner'
            Write-Host "    Windows 路径: $(Join-Path $winPath 'Release')" -ForegroundColor Green
        }
        default {
            Write-Host "    构建目录: $buildDir" -ForegroundColor Green
        }
    }
    Write-Host ""
    Write-Host "    注意：本构建产物包含商业版权内容（玩家手册 2024 私有提取），" -ForegroundColor Yellow
    Write-Host "          仅限本地测试，不得向第三方分发。" -ForegroundColor Yellow
} else {
    throw "flutter build $Target failed"
}
