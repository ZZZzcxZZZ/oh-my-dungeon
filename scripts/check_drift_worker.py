#!/usr/bin/env python3
"""校验 drift WASM worker 编译产物没有和源码 / 依赖版本漂移。

背景
----
``apps/client_flutter/web/drift_worker.dart.js`` 是
``dart compile js -O4 web/drift_worker.dart`` 的产物。Flutter web 构建只会处理
``lib/main.dart`` 这一个入口，**不会**自动编译 ``web/`` 下的额外入口，所以 drift
官方要求把该产物一并提交，否则 web 端数据库不可用。

风险：``web/drift_worker.dart`` 与 ``pubspec.lock`` 里的 drift 版本都可能被改动或
升级，而没人重新编译那个 JS。两者一旦漂移，只有运行期才会炸，且没有任何测试会发现。

方案：用清单 ``web/drift_worker.manifest.json`` 把「入口源码 + drift 版本 + 产物
哈希 / 大小」钉在一起。重新编译很慢且跨 SDK 不稳定，不适合放进测试；逐字节比对
同样如此。清单校验只需要纯标准库、毫秒级，可以随时跑。

用法
----
    python3 scripts/check_drift_worker.py            # 校验，漂移则退出码 1
    python3 scripts/check_drift_worker.py --update --sdk-version 3.11.1

一般不需要手动传 ``--update``：``scripts/rebuild-drift-worker.ps1`` 重编译完成后会
调用它刷新清单。
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
CLIENT_ROOT = REPO_ROOT / "apps" / "client_flutter"
WEB_ROOT = CLIENT_ROOT / "web"
MANIFEST_PATH = WEB_ROOT / "drift_worker.manifest.json"
PUBSPEC_LOCK_PATH = CLIENT_ROOT / "pubspec.lock"

#: 重新生成产物与清单的唯一入口（错误信息里直接告诉用户跑这一条）。
REBUILD_COMMAND = "pwsh -File scripts/rebuild-drift-worker.ps1"

EXPECTED_ENTRYPOINT = "web/drift_worker.dart"
DEFAULT_OUTPUT = "web/drift_worker.dart.js"

REQUIRED_FIELDS = (
    "entrypoint",
    "entrypointSha256",
    "driftVersion",
    "driftWorkerSdk",
    "outputSha256",
    "outputBytes",
)

#: ``dart compile js -O4`` 会压缩掉 ``WasmDatabase.workerMainForOpen`` 这类符号名，
#: 所以不能直接 grep「入口符号」。这里改用 drift 源码
#: (``drift/lib/src/web/wasm_setup/shared.dart``) 里会原样出现在产物中的字符串常量
#: 作为「这确实是 drift 的 wasm worker」的证据。只要命中任意一个即通过，避免 drift
#: 重命名单个常量时误报。
DRIFT_WORKER_MARKERS = (
    "drift_db",  # OPFS 根目录名
    "_drift_feature_detection",  # OPFS 能力探测文件名
    "drift_mock_db",  # IndexedDB 能力探测库名
    "drift.runtime.cancellation",  # drift 内部调试名
)

#: dart2js 生成的入口调用，证明这是编译出来的 Dart 入口而不是占位文件。
DART2JS_RUNNER_MARKER = "dartMainRunner"

#: 占位 / 截断文件的体积下限。
MIN_OUTPUT_BYTES = 100 * 1024


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_drift_version(lock_path: Path | None = None) -> str | None:
    """从 ``pubspec.lock`` 里取出 ``drift``（不是 ``drift_dev``）的版本。"""
    lock_path = Path(lock_path or PUBSPEC_LOCK_PATH)
    if not lock_path.is_file():
        return None

    current: str | None = None
    version: str | None = None
    for line in lock_path.read_text(encoding="utf-8").splitlines():
        header = re.match(r"^  ([A-Za-z0-9_]+):\s*$", line)
        if header:
            if current == "drift" and version:
                return version
            current = header.group(1)
            version = None
            continue
        if current == "drift":
            found = re.match(r'^    version:\s*"?([^"\s]+)"?\s*$', line)
            if found:
                version = found.group(1)
    if current == "drift" and version:
        return version
    return None


def verify(
    manifest_path: Path | None = None,
    client_root: Path | None = None,
    lock_path: Path | None = None,
) -> list[str]:
    """逐项校验清单；返回问题列表，空列表表示一致。"""
    manifest_path = Path(manifest_path or MANIFEST_PATH)
    client_root = Path(client_root or CLIENT_ROOT)
    lock_path = Path(lock_path or PUBSPEC_LOCK_PATH)

    if not manifest_path.is_file():
        return [f"清单不存在：{manifest_path}；请运行 `{REBUILD_COMMAND}` 生成"]

    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        return [f"清单不是合法 JSON（{error}）；请运行 `{REBUILD_COMMAND}` 重新生成"]

    if not isinstance(manifest, dict):
        return [f"清单根节点必须是对象；请运行 `{REBUILD_COMMAND}` 重新生成"]

    missing = [field for field in REQUIRED_FIELDS if field not in manifest]
    if missing:
        return [
            "清单缺少字段：" + ", ".join(missing) + f"；请运行 `{REBUILD_COMMAND}` 刷新"
        ]

    problems: list[str] = []

    # --- 入口源码 ---------------------------------------------------------
    entrypoint_rel = manifest["entrypoint"]
    if entrypoint_rel != EXPECTED_ENTRYPOINT:
        problems.append(
            f"清单 entrypoint 是 {entrypoint_rel!r}，期望 {EXPECTED_ENTRYPOINT!r}"
        )
    entrypoint = client_root / str(entrypoint_rel)
    if not entrypoint.is_file():
        problems.append(f"入口源码不存在：{entrypoint}")
    else:
        actual = sha256_file(entrypoint)
        if actual != manifest["entrypointSha256"]:
            problems.append(
                "入口源码已改动："
                f"{entrypoint_rel} 的 sha256 现在是 {actual}，"
                f"清单记录的是 {manifest['entrypointSha256']}"
            )

    # --- 编译产物 ---------------------------------------------------------
    output_rel = str(manifest.get("output", DEFAULT_OUTPUT))
    output = client_root / output_rel
    if not output.is_file():
        problems.append(f"编译产物不存在：{output}；请运行 `{REBUILD_COMMAND}` 生成")
    else:
        size = output.stat().st_size
        if size <= MIN_OUTPUT_BYTES:
            problems.append(
                f"编译产物过小（{size} 字节 ≤ {MIN_OUTPUT_BYTES}），疑似占位文件："
                f"{output_rel}；请运行 `{REBUILD_COMMAND}` 重新生成"
            )
        if size != manifest["outputBytes"]:
            problems.append(
                f"编译产物大小已变：{output_rel} 现在是 {size} 字节，"
                f"清单记录的是 {manifest['outputBytes']}"
            )
        actual = sha256_file(output)
        if actual != manifest["outputSha256"]:
            problems.append(
                f"编译产物哈希已变：{output_rel} 的 sha256 现在是 {actual}，"
                f"清单记录的是 {manifest['outputSha256']}"
            )

        # 产物里必须能找到 drift wasm worker 的真实证据。
        text = output.read_text(encoding="utf-8", errors="replace")
        matched = [marker for marker in DRIFT_WORKER_MARKERS if marker in text]
        if not matched:
            problems.append(
                "编译产物里找不到任何 drift wasm worker 标记（"
                + ", ".join(DRIFT_WORKER_MARKERS)
                + f"）；{output_rel} 可能不是 drift 的 worker 产物"
            )
        if DART2JS_RUNNER_MARKER not in text:
            problems.append(
                f"编译产物里找不到 dart2js 入口标记 {DART2JS_RUNNER_MARKER!r}；"
                f"{output_rel} 可能不是编译产物"
            )

    # --- drift 版本 -------------------------------------------------------
    lock_version = read_drift_version(lock_path)
    if lock_version is None:
        problems.append(f"无法从 {lock_path.name} 里解析出 drift 版本")
    elif lock_version != manifest["driftVersion"]:
        problems.append(
            f"drift 版本漂移：pubspec.lock 是 {lock_version}，"
            f"清单记录的产物是用 {manifest['driftVersion']} 编译的"
        )

    # --- Dart SDK（只校验类型；null 表示生成时未能确定） -------------------
    sdk = manifest["driftWorkerSdk"]
    if sdk is not None and not isinstance(sdk, str):
        problems.append(f"driftWorkerSdk 必须是字符串或 null，实际是 {sdk!r}")

    # --- 可选交叉校验：.deps 里记录的 drift 版本 -------------------------
    deps = output.with_name(output.name + ".deps")
    if deps.is_file():
        deps_text = deps.read_text(encoding="utf-8", errors="replace")
        found = re.findall(r"pub\.dev[/\\]drift-([0-9][0-9A-Za-z.\-+]*)", deps_text)
        if found and manifest["driftVersion"] not in found:
            problems.append(
                f"{deps.name} 记录的 drift 版本是 {sorted(set(found))}，"
                f"与清单 {manifest['driftVersion']} 不一致"
            )

    return problems


def _build_manifest(sdk_version: str | None) -> dict:
    entrypoint = CLIENT_ROOT / EXPECTED_ENTRYPOINT
    output = CLIENT_ROOT / DEFAULT_OUTPUT
    if not entrypoint.is_file():
        raise SystemExit(f"入口源码不存在：{entrypoint}")
    if not output.is_file():
        raise SystemExit(f"编译产物不存在：{output}；请先运行 dart compile js")

    lock_version = read_drift_version()
    if lock_version is None:
        raise SystemExit(f"无法从 {PUBSPEC_LOCK_PATH} 里解析出 drift 版本")

    if sdk_version is None and MANIFEST_PATH.is_file():
        try:
            previous = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
            sdk_version = previous.get("driftWorkerSdk")
        except (json.JSONDecodeError, AttributeError):
            sdk_version = None

    return {
        "entrypoint": EXPECTED_ENTRYPOINT,
        "entrypointSha256": sha256_file(entrypoint),
        "driftVersion": lock_version,
        "driftWorkerSdk": sdk_version,
        "output": DEFAULT_OUTPUT,
        "outputSha256": sha256_file(output),
        "outputBytes": output.stat().st_size,
        "rebuildCommand": REBUILD_COMMAND,
    }


def write_manifest(sdk_version: str | None = None) -> None:
    payload = _build_manifest(sdk_version)
    MANIFEST_PATH.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--update",
        action="store_true",
        help="按当前源码与产物刷新清单（重编译脚本会调用）",
    )
    parser.add_argument(
        "--sdk-version",
        default=None,
        help="生成该 JS 的 Dart SDK 版本，写入清单的 driftWorkerSdk",
    )
    args = parser.parse_args(argv)

    if args.update:
        write_manifest(args.sdk_version)
        print(f"已刷新清单：{MANIFEST_PATH.relative_to(REPO_ROOT)}")

    problems = verify()
    if problems:
        print("drift worker 清单校验失败：", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        print(f"\n修复：{REBUILD_COMMAND}", file=sys.stderr)
        return 1

    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    print("drift worker 清单校验通过：")
    print(f"  入口层        {manifest['entrypoint']}")
    print(f"  drift 版本    {manifest['driftVersion']}")
    print(f"  Dart SDK      {manifest['driftWorkerSdk'] or '未记录'}")
    print(f"  产物          {manifest.get('output', DEFAULT_OUTPUT)}"
          f"（{manifest['outputBytes']} 字节，sha256 {manifest['outputSha256'][:12]}…）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
