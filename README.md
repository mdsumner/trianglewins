# trianglewins

A comparison harness for constrained triangulation in R. The same inputs
go through every backend, and the results are judged by code that belongs
to none of them.

| backend | library | source |
|---|---|---|
| laridae | CGAL 6.1 (`Constrained_triangulation_plus_2`, `Delaunay_mesher_2`) | hypertidy/laridae, main |
| cdtr | artem-ogre/CDT | CRAN (0.1.0); hypertidy/cdtr, main, for 0.2.0 |
| trowel | spade (Rust, via extendr) | hypertidy/trowel, main |
| RTriangle | Shewchuk's Triangle | CRAN |

All four are in Suggests. A backend that is not installed shows up in the
results as skipped, not as a failure. It also serves as laridae's
acceptance test.


The site at https://mdsumner.github.io/trianglewins/ has three articles
and the benchmark:

- [survey](survey/r-triangulation-survey.md): quick answers by problem,
  then R packages that triangulate points, polygons or segment sets, with
  lineage, a capability matrix and a look at Python;
- [triangulation in context](survey/context.md): earcut and GEOS against
  laridae on the same inputs, the silicate and anglr history, and why
  CGAL (figures from [survey/context/figures.R](survey/context/figures.R));
- [notes](survey/notes.md) on dimension and interpolation;
- [grids as meshes](survey/grids.md): where gridded data meets
  triangulation, and "Delaunay in what?" measured on one polar grid block;
- the [benchmark](bench/) at scale on geoBoundaries country boundaries.

The articles are rendered by `sh survey/build.sh` (pandoc), which also
writes redirect stubs for the pages merged in October 2026 (choose,
dimension, interpolation, roadmap).

## What it measures

The input contract is the one the three hypertidy packages share: vertices
(x, y) and segments (index pairs). Each backend's output is reduced to a
vertex table and a triangle table (with the backend's own depth when it
has one). `tw_measure()` then works out, from those tables and the input
alone:

* vertex and triangle counts, and how many vertices were added
* whether every input vertex is present
* area bound: share of triangles at or under `max_area`, and the largest area
* angle bound: share of triangles at or over `min_angle`, and the smallest angle
* segment preservation: every input segment present as a chain of collinear
  output edges, end to end
* constrained Delaunay: unconstrained interior edges failing the empty
  circumcircle test
* triangles shared by more than two edges, and near-zero-area slivers
* **harness depth**: the least number of constraint crossings from outside
  the mesh to each triangle, computed by a shortest path over the output
  triangle adjacency. It is computed two ways, counting an edge covered
  by k input segments as k crossings (`depth_k`) or as 1 (`depth_1`),
  and the backend's own depth (and its distinct depth, where it returns
  one) is matched against both
* attribute carry: every case is run again with `z = x + 2y` on the input
  vertices. Linear interpolation reproduces a linear field exactly, so any
  deviation on crossing or Steiner vertices is an interpolation error
* grid cells (`tw_in_cell()`, grid cases only): the share of triangles that
  are half of one grid quad, judged in the grid's own index, and of those
  the share using the (i, j)-(i + 1, j + 1) diagonal
* the edge-length floor the refiner used (`min_edge_length`): cdtr and
  laridae run with their defaults, which derive one from the input
* time: median over repeats, including reading the tables back

## Cases

