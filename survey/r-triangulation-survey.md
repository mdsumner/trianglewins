# Triangulation in R: a survey of packages and where their algorithms come from

6 October 2026. Companion to the trianglewins benchmark and to the project
notes on laridae, cdtr and trowel (state-of-three.md). Covers every R package found
(CRAN, GitHub, r-universe) that triangulates points, polygons or segment
sets in the plane, classified by algorithm, upstream code, intended use,
input form, constraints, and control over the output. Facts were checked
against package source (CRAN mirrors at github.com/cran, and the authors'
GitHub repos) on this date; versions are the current CRAN or GitHub ones.
Where a claim comes from upstream documentation rather than the R source it
is marked (upstream docs).

## 1. The algorithm families

Each package below falls into one (sometimes two) of these. The families
differ in what they promise about the output, which matters more than
speed.

- **Ear cutting (ear clipping).** Input is a polygon (rings, holes). Output
  uses only the input vertices, every triangle lies inside the polygon, no
  quality guarantee (long slivers are normal), no Delaunay property.
  O(n^2) worst case; Mapbox earcut adds z-order hashing to make it fast in
  practice. Holes are bridged into the outer ring before cutting. Cannot
  take points or loose segments, only rings.
- **Point Delaunay.** Input is points only. Output is the convex hull
  triangulated with the empty-circumcircle property. Algorithms seen in R:
  incremental insertion (Lee-Schachter, Bowyer-Watson, Guibas-Stolfi
  quad-edge), radial sweep (S-hull), Fortune's sweepline (Voronoi first,
  Delaunay as the dual), Quickhull (lift to a paraboloid, take the lower
  hull; works in n dimensions), Delaunator (sweep-hull variant).
- **Constrained Delaunay (CDT).** Points plus segments; the segments are
  forced to be edges, the rest is "as Delaunay as possible". No new
  vertices except, in some libraries, at segment crossings. Holes and
  outside are removed after the fact by seeds, parity or nesting level.
- **Conforming Delaunay.** Segments are split with Steiner points until
  every piece is a true Delaunay edge. Output is fully Delaunay.
- **Quality refinement (Ruppert, Chew, off-centres).** Starts from a CDT and
  inserts Steiner points (circumcentres or off-centres, plus segment
  midpoints when an encroached segment is found) until triangles meet a
  minimum angle and/or maximum area or edge length. Some add a size
  function or a Steiner budget.
- **Mesh smoothing / force-based (DistMesh).** Points are moved by a spring
  analogy and re-triangulated (point Delaunay) each iteration, against a
  signed distance function for the domain. No exact constraint edges.
- **Terrain simplification (greedy insertion).** Input is a height grid;
  vertices are added where the error is worst, the triangulation is
  Delaunay. Output is a TIN approximating the grid.
- **Polygon decomposition.** A polygon is cut into triangles (or convex
  pieces) by a geometric library, usually via a CDT of its boundary.

## 2. Ear cutting

| Package::function | Upstream code | Input | Holes / constraints | Output control | Output |
|---|---|---|---|---|---|
| decido::earcut() (CRAN 0.4.0, MIT) | mapbox earcut.hpp (C++ port of earcut.js), vendored | x,y matrix of one polygon, `holes` = start index of each hole ring | holes yes; no loose segments, no points | none | integer vector of vertex indices, 3 per triangle |
| rearcut (GitHub hypertidy, MIT) | mapbox earcut.js run in V8 | x, y, holes | holes | none | index vector. Superseded by decido |
| silicate::TRI(), TRI0() (CRAN 0.7.1) | decido | sf/sp/silicate models (PATH, SC) | polygon holes via ring structure | none | TRI/TRI0 tables (vertex, triangle, object link) |
| rgl::triangulate() (CRAN 1.3.36) | own R/C ear clipping (refs Eberly) | x,y(,z) polygon, rings separated by NA | holes and islands by nesting (vertex order ignored) | `partial` keeps going on failure | 3 x n index matrix |
| tigers::triangulate() (CRAN, GPL-3, Paradis) | own R implementation, Toussaint (1991) | x,y of one simple polygon | none | `method` 1 or 2 | index matrix |
| interleave (CRAN, dcooley) | earcut.hpp via `geometries` | internal `rcpp_earcut` | holes | none | used for interleaved vertex buffers, not a user API |

