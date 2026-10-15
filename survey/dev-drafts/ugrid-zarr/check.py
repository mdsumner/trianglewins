"""Open the R-written UGRID-in-Zarr meshes with the Python stack.

    python survey/dev-drafts/ugrid-zarr/check.py <outdir>

Readers: xarray (zarr-python 3), uxarray, xugrid, xpublish-tiles (mesh
detection, grid system, one rendered tile), and Icechunk (copy the v2 store
into a repo as a commit, reopen it, compare).
"""

import asyncio
import json
import sys
import time
from pathlib import Path

import numpy as np
import xarray as xr

out = Path(sys.argv[1])
res: dict[str, object] = {}


def timed(label, fn):
    t0 = time.perf_counter()
    v = fn()
    res[f"{label}_s"] = round(time.perf_counter() - t0, 3)
    return v


v2 = out / "inlandwaters-v2.zarr"
v3 = out / "inlandwaters-v3.zarr"

# xarray: both formats, same values
ds2 = timed("xarray_open_v2", lambda: xr.open_zarr(v2, consolidated=True).load())
ds3 = timed("xarray_open_v3", lambda: xr.open_zarr(v3, consolidated=False).load())
res["xarray_v2_equals_v3"] = bool(ds2.identical(ds3.assign_attrs(ds2.attrs)))
faces = ds2["mesh_face_nodes"].values
x, y = ds2["mesh_node_x"].values, ds2["mesh_node_y"].values
res["dtypes"] = {k: str(ds2[k].dtype) for k in ds2.variables}
res["n_node"], res["n_face"] = int(x.size), int(faces.shape[0])
a, b, c = faces[:, 0], faces[:, 1], faces[:, 2]
cross = (x[b] - x[a]) * (y[c] - y[a]) - (y[b] - y[a]) * (x[c] - x[a])
res["ccw_all"] = bool((cross > 0).all())
res["area_matches"] = bool(np.allclose(cross / 2, ds2["area"].values, rtol=0, atol=0))

edges = ds2["mesh_edge_nodes"].values
derived = np.sort(np.concatenate([faces[:, [0, 1]], faces[:, [1, 2]], faces[:, [2, 0]]]), axis=1)
derived = np.unique(derived, axis=0)
res["edges_match_faces"] = bool(np.array_equal(derived, edges))
res["n_edge"] = int(edges.shape[0])
res["n_constrained_edges"] = int(ds2["mesh_edge_constrained"].values.sum())
res["euler_V_minus_E_plus_F"] = int(x.size - edges.shape[0] + faces.shape[0])

# GDAL multidimensional API, both formats
import shutil
import subprocess

if shutil.which("gdalmdiminfo"):
    for name, path in (("v2", v2), ("v3", v3)):
        info = json.loads(subprocess.run(["gdalmdiminfo", str(path)], capture_output=True,
                                         text=True, check=True).stdout)
        res[f"gdal_{name}"] = {
            "dimensions": {d["name"]: d["size"] for d in info["dimensions"]},
            "arrays": len(info["arrays"]),
        }

# uxarray
import uxarray as ux

g = timed("uxarray_open", lambda: ux.open_grid(ds2))
res["uxarray"] = {
    "n_node": int(g.n_node),
    "n_face": int(g.n_face),
    "n_max_face_nodes": int(g.n_max_face_nodes),
    "face_nodes_equal": bool(np.array_equal(g.face_node_connectivity.values, faces)),
}
uxds = ux.UxDataset.from_xarray(ds2, uxgrid=g) if hasattr(ux.UxDataset, "from_xarray") else None
res["uxarray_field_mean"] = (
    float(uxds["field"].mean()) if uxds is not None and "field" in uxds else None
)

# xugrid
import xugrid as xu

uds = timed("xugrid_open", lambda: xu.UgridDataset(ds2))
grid = uds.ugrid.grid
res["xugrid"] = {
    "n_node": int(grid.n_node),
    "n_face": int(grid.n_face),
    "face_nodes_equal": bool(np.array_equal(grid.face_node_connectivity, faces)),
    "edge_dimension": grid.edge_dimension,
    "field_on": str(uds["field"].dims),
    "area_on": str(uds["area"].dims),
}

