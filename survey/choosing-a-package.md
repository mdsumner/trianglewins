# Choosing a triangulation package in R

6 October 2026. A guide for R users who need triangles and want to know
what to try first. It is organised by the problem you are solving, not by
package. Within each problem, CRAN packages come first, marked **[CRAN]**;
packages installed from GitHub or r-universe follow, marked **[GitHub]**.
CRAN is the first choice because it installs everywhere with
`install.packages()` and is checked against current R, but several
problems (editing a mesh, refinement with a free licence for a general
segment set) are only solved off CRAN today.

The detail behind every claim (algorithm, upstream library, arguments) is
in the [survey](../survey/), and measured times are in the
[benchmark](../bench/).

**Dimension has two meanings here, and we always say which.**
*Coordinate dimension* is the number of coordinates per vertex: xy (2),
xyz (3), xyzt (4) and so on. *Topological dimension* is the dimension of
the shape itself: 0 a point, 1 a segment or line, 2 a triangle or polygon,
3 a tetrahedron. A triangulation is made of topologically 2-dimensional
cells whatever its coordinates: triangles in xy are a planar mesh,
triangles in xyz are a surface (a terrain, a sphere). Delaunay of points
with d coordinates gives d-dimensional simplices: triangles for xy,
tetrahedra for xyz. "2.5D" means triangles built from xy only, with z
carried along, so the surface is a single-valued function of x and y. A
value carried at a vertex that the triangulation does not use (elevation,
temperature, time) is an attribute, not a coordinate. How other
communities use these words, and where mixing them up bites, is in
[On dimension](../dimension/).

## Quick answers

| You want to | Try first [CRAN] | Also consider |
|---|---|---|
| Fill polygons with triangles for drawing (rgl, WebGL, a scene in xyz) | decido | rgl::triangulate, sf::st_triangulate_constrained |
| Delaunay triangles or edges of a point set | deldir | geometry (large, or points with more than two coordinates), interp, sf / terra / geos / gdalraster for spatial objects |
| Interpolate scattered values linearly | interp | geometry::tsearch, lidR / lasR for point clouds |
| A TIN from a height grid | terrainmeshr | lidR / lasR from LiDAR points |
| A mesh for a statistical model (SPDE, INLA, TMB) | fmesher | tulpaMesh |
| A mesh for finite elements on a polygon | fmesher, fdaPDE | RTriangle, tulpaMesh |
| Triangulate polygons, lines and points with every segment kept | RCDT | RTriangle (refinement, non-commercial licence), delaunay (CGAL); [GitHub] cdtr |
| Good-shaped triangles (min angle, max area) on a general segment set | RTriangle | [GitHub] cdtr, laridae, trowel |
| Mesh density that varies over space | fmesher | geometry::distmesh2d; [GitHub] laridae |
| Add or remove points and segments after building | nothing on CRAN | [GitHub] trowel, laridae |
| A mesh on the sphere | fmesher | tulpaMesh; for points only, geometry::convhulln on geocentric XYZ (PROJ "+proj=cart" via reproj, PROJ, gdalraster, sf, terra) |
| Delaunay of xyz (or more) coordinates: tetrahedra and higher simplices | geometry, tessellation | delaunay (tetrahedra in xyz, CGAL) |

## 1. Drawing polygons: fill them with triangles

You have polygons (with holes) and need triangles to render them: rgl,
rayrender, a WebGL or deck.gl layer, an extruded model in xyz. Extra vertices
are unwelcome and triangle shape does not matter.

- **decido [CRAN]**: `earcut(xy, holes)`. Mapbox's ear-cutting library;
  very fast, no dependencies, returns vertex indices so the triangles share
  your original coordinates. One polygon (with its holes) per call. Used
  by silicate, anglr and raybevel.
- **rgl::triangulate() [CRAN]**: ear clipping with rings separated by NA;
  works out holes and islands from nesting, so ring order and direction do
  not matter. Good when you are already in rgl.
- **sf::st_triangulate_constrained() [CRAN]** (also geos, terra with
  `constrained = TRUE`, gdalraster): GEOS ear clipping followed by Delaunay
  flips, so triangles are better shaped than plain ear cutting. Returns
  triangle polygons, not indices, so you rebuild the index by matching
  coordinates. Needs GEOS 3.10 or later.
- **silicate::TRI() [CRAN]**: decido applied to every feature of an sf
  object, returning shared vertex and triangle tables.