Consumers of decido: silicate, anglr (TRI), raybevel and rayvertex
(tylermorganwall, 3D extrusion and roofs).

## 3. Point Delaunay (unconstrained)

| Package::function | Upstream code | Algorithm | Input | Output control | Output |
|---|---|---|---|---|---|
| deldir::deldir() (CRAN 2.0-4, GPL) | own Fortran (Turner) | incremental, Lee and Schachter's second algorithm | x, y (z, id carried) | rectangular window `rw`, dummy points, `eps` duplicate tolerance | delsgs/dirsgs segment tables; triang.list(), tile.list() |
| interp::tri.mesh() (CRAN 1.1-6, GPL) | S-hull (Sinclair) in C++, written as a free replacement for tripack | radial sweep then flips | x, y | `duplicate`, `jitter` | `triSht` object; used by interp::interp, alphahull::delvor |
| geometry::delaunayn() (CRAN 0.5.2, GPL-3) | Qhull, vendored | Quickhull on lifted points, n-D | n x d matrix | Qhull option string (`"Qt Qbb Qc"` etc.) | index matrix (simplices) |
| tessellation::delaunay() (CRAN 2.3.0, GPL-3, S. Laurent) | Qhull, own C | Quickhull, 2D/3D/n-D | matrix | degenerate handling options | rich list (simplices, facets, edges), rgl plots |
| rvoronoi::delaunay() (GitHub coolbutuseless, MIT) | Steven Fortune's C sweepline | Fortune sweep | x, y | none | triangles, optional polygons and areas |
| voronoifortune::voronoi() (CRAN, GPL-3, Paradis) | port of Fortune's early 1990s C | Fortune sweep | coordinate matrix | none | Voronoi and Delaunay lists |
| sf::st_triangulate() (CRAN 1.1-3) | GEOS DelaunayTriangulationBuilder | incremental quad-edge (upstream docs) | any sf geometry; uses its vertices only | `dTolerance` snapping, `bOnlyEdges` | GEOMETRYCOLLECTION of POLYGON (or MULTILINESTRING) |
| geos::geos_delaunay_triangles(), _edges() (CRAN 0.2.5, MIT) | GEOS | as above | any geos/wk geometry | `tolerance` | geos geometry |
| terra::delaunay() (CRAN 1.9-50) | GEOS (GEOSDelaunayTriangulation_r) | as above | SpatVector | `tolerance`, `as.lines` | SpatVector |
| spatstat.geom::delaunay() | deldir | as deldir | ppp point pattern | none | tess of triangles |
| ggforce geom_delaunay_* | deldir | as deldir | ggplot aesthetics | none | ggplot layers |
| lasR triangulate() stage (GitHub/r-universe r-lidar) | Delaunator (C++ port), vendored | sweep-hull | LAS/LAZ point clouds in a streaming pipeline | `max_edge` trims long triangles, `filter`, attribute for z | 2.5D TIN used by DTM/CHM stages, optional file |
| lidR (CRAN 4.3.3) internal C_delaunay / interpolate_delaunay | boost::polygon Voronoi on integer (scaled) coordinates; a vendored incremental Delaunay (hporro, MIT) for spike-free and PTD | Voronoi dual (exact on integers); incremental | LAS objects | `trim` max edge | used for TIN DTM, CHM, ground classification |

Notes. None of these accept segments. GEOS, terra and sf return geometry,
not an index, so topology must be rebuilt by matching coordinates. deldir
and the GEOS family are the de facto point-Delaunay engines in the spatial
stack; Qhull is the n-D one.

## 4. Constrained Delaunay, without refinement

