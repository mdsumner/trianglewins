"""A sizing field from population density: figure and numbers for survey/sizing.md.

    python3 survey/sizing/population.py docs/sizing [cache-dir]
Needs numpy, matplotlib, triangle, shapely and pyproj. Downloads Natural
Earth populated places and 50m land from GitHub into cache-dir (default .).

The Americas mainland is meshed in an oblique stereographic CRS (conformal,
centred at 10N 80W). Ground density comes from a Gaussian kernel over Natural
Earth places weighted by pop_max. The target ground area of a triangle is a
fixed number of people divided by the density, and the CRS area is that times
the areal scale k^2 from PROJ. Three meshes with about the same vertex count:

  sampled  : points drawn in proportion to population, constrained Delaunay
             (no refinement), the usual "density with triangles" look
  area     : Delaunay refinement to the field, no angle bound
  area+q30 : Delaunay refinement to the field with min angle 30
"""
import os, sys, json, urllib.request
import numpy as np
import triangle
import shapely
from shapely.geometry import shape, Point
from pyproj import Proj
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
CACHE = sys.argv[2] if len(sys.argv) > 2 else "."
NE = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/"
rng = np.random.default_rng(2026)


def fetch(name):
    p = os.path.join(CACHE, name + ".geojson")
    if not os.path.exists(p):
        urllib.request.urlretrieve(NE + name + ".geojson", p)
    with open(p) as fh:
        return json.load(fh)


crs = Proj("+proj=stere +lat_0=10 +lon_0=-80 +k=1 +x_0=0 +y_0=0 +R=6371000 +units=km")

# --- the Americas mainland: largest land polygon with its centroid west of 30W
land = [shape(f["geometry"]) for f in fetch("ne_50m_land")["features"]]
polys = [g for G in land for g in getattr(G, "geoms", [G])]
polys = [g for g in polys if g.centroid.x < -30]
main = max(polys, key=lambda g: g.area)
lon, lat = np.asarray(main.exterior.coords).T
x, y = crs(lon, lat)
poly = shapely.Polygon(np.c_[x, y]).simplify(15)  # km
B = np.asarray(poly.exterior.coords)[:-1]
SB = np.c_[np.arange(len(B)), (np.arange(len(B)) + 1) % len(B)]

# --- population density on a 25 km grid (people per km2), kernel sigma 120 km
pl = fetch("ne_10m_populated_places_simple")["features"]
P = np.array([[f["properties"]["longitude"], f["properties"]["latitude"],
               max(f["properties"]["pop_max"], 0)] for f in pl], float)
px, py = crs(P[:, 0], P[:, 1])
keep = shapely.contains_xy(poly.buffer(50), px, py)
px, py, pw = px[keep], py[keep], P[keep, 2]
G = 25.0
x0, y0, x1, y1 = poly.bounds
gx = np.arange(x0, x1 + G, G); gy = np.arange(y0, y1 + G, G)
GX, GY = np.meshgrid(gx, gy)
sig = 120.0
dens = np.zeros_like(GX)
for i in range(0, len(px), 400):
    dx = GX[..., None] - px[i:i + 400]; dy = GY[..., None] - py[i:i + 400]
    dens += (pw[i:i + 400] * np.exp(-(dx * dx + dy * dy) / (2 * sig * sig))).sum(-1)
dens /= 2 * np.pi * sig * sig
dens += 2.0  # a rural floor, people per km2
inside = shapely.contains_xy(poly, GX, GY)

# areal scale k^2 of the CRS on the grid (PROJ factors)
glon, glat = crs(GX, GY, inverse=True)
k2 = crs.get_factors(glon, glat).areal_scale

N_TRI = 9000
P0 = (dens[inside] * G * G).sum() / N_TRI          # people per triangle
A_ground = np.clip(P0 / dens, 15.0 ** 2, 600.0 ** 2)  # km2
A_crs = A_ground * k2


def lookup(Z, xx, yy):
    i = np.clip(np.round((yy - y0) / G).astype(int), 0, len(gy) - 1)
    j = np.clip(np.round((xx - x0) / G).astype(int), 0, len(gx) - 1)
    return Z[i, j]


