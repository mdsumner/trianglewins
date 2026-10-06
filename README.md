# trianglewins

A comparison harness for constrained triangulation in R. The same inputs
go through every backend, and the results are judged by code that belongs
to none of them.

| backend | library | source |
|---|---|---|
| laridae | CGAL 6 (`Constrained_triangulation_plus_2`, `Delaunay_mesher_2`) | hypertidy/laridae, main |
| cdtr | artem-ogre/CDT | hypertidy/cdtr, branch cpp11 |
| trowel | spade (Rust, via extendr) | hypertidy/trowel, main |
| RTriangle | Shewchuk's Triangle | CRAN |

All four are in Suggests. A backend that is not installed shows up in the
results as skipped, not as a failure. It also serves as laridae's
acceptance test.


The site at https://mdsumner.github.io/trianglewins/ indexes three pages:

- a guide for R users choosing a triangulation package, by kind of
  problem, CRAN first, at https://mdsumner.github.io/trianglewins/choose/,
  source in [survey/choosing-a-package.md](survey/choosing-a-package.md);
- the performance benchmark at scale (geoBoundaries country boundaries from
  `sds::CGAZ()`, 23 thousand to 6.8 million vertices), at
  https://mdsumner.github.io/trianglewins/bench/, code in [bench/](bench/);
- a survey of R packages that triangulate points, polygons or segment sets
  (algorithm, upstream library, input, constraints, output control), at
  https://mdsumner.github.io/trianglewins/survey/, source in
  [survey/](survey/r-triangulation-survey.md), both rendered
  by `sh survey/build.sh` (pandoc).

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
  and the backend's own depth is matched against both
* attribute carry: every case is run again with `z = x + 2y` on the input
  vertices. Linear interpolation reproduces a linear field exactly, so any
  deviation on crossing or Steiner vertices is an interpolation error
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

## Findings (2 October 2026)

From [inst/results/results.md](inst/results/results.md), on laridae
bf90fc9, cdtr 93af86f, trowel 32e0fe8, and RTriangle 1.6-0.15 (4-core Linux
container). Every refinement had the same Steiner budget (100000).

**Agreed everywhere.** Every backend kept every input segment and every
input vertex in every case. Every mesh was constrained Delaunay (0
violations), with no edge shared by more than two triangles. Constrained-only
meshes have the same triangle count and the same harness depth on all four
backends, for every case each of them accepted. That is the contract, holding.

**Depth means two things.** laridae and cdtr count an edge covered by k
input segments k times, and trowel counts it once. They agree on every
input where no boundary is given twice. Where one is, they differ:
`grid3_doubled` gives the centre cell 3 (laridae, cdtr) or 2 (trowel),
`nc_rings` gives 1/3/5 or 1/2/3, and `cad_tas` (collinear overlapping
segments even after exact deduplication) differs on 6 of 1974 triangles.
Neither is wrong, but the shared contract has to name one, or offer both.
The harness computes both and says which one each backend matches.

**RTriangle refuses duplicated vertices** ("Duplicated vertices in P"),
so `grid3_doubled` and `nc_rings` fail there. The other three merge
duplicates silently. RTriangle has no depth.

**laridae leaves slivers along the hull.** When cont_tas is refined over its
convex hull, laridae returns about 2650 triangles with area around
1e-11 (smallest angle 0). Every one of them touches the hull. Points
inserted on the temporarily constrained hull edges are not exactly
collinear once those constraints are released. The same runs carry
attributes with 4e-6 relative error. This is the only defect the harness
found in laridae, and it shows up only in hull mode.

**trowel's attributes are not always interpolated.** On nc refined by
area, 7 Steiner vertices near the Outer Banks have the value of a
neighbouring vertex rather than the linear interpolant (1.7e-3 relative
error). points_only shows the same at 3.7e-2. laridae, cdtr and
RTriangle reproduce the linear field to 1e-11 or better.

**cdtr does not refine without a closed boundary.** On crossing_x and
points_only with an area bound, cdtr adds nothing (0% of triangles meet the
bound) and reports `circumcenterOutside`. On the hull-meshed
collinear_overlap and cont_tas it reaches 98% and 99.7%. In the
area_angle scenario on nested3 and cad_tas, a handful of triangles miss
the area bound (99.7%, 99.95%).

**How much each backend refines.** With both bounds on nc, RTriangle adds
2455 vertices, laridae 2854, cdtr 3054 and trowel 5576. trowel has no
edge-length floor, so it meets the angle bound most often (99.5% of
triangles or more on nc, cont_tas and cad_tas). The floor that laridae and cdtr
share holds them at 92 to 99%, and laridae drops to 77% on cont_tas,
where short contour segments make the floor large next to the hull's open
triangles. RTriangle reaches 94 to 99.9% with the fewest vertices.

**Time.** Constrained only, all four take about 3 ms on nc. Refinement is
where RTriangle leads: nc with both bounds takes 6.5 ms, against 19
(laridae), 20 (cdtr) and 27 (trowel). On cont_tas the times are 19, 72, 35
and 60 ms respectively. Editing a refined nc mesh and refining again takes
5 ms in laridae and 18 ms in trowel. A rebuild with the edit takes 17 ms
in cdtr and 6 ms in RTriangle.

**Checks on earlier claims.** Under this harness, Triangle did not give up
on the cont_tas area bound: 100% of triangles meet it, both inside the
contours and over the hull. trowel's re-refine after an edit took 18 ms
here, against 8.4 ms in its own benchmark. This run used an angle bound of
20 degrees as well as the area bound, so the two numbers are not directly
comparable.

## Licence

MIT. The nc data come from sf (nc.shp) and the Tasmanian data from anglr.
