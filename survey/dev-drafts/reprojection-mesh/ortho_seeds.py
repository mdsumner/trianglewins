"""Constrained seeds for lon/lat tiles drawn in an orthographic hemisphere.

The visible part of each 22.5 degree tile is the tile box clipped to the
spherical cap seen from the view centre (radius 89.5 degrees, so the
projection stays defined on every chord). The clipped polygon, in tile uv,
is triangulated as a constrained Delaunay triangulation (Shewchuk's Triangle,
'p' switch, no refinement) and written in RasterReprojector's seed shape:
uvs, triangles, halfedges.

Run: python3 ortho_seeds.py  -> results/ortho-seeds.json
"""

import json
import math
from pathlib import Path

import numpy as np
import shapely
import triangle
from shapely.geometry import Polygon, box

HERE = Path(__file__).resolve().parent
LON0, LAT0 = 147.0, -42.0  # view centre (Hobart)
CAP = 89.5  # visible cap radius, degrees
TILE = 22.5
STEP = 0.1  # horizon trace step in longitude, degrees

D2R = math.pi / 180
cosc = math.cos(CAP * D2R)


def visible(lon, lat):
    d = (math.sin(lat * D2R) * math.sin(LAT0 * D2R)
         + math.cos(lat * D2R) * math.cos(LAT0 * D2R) * math.cos((lon - LON0) * D2R))
    return d >= cosc


def horizon_lat(lon):
    # the cap holds the south pole and not the north pole, so each meridian
    # leaves it exactly once: bisect for that latitude
    lo, hi = -90.0, 90.0
    for _ in range(60):
        mid = (lo + hi) / 2
        if visible(lon, mid):
            lo = mid
        else:
            hi = mid
    return lo


assert visible(0, -90) and not visible(0, 90)


def horizon_ring(step=0.05):
    """The cap's edge traced by azimuth around the view centre (even spacing
    on the sphere), as a lon/lat polygon. The cap holds the south pole, so the
    unwrapped trace spans 360 degrees of longitude and closes along -90."""
    lat0, lon0, c = LAT0 * D2R, LON0 * D2R, CAP * D2R
    pts = []
    for az in np.arange(0, 360, step) * D2R:
        lat = math.asin(math.sin(lat0) * math.cos(c) + math.cos(lat0) * math.sin(c) * math.cos(az))
        lon = lon0 + math.atan2(math.sin(az) * math.sin(c) * math.cos(lat0),
                                math.cos(c) - math.sin(lat0) * math.sin(lat))
        pts.append([lon / D2R, lat / D2R])
    pts = np.array(pts)
    pts[:, 0] = np.degrees(np.unwrap(np.radians(pts[:, 0])))
    if pts[-1, 0] < pts[0, 0]:
        pts = pts[::-1]
    a = pts[0, 0]
    ring = np.vstack([pts, [[a + 360, pts[0, 1]], [a + 360, -90], [a, -90]]])
    poly = Polygon(ring).buffer(0)
    world = box(-180, -90, 180, 90)
    parts = [shapely.affinity.translate(poly, k * 360).intersection(world) for k in (-2, -1, 0, 1)]
    return shapely.union_all(parts)


import shapely.affinity  # noqa: E402

cap = horizon_ring()


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


def seed_for(part, lon0, lat_top):
    ext = np.asarray(part.exterior.coords)[:-1]
    uv = np.c_[(ext[:, 0] - lon0) / TILE, (lat_top - ext[:, 1]) / TILE]
    uv = np.clip(uv, 0, 1)
    n = len(uv)
    segs = np.c_[np.arange(n), (np.arange(n) + 1) % n]
    t = triangle.triangulate({"vertices": uv, "segments": segs}, "pQ")
    assert len(t["vertices"]) == n, "Triangle added points"
    tris = t["triangles"].tolist()
    # same winding as delaunator output and triangulateRectangle (negative
    # signed area in uv), which the reprojector's flip tests assume
    v = t["vertices"]
    fixed = []
    for a, b, c in tris:
        cross = (v[b][0] - v[a][0]) * (v[c][1] - v[a][1]) - (v[b][1] - v[a][1]) * (v[c][0] - v[a][0])
        fixed.append([a, b, c] if cross < 0 else [a, c, b])
    return v.ravel().tolist(), fixed


tiles = []
for row in range(8):
    for col in range(16):
        lon0 = -180 + col * TILE
        lat_top = 90 - row * TILE
        clip = box(lon0, lat_top - TILE, lon0 + TILE, lat_top).intersection(cap)
        if clip.is_empty or clip.area < 1e-9:
            continue
        full = abs(clip.area - TILE * TILE) < 1e-9
        parts = [clip] if clip.geom_type == "Polygon" else list(clip.geoms)
        uvs, tris = [], []
        for part in parts:
            if part.area < 1e-9:
                continue
            u, t = seed_for(part, lon0, lat_top)
            off = len(uvs) // 2
            uvs += u
            tris += [[i + off for i in tri] for tri in t]
        tiles.append({
            "col": col, "row": row, "lon0": lon0, "latTop": lat_top, "deg": TILE,
            "full": full, "parts": len(parts),
            "visible_deg2": clip.area,
            "seed": {"uvs": uvs, "triangles": sum(tris, []), "halfedges": halfedges_of(tris)},
        })

out = {"lon0": LON0, "lat0": LAT0, "cap": CAP, "tiles": tiles}
(HERE / "results").mkdir(exist_ok=True)
(HERE / "results" / "ortho-seeds.json").write_text(json.dumps(out))
print(len(tiles), "tiles;", sum(t["full"] for t in tiles), "wholly visible;",
      sum(not t["full"] for t in tiles), "cut by the horizon")
