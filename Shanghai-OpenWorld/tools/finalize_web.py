#!/usr/bin/env python3
"""Make the local Web build cache all of its same-origin assets for offline play."""
from hashlib import sha256
import json
from pathlib import Path

folder = Path(__file__).resolve().parents[1] / 'builds/web'
entry = folder / 'index.html'
html = entry.read_text()
registration = """<script>
if (window.isSecureContext && 'serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./index.service.worker.js').catch(console.warn);
  });
}
</script>
"""
if '</head>' not in html:
    raise SystemExit('Unexpected Godot HTML shell')
entry.write_text(html.replace('</head>', registration + '</head>', 1))
files = sorted(p.name for p in folder.glob('index.*') if not p.name.endswith('.service.worker.js'))
build = sha256((folder / 'index.pck').read_bytes() + (folder / 'index.js').read_bytes()).hexdigest()[:16]
worker = """'use strict';
const prefix = 'shanghai-open-world:' + self.registration.scope + ':';
const name = prefix + BUILD;
const assets = FILES;
const allowed = new Set(assets.map(file => new URL(file, self.registration.scope).href));
self.addEventListener('install', event => {
  event.waitUntil(caches.open(name).then(cache => cache.addAll(assets)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys
    .filter(key => key.startsWith(prefix) && key !== name).map(key => caches.delete(key))))
    .then(() => self.clients.claim()));
});
self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  url.hash = '';
  url.search = '';
  const key = url.href === self.registration.scope ?
    new URL('index.html', self.registration.scope).href : url.href;
  if (!allowed.has(key)) return;
  event.respondWith(caches.open(name).then(cache => cache.match(key))
    .then(response => response || fetch(event.request)));
});
"""
(folder / 'index.service.worker.js').write_text(worker.replace('BUILD', json.dumps(build)).replace('FILES', json.dumps(files)))
