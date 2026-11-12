"""Seeds for a polar-native raster (south polar stereographic, EPSG:3031
style, spherical) drawn in a world projection (Equal Earth).

The raster covers the square that holds the southern hemisphere, in 5 x 5
tiles of 512 pixels, so one tile holds the pole and a column of tiles below
it straddles the antimeridian (the ray x = 0, y < 0). For each tile:

1. clip the tile box to the hemisphere (the equator circle) minus a tiny
   cap at the pole (radius 0.05 degrees, about 5.6 km, under one pixel);
2. if the antimeridian crosses the tile, cut it along x = 0 into a west
   part (longitude -180..0) and an east part (0..180);
3. triangulate each part with constraints (Triangle, 'p', no refinement).

Each part is meshed on its own, with its own longitude branch, so vertices
on the cut get -180 on one side and +180 on the other.

Run: python3 am_seeds.py  -> results/am-seeds.json
"""

import json
import math
from pathlib import Path

import numpy as np
import shapely
import triangle
from shapely.geometry import Point, Polygon, box

HERE = Path(__file__).resolve().parent
R = 6371008.8
D2R = math.pi / 180
K0 = (1 - math.sin(-71 * D2R)) / 2
NT = 5
W = 512


def rho(lat):
    return 2 * R * K0 * math.tan((math.pi / 2 + lat * D2R) / 2)


E = rho(0.0)  # the equator: half-width of the raster
SIDE = 2 * E / NT
HOLE = rho(-89.95)


def circle(r, step=0.05):
    az = np.arange(0, 360, step) * D2R
    return Polygon(np.c_[r * np.sin(az), r * np.cos(az)])


# 0.5 degree steps on the equator circle (chords within 120 m of it, a
# hundredth of a pixel); 2 degree steps on the tiny polar cap
domain = circle(E, 0.5).difference(circle(HOLE, 2.0))


def halfedges_of(tris):
    he = [-1] * (3 * len(tris))
    seen = {}
    for t, (a, b, c) in enumerate(tris):
        for k, (p, q) in enumerate(((a, b), (b, c), (c, a))):
            e = 3 * t + k
            if (q, p) in seen:
                o = seen.pop((q, p))
                he[e], he[o] = o, e
            else:
                seen[(p, q)] = e
    return he


def seed_for(part, x0, ytop):
    ext = np.asarray(part.exterior.coords)[:-1]
    uv = np.clip(np.c_[(ext[:, 0] - x0) / SIDE, (ytop - ext[:, 1]) / SIDE], 0, 1)
    n = len(uv)
    segs = np.c_[np.arange(n), (np.arange(n) + 1) % n]
    holes = [np.asarray(h.coords)[:-1] for h in part.interiors]
    tri_in = {"vertices": uv, "segments": segs}
    if holes:
        raise ValueError("unexpected hole")
    t = triangle.triangulate(tri_in, "pQ")
    assert len(t["vertices"]) == n, "Triangle added points"
    v = t["vertices"]
    out = []
    for a, b, c in t["triangles"].tolist():
        cross = (v[b][0] - v[a][0]) * (v[c][1] - v[a][1]) - (v[b][1] - v[a][1]) * (v[c][0] - v[a][0])
        out.append([a, b, c] if cross < 0 else [a, c, b])
    return {"uvs": v.ravel().tolist(), "triangles": sum(out, []), "halfedges": halfedges_of(out)}


tiles = []
for row in range(NT):
    for col in range(NT):
        x0 = -E + col * SIDE
        ytop = E - row * SIDE
        tb = box(x0, ytop - SIDE, x0 + SIDE, ytop)
        base = tb.intersection(domain)
        if base.is_empty:
            continue
        crosses = x0 < 0 < x0 + SIDE and ytop - SIDE < 0
        pieces = []
        if crosses:
            for branch, half in ((-1, box(-2 * E, -2 * E, 0, 2 * E)), (1, box(0, -2 * E, 2 * E, 2 * E))):
                pieces.append((branch, base.intersection(half)))
        else:
            pieces.append((0, base))
        parts = []
        for branch, g in pieces:
            for p in ([g] if g.geom_type == "Polygon" else list(g.geoms)):
                if p.area > 1e-6 * SIDE * SIDE:
                    parts.append({"branch": branch, "seed": seed_for(p, x0, ytop)})
        tiles.append({
            "col": col, "row": row, "x0": x0, "yTop": ytop, "side": SIDE,
            "has_pole": tb.contains(Point(0, 0)), "crosses": crosses,
            "box_inside": tb.within(circle(E)), "parts": parts,
        })

out = {"R": R, "K0": K0, "E": E, "side": SIDE, "W": W, "hole_lat": -89.95, "tiles": tiles}
(HERE / "results").mkdir(exist_ok=True)
(HERE / "results" / "am-seeds.json").write_text(json.dumps(out))
print(len(tiles), "tiles;", sum(t["crosses"] for t in tiles), "cut at the antimeridian;",
      sum(len(t["parts"]) for t in tiles), "parts")
