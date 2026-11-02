"""Sizing fields and map projections: figures and numbers for survey/sizing.md.

    python3 survey/sizing/experiments.py docs/sizing
Needs numpy, matplotlib and triangle (Shewchuk's Triangle, the same
Delaunay-refinement family as laridae/CGAL).

1. Northern hemisphere, polar aspect, min angle 30 requested in the CRS:
   uniform in stereographic, stereographic + a compensating scalar field
   (CRS area = ground area * k^2), and uniform in Lambert azimuthal
   equal-area. Judged on the sphere.
2. Unit square: laridae's linear area field by the engine and by a stretch
   map, and an exponential field by the engine and by a conformal map.
"""
import os, json
import numpy as np
import triangle
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

import sys
OUT = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)
QUAL = "q30"


def mesh_uniform(V, S, area):
    return triangle.triangulate(dict(vertices=V, segments=S), "p%sa%.10f" % (QUAL, area))


def mesh_field(V, S, area_fun, start, maxit=40):
    """Refine until every triangle meets area_fun(centroid); area_fun in mesh coords."""
    t = triangle.triangulate(dict(vertices=V, segments=S), "p%sa%.10f" % (QUAL, start))
    for _ in range(maxit):
        P, T = t["vertices"], t["triangles"]
        c = P[T].mean(axis=1)
        want = area_fun(c[:, 0], c[:, 1])
        if np.all(tri_area2d(P, T) <= want * 1.0001):
            break
        t = triangle.triangulate(dict(vertices=P, segments=t["segments"], triangles=T,
                                      triangle_max_area=want), "rp%sa" % QUAL)
    return t


def tri_area2d(P, T):
    a, b, c = P[T[:, 0]], P[T[:, 1]], P[T[:, 2]]
    return 0.5 * np.abs((b[:, 0] - a[:, 0]) * (c[:, 1] - a[:, 1]) - (b[:, 1] - a[:, 1]) * (c[:, 0] - a[:, 0]))


def tri_metrics(X, T):
    """area and min angle (deg) of triangles with vertices X (2D or 3D)."""
    a, b, c = X[T[:, 0]], X[T[:, 1]], X[T[:, 2]]
    def ang(p, q, r):
        u, v = q - p, r - p
        cs = np.sum(u * v, 1) / np.linalg.norm(u, axis=1) / np.linalg.norm(v, axis=1)
        return np.degrees(np.arccos(np.clip(cs, -1, 1)))
    A = np.stack([ang(a, b, c), ang(b, c, a), ang(c, a, b)], 1)
    if X.shape[1] == 2:
        X3 = np.c_[X, np.zeros(len(X))]
        a, b, c = X3[T[:, 0]], X3[T[:, 1]], X3[T[:, 2]]
    area = 0.5 * np.linalg.norm(np.cross(b - a, c - a), axis=1)
    return area, A.min(1)


def edges_of(T):
    E = np.sort(np.r_[T[:, [0, 1]], T[:, [1, 2]], T[:, [2, 0]]], 1)
    return np.unique(E, axis=0)


# ---------------------------------------------------------------- 1. sphere
# Northern hemisphere (colatitude 0..90 deg), unit sphere, polar aspect.
# stereographic (conformal): r = 2 tan(c/2), point scale k = sec^2(c/2) = 1 + r^2/4
# Lambert azimuthal equal-area: r = 2 sin(c/2), area scale 1, Tissot axes cos(c/2), sec(c/2)
proj = {
    "stereographic": dict(r=lambda c: 2 * np.tan(c / 2), inv=lambda r: 2 * np.arctan(r / 2)),
    "laea": dict(r=lambda c: 2 * np.sin(c / 2), inv=lambda r: 2 * np.arcsin(np.clip(r / 2, 0, 1))),
}


def to_sphere(P, inv):
    r = np.hypot(P[:, 0], P[:, 1]); t = np.arctan2(P[:, 1], P[:, 0]); c = inv(r)
    return np.c_[np.sin(c) * np.cos(t), np.sin(c) * np.sin(t), np.cos(c)]


def disc(R, h):
    """circle of radius R densified to edge length about h (in the mesh CRS)."""
    n = int(np.ceil(2 * np.pi * R / h))
    t = np.linspace(0, 2 * np.pi, n, endpoint=False)
    V = np.c_[R * np.cos(t), R * np.sin(t)]
    S = np.c_[np.arange(n), (np.arange(n) + 1) % n]
    return V, S


