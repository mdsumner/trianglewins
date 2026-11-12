"""Figures for the reprojection-mesh dev draft.

Run after run.mjs and ortho.mjs:  python3 figures.py [outdir]
"""

import json
import math
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
from matplotlib.collections import LineCollection, PolyCollection  # noqa: E402

HERE = Path(__file__).resolve().parent
RES = HERE / "results"
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else RES / "figures"
OUT.mkdir(parents=True, exist_ok=True)

M = json.loads((RES / "meshes.json").read_text())
O = json.loads((RES / "ortho-meshes.json").read_text())
P = M["P"]
INK, MUTED, ACCENT, WARN = "#1f2937", "#6b7280", "#2563eb", "#dc2626"
plt.rcParams.update({"font.size": 9, "axes.titlesize": 10, "axes.edgecolor": MUTED})


def tri_lines(xy, tri):
    xy = np.asarray(xy, float).reshape(-1, 2)
    t = np.asarray(tri).reshape(-1, 3)
    e = np.r_[t[:, [0, 1]], t[:, [1, 2]], t[:, [2, 0]]]
    e = np.unique(np.sort(e, axis=1), axis=0)
    return xy[e]


def draw(ax, xy, tri, color=INK, lw=0.25, scale=1.0, **kw):
    segs = tri_lines(xy, tri) * scale
    ax.add_collection(LineCollection(segs, colors=color, linewidths=lw, **kw))


def bare(ax):
    ax.set_aspect("equal")
    ax.set_xticks([])
    ax.set_yticks([])


def uv_to_lonlat(t, uv):
    uv = np.asarray(uv, float).reshape(-1, 2)
    return np.c_[t["lon0"] + uv[:, 0] * t["deg"], t["latTop"] - uv[:, 1] * t["deg"]]


# 1. the same two tiles in source lon/lat and on the polar map -----------------
ring = M["scenarios"]["pole"]["B0"]
pick = [t for t in ring if t["col"] in (8, 9)]
fig, (a, b) = plt.subplots(1, 2, figsize=(8, 4.2))
for t in pick:
    ll = uv_to_lonlat(t, t["uv"])
    col = ACCENT if t["row"] == 1 else INK
    draw(a, ll, t["tri"], color=col, lw=0.3)
    draw(b, t["xy"], t["tri"], color=col, lw=0.3, scale=1e-3)
a.set_xlim(-0.5, 45.5); a.set_ylim(-90.5, -44.5); a.set_aspect("equal")
a.set_xlabel("longitude"); a.set_ylabel("latitude")
a.set_title("Where the mesh is built: source lon/lat")
b.autoscale(); bare(b)
b.set_title("Where it is drawn: polar stereographic (km)")
fig.text(0.5, 0.005, "Four tiles (two columns, two rows) from the upstream mesher, 0.125 pixel tolerance. "
         "Blue: the polar row.", ha="center", color=MUTED)
fig.tight_layout(rect=(0, 0.06, 1, 1))
fig.savefig(OUT / "same-mesh.png", dpi=200)
plt.close(fig)

# 2. density per square degree and per area on the map --------------------------
fig, ax = plt.subplots(figsize=(6.5, 3.2))
ax2 = ax.twinx()
rows = []
for t in M["scenarios"]["pole"]["B1"]:
    uv = np.asarray(t["uv"]).reshape(-1, 2)
    xy = np.asarray(t["xy"], float).reshape(-1, 2)
    tri = np.asarray(t["tri"]).reshape(-1, 3)
    lat = (t["latTop"] - uv[:, 1] * t["deg"])[tri].mean(1)

    def area(p):
        a_, b_, c_ = p[tri[:, 0]], p[tri[:, 1]], p[tri[:, 2]]
        return 0.5 * np.abs((b_[:, 0] - a_[:, 0]) * (c_[:, 1] - a_[:, 1]) - (b_[:, 1] - a_[:, 1]) * (c_[:, 0] - a_[:, 0]))

    rows.append(np.c_[lat, area(uv * t["deg"]), area(xy) / 1e6])
