"""Rebuild campaign labels and pixel glyphs; no runtime font/network dependency."""
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

PROJECT = Path(__file__).resolve().parents[3]
LAB = PROJECT / "tools/art-lab"
FONT = PROJECT / "pushbox/assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2"
NAMES = dict(zip(
    ("dungeon", "forest", "ruins", "cave", "sky_island", "cosmos"),
    ("幽暗石牢", "迷雾古森", "黄金神庙", "幽光晶窟", "云端圣域", "深空星站"),
))

chapters = []
for key, name in NAMES.items():
    levels = []
    for source in sorted((PROJECT / "pushbox/levels/campaign" / key).glob("*.json")):
        level = json.loads(source.read_text())
        levels.append({"id": level["id"], "title": level["title"]})
    assert len(levels) == 6, (key, len(levels))
    chapters.append({"id": key, "name": name, "levels": levels})
(LAB / "js/data/campaign.js").write_text(
    "// Campaign labels mirror pushbox/levels/campaign; covered by the camp UI tests.\n"
    "const UI_CHAPTERS = " + json.dumps(chapters, ensure_ascii=False, indent=2) + ";\n"
)

characters = set(chr(i) for i in range(32, 127))
sources = [p for p in (LAB / "js/ui").glob("*.js") if p.name != "font.js"]
sources.append(LAB / "js/data/campaign.js")
for source in sources:
    characters.update(c for c in source.read_text() if ord(c) > 127 and not c.isspace())
font = ImageFont.truetype(str(FONT), 12)
glyphs = []
for char in sorted(characters):
    advance = max(1, round(font.getlength(char)))
    bitmap = Image.new("1", (advance, 14))
    ImageDraw.Draw(bitmap).text((0, 11), char, font=font, fill=1, anchor="ls")
    rows = [
        sum(1 << x for x in range(advance) if bitmap.getpixel((x, y)))
        for y in range(14)
    ]
    glyphs.append(
        json.dumps(char, ensure_ascii=False) + ":"
        + json.dumps({"advance": advance, "rows": rows}, separators=(",", ":"))
    )
font_hash = hashlib.sha256(FONT.read_bytes()).hexdigest()
(LAB / "js/ui/font.js").write_text(
    "// Generated Fusion Pixel 12px bitmap subset; see licenses/font/.\n"
    "// Source font SHA-256: " + font_hash + "\n"
    'const CAMP_FONT = {height:14,baseline:11,glyphs:{\n'
    + ",\n".join(glyphs) + "\n}};\n"
)
for source in (PROJECT / "pushbox/assets/fonts").rglob("*.txt"):
    target = LAB / "licenses/font" / source.relative_to(PROJECT / "pushbox/assets/fonts")
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
print(f"Rebuilt 36 campaign labels and {len(glyphs)} pixel glyphs.")