| Package::function | Upstream code | Input | Constraints | Holes / outside | Output |
|---|---|---|---|---|---|
| tripack::tri.mesh() + add.constraint() (CRAN 1.3-9.4, ACM licence, non-free) | Renka TRIPACK, ACM TOMS 751, Fortran | x, y; constraint curves as closed polygons | closed constraint curves, region on one side excluded | by curve orientation | `tri` object, voronoi.mosaic |
| akima (CRAN 0.6-3.6, ACM licence) | Renka's triangulation inside Akima's ACM 761 Fortran | x, y, z | none exposed | none | interpolation only, triangulation internal |
| RCDT::delaunay() (CRAN 1.3.0, GPL-3, S. Laurent) | artem-ogre/CDT (MPL-2.0) via RcppArmadillo | points matrix, `edges` 2-col index matrix | yes, index pairs | CDT eraseOuterTrianglesAndHoles (parity) | list: mesh (rgl mesh3d), edges, constraint edges, area |
| delaunay::delaunay() (CRAN 2.0.0, GPL-3, S. Laurent) | CGAL Constrained_Delaunay_triangulation_2 via RcppCGAL; needs gmp, mpfr | points matrix, `constraints` 2-col index matrix; also 2.5D (`elevation`) and 3D | yes | CGAL nesting level, odd = inside (parity) | list with mesh, edges; mesh2d() to rgl |
| sf::st_triangulate_constrained() (GEOS >= 3.10) | GEOS ConstrainedDelaunayTriangulator: ear clipping then Delaunay edge flips (upstream docs) | POLYGON/MULTIPOLYGON only | polygon rings only; each polygon on its own | holes joined to shell; no outside | GEOMETRYCOLLECTION of triangles |
| geos::geos_constrained_delaunay_triangles() | GEOS, same | polygons | as above | as above | geos geometry |
| terra::delaunay(constrained = TRUE) | GEOS, same | SpatVector polygons | as above | as above | SpatVector |
| cgalPolygons (CRAN 0.1.1, GPL-3) `$convexParts(method = "triangle")` | CGAL Polygon_triangulation_decomposition_2 | R6 polygon (with holes) | polygon boundary | holes | list of triangles as coordinate matrices |
| spatstat.geom::triangulate.owin() | deldir, recursive: Delaunay of window vertices, intersect each triangle with the window, recurse on non-triangles | owin window | window edges respected by construction | holes | tess of triangles |

Notes. GEOS's "constrained" Delaunay is a polygon triangulation (no Steiner
points, no loose segments, no shared topology between polygons), so a
coverage is triangulated polygon by polygon and shared edges are not
matched. RCDT and delaunay are the only CRAN packages that take an
arbitrary segment index (a PSLG) without refinement. Both decide inside and
outside by parity.

## 5. Quality meshing (constrained / conforming Delaunay with refinement)

