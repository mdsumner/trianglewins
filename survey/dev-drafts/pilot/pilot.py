# Pilot of the geoarrow.triangles Parquet default at scale.
#   python survey/dev-drafts/pilot/pilot.py [n_points]
import os, sys, time, json, tempfile
import numpy as np, pyarrow as pa, pyarrow.parquet as pq, pyarrow.ipc as ipc
from scipy.spatial import Delaunay
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import geoarrow_triangles as gt

n = int(sys.argv[1]) if len(sys.argv) > 1 else 1_000_000
out = tempfile.mkdtemp()
rng = np.random.default_rng(1)
res = {}
def clock(label, f):
    t0 = time.perf_counter(); v = f(); res[label] = round(time.perf_counter() - t0, 3); return v
def size(p): return os.path.getsize(p)

gt.register()
# projected-looking coordinates (metres, full double precision)
xy0 = np.column_stack([rng.uniform(500000, 600000, n), rng.uniform(5.2e6, 5.3e6, n)])
tri0 = clock("delaunay_s", lambda: Delaunay(xy0).simplices)
tri0 = gt.orient_ccw(xy0, tri0)
xy, tri = clock("canonical_order_s", lambda: gt.canonical_order(xy0, tri0))
m = len(tri)
res.update(points=n, vertices=len(xy), triangles=m,
           ccw=bool((gt.signed_area2(xy, tri) > 0).all()))
meta = {"vertex_identity": "exact_float"}
arr = clock("build_array_s", lambda: gt.from_mesh(xy, tri, meta))

# sibling columns: per-triangle depth and constrained flags (all false here)
depth = pa.array(np.ones(m, dtype=np.int32))
cons = pa.FixedSizeListArray.from_arrays(pa.array(np.zeros(3 * m, dtype=bool)), 3)
extra = {"depth": depth, "constrained": cons}

# IPC with and without deltas
p_ipc = os.path.join(out, "mesh.arrow"); p_ipcd = os.path.join(out, "mesh-delta.arrow")
clock("ipc_write_s", lambda: gt.write_ipc(p_ipc, arr, deltas=False, extra=extra))
clock("ipc_delta_write_s", lambda: gt.write_ipc(p_ipcd, arr, deltas=True, extra=extra))
t_ipc = clock("ipc_delta_read_s", lambda: gt.read_ipc(p_ipcd))
ch = t_ipc.column("triangles").chunks
xy_r, tri_r = gt.to_mesh(ch[-1].storage) if False else (None, None)
# every batch sees a prefix of the final dictionary; ids are global
last = ch[-1].storage.values.dictionary
ids = np.concatenate([c.storage.values.indices.to_numpy() for c in ch]).reshape(-1, 3)
res["ipc_batches"] = len(ch)
res["ipc_delta_ids_equal"] = bool(np.array_equal(ids, tri))
res["ipc_delta_dict_equal"] = bool(np.array_equal(
    np.column_stack([last.field("x").to_numpy(), last.field("y").to_numpy()]), xy))

# Parquet, decoded layout (the default)
p_pq = os.path.join(out, "mesh.parquet")
clock("parquet_write_s", lambda: gt.write_parquet(p_pq, arr, extra=extra, compression="zstd"))
back, tab = clock("parquet_read_repool_s", lambda: gt.read_parquet(p_pq))
xy_b, tri_b = gt.to_mesh(back)
res["parquet_type_kept"] = isinstance(tab.column("triangles").type, gt.Triangles)
res["parquet_meta_kept"] = back.type.meta == meta
res["parquet_ids_preserved"] = bool(np.array_equal(tri_b, tri))
res["parquet_coords_bitwise_equal"] = bool(np.array_equal(xy_b.view(np.uint64), xy.view(np.uint64)))

