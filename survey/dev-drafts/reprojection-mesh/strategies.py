"""The same two lon/lat tiles meshed three ways for south polar
stereographic, compared at the same true error on the map.

  grid      a fixed power-of-two grid in the source tile, split into
            triangles (the MapLibre globe approach: a set number of cells
            per tile, not error driven); the smallest grid that meets the
            tolerance
  target    a quadtree in the map (the OpenLayers approach): split a quad
            while the inverse of its centre is off the mean of its diagonal
            corners' inverses, measured here as a map displacement; up to 10
            levels, quads kept when any corner falls in the tile
  greedy    deck.gl-raster's RasterReprojector with one shared error unit
            (from run.mjs, scenario "pole", variant B1)

Error everywhere: for a point on the map, the source point the GPU samples
there (linear in the triangle) is projected forward, and the distance to
the point itself is the error, in P (one source pixel at 71 S).

Run after run.mjs:  python3 strategies.py  -> results/strategies.csv, .json
"""

import json
import math
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
R = 6371008.8
D2R = math.pi / 180
K0 = (1 - math.sin(-71 * D2R)) / 2
M = json.loads((HERE / "results" / "meshes.json").read_text())
P = M["P"]
TOL = 0.125 * P
TILES = {"outer": (0.0, -45.0), "polar": (0.0, -67.5)}  # lon0, latTop
DEG = 22.5


def fwd(lon, lat):
    r = 2 * R * K0 * np.tan((np.pi / 2 + np.asarray(lat) * D2R) / 2)
    return r * np.sin(np.asarray(lon) * D2R), r * np.cos(np.asarray(lon) * D2R)


def inv(x, y):
    r = np.hypot(x, y)
    return np.arctan2(x, y) / D2R, (2 * np.arctan(r / (2 * R * K0)) - np.pi / 2) / D2R


# barycentric sample points, 28 per triangle
N = 6
BARY = np.array([(p / N, q / N, 1 - p / N - q / N) for p in range(N + 1) for q in range(N + 1 - p)])


def err_source_mesh(src, tri):
    """src: vertices in lon/lat; triangles drawn at fwd(src)."""
    sx, sy = src[:, 0][tri], src[:, 1][tri]  # (T, 3)
    mx, my = fwd(sx, sy)
    lon = sx @ BARY.T
    lat = sy @ BARY.T
    ex, ey = fwd(lon, lat)
    return np.hypot(ex - mx @ BARY.T, ey - my @ BARY.T).max()


def err_target_mesh(xy, tri, inside):
    """xy: vertices on the map, sources inv(xy); a sample at map point m shows
    source s_lin, which belongs at fwd(s_lin)."""
    lon, lat = inv(xy[:, 0], xy[:, 1])
    lon_t, lat_t = lon[tri], lat[tri]
    mx = xy[:, 0][tri] @ BARY.T
    my = xy[:, 1][tri] @ BARY.T
    sl = lon_t @ BARY.T
    sp = lat_t @ BARY.T
    ex, ey = fwd(sl, sp)
    e = np.hypot(ex - mx, ey - my)
    ok = inside(*inv(mx, my))
    return e[ok].max() if ok.any() else 0.0


def grid(lon0, lat_top):
    for n in (1, 2, 4, 8, 16, 32, 64, 128, 256):
        u = np.linspace(0, 1, n + 1)
        uu, vv = np.meshgrid(u, u)
        src = np.c_[lon0 + uu.ravel() * DEG, lat_top - vv.ravel() * DEG]
        k = lambda i, j: i * (n + 1) + j  # noqa: E731
        tri = []
        for i in range(n):
            for j in range(n):
                a, b, c, d = k(i, j), k(i, j + 1), k(i + 1, j + 1), k(i + 1, j)
                tri += [[a, b, c], [a, c, d]]
        tri = np.array(tri)
        e = err_source_mesh(src, tri)
        if e <= TOL:
            return n, src, tri, e
    return n, src, tri, e


