# Dimension: one word, several meanings

6 October 2026. "2D", "3D" and "n-dimensional" are used everywhere in
meshing, GIS, graphics, finite elements and data analysis, and they do not
always mean the same thing. A "3D mesh" is a surface of triangles to a
graphics programmer and a volume of tetrahedra to a finite-element
analyst; a "2.5D" mesh is a terrain to a GIS user and a curved surface to
fdaPDE; a "4D dataset" is an array with a time axis to a climate scientist.
This note sets out the two meanings that matter for triangulation, how
different communities name them, and where mixing them up causes real
mistakes. It is the reference for the wording on the rest of this site.

## The two meanings

- **Coordinate dimension**: how many coordinates each vertex has. xy is
  2, xyz is 3, xyzm or xyzt is 4. It describes the space the shape sits
  in.
- **Topological dimension**: the dimension of the shape itself,
  independent of its coordinates. A point is 0, a segment or line is 1, a
  triangle or polygon is 2, a tetrahedron or solid is 3. In mesh terms a
  k-dimensional cell is a k-simplex.

The topological dimension can never exceed the coordinate dimension, and
it is often smaller: a triangle in xyz (2 in 3) is a piece of surface; a
line in xy (1 in 2) is a path on a map. The difference is called the
codimension. Triangulations are always made of topologically
2-dimensional cells, whatever the coordinates; a tetrahedralisation is
the 3-dimensional equivalent.

This site first used "geometric dimension" for the coordinate count. The
GIS standards and the R spatial packages say "coordinate dimension", and
"geometric" is ambiguous (the geometry object in sf or GEOS reports its
topological dimension), so the site now uses **coordinate dimension**.

## Who calls it what

| Community or library | Coordinate count | Shape dimension | Notes |
|---|---|---|---|
| OGC Simple Features, PostGIS | coordinate dimension (`ST_CoordDim`, `ST_NDims`); spatial dimension counts XY or XYZ only, leaving out M (upstream docs) | dimension, "topological dimension" (`ST_Dimension`) | XYM and XYZM: M is a measure, a coordinate slot that is not spatial |
| sf | `XY`, `XYZ`, `XYM`, `XYZM` classes; `st_zm()` | `st_dimension()`: 0 points, 1 lines, 2 surfaces | |
| geos (R) | `geos_coordinate_dimension()` | `geos_dimension()` | |
| GEOS C API | "cartesian dimension" (`GEOSGeom_getCoordinateDimension`) | "planar dimensionality" (`GEOSGeom_getDimensions`) | two more names for the same pair |
| Mathematics, topology | ambient or embedding dimension | intrinsic or topological dimension; a k-manifold, a k-simplex | codimension = ambient minus intrinsic |
| Computational geometry (Qhull, CGAL) | "d-dimensional" input; CGAL's `_2` and `_3` suffixes (`Triangulation_2`, `Mesh_3`) name the ambient dimension; CGAL dD triangulations report `maximal_dimension()` | the triangulation's current dimension (`dimension()`, `current_dimension()`), which drops below the ambient one for degenerate input such as collinear points | a "d-dimensional Delaunay triangulation" means d coordinates and d-simplices: the two coincide when the input is full-dimensional |
| Graphics (rgl, WebGL, game engines) | "3D" almost always means xyz coordinates | rarely named; a "3D mesh" is usually triangles (a surface), occasionally a volume | "2D" often means screen space |
| Finite elements | the problem's spatial dimension | element dimension: 1D bars, 2D shells and plates, 3D solids | fmesher: "1-, 2-, and 3-dimensional flat and curved manifolds" |
| fdaPDE | xy or xyz nodes | `mesh.1.5D` is a network of segments in xy, `mesh.2D` triangles in xy, `mesh.2.5D` triangles in xyz (any curved surface), `mesh.3D` tetrahedra | the ".5" marks one topological dimension less than the coordinates |
| GIS terrain and LiDAR | xyz points | "2.5D": a surface that is a single-valued function z = f(x, y) | a TIN or DEM is 2.5D; overhangs and caves need true surfaces or volumes ("3D GIS") |
| Arrays (netCDF, GDAL multidimensional, stars, xarray) | not this at all: a dimension is an array axis (x, y, z, time, band) | not used | a "4D" variable has four axes; nothing about mesh shape |
| Statistics and machine learning | dimension = number of variables or features | intrinsic dimension of the data (the manifold the points lie near) | "dimension reduction" lowers the coordinate count, trying to keep the intrinsic structure |
| silicate, anglr | vertex tables with x_, y_ and optional z_ or other columns | models named by primitive: SC on segments (1-simplices), TRI on triangles (2-simplices) | attributes on vertices are columns, not coordinates, until you choose to plot them as such |