# xpublish-tiles: mesh detection, grid system, a rendered tile
import morecantile
from pyproj import CRS
from pyproj.aoi import BBox
from xpublish_tiles import grids
from xpublish_tiles.pipeline import pipeline
from xpublish_tiles.types import ImageFormat, OutputBBox, OutputCRS, QueryParams
from xpublish_tiles.ugrid import detect_mesh

mesh = detect_mesh(ds2)
res["xpt_detect_mesh"] = None if mesh is None else {
    "face_dim": mesh.face_dim,
    "node_dim": mesh.node_dim,
    "start_index": mesh.start_index,
}
called = {"n": 0}
orig = grids.triangular.delaunay


def spy(*args, **kw):
    called["n"] += 1
    return orig(*args, **kw)


grids.triangular.delaunay = spy
gs = timed("xpt_grid_system", lambda: grids.guess_grid_system(ds2, "field"))
res["xpt_grid"] = type(gs).__name__
res["xpt_delaunay_calls"] = called["n"]

tms = morecantile.tms.get("WebMercatorQuad")
tile = tms.tile(146.5, -42.0, int(sys.argv[2]) if len(sys.argv) > 2 else 7)  # Tasmania
res["tile"] = [tile.x, tile.y, tile.z]
bounds = tms.xy_bounds(tile)
for var in ("field", "area"):
    q = QueryParams(
        variables=[var],
        crs=OutputCRS(CRS.from_epsg(3857)),
        bbox=OutputBBox(BBox(west=bounds[0], south=bounds[1], east=bounds[2], north=bounds[3])),
        selectors={},
        style="raster",
        width=512,
        height=512,
        variant="viridis",
        colorscalerange=None,
        colormap=None,
        abovemaxcolor=None,
        belowmincolor=None,
        format=ImageFormat.PNG,
    )
    try:
        png = asyncio.run(pipeline(ds2, q))
        (out / f"tile-{var}.png").write_bytes(png.getvalue())
        res[f"xpt_tile_{var}"] = f"{len(png.getvalue())} bytes"
    except Exception as e:  # report, do not hide
        res[f"xpt_tile_{var}"] = f"{type(e).__name__}: {e}"
        # face-located data: the size budget multiplies the node selection by
        # the face chunk length (the face dim is not counted as covered), so
        # retry once with the budget lifted to see whether rendering works
        if type(e).__name__ == "TileTooBigError":
            from xpublish_tiles.config import config

            with config.set({"max_renderable_size": 2**40}):
                try:
                    png = asyncio.run(pipeline(ds2, q))
                    (out / f"tile-{var}.png").write_bytes(png.getvalue())
                    res[f"xpt_tile_{var}_budget_lifted"] = f"{len(png.getvalue())} bytes"
                except Exception as e2:
                    res[f"xpt_tile_{var}_budget_lifted"] = f"{type(e2).__name__}: {e2}"
res["xpt_delaunay_calls_after_tiles"] = called["n"]

# Icechunk: R wrote plain Zarr; Python commits it to a repo and reads it back
import icechunk

repo_path = out / "icechunk-repo"
if repo_path.exists():
    import shutil

    shutil.rmtree(repo_path)
repo = icechunk.Repository.create(icechunk.local_filesystem_storage(str(repo_path)))
session = repo.writable_session("main")
src = xr.open_zarr(v2, consolidated=True)
for k in src.variables:
    src[k].encoding.pop("compressors", None)
    src[k].encoding.pop("compressor", None)
    src[k].encoding.pop("filters", None)
timed("icechunk_write", lambda: src.to_zarr(session.store, mode="w", consolidated=False, zarr_format=3))
snap = session.commit("UGRID mesh written from R (trianglewins ugrid-zarr pilot)")
ro = repo.readonly_session(snapshot_id=snap)
ic = timed("icechunk_read", lambda: xr.open_zarr(ro.store, consolidated=False).load())
res["icechunk_identical"] = bool(ic.drop_attrs().identical(ds2.drop_attrs()))
res["icechunk_attrs_kept"] = ic["mesh"].attrs == ds2["mesh"].attrs
res["icechunk_detect_mesh"] = detect_mesh(ic) is not None

res["versions"] = {
    "xarray": xr.__version__,
    "zarr": __import__("zarr").__version__,
    "uxarray": ux.__version__,
    "xugrid": xu.__version__,
    "icechunk": icechunk.__version__,
}
print(json.dumps(res, indent=2))
(out / "python-read.json").write_text(json.dumps(res, indent=2))
