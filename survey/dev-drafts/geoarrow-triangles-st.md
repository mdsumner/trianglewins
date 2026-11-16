# What geoarrow.triangles needs for ST_*

*Development draft, 15 November 2026. A plan, not a proposal. It reads the
[geoarrow.triangles proposal](../geoarrow-triangles-proposal/) against
what the [ST_* suite on wkpool and geos](../st-mesh-geos/) needed in
practice, and lists what would have to exist, in the format and in code,
for an engine to offer the usual `ST_*` functions on a mesh column so
that users need not care how it is stored. Nothing here goes upstream
until Michael says so.*

## The goal, restated

Asked about the proposal, the GeoArrow side's answer was that adoption is
easier if the `ST_*` functions are defined for it. Taken literally, that
means: a user who calls `ST_Area(geom)`, `ST_Intersects(a.geom, b.geom)`
or `ST_Union_Agg(geom)` on a column of `geoarrow.triangles` gets the
answer they would get for the polygons, and never writes a `GROUP BY` over
triangles. The two drafts so far show the computation is there: 24
functions agree with GEOS, and the relations tier is several times faster.
What is missing is mostly not computation. It is the unit a function is
applied to.

## Requirement 1: a row must be a feature

In the proposal one row is one triangle. That is the natural storage, and
per-triangle `ST_*` is trivially native, but nobody wants the area of a
triangle. An engine evaluates `ST_*` per row, so with one triangle per row
the user has to group, and has to know which column to group by. That is
exactly caring about storage.

The fix costs one list level. Wrap the triangles of each feature in a
list, and keep one dictionary for the whole array:

```
List<FixedSizeList<Dictionary<int32, Coordinate>>[3]>
```