## The many "2.5D"s

The half dimension always means "one coordinate more than the shape
really uses", but which shape varies:

- **GIS terrain**: triangles built from xy, with z carried; the surface is
  a function of x and y (a TIN, a DEM). This is how this site uses it, and
  how delaunay's `elevation = TRUE` and lasR's triangulate stage work.
- **fdaPDE**: `mesh.2.5D` is any triangulated surface in xyz, not
  necessarily a function of x and y (a sphere, a brain cortex); its
  `mesh.1.5D` is a network of segments.
- **Elsewhere** (general usage, not from these packages): layered or
  extruded geometry in CAD and machining, and pseudo-3D isometric views
  in games.

When someone says 2.5D, ask whether z can be recovered from x and y
(terrain sense) or not (surface sense).

## Where mixing them up causes mistakes

1. **Delaunay of xyz points is not a triangulated surface.** Delaunay of
   points with three coordinates gives tetrahedra filling their convex
   hull. If the points lie on a surface (a sphere, a terrain), you want
   triangles: on a sphere, the convex hull's facets (`geometry::convhulln`);
   on a terrain, a triangulation of xy with z carried. Asking for "3D
   Delaunay" when you mean a surface gives the wrong topological
   dimension.
2. **Refinement bounds are measured in the coordinates the mesher sees.**
   When a terrain is triangulated in xy and z is carried, a maximum area
   or minimum angle applies to the xy footprint, not to the surface: on a
   steep slope the real triangles are larger and thinner than the bound
   says. The same is true of longitude and latitude used as xy (the
   benchmark does this): areas and angles are in degrees, and both
   distort towards the poles.
3. **Longitude and latitude are coordinate dimension 2 on a surface of
   topological dimension 2 that is not a plane.** Treating them as planar
   xy is fine for topology (which triangle touches which), but not for
   shape, area or the Delaunay property on the sphere. Geocentric xyz
   restores the geometry at the cost of a third coordinate.
4. **Degenerate input lowers the topological dimension.** Collinear
   points have a hull of dimension 1, so there are no triangles to make:
   CGAL reports `dimension() == 1`, Qhull stops on a flat initial simplex
   unless joggled, and other libraries return nothing or an error. A
   pipeline that expects triangles should test for this.
5. **Attributes are not coordinates until you say so.** Elevation, time
   or temperature carried on vertices (point attributes in RTriangle, cdtr,
   trowel and laridae) are interpolated onto new vertices but play no
   part in where vertices go. Making them coordinates (xyz, xyt) changes
   the problem: a triangulation in xy becomes either a surface in xyz or,
   via Delaunay, a set of tetrahedra.
6. **"Dimension" in array tools is an axis.** A stars object with x, y
   and time "dimensions" is a 3-axis array; its cells are still
   topologically 2-dimensional pixels repeated through time.

## The words this site uses

- **Coordinate dimension** for the number of coordinates per vertex,
  written by name: xy, xyz, xyzm, xyzt.
- **Topological dimension** for the shape: point (0), segment or line (1),
  triangle or polygon (2), tetrahedron (3); "k-simplex" in mesh contexts.
- **Triangles in xy** for a planar mesh, **triangles in xyz** for a
  surface, **tetrahedra in xyz** for a volume mesh.
- **2.5D** only in the terrain sense, defined where used.
- No bare "2D" or "3D" except inside a package's own function names
  (`create.mesh.2D()`, `Mesh_3`).
