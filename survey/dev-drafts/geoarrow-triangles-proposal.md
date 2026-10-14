# Proposal: a `geoarrow.triangles` extension type

*Development draft, October 2026. Not submitted anywhere. This is the
proposal-shaped companion to [Triangles in GeoArrow](../geoarrow-triangles/),
which carries the background and the reasons; this page carries only what would
be asked of the spec.*

GeoArrow has no formal RFC process. Changes to the
[spec repository](https://github.com/geoarrow/geoarrow) (format version 0.2)
arrive as an issue, then a pull request that edits `format.md` and
`extension-types.md`, backed by a working implementation. This draft is written
so that its two "proposed text" sections can be lifted into that pull request
nearly as they are, and its reference checks can travel with it.

## Summary

Add one extension type, `geoarrow.triangles`. Each row is one triangle. The
three vertices are indices into a dictionary of coordinates, and that
dictionary is the mesh's vertex pool, so a whole triangulation is one Arrow
array that shares its vertices instead of repeating them.

```
FixedSizeList<Dictionary<int32, Coordinate>>[3]
```

A decoded form, `FixedSizeList<Coordinate>[3]`, carries the same extension
name for formats that cannot store a nested dictionary, which today includes
Parquet.

## Motivation

Constrained Delaunay triangulation, terrain TINs, finite element meshes and
renderers (deck.gl, WebGL, glTF) all produce or consume indexed triangles: a
vertex table and triangles that point into it. Today the only GeoArrow route is
one polygon per triangle, which repeats each shared vertex about six times,
closes every ring, and loses which triangles share an edge. WKB has `TRIANGLE`
and `TIN`, with the same repetition.

Dictionary-encoding the vertices was suggested from the GeoArrow side, and it
fits Arrow well: in IPC the dictionary is sent once and every record batch
refers to it, and rows stay small (three indices each). The background page
covers the alternatives that were considered (soup, per-feature mesh, two
tables) and what was learned building meshes in R with wkpool, cdtr and
laridae.

## Proposed text for `format.md`

#### Triangles

```
FixedSizeList<Dictionary<Index, Coordinate>>[3]
```

An array of triangles is represented as a fixed-size list of three vertices
per element. The child field name should be "vertices" and the child must be
marked non-nullable. Each vertex is an index into a dictionary whose values are
coordinates in either the separated or the interleaved representation.
`Index` should be `int32`; `int64` may be used for meshes with more than
2^31 - 1 vertices.

The dictionary is the vertex pool of a mesh, and a dictionary index is a vertex
id (0-based). Triangles that share an index share that vertex. One array is one
mesh. In the IPC format a mesh may span record batches: later batches may add
vertices with dictionary deltas, and vertex ids stay valid across the batches
of a stream. A dictionary replacement starts a new mesh, and consumers must not
compare vertex ids across it. Chunks of an in-memory chunked array with
different dictionaries are different meshes.

- The three vertices of a triangle should be in counter-clockwise order in
  the x-y plane.
- The ring is not closed: the first vertex is not repeated. Converting a
  triangle to a Polygon appends the first vertex to close the ring.
- Producers should not write degenerate (zero-area) triangles.
- The dictionary should not contain two entries with equal coordinates.
- The dictionary may contain vertices that no triangle references (for
  example isolated input points of a triangulation).
- Coordinates in the dictionary must not be null. A triangle may be null; the
  indices of a non-null triangle must not be null.

A decoded layout is also defined for formats and systems that do not support a
dictionary nested in a list:

```
FixedSizeList<Coordinate>[3]
```

This holds the same triangles with each vertex written out. Vertex sharing is
recovered by matching coordinates exactly (see `vertex_identity` below); vertex
ids are renumbered and unreferenced vertices are lost.

## Proposed text for `extension-types.md`

Add `geoarrow.triangles` to the list of extension names. Both layouts above use
this name. The `crs` and `edges` keys apply as for other types (with
`"edges": "spherical"` a triangle is a spherical triangle).

One new optional key:

- `vertex_identity`: an optional JSON string saying by which rule two
  vertices are the same vertex, so that a consumer knows whether two nearby
  dictionary entries are meant to be distinct. Omitted means unknown. One of:

  - `"exact_float"`: entries are distinct as double values.
  - `"tolerance"`: vertices closer than a producer-chosen tolerance were merged.
  - `"noded"`: input was noded so that crossings are vertices, with crossings
    computed in floating point.
  - `"exact"`: as `"noded"`, with constructions computed exactly and rounded to
    the nearest double on output.

## Parquet: the default chosen here

pyarrow refuses to write a dictionary nested in a list to Parquet. The default
in this draft is that **Parquet gets the decoded layout under the same
extension name**, and a reader rebuilds the dictionary by exact coordinate
matching. Checked: the decoded array round-trips through Parquet with its
extension name and metadata, and re-pooling recovers the same 4 vertices and
the same triangles.

What this loses: vertex ids are renumbered (by first appearance), unreferenced
vertices are dropped, and with `vertex_identity` `"tolerance"` two distinct
entries that happen to share a double value would merge. A lossless
alternative is two tables (vertices, and triangles of `FixedSizeList<int32>[3]`
indices), but that is a file-level convention for GeoParquet rather than a
column type for GeoArrow, so it is left out of this proposal.

**This is the main open decision.** The options are (a) decoded layout as
above, (b) no Parquet story in the type, defer to GeoParquet, (c) a second
storage layout of plain indices plus a separate vertex column, which needs a
cross-column reference GeoArrow has never had.

## Conventions outside the type

These came out of the mesh work and are worth recommending, but they are
columns beside the triangles, not part of the extension type:

- `constrained: FixedSizeList<bool>[3]` per triangle: whether edge k (vertex k
  to vertex k + 1) is a constraint (an input boundary). A second dictionary
  column for constraint edges would send the vertices a second time in IPC.
- `depth: int32` per triangle: constraint edges crossed to reach it from
  outside; odd is inside under even-odd rules.
- Vertex attributes (`origin` as input, crossing or steiner; z; exact rational
  coordinates) need a home keyed by dictionary index, either a wider
  dictionary value type or a vertex table. This draft does not choose.

## Out of scope

- A per-feature mesh, one mesh per row, as returned by a scalar
  `ST_Triangulate(geom)`. Useful as a later addition; rows can get large.
- Meshes of quads or mixed polygons (UGRID-style face-node tables), and
  tetrahedra.
- Topology beyond shared vertices (edge tables, neighbour tables). These can
  be computed from the indices.

## Open questions

1. Parquet: (a), (b) or (c) above.
2. Does `vertex_identity` belong in the spec, or in producer-specific
   metadata?
3. Should counter-clockwise order be "should" or "must"? GeoArrow does not
   fix ring orientation for polygons.
4. Should GeoArrow implementations (geoarrow-c, geoarrow-rs) also read WKB
   `TRIANGLE` into this type, and write a mesh as WKB `TIN`?
5. Is the name `geoarrow.triangles` right, given each row is one triangle but
   the array is the mesh?

## Reference checks

[`geoarrow-triangles-ref.py`](https://github.com/mdsumner/trianglewins/blob/main/survey/dev-drafts/geoarrow-triangles-ref.py)
registers the type in pyarrow (26.0) and checks the claims above:

| check | result |
|---|---|
| IPC stream, two batches, one dictionary | `schema, dictionary, record batch, record batch` |
| IPC stream, batch 2 adds a vertex by delta | `schema, dictionary, record batch, dictionary, record batch`; batch 2 sees 5 vertices |
| delta dictionaries in the IPC file format | written and read, 2 batches |
| reader without the type registered | sees the storage type plus `ARROW:extension:name` and metadata |
| Parquet, dictionary layout | refused: nested dictionary not supported |
| Parquet, decoded layout | round-trips with extension name and metadata; re-pooling gives 4 vertices and the same triangles |
| triangle to Polygon | ring closed by repeating the first vertex |
| winding | the test triangles are counter-clockwise |

Still to do before this goes upstream: an export from wkpool (R, through
nanoarrow) so there is a second, independent producer, and a reader in
geoarrow-c or geoarrow-rs if a maintainer is willing.
