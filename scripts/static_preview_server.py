import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError
from urllib.request import Request, urlopen


class NoCacheRequestHandler(SimpleHTTPRequestHandler):
    backend_origin = "http://127.0.0.1:3000"

    def do_GET(self):
        if self._is_backend_path(self.path):
            self._proxy_to_backend()
            return
        if self._redirect_localhost_to_loopback_ip():
            return
        super().do_GET()

    def do_HEAD(self):
        if self._is_backend_path(self.path):
            self._proxy_to_backend()
            return
        if self._redirect_localhost_to_loopback_ip():
            return
        super().do_HEAD()

    def do_POST(self):
        self._proxy_to_backend()

    def do_PUT(self):
        self._proxy_to_backend()

    def do_PATCH(self):
        self._proxy_to_backend()

    def do_DELETE(self):
        self._proxy_to_backend()

    @staticmethod
    def _is_backend_path(path):
        return path.startswith("/api/") or path.startswith("/.well-known/") or path == "/health"

    def _proxy_to_backend(self):
        content_length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(content_length) if content_length else None
        headers = {
            name: value
            for name, value in self.headers.items()
            if name.lower() not in {"host", "connection", "content-length"}
        }
        request = Request(
            f"{self.backend_origin}{self._backend_path(self.path)}",
            data=body,
            headers=headers,
            method=self.command,
        )
        try:
            with urlopen(request) as response:
                self._send_proxy_response(response.status, response.headers, response.read())
        except HTTPError as error:
            self._send_proxy_response(error.code, error.headers, error.read())

    @staticmethod
    def _backend_path(path):
        if path.startswith("/auth/"):
            return f"/api{path}"
        return path

    def _send_proxy_response(self, status, headers, body):
        self.send_response(status)
        for name, value in headers.items():
            if name.lower() not in {"connection", "transfer-encoding", "content-length"}:
                self.send_header(name, value)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def _redirect_localhost_to_loopback_ip(self):
        host = self.headers.get("Host", "")
        if host != "localhost" and not host.startswith("localhost:"):
            return False

        port = host.partition(":")[2]
        target_host = "127.0.0.1" if not port else f"127.0.0.1:{port}"
        self.send_response(302)
        self.send_header("Location", f"http://{target_host}{self.path}")
        self.end_headers()
        return True

    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()


def main():
    parser = argparse.ArgumentParser(description="Serve Flutter web artifacts without browser caching.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--directory", required=True)
    parser.add_argument("--backend-origin", default="http://127.0.0.1:3000")
    args = parser.parse_args()

    NoCacheRequestHandler.backend_origin = args.backend_origin.rstrip("/")
    handler = partial(NoCacheRequestHandler, directory=args.directory)
    server = ThreadingHTTPServer((args.host, args.port), handler)
    print(f"Serving Flutter web preview at http://{args.host}:{args.port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
