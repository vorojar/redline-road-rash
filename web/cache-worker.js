// Immutable, content-addressed game files only; HTML always comes from the network.
const CACHE = 'redline-game-assets-v1';
const ROOT = new URL('./', self.location.href);
const ASSET = /^(?:redline-[a-f0-9]{16}\.pck|engine-[a-f0-9]{16}\.(?:wasm|js|audio(?:\.position)?\.worklet\.js)|title-[a-f0-9]{16}\.webp)$/;
self.addEventListener('install', event => event.waitUntil(self.skipWaiting()));
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));
async function notice() {
 for (const client of await self.clients.matchAll()) client.postMessage({type:'cache-unavailable'});
}
self.addEventListener('fetch', event => {
 const url = new URL(event.request.url);
 if (event.request.method !== 'GET' || url.origin !== ROOT.origin || !url.pathname.startsWith(ROOT.pathname) || !ASSET.test(url.pathname.slice(ROOT.pathname.length)) || url.search) return;
 let saving = Promise.resolve();
 const response = (async () => {
  let cache;
  try {
   cache = await caches.open(CACHE);
   const stored = await cache.match(event.request);
   if (stored) return stored;
  } catch (_) { await notice(); }
  const fresh = await fetch(event.request);
  if (cache && fresh.status === 200) {
   saving = cache.put(event.request, fresh.clone()).catch(notice);
  }
  return fresh;
 })();
 event.respondWith(response);
 event.waitUntil(response.then(() => saving));
});
// Keep two generations of each asset family, without touching career/IndexedDB data.
self.addEventListener('message', event => {
 if (event.data?.type !== 'prune-game-cache') return;
 event.waitUntil((async () => {
  const cache = await caches.open(CACHE);
  const families = new Map();
  for (const request of await cache.keys()) {
   const name = new URL(request.url).pathname.split('/').pop();
   const family = name.replace(/[a-f0-9]{16}/, 'version');
   const entries = families.get(family) || [];
   entries.push(request); families.set(family, entries);
  }
  for (const entries of families.values()) {
   for (const request of entries.slice(0, -2)) await cache.delete(request);
  }
 })().catch(notice));
});
