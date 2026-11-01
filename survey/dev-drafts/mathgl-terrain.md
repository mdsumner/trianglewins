# math.gl terrain, read from the mesh side

*Development draft, 31 October 2026. A study suite, not a proposal: we read the
[math.gl terrain roadmap](https://github.com/visgl/math.gl/issues/341) against
our own mesh work and test what we can on our side first. Nothing here has been
sent upstream. Studies so far:
[Breaklines in terrain meshes](../mathgl-breaklines/).*

## What math.gl is building

[visgl/math.gl#341](https://github.com/visgl/math.gl/issues/341) (Ib Green,
27 October 2026) plans a terrain substrate in `@math.gl/geospatial/terrain`.
The long form is
[dev-docs/terrain-roadmap.md](https://github.com/visgl/math.gl/blob/master/dev-docs/terrain-roadmap.md),
with tranches T0 to T7. This reading is of commit `c9cc7d6` (28 October 2026).

A lot has already landed:

- height fields with explicit cell or vertex registration, validity and a
  height reference;
- tiled snapshots with halos;
- regular meshes, plus MARTINI and Delatin adaptive meshes (Delatin moved
  over from loaders.gl);
- BVH ray and contact queries;
- slope and aspect checked against GDAL 3.9.3;
- contours and profiles;
- vertex-tile reconciliation, mixed-resolution seam stitching and skirts.

The next steps are a mesh lab (regular, MARTINI and Delatin on more DEMs),
tile continuity, and adoption in loaders.gl, luma.gl and deck.gl. Last, and
only once real consumers exist, comes T7: constrained TINs, breaklines,
incremental edits, hydrologic conditioning, and metrics for finite-volume
solvers.

The roadmap is careful about error. It separates *measured*, *estimated* and
*bounded* error. It keeps source terrain, displayed geometry and simulation
resolution apart. It also says plainly that "a vertical error measured at
original samples does not by itself certify every point of an interpolated
surface". Our first study measures exactly that.

## Where it meets our work

| math.gl | ours | how close |
|---|---|---|
| `TerrainGridMesh`: Float64 `positions` relative to `origin`, 0-based Uint32 `indices`, CCW in world XY | [mesh spec](https://github.com/hypertidy/meshcore/blob/main/docs/mesh-spec-v0.2.md) drawable form: positions with `local_origin` subtracted, 0-based uint32 indices, CCW (decisions 2 and 3) | Same shape. They chose the same index base, winding and origin handling on their own |
| `gridCoordinates`: integer (column, row) per vertex; fractional after seam stitching | `origin = grid` / `lattice`, and the drawable form's `uv` into the source grid | Same idea. Theirs is per vertex and numeric, ours is a provenance label plus `uv` |
| Registration: cell or vertex, "a 256-pixel DEM and a 257-vertex mesh are not interchangeable" | meshcore GRID model; [Grids as meshes](../../grids/) | Same concern, in nearly the same words |
| T7 constrained TINs and breaklines; CGAL named as the validation reference | cdtr, laridae, the `constraints` table | Direct: we have working engines |
| Mixed-resolution seam stitching: union knots on an authoritative edge, boundary triangles split | `edge_sources` (spec v0.2): every mesh edge maps to the input segments that cover it | Their seam is one constrained boundary. Provenance per edge would record which side owns it |
| Vertex-tile reconciliation: canonical ownership, a disagreement budget | The vertex identity ladder: exact, snapped, noded, exact constructions | They are on the snapped rung, with a budget we do not yet record |
| Delatin and MARTINI refuse a grid with any invalid sample (`validCount` must equal the sample count); only the regular mesh keeps nodata holes | Constraint boundaries with `erase = "holes"` | An opening: a boundary as a constraint lets an adaptive mesh skip nodata |
| T7 finite-volume metrics: "a good rendering mesh is not a good numerical mesh" | UGRID model, MDAL and GDAL multidim bridge | Same direction |
| Contour welding across tiles, isobands | polymer, wkpool | Partly: cross-tile welding is a shared-vertex problem |
| `subdivideTriangleMesh` in `@math.gl/geometry`: refine in source space to a target-space tolerance, three source vertices recorded per output vertex | bigcurve, and [Curves](../../curves/) | Same tolerance question, for triangles rather than edges |

## Questions to work through here

Each question gets a study page, with code under
`survey/dev-drafts/mathgl-terrain/` in this repository.

1. **What does a breakline buy over sample-only meshing?** Done:
   [Breaklines in terrain meshes](../mathgl-breaklines/). On an analytic cliff
   and on the Hobart coast, it covers sample error, true-surface error,
   coastline height and triangle count.
2. **How far is sample error from surface error on real DEMs?** Partly done in
   study 1, against the bilinear surface for Hobart. Next: MARTINI, and their
   own N43 DTED fixture.
3. **Can the greedy mesher match Delatin's triangle count with constraints?**
   The R prototype inserts points in batches and needs about 35% more
   triangles. A one-at-a-time version would settle whether constraints cost
   anything at all.
4. **Seams as constraints.** Two tiles that share a boundary constraint mesh
   independently and still conform. How does that compare with stitching
   after the fact? What does `edge_sources` record for the shared edge?
5. **Registration in the mesh.** Cell-registered DEM samples give a mesh that
   stops half a cell short of the tile's edge. Write this down for the GRID
   model, alongside their 256/257 note.
6. **Exactness.** Shewchuk predicates are their CPU baseline. Where do float
   breakline vertices from a projected vector source break a constrained mesh,
   and does laridae's exact path matter for terrain at all?
7. **Interchange.** Would a mesh written in the triangle-form tables (or
   geoarrow.triangles) carry everything `TerrainGridMesh` and
   `AdaptiveTerrainMesh` carry? Map field by field, including `heightReference`
   and the error record.

## Not doing yet

- No comments, issues or pull requests to math.gl, loaders.gl or deck.gl.
- No JavaScript port of the constrained mesher. The studies use cdtr from R,
  and Delatin from npm (the same algorithm math.gl vendors) for comparison.
