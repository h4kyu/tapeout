"""Local browser transport. HTTP threads exchange data; only PokerSim drives RTL."""

import json
import errno
from urllib.parse import urlparse, parse_qs
from sim.vga_capture import png_bytes
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from queue import Queue, Full
from threading import Lock, Thread


class ViewerState:
    def __init__(self):
        self.keys = Queue(maxsize=64)
        self.lock = Lock()
        self.png = None
        self.rgba = None
        self.frame_number = 0
        self.frame_requested = False
        self.status = {"frame": 0, "message": "Starting RTL simulation"}

    def take_frame_request(self):
        with self.lock:
            requested = self.frame_requested
            self.frame_requested = False
            return requested

    def publish_frame(self, number, rgba):
        with self.lock:
            self.frame_number, self.rgba = number, rgba
            self.png = None

    def publish(self, status, png=None, clear=False):
        with self.lock:
            self.status = dict(status)
            if clear:
                self.png = None
                self.rgba = None
            if png is not None:
                self.png = png


def start_server(state, port=8765):
    page = Path(__file__).with_name("vga_viewer.html").read_bytes()

    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, *_):
            pass

        def reply(self, code, kind, data=b"", frame=None):
            self.send_response(code)
            self.send_header("Content-Type", kind)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-store")
            if frame is not None:
                self.send_header("X-Frame-Number", str(frame))
            self.end_headers()
            try:
                self.wfile.write(data)
            except (BrokenPipeError, ConnectionResetError):
                pass

        def do_GET(self):
            path = self.path.split("?", 1)[0]
            if path == "/":
                self.reply(200, "text/html; charset=utf-8", page)
            elif path == "/state":
                with state.lock:
                    body = json.dumps(state.status).encode()
                self.reply(200, "application/json", body)
            elif path == "/frame.rgba":
                after = parse_qs(urlparse(self.path).query).get("after", [""])[0]
                with state.lock:
                    state.frame_requested = True
                    body, number = state.rgba, state.frame_number
                if body is None or str(number) == after:
                    self.reply(204, "application/octet-stream")
                else:
                    self.reply(200, "application/octet-stream", body, frame=number)
            elif path == "/frame.png":
                with state.lock:
                    body, rgba = state.png, state.rgba
                if body is None and rgba is not None:
                    rgb = bytearray(640 * 480 * 3)
                    rgb[0::3] = rgba[0::4]; rgb[1::3] = rgba[1::4]; rgb[2::3] = rgba[2::4]
                    body = png_bytes(rgb)
                self.reply(200 if body else 204, "image/png", body or b"")
            else:
                self.reply(404, "text/plain", b"Not found")

        def do_POST(self):
            if self.path != "/key":
                self.reply(404, "text/plain", b"Not found")
                return
            # No arbitrary commands, file paths, or RTL access from the browser.
            try:
                length = int(self.headers.get("Content-Length", "0"))
                if not 0 < length <= 64:
                    raise ValueError("Invalid input size")
                key = json.loads(self.rfile.read(length)).get("key")
                if key not in (" ", "1", "2", "3", "4", "5", "b", "r", "q"):
                    raise ValueError("Unknown key")
                state.keys.put_nowait(key)
            except (ValueError, TypeError, AttributeError, Full):
                self.reply(400, "text/plain", b"Invalid command or input queue full")
                return
            self.reply(202, "text/plain", b"Queued")

    try:
        server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    except OSError as error:
        if error.errno == errno.EADDRINUSE:
            raise RuntimeError(f"VGA port {port} is already in use. Stop the previous viewer with Q "
                               f"(or resume it with fg if suspended), or run VGA_PORT={port + 1} make play-vga.") from None
        raise
    server.daemon_threads = True
    Thread(target=server.serve_forever, daemon=True).start()
    return server
