# Triangles in GeoArrow: notes from wkpool, laridae and cdtr

*Development draft, October 2026; revised 14 October after feedback from the
GeoArrow side on the dictionary form. Written for the GeoArrow discussion about
storing triangles, from what we learned building triangle meshes in R. Not a
spec; a list of what worked, what broke, and one possible shape.*

*The proposal-shaped version is
[Proposal: geoarrow.triangles](../geoarrow-triangles-proposal/).*

The remark that started this:

> we have to solve triangles in GeoArrow too at some point... we can
> dictionary-encode points maybe and store as a fixed-size list or struct of
> geoarrow.point

Dictionary-encoding the points is the right instinct. It is the vertex pool
that [wkpool](https://github.com/hypertidy/wkpool) is built on: one table of
unique vertices, and geometry as integer references into it. The notes below
are about the details that decide whether that works in practice.

## 1. Four ways to store triangles

| form | layout | keeps adjacency | Parquet | notes |
|---|---|---|---|---|
| A. soup | `fixed_size_list<geoarrow.point, 3>` per triangle | no | yes | simplest; same information as WKB `TRIANGLE`; every shared vertex repeated (about 6 times in a typical mesh) |
| B. per-feature mesh | struct of `vertices: list<point>` and `triangles: list<fixed_size_list<uint32, 3>>`, indices local to the row | within a feature | yes | like glTF or PLY; one row is one mesh |
| C. two tables | a vertex table and a triangle table of three vertex ids | across features | yes | the form in our mesh spec |
| D. dictionary | `fixed_size_list<dictionary<int32, geoarrow.point>, 3>`, one mesh per Arrow array | across batches | no (decode to A) | rows are triangles, the dictionary is the vertex pool |

**Form D is the one GeoArrow has in mind**: one mesh per Arrow array, each
row a triangle, the dictionary holding the vertices. It is form C folded into a
single column, and it has the right properties for Arrow:

- **Shared across batches.** In IPC the dictionary is sent once and every later
  record batch refers to it. Checked with pyarrow 25: two batches of triangles
  over one vertex dictionary write as `schema, dictionary, record batch,
  record batch`, and both batches read back with the same dictionary. The IPC
  file format round-trips the type too.
- **Rows stay small.** Each row is three indices, so nothing depends on very
  large rows, which many tools handle poorly.
- **Triangle attributes are sibling columns** (depth, a feature id, a face
  value), aligned row for row.

What we found when testing it
([script](https://github.com/mdsumner/trianglewins/blob/main/survey/dev-drafts/geoarrow-dict-check.py)):

- **Parquet does not take it.** pyarrow 25 refuses to write it
  (`Writing DictionaryArray with nested dictionary type not yet supported`).
  The sharing has to be decoded to form A for Parquet, or written as form C.
- **A second column means a second dictionary.** Constraint edges stored as
  `fixed_size_list<dictionary<int32, point>, 2>` beside the triangles get
  their own dictionary in IPC (`schema, dictionary, dictionary, record batch`),
  so the vertices are sent twice. Flags on the triangle avoid that (section 4).
- **Vertex attributes need a home.** `origin`, z, or exact rational
  coordinates (section 2) belong to vertices, not triangles. Either the
  dictionary value type carries them (a struct wider than `geoarrow.point`),
  or a vertex table sits beside the array keyed by dictionary index.

**Form B is still useful, in addition.** It is what a scalar function returns:
an `ST_Earcut(wkb)` or `ST_Triangulate(wkb)` maps one geometry to one mesh, so
its output must be a per-row value. Rows can get big for detailed polygons,
which is the cost of a scalar result. Form C is the interchange form for
writing to Parquet or a database.

## 2. Say how vertices were matched

Two points are "the same vertex" only by some rule. We use a ladder:

1. exact float equality of the input coordinates;
2. tolerance or snapping;
3. noded, as GEOS does, where crossings become vertices;
4. exact, with constructed points held as rationals (CGAL's exact kernel).

Dictionary-encoding by equality is rung 1 only. A mesh should record which
rung produced its vertex ids, for example in field metadata
(`"vertex_identity": "exact_float"`), so a reader knows whether two nearby
vertices are meant to be one.

Why this matters: we triangulated 60 random segments with integer endpoints
twice. With crossings computed in double (CGAL's Epick kernel) there were 398
crossing vertices, but only 15 lay exactly on their input segments, and 4 were
spurious near-duplicates (one pair 1.9e-14 apart) where three segments
meet. With exact constructions there were 394, all exactly on their segments.
The exact run uses `lari_cdt(exact = TRUE)` on the laridae
[`exact-cdt` branch](https://github.com/hypertidy/laridae/tree/exact-cdt),
and the check uses euclid's exact `has_on()`.

If exact values need to travel, they can: numerator and denominator as string
columns (`x_num`, `x_den`, `y_num`, `y_den`) beside the nearest doubles. That
is plain data, unlike an exact number behind a pointer.

## 3. Constructed vertices are not input

A constrained triangulation adds vertices: crossings where input segments
intersect, and Steiner points from refinement. A reader needs to tell them
apart, and to trace mesh edges back to the input.

- An `origin` column on vertices, dictionary encoded: `input`, `crossing`,
  `steiner` (plus `grid` or `lattice` for generated meshes).
- Optionally, for each constraint edge in the mesh, the input segment it came
  from and how many input segments overlap it (laridae returns `segment` and
  `count`).
- Input vertices first, in input order, so ids of the input survive.

## 4. Triangles alone lose the polygon

A set of triangles does not say which edges were boundaries, or which
triangles are inside a hole. Keep two more things:

- the **constraint edges**, so boundaries and holes can be rebuilt. In form C
  they are a table of vertex id pairs. In form D, where a second column would
  repeat the dictionary, a per-triangle `fixed_size_list<bool, 3>` saying
  which of its edges are constrained does the same job (edge k runs from
  vertex k to vertex k + 1);
- a per-triangle **depth**: how many constraint edges you cross to reach it
  from outside. Odd depth is inside under even-odd rules. When two polygons
  share a boundary, that edge is counted once per copy, so depth stays
  meaningful for coverages.

## 5. Conventions worth fixing early

These are the decisions in our mesh spec (v0.1); they cost nothing to agree on
and are painful to change later.

- Triangles counter-clockwise in xy.
- Vertex ids 0-based in Arrow (R presents them 1-based).
- The constraint table is called `constraints`.
- A doubled boundary counts once per copy in depth.
- The constraint-to-input map is optional.

## 6. Indexed triangles pay off

Indexing is not only about size. In wkpool, drawing 40,000 triangles from the
vertex pool with one indexed `polygon()` call took 0.4 s, against 74 s when
each triangle was cast to its own polygon geometry first. Renderers (deck.gl,
WebGL, glTF) want indexed triangles too, so forms B, C and D feed them directly.

## 7. Traps we hit

- **Per-polygon triangulation.** Triangulating each polygon of a coverage on
  its own is easy, but Steiner points added on a shared edge are not shared by
  the neighbour, so the mesh has cracks. Triangulate the coverage as one
  planar straight-line graph, or refine shared edges once.
- **Batch seams.** Streaming a large coverage in batches means edges on the
  seam appear in two batches; the vertex ids there must agree (see section 2).
- **Units.** A maximum triangle area in metres applied to longitude/latitude
  data asks for an astronomical number of triangles. Estimating
  `bbox_area / max_area` before refining and warning above about 1e7 catches
  it.
- **Points and lines.** A triangulation input can include bare points and open
  lines, not only polygons. A format that only takes polygons cannot carry
  them.

## A possible shape

For discussion only. The mesh as one array (form D), with optional sibling
columns:

```
triangles:   fixed_size_list<dictionary<int32, geoarrow.point>, 3>  -- CCW
constrained: fixed_size_list<bool, 3>    -- optional; edge k is v[k] -> v[k+1]
depth:       int32                       -- optional, per triangle
field metadata: vertex_identity
```

For a scalar function returning one mesh per geometry (form B):

```
struct<
  vertices:    list<geoarrow.point>,
  triangles:   list<fixed_size_list<uint32, 3>>,   -- CCW, 0-based, row-local
  constraints: list<fixed_size_list<uint32, 2>>,   -- optional
  depth:       list<int32>                         -- optional, per triangle
>
```

and for Parquet or a database, the two-table form C with the same column
names, the triangle table keyed to the vertex table.

## Where this comes from

- [wkpool](https://github.com/hypertidy/wkpool): vertex pool, `wkpool_tri`.
- [cdtr](https://github.com/hypertidy/cdtr): constrained Delaunay
  triangulation (CDT library); minimal points / triangles / segments contract.
- [laridae](https://github.com/hypertidy/laridae): CGAL constrained
  triangulation and refinement with the full contract (origin, constraint map,
  depth).
- [meshcore](https://github.com/hypertidy/meshcore): mesh spec v0.1 in
  `docs/mesh-spec-v0.1.md`.
