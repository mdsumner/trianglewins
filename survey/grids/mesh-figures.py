"""A raster is a mesh: figures for survey/grids.md.
    python3 survey/grids/mesh-figures.py docs/grids
Needs numpy and matplotlib. Writes:
  grid-mesh-tables.png   vertex pool, segment pairs, triangle triplets of a 3 x 2 grid
  grid-rings-vs-pool.png the same cells as polygon rings and as one vertex pool
  grid-same-topology.png one index mesh under four transforms, texture space included
Indexing as in survey/grids/grid-mesh.R: i is the column from the left,
j the row from the top, vertex ids 1-based.
"""
import sys
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

OUT = sys.argv[1] if len(sys.argv) > 1 else "docs/grids"
INK = "#222222"
MUTED = "#9a9a9a"
ACCENT = "#c0392b"
FILL = "#dfe8f1"


def grid_mesh(ncol, nrow):
    """Index topology only: vertex (i, j), segments, quads, triangles (0-based)."""
    vid = lambda i, j: j * (ncol + 1) + i
    vi, vj = np.meshgrid(np.arange(ncol + 1), np.arange(nrow + 1))
    vi, vj = vi.ravel(), vj.ravel()
    ci, cj = np.meshgrid(np.arange(ncol), np.arange(nrow))
    ci, cj = ci.ravel(), cj.ravel()
    a, b, c, d = vid(ci, cj), vid(ci + 1, cj), vid(ci + 1, cj + 1), vid(ci, cj + 1)
    tri = np.vstack([np.column_stack([a, b, c]), np.column_stack([a, c, d])])
    hi, hj = np.meshgrid(np.arange(ncol), np.arange(nrow + 1))
    wi, wj = np.meshgrid(np.arange(ncol + 1), np.arange(nrow))
    hseg = np.column_stack([vid(hi.ravel(), hj.ravel()), vid(hi.ravel() + 1, hj.ravel())])
    wseg = np.column_stack([vid(wi.ravel(), wj.ravel()), vid(wi.ravel(), wj.ravel() + 1)])
    dseg = np.column_stack([a, c])
    return vi, vj, hseg, wseg, dseg, np.column_stack([a, b, c, d]), tri


def affine(vi, vj, gt):
    """GDAL geotransform: x = gt0 + i gt1 + j gt2, y = gt3 + i gt4 + j gt5."""
    return gt[0] + vi * gt[1] + vj * gt[2], gt[3] + vi * gt[4] + vj * gt[5]


def frame(ax, title):
    ax.set_title(title, fontsize=11, color=INK, loc="left")
    ax.set_aspect("equal")
    ax.axis("off")


def draw_segments(ax, x, y, seg, **kw):
    for s in seg:
        ax.plot(x[s], y[s], solid_capstyle="round", **kw)


# ---- figure 1: the three tables of a 3 x 2 grid --------------------------
NC, NR = 3, 2
vi, vj, hseg, wseg, dseg, quad, tri = grid_mesh(NC, NR)
x, y = affine(vi, vj, (0, 1, 0, NR, 0, -1))  # bbox 0 0 3 2

fig, axes = plt.subplots(1, 3, figsize=(12, 3.4))
ax = axes[0]
frame(ax, "vertex pool: 12 corners, each once")
draw_segments(ax, x, y, np.vstack([hseg, wseg]), color=MUTED, lw=1)
ax.scatter(x, y, s=180, color="white", edgecolor=INK, zorder=3)
for k in range(len(x)):
    ax.text(x[k], y[k], str(k + 1), ha="center", va="center", fontsize=8, zorder=4)

ax = axes[1]
frame(ax, "segments: 23 pairs, diagonals in red")
draw_segments(ax, x, y, np.vstack([hseg, wseg]), color=INK, lw=1.4)
draw_segments(ax, x, y, dseg, color=ACCENT, lw=1.8)
ax.scatter(x, y, s=18, color=INK, zorder=3)
s = dseg[0]
ax.annotate(f"({s[0] + 1}, {s[1] + 1})", xy=(x[s].mean(), y[s].mean()),
            xytext=(0.62, 1.55), fontsize=9, color=ACCENT,
            arrowprops=dict(arrowstyle="-", color=ACCENT, lw=0.8))