| case | what it is for |
|---|---|
| square | sanity |
| square_hole | nested rings: depth 1 and 2 |
| nested3 | rings three deep: depth 1, 2, 3 |
| grid3_doubled | 3 x 3 coverage, every cell its own ring: shared vertices repeated, shared edges given twice |
| grid3_dedup | the same coverage, shared edges once |
| crossing_rings | two overlapping squares whose rings cross |
| crossing_x | two crossing segments, no region (meshed over the hull) |
| collinear_overlap | collinear overlapping segments (the case that crashed polymer) |
| dangling | an open polyline inside a square |
| sharp_corner | a star with sharp spikes and a 1 degree sliver |
| points_only | 500 points, no segments |
| grid_quads | 10 x 10 NSIDC 3412 cell centres near 60 S in lon/lat, the index's quad edges as constraints |
| grid_frames_lonlat | the same points only, in lon/lat: Delaunay gives 186 triangles, 87% of them quad halves |
| grid_frames_3412 | the same points only, in EPSG:3412 where the grid is regular: 162 triangles, all quad halves |
| grid_diagonal | 3 x 3 unit cells: both diagonals of each are Delaunay, so the diagonal is a tie-break |
| nc | North Carolina counties, shared boundaries once (1255 vertices) |
| nc_rings | the same counties as rings in full (2421 vertices, everything shared twice) |
| cont_tas | Tasmanian contours (anglr), open lines meshed over their hull |
| cad_tas | Tasmanian cadastre (anglr) |

Each case runs four scenarios: constrained only, an area bound (bounding box
area / 200 for the synthetic cases, / 5000 for the real ones), a 25 degree
angle bound, and both. The real-data cases are CSV files in `inst/extdata`.
`inst/scripts/make-extdata.R` shows how they were made. `tw_run_dynamic()`
adds the live-mesh question: refine nc, add one short constraint, and get the
refined mesh again, by editing the handle (laridae, trowel) or by
rebuilding (cdtr, RTriangle).

## Real-world data

[`guide/`](guide/README.md) is a guide to feeding the meshers from real
layers: example interfaces (not part of the package, `source()` them) that
read any wk handleable into the shared tables, mesh with any backend, label
triangles by feature and write wkb back out, worked on
`silicate::inlandwaters`.

## Running it

```r
library(trianglewins)
tw_available()
r <- tw_run(cases = c("nc", "grid3_doubled"))
tw_report(r)
```

`Rscript inst/scripts/run-all.R` runs everything, one R process per backend
(a crash or a runaway refinement cannot take the others down), and writes
[inst/results/results.md](inst/results/results.md) and `results.csv`.

## Findings (16 November 2026)

From [inst/results/results.md](inst/results/results.md), on laridae 0.1.0
(ca6770f, CGAL 6.1), cdtr 0.1.0.9002 (1b52f51, the development version for
0.2.0), trowel 32e0fe8 and RTriangle 1.6-0.15 (32-core Linux, R 4.6.1).
Every refinement had the same Steiner budget (100000). cdtr and laridae
ran with their default edge-length floor (`min_edge_length = NULL`),
which the results now record.

The first run, on 2 October 2026 (laridae bf90fc9, cdtr 93af86f, from
before cdtr 0.1.0), is in the history of `inst/results/`. Since then the
cdtr, trowel and RTriangle meshes are unchanged in every case: the same
vertex and triangle counts, status and attribute error. laridae's changed
in 15 of 61, as described below. Times are not comparable between the two
runs, which used different machines.

**Agreed everywhere.** Every backend kept every input segment and every
input vertex in every case. Every mesh was constrained Delaunay (0
violations), with no edge shared by more than two triangles. Constrained-only
meshes have the same triangle count and the same harness depth on all four
backends, for every case each of them accepted, including the four grid
cases added since October. That is the contract, holding.

**Depth means two things, and two backends give both.** laridae's and cdtr's
`depth` counts an edge covered by k input segments k times, and trowel
counts it once. They agree on every input where no boundary is given
twice. Where one is, they differ: `grid3_doubled` gives the centre cell 3
(laridae, cdtr) or 2 (trowel), `nc_rings` gives 1/3/5 or 1/2/3, and
`cad_tas` (collinear overlapping segments even after exact deduplication)
differs on 6 of 1974 triangles. laridae and cdtr (with
`depth_distinct = TRUE`) also return `depth_distinct`, which counts once
and matches trowel and the harness's `depth_1` on all three. Neither
reading is wrong. The mesh spec's `depth` is the per-copy one, and the
harness checks both.

