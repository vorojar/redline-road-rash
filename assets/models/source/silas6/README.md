# Motorcycle — Silas6

Original source GLB downloaded through Sketchfab's official free download on 2026-09-08.

- Creator: [Silas6](https://sketchfab.com/Silas6)
- Work: [Motorcycle](https://sketchfab.com/3d-models/motorcycle-693e83d86e1e4e5b95e4314dbdd95d40)
- License: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- Original source file: `motorcycle.glb` (69,908 triangles, embedded textures up to 2K).

REDLINE modifications in `scripts/import_street_bike.py`: fit the chassis to the game, separate tires and hubs into front/rear rolling groups while preserving circular wheels and UVs, cap runtime textures at 1K, and export `assets/models/ratchet.glb`. The game adapts the hand contact points, recolors the orange paint and adds wear. Original textures and geometry remain credited to Silas6. No endorsement by the creator is implied.

Run from the repository root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python scripts/import_street_bike.py
```
