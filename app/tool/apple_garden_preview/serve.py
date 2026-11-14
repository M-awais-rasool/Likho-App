"""Local preview of the real Flutter lesson, with existing offline course audio.

From app/:
  flutter build web -t lib/preview/preview_main.dart --output build/apple-garden-web \
    --base-href /preview/ --no-web-resources-cdn --no-wasm-dry-run
  python3 tool/apple_garden_preview/serve.py
"""
import hashlib
import json
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit

APP = Path(__file__).resolve().parents[2]
BUILD = APP / 'build/apple-garden-web'
MEDIA = APP.parent / 'media'
COURSE = APP / 'test/fixtures/english-handwriting.json'
PORT = 8173


def manifest():
    paths = set()

    def walk(value):
        if isinstance(value, dict):
            if isinstance(value.get('audio'), str):
                audio = value['audio']
                paths.update([audio, str(Path(audio).with_suffix('.lip'))])
            if isinstance(value.get('picture'), dict):
                paths.add('pictures/' + value['picture']['key'] + '.png')
            for child in value.values():
                walk(child)
        elif isinstance(value, list):
            for child in value:
                walk(child)

    course = json.loads(COURSE.read_text())
    walk(next(level for level in course['levels'] if level['id'] == 'level-01'))
    return json.dumps({'files': {p: hashlib.sha256((MEDIA / p).read_bytes()).hexdigest()[:16]
                                  for p in paths if (MEDIA / p).is_file()}}).encode()


class Preview(SimpleHTTPRequestHandler):
    def translate_path(self, path):
        path = unquote(urlsplit(path).path)
        if path == '/':
            return str(Path(__file__).with_name('index.html'))
        if path == '/course.json':
            return str(COURSE)
        root, relative = (MEDIA, path[len('/media/'):]) if path.startswith('/media/') else (BUILD, path.removeprefix('/preview/'))
        target = (root / relative).resolve()
        return str(target if target.is_relative_to(root) else BUILD / 'not-found')

    def do_GET(self):
        if urlsplit(self.path).path == '/v1/media':
            data = manifest()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        super().do_GET()


if __name__ == '__main__':
    if not (BUILD / 'index.html').exists():
        raise SystemExit('Build the Flutter web preview first; see the command in this file.')
    print(f'Apple Garden: http://127.0.0.1:{PORT}', flush=True)
    ThreadingHTTPServer(('127.0.0.1', PORT), Preview).serve_forever()
