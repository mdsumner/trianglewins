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
| `laridae-mesh.R` | real constrained meshes from laridae (exact-cdt branch), exported with `constrained`, `depth` and a vertex table |
| `laridae-check.py` | Python checks on those meshes, including the exact rational coordinates |
| `plot-mesh.R` | draws a mesh read back from its Parquet file |
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

## Real constrained meshes from laridae

`laridae-mesh.R` triangulates three inputs with laridae built here from the
`exact-cdt` branch (RcppCGAL 6.2.1), and writes each as a dictionary-layout
IPC file, a decoded Parquet file and a vertex table keyed by dictionary index
(`vertex`, `input_row`, `origin`, and the exact rational strings when present).
Sibling columns are `constrained` (`fixed_size_list<bool>[3]`) and `depth`.

| mesh | input vertices | vertices (Steiner, crossing) | triangles | depth |
|---|---|---|---|---|
| ACT, NSW, Victoria (inlandwaters rows 1, 3, 6), refined, min angle 25 | 12,140 | 40,654 (28,514 Steiner) | 71,318 | 1: 65,671; 2: 4,444; 3: 1,203 |
| `minimal_mesh`, refined, min angle 25 | 14 | 275 (261 Steiner) | 479 | 1: 433; 2: 46 |
| polymer#7 lines (200 points, buffered), exact crossings | 400 | 5,636 (5,236 crossing) | 11,250 | not computed by `lari_cdt()` |

For all of them, in Python: the IPC ids match what R wrote, the Parquet round
trip gives the same ids and bit-identical coordinates, the vertex table lines
up with the dictionary, and the unique constrained edges recovered from the
per-triangle flags equal the rows of laridae's segment table (14,327; 97;
10,872). The pictures are drawn in R from the Parquet files alone:
`results/minimal-mesh.png` and `results/vic-nsw-act.png`.

Two findings from the exact mesh:

- **laridae's `x`, `y` for exact crossings are not always the nearest
  double.** Rounding the exact rationals correctly (Python `Fraction`) differs
  from laridae's doubles for 3,961 of 5,636 vertices, mostly by 1 ulp, at most
  51 ulps. The proposal's `"exact"` identity says "rounded to the nearest
  double", so `lari_cdt()` should round from the rational. It uses
  `CGAL::to_double()` on the lazy exact number (`src/exact.cpp` lines 90-91),
  which does not promise the nearest double.
- **Double and exact crossings differ almost everywhere.** Against the
  correctly rounded exact values, 4,839 of the double-kernel run's 5,636
  vertices differ, by at most 9.6e-13. Both runs give the same counts here,
  so this input does not show the spurious vertices seen on integer segments.

The vertex table resolves an ordering question: laridae (and mesh spec v0.1)
put input vertices first in input order, while the proposal recommends
first-appearance order. Settled 14 October 2026: both, at different layers.
The in-memory mesh keeps input-first; the serialised array uses first
appearance, and `input_row` maps each vertex back (mesh spec Decision 8).

## Not covered

- Streaming re-pool row group by row group (the pilot re-pools whole files;
  a hash table carried across row groups would bound memory).
- GDAL, geoarrow-c and geoarrow-rs as readers.
- A per-triangle input feature (which polygon a triangle came from); laridae
  gives depth, not the feature.
