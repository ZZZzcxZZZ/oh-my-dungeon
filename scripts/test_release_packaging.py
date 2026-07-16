import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class ReleasePackagingTest(unittest.TestCase):
    def test_private_apk_builder_stages_then_restores_the_placeholder(self):
        script = (ROOT / "scripts" / "build-private-test-apk.ps1").read_text(
            encoding="utf-8"
        )

        self.assertIn("phb-2024-v2-bundle.json", script)
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
        self.assertIn("dnd-table-server-linux", script)
        self.assertIn("$serverBuildInputs", script)
        self.assertIn('"src"', script)
        self.assertIn('"prisma"', script)
        self.assertIn('"*.spec.ts"', script)


if __name__ == "__main__":
    unittest.main()