Why not Delaunay here: a point Delaunay ignores the polygon edges, and a
constrained Delaunay mesher is more than you need unless you also want
good-shaped triangles.

## 2. Points to triangles: neighbours, graphs, Voronoi

You have points and want the Delaunay triangulation (or its edges, or the
dual Voronoi tiles) for neighbour graphs, spatial statistics, natural
neighbour ideas or plotting.

- **deldir [CRAN]**: the standard. Pure Fortran, no system dependencies;
  triangles, Voronoi (Dirichlet) tiles, clipping to a rectangle, tile
  summaries. Used by spatstat and ggforce, so the answers agree with those.
- **geometry::delaunayn() [CRAN]**: Qhull. Fast on large point sets and
  the one to use for points with three or more coordinates (output is
  tetrahedra for xyz, higher simplices beyond). Returns an index
  matrix. tessellation (also Qhull) adds richer output and plotting.
- **interp::tri.mesh() [CRAN]**: S-hull, free licence; pairs with
  interp's interpolation functions.
- **sf::st_triangulate(), terra::delaunay(), geos::geos_delaunay_triangles(),
  gdalraster::g_delaunay_triangulation() [CRAN]**: all GEOS. Use whichever
  matches the objects you already have (sf, SpatVector, geos, WKB). Output
  is geometry, not an index.
- **spatstat.geom::delaunay() [CRAN]**: deldir, for ppp point patterns.
- **voronoifortune [CRAN]**, **rvoronoi [GitHub]**: Fortune's sweepline,
  when Voronoi is what you mainly want.

Duplicates: deldir drops duplicated points (and reports which were kept), interp has
`duplicate =`, Qhull merges them by option; check what your package does
before counting triangles.

## 3. Interpolating scattered values

You have values at irregular points and want a surface (linear on
triangles). What that interpolation promises, and how the mesh changes
the answer, is in [Interpolation on triangles](../interpolation/).

- **interp::interp() [CRAN]**: linear and Akima spline interpolation on a
  Delaunay triangulation, under a free licence. Prefer it to akima and
  tripack, whose ACM licence is not free.
- **geometry::tsearch() [CRAN]**: finds the containing triangle and
  barycentric weights for query points, if you want to do the
  interpolation yourself from geometry::delaunayn().
- **lidR [CRAN]** and **lasR [GitHub, r-universe]**: for LiDAR. Both build
  a Delaunay TIN of ground points (with a maximum edge to trim the hull)
  and rasterise it into a DTM or canopy model; lasR streams large
  collections of tiles.
- RTriangle and the [GitHub] mesh packages (cdtr, trowel, laridae) carry
  point attributes onto any new vertices, which helps when the mesh has
  been refined and you still need values at every vertex.

## 4. A TIN from a raster

- **terrainmeshr [CRAN]**: Garland and Heckbert greedy insertion; adds
  vertices where the error is largest until a tolerance or a triangle
  budget is met.
- For point clouds rather than grids, see lidR and lasR above.

## 5. A mesh for a spatial statistical model

You are fitting an SPDE model (INLA, inlabru, sdmTMB, tulpa) and need a
mesh covering the data with a buffer.

- **fmesher [CRAN]**: the default and the most complete. `fm_mesh_2d()`
  takes points, sf or sp boundaries and interior segments, with
  `max.edge = c(inner, outer)` for a fine study area and coarse buffer,
  `cutoff` to merge near points, `min.angle`, and meshes on the sphere.
  Free licence (MPL-2.0), no system dependencies. Use it when INLA or
  inlabru is your model engine, since they expect its mesh objects.
- **tulpaMesh [CRAN]**: newer (2026), on the CDT library with its own
  Ruppert refinement; similar controls (`max_edge`, `cutoff`,
  `min_angle`, `max_area`, `max_steiner`), sf boundaries, adaptive
  refinement from an indicator, sphere meshes, and finite element
  matrices. Worth trying if you are not tied to INLA.

## 6. A mesh for finite elements on a domain

You have a polygonal domain (with holes, maybe internal boundaries) and
want well-shaped triangles to solve a PDE.

- **fmesher [CRAN]**: as above; it also computes FEM matrices.
- **fdaPDE [CRAN]**: `create.mesh.2D(nodes, segments, holes)` and
  `refine.mesh.2D(minimum_angle, maximum_area)`. Use it if fdaPDE is your
  solver. Its mesher is a copy of Triangle.