def delaunay_violations(X, T):
    """fraction of interior edges that fail the empty-circumcap test on the sphere."""
    from collections import defaultdict
    opp = defaultdict(list)
    for t in T:
        for i in range(3):
            e = tuple(sorted((t[i], t[(i + 1) % 3])))
            opp[e].append((t, t[(i + 2) % 3]))
    bad = n = 0
    for e, lst in opp.items():
        if len(lst) != 2:
            continue
        n += 1
        (t, _), (_, d) = lst
        a, b, c = X[t[0]], X[t[1]], X[t[2]]
        nrm = np.cross(b - a, c - a)
        if np.dot(nrm, a) < 0:
            nrm = -nrm
        bad += np.dot(nrm, X[d] - a) > 1e-14
    return bad / n


def edge_bulge(P, X, T, inv):
    """deviation of the image of a straight P-edge from the great circle, / edge length."""
    E = edges_of(T)
    mP = 0.5 * (P[E[:, 0]] + P[E[:, 1]])
    mX = to_sphere(mP, inv)
    g = X[E[:, 0]] + X[E[:, 1]]; g /= np.linalg.norm(g, axis=1)[:, None]
    L = np.arccos(np.clip(np.sum(X[E[:, 0]] * X[E[:, 1]], 1), -1, 1))
    dev = np.arccos(np.clip(np.sum(mX * g, 1), -1, 1))
    return dev / L


H = lambda A: 1.52 * np.sqrt(A)  # edge length of an equilateral triangle of area A
A_GROUND = 0.002  # target ground area (unit sphere), about 3000 triangles on the hemisphere
cases = {}
c90 = np.pi / 2
for name, pr in proj.items():
    R = pr["r"](c90)
    if name == "stereographic":
        # uniform in the CRS: right size at the pole (k = 1), k = 2 at the equator
        cases["stereo uniform"] = (mesh_uniform(*disc(R, H(A_GROUND)), A_GROUND), pr)
        # compensating scalar field: CRS area = ground area * k^2
        k2 = lambda x, y: (1 + (x * x + y * y) / 4) ** 2
        cases["stereo + field"] = (mesh_field(*disc(R, H(A_GROUND * 4)),
                                              lambda x, y: A_GROUND * k2(x, y), 0.05), pr)
    else:
        cases["laea uniform"] = (mesh_uniform(*disc(R, H(A_GROUND)), A_GROUND), pr)

rows = []
fig, ax = plt.subplots(2, 3, figsize=(13, 8.5))
for j, (name, (t, pr)) in enumerate(cases.items()):
    P, T = t["vertices"], t["triangles"]
    X = to_sphere(P, pr["inv"])
    area, amin = tri_metrics(X, T)
    cx = X[T].mean(1); colat = np.degrees(np.arccos(cx[:, 2] / np.linalg.norm(cx, axis=1)))
    _, amin_p = tri_metrics(P, T)
    bulge = edge_bulge(P, X, T, pr["inv"])
    row = dict(case=name, n_tri=len(T),
               median_ground_area_pole_band=float(np.median(area[colat < 30])),
               median_ground_area_equator_band=float(np.median(area[colat > 75])),
               pole_over_equator=float(np.median(area[colat < 30]) / np.median(area[colat > 75])),
               min_angle_in_mesh_crs=float(amin_p.min()),
               min_angle_on_sphere=float(amin.min()),
               min_angle_on_sphere_p01=float(np.percentile(amin, 1)),
               delaunay_violation_frac_on_sphere=float(delaunay_violations(X, T)),
               edge_bulge_max=float(bulge.max()), edge_bulge_median=float(np.median(bulge)))
    rows.append(row)
    a = ax[0, j]
    a.tripcolor(X[:, 0], X[:, 1], T, facecolors=np.log10(area), cmap="viridis",
                edgecolors="k", linewidth=0.1, vmin=np.log10(A_GROUND) - 1.2, vmax=np.log10(A_GROUND) + 0.3)
    a.set_aspect(1); a.set_title("%s\n%d triangles (orthographic view from pole)" % (name, len(T)), fontsize=10)
    a.set_xticks([]); a.set_yticks([])
    b = ax[1, j]
    b.hist(amin, bins=40, color="0.4"); b.axvline(30, color="r", lw=1)
    b.set_xlabel("min angle on the sphere (deg), red = 30 deg requested in the CRS")
    b.set_title("median ground area, pole band / equator band = %.2f" % row["pole_over_equator"], fontsize=10)
