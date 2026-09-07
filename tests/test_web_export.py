"""Export identities must refresh changed assets while reusing unchanged engine bytes."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

FINALIZE = Path(__file__).resolve().parents[1] / 'scripts/finalize_web.py'


class WebExport(unittest.TestCase):
    def test_resource_versions(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            output = root / 'outputs/web'
            source = root / 'web'
            output.mkdir(parents=True)
            source.mkdir()
            (source / 'cache-worker.js').write_text('// worker')
            (source / 'title-road.webp').write_bytes(b'artwork')

            def export(pack, runtime=b'engine'):
                (output / 'index.pck').write_bytes(pack)
                for suffix in ['js', 'wasm', 'audio.worklet.js', 'audio.position.worklet.js']:
                    (output / ('index.' + suffix)).write_bytes(runtime + suffix.encode())
                config = {'executable': 'index', 'mainPack': 'index.pck', 'fileSizes': {'index.pck': len(pack), 'index.wasm': 99}}
                (output / 'index.html').write_text('<img src="title-road.webp"><script src="index.js"></script>\nconst config=' + json.dumps(config) + ';')
                subprocess.run([sys.executable, str(FINALIZE)], cwd=root, check=True, capture_output=True)
                html = (output / 'index.html').read_text()
                result = json.loads(html.split('const config=')[1][:-1])
                for suffix in ['js', 'wasm', 'audio.worklet.js', 'audio.position.worklet.js']:
                    self.assertEqual((output / (result['executable'] + '.' + suffix)).read_bytes(), runtime + suffix.encode())
                self.assertIn('src="' + result['executable'] + '.js"', html)
                self.assertNotIn('title-road.webp', html)
                self.assertEqual((output / result['mainPack']).read_bytes(), pack)
                self.assertEqual(result['fileSizes'][result['mainPack']], len(pack))
                self.assertNotIn('index.wasm', result['fileSizes'])
                return result

            first = export(b'game-v1')
            self.assertEqual(first, export(b'game-v1'))
            second = export(b'game-v2')
            self.assertNotEqual(first['mainPack'], second['mainPack'])
            self.assertEqual(first['executable'], second['executable'])
            self.assertTrue((output / first['mainPack']).exists())
            third = export(b'game-v2', b'new-engine')
            self.assertEqual(second['mainPack'], third['mainPack'])
            self.assertNotEqual(second['executable'], third['executable'])
            self.assertEqual(len(list(output.glob('engine-*.wasm'))), 2)
            export(b'game-v3', b'new-engine')
            self.assertFalse((output / first['mainPack']).exists())
            self.assertEqual(len(list(output.glob('redline-*.pck'))), 2)
            self.assertEqual((output / 'cache-worker.js').read_text(), '// worker')


if __name__ == '__main__':
    unittest.main()
