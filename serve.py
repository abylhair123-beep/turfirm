"""
Локальный сервер для SAPAR PWA (build/web).

Раздаёт собранный Flutter-билд с правильными заголовками
для Service Worker, CORS и кеширования.

Запуск:
  python serve.py          — раздаёт build/web на 0.0.0.0:5050
  python serve.py --dir .  — раздаёт текущую папку (для dev)
"""

import http.server
import socketserver
import argparse
import os
import sys

PORT = 5050


class PwaHandler(http.server.SimpleHTTPRequestHandler):
    """HTTP handler с правильными заголовками для PWA."""

    def end_headers(self):
        # CORS
        self.send_header('Access-Control-Allow-Origin', '*')

        # Service Worker: разрешить scope = /
        self.send_header('Service-Worker-Allowed', '/')

        # Для dev — без кеша; на проде Nginx/Cloudflare добавят нормальный кеш
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')

        super().end_headers()

    def do_GET(self):
        # SPA fallback: если файл не найден — отдаём index.html
        # (для корректной навигации Flutter Router)
        path = self.translate_path(self.path)
        if not os.path.exists(path) and not self.path.startswith('/api'):
            self.path = '/index.html'
        return super().do_GET()


# Правильные MIME-типы
PwaHandler.extensions_map.update({
    '.wasm': 'application/wasm',
    '.js': 'application/javascript',
    '.mjs': 'application/javascript',
    '.json': 'application/json',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.webp': 'image/webp',
    '.svg': 'image/svg+xml',
    '.otf': 'font/otf',
    '.ttf': 'font/ttf',
    '.woff': 'font/woff',
    '.woff2': 'font/woff2',
    '.css': 'text/css',
    '.html': 'text/html',
    '.webmanifest': 'application/manifest+json',
})


def main():
    parser = argparse.ArgumentParser(description='SAPAR PWA Dev Server')
    parser.add_argument('--dir', default='build/web',
                        help='Директория для раздачи (по умолчанию build/web)')
    parser.add_argument('--port', type=int, default=PORT,
                        help=f'Порт (по умолчанию {PORT})')
    args = parser.parse_args()

    serve_dir = os.path.abspath(args.dir)
    if not os.path.isdir(serve_dir):
        print(f'ERROR: Directory "{serve_dir}" not found.')
        print(f'   Build first: flutter build web --release')
        sys.exit(1)

    os.chdir(serve_dir)

    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(('0.0.0.0', args.port), PwaHandler) as httpd:
        local_ip = _get_local_ip()
        print(f'')
        print(f'  SAPAR PWA Server')
        print(f'  -----------------------------------')
        print(f'  Papka:      {serve_dir}')
        print(f'  Local:      http://localhost:{args.port}')
        if local_ip:
            print(f'  Network:    http://{local_ip}:{args.port}')
            print(f'')
            print(f'  Otkroyte ssylku "Network" na telefone')
            print(f'  chtoby ustanovit SAPAR kak prilozhenie!')
        print(f'  -----------------------------------')
        print(f'  Ctrl+C dlya ostanovki')
        print(f'')
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print('\n  Server stopped.')


def _get_local_ip():
    """Получить локальный IP для доступа с телефона по WiFi."""
    import socket
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return None


if __name__ == '__main__':
    main()
