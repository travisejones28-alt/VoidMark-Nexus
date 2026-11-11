#!/usr/bin/env python3
"""Bake OpenMap (MIT, github.com/openmap-world/openmap) data Nexus uses for route previews.

  python tools/bake_openmap.py PATH/TO/OpenMap

Writes Data/ZoneLand.lua:
  * each zone's land outline (OpenMap's Media/Textures/Forever/MapZoneLand/<uiMapID>.tga alpha,
    the zone's own ground without its painted sea) as a coarse 60x40 grid over the zone map
  * the list of OpenMap's baked world tiles (Data/Forever/ZoneArt.lua) so the preview only asks for
    textures that exist
Regenerate rather than edit.
"""
import re, sys
from pathlib import Path
from PIL import Image

GW, GH = 60, 40   # grid cells over the zone map (same 3:2 shape as the zone art)

def main(src):
    src = Path(src)
    land_dir = src / "Media/Textures/Forever/MapZoneLand"
    art = (src / "Data/Forever/ZoneArt.lua").read_text(encoding="utf-8")
    params = {k: int(v) for k, v in re.findall(r"\b(px|size|step)\s*=\s*(\d+)", art)}
    tiles_block = re.search(r"tiles\s*=\s*\{(.*?)\}", art, re.S).group(1)
    tiles = [int(t) for t in re.findall(r"\d+", tiles_block)]
    version = re.search(r"## Version:\s*(\S+)", (src / "OpenMap.toc").read_text(encoding="utf-8", errors="ignore")).group(1)
    out = [
        "-- Baked from OpenMap %s (MIT; map art is Blizzard's) by tools/bake_openmap.py. Regenerate rather than edit." % version,
        "-- land[uiMapID] = rows of a %dx%d grid over the zone map, hex, 1 bit per cell (1 = the zone's own land)." % (GW, GH),
        "-- tiles: OpenMap's baked world tiles (MapZones\\<i>_<j>), key i*256+j; px/size/step as its ZoneArt.lua.",
        "local _, N = ...",
        "N.zoneLand = { w = %d, h = %d, land = {" % (GW, GH),
    ]
    zones = 0
    for f in sorted(land_dir.glob("*.tga"), key=lambda p: int(p.stem)):
        im = Image.open(f).convert("RGBA").split()[3].resize((GW, GH), Image.BOX)
        px = im.load()
        rows = []
        for y in range(GH):
            bits = "".join("1" if px[x, y] >= 128 else "0" for x in range(GW))
            bits += "0" * ((-len(bits)) % 4)
            rows.append("%0*x" % (len(bits) // 4, int(bits, 2)))
        out.append("  [%s] = { %s }," % (f.stem, ", ".join('"%s"' % r for r in rows)))
        zones += 1
    out.append("}, art = { px = %d, size = %d, step = %d, tiles = {" % (params["px"], params["size"], params["step"]))
    for i in range(0, len(tiles), 20):
        out.append("  " + ", ".join(str(t) for t in tiles[i:i + 20]) + ",")
    out.append("} } }")
    Path("Data/ZoneLand.lua").write_text("\n".join(out) + "\n", encoding="utf-8")
    print("baked %d zones, %d tiles from OpenMap %s" % (zones, len(tiles), version))

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "OpenMap")
