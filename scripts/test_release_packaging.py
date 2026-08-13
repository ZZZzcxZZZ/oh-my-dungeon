import unittest
import json
import tempfile
from pathlib import Path

from scripts.build_private_core_bundle import merge_private_bundles


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
                        "formatVersion": 2,
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
                        "formatVersion": 2,
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


if __name__ == "__main__":
    unittest.main()