| Package::function | Upstream code | Input | Constraints | Output control | Output |
|---|---|---|---|---|---|
| RTriangle::pslg() + triangulate() (CRAN 1.6-0.15, CC BY-NC-SA, Sterratt) | Shewchuk Triangle 1.6, vendored | `pslg(P, PB, PA, S, SB, H)`: points, boundary markers, point attributes, segments, hole seed points | segments; crossing segments are split | `a` max area, `q` min angle, `Y` no Steiner on boundary, `j` jettison unused, `D` conforming Delaunay, `S` max Steiner | `triangulation` list: P, T, S, E, PB, PA, EB, neighbours; attributes interpolated onto Steiner points |
| fdaPDE::create.mesh.2D(), refine.mesh.2D() (CRAN 1.1-24, GPL-3) | Triangle, vendored in src/C_Libraries (licence of triangle.c still non-commercial) | nodes, nodesattributes, segments, holes | segments | `minimum_angle`, `maximum_area`, `delaunay`; quadratic elements (`order = 2`) | mesh.2D object for FEM |
| sfdct::ct_triangulate() (GitHub/r-universe hypertidy, archived from CRAN) | RTriangle | sf / sfc / sfg | polygon and line edges | `trim`, plus RTriangle `a`, `q`, ... via `...` | sf GEOMETRYCOLLECTIONs of triangles |
| anglr::DEL(), DEL0() (GitHub/r-universe, archived from CRAN) | RTriangle (cdtr backend on a parked branch) | sf/sp/silicate | segments from paths | `max_area` | DEL/DEL0 relational tables, plot3d/mesh3d |
| retistruct (davidcsterratt) | RTriangle | its own outline objects | outline | area/angle | internal (RTriangle was split out of this package) |
| fmesher::fm_mesh_2d(), fm_rcdt_2d() (CRAN 0.8.0, MPL-2.0, Lindgren) | own C++ (ex-INLA), after Hjelle and Daehlen, Triangulations and Applications (2006) | loc matrix, sf/sp, fm_segm boundary and interior segments, crs | boundary and interior segments | `max.edge` (inner, outer), `min.angle`, `cutoff` (merge near points), `offset` (extension zone), `max.n`, `quality.spec` per vertex, `globe`/sphere meshes, `lattice` | fm_mesh_2d with vertex/triangle tables, crs, FEM matrices |
| tulpaMesh::tulpa_mesh(), refine_mesh() (CRAN 0.1.3, MIT, Colling) | artem-ogre/CDT plus its own Ruppert refinement with off-centres (Ungor 2009) in mesh.cpp | coords matrix/data.frame/formula; boundary as matrix or sf polygon | boundary | `max_edge` (inner, outer), `cutoff`, `extend`, `min_angle`, `max_area`, `max_steiner`; adaptive refine by indicator | tulpa_mesh with FEM matrices; sphere by icosahedral subdivision; 1D and graph meshes |
| geometry::distmesh2d(), distmeshnd() | own R port of Persson and Strang DistMesh, Qhull per iteration | signed distance fn `fd`, size fn `fh`, `h0`, bbox, fixed points `pfix` | domain via distance function; fixed points only, no exact segments | element size function, tolerances, iterations | points and triangle index matrix |

Notes. Triangle is the reference implementation of Ruppert/Chew refinement
and is behind every mature 2D quality mesher in R except fmesher and
tulpaMesh; its licence forbids commercial use, which is why anglr, sfdct
and RTriangle carry CC BY-NC-SA. fmesher is the most capable CRAN option
for statistical (SPDE) meshes: two-zone sizing, near-point merging, sphere
meshes, CRS awareness. tulpaMesh is new (2026) and is the nearest relative
of cdtr: same CDT library, with refinement written on top of it rather than
using CDT's own.

## 6. Terrain and raster-derived TINs

| Package::function | Upstream code | Algorithm | Input | Output control | Output |
|---|---|---|---|---|---|
| terrainmeshr::triangulate_matrix() (CRAN 1.0.1, MIT) | Fogleman's hmm (C++) | Garland and Heckbert greedy insertion, Delaunay | height matrix | max error, max triangles | triangle vertex table |
| lasR, lidR | see section 3 | point Delaunay with max-edge trim | point clouds | `max_edge` | rasters derived from TIN |

## 7. This project's packages, for comparison

| Package | Upstream code | Algorithm | Input | Constraints | Output control | Output |
|---|---|---|---|---|---|---|
| cdtr (hypertidy/cdtr, branch cpp11) | artem-ogre/CDT (MPL-2.0) via cpp11 | CDT, conforming mode, CDT's own refinement (one criterion per pass) | x, y, s0, s1 index vectors; `cdt_pslg()` from RTriangle pslg | segments, crossings resolved | `max_area`, `min_angle`, `max_steiner`, data-driven `min_edge_length`; `unrefined` report; attributes on Steiner vertices | contract tables: vertices with origin, triangles with depth, segments |
| trowel (hypertidy/trowel) | spade 2.15 (Rust, MIT/Apache) via extendr | live CDT handle; insert and remove points and segments; spade refinement | same tables, incremental | segments, crossings spliced into chains | `min_angle`, `max_area`, `max_steiner` | same tables, stable ids across edits |
| laridae (hypertidy/laridae, off CRAN by decision) | CGAL Constrained_triangulation_plus_2 + Delaunay_mesher_2 via cpp11 | fully dynamic CDT with exact predicates; Delaunay mesher with seeds and stepping | x, y, s0, s1, PA; lari_add_points/segments | segments, crossings exact | `min_angle`, `max_area`, `min_edge_length`, sizing function or grid (`size_fun`, `grid_x/y/z`), seeds, `max_steiner`, `lari_step()` | same tables, `lari_depth()` |

