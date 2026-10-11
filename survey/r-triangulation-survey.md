# Triangulation in R: a survey of packages and where their algorithms come from

Every R package found (CRAN, GitHub, r-universe) that triangulates points,
polygons or segment sets, classified by algorithm, upstream library, input,
constraints and output control, with a short look at Python. Facts were
checked against package source on 6 October 2026; claims resting only on
upstream documentation are marked (upstream docs). No package was run for
this page: measured behaviour is in the harness and the
[benchmark](../bench/), and the three main engines are compared on worked
examples in [Triangulation in context](../context/). "xy" and "xyz" are
coordinate dimension, and triangles and tetrahedra are topological
dimension; see [Notes](../notes/).

## Before the algorithm

For a short answer by kind of problem, see the table in
[Start here](../start/#which-package). What often decides the choice
before the algorithm does:

- **Licence.** RTriangle, fdaPDE's mesher, sfdct and anglr carry
  Triangle's non-commercial terms; tripack and akima the ACM licence
  (interp replaces both). Everything else is GPL, LGPL, MIT or MPL.
- **Installation.** No system dependencies: decido, deldir, geometry,
  interp, RCDT, fmesher, tulpaMesh, RTriangle, terrainmeshr, cdtr. GDAL and
  GEOS: sf, terra, gdalraster (geos bundles GEOS via libgeos). gmp and
  mpfr: delaunay, cgalPolygons. Rust: trowel. RcppCGAL headers: laridae.
- **Index or geometry out.** The GEOS family returns triangle polygons, so
  topology must be rebuilt by matching coordinates. Everything else
  returns vertex indices.
- **Duplicates and crossings.** RTriangle refuses duplicated vertices
  (merge shared vertices first); CDT and CGAL packages split crossing
  segments; GEOS needs valid polygons.
- **Inside and outside.** Ear cutting and GEOS use ring nesting; Triangle
  and fdaPDE need hole seed points; RCDT and delaunay use parity, which
  cannot express a coverage of neighbouring polygons; cdtr, trowel and
  laridae report depth and leave the choice to you.

## 1. The algorithm families

The families differ in what they promise about the output, which matters
more than speed.

- **Ear cutting.** Rings (with holes) in; triangles using only the input
  vertices out. No shape guarantee, not Delaunay, no points or loose
  segments. O(n^2) worst case; earcut's z-order hashing makes it fast in
  practice.
- **Point Delaunay.** Points only; the convex hull triangulated with the
  empty-circumcircle property. In R: incremental insertion (Lee-Schachter,
  Bowyer-Watson, quad-edge), radial sweep (S-hull), Fortune's sweepline,
  Quickhull (any number of coordinates, giving d-simplices), Delaunator.
- **Constrained Delaunay (CDT).** Points plus segments forced to be edges,
  otherwise as Delaunay as possible. No new vertices except, in some
  libraries, at crossings. Holes and outside removed afterwards by seeds,
  parity or nesting.
- **Conforming Delaunay.** Segments split with Steiner points until every
  piece is a Delaunay edge.
- **Quality refinement (Ruppert, Chew, off-centres).** A CDT plus Steiner
  points until triangles meet a minimum angle and maximum area or edge
  length; some add a size function or a Steiner budget.
- **Smoothing (DistMesh).** Points moved by a spring analogy against a
  signed distance function, re-triangulated each iteration. No exact
  constraint edges.
- **Terrain simplification.** Greedy insertion into a Delaunay TIN where a
  height grid's error is worst.

## 2. Ear cutting

| Package::function | Upstream code | Input | Holes / constraints | Output |
|---|---|---|---|---|
| decido::earcut() (CRAN 0.4.0, MIT) | mapbox earcut.hpp, vendored | x,y of one polygon, `holes` = start row of each hole ring | holes; no loose segments or points | vertex index, 3 per triangle |
| rearcut (GitHub hypertidy) | earcut.js in V8 | x, y, holes | holes | index. Superseded by decido |
| silicate::TRI(), TRI0() (CRAN 0.7.2) | decido | sf/sp/silicate models | holes via ring structure | TRI/TRI0 tables |
| rgl::triangulate() (CRAN 1.3.36) | own ear clipping (Eberly) | rings separated by NA | holes and islands by nesting | 3 x n index |
| tigers::triangulate() (CRAN, Paradis) | own R, Toussaint (1991) | one simple polygon | none | index |
| interleave (CRAN, dcooley) | earcut.hpp via geometries | internal | holes | not a user API |

decido is also used by anglr, raybevel and rayvertex.

## 3. Point Delaunay (unconstrained)

| Package::function | Upstream code | Algorithm | Input | Output control |
|---|---|---|---|---|
| deldir::deldir() (CRAN 2.0-4, GPL) | own Fortran (Turner) | Lee-Schachter incremental | x, y | window `rw`, dummy points, `eps`; drops duplicates and reports which were kept |
| interp::tri.mesh() (CRAN 1.1-6) | S-hull (Sinclair), C++ | radial sweep, flips | x, y | `duplicate`, `jitter` |
| geometry::delaunayn() (CRAN 0.5.2) | Qhull | Quickhull, any number of coordinates | n x d matrix | Qhull options |
| tessellation::delaunay() (CRAN 2.3.0, Laurent) | Qhull | Quickhull | matrix | degenerate handling; rich output |
| rvoronoi (GitHub coolbutuseless) | Fortune's C | sweepline | x, y | none |
| voronoifortune (CRAN, Paradis) | Fortune's C | sweepline | matrix | none |
| sf::st_triangulate(), terra::delaunay(), geos::geos_delaunay_triangles(), gdalraster::g_delaunay_triangulation() | GEOS | quad-edge incremental (upstream docs) | any geometry's vertices | `tolerance`, edges only; geometry out |
| spatstat.geom::delaunay(), ggforce geom_delaunay_* | deldir | as deldir | ppp, aesthetics | none |
| lasR triangulate() (r-universe) | Delaunator, vendored | sweep-hull | LAS/LAZ, streaming | `max_edge`; 2.5D TIN |
| lidR (CRAN 4.3.3), internal | boost::polygon Voronoi on integers; incremental (hporro) | dual of exact Voronoi | LAS | `trim` |

None of these accept segments. gdalraster reaches GEOS through GDAL's OGR
layer, so its GEOS is the one GDAL was built with.

## 4. Constrained Delaunay, without refinement

| Package::function | Upstream code | Input | Holes / outside | Output |
|---|---|---|---|---|
| tripack::tri.mesh() + add.constraint() (CRAN, ACM licence) | Renka TRIPACK (TOMS 751) | x, y; closed constraint curves | curve orientation | `tri` object |
| akima (CRAN, ACM licence) | Renka inside ACM 761 | x, y, z | none | interpolation only |
| RCDT::delaunay() (CRAN 1.3.0, Laurent) | artem-ogre/CDT | points, 2-column `edges` index | parity | list with rgl mesh, edges |
| delaunay::delaunay() (CRAN 2.0.0, Laurent) | CGAL CDT via RcppCGAL; gmp, mpfr | points, `constraints` index; 2.5D `elevation`; xyz to tetrahedra | nesting level, odd inside | list with mesh, edges |
| sf::st_triangulate_constrained(), geos::geos_constrained_delaunay_triangles(), terra::delaunay(constrained = TRUE), gdalraster::g_delaunay_triangulation(constrained = TRUE) | GEOS >= 3.10 (gdalraster: GDAL >= 3.12): ear clipping then flips (upstream docs) | valid polygons, one at a time | holes joined to shell | triangle polygons |
| cgalPolygons (CRAN 0.1.1) `$convexParts(method = "triangle")` | CGAL Polygon_triangulation_decomposition_2 | R6 polygon with holes | holes | coordinate matrices |
| spatstat.geom::triangulate.owin() | deldir, recursive clipping | owin | holes | tess |

GEOS's "constrained" Delaunay is a polygon triangulation: no Steiner
points, no loose segments, each polygon on its own, so shared edges in a
coverage are not matched. RCDT and delaunay are the only CRAN packages
taking an arbitrary segment index without refinement.

## 5. Quality meshing

| Package::function | Upstream code | Input | Output control |
|---|---|---|---|
| RTriangle::pslg() + triangulate() (CRAN 1.6-0.15, CC BY-NC-SA, Sterratt) | Shewchuk's Triangle 1.6 | points, markers, attributes, segments, hole seeds | `a` area, `q` angle, `Y`, `j`, `D` conforming, `S` Steiner limit; attributes onto Steiner points |
| fdaPDE::create.mesh.2D(), refine.mesh.2D() (CRAN 1.1-24) | Triangle, vendored (licence still non-commercial) | nodes, attributes, segments, holes | `minimum_angle`, `maximum_area`; quadratic elements |
| sfdct::ct_triangulate() (r-universe, archived) | RTriangle | sf | `trim`, RTriangle options |
| anglr::DEL(), DEL0() (r-universe, archived) | RTriangle; cdtr via `triangulator` | sf/sp/silicate | `max_area` |
| retistruct (Sterratt) | RTriangle | outlines | area, angle |
| fmesher::fm_mesh_2d(), fm_rcdt_2d() (CRAN 0.8.0, MPL-2.0, Lindgren) | own C++ (ex-INLA) | points, sf/sp, boundary and interior segments, crs | `max.edge` (inner, outer), `min.angle`, `cutoff`, `offset`, `max.n`, `quality.spec`, sphere meshes |
| tulpaMesh::tulpa_mesh(), refine_mesh() (CRAN 0.1.3, MIT, Colling) | artem-ogre/CDT plus its own off-centre Ruppert loop | points, boundary (matrix or sf) | `max_edge`, `cutoff`, `extend`, `min_angle`, `max_area`, `max_steiner`, adaptive refine; sphere; 1D meshes |
| geometry::distmesh2d(), distmeshnd() | DistMesh port, Qhull per iteration | distance function `fd`, size `fh`, fixed points | size function; no exact segments |

Triangle is behind every mature xy quality mesher in R except fmesher and
tulpaMesh, and its licence is why anglr, sfdct and RTriangle carry
CC BY-NC-SA. fmesher is the most capable CRAN option for SPDE meshes.
tulpaMesh (2026) is cdtr's nearest relative: same CDT library, its own
refinement on top.

## 6. Terrain TINs

terrainmeshr::triangulate_matrix() (CRAN 1.0.1, MIT): Fogleman's hmm,
Garland and Heckbert greedy insertion on a height matrix, to a maximum
error or triangle budget. lasR and lidR build TINs from point clouds
(section 3).

## 7. This project's packages

| Package | Upstream code | Algorithm | Output control | Output |
|---|---|---|---|---|
| cdtr (hypertidy/cdtr) | artem-ogre/CDT, MPL-2.0 | CDT, conforming, CDT's refinement (one criterion per pass) | `max_area`, `min_angle`, `max_steiner`, `min_edge_length`; `unrefined` report; attributes | vertices with origin, triangles with depth, segments |
| trowel (hypertidy/trowel) | spade 2.15 (Rust) | live CDT handle, insert and remove, spade refinement | `min_angle`, `max_area`, `max_steiner` | same tables, stable ids across edits |
| laridae (hypertidy/laridae) | CGAL Constrained_triangulation_plus_2 + Delaunay_mesher_2 | fully dynamic CDT, exact predicates, step-wise mesher | angle, area, edge floor, sizing function or grid, seeds, `max_steiner`, `lari_step()` | same tables, `lari_depth()` |

All three take `x, y, s0, s1` and return the triangle form of the
[mesh spec v0.1](https://github.com/hypertidy/meshcore/blob/main/docs/mesh-spec-v0.1.md).
trowel needs work before CRAN: a spatial sort or bulk load (152 s for a
million unordered points, against 2 to 4 s for the others), the southern
Africa stall, Steiner attributes that take the nearest value, then
vendored crates under CRAN's Rust policy.

## 8. Lineage

| Upstream library (licence) | Algorithm class | R packages |
|---|---|---|
| Shewchuk's Triangle (non-commercial) | CDT, conforming, Ruppert/Chew | RTriangle, fdaPDE; via RTriangle: sfdct, anglr, retistruct |
| artem-ogre/CDT (MPL-2.0) | CDT, conforming, simple refinement | RCDT, tulpaMesh, cdtr |
| CGAL (GPL/LGPL parts) | CDT, dynamic CDT, mesher, decomposition | delaunay, cgalPolygons, laridae, raybevel (skeletons) |
| spade (MIT/Apache) | dynamic CDT, refinement | trowel |
| fmesher core (MPL-2.0) | CDT with refinement, sphere | fmesher, and through it INLA, inlabru, sdmTMB |
| GEOS (LGPL) | point Delaunay, polygon CDT | sf, geos, terra; gdalraster via GDAL |
| Qhull | Quickhull, any number of coordinates | geometry, tessellation |
| mapbox earcut (ISC) | ear cutting | decido, interleave, rearcut; via decido: silicate, anglr, raybevel |
| Renka TRIPACK / Akima (ACM) | incremental Delaunay, constraint curves | tripack, akima |
| S-hull | radial sweep | interp, alphahull |
| deldir (Fortran) | Lee-Schachter | deldir, spatstat.geom, ggforce |
| Fortune's sweepline | Voronoi / Delaunay | rvoronoi, voronoifortune |
| Delaunator | sweep-hull | lasR |
| boost::polygon | exact integer Voronoi | lidR |
| hmm (MIT) | greedy-insertion TIN | terrainmeshr |
| own code | various | rgl, tigers, geometry::distmesh2d |

## 9. Capability matrix

Against the shared contract: vertex and segment tables in; vertices (with
origin), triangles (with depth) and segments out; refinement that reports
what it could not do; attributes onto new vertices.

| Capability | Who has it |
|---|---|
| Arbitrary PSLG (index segments, not just rings) | RTriangle, fdaPDE, RCDT, delaunay, fmesher, tulpaMesh (boundary only), cdtr, trowel, laridae |
| Crossing segments resolved | RTriangle, RCDT, tulpaMesh, cdtr, laridae, trowel. Not GEOS |
| Steiner points for quality | RTriangle, fdaPDE, fmesher, tulpaMesh, cdtr, trowel, laridae |
| Steiner budget | RTriangle, tulpaMesh, cdtr, trowel, laridae; fmesher `max.n` |
| Size as a function of position | laridae, fmesher, distmesh2d, tulpaMesh (indicator) |
| Attributes onto new vertices | RTriangle, fdaPDE, cdtr, trowel, laridae |
| Inside and outside by depth | cdtr, trowel, laridae only |
| Origin of each vertex | cdtr, trowel, laridae; RTriangle only indirectly |
| Report of what refinement could not do | cdtr, laridae; Triangle stops silently |
| Editing after build | trowel, laridae. Nothing on CRAN |
| Sphere | fmesher, tulpaMesh |
| sf in directly | GEOS family, fmesher, tulpaMesh, sfdct, anglr, silicate |
| Exact or robust predicates | CGAL, CDT (Lenthe), spade, Triangle, boost::polygon |

## 10. Python, briefly

From PyPI metadata and repositories, not run.

| Package | Upstream | Note |
|---|---|---|
| triangle | Triangle | same table shape as the contract; PyPI says LGPL-3.0 but the C code is non-commercial |
| meshpy | Triangle, TetGen | Triangle licence; TetGen AGPL (upstream docs) |
| scipy.spatial.Delaunay | Qhull | as geometry |
| matplotlib.tri | Qhull, or any triangle array | contract output plugs into `Triangulation(x, y, triangles)` |
| shapely 2.1 | GEOS | same polygon triangulation as sf |
| mapbox-earcut | earcut | as decido |
| PythonCDT (GitHub) | CDT | by the CDT author; refinement and depth exposure not checked |
| cgal (swig bindings, 5.6) | CGAL | has Mesh_2; two releases behind |
| pygalmesh | CGAL | mostly xyz meshing |
| jigsawpy (GitHub) | JIGSAW | sizing-field refinement, like laridae's |
| pydelatin | hmm | as terrainmeshr |
| dmsh | own | DistMesh style |

Python has no editable constrained mesh, no spade binding, and nothing
that reports depth. The PyPI names `spade`, `pyspade` and `cdt` belong to
unrelated projects.

## 11. Observations and offers

Proposals only; nothing has been submitted.

1. **Depth is unique to this project's three packages**, and is why a
   coverage works here and not elsewhere. CDT already has
   `calculateTriangleDepths()`: exposing it is a small offer to RCDT and
   PythonCDT, and CGAL's nesting level is the same offer to delaunay.
2. **The GEOS functions are often read as general constrained Delaunay.**
   A documentation line in sf, geos, terra, gdalraster and shapely saying
   "polygon triangulation, no Steiner points, per polygon" would help.
3. **One CDT, three copies.** RCDT and tulpaMesh vendor pre-2.0 CDT, cdtr
   2.0.1. A shared header package (as BH and RcppCGAL are) would let one
   upgrade reach all three.
4. **tulpaMesh's combined angle and area Ruppert loop** is what CDT itself
   lacks; upstreaming it would benefit RCDT, tulpaMesh, cdtr and
   PythonCDT.
5. **RTriangle** could merge or report duplicated vertices rather than
   refuse them, and say when refinement stops short.
6. **spade `exclude_faces`** in its refinement parameters would make
   trowel's re-refine cheaper and help every spade user.
7. **Harness breadth:** RCDT and delaunay (same input shape), fmesher and
   tulpaMesh (refinement, different controls) and the GEOS polygon
   triangulation are the cheap additions. A backend adapter is one
   function in R/backends.R, which is the easiest invitation to make.
8. **Python:** a core crate under trowel with a PyO3 layer would give
   Python an editable mesh, and the harness cases (CSV) and measures port
   easily, making the comparison cross-language.

Adjacent but out of scope: surface and volume meshing in xyz (Rvcg,
cgalMeshes, TDA, alphashape3d), hulls (alphahull, concaveman), external
programs (SAGA, GRASS, QGIS), and packages that only consume a mesh (INLA,
inlabru, sdmTMB, rayrender). rgeos left CRAN in 2023.

## Method

Metadata and signatures from the CRAN mirrors (github.com/cran) and
authors' repositories on 6 October 2026; discovery through the r-universe
search API and web search; algorithm attributions from DESCRIPTION, Rd
references and vendored source headers.
