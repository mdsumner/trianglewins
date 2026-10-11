# Notes: dimension and interpolation

Two words that cause most of the confusion around triangulation, and the
wording the rest of this site uses for them.

## Dimension

"2D" and "3D" mean different things in different communities: a "3D mesh"
is a surface of triangles to a graphics programmer and a volume of
tetrahedra to a finite-element analyst. Two meanings matter here.

- **Coordinate dimension**: coordinates per vertex. xy is 2, xyz 3, xyzm
  or xyzt 4.
- **Topological dimension**: the dimension of the shape. Point 0, segment
  1, triangle or polygon 2, tetrahedron 3; a k-dimensional cell is a
  k-simplex.

The topological dimension never exceeds the coordinate dimension and is
often smaller: a triangle in xyz is a piece of surface. A triangulation is
always made of topologically 2-dimensional cells, whatever its
coordinates.

| Community | Coordinate count | Shape dimension |
|---|---|---|
| OGC, PostGIS | coordinate dimension (`ST_CoordDim`); M is a measure, not spatial | `ST_Dimension` |
| sf, geos (R) | `XY`, `XYZ`, `XYM`, `XYZM`; `geos_coordinate_dimension()` | `st_dimension()`, `geos_dimension()` |
| GEOS C API | "cartesian dimension" | "planar dimensionality" |
| Mathematics | ambient dimension | intrinsic dimension; codimension is the difference |
| CGAL, Qhull | `_2`, `_3` suffixes name the ambient dimension | `dimension()`, which drops for degenerate input |
| Graphics | "3D" means xyz | rarely named; a "3D mesh" is usually a surface |
| Finite elements, fdaPDE | spatial dimension | element dimension; fdaPDE's `mesh.2.5D` is triangles in xyz, `mesh.1.5D` segments in xy |
| GIS terrain | xyz points | "2.5D": z = f(x, y) |
| Arrays (netCDF, xarray, stars) | neither: a dimension is an array axis | |

"2.5D" always means one coordinate more than the shape uses, but which
shape varies. Here it means the terrain sense: triangles built from xy
with z carried, so z is a function of x and y. In fdaPDE it is any surface
in xyz.

Where mixing them up goes wrong:

1. **Delaunay of xyz points is not a surface.** It gives tetrahedra
   filling the hull. For a terrain, triangulate xy and carry z; for a
   sphere, take the convex hull (below).
2. **Refinement bounds are measured in the coordinates the mesher sees.**
   With z carried, a maximum area bounds the xy footprint, not the
   surface; in longitude and latitude, areas are in degrees squared and
   distort towards the poles.
3. **Degenerate input lowers the dimension.** Collinear points have no
   triangles: CGAL reports `dimension() == 1`, Qhull stops unless joggled.
4. **Attributes are not coordinates** until you make them so. Elevation or
   time carried on vertices is interpolated onto new vertices but plays no
   part in where vertices go.

This site writes xy, xyz and so on for coordinates, names shapes
(triangles in xy, triangles in xyz, tetrahedra in xyz), uses 2.5D only in
the terrain sense, and avoids bare "2D" and "3D".

## Triangles on the sphere

For points on a sphere or ellipsoid, without constraints or refinement:
convert to geocentric xyz (`"+proj=cart"` through reproj, PROJ,
gdalraster, sf or terra; or `x = cos(lat) cos(lon)`, `y = cos(lat)
sin(lon)`, `z = sin(lat)` on a sphere) and take
`geometry::convhulln(xyz)`. Every point of a convex surface is a hull
vertex, so the hull's facets triangulate the surface, and on a sphere
they are exactly the spherical Delaunay triangulation. Vertex order is
kept, so map back by index. Regional data gets a facet spanning the
uncovered part; drop it by facet normal or maximum edge length. With
constraints or refinement, use fmesher or tulpaMesh, or project to a
local planar CRS first.

## Interpolation

A triangulation is most often built to carry values. The word covers
several jobs that share little: scattered data to a surface (the main one
here); resampling a grid (bilinear is not triangle-linear, and splitting
cells into triangles depends on the diagonal); attributes onto vertices a
mesher adds; interpolating a coordinate transformation across a mesh
(texture reprojection, GDAL's approximate transformer); and areal
interpolation of totals between polygons (`sf::st_interpolate_aw()`),
which interpolates no point values at all.

### Linear on a triangle

Inside a triangle the value is w1 v1 + w2 v2 + w3 v3, with barycentric
weights. Across the mesh this is a piecewise linear surface. It is exact
for planes, continuous, and never overshoots the data, but its gradient
jumps across every edge and the answer depends on the triangulation: the
centre of a square differs by diagonal. Delaunay gives the least rough
surface of any triangulation of the same points (Rippa, 1990). Triangle
methods stop at the hull unless told to extrapolate.

### Size and shape

Along an edge of length h, the error is at most h^2 / 8 times the largest
second derivative, so a tolerance becomes a target size wherever the
curvature is known; that is what a sizing field such as laridae's is for.
The value error depends on size; the gradient error depends on the
largest angle (Babuska and Aziz, 1976). Small angles alone are harmless,
so a long thin triangle along a ridge can be a good one, though isotropic
meshers will avoid it.

### The mesh decides the answer

1. **Constraints place edges, not jumps.** A breakline stops triangles
   straddling it, but the surface is still continuous across it. A real
   discontinuity needs two vertex rows at the same xy, one per side.
2. **Contours make flat triangles** whose three vertices share a value,
   terracing the surface. Refinement cannot fix that; it needs extra
   information.
3. **Steiner points add triangles, not information,** when the attribute
   is a measurement: their values are interpolated from the triangle they
   fall in (Triangle, cdtr and laridae do this; trowel interpolates from
   the mesh before refinement). When the attribute can be computed
   anywhere (a transformation, a raster you can sample), new vertices
   should be evaluated instead, and refinement does add information.
4. **Crossings can have two answers,** one along each segment. The mesh
   spec does not yet say which wins.
5. **Remove outside triangles first.** Interpolating across a hole or
   between polygons of a coverage mixes values that should not mix.

### Linear in which coordinates?

Barycentric weights are linear in the coordinates the mesh was built in.
Longitude and latitude, a projected CRS and geocentric xyz give different
triangles and different weights; the differences are small for short
edges and large across a continent, near a pole or across the
antimeridian. Choose the coordinates on purpose. Transforming there and
back is one PROJ call each way, and geographiclib vectorises projection
centres, so a local projection per feature costs no more than a global
one.

For a reprojection mesh, test a point in each triangle against the exact
transformation and split where the error exceeds a tolerance; rims, poles
and seams are better inserted as constraints than found by refinement.

### R tools

| Job | Try |
|---|---|
| Scattered points to a grid, linear | `interp::interp(method = "linear")` |
| Smoother | `interp::interp(method = "akima")`; Sibson via `interpolation::interpfun()`; without triangles: gstat, fields::Tps, MBA, terra::interpIDW |
| GDAL's linear gridder | `sf::gdal_utils("grid", ...)` with `-a linear` |
| Values at points from a mesh | `geometry::tsearch()`, `interp::interpp()`, `fmesher::fm_basis()` (sparse weight matrix) |
| Rasterise a TIN | lidR, lasR; guerrilla [GitHub] compares methods side by side |
| Attributes onto new vertices | RTriangle (`PA`), cdtr, trowel, laridae |
| Totals between zone sets | `sf::st_interpolate_aw()` |