- **RTriangle [CRAN]**: Shewchuk's Triangle, the reference quality mesher
  (minimum angle `q`, maximum area `a`, conforming Delaunay `D`, Steiner
  limit `S`, holes, boundary markers, attributes). Its licence forbids
  commercial use (CC BY-NC-SA).
- **geometry::distmesh2d() [CRAN]**: DistMesh. Describe the domain by a
  signed distance function and the size by a function; produces very
  even meshes on smooth domains. No exact boundary segments, so not for
  data with fixed edges.
- **tulpaMesh [CRAN]**: as above.

## 7. Triangulating polygons, lines and points together, keeping every edge

You have a planar straight-line graph: polygon boundaries, perhaps shared
between neighbours (a coverage), contour lines, roads, sample points. You
want triangles whose edges include every input segment, and you want to
know which triangle lies in which polygon.

- **RCDT [CRAN]**: the CDT library; points plus an index matrix of edges,
  crossing edges handled, outside and holes removed by parity. No
  refinement. Free licence, no system dependencies. The simplest correct
  CRAN choice for a constrained triangulation without new points.
- **RTriangle [CRAN]**: the same, plus refinement, plus attributes; holes
  must be given as seed points. Refuses duplicated vertices, so merge
  shared vertices first. Non-commercial licence.
- **delaunay [CRAN]**: CGAL's constrained Delaunay; needs the gmp and mpfr
  system libraries. Inside and outside by nesting parity.
- **sf::st_triangulate_constrained() [CRAN]** and the other GEOS
  interfaces: only for valid polygons, one polygon at a time; shared edges
  between neighbours are not matched and loose lines and points are not
  allowed.
- **cdtr [GitHub]** (`remotes::install_github("hypertidy/cdtr")`):
  CDT with refinement and the same vertex/segment/triangle tables in and
  out, a depth for every triangle (how many boundaries lie between it and
  the outside), the origin of every vertex, and attribute interpolation.
  No system dependencies. Use it when you need to know where each
  triangle sits in a coverage, or need refinement without Triangle's
  licence.
- **sfdct, anglr [GitHub]**: convenience wrappers that take sf objects to
  RTriangle; same licence.

Parity versus depth: parity (odd inside, even outside) works for nested
rings but not for a coverage of neighbouring polygons. If your input is a
coverage, use cdtr, trowel or laridae, or label triangles yourself with a
point-in-polygon test of each centroid.

## 8. Good-shaped triangles on a general segment set

Quality refinement (a minimum angle, a maximum area) on arbitrary
constraints, not just a domain boundary.

- **RTriangle [CRAN]**: fastest and most mature; licence permitting, start
  here. It may stop short of the angle bound on intricate coastlines
  without telling you.
- **fmesher, tulpaMesh [CRAN]**: if your constraints fit their model
  (boundary plus interior segments) and their controls.
- **cdtr [GitHub]**: refinement by area and angle with a Steiner budget
  and an edge-length floor, and a report of what it could not refine.
- **laridae [GitHub]**: CGAL's mesher, with exact arithmetic, seeds, and
  refinement one step at a time. Needs CGAL 6 headers. GPL.
- **trowel [GitHub]**: spade (Rust) refinement on a live mesh; needs a Rust
  toolchain.

## 9. Mesh density that varies over space

- **fmesher [CRAN]**: two zones (inner, outer) via `max.edge`, and per
  vertex control through `quality.spec`.
