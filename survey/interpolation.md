# Interpolation on triangles

7 October 2026. A triangulation is most often built to carry values: a
height at each vertex, a temperature, a source pixel coordinate. Between
the vertices those values have to be filled in, and that is interpolation.
This note covers what the word means in the different places it turns up,
what linear interpolation on triangles does and does not promise, how the
mesh itself (its shape, its constraints, its new vertices) decides the
answer, and which R tools do each job. It follows the vocabulary of
[On dimension](../dimension/): coordinates are xy or xyz, and a value
carried at a vertex is an attribute, not a coordinate.

## What "interpolation" means, depending on who says it

- **Scattered data to a surface.** Values measured at irregular points,
  wanted everywhere (on a grid or at other points). The classic use of a
  Delaunay triangulation, and the main subject here.
- **Resampling a grid.** Values on one grid, wanted on another (nearest,
  bilinear, cubic in GDAL, terra, stars). Bilinear is the grid cousin of
  triangle-linear but not the same thing: it is not linear inside a cell,
  and splitting each cell into two triangles gives a different answer that
  depends on which diagonal is used.
- **Attributes onto new vertices.** A mesher adds vertices (Steiner points
  for quality, intersection points where segments cross) and has to give
  them attribute values. Triangle, cdtr, trowel and laridae do this; it is
  part of this project's contract.
- **Interpolating a map.** A mesh stores a coordinate transformation at its
  vertices (display position to source pixel, longitude and latitude to
  projected xy) and interpolates it across each triangle. Texture
  reprojection and GDAL's approximate transformer work this way. Here the
  "attribute" is itself a pair of coordinates, and the question is how
  small the triangles must be for the straight-line approximation to stay
  within a tolerance.
- **Areal interpolation.** Moving totals or densities between two sets of
  polygons (`sf::st_interpolate_aw()`). No point values are interpolated at
  all; the name is shared, the problem is not.
- **Interpolation versus approximation.** An interpolant passes exactly
  through the data; a smoother (thin plate spline with a penalty, kriging
  with a nugget, a GAM) does not. Triangle-linear is always exact at the
  vertices.