d = np.vstack(rows)
bands = np.arange(-90, -45, 5)
per_deg = [((d[:, 0] >= lo) & (d[:, 0] < lo + 5)).sum() / d[(d[:, 0] >= lo) & (d[:, 0] < lo + 5), 1].sum() for lo in bands]
per_km = [1000 * ((d[:, 0] >= lo) & (d[:, 0] < lo + 5)).sum() / d[(d[:, 0] >= lo) & (d[:, 0] < lo + 5), 2].sum() for lo in bands]
x = bands + 2.5
ax.plot(x, per_deg, "o-", color=INK, label="per square degree (source)")
ax2.plot(x, per_km, "s--", color=ACCENT, label="per 1000 km$^2$ (map)")
ax.set_ylim(0, max(per_deg) * 1.3); ax2.set_ylim(0, max(per_km) * 1.1)
ax.set_xlabel("latitude band"); ax.set_ylabel("triangles per square degree")
ax2.set_ylabel("triangles per 1000 km$^2$", color=ACCENT)
ax.set_title("Mesh density by latitude, polar stereographic, one shared tolerance")
h1, l1 = ax.get_legend_handles_labels(); h2, l2 = ax2.get_legend_handles_labels()
ax.legend(h1 + h2, l1 + l2, loc="upper right", frameon=False)
fig.tight_layout()
fig.savefig(OUT / "density.png", dpi=200)
plt.close(fig)

# 3. a seam at a change of level -------------------------------------------------
fig, axs = plt.subplots(1, 2, figsize=(8, 4.2))
lod = M["scenarios"]["lod"]
for ax, var, title in ((axs[0], "B0", "Upstream: tolerance per tile"),
                       (axs[1], "B1", "One tolerance for the view")):
    tiles = [t for t in lod[var] if (t["level"] == 0 and t["col"] == 9) or (t["level"] == 1 and t["col"] in (18, 19) and t["row"] == 2)]
    edge_v = {}
    for t in tiles:
        col = INK if t["level"] == 0 else ACCENT
        draw(ax, t["xy"], t["tri"], color=col, lw=0.35, scale=1e-3)
        ll = uv_to_lonlat(t, t["uv"])
        on = np.abs(ll[:, 1] + 67.5) < 1e-9
        xy = np.asarray(t["xy"], float).reshape(-1, 2)[on] / 1e3
        for p, q in zip(map(tuple, np.round(ll[on], 9)), xy):
            edge_v.setdefault(p, []).append((t["level"], q))
    tj = [v[0][1] for v in edge_v.values() if len({lv for lv, _ in v}) == 1]
    if tj:
        tj = np.array(tj)
        ax.plot(tj[:, 0], tj[:, 1], "o", ms=3.5, mfc="none", mec=WARN, mew=1)
    ax.autoscale(); bare(ax)
    ax.set_title(f"{title}\n{len(tj)} T-junctions on this edge", color=INK)
fig.text(0.5, 0.01, "One coarse tile (black) above two tiles one level finer (blue), meeting on the 67.5 S parallel. "
         "Red rings: a vertex on one side only.", ha="center", color=MUTED)
fig.tight_layout(rect=(0, 0.04, 1, 1))
fig.savefig(OUT / "seam.png", dpi=200)
plt.close(fig)

# 4. orthographic hemisphere --------------------------------------------------
R = 6371008.8
fig, axs = plt.subplots(1, 2, figsize=(8, 4.6))
for ax, var, title in ((axs[0], "boxes-only", "Lon/lat box seeds: whole tiles only"),
                       (axs[1], "constrained", "Constrained seeds: tiles cut at the horizon")):
    th = np.linspace(0, 2 * math.pi, 400)
    ax.fill(R / 1e3 * np.cos(th), R / 1e3 * np.sin(th), color="#fde68a", lw=0)
    for t in O["variants"][var]:
        xy = np.asarray(t["xy"], float).reshape(-1, 2) / 1e3
        tri = np.asarray(t["tri"]).reshape(-1, 3)
        fc = "#e5e7eb" if t["full"] else "#bfdbfe"
        ax.add_collection(PolyCollection(xy[tri], facecolors=fc, edgecolors=fc, linewidths=0.2))
        # tile outline: mesh edges used by one triangle only
        e = np.r_[tri[:, [0, 1]], tri[:, [1, 2]], tri[:, [2, 0]]]
        es = np.sort(e, axis=1)
        u, n = np.unique(es, axis=0, return_counts=True)
        ax.add_collection(LineCollection(xy[u[n == 1]], colors=INK if t["full"] else ACCENT, linewidths=0.4))
    ax.set_xlim(-R / 1e3 * 1.02, R / 1e3 * 1.02); ax.set_ylim(-R / 1e3 * 1.02, R / 1e3 * 1.02); bare(ax)
    ax.set_title(title)
fig.text(0.5, 0.01, "Orthographic view centred on Hobart, 22.5 degree lon/lat tiles. Yellow: visible but not drawn. "
         "Blue: tiles cut at the horizon.", ha="center", color=MUTED)
fig.tight_layout(rect=(0, 0.04, 1, 0.97))
fig.savefig(OUT / "ortho.png", dpi=200)
plt.close(fig)
print("wrote", sorted(p.name for p in OUT.glob("*.png")))