## 8. Lineage: which upstream library sits under which package

| Upstream library (language, licence) | Algorithm class | R packages using it |
|---|---|---|
| Shewchuk Triangle (C, non-commercial) | CDT, conforming, Ruppert/Chew refinement | RTriangle, fdaPDE (vendored), via RTriangle: sfdct, anglr, retistruct |
| artem-ogre/CDT (C++, MPL-2.0) | CDT, conforming, simple refinement | RCDT, tulpaMesh, cdtr |
| CGAL (C++, GPL/LGPL parts) | CDT, dynamic CDT, Delaunay mesher, decomposition | delaunay, cgalPolygons, laridae (also raybevel for straight skeletons; RcppCGAL ships headers) |
| spade (Rust, MIT/Apache) | dynamic CDT, refinement | trowel |
| fmesher core (C++, MPL-2.0) | CDT with refinement, sphere | fmesher, and through it INLA, inlabru, sdmTMB and other SPDE users |
| GEOS (C++, LGPL) | point Delaunay (quad-edge), polygon CDT (ear clip + flip) | sf, geos, terra |
| Qhull (C) | Quickhull, n-D Delaunay | geometry, tessellation |
| mapbox earcut (C++ / JS, ISC) | ear cutting | decido, interleave (via geometries), rearcut; via decido: silicate, anglr, raybevel |
| Renka TRIPACK / Akima (Fortran, ACM licence) | incremental Delaunay, constraint curves | tripack, akima |
| S-hull (Sinclair) | radial sweep Delaunay | interp, and through it alphahull |
| Turner's deldir (Fortran) | Lee-Schachter incremental | deldir, spatstat.geom, ggforce, interp (imports) |
| Fortune sweepline (C) | Voronoi / Delaunay | rvoronoi, voronoifortune |
| Delaunator (C++ port) | sweep-hull Delaunay | lasR |
| boost::polygon (C++, BSL) | exact integer Voronoi | lidR |
| hmm (C++, MIT) | greedy-insertion TIN | terrainmeshr |
| own code | various | rgl (ear clipping), tigers (ear clipping), geometry::distmesh2d (DistMesh) |

## 9. Capability matrix against the project contract

Contract (from state-of-three.md): vertex and segment tables in; vertex
(with origin), triangle (with depth) and segment tables out; refinement by
min angle, max area, Steiner budget and edge floor, reporting what was not
done; attributes interpolated onto new vertices.

| Capability | Who has it |
|---|---|
| Arbitrary PSLG (index segments, not just rings) | RTriangle, fdaPDE, RCDT, delaunay, fmesher, tulpaMesh (boundary only), cdtr, trowel, laridae |
| Crossing segments resolved by inserting intersection vertices | RTriangle, CDT-based (RCDT, tulpaMesh, cdtr), CGAL plus (laridae), spade (trowel). Not GEOS (polygons must be valid) |
| Steiner points for quality (angle/area) | RTriangle, fdaPDE, fmesher, tulpaMesh, cdtr, trowel, laridae |
| Steiner budget | RTriangle (`S`), tulpaMesh, cdtr, trowel, laridae; fmesher has `max.n` |
| Size as a function of position | laridae (size_fun / grid), fmesher (per-vertex quality.spec, inner/outer max.edge), geometry::distmesh2d (`fh`), tulpaMesh (indicator-driven refine_mesh) |
| Attributes interpolated onto new vertices | RTriangle (PA), fdaPDE (nodesattributes), cdtr, trowel, laridae |
| Inside/outside by depth rather than parity or seeds | cdtr, trowel, laridae only. Others: hole seed points (Triangle, fdaPDE), parity (RCDT, delaunay), nesting by orientation (rgl, decido, GEOS) |
| Origin of each vertex (input / crossing / Steiner) | cdtr, trowel, laridae. RTriangle exposes it only indirectly (vertex index beyond input count, boundary markers) |
| Report of what refinement could not do | cdtr (`unrefined`), laridae; Triangle silently stops |
| Incremental editing (insert/remove after build) | trowel, laridae. Nothing on CRAN |
| Sphere | fmesher (globe, S2 meshes), tulpaMesh (icosahedral) |
| Works from sf directly | sf, geos, terra (GEOS family), fmesher, tulpaMesh (boundary), sfdct, anglr, silicate |
| Exact predicates | CGAL (delaunay, laridae), CDT uses robust predicates (Lenthe), spade robust, Triangle adaptive exact predicates, boost::polygon exact on integers |