ax = axes[2]
frame(ax, "triangles: 12 triplets sharing the diagonal")
for k, t in enumerate(tri):
    ax.fill(x[t], y[t], facecolor=FILL if k < len(tri) // 2 else "white",
            edgecolor=INK, lw=1)
    ax.text(x[t].mean(), y[t].mean(), str(k + 1), ha="center", va="center", fontsize=8)
draw_segments(ax, x, y, dseg, color=ACCENT, lw=1.8)
fig.tight_layout()
fig.savefig(os.path.join(OUT, "grid-mesh-tables.png"), dpi=130)
plt.close(fig)

# ---- figure 2: rings against the pool ------------------------------------
fig, axes = plt.subplots(1, 2, figsize=(9, 3.6))
ax = axes[0]
frame(ax, "as polygon rings: 24 corners, 7 edges twice")
inset = 0.08
for q in quad:
    qx, qy = x[q], y[q]
    cx, cy = qx.mean(), qy.mean()
    rx, ry = cx + (qx - cx) * (1 - 2 * inset), cy + (qy - cy) * (1 - 2 * inset)
    ax.fill(np.r_[rx, rx[0]], np.r_[ry, ry[0]], facecolor=FILL, edgecolor=INK, lw=1)
    ax.scatter(rx, ry, s=14, color=INK, zorder=3)
ax.text(1.5, -0.32, "each cell stores its own corners; shared edges are drawn by both owners",
        ha="center", fontsize=8, color=MUTED)

ax = axes[1]
frame(ax, "as a mesh: 12 corners, every edge once")
for q in quad:
    ax.fill(x[q], y[q], facecolor=FILL, edgecolor=INK, lw=1)
ax.scatter(x, y, s=14, color=INK, zorder=3)
ax.text(1.5, -0.32, "cells are index quadruples into one vertex pool",
        ha="center", fontsize=8, color=MUTED)
fig.tight_layout()
fig.savefig(os.path.join(OUT, "grid-rings-vs-pool.png"), dpi=130)
plt.close(fig)

# ---- figure 3: one topology, four geometries ------------------------------
NC, NR = 6, 4
vi, vj, hseg, wseg, dseg, quad, tri = grid_mesh(NC, NR)
th = np.radians(25)
geoms = [
    ("regular: bbox (or a geotransform)", affine(vi, vj, (0, 1, 0, NR, 0, -1))),
    ("rotated: geotransform with shear terms",
     affine(vi, vj, (0, np.cos(th), np.sin(th), NR, np.sin(th), -np.cos(th)))),
]
# curvilinear: positions from arrays, here a polar sector
r = 2 + vj * 0.6
a = np.radians(30 + vi * 15)
geoms.append(("curvilinear: x and y from arrays", (r * np.cos(a), r * np.sin(a))))
geoms.append(("texture: u = i / ncol, v = j / nrow", (vi / NC, -(vj / NR))))  # v grows downward, like rows

fig, axes = plt.subplots(1, 4, figsize=(14, 3.4))
for ax, (title, (gx, gy)) in zip(axes, geoms):
    frame(ax, title)
    for k, t in enumerate(tri):
        # shade the first triangle of every cell, so the diagonal shows
        shade = FILL if k < NC * NR else "white"
        ax.fill(gx[t], gy[t], facecolor=shade, edgecolor=MUTED, lw=0.6)
    draw_segments(ax, gx, gy, np.vstack([hseg, wseg]), color=INK, lw=0.9)
    k = 0  # vertex 1 marked in every panel
    ax.scatter(gx[k], gy[k], s=30, color=ACCENT, zorder=4)
fig.suptitle("the same vertex pool, segments and triangles; only the vertex positions change",
             fontsize=10, color=MUTED, y=0.04)
fig.tight_layout(rect=(0, 0.06, 1, 1))
fig.savefig(os.path.join(OUT, "grid-same-topology.png"), dpi=130)
plt.close(fig)
print("wrote", OUT)
