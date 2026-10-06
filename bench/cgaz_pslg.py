"""CGAZ ADM0 GeoParquet -> planar straight line graphs as raw binary files.

usage: python3 -I cgaz_pslg.py CGAZ.parquet OUTDIR

Writes OUTDIR/<name>.bin: int32 header (nv, ns), float64 x[nv], y[nv],
int32 s0[ns], s1[ns] (1-based), plus OUTDIR/datasets.csv describing each.
"""
import sys, csv, os
import numpy as np
import pyarrow.parquet as pq
import shapely

src, out = sys.argv[1], sys.argv[2]
t = pq.read_table(src, columns=['shapeGroup', 'shapeName', 'geometry']).to_pydict()
geoms = {g: shapely.from_wkb(w) for g, w in zip(t['shapeGroup'], t['geometry'])}

SA = ['ARG', 'BOL', 'BRA', 'CHL', 'COL', 'ECU', 'GUY', 'PRY', 'PER', 'SUR', 'URY', 'VEN']
SAF = ['ZAF', 'LSO', 'SWZ', 'NAM', 'BWA', 'ZWE', 'MOZ', 'ZMB', 'MWI', 'AGO']
DATASETS = [
    ('kosovo', ['XKX'], 'one polygon, landlocked'),
    ('cuba', ['CUB'], 'main island plus keys'),
    ('southern_africa', SAF, 'coverage of 10 countries, shared borders'),
    ('norway', ['NOR'], 'fjords and skerries'),
    ('indonesia', ['IDN'], '248 islands'),
    ('canada', ['CAN'], 'arctic archipelago'),
    ('south_america', SA, 'coverage of 12 countries, shared borders'),
    ('world', sorted(geoms), 'every CGAZ country'),
]

def rings(geom):
    polys = list(geom.geoms) if geom.geom_type == 'MultiPolygon' else [geom]
    for p in polys:
        yield np.asarray(p.exterior.coords)[:-1, :2]
        for r in p.interiors:
            yield np.asarray(r.coords)[:-1, :2]

def pslg(codes, dedupe=True):
    xy, s0, s1, off = [], [], [], 0
    for c in codes:
        for r in rings(geoms[c]):
            n = len(r)
            if n < 3:
                continue
            xy.append(r)
            i = np.arange(n)
            s0.append(off + i); s1.append(off + (i + 1) % n)
            off += n
    xy = np.vstack(xy); s0 = np.concatenate(s0); s1 = np.concatenate(s1)
    if dedupe:
        u, inv = np.unique(xy, axis=0, return_inverse=True)
        inv = inv.ravel()
        a, b = inv[s0], inv[s1]
        lo, hi = np.minimum(a, b), np.maximum(a, b)
        keep = lo != hi
        seg = np.unique(np.stack([lo[keep], hi[keep]], 1), axis=0)
        xy, s0, s1 = u, seg[:, 0], seg[:, 1]
    return xy, s0 + 1, s1 + 1

def write(name, xy, s0, s1):
    with open(os.path.join(out, name + '.bin'), 'wb') as f:
        np.array([len(xy), len(s0)], dtype='<i4').tofile(f)
        np.ascontiguousarray(xy[:, 0], dtype='<f8').tofile(f)
        np.ascontiguousarray(xy[:, 1], dtype='<f8').tofile(f)
        np.asarray(s0, dtype='<i4').tofile(f)
        np.asarray(s1, dtype='<i4').tofile(f)

os.makedirs(out, exist_ok=True)
rows = []
for name, codes, note in DATASETS:
    xy, s0, s1 = pslg(codes)
    write(name, xy, s0, s1)
    rows.append((name, 'segments', len(xy), len(s0), ' '.join(codes) if len(codes) < 20 else 'all', note))
    print(name, len(xy), len(s0), flush=True)
## shared borders as given (every ring in full) for one coverage
xy, s0, s1 = pslg(SAF, dedupe=False)
write('southern_africa_rings', xy, s0, s1)
rows.append(('southern_africa_rings', 'segments', len(xy), len(s0), ' '.join(SAF),
             'the same coverage with every ring in full: shared borders twice'))
## point clouds sampled from the world's vertices
wxy, _, _ = pslg(sorted(geoms))
rng = np.random.default_rng(42)
for n in [10_000, 100_000, 1_000_000]:
    p = wxy[rng.choice(len(wxy), n, replace=False)]
    write('points_%d' % n, p, np.zeros(0, int), np.zeros(0, int))
    rows.append(('points_%d' % n, 'points', n, 0, 'all', 'points sampled from CGAZ vertices, no segments'))
with open(os.path.join(out, 'datasets.csv'), 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(['name', 'kind', 'vertices', 'segments', 'countries', 'note'])
    w.writerows(rows)
