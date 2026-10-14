# Check the laridae meshes written by laridae-mesh.R.
#   python survey/dev-drafts/pilot/laridae-check.py <outdir>
import os, sys, json
from fractions import Fraction
import numpy as np, pyarrow as pa, pyarrow.ipc as ipc, pyarrow.parquet as pq
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import geoarrow_triangles as gt

d = sys.argv[1]; gt.register(); res = {}
for name in ["lari-vic-nsw-act", "lari-minimal-mesh", "lari-polymer7-exact", "lari-polymer7-double"]:
    r = {}
    ids = np.loadtxt(os.path.join(d, name + "-ids.csv"), delimiter=",", skiprows=1, dtype=np.int64)
    t = ipc.open_file(os.path.join(d, name + ".arrow")).read_all()
    col = t.column("triangles").combine_chunks()
    xy, tri = gt.to_mesh(col)
    r["type"] = str(col.type); r["meta"] = col.type.meta
    r["ipc_ids_equal"] = bool(np.array_equal(tri, ids))
    back, tab = gt.read_parquet(os.path.join(d, name + ".parquet"))
    xy_b, tri_b = gt.to_mesh(back)
    r["parquet_ids_equal"] = bool(np.array_equal(tri_b, ids))
    r["parquet_coords_bitwise_equal"] = bool(np.array_equal(xy_b.view(np.uint64), xy.view(np.uint64)))
    r["sibling_columns"] = {c: str(tab.column(c).type) for c in tab.column_names if c != "triangles"}
    cons = np.array(tab.column("constrained").combine_chunks().flatten().to_pylist()).reshape(-1, 3)
    e = np.stack([tri, np.roll(tri, -1, axis=1)], axis=2)[cons]
    r["unique_constrained_edges"] = int(len(np.unique(np.sort(e, axis=1), axis=0)))
    if "depth" in tab.column_names:
        dep = tab.column("depth").to_numpy()
        r["depth_values"] = {int(k): int(v) for k, v in zip(*np.unique(dep, return_counts=True))}
    vt = pq.read_table(os.path.join(d, name + "-vertices.parquet"))
    r["vertex_table_rows"] = vt.num_rows
    r["vertex_table_matches_dictionary"] = vt.num_rows == len(xy) and \
        vt.column("vertex").to_pylist() == list(range(len(xy)))
    r["vertex_table_columns"] = {f.name: str(f.type) for f in vt.schema}
    if "x_num" in vt.column_names and vt.column("x_num").null_count == 0:
        xn, xd = vt.column("x_num").to_pylist(), vt.column("x_den").to_pylist()
        yn, yd = vt.column("y_num").to_pylist(), vt.column("y_den").to_pylist()
        fx = [Fraction(int(a), int(b)) for a, b in zip(xn, xd)]
        fy = [Fraction(int(a), int(b)) for a, b in zip(yn, yd)]
        r["exact_nearest_double_matches_xy"] = all(float(a) == x for a, x in zip(fx, xy[:, 0])) and \
                                              all(float(a) == y for a, y in zip(fy, xy[:, 1]))
        r["exact_non_dyadic_crossings"] = sum(1 for a, b in zip(fx, fy)
                                              if (a.denominator & (a.denominator - 1)) or (b.denominator & (b.denominator - 1)))
        r["max_denominator_digits"] = max(len(str(a.denominator)) for a in fx + fy)
    res[name] = r
# exact vs double crossings: how many exact crossings (rounded) differ from the double run
xe, _ = gt.to_mesh(ipc.open_file(os.path.join(d, "lari-polymer7-exact.arrow")).read_all().column("triangles").combine_chunks())
xd_, _ = gt.to_mesh(ipc.open_file(os.path.join(d, "lari-polymer7-double.arrow")).read_all().column("triangles").combine_chunks())
se = set(map(tuple, xe.view(np.uint64))); sd = set(map(tuple, xd_.view(np.uint64)))
res["polymer7_exact_vs_double"] = {"exact_points": len(se), "double_points": len(sd),
                                   "bitwise_shared": len(se & sd), "only_exact": len(se - sd)}
gt.unregister()
print(json.dumps(res, indent=1))
