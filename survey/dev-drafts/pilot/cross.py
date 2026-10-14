# Cross-language checks: read what pilot-r.R wrote, and write a mesh for it.
#   python survey/dev-drafts/pilot/cross.py <r-outdir> [n_points]
import os, sys, json
import numpy as np, pyarrow as pa, pyarrow.ipc as ipc, pyarrow.parquet as pq
from scipy.spatial import Delaunay
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import geoarrow_triangles as gt

d = sys.argv[1]; n = int(sys.argv[2]) if len(sys.argv) > 2 else 200_000
gt.register(); res = {}
ids = np.loadtxt(os.path.join(d, "inlandwaters-ids.csv"), delimiter=",", skiprows=1, dtype=np.int64)

t = ipc.open_file(os.path.join(d, "inlandwaters.arrow")).read_all()
col = t.column("triangles")
res["r_ipc_type"] = str(col.type)
res["r_ipc_meta"] = col.type.meta
xy_i, tri_i = gt.to_mesh(col.combine_chunks())
res["r_ipc_ids_equal"] = bool(np.array_equal(tri_i, ids))
res["r_ipc_ccw"] = bool((gt.signed_area2(xy_i, tri_i) > 0).all())

back, tab = gt.read_parquet(os.path.join(d, "inlandwaters.parquet"))
xy_p, tri_p = gt.to_mesh(back)
res["r_parquet_type_kept"] = isinstance(tab.column("triangles").type, gt.Triangles)
res["r_parquet_repool_ids_equal"] = bool(np.array_equal(tri_p, ids))
res["r_parquet_coords_equal_ipc"] = bool(np.array_equal(xy_p.view(np.uint64), xy_i.view(np.uint64)))
res["r_feature_column"] = tab.column("feature").type.__str__()

rng = np.random.default_rng(2)
xy0 = np.column_stack([rng.uniform(500000, 600000, n), rng.uniform(5.2e6, 5.3e6, n)])
tri0 = gt.orient_ccw(xy0, Delaunay(xy0).simplices)
xy, tri = gt.canonical_order(xy0, tri0)
p = os.path.join(d, "python-mesh.parquet")
gt.write_parquet(p, gt.from_mesh(xy, tri, {"vertex_identity": "exact_float"}),
                 row_group_size=100_000, compression="zstd")
np.savetxt(os.path.join(d, "python-mesh-ids.csv"), tri, fmt="%d", delimiter=",", header="v0,v1,v2", comments="")
res["python_parquet"] = {"path": p, "vertices": len(xy), "triangles": len(tri),
                         "row_groups": pq.ParquetFile(p).num_row_groups}
gt.unregister()
print(json.dumps(res, indent=1))