fig.suptitle("Hemisphere: colour is log10 ground area (same scale in all panels)")
fig.tight_layout(); fig.savefig(os.path.join(OUT, "hemisphere.png"), dpi=110)

# ------------------------------------------------------- 2. unit square fields
# (a) laridae article's field area(x) = 0.0005 + 0.01 x  (not log-harmonic)
# (b) same field by a separable stretch map x' = G(x), G' = c / area(x)
# (c) exponential field area(x) = 0.0005 * 21^x  (log-linear, so log h IS harmonic)
#     realised exactly by the conformal map w = exp(-lam z), lam = log(21)/2
a0, a1 = 0.0005, 0.01
fa = lambda x, y: a0 + a1 * x
fe = lambda x, y: a0 * 21.0 ** x

def square(n=40):
    s = np.linspace(0, 1, n, endpoint=False)
    V = np.r_[np.c_[s, 0 * s], np.c_[1 + 0 * s, s], np.c_[1 - s, 1 + 0 * s], np.c_[0 * s, 1 - s]]
    m = len(V); S = np.c_[np.arange(m), (np.arange(m) + 1) % m]
    return V, S

V, S = square(1)    # corners only; Triangle splits segments as needed
VC, SC = square(24) # the conformal case needs the boundary densified in the map CRS
# (b) stretch map
c = 0.002
G = lambda x: c / a1 * np.log((a0 + a1 * x) / a0)
Ginv = lambda u: (a0 * np.exp(u * a1 / c) - a0) / a1
VP = np.c_[G(V[:, 0]), V[:, 1]]
tb = mesh_uniform(VP, S, c)
sq_b = (np.c_[Ginv(tb["vertices"][:, 0]), tb["vertices"][:, 1]], tb["triangles"], fa)

# (c) conformal exponential map; boundary densified in P is the image of the square boundary
lam = np.log(21) / 2
fwd = lambda Z: np.c_[np.exp(-lam * Z[:, 0]) * np.cos(-lam * Z[:, 1]), np.exp(-lam * Z[:, 0]) * np.sin(-lam * Z[:, 1])]
def inv_c(W):
    return np.c_[-np.log(np.hypot(W[:, 0], W[:, 1])) / lam, -np.arctan2(W[:, 1], W[:, 0]) / lam]
# |f'|^2 = lam^2 exp(-2 lam x) = lam^2 / 21^x, so P area = ground area * lam^2 / 21^x = a0 lam^2
tc = mesh_uniform(fwd(VC), SC, a0 * lam ** 2)
sq_c = (inv_c(tc["vertices"]), tc["triangles"], fe)
td = mesh_field(V, S, fe, 0.01)
sq_d = (td["vertices"], td["triangles"], fe)
ta = mesh_field(V, S, fa, 0.01)
sq_a = (ta["vertices"], ta["triangles"], fa)

panels = [("(a) engine field, area = 0.0005 + 0.01x", sq_a),
          ("(b) stretch map x'=G(x), same field", sq_b),
          ("(c) conformal map exp(-lam z), area = 0.0005*21^x", sq_c),
          ("(d) engine field, area = 0.0005*21^x", sq_d)]
fig, ax = plt.subplots(2, 4, figsize=(17, 8.5))
for j, (name, (X, T, f)) in enumerate(panels):
    area, amin = tri_metrics(X, T)
    cen = X[T].mean(1); ratio = area / f(cen[:, 0], cen[:, 1])
    rows.append(dict(case="square " + name, n_tri=len(T),
                     area_over_target_median=float(np.median(ratio)),
                     area_over_target_p95=float(np.percentile(ratio, 95)),
                     min_angle_ground=float(amin.min()),
                     min_angle_ground_p01=float(np.percentile(amin, 1)),
                     min_angle_ground_median=float(np.median(amin))))
    a = ax[0, j]; a.triplot(X[:, 0], X[:, 1], T, lw=0.25, color="k")
    a.set_aspect(1); a.set_title(name + "\n%d triangles" % len(T), fontsize=9)
    b = ax[1, j]; b.hist(amin, bins=40, color="0.4", range=(0, 60)); b.axvline(30, color="r", lw=1)
    b.set_xlabel("min angle in the output (deg)")
fig.tight_layout(); fig.savefig(os.path.join(OUT, "square.png"), dpi=110)

for r in rows:
    print(r)