- **Interpolation versus extrapolation.** Triangle methods stop at the
  convex hull (or at the mesh boundary). Outside it they return NA unless
  told to extrapolate (`interp(extrap = TRUE)`), fall back to the nearest
  value (GDAL's linear gridder, within its radius), or do something else.

## Linear interpolation on a triangle

Inside a triangle with vertex values v1, v2, v3, the value at a point p is
w1 v1 + w2 v2 + w3 v3, where w1, w2, w3 are p's barycentric coordinates
(non-negative inside the triangle, summing to 1). The result is the plane
through the three vertices. Across the whole mesh this gives a piecewise
linear surface (a TIN when the attribute is elevation).

What it promises:

- exact for any plane (a + b x + c y);
- continuous everywhere, but with a gradient that is constant in each
  triangle and jumps across every edge (slope and aspect come out
  faceted);
- no overshoot: every interpolated value lies between the minimum and
  maximum of the data, so no new peaks, pits or negative concentrations.

What it does not promise: smoothness, or the same answer on a different
triangulation of the same points. Four points of a square can be split
along either diagonal, and the value at the centre differs. Among all
triangulations of a point set, the Delaunay triangulation gives the
piecewise linear surface of least roughness, for any data (Rippa, 1990),
which is the main reason to use Delaunay for interpolation rather than any
other triangulation of the same points.

## How big and what shape the triangles must be

Along an edge of length h, linear interpolation of a smooth function errs
by at most h^2 / 8 times the largest second derivative along the edge. So
the error falls with the square of the edge length, and a tolerance
translates into a target edge length (or maximum area) wherever the
curvature is known. That is what a sizing field is for: laridae takes a
maximum area as a function of position or as a grid, so triangles can be
small where the surface bends and large where it is flat.

Shape matters too, but not in the way the usual refinement criterion
suggests. The error in the value depends mainly on size; the error in the
gradient depends on the largest angle, and blows up as a triangle flattens
towards 180 degrees (the maximum angle condition, Babuska and Aziz, 1976).
Small angles on their own are harmless for interpolation. A minimum angle
bound still helps, because it also caps the largest angle (a 20 degree
minimum allows at most 140), but a long thin triangle aligned with a
ridge can be a good interpolating triangle, and isotropic meshers such as
Triangle, CDT, CGAL and spade will spend extra triangles avoiding it.

## The mesh decides the answer

1. **Constraints say where edges lie, not where values jump.** Putting a
   breakline, a coastline or a road into a constrained triangulation stops
   triangles from straddling it, so values are not averaged across it. But
   the interpolated surface is still continuous across the line. For a
   real discontinuity (a cliff, a fault, land and sea values on either
   side of a coast) the vertices on the line need two values, one per
   side; in the table form used here that means two vertex rows at the
   same xy, one belonging to each side's triangles.
2. **Contours make flat triangles.** Triangulating contour lines as
   constraints connects many triangles whose three vertices lie on the same
   contour, so they are flat and the surface becomes terraced, with
   ridges and valleys cut off. Refinement helps only if the new Steiner
   vertices get better values than linear interpolation from the flat
   triangle gives them, which by definition they do not; fixing it needs
   extra information (spot heights, a stream network, or an interpolant
   that uses more than one triangle). The trianglewins measures count flat
   triangles for this reason.
3. **New vertices inherit interpolated values.** When a mesher adds a
   Steiner vertex, its attribute is linearly interpolated from the
   triangle it falls in. Triangle does this as it inserts each vertex; cdtr
   matches Triangle to 1e-12; trowel interpolates from the mesh as it was
   before refinement. Refinement therefore never adds information: it
   reshapes the triangles of the same piecewise linear surface. Where the
   attribute is a measurement, adding Steiner points cannot make the
   interpolation more accurate, only make later operations (rendering,
   finite elements) better behaved.
4. **Crossings can have two answers.** Where two constraint segments
   cross, the new vertex lies on both, and linear interpolation along
   each can give a different value (a road crossing a contour, two survey
   lines measured at different times). A mesher has to pick one, average
   them, or keep both as separate attributes. The project contract says
   attributes are linearly interpolated but does not yet say along which
   segment; it is worth settling before the contract is written down.
5. **Inside and outside matter.** Interpolating across a hole (a lake in a
   terrain) or across the gap between two polygons of a coverage mixes
   values that should not mix. Remove those triangles (by depth, seeds or
   parity) before interpolating, and expect NA there.

## Linear in which coordinates?

Barycentric weights are computed in the coordinates the triangulation was
built in. Triangles built from longitude and latitude interpolate linearly
in degrees; the same points triangulated in a projected CRS give different
triangles and different weights, and on the sphere (geocentric xyz,
convex hull facets) different again. For short edges the differences are
small; across a continent, near a pole or across the antimeridian they
are not. Pick the coordinates in which "straight between the vertices"
means what you want, triangulate there, and carry the attribute.

The same holds for a 2.5D terrain: the interpolation is linear over the xy
footprint, so on steep slopes the surface triangles are larger than their
footprint suggests, and a sizing field set in xy undercounts the real
surface.

## Interpolating a map: the reprojection mesh

When the attribute is a coordinate transformation, the error that matters
is in the output: how far from its true position a feature is drawn. Test
a point inside each triangle (an edge midpoint or the centroid), push it
through the exact transformation, compare with the interpolated position,
and split the triangle if the distance exceeds the tolerance. The h^2 / 8
bound above turns into a sizing field from the transformation's second
derivatives. Rims, poles and seams (the antimeridian, a projection's
horizon) are where the curvature is extreme, and they are better
inserted as constraint segments than discovered by refinement. GDAL's
approximate transformer applies the same idea one dimension down, along
scanlines (its default error threshold is 0.125 pixels).

## R tools, by job

CRAN packages first; [GitHub] marks the rest.

| Job | Try | Notes |
|---|---|---|
| Scattered points to a grid, linear | `interp::interp(method = "linear")` | S-hull Delaunay, free licence; `extrap`, `duplicate` arguments; replaces akima |
| Scattered points to a grid, smoother | `interp::interp(method = "akima")`; `interpolation::interpfun(method = "sibson")` | Akima's bicubic on triangles; Sibson natural neighbour via CGAL, exact for quadratics of the form a + bx + cy + d(x^2 + y^2) |
| Same, without triangles | `gstat::idw()`, `gstat::krige()`, `fields::Tps()`, `MBA::mba.surf()`, `terra::interpIDW()` | inverse distance, kriging, thin plate spline, multilevel B-splines; kriging and splines can smooth rather than interpolate |
| Gridding inside the GDAL world | `sf::gdal_utils("grid", ...)` with `-a linear`; `terra::interpNear(interpolate = TRUE)` | GDAL's linear gridder triangulates and interpolates barycentrically, falling back to the nearest value or nodata outside (upstream docs) |
| Values at arbitrary points from a mesh | `geometry::tsearch()` (triangle and barycentric weights); `interp::interpp()`; `fmesher::fm_basis()`, `fm_evaluate()` | fm_basis returns the sparse matrix of barycentric weights, so many evaluations are one matrix product |
| Rasterise a TIN | lidR, lasR (terrain and canopy models); `guerrilla::grid_barycentric()` [GitHub] | guerrilla (hypertidy) tours the methods side by side with the arithmetic visible: barycentric, IDW, TPS, kriging, GAM, Voronoi, GDAL |
| Attributes onto Steiner and crossing vertices | RTriangle (`PA`), cdtr `cdt_triangulate_attr()` [GitHub], trowel, laridae [GitHub] | linear from the containing triangle; see "The mesh decides the answer" above |
| Polygon totals between zone sets | `sf::st_interpolate_aw()` | areal interpolation, not point interpolation |

## Short version

- Linear on triangles is exact at the data, never overshoots, and is
  faceted; Delaunay is the least rough choice of triangles for it.
- Size controls the value error (h squared), the largest angle controls
  the gradient error; long thin triangles along a feature are fine.
- Constraints place edges but do not create jumps; a jump needs two
  values at the same place.
- Steiner points add triangles, not information.
- The weights are linear in the coordinates you triangulated in: choose
  them on purpose.