## 10. Observations for this project

1. Licence is the main reason RTriangle is not the answer: everything that
   wants Ruppert refinement on CRAN without a non-commercial clause today
   goes through fmesher or tulpaMesh. cdtr, trowel and laridae close that
   gap with segment-level control those two do not offer (they are aimed at
   SPDE meshes, with a boundary and points, not a general PSLG with
   provenance).
2. tulpaMesh is worth reading before improving cdtr's refinement: it runs
   its own Ruppert-with-off-centres loop over CDT (src/mesh.cpp,
   `cpp_ruppert_refine`) instead of CDT's one-criterion-per-call
   refinement, which is the combined angle+area criterion that
   state-of-three.md lists as an upstream wish for CDT.
3. Every other library decides inside/outside by parity, seeds or ring
   orientation. Depth as a topological count is unique to this project's
   three packages, and is the reason a coverage (shared boundaries) works
   here and not elsewhere (GEOS triangulates each polygon alone; RCDT and
   delaunay use parity, which by state-of-three.md lesson 4 cannot express
   a coverage; inferred, not run).
4. Nothing on CRAN offers a persistent, editable triangulation; trowel and
   laridae are alone in that.
5. The GEOS functions are commonly mistaken for general constrained
   Delaunay. They are polygon triangulations without Steiner points, a
   useful baseline for the harness (trianglewins) alongside decido.
6. For harness breadth, the cheap additions are RCDT and delaunay (same
   PSLG input shape, no refinement), fmesher and tulpaMesh (refinement,
   different controls), and sf::st_triangulate_constrained as the polygon
   baseline.

## 11. Out of scope but adjacent

- 3D surface and volume meshes: Rvcg (VCGlib), cgalMeshes (CGAL), TDA
  (alpha complexes via GUDHI/CGAL), alphashape3d (geometry/Qhull).
- Alpha shapes and hulls built on Delaunay: alphahull (interp), concaveman.
- External programs: RSAGA (SAGA), fasterRaster (GRASS v.delaunay),
  qgisprocess (QGIS algorithms).
- rgeos::gDelaunayTriangulation (GEOS) retired from CRAN in 2023; sf, geos
  and terra replace it.
- Packages that only consume a mesh (INLA, inlabru, sdmTMB, stelfi, sspm,
  rayrender, rayvertex) are not listed separately; their engine is named in
  the lineage table.

## Method

Package metadata and function signatures read from the CRAN mirrors at
github.com/cran/<pkg> and from GitHub repos (hypertidy/rearcut, silicate,
anglr, cdtr, trowel; coolbutuseless/rvoronoi; emmanuelparadis/voronoifortune,
tigers; r-lidar/lasR) on 6 October 2026; package discovery via the
r-universe search API ("triangulation", "delaunay", "earcut") and web
search. Algorithm attributions come from the packages' DESCRIPTION, Rd
references and vendored source headers, except the GEOS internals, marked
(upstream docs). No package was run for this survey; measured behaviour is
in the trianglewins harness.
