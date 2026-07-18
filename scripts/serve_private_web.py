#!/usr/bin/env python3
"""Private test static server with reverse proxy to NestJS backend.

Serves the Flutter Web release on 5181 and proxies /api and /.well-known
to the NestJS server (default http://localhost:3000), so that the web
client's relative-path requests reach the real backend instead of the
static server (which would return 501 on POST).

Usage:
    python scripts/serve_private_web.py [--port 5181] [--backend http://localhost:3000] [--web-dir apps/client_flutter/build/web]
"""

from __future__ import annotations

import argparse
import http.server
import os
import socketserver
import urllib.request
import urllib.error
from http import HTTPStatus
from pathlib import Path

PROXY_PREFIXES = ("/api/", "/.well-known/")


class ProxyHandler(http.server.SimpleHTTPRequestHandler):
    """Serve static files; proxy API + well-known to the NestJS backend."""

    backend_origin: str = "http://localhost:3000"
    web_dir: Path = Path("apps/client_flutter/build/web")

    def _is_proxy(self) -> bool:
        return any(self.path.startswith(p) for p in PROXY_PREFIXES)

    def _proxy(self) -> None:
        target = f"{self.backend_origin}{self.path}"
        # Forward request body for POST/PUT/PATCH/DELETE.
        length = int(self.headers.get("Content-Length", 0) or 0)
        body = self.rfile.read(length) if length > 0 else None
        req_headers = {
            k: v
            for k, v in self.headers.items()
            if k.lower() not in ("host", "content-length", "connection")
        }
        req = urllib.request.Request(
            target,
            data=body,
            method=self.command,
            headers=req_headers,
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                self.send_response(resp.status)
                for k, v in resp.getheaders():
                    if k.lower() not in ("connection", "transfer-encoding"):
                        self.send_header(k, v)
                self.end_headers()
                payload = resp.read()
                if payload:
                    self.wfile.write(payload)
        except urllib.error.HTTPError as exc:
            self.send_response(exc.code)
            for k, v in exc.headers.items():
                if k.lower() not in ("connection", "transfer-encoding"):
                    self.send_header(k, v)
            self.end_headers()
            data = exc.read()
            if data:
                self.wfile.write(data)
        except urllib.error.URLError as exc:
            self.send_response(HTTPStatus.BAD_GATEWAY)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(
                f'{{"message":"Backend unreachable: {exc.reason}","statusCode":502}}'.encode()
            )

    def do_GET(self) -> None:
        if self._is_proxy():
            return self._proxy()
        return super().do_GET()

    def do_HEAD(self) -> None:
        if self._is_proxy():
            return self._proxy()
        return super().do_HEAD()

    def do_POST(self) -> None:
        if self._is_proxy():
            return self._proxy()
        self.send_error(HTTPStatus.NOT_IMPLEMENTED, "POST only supported on /api")

    def do_PUT(self) -> None:
        if self._is_proxy():
            return self._proxy()
        self.send_error(HTTPStatus.NOT_IMPLEMENTED, "PUT only supported on /api")

    def do_DELETE(self) -> None:
        if self._is_proxy():
            return self._proxy()
        self.send_error(HTTPStatus.NOT_IMPLEMENTED, "DELETE only supported on /api")

    def do_OPTIONS(self) -> None:
        if self._is_proxy():
            return self._proxy()
        self.send_response(HTTPStatus.NO_CONTENT)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,HEAD,OPTIONS")
        self.end_headers()

    def translate_path(self, path: str) -> str:
        # Serve from the configured web dir instead of cwd.
        rel = path.lstrip("/")
        return str((self.web_dir / rel) if rel else self.web_dir / "index.html")

    def end_headers(self) -> None:
        # Ensure index.html fallback for SPA routes (no caching issues).
        super().end_headers()


class ThreadingHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True


def main() -> None:
    parser = argparse.ArgumentParser(description="Private web server with API proxy")
    parser.add_argument("--port", type=int, default=5181)
    parser.add_argument("--backend", default="http://localhost:3000")
    parser.add_argument(
        "--web-dir", default="apps/client_flutter/build/web"
    )
    args = parser.parse_args()

    web_dir = Path(args.web_dir).resolve()
    if not (web_dir / "index.html").exists():
        raise SystemExit(f"index.html not found in {web_dir}")

    ProxyHandler.backend_origin = args.backend.rstrip("/")
    ProxyHandler.web_dir = web_dir
    # SimpleHTTPRequestHandler needs cwd to be the web dir for its default
    # translate_path, but we override translate_path so just keep cwd.
    os.chdir(web_dir)

    server = ThreadingHTTPServer(("127.0.0.1", args.port), ProxyHandler)
    print(
        f"Serving {web_dir} on http://127.0.0.1:{args.port} "
        f"(proxy /api, /.well-known -> {args.backend})"
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.shutdown()


if __name__ == "__main__":
    main()
