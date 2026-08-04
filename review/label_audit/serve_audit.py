#!/usr/bin/env python3
"""Local annotation server for the Tier-1 label benchmark.

Stdlib only. Binds 127.0.0.1 by default; pass --host 0.0.0.0 to expose on the LAN. Every annotation is appended to a JSONL
immediately, so the session is resumable and nothing is held in memory.

    python3 review/label_audit/serve_audit.py [--port 8731]
"""
import json, os, sys, argparse, datetime, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
ITEMS = os.path.join(HERE, 'app_items.json')
MODS  = os.path.join(HERE, 'app_mods.json')
ANN   = os.path.join(HERE, 'annotations.jsonl')
CORR  = os.path.join(HERE, 'corrections.json')
VERD  = os.path.join(HERE, 'verdicts.jsonl')
MENU  = os.path.join(HERE, 'menu_notes.jsonl')
PAGE  = os.path.join(HERE, 'index.html')

LOCK = threading.Lock()


def _append(path, rec):
    with LOCK:
        with open(path, 'a', encoding='utf-8') as f:
            f.write(json.dumps(rec, ensure_ascii=False) + '\n')
            f.flush()
            os.fsync(f.fileno())


def _read_jsonl(path):
    if not os.path.exists(path):
        return []
    out = []
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    out.append(json.loads(line))
                except json.JSONDecodeError:
                    pass
    return out


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send(self, code, body, ctype='application/json'):
        if isinstance(body, (dict, list)):
            body = json.dumps(body, ensure_ascii=False)
        body = body.encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', ctype + '; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        p = self.path.split('?')[0]
        if p in ('/', '/index.html'):
            with open(PAGE, encoding='utf-8') as f:
                return self._send(200, f.read(), 'text/html')
        if p == '/api/items':
            with open(ITEMS, encoding='utf-8') as f:
                return self._send(200, f.read())
        if p == '/api/mods':
            with open(MODS, encoding='utf-8') as f:
                return self._send(200, f.read())
        if p == '/api/corrections':
            with open(CORR, encoding='utf-8') as f:
                return self._send(200, f.read())
        if p == '/api/state':
            # latest annotation per key wins, so re-annotating overwrites
            done = {}
            for r in _read_jsonl(ANN):
                done[r.get('key')] = r
            menus = {}
            for r in _read_jsonl(MENU):
                menus[r.get('key')] = r.get('text', '')
            verdicts = {}
            for r in _read_jsonl(VERD):
                verdicts[str(r.get('rid'))] = r
            return self._send(200, {'done': done, 'menus': menus, 'verdicts': verdicts})
        return self._send(404, {'error': 'not found'})

    def do_POST(self):
        n = int(self.headers.get('Content-Length', 0))
        try:
            rec = json.loads(self.rfile.read(n) or b'{}')
        except json.JSONDecodeError:
            return self._send(400, {'error': 'bad json'})
        rec['ts'] = datetime.datetime.now().isoformat(timespec='seconds')
        p = self.path.split('?')[0]
        if p == '/api/annotate':
            _append(ANN, rec)
            return self._send(200, {'ok': True})
        if p == '/api/menu':
            _append(MENU, rec)
            return self._send(200, {'ok': True})
        if p == '/api/verdict':
            _append(VERD, rec)
            return self._send(200, {'ok': True})
        return self._send(404, {'error': 'not found'})


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--port', type=int, default=8885)
    ap.add_argument('--host', default='127.0.0.1')
    a = ap.parse_args()
    for f in (ITEMS, MODS, PAGE, CORR):
        if not os.path.exists(f):
            sys.exit(f'missing {f}')
    n_items = len(json.load(open(CORR, encoding='utf-8')))
    n_done = len({r.get('rid') for r in _read_jsonl(VERD)})
    srv = ThreadingHTTPServer((a.host, a.port), H)
    print(f'  corrections {n_items}')
    print(f'  decided     {n_done}')
    print(f'  writing     {VERD}')
    if a.host == '0.0.0.0':
        import socket
        ip = socket.gethostbyname(socket.gethostname())
        print(f'\n  bound on all interfaces')
        print(f'  ->  http://127.0.0.1:{a.port}      (this machine)')
        print(f'  ->  http://{ip}:{a.port}   (WSL address)\n')
    else:
        print(f'\n  ->  http://127.0.0.1:{a.port}\n')
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print('\nstopped; annotations are on disk')


if __name__ == '__main__':
    main()
