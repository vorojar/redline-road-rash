#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = ["fonttools==4.64.0"]
# ///
"""Keep runtime characters and variable outlines; do not rasterize or simplify them."""
from pathlib import Path
import json
from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.pens.recordingPen import RecordingPen

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/fonts/NotoSansSC.ttf"
OUTPUT = ROOT / "assets/fonts/RedlineUI.ttf"


def runtime_characters():
    files = sorted((ROOT / "game").rglob("*.gd")) + sorted((ROOT / "data").rglob("*.json"))
    text = "".join(p.read_text() for p in files)
    # Include Latin key names, digits and punctuation beyond the current UI strings.
    return {ord(c) for c in text if c.isprintable()} | set(range(32, 591))


def main():
    full = TTFont(SOURCE, recalcTimestamp=False)
    required = runtime_characters()
    available = full.getBestCmap()
    characters = required & available.keys()
    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.name_legacy = True
    options.name_languages = ["*"]
    options.glyph_names = True
    options.hinting = True
    options.recalc_timestamp = False
    small = TTFont(SOURCE, recalcTimestamp=False)
    builder = subset.Subsetter(options=options)
    builder.populate(unicodes=characters)
    builder.subset(small)
    # A distinct family name identifies the subset; the original font stays intact.
    names = {1: "Redline UI", 2: "Regular", 3: "RedlineUI-Subset", 4: "Redline UI", 6: "RedlineUI", 16: "Redline UI", 17: "Regular"}
    for record in small["name"].names:
        if record.nameID in names:
            record.string = names[record.nameID].encode(record.getEncoding())
    small.save(OUTPUT)
    final = TTFont(OUTPUT, recalcTimestamp=False)
    assert characters <= final.getBestCmap().keys(), "Subset lost required characters"
    assert full["fvar"].axes[0].minValue == final["fvar"].axes[0].minValue
    # Compare actual outlines and advance widths at every weight used by the HUD.
    sample = set("公路狂徒滑动转向格挡蓄力刹车攻击暂停继续比赛松岭海岸断崖体力摩托REDLINE0123456789")
    for weight in [100, 500, 700]:
        original_glyphs = full.getGlyphSet(location={"wght": weight})
        subset_glyphs = final.getGlyphSet(location={"wght": weight})
        for character in sample:
            old = original_glyphs[available[ord(character)]]
            new = subset_glyphs[final.getBestCmap()[ord(character)]]
            a, b = RecordingPen(), RecordingPen()
            old.draw(a)
            new.draw(b)
            assert a.value == b.value and old.width == new.width, f"Glyph changed: {character} / {weight}"
    print(json.dumps({"characters": len(characters), "original_bytes": SOURCE.stat().st_size,
                      "subset_bytes": OUTPUT.stat().st_size, "outline_checks": len(sample)*3}, ensure_ascii=False))


if __name__ == "__main__":
    main()
