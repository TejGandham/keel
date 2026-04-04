#!/usr/bin/env python3
"""
Host-side companion for Repo Man.

Listens on localhost:4001 and opens Ghostty at the requested directory.
Run alongside `docker compose up`:

    python3 scripts/terminal-opener.py &
    docker compose up

The Phoenix app sends requests like:
    GET /open?path=/Users/tej/src/shred/AXO471

CORS headers allow requests from localhost:4000 (the Repo Man UI).
"""

import subprocess
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)

        if parsed.path == "/open" and "path" in params:
            directory = params["path"][0]
            # AppleScript: activate Ghostty, open new tab (Cmd+T),
            # type cd command to switch to the repo directory.
            script = f'''
                tell application "Ghostty" to activate
                delay 0.3
                tell application "System Events" to tell process "Ghostty"
                    keystroke "t" using command down
                    delay 0.3
                    keystroke "cd {directory}"
                    key code 36
                end tell
            '''
            subprocess.Popen(["osascript", "-e", script])
            self.send_response(204)
        else:
            self.send_response(400)

        # CORS for localhost:4000
        self.send_header("Access-Control-Allow-Origin", "http://localhost:4000")
        self.end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "http://localhost:4000")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.end_headers()

    def log_message(self, format, *args):
        pass  # silent


if __name__ == "__main__":
    server = HTTPServer(("127.0.0.1", 4001), Handler)
    print("terminal-opener listening on http://127.0.0.1:4001")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nstopped")