def refine(opts):
    t = triangle.triangulate(dict(vertices=B, segments=SB), "p" + opts + "a%f" % A_crs[inside].max())
    for _ in range(60):
        V, T = t["vertices"], t["triangles"]
        c = V[T].mean(1)
        want = lookup(A_crs, c[:, 0], c[:, 1])
        if np.all(area2(V, T) <= want * 1.0001):
            break
        t = triangle.triangulate(dict(vertices=V, segments=t["segments"], triangles=T,
                                      triangle_max_area=want), "rp" + opts + "a")
    return t


def area2(V, T):
    a, b, c = V[T[:, 0]], V[T[:, 1]], V[T[:, 2]]
    return 0.5 * np.abs((b[:, 0] - a[:, 0]) * (c[:, 1] - a[:, 1]) - (b[:, 1] - a[:, 1]) * (c[:, 0] - a[:, 0]))


def angles(V, T):
    out = []
    for i in range(3):
        p, q, r = V[T[:, i]], V[T[:, (i + 1) % 3]], V[T[:, (i + 2) % 3]]
        u, v = q - p, r - p
        cs = np.sum(u * v, 1) / np.linalg.norm(u, axis=1) / np.linalg.norm(v, axis=1)
        out.append(np.degrees(np.arccos(np.clip(cs, -1, 1))))
    A = np.stack(out, 1)
    return A.min(1), A.max(1)


meshes = {}
meshes["refined, min angle 30"] = refine("q30")
meshes["refined, area only"] = refine("")
nv = len(meshes["refined, min angle 30"]["vertices"])

# sampled: draw cells in proportion to people, jitter, keep those on land
w = (dens * G * G * inside).ravel(); w /= w.sum()
need = nv - len(B)
S = np.empty((0, 2))
while len(S) < need:
    idx = rng.choice(w.size, size=2 * need, p=w)
    s = np.c_[GX.ravel()[idx], GY.ravel()[idx]] + rng.uniform(-G / 2, G / 2, (2 * need, 2))
    s = s[shapely.contains_xy(poly.buffer(-5), s[:, 0], s[:, 1])]
    S = np.r_[S, s][:need]
meshes = {"sampled points, Delaunay": triangle.triangulate(
    dict(vertices=np.r_[B, S], segments=SB), "p"), **meshes}

rows = []
fig, ax = plt.subplots(2, 3, figsize=(15, 11.5), gridspec_kw=dict(height_ratios=[1.35, 1]))
zoom = (crs(-84, 33), crs(-68, 46))  # US north east
for j, (name, t) in enumerate(meshes.items()):
    V, T = t["vertices"], t["triangles"]
    amin, amax = angles(V, T)
    c = V[T].mean(1)
    ratio = area2(V, T) / lookup(A_crs, c[:, 0], c[:, 1])
    rows.append(dict(case=name, vertices=len(V), triangles=len(T),
                     obtuse_share=float(np.mean(amax > 90)),
                     min_angle_below_20_share=float(np.mean(amin < 20)),
                     min_angle_p01=float(np.percentile(amin, 1)),
                     min_angle_median=float(np.median(amin)),
                     area_over_target_median=float(np.median(ratio)),
                     area_over_target_p99=float(np.percentile(ratio, 99))))
    r = rows[-1]
    for a, lim in ((ax[0, j], None), (ax[1, j], zoom)):
        a.triplot(V[:, 0], V[:, 1], T, lw=0.15 if lim is None else 0.35, color="k")
        a.set_aspect(1); a.set_xticks([]); a.set_yticks([])
        if lim is not None:
            a.set_xlim(lim[0][0], lim[1][0]); a.set_ylim(lim[0][1], lim[1][1])
    ax[0, j].set_title("%s\n%d triangles, %.0f%% obtuse, %.0f%% with an angle under 20"
                       % (name, len(T), 100 * r["obtuse_share"], 100 * r["min_angle_below_20_share"]),
                       fontsize=10)
ax[1, 0].set_ylabel("US north east")
fig.tight_layout()
fig.savefig(os.path.join(OUT, "population.png"), dpi=100)
for r in rows:
    print(r)
print("people per triangle:", round(P0))