**RTriangle refuses duplicated vertices** ("Duplicated vertices in P"),
so `grid3_doubled` and `nc_rings` fail there. The other three merge
duplicates silently. RTriangle has no depth.

**laridae no longer leaves slivers along the hull.** On 2 October,
refining cont_tas over its convex hull left about 2650 triangles of area
around 1e-11 in laridae, all touching the hull, and attributes carried
with 4e-6 relative error. laridae 0.1.0 leaves no near-zero-area triangle
in any case, and carries attributes to 7e-16. On cont_tas it now adds 2377
vertices with the area bound (7661 before) and meets the angle bound on
96.5% of triangles with both bounds (77% before). The harness finds no
defect in laridae now.

**trowel's attributes are not always interpolated.** On nc refined by
area, 7 Steiner vertices near the Outer Banks have the value of a
neighbouring vertex rather than the linear interpolant (1.7e-3 relative
error). points_only shows the same at 3.7e-2, and the new grid_quads and
grid_frames_lonlat cases at 1.8e-3. laridae, cdtr and RTriangle reproduce
the linear field to 1e-11 or better.

**cdtr does not refine without a closed boundary.** On crossing_x with an
area bound, cdtr adds only the crossing vertex, so no triangle meets the
bound, and it reports `circumcenterOutside`. On points_only with an angle
bound it adds one vertex and 95% of triangles meet the bound, where
RTriangle adds 292 and reaches 100%. (The October text put points_only
under the area bound, which its Delaunay mesh already meets.) On the
hull-meshed collinear_overlap and cont_tas the area bound reaches 98% and
99.7%. In the area_angle scenario on nested3 and cad_tas, a handful of
triangles miss the area bound (99.7%, 99.95%).

**How much each backend refines.** With both bounds on nc, RTriangle adds
2455 vertices, laridae 2847, cdtr 3054 and trowel 5576. trowel has no
edge-length floor, so it meets the angle bound most often (99.5% of
triangles or more on nc, cont_tas and cad_tas). laridae and cdtr derive
the same floor from the input (0.0138 on nc, 2.80 on cont_tas, 3.0 to 3.2
on cad_tas), and it holds them at 92 to 99%. RTriangle reaches 94 to
99.9%. It adds the fewest vertices on nc, but more than laridae and cdtr
on the Tasmanian data (7992 on cont_tas, against 4662 and 4262). The
floor matters little on cont_tas: with `min_edge_length = 0`, cdtr adds
2152 vertices instead of 2008 with the area bound (checked separately).

**Time.** Constrained only on nc, RTriangle and trowel take about 3 ms,
cdtr 4 ms and laridae 8 ms, about 5 ms of which laridae spends building
its output tables (the same in its 22 October build and in main).
Refinement is where RTriangle leads: nc with both bounds takes 6.3 ms,
against 30 (laridae), 20 (cdtr) and 25 (trowel). On cont_tas the times are
18, 69, 35 and 54 ms respectively. Editing a refined nc mesh and
refining again takes 18 ms in laridae and 17 ms in trowel. A rebuild with
the edit takes 17 ms in cdtr and 6 ms in RTriangle. So at this size a
live handle is no faster than a rebuild, and the October run's 5 ms for
laridae no longer holds. The [benchmark](bench/) found the handle several
hundred times faster than a rebuild at scale, but it ran on 6 October,
before that change, and has not been re-run.

**Checks on earlier claims.** Under this harness, Triangle did not give up
on the cont_tas area bound: 100% of triangles meet it, both inside the
contours and over the hull. trowel's re-refine after an edit took 17 ms
here, against 8.4 ms in its own benchmark. This run used an angle bound of
20 degrees as well as the area bound, so the two numbers are not directly
comparable.

## Licence

MIT. The nc data come from sf (nc.shp) and the Tasmanian data from anglr.
