import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer


class NoCacheRequestHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self._redirect_localhost_to_loopback_ip():
            return
        super().do_GET()

    def do_HEAD(self):
        if self._redirect_localhost_to_loopback_ip():
            return
        super().do_HEAD()

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
    args = parser.parse_args()

    handler = partial(NoCacheRequestHandler, directory=args.directory)
    server = ThreadingHTTPServer((args.host, args.port), handler)
    print(f"Serving Flutter web preview at http://{args.host}:{args.port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