# 5. overview: the whole polar disc, source-pixel vs screen-pixel tolerance --
fig, axs = plt.subplots(1, 2, figsize=(8, 4.8))
SUM = {(r["scenario"], r["variant"]): r for r in __import__("csv").DictReader(open(RES / "summary.csv"))}
for ax, var, title in ((axs[0], "B0", "Tolerance in source pixels (upstream)"),
                       (axs[1], "S", "Tolerance in screen pixels, 1000 px view")):
    for t in M["scenarios"]["ring"][var]:
        draw(ax, t["xy"], t["tri"], color=INK, lw=0.12, scale=1e-3)
    ax.autoscale(); bare(ax)
    ax.set_title(f"{title}\n{int(SUM[('ring', var)]['triangles_total']):,} triangles", fontsize=9)
fig.text(0.5, 0.01, "32 lon/lat tiles from 45 S to the pole in polar stereographic, one overview level, both at 0.125 of their pixel.",
         ha="center", color=MUTED, fontsize=8)
fig.tight_layout(rect=(0, 0.04, 1, 0.97))
fig.savefig(OUT / "overview.png", dpi=200)
plt.close(fig)

# 6. three strategies on the same polar tile ----------------------------------
S3 = json.loads((RES / "strategies.json").read_text())
import csv  # noqa: E402

stats = {(r["tile"], r["strategy"]): r for r in csv.DictReader(open(RES / "strategies.csv"))}
fig, axs = plt.subplots(1, 3, figsize=(9, 3.9))
labels = {"grid": "Fixed grid in the source\n(MapLibre globe style)",
          "target": "Quadtree on the map\n(OpenLayers style)",
          "greedy": "Greedy in the source\n(deck.gl-raster)"}
for ax, k in zip(axs, ("grid", "target", "greedy")):
    m = S3["tiles"]["polar"][k]
    draw(ax, m["xy"], m["tri"], color=INK if k != "target" else ACCENT, lw=0.25, scale=1e-3)
    s = stats[("polar", k)]
    ax.autoscale(); bare(ax)
    ax.set_title(f"{labels[k]}\n{int(s['triangles']):,} triangles, worst error {float(s['true_max_error_P']):.2f} px", fontsize=8.5)
    if k == "target":
        lim = 1.05 * np.abs(np.asarray(S3["tiles"]["polar"]["greedy"]["xy"], float)).max() / 1e3
        ax.set_xlim(-0.05 * lim, lim); ax.set_ylim(-0.05 * lim, lim)
fig.text(0.5, 0.01, "One 22.5 degree lon/lat tile from 67.5 S to the pole, polar stereographic, target 0.125 px. "
         "The quadtree also covers map area outside the tile.", ha="center", color=MUTED, fontsize=8)
fig.tight_layout(rect=(0, 0.05, 1, 1))
fig.savefig(OUT / "strategies.png", dpi=200)
plt.close(fig)

# 7. a polar-native raster in Equal Earth --------------------------------------
A = json.loads((RES / "antimeridian-meshes.json").read_text())
half = A["worldHalf"] / 1e3
fig, axs = plt.subplots(2, 1, figsize=(8, 6.6))
for ax, var, title in ((axs[0], "one-mesh", "One mesh per tile (upstream)"),
                       (axs[1], "cut", "Tiles clipped to the hemisphere and cut at the antimeridian")):
    for i, t in enumerate(A["variants"][var]):
        xy = np.asarray(t["xy"], float).reshape(-1, 2) / 1e3
        tri = np.asarray(t["tri"]).reshape(-1, 3)
        fc = "#bfdbfe" if (t["crosses"] and var == "cut") else ("#fecaca" if not t["converged"] else "#e5e7eb")
        ax.add_collection(PolyCollection(xy[tri], facecolors=fc, edgecolors=INK, linewidths=0.05, alpha=0.55))
    ax.plot([-half, half, half, -half, -half], [0, 0, -half * 0.49, -half * 0.49, 0], color=MUTED, lw=0)
    ax.set_xlim(-half * 1.03, half * 1.03); ax.set_ylim(-half * 0.53, half * 0.08); bare(ax)
    ax.axhline(0, color=MUTED, lw=0.5)
    ax.set_title(title)
fig.text(0.5, 0.01, "Southern hemisphere of a south polar stereographic raster (5 x 5 tiles) drawn in Equal Earth. "
         "Red: did not converge. Blue: tiles cut in two.", ha="center", color=MUTED, fontsize=8)
fig.tight_layout(rect=(0, 0.03, 1, 1))
fig.savefig(OUT / "antimeridian.png", dpi=200)
plt.close(fig)
print("wrote", sorted(p.name for p in OUT.glob("*.png")))
