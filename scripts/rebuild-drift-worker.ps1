<#
.SYNOPSIS
    重新编译 drift 的 WASM worker，并刷新 web/drift_worker.manifest.json。

.DESCRIPTION
    apps/client_flutter/web/drift_worker.dart.js 是 `dart compile js` 的产物，必须提交
    （Flutter web 构建不会自动编译 web/ 下的额外入口）。改动下面任何一处都必须跑本脚本：

      - apps/client_flutter/web/drift_worker.dart
      - pubspec.lock 里的 drift 版本（升级 drift / drift_flutter）

    本脚本做三件事：
      1. 用 `dart compile js -O4` 重新编译到临时目录（保持输出文件名不变，
         这样产物里的 sourceMappingURL 与提交版一致），再覆盖 web/ 下的 .js/.map/.deps；
      2. 调用 scripts/check_drift_worker.py --update 刷新清单（sha256 / 大小 / drift 版本 / Dart SDK）；
      3. 打印摘要。

    含中文注释，因此本文件必须保存为带 UTF-8 BOM 的 UTF-8（见 docs/README.md §14.3），
    否则 Windows PowerShell 5.1 会按 ANSI 解析并报错。

.EXAMPLE
    pwsh -File scripts/rebuild-drift-worker.ps1
    pwsh -File scripts/rebuild-drift-worker.ps1 -DartExe 'C:\Flutter\flutter\bin\cache\dart-sdk\bin\dart.exe'
#>
[CmdletBinding()]
param(
    # 显式指定 dart 可执行文件；默认依次从 PATH 上的 dart / flutter 推导。
    [string]$DartExe = ''
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$clientRoot = Join-Path $repoRoot 'apps\client_flutter'
$webRoot = Join-Path $clientRoot 'web'
$workerSource = Join-Path $webRoot 'drift_worker.dart'
$manifestPath = Join-Path $webRoot 'drift_worker.manifest.json'
$checkScript = Join-Path $PSScriptRoot 'check_drift_worker.py'

# 产物文件族：编译器会同时写出 .js / .js.map / .js.deps。
$artifactNames = @(
    'drift_worker.dart.js',
    'drift_worker.dart.js.map',
    'drift_worker.dart.js.deps'
)

function Resolve-DartExe {
    param([string]$Explicit)

    if ($Explicit) {
        if (Test-Path $Explicit) { return $Explicit }
        throw "指定的 Dart 可执行文件不存在：$Explicit"
    }

    $dart = Get-Command dart -ErrorAction SilentlyContinue
    if ($dart) { return $dart.Source }

    $flutter = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutter) {
        # <flutter>\bin\flutter.bat -> <flutter>\bin\cache\dart-sdk\bin\dart.exe
        $flutterRoot = Split-Path -Parent (Split-Path -Parent $flutter.Source)
        $candidate = Join-Path $flutterRoot 'bin\cache\dart-sdk\bin\dart.exe'
        if (Test-Path $candidate) { return $candidate }
    }

    foreach ($candidate in @('C:\Flutter\flutter\bin\cache\dart-sdk\bin\dart.exe')) {
        if (Test-Path $candidate) { return $candidate }
    }

    throw '找不到 Dart SDK。请安装 Flutter/Dart，或用 -DartExe 指定 dart 路径。'
}

function Resolve-PythonCommand {
    # 仓库脚本在 Windows 上用 python，在 WSL/CI 上用 python3；两者都探测。
    # 用 `-c "import sys"` 排除 Windows 应用商店的占位别名。
    foreach ($candidate in @('python3', 'python')) {
        $command = Get-Command $candidate -ErrorAction SilentlyContinue
        if (-not $command) { continue }
        $null = & $command.Source -c 'import sys' 2>&1
        if ($LASTEXITCODE -eq 0) { return $command.Source }
    }
    throw '找不到可用的 Python（需要 python3 或 python）来刷新清单。'
}

if (-not (Test-Path $workerSource)) {
    throw "入口源码不存在：$workerSource"
}

$dart = Resolve-DartExe -Explicit $DartExe

# 编译到临时目录，且输出文件名与最终一致：dart2js 用输出文件名写 sourceMappingURL，
# 直接输出成 xxx.new.js 会让提交版多出 `.new` 字样。
$staging = Join-Path $clientRoot '.dart_tool\drift_worker_rebuild'
if (Test-Path $staging) { Remove-Item -Recurse -Force $staging }
New-Item -ItemType Directory -Force -Path $staging | Out-Null

try {
    Write-Host "编译 $workerSource ..." -ForegroundColor Cyan
    & $dart compile js -O4 $workerSource -o (Join-Path $staging 'drift_worker.dart.js')
    if ($LASTEXITCODE -ne 0) {
        throw "dart compile js 失败（退出码 $LASTEXITCODE）"
    }

    $copied = @()
    foreach ($name in $artifactNames) {
        $from = Join-Path $staging $name
        if (Test-Path $from) {
            Copy-Item -Force $from (Join-Path $webRoot $name)
            $copied += $name
        }
    }
}
finally {
    # 无论成功失败都清掉临时目录，工作树里不留垃圾。
    if (Test-Path $staging) { Remove-Item -Recurse -Force $staging }
}

# 解析 Dart SDK 版本写入清单（`dart --version` 走 stderr）。
$sdkVersion = $null
$versionText = (& $dart --version 2>&1 | Out-String)
if ($versionText -match 'Dart SDK version:\s*([0-9][0-9A-Za-z.\-+]*)') {
    $sdkVersion = $Matches[1]
}

$python = Resolve-PythonCommand
$checkArgs = @($checkScript, '--update')
if ($sdkVersion) { $checkArgs += @('--sdk-version', $sdkVersion) }

Write-Host '刷新清单 ...' -ForegroundColor Cyan
& $python @checkArgs
if ($LASTEXITCODE -ne 0) {
    throw "刷新 / 校验清单失败（退出码 $LASTEXITCODE）"
}

$manifest = Get-Content -Raw -Encoding UTF8 $manifestPath | ConvertFrom-Json
Write-Host ''
Write-Host 'drift worker 重新生成完成：' -ForegroundColor Green
Write-Host ("  入口层      {0}" -f $manifest.entrypoint)
Write-Host ("  drift 版本  {0}" -f $manifest.driftVersion)
Write-Host ("  Dart SDK    {0}" -f $manifest.driftWorkerSdk)
Write-Host ("  产物        {0}（{1} 字节，sha256 {2}…）" -f $manifest.output, $manifest.outputBytes, $manifest.outputSha256.Substring(0, 12))
Write-Host ("  清单        {0}" -f (Resolve-Path -Relative $manifestPath))
Write-Host ("  已刷新      {0}" -f ($copied -join ', '))