Each row is one polygonal feature, the way a `geoarrow.multipolygon` row
is, but its value is the feature's triangles, and every triangle indexes
the same vertex dictionary as every other row. Arrow already does all of
this (checked with pyarrow 26,
[`feature-layout-check.py`](https://github.com/mdsumner/trianglewins/blob/main/survey/dev-drafts/st-mesh-geos/feature-layout-check.py)):

| check | result |
|---|---|
| two features sharing an edge | both rows hold vertex ids 1 and 2 |
| slice one row | keeps the shared dictionary |
| IPC stream, second batch adds a feature with a new vertex | dictionary delta to 7 vertices; the new triangle refers to ids 4, 6, 5 |
| Parquet | refused (nested dictionary), as for the flat layout |
| list offsets | are the feature-to-triangle ranges: the `feature` column, for free |

This one change settles three things the earlier drafts left open:

- **The feature column.** For a coverage sorted by feature, the list
  offsets are the feature column, so the recommendation "add `feature:
  int32`" disappears into the type.
- **Overlapping features.** A triangle covered by two features appears in
  both rows (three more indices, no new vertices). That is the v0.2
  `set_id` plus `set_features` labelling, flattened, and it is what the
  DE-9IM kernel already reads (membership as offsets and ids).
- **The per-feature mesh.** The proposal ruled out one mesh per row,
  because rows get large and vertices repeat. Here rows are features of
  one mesh and nothing repeats.

The flat row-per-triangle layout stays useful as the storage of the mesh
itself (renderers, `TIN`, a whole-mesh column). The two are the same
buffers with or without the outer offsets.

**Decision for Michael:** propose the list layout as the primary
`geoarrow.triangles` (a row is a feature), the flat layout as primary
with the list as a second extension name, or keep the flat layout and
leave features to a column convention. The ST_* goal argues for the
first.

## Requirement 2: what the metadata must promise

| promise | why ST_* needs it | proposal today |
|---|---|---|
| counter-clockwise triangles | point location, validity, the dissolve walk and DE-9IM's boundary classes all assume it; otherwise every consumer tests every triangle first | "should" (open question 3) |
| `vertex_identity` | relations from indices are exact only when the mesh is noded: at `"noded"` or `"exact"` a shared boundary is a shared vertex id; at `"exact_float"` it is only if the input was already a clean coverage | optional key (open question 2) |
| `edges` | planar or spherical; every closed form changes on the sphere | inherited from GeoArrow |
| no duplicate dictionary entries | two entries with equal coordinates break "shared boundary = shared id" | "should" |
| triangles form a triangulation (no overlaps, edge to edge) | edge adjacency and the edge table assume it; a triangle soup would need re-pooling first | implied, not stated |

The suggestion is to make orientation a must, `vertex_identity` a
recommended key with a stated meaning for each value, and the
triangulation property a must whenever `vertex_identity` is set.

## Requirement 3: what the binding computes once and caches

Two derived tables made the difference between slow and fast in the
suite. Neither needs to be stored; both should be computed once per array
(per dictionary) and cached by whatever binds the type:

- **The edge table**: the triangle across each edge, from one sort or hash
  of the triangles (34 ms for 78,000 triangles in the prototype). It feeds
  perimeter, boundary, DE-9IM and the dissolve.
- **The point locator**: a grid of triangle buckets (cdtr's
  `cdt_locate()`), built in a few milliseconds.

A third is worth storing or caching because the suite showed it is the
mesh's weak spot:

- **Rings.** Number of parts, number of holes, `ST_Boundary` as lines and
  every fallback go through the dissolve. Cached, they become reads. A
  file could carry them as an optional column (ring count per feature, or
  the boundary edges), but caching in the binding is enough to start.

## Requirement 4: the kernels

An engine (or a library it calls) needs seven kernels. Sizes are the C++
in this repository's prototypes and in cdtr and wkpool:

| kernel | serves | size | where it lives now |
|---|---|---|---|
| per-triangle closed forms with a group reduction | `ST_Area`, `ST_Centroid`, `ST_PointOnSurface`, `ST_Envelope`, `ST_IsValid`, `ST_Affine` and `ST_Transform` on the dictionary | ~40 lines | `st_mesh.cpp` |
| edge table | everything combinatorial | ~20 lines | `st_mesh.cpp` |
| DE-9IM from indices | `ST_Relate` and every named predicate between features of one array | ~60 lines | `st_mesh.cpp` |
| point locator, exact | `ST_Intersects`, `ST_Contains` with points, `ST_Distance` inside | ~130 lines | cdtr `cdt_locate()` (cdtr#9) |
| dissolve walk | `ST_Union_Agg`, polygons out, structure accessors, every fallback | ~300 lines | wkpool `tri_dissolve()` (wkpool#15) |
| clip by convex shape | `ST_ClipByBox2D`, intersection with a convex polygon, staying a mesh | ~80 lines | `st_mesh.cpp` |
| producer: polygons to labelled mesh | casting polygons in, and any relation between two different arrays | a CDT plus ~200 lines of labelling | cdtr + polymer |

About 800 lines plus a CDT library. Everything else falls back: dissolve,
then GEOS (buffer, simplify, offset curves, concave hull, distance to far
points).

A natural home is the C++17 header the polymer-core brainstorm already
recommended (polymer first, its own repository later): the labelling
lives there, and these kernels read the same arrays. R, Python and a
DuckDB or SedonaDB extension could then share one implementation, as
GEOS is shared today.

## Requirement 5: relations across two arrays

Everything fast in the suite is within one array, where vertex ids are
comparable. A SQL join, `ST_Intersects(a.geom, b.geom)` across two
tables, compares features of two meshes whose ids mean nothing to each
other. There are three routes, and the format should say which it
expects:

1. **Overlay once.** Build one mesh of both (polymer). After that every
   relation and every intersection area is an index lookup (the nc by grid
   overlay: 3.7 ms for 406 relate matrices, 1 ms for all intersection
   areas). The build (38 ms there) is the cost, so this pays for joins that
   ask many questions of the same pair of layers.
2. **Locate and test.** For points, or small geometries against a mesh,
   locate the vertices and test the crossing triangles. Near-native, no
   rebuild.
3. **Fall back.** Dissolve both sides and use GEOS prepared predicates.
   No worse than polygons today, plus a dissolve.

A binding should pick per call: points take route 2, a join across two
mesh columns takes route 1 when the engine can keep the overlay for the
query, and route 3 otherwise. The type itself needs nothing extra for
this, but `vertex_identity` matters again: an overlay of two `"exact"`
meshes can stay exact (laridae), one of `"exact_float"` meshes cannot.

## Requirement 6: a conformance story

GeoArrow changes arrive with an implementation. For ST_* the evidence
that counts is agreement with GEOS (and, for the sphere, s2) on a public
corpus:

- every function in the suite against the geos package, as now, plus the
  shapely equivalents in Python;
- DE-9IM against `geos_relate()` on the polygon validity catalogue and on
  coverages with holes, pinches and touching corners (the suite has
  58,452 pairs, all equal, but no adversarial cases yet);
- the `vertex_identity` ladder: one input meshed at each rung, showing
  which answers change and why.

## Plan, on our side first

1. **Land the two package steps.** cdtr#9 (`cdt_locate()`) and wkpool#15
   (compiled `tri_dissolve()`), under review. *(16 November: both merged on
   15 November; cdtr's development version adds `cdt_locate(barycentric =
   TRUE)`.)*
2. **A feature-layout pilot.** Extend the existing pilot (nanoarrow in R,
   pyarrow in Python) to write and read the list layout, with zero-copy
   views of the dictionary as `x`, `y` and of the offsets as the
   membership, so the suite's kernels run on Arrow memory directly.
3. **Kernels into one C++ header** next to the polymer core, with R
   bindings in wkpool or polymer (`tri_relate()`, `tri_measures()`,
   `tri_clip()`), and the same header compiled for Python.
4. **Conformance corpus** as above, in this repository.
5. **Rings cache** in the binding; measure the structural accessors
   again.
6. **Revise the proposal**: the list layout, orientation as a must, the
   meaning of each `vertex_identity` value, and a short "ST_* support"
   section that points at the kernels and the conformance results.
7. **Sketch, without proposing,** what a DuckDB or SedonaDB function over
   the type would look like: a scalar `ST_Area(triangles)` reading the
   row's list, and an aggregate or table function for the cross-array
   overlay.

Steps 1 to 5 are code in our packages and this repository. Step 6 changes
the draft. Step 7 is a page. None of it needs anyone else yet.

## Open questions

1. Row as feature (list layout) or row as triangle: which is primary, and
   does the other get its own extension name?
2. Does the overlapping case (a triangle in several rows) belong in the
   type, or should the type require a coverage and leave overlaps to the
   v0.2 tables?
3. Store rings, or leave them to a cache?
4. Is the first implementation a C++ header (shared by R, Python and
   engines), or Rust beside geoarrow-rs?
5. Spherical meshes: the closed forms and predicates exist (s2), but this
   suite has not tried them. In the first version, or later?