# same mesh without canonical order: triangles equal, ids renumbered
arr_nc = gt.from_mesh(xy0, tri0, meta)
p_nc = os.path.join(out, "mesh-nc.parquet")
gt.write_parquet(p_nc, arr_nc, compression="zstd")
b2, _ = gt.read_parquet(p_nc)
xy2, tri2 = gt.to_mesh(b2)
res["noncanonical_ids_preserved"] = bool(np.array_equal(tri2, tri0))
res["noncanonical_same_triangles"] = bool(np.array_equal(xy2[tri2], xy0[tri0]))

# comparisons: option (c) two tables, and WKB polygons
p_v = os.path.join(out, "c-vertices.parquet"); p_t = os.path.join(out, "c-triangles.parquet")
pq.write_table(pa.table({"x": xy[:, 0], "y": xy[:, 1]}), p_v, compression="zstd")
pq.write_table(pa.table({"triangle": pa.FixedSizeListArray.from_arrays(pa.array(tri.ravel()), 3)}),
               p_t, compression="zstd")
import shapely
ring = xy[np.column_stack([tri, tri[:, :1]])]
wkb = clock("wkb_build_s", lambda: shapely.to_wkb(shapely.polygons(ring)))
p_wkb = os.path.join(out, "wkb.parquet")
pq.write_table(pa.table({"geometry": pa.array(wkb, pa.binary())}), p_wkb, compression="zstd")
res["bytes"] = {"ipc_dictionary": size(p_ipc), "ipc_dictionary_deltas": size(p_ipcd),
                "parquet_decoded_default": size(p_pq), "parquet_two_tables_c": size(p_v) + size(p_t),
                "parquet_wkb_polygons": size(p_wkb)}

# a reader that knows nothing about the type: DuckDB on the decoded Parquet
import duckdb
q = f"""select count(*) n,
  sum(((t[2].x - t[1].x) * (t[3].y - t[1].y) - (t[3].x - t[1].x) * (t[2].y - t[1].y)) / 2) area
  from (select triangles t from read_parquet('{p_pq}'))"""
n_dd, area_dd = clock("duckdb_query_s", lambda: duckdb.sql(q).fetchone())
area_np = float(gt.signed_area2(xy, tri).sum() / 2)
res["duckdb"] = {"rows": n_dd, "area_rel_diff": abs(area_dd - area_np) / area_np,
                 "type_seen": str(duckdb.sql(f"describe select * from read_parquet('{p_pq}')").fetchall()[0][1])}

# edge cases on a tiny mesh
sq = np.array([[0., 0.], [1., 0.], [0., 1.], [1., 1.], [5., 5.]])
t2 = np.array([[0, 1, 2], [1, 3, 2]])
b, _ = (lambda p: (gt.write_parquet(p, gt.from_mesh(sq, t2)), gt.read_parquet(p)))(os.path.join(out, "e1.parquet"))[1]
res["edge_unreferenced_vertex_dropped"] = len(gt.to_mesh(b)[0]) == 4
negz = np.array([[0., 0.], [1., 0.], [0., 1.], [-0., 0.], [1., 1.]])
t3 = np.array([[0, 1, 2], [3, 4, 2]])
p = os.path.join(out, "e2.parquet"); gt.write_parquet(p, gt.from_mesh(negz, t3)); b, _ = gt.read_parquet(p)
res["edge_negative_zero_kept_distinct"] = len(gt.to_mesh(b)[0]) == 5
dup = np.array([[0., 0.], [1., 0.], [0., 1.], [1., 0.], [1., 1.]])
t4 = np.array([[0, 1, 2], [3, 4, 2]])
p = os.path.join(out, "e3.parquet"); gt.write_parquet(p, gt.from_mesh(dup, t4)); b, _ = gt.read_parquet(p)
res["edge_duplicate_coords_merged"] = len(gt.to_mesh(b)[0]) == 4

import resource
res["peak_rss_mb"] = round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024)
gt.unregister()
res["versions"] = {"pyarrow": pa.__version__, "numpy": np.__version__, "duckdb": duckdb.__version__}
print(json.dumps(res, indent=1))
