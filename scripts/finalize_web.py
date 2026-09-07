"""Give immutable resources content identities; leave the entry HTML updateable."""
import hashlib
import json
import re
from pathlib import Path

root = Path('outputs/web')
pack = root / 'index.pck'
pack_name = 'redline-' + hashlib.sha256(pack.read_bytes()).hexdigest()[:16] + '.pck'
pack.replace(root / pack_name)
# Godot resolves wasm and audio worklets relative to a common executable prefix.
suffixes = ['js', 'wasm', 'audio.worklet.js', 'audio.position.worklet.js']
identity = hashlib.sha256()
for suffix in suffixes:
    identity.update(suffix.encode())
    identity.update((root / ('index.' + suffix)).read_bytes())
engine = 'engine-' + identity.hexdigest()[:16]
for suffix in suffixes:
    # Keep legacy URLs usable for a tab that still has the previous entry page.
    (root / (engine + '.' + suffix)).write_bytes((root / ('index.' + suffix)).read_bytes())
hero = Path('web/title-road.webp').read_bytes()
hero_name = 'title-' + hashlib.sha256(hero).hexdigest()[:16] + '.webp'
(root / hero_name).write_bytes(hero)
(root / 'cache-worker.js').write_bytes(Path('web/cache-worker.js').read_bytes())
page = root / 'index.html'
html = page.read_text()
match = re.search(r'const config=(\{[^\n]+\});', html)
if match is None:
    raise SystemExit('Godot config not found in exported HTML')
config = json.loads(match.group(1))
config['mainPack'] = pack_name
config['executable'] = engine
config['fileSizes'][pack_name] = config['fileSizes'].pop('index.pck')
config['fileSizes'][engine + '.wasm'] = config['fileSizes'].pop('index.wasm')
html = html[:match.start()] + 'const config=' + json.dumps(config, separators=(',', ':')) + ';' + html[match.end():]
html = html.replace('src="index.js"', f'src="{engine}.js"').replace('title-road.webp', hero_name)
page.write_text(html)
# Keep two published generations per family so an older open entry can still start.
# Only generated, content-addressed artifacts are eligible for pruning.
families = {}
for asset in root.iterdir():
    if re.fullmatch(r'(?:redline|engine|title)-[a-f0-9]{16}\.[\w.]+', asset.name):
        family = re.sub(r'[a-f0-9]{16}', 'version', asset.name, count=1)
        families.setdefault(family, []).append(asset)
for versions in families.values():
    for previous in sorted(versions, key=lambda path: path.stat().st_mtime_ns, reverse=True)[2:]:
        previous.unlink()
print('Game pack:', pack_name)
print('Engine:', engine)
print('Title artwork:', hero_name, len(hero), 'bytes')
