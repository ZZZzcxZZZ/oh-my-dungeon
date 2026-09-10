import sys
import unittest
from io import BytesIO
from pathlib import Path

# 允许从仓库根运行: python -m unittest scripts/test_static_preview_server.py
sys.path.insert(0, str(Path(__file__).resolve().parent))

from static_preview_server import NoCacheRequestHandler  # noqa: E402


class StaticPreviewServerTest(unittest.TestCase):
    def test_end_headers_adds_no_cache_headers(self):
        handler = object.__new__(NoCacheRequestHandler)
        sent_headers = []

        handler.send_header = lambda name, value: sent_headers.append((name, value))
        handler._headers_buffer = []
        handler.request_version = "HTTP/1.1"
        handler.wfile = BytesIO()

        NoCacheRequestHandler.end_headers(handler)

        self.assertIn(("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0"), sent_headers)
        self.assertIn(("Pragma", "no-cache"), sent_headers)
        self.assertIn(("Expires", "0"), sent_headers)

    def test_preview_script_disables_flutter_service_worker(self):
        script = Path(__file__).with_name("preview-client.ps1").read_text(encoding="utf-8")

        self.assertIn("--pwa-strategy=none", script)
        self.assertIn("flutter_service_worker.js", script)

    def test_redirects_localhost_to_loopback_ip(self):
        handler = object.__new__(NoCacheRequestHandler)
        sent_responses = []
        sent_headers = []

        handler.headers = {"Host": "localhost:5173"}
        handler.path = "/characters?tab=all"
        handler.send_response = lambda code: sent_responses.append(code)
        handler.send_header = lambda name, value: sent_headers.append((name, value))
        handler.end_headers = lambda: None

        self.assertTrue(handler._redirect_localhost_to_loopback_ip())

        self.assertEqual(sent_responses, [302])
        self.assertIn(("Location", "http://127.0.0.1:5173/characters?tab=all"), sent_headers)

    def test_routes_api_and_discovery_requests_to_the_backend(self):
        self.assertTrue(NoCacheRequestHandler._is_backend_path("/api/auth/login"))
        self.assertTrue(
            NoCacheRequestHandler._is_backend_path(
                "/.well-known/dnd-tool-server"
            )
        )
        self.assertFalse(NoCacheRequestHandler._is_backend_path("/main.dart.js"))

    def test_upgrades_legacy_auth_requests_to_the_api_prefix(self):
        self.assertEqual(
            NoCacheRequestHandler._backend_path("/auth/register"),
            "/api/auth/register",
        )
        self.assertEqual(
            NoCacheRequestHandler._backend_path("/api/auth/register"),
            "/api/auth/register",
        )


if __name__ == "__main__":
    unittest.main()
