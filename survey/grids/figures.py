"""Delaunay in what? One small grid, three frames.

Figure and numbers for survey/grids.md:
    python3 survey/grids/figures.py docs/grids/delaunay-in-what.png
Needs numpy, scipy, matplotlib and pyproj.

A 10 x 10 block of NSIDC 25 km south polar stereographic cell centres
(EPSG:3412, regular in that frame) is triangulated three ways:
  lonlat : Delaunay of (longitude, latitude) as planar x, y
  3412   : Delaunay of the projected (x, y), the grid's native frame
  xyz    : convex hull of geocentric unit vectors (spherical Delaunay)
Each triangulation is drawn and judged in the grid's own index space.

Measures, per frame:
  in_cell : share of triangles whose three vertices lie in one index
            cell (i and j each span at most 1), i.e. a quad half
  diag_ne : of those, the share using the (i, j)-(i+1, j+1) diagonal
  same_as : triangles identical to the xyz (spherical) triangulation
"""
import sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from pyproj import Transformer
from scipy.spatial import Delaunay, ConvexHull

N = 10
STEP = 25000.0
to_ll = Transformer.from_crs("EPSG:3412", "EPSG:4326", always_xy=True)

def block(x0, y0):
    i, j = np.meshgrid(np.arange(N), np.arange(N))
    i, j = i.ravel(), j.ravel()
    x = x0 + i * STEP
    y = y0 + j * STEP
    lon, lat = to_ll.transform(x, y)
    return i, j, x, y, np.asarray(lon), np.asarray(lat)

def tri_planar(a, b):
    return Delaunay(np.column_stack([a, b])).simplices

def tri_sphere(lon, lat):
    lo, la = np.radians(lon), np.radians(lat)
    xyz = np.column_stack([np.cos(la) * np.cos(lo), np.cos(la) * np.sin(lo), np.sin(la)])
    hull = ConvexHull(xyz)
    keep = []
    for s, eq in zip(hull.simplices, hull.equations):
        c = xyz[s].mean(axis=0)
        # a facet of the surface faces outward along its own position;
        # the lid and the walls along the block's rim face elsewhere
        if eq[:3] @ (c / np.linalg.norm(c)) > 0.99:
            keep.append(s)
    return np.array(keep)

def key(t):
    return {tuple(sorted(r)) for r in t.tolist()}

def measure(name, t, i, j, ref):
    span_i = i[t].max(axis=1) - i[t].min(axis=1)
    span_j = j[t].max(axis=1) - j[t].min(axis=1)
    cell = (span_i <= 1) & (span_j <= 1)
    ne = 0
    for r in t[cell]:
        ii, jj = i[r], j[r]
        lo = (ii == ii.min()) & (jj == jj.min())
        hi = (ii == ii.max()) & (jj == jj.max())
        ne += int(lo.any() and hi.any())
    same = len(key(t) & ref)
    return dict(frame=name, triangles=len(t), in_cell=cell.mean(),
                diag_ne=ne / max(cell.sum(), 1), same_as_xyz=same / len(t))

def run(label, x0, y0, ax_row):
    i, j, x, y, lon, lat = block(x0, y0)
    tris = {"lonlat": tri_planar(lon, lat), "3412": tri_planar(x, y), "xyz": tri_sphere(lon, lat)}
    ref = key(tris["xyz"])
    rows = [measure(k, v, i, j, ref) for k, v in tris.items()]
    print(f"\n{label}: lat {lat.min():.1f} to {lat.max():.1f}, lon {lon.min():.1f} to {lon.max():.1f}")
    print(f"{'frame':8s} {'tris':>5s} {'in_cell':>8s} {'diag_ne':>8s} {'same_as_xyz':>12s}")
    for r in rows:
        print(f"{r['frame']:8s} {r['triangles']:5d} {r['in_cell']:8.2f} {r['diag_ne']:8.2f} {r['same_as_xyz']:12.2f}")
    for ax, (k, t) in zip(ax_row, tris.items()):
        ax.triplot(i, j, t, lw=0.6, color="0.2")
        ax.set_aspect("equal"); ax.set_xticks([]); ax.set_yticks([])
        ax.set_title(f"{label}: Delaunay in {k}", fontsize=9)
    return rows

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "docs/grids/delaunay-in-what.png"
    fig, axes = plt.subplots(2, 3, figsize=(9, 6.4))
    run("pole", -N / 2 * STEP + STEP / 2, -N / 2 * STEP + STEP / 2, axes[0])
    run("60S", -N / 2 * STEP + STEP / 2, 3300000.0, axes[1])
    fig.suptitle("One 10 x 10 block of the NSIDC grid, drawn in index space", fontsize=10)
    fig.tight_layout()
    fig.savefig(out, dpi=130)
