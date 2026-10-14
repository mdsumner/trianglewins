# Pilot: the geoarrow.triangles Parquet default

A working implementation of the default in
[the proposal](https://mdsumner.github.io/trianglewins/dev-drafts/geoarrow-triangles-proposal/): the dictionary layout in
memory and IPC, the decoded layout in Parquet, and the vertex pool rebuilt on
read by exact match. Two independent producers and readers, Python (pyarrow)
and R (nanoarrow arrays, wkpool for pooling), read each other's files.

## Files

| file | what |
|---|---|
| `geoarrow_triangles.py` | Python module: extension type, `from_mesh`, `canonical_order`, `decode`, `repool`, IPC and Parquet read/write |
| `geoarrow_triangles.R` | R functions: `wkpool_tri` to the dictionary or decoded layout with nanoarrow, decoded coordinates back to a `wkpool_tri` with `wkpool::merge_coincident()` |
| `pilot.py` | scale run: Delaunay of N random points, IPC, Parquet, comparisons, DuckDB, edge cases |
| `pilot-r.R` | R producer (inlandwaters through wkpool) and R reader |
| `cross.py` | Python reads the R files and writes a mesh for R to read |
| `setup.sh` | environment (conda-forge R, pip Python) |
| `results/` | JSON output of the runs below |

Run:

```
python survey/dev-drafts/pilot/pilot.py 1000000
Rscript survey/dev-drafts/pilot/pilot-r.R /tmp/silicate/data/inlandwaters.rda out
python survey/dev-drafts/pilot/cross.py out
Rscript survey/dev-drafts/pilot/pilot-r.R /tmp/silicate/data/inlandwaters.rda out out/python-mesh.parquet
```

## Results

Versions: pyarrow 26.0.0, numpy 2.5.3, DuckDB 1.5.6; R nanoarrow 0.8.0.1,
arrow 25.0.0, wk 0.9.5, wkpool 0.4.0. 4 cores, 15 GB.

**The round trip is exact.** With vertices numbered by first appearance in
the triangles, writing the decoded layout to Parquet and re-pooling on read
gives back the same vertex ids and bit-identical coordinates. This held for
1,999,957 triangles on 999,999 vertices (Python), for the 33,205 triangles of
inlandwaters (R, 6 features, earcut through wkpool), and across languages in
both directions (R wrote, Python read; Python wrote 399,962 triangles in 4 row
groups, R read and pooled with `merge_coincident()`).

**First-appearance order is what makes ids survive.** Without it the same
triangles come back, but renumbered. So the proposal should recommend that
producers number vertices by first appearance. The same order also makes IPC
dictionary deltas natural: each batch adds only the vertices it first uses
(31 batches, ids and dictionary equal on read).

**The extension type survives Parquet** in both pyarrow and R arrow, through
the stored Arrow schema: extension name and metadata come back.

**A reader that knows nothing about the type can use it.** DuckDB reads the
decoded Parquet as `STRUCT(x DOUBLE, y DOUBLE)[]` and summed the triangle
areas in SQL to a relative difference of 1.9e-16 from numpy.

Sizes and times, 1M random points (2M triangles), zstd:

| form | bytes |
|---|---|
| IPC, dictionary layout (uncompressed) | 48.8 MB |
| IPC, dictionary layout with deltas | 48.8 MB |
| **Parquet, decoded layout (the default)** | **41.9 MB** |
| Parquet, two tables (option c) | 29.2 MB |
| Parquet, WKB polygons | 42.7 MB |

| step | seconds |
|---|---|
| Parquet write (decode + write) | 1.2 |
| Parquet read + re-pool | 1.4 |
| DuckDB area query | 0.14 |
| IPC write with deltas | 0.10 |
| IPC read | 0.01 |

Random full-precision coordinates are the worst case for compression. The
default costs about 43% more than two tables and about the same as WKB
polygons. For inlandwaters
(30,835 vertices, projected metres) the decoded Parquet was 0.84 MB against
0.79 MB for the uncompressed IPC dictionary file.

**Edge cases behave as the proposal says:** an unreferenced vertex is dropped,
two entries with equal coordinates merge, and `-0.0` and `0.0` stay distinct
because matching is on the bit pattern.

## Not covered

- Streaming re-pool row group by row group (the pilot re-pools whole files;
  a hash table carried across row groups would bound memory).
- GDAL, geoarrow-c and geoarrow-rs as readers.
- Real meshes from laridae or cdtr with constraint flags and Steiner points
  (the pilot writes `depth` and `constrained` columns but all-default values).
