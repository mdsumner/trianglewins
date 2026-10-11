# Start here: triangles for spatial data

If you work with maps in R, you have probably met triangles without
asking for them. Every filled polygon on a screen is drawn as triangles,
and a terrain model is often a mesh of triangles. Spatial statistics
packages such as INLA build a triangle mesh before they fit anything.
This page explains what triangulation is, what it is good for, and which
package to reach for. It assumes you know sf and nothing else.

## What a triangulation is

A triangulation cuts a shape into triangles that fit together edge to
edge, with no gaps or overlaps. You can start from a polygon or from a
set of points.

![A polygon cut into triangles, and a set of points joined into triangles](idea.png)

Why triangles? A triangle is the simplest shape that can tile any
polygon, and a triangle is always flat. If you know a value at each of
its three corners (an elevation, say), there is exactly one sensible
way to fill in the values inside. That makes triangles the natural unit
for drawing, for interpolating, and for numerical models.

## Three questions, three kinds of answer

Most needs come down to one of three questions. They look alike but
they want different tools, because each one asks for a different
promise about the triangles.

![The same county filled by earcut, its sample points joined by Delaunay, and a refined constrained mesh](three.png)

**"Fill my polygon."** You want to draw a polygon, extrude it, or
compute with its pieces. Any triangles will do, as long as they cover
the polygon exactly. The answer is *ear cutting*: fast, it adds no new
points, and it doesn't care if the triangles are long and thin.

```r
library(sf)
nc <- st_read(system.file("shape/nc.shp", package = "sf"))
wake <- st_transform(nc[nc$NAME == "Wake", ], 32119)
st_triangulate_constrained(st_geometry(wake))   # triangles as polygons

xy <- st_coordinates(wake)[, c("X", "Y")]
xy <- xy[-nrow(xy), ]          # one ring; drop the repeated last point
decido::earcut(xy)             # or as indices into xy, much faster
```

**"Connect my points."** You have points (sample sites, weather
stations, LiDAR returns) and want to know which are neighbours, or to
interpolate between them. The answer is a *Delaunay triangulation*: the
triangles are as close to equilateral as the points allow, and no point
lies inside another triangle's circumcircle. It ignores any boundary and
fills the convex hull of the points.

```r
pts <- st_sample(wake, 60)
st_triangulate(st_union(pts))      # sf, via GEOS
deldir::deldir(st_coordinates(pts)[, 1], st_coordinates(pts)[, 2])  # with Voronoi tiles too
```

**"Keep my edges, and make the triangles nice."** You have boundaries,
coastlines, roads or contours that must stay as edges, and you want
well-shaped triangles of a size you choose. This is a mesh for a model,
a smooth surface, or a finite element solver. The answer is a
*constrained Delaunay triangulation*, refined by adding new points until
every triangle meets a minimum angle and a maximum area.

```r
n <- nrow(xy)
m <- cdtr::cdt_triangulate(xy[, 1], xy[, 2], s0 = 1:n, s1 = c(2:n, 1),
                           max_area = 7e6, min_angle = 25)   # m^2, degrees
```

`s0` and `s1` say which points are joined by an edge that must be kept.
cdtr is on GitHub (`remotes::install_github("hypertidy/cdtr")`). On
CRAN, fmesher does this job for statistical meshes, and RTriangle does
it in general but has a non-commercial licence.

## Three things that catch people out

**Neighbouring polygons should be meshed together.** If you mesh each
polygon separately and add points, the two sides of a shared boundary
get different points, and the meshes don't join up. Meshed as one, the
shared boundary is one set of edges.

![Two neighbouring counties meshed one at a time, and together](neighbours.png)

**"Constrained" in sf, geos and terra means one polygon at a time.**
`st_triangulate_constrained()` keeps each polygon's edges, which is what
you need for drawing. But it adds no new points, takes no loose lines
or points, and never sees two polygons as one mesh.

**Longitude and latitude are not flat.** A maximum area in degrees
squared means different things at the equator and near the poles, and
"nicely shaped" triangles in degrees are stretched on the ground.
Project your data first, as above, unless you are deliberately meshing
the sphere.

## Which package?

CRAN first, because it installs everywhere. Several problems are only
solved off CRAN today, marked [GitHub].

| You want to | Try first | Also consider |
|---|---|---|
| Fill polygons with triangles for drawing | decido | rgl::triangulate, sf::st_triangulate_constrained |
| Delaunay triangles or edges of a point set | deldir | geometry (large sets, xyz and up), interp, the GEOS functions in sf and terra |
| Interpolate scattered values linearly | interp | geometry::tsearch; lidR, lasR for point clouds |
| A TIN from a height grid | terrainmeshr | lidR, lasR from LiDAR points |
| A mesh for an SPDE model (INLA, TMB) | fmesher | tulpaMesh |
| A mesh for finite elements on a polygon | fmesher, fdaPDE | RTriangle, tulpaMesh |
| Polygons, lines and points with every edge kept | RCDT | RTriangle, delaunay; [GitHub] cdtr |
| Good-shaped triangles on any set of edges | RTriangle | [GitHub] cdtr, laridae, trowel |
| Triangle size that varies over space | fmesher | geometry::distmesh2d; [GitHub] laridae |
| Add or remove points and edges after building | nothing on CRAN | [GitHub] trowel, laridae |
| A mesh on the sphere | fmesher | tulpaMesh; for points only, see [Notes](../notes/#triangles-on-the-sphere) |
| Delaunay of xyz points (tetrahedra) | geometry, tessellation | delaunay |

## Where to go next

- [How the engines differ](../context/): the same inputs through earcut,
  GEOS and a full mesher, side by side, with the words (constraint,
  Steiner point, depth) explained as they come up.
- [Package survey](../survey/): every R package found, what algorithm and
  library it uses, and what it can and cannot do. A reference, not a
  read.
- [Notes](../notes/): what "2D" and "3D" mean to different people, and
  what interpolation on triangles promises.
- [Benchmark](../bench/): speed, memory and mesh quality at scale, for
  developers.

Figures are drawn by
[`survey/start/figures.R`](https://github.com/mdsumner/trianglewins/blob/main/survey/start/figures.R).
