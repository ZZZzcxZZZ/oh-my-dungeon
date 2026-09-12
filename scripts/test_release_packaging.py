import hashlib
import unittest
import json
import tempfile
from pathlib import Path

from scripts.build_private_core_bundle import merge_private_bundles
from scripts.check_drift_worker import REQUIRED_FIELDS, verify as verify_drift_worker


ROOT = Path(__file__).resolve().parents[1]


class ReleasePackagingTest(unittest.TestCase):
    def test_private_core_bundle_rebases_ids_and_references(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            first = root / "first.json"
            second = root / "second.json"
            output = root / "core.json"
            first.write_text(
                json.dumps(
                    {
                        "formatVersion": 3,
                        "id": "legacy-a",
                        "name": "A",
                        "version": "1",
                        "locale": "zh-CN",
                        "system": "dnd5e-2024",
                        "entryCount": 1,
                        "entries": [
                            {
                                "id": "legacy-a:class/example",
                                "type": "class",
                                "slug": "example",
                                "name": "Example",
                                "body": [
                                    {
                                        "type": "entryLink",
                                        "targetId": "legacy-b:feat/example",
                                    }
                                ],
                                "relations": [
                                    {
                                        "type": "grants",
                                        "targetId": "legacy-b:feat/example",
                                    }
                                ],
                                "revision": 1,
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )
            second.write_text(
                json.dumps(
                    {
                        "formatVersion": 3,
                        "id": "legacy-b",
                        "name": "B",
                        "version": "1",
                        "locale": "zh-CN",
                        "system": "dnd5e-2024",
                        "entryCount": 1,
                        "entries": [
                            {
                                "id": "legacy-b:feat/example",
                                "type": "feat",
                                "slug": "example",
                                "name": "Feat",
                                "body": [],
                                "revision": 1,
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )

            merged = merge_private_bundles([first, second], output)

            self.assertEqual(merged["id"], "core-2024-private-test")
            self.assertEqual(merged["entryCount"], 2)
            serialized = json.dumps(merged, ensure_ascii=False)
            self.assertNotIn("legacy-a:", serialized)
            self.assertNotIn("legacy-b:", serialized)
            self.assertIn("core-2024-private-test:feat/example", serialized)

    def test_private_bundle_builder_reads_every_json_file_as_utf8(self):
        script = (ROOT / "scripts" / "build-private-content-bundle.ps1").read_text(
            encoding="utf-8"
        )

        self.assertIn("Get-Content", script)
        self.assertIn("-Encoding UTF8", script)
        self.assertIn("phb-2024-v2-bundle.json", script)
        self.assertIn("entryCount", script)

    def test_local_web_preview_uses_the_private_builder_when_available(self):
        script = (ROOT / "scripts" / "preview-client.ps1").read_text(
            encoding="utf-8"
        )

        self.assertIn("build_private_client.ps1", script)
        self.assertIn("phb-2024-v2", script)

    def test_private_client_builder_checks_the_powershell_invocation_status(self):
        script = (ROOT / "scripts" / "build_private_client.ps1").read_text(
            encoding="utf-8"
        )
        invocation = (
            "& $bundleBuilderPath -SourceDirectory $package.Directory "
            "-OutputPath $package.Bundle"
        )
        aggregation = script.split(invocation, 1)[1].split(
            "$parsedPackage =", 1
        )[0]

        self.assertIn("if (-not $?)", aggregation)
        self.assertNotIn("$LASTEXITCODE", aggregation)

    def test_private_client_builder_exposes_one_core_test_package(self):
        script = (ROOT / "scripts" / "build_private_client.ps1").read_text(
            encoding="utf-8"
        )
        merger = (ROOT / "scripts" / "build_private_core_bundle.py").read_text(
            encoding="utf-8"
        )

        self.assertIn("build_private_core_bundle.py", script)
        self.assertIn("core-2024-private-test", merger)
        self.assertIn('"2024 核心测试包"', merger)
        self.assertNotIn("packages = $packageBundles", script)

    def test_private_apk_builder_stages_then_restores_the_placeholder(self):
        script = (ROOT / "scripts" / "build-private-test-apk.ps1").read_text(
            encoding="utf-8"
        )

        self.assertIn("private-test-all-bundle.json", script)
        self.assertIn("ohmydungeon-0.1-private-test.apk", script)
        self.assertIn("flutter build apk --release", script)
        self.assertIn("gradle-repositories.init.gradle", script)
        self.assertIn("init.d", script)
        self.assertIn("finally", script)
        self.assertIn("WriteAllBytes", script)

        init_script = (ROOT / "scripts" / "gradle-repositories.init.gradle").read_text(
            encoding="utf-8"
        )
        self.assertIn("gradle.beforeProject", init_script)
        self.assertIn("maven.aliyun.com", init_script)

    def test_linux_start_script_generates_a_secret_and_checks_health(self):
        script = (ROOT / "infra" / "linux-server" / "start.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn("docker compose up -d --build", script)
        self.assertIn("JWT_SECRET", script)
        self.assertIn("/health", script)
        self.assertIn('ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)', script)

    def test_linux_package_builder_creates_a_tarball(self):
        script = (ROOT / "scripts" / "build-linux-server-package.ps1").read_text(
            encoding="utf-8"
        )

        self.assertIn("tar.exe", script)
        self.assertIn("ohmydungeon-server-linux", script)
        self.assertIn("$serverBuildInputs", script)
        self.assertIn('"src"', script)
        self.assertIn('"prisma"', script)
        self.assertIn('"*.spec.ts"', script)

    def test_docker_compose_wrapper_preserves_detached_mode(self):
        script = (ROOT / "scripts" / "docker-compose.ps1").read_text(
            encoding="utf-8"
        )

        self.assertIn('[Alias("d")]', script)
        self.assertIn('$ComposeArgs += "--detach"', script)

    def test_server_image_npm_registry_is_overridable(self):
        """`npm ci` 必须走可覆盖的 registry。

        国内服务器直连 registry.npmjs.org 会长时间卡在 `npm ci`（实测 17 分钟无进展），
        所以 Dockerfile 的**两个阶段**都要接受 `NPM_REGISTRY` 构建参数，
        compose 要从 `.env` 注入，`.env.example` 要写明怎么改。
        """
        dockerfile = (ROOT / "apps" / "server_nest" / "Dockerfile").read_text(
            encoding="utf-8"
        )
        compose = (ROOT / "docker-compose.yml").read_text(encoding="utf-8")
        env_example = (ROOT / ".env.example").read_text(encoding="utf-8")

        self.assertEqual(
            dockerfile.count("ARG NPM_REGISTRY="),
            2,
            "Dockerfile 的 build 与 runtime 两个阶段都要声明 NPM_REGISTRY",
        )
        self.assertEqual(
            dockerfile.count('npm config set registry "$NPM_REGISTRY" && npm ci'),
            2,
            "两处 npm ci 都必须先设置 registry",
        )
        self.assertIn("NPM_REGISTRY: ${NPM_REGISTRY:-", compose)
        self.assertIn("NPM_REGISTRY=", env_example)

    def test_drift_worker_manifest_matches_the_committed_artifact(self):
        """提交的 drift worker 产物必须与清单一致（见 docs/README.md §14.5）。

        `web/drift_worker.dart.js` 是 `dart compile js` 的产物，必须提交（Flutter web
        构建不会自动编译 `web/` 下的额外入口）。改动 `web/drift_worker.dart` 或升级
        `pubspec.lock` 里的 drift 却忘记重编译时，这条测试会转红——否则只有运行期才会炸。
        """
        manifest_path = (
            ROOT / "apps" / "client_flutter" / "web" / "drift_worker.manifest.json"
        )
        self.assertTrue(
            manifest_path.is_file(),
            "web/drift_worker.manifest.json 缺失；"
            "请运行 pwsh -File scripts/rebuild-drift-worker.ps1",
        )

        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        for field in REQUIRED_FIELDS:
            with self.subTest(field=field):
                self.assertIn(field, manifest)

        # 清单记录的哈希必须与磁盘上的实际内容一致。
        entrypoint = ROOT / "apps" / "client_flutter" / manifest["entrypoint"]
        self.assertEqual(
            manifest["entrypointSha256"],
            hashlib.sha256(entrypoint.read_bytes()).hexdigest(),
        )

        output = ROOT / "apps" / "client_flutter" / manifest["output"]
        self.assertTrue(output.is_file(), f"{manifest['output']} 缺失")
        self.assertEqual(
            manifest["outputSha256"],
            hashlib.sha256(output.read_bytes()).hexdigest(),
        )
        self.assertEqual(manifest["outputBytes"], output.stat().st_size)

        # 完整校验（drift 版本、体积下限、worker 标记）由检查脚本负责。
        self.assertEqual([], verify_drift_worker())

    def test_powershell_scripts_with_chinese_text_keep_the_utf8_bom(self):
        """含中文的 `.ps1` 必须带 UTF-8 BOM（见 docs/README.md §14.3）。

        Windows PowerShell 5.1 会把无 BOM 的脚本按 ANSI 解析，中文注释与字符串会变成
        乱码并可能直接报错。文本编辑器/重写脚本很容易悄悄吃掉 BOM，所以这里钉死。
        """
        checked = 0
        for script in sorted((ROOT / "scripts").glob("*.ps1")):
            raw = script.read_bytes()
            if raw.decode("utf-8", errors="ignore").isascii():
                continue
            checked += 1
            with self.subTest(script=script.name):
                self.assertTrue(
                    raw.startswith(b"\xef\xbb\xbf"),
                    f"{script.name} 含非 ASCII 文本但没有 UTF-8 BOM",
                )
        self.assertGreater(checked, 0, "至少应有一个含中文的 PowerShell 脚本")


if __name__ == "__main__":
    unittest.main()