- **geometry::distmesh2d() [CRAN]**: any size function `fh(p)`.
- **tulpaMesh [CRAN]**: adaptive refinement from a per-triangle indicator
  (for example a model's error).
- **laridae [GitHub]**: a sizing field as an R function of position or as
  a grid, for example finer triangles where a raster is steep.

## 10. Editing a mesh after it is built

Adding a point, a segment, or removing them, without starting over (an
interactive tool, a simulation that moves a boundary, streaming data).

- Nothing on CRAN keeps a mesh you can edit. With any CRAN package you
  rebuild from scratch; that is fine for small inputs.
- **trowel [GitHub]**: a persistent mesh with stable vertex and segment
  ids across insertions and removals; inserting into a 100 thousand
  vertex mesh takes tens of microseconds. Needs Rust.
- **laridae [GitHub]**: CGAL's fully dynamic constrained triangulation, the
  same operations with exact crossings; on the benchmark, 1000 points
  were added to a world-scale mesh in 0.09 s, against 44 to 49 s to
  rebuild.

## 11. Surfaces in xyz (sphere, ellipsoid), and Delaunay with more coordinates

- On the sphere, with constraints or refinement: **fmesher [CRAN]**
  (globe and S2 meshes) and **tulpaMesh [CRAN]** (icosahedral
  subdivision).
- On the sphere or ellipsoid, points only: convert longitude and latitude
  to geocentric xyz and take the convex hull of the xyz points. The hull's
  facets are triangles: topological dimension 2 in coordinate dimension 3.
  Every point on a convex
  surface is a hull vertex, so the hull's triangular facets are a
  triangulation of the surface, and on a sphere it is exactly the
  spherical Delaunay triangulation (the empty-circumcircle test on the
  sphere is the empty-half-space test of the hull). On an ellipsoid the
  hull is still a valid triangulation of the points, only not strictly
  Delaunay in the geodesic sense.
  - xyz: any PROJ interface with the target `"+proj=cart"` (geocentric
    on the source datum's ellipsoid), for example **reproj::reproj_xyz()**
    or **reproj::reproj()** (which also transforms whole meshes),
    **PROJ::proj_trans()**, **gdalraster::transform_xy()** (z kept if
    given), **geographiclib::geocentric_fwd()** (no PROJ needed), and the transformations in **sf**, **terra** and other PROJ
    based packages [all CRAN]. On a sphere you can compute it directly:
    `x = cos(lat) * cos(lon)`, `y = cos(lat) * sin(lon)`, `z = sin(lat)`
    (radians).
  - Hull: **geometry::convhulln(xyz) [CRAN]** returns a 3-column triangle
    index (Qhull triangulates facets by default). Use the hull, not
    `delaunayn(xyz)`: Delaunay of xyz points gives tetrahedra (topological
    dimension 3) filling the ball, whose outer faces are the same hull triangles, so convhulln is
    the direct route. tessellation, cxhull and delaunay (CGAL) [CRAN] can
    also compute hulls of xyz points.
  - Caveats: no constraint segments and no refinement; regional data (not
    covering the globe) gets a facet spanning the uncovered part, which
    you remove (for example by dropping facets whose normal points away
    from the data, or with a maximum edge length). Map triangles back
    with the same vertex index, since the hull keeps your input order.
- Everything else here triangulates xy coordinates, so for other
  approaches project your data to xy first (a local equal-area or azimuthal projection keeps shapes
  reasonable).
- Delaunay of points with xyz or more coordinates (tetrahedra and higher
  simplices): **geometry [CRAN]** and **tessellation [CRAN]** (Qhull, any
  number of coordinates), **delaunay [CRAN]** (CGAL: tetrahedra in xyz,
  and 2.5D triangles built from xy with z carried).
- Surface meshes (triangles in xyz) and volume meshes (tetrahedra):
  remeshing, alpha shapes: Rvcg, cgalMeshes,
  alphashape3d, TDA [CRAN]; these are outside this guide.

## Things that decide the choice before the algorithm does

- **Licence.** RTriangle, fdaPDE's mesher, sfdct and anglr carry Triangle's
  non-commercial terms. tripack and akima are under the ACM licence (not
  free); interp replaces both. Everything else named here is GPL, LGPL,
  MIT or MPL.
- **Installation.** No system dependencies: decido, deldir, geometry,
  interp, RCDT, fmesher, tulpaMesh, RTriangle, terrainmeshr, cdtr. GDAL
  and GEOS: sf, terra, gdalraster (geos instead bundles GEOS through the
  libgeos package). gmp and mpfr: delaunay, cgalPolygons. Rust toolchain: trowel.
  CGAL 6 headers: laridae.
- **Index or geometry out.** The GEOS family returns triangle polygons.
  Everything else returns vertex indices, which you need for meshes,
  graphs, interpolation and rendering.
- **Duplicates and crossings.** RTriangle refuses duplicated vertices; CDT
  packages (RCDT, cdtr) and CGAL (delaunay, laridae) split crossing
  segments at their intersection; GEOS needs valid polygons.
- **Inside and outside.** Ear cutting and GEOS work from ring nesting;
  RTriangle and fdaPDE need hole seed points; RCDT and delaunay use
  parity; cdtr, trowel and laridae report depth and leave the choice to
  you.