def target(lon0, lat_top):
    lat_bot = lat_top - DEG

    def inside(lon, lat):
        return (lon >= lon0 - 1e-9) & (lon <= lon0 + DEG + 1e-9) & (lat <= lat_top + 1e-9) & (lat >= lat_bot - 1e-9)

    # the tile's map bounding box, from a dense outline
    t = np.linspace(0, 1, 200)
    ol = np.r_[np.c_[lon0 + t * DEG, np.full_like(t, lat_top)], np.c_[lon0 + t * DEG, np.full_like(t, lat_bot)],
               np.c_[np.full_like(t, lon0), lat_top - t * DEG], np.c_[np.full_like(t, lon0 + DEG), lat_top - t * DEG]]
    bx, by = fwd(ol[:, 0], ol[:, 1])
    quads = []

    def corner_in(x, y):
        return inside(*inv(np.array(x), np.array(y)))

    def add(x0, y0, x1, y1, depth):
        cx, cy = np.array([x0, x1, x1, x0]), np.array([y0, y0, y1, y1])
        if not corner_in(cx, cy).any():
            # keep a quad the tile passes through without a corner inside it
            sx, sy = np.linspace(x0, x1, 5), np.linspace(y0, y1, 5)
            gx, gy = np.meshgrid(sx, sy)
            if not corner_in(gx.ravel(), gy.ravel()).any():
                return
        if depth < 10:
            lon, lat = inv(cx, cy)
            # the a-c diagonal midpoint, as OpenLayers tests it
            ml, mp = (lon[0] + lon[2]) / 2, (lat[0] + lat[2]) / 2
            ex, ey = fwd(ml, mp)
            if math.hypot(ex - (x0 + x1) / 2, ey - (y0 + y1) / 2) > TOL:
                if abs(x1 - x0) >= abs(y1 - y0):
                    xm = (x0 + x1) / 2
                    add(x0, y0, xm, y1, depth + 1)
                    add(xm, y0, x1, y1, depth + 1)
                else:
                    ym = (y0 + y1) / 2
                    add(x0, y0, x1, ym, depth + 1)
                    add(x0, ym, x1, y1, depth + 1)
                return
        quads.append((x0, y0, x1, y1))

    add(bx.min(), by.min(), bx.max(), by.max(), 0)
    xy, tri = [], []
    for x0, y0, x1, y1 in quads:
        i = len(xy)
        xy += [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
        tri += [[i, i + 1, i + 2], [i, i + 2, i + 3]]
    xy, tri = np.array(xy), np.array(tri)
    return xy, tri, err_target_mesh(xy, tri, inside)


def greedy(row):
    t = next(t for t in M["scenarios"]["pole"]["B1"] if t["col"] == 8 and t["row"] == row)
    uv = np.asarray(t["uv"]).reshape(-1, 2)
    src = np.c_[t["lon0"] + uv[:, 0] * t["deg"], t["latTop"] - uv[:, 1] * t["deg"]]
    tri = np.asarray(t["tri"]).reshape(-1, 3)
    return src, tri, err_source_mesh(src, tri)


rows = ["tile,strategy,triangles,true_max_error_P,note"]
out = {"P": P, "tiles": {}}
for name, (lon0, lat_top) in TILES.items():
    row = 0 if name == "outer" else 1
    out["tiles"][name] = {}
    n, src, tri, e = grid(lon0, lat_top)
    x, y = fwd(src[:, 0], src[:, 1])
    rows.append(f"{name},grid,{len(tri)},{e / P:.4f},{n}x{n} cells")
    out["tiles"][name]["grid"] = {"xy": np.c_[x, y].round().tolist(), "tri": tri.tolist()}
    xy, ttri, e = target(lon0, lat_top)
    rows.append(f"{name},target,{len(ttri)},{e / P:.4f},quadtree up to 10 levels")
    out["tiles"][name]["target"] = {"xy": xy.round().tolist(), "tri": ttri.tolist()}
    src, gtri, e = greedy(row)
    x, y = fwd(src[:, 0], src[:, 1])
    rows.append(f"{name},greedy,{len(gtri)},{e / P:.4f},deck.gl-raster with a shared unit")
    out["tiles"][name]["greedy"] = {"xy": np.c_[x, y].round().tolist(), "tri": gtri.tolist()}

(HERE / "results" / "strategies.csv").write_text("\n".join(rows) + "\n")
(HERE / "results" / "strategies.json").write_text(json.dumps(out))
print("\n".join(rows))
