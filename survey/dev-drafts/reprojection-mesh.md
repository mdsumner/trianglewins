# Reprojection meshes: why they look the way they do

*Development draft, 12 November 2026.*

deck.gl-raster's
[custom projection example](https://developmentseed.org/deck.gl-raster/examples/custom-projection/)
draws Cloud-Optimized GeoTIFFs in any planar map projection. Each tile is
textured onto a triangle mesh. Turn on the debug view over Antarctica with
a longitude/latitude source (GEBCO, EPSG:4326) and the mesh looks bad. It
fans into the pole, it goes almost black in a disc around the pole, and
pink tile outlines run through it. This page explains why it is built
that way, and what our side (bigcurve, the sizing-field work, cdtr and
laridae, and the mesh spec) would change.

Everything here runs headless against deck.gl-raster's own mesher,
`RasterReprojector` in `packages/raster-reproject`, fetched at a pinned
commit. The scripts and results are in
[survey/dev-drafts/reprojection-mesh/](https://github.com/mdsumner/trianglewins/tree/main/survey/dev-drafts/reprojection-mesh).
Nothing has been sent upstream.

The short version:

- **The mesh only exists to warp a texture.** The GPU interpolates
  texture coordinates linearly in each triangle, so the only thing that
  matters is how far a drawn point lands from where it belongs. Triangle
  shape on the map does not matter at all.
- **The dense disc is not a bug.** It comes from linear interpolation of a
  longitude/latitude grid near a pole. The mesh is about evenly dense per
  square degree, and the map squeezes square degrees together near the
  pole. A smarter mesh in source space would not avoid that.
- **The tolerance belongs to the view, not the tile.** Upstream sets the
  error unit for each tile separately. When neighbouring tiles come from
  different overview levels, that triples the polar mesh and leaves
  T-junctions along the tile seams. With one shared unit, both problems go
  away, because the mesher's own midpoint rule is already the bigcurve
  edge rule.
- **Constrained seeds are the real gain.** The mesher accepts any starting
  triangulation. If it starts from a tile clipped to the projection's
  valid area, triangulated with constraints, it handles domains that are
  not longitude/latitude boxes. An orthographic hemisphere goes from 92%
  coverage to all of it.

## How the mesh is built

`RasterReprojector` is a fork of mapbox's Delatin, a greedy Delaunay
refiner for terrain. Here it refines a warp instead of a height:

1. Start each tile from two triangles over its pixel rectangle, in
   **source** texture coordinates (uv).
2. For each triangle, project its corners exactly into the map CRS. Test
   four sample points (the centroid and three edge midpoints): where the
   GPU would draw the point (linear in the triangle) against where it
   belongs (the exact projection).
3. Insert a vertex at the worst sample point, legalise the Delaunay
   triangulation in uv, and repeat until the worst error is below
   `maxError`.

In "output" mode, which the raster layer uses, the error is measured on
the map. The unit is one source pixel's size on the map, measured at the
centre of the tile, and the default `maxError` is 0.125 of that unit.

Building the mesh in source space is the robust choice. The texture
coordinate has to be linear within each triangle. Going the other way,
meshing in map space and interpolating longitude and latitude, fails at
the pole and the antimeridian, where longitude jumps.

![Four tiles from the upstream mesher, in source longitude/latitude (left) and on the polar stereographic map (right). In source space the mesh is ordinary; the fan only appears on the map.](same-mesh.png)

The sandbox uses the example's layout: 22.5 degree tiles of 512 pixels,
in two rows from 45 S to the pole, drawn in south polar stereographic
(spherical, standard parallel 71 S). P is one source pixel on the map at
71 S, 2.79 km. All errors below are in units of P.

## Why the disc is dense

The image of a straight source-space triangle edge on the polar map is a
curve. An edge along a parallel becomes an arc, and an edge along a
meridian stays straight. An edge that changes both longitude and latitude
becomes a piece of a spiral. The spiral's bulge is about
`rho' * dlon * dlat / 4`, where `rho'` is how fast the distance from the
pole grows with latitude. Near the pole, `rho'` is nearly constant. So the
largest triangle allowed is about the same size **in square degrees**
everywhere near the pole. For a tolerance of 0.125 P that is about 0.37
square degrees, or roughly 2.7 triangles per square degree.

The mesher finds that limit without being told:

![Triangles per square degree (black) are flat from 45 S to the pole; triangles per 1000 square km on the map (blue) climb steeply toward the pole.](density.png)

| latitude band | triangles per square degree | triangles per 1000 km^2 |
|---|---|---|
| 90 to 85 S | 2.73 | 5.30 |
| 80 to 75 S | 2.31 | 0.89 |
| 70 to 65 S | 2.38 | 0.49 |
| 50 to 45 S | 2.54 | 0.24 |

The count is flat in source space and goes up more than 20 times per
unit of map area. The disc in the screenshot is that factor, drawn with
one-pixel lines. The polar row holds about as many triangles as the outer
row (19,088 against 18,016) in a third of the map area. No mesh that
interpolates longitude and latitude linearly can do much better, because
the limit comes from the warp, not from how the vertices are placed. The
only way out is not to interpolate at all: compute the texture coordinate
per pixel in the shader, by inverse projection. For analytic projections
like this one, that is cheap.

Two smaller findings:

- **The pole hole can close.** Upstream stops geographic tiles half a
  degree short of each pole, a hole about 110 km across. In output mode
  the mesh converges all the way to the pole, and the polar row
  gets *smaller*: 20,400 triangles against 21,440 with the hole. The
  sliver triangles along the cut edge are the cost.
- **The four-point sampler holds up.** Checked by dense sampling of every
  triangle (28 points each), the true worst error is within 1% of
  `maxError` with a fixed unit and within 3% on the orthographic seeds
  below.

## Seams and the error unit

Upstream measures each tile's error unit at the tile's centre. In this
symmetric layout that is harmless: neighbours in a row have the same
unit, and the edge between the rows happens to split the same way from
both sides. It breaks when neighbours come from different overview
levels, which the tileset does whenever it picks a finer level for part
of the view. A tile one level finer has pixels half the size, so its
tolerance on the map is halved.

| two rows, polar cap one level finer | upstream: unit per tile | one unit for the view |
|---|---|---|
| triangles in the polar cap | 69,440 | 19,104 |
| T-junctions on tile seams | 256 | 0 |
| widest seam gap | 0.067 P | 0 |
| true worst error | 0.168 P | 0.125 P |

![A coarse tile (black) above two finer tiles (blue). Upstream (left) splits the shared parallel more finely from the fine side, leaving vertices on one side only (red). With one unit (right) the vertices match.](seam.png)

A T-junction is a vertex on one side of an edge but not the other. The
gap it leaves is below a tenth of a pixel here, so in practice it shows
up as the occasional dropped pixel along a seam, not a visible crack. The
mesh size is the bigger effect: tying the tolerance to source pixels
makes the polar cap 3.6 times larger for no visible gain.

The fix is one number. With a single error unit for all tiles in a view
(the sandbox adds a `_pixelSize` option, see `pixel-size.patch`), the
seams match exactly and the mesh no longer depends on the overview
level. The cost is that the mesh then depends on the view, so a cache
would key on tile and zoom (a quantised zoom is enough), not on tile
alone.

## The mesher already uses the bigcurve rule

The sandbox's first attempt at "conforming" tiles copied bigcurve. It
densified every tile edge first, by bisecting until the projected
midpoint is within tolerance of the chord. That rule looks only at the
edge, so both tiles sharing an edge get the same vertices. The edges were
then fixed as the seed's boundary.

It made no difference to the seams, and it cost 26% more triangles
(46,732 against 37,152), because a seed with many boundary points and
long thin triangles refines less efficiently. The reason it made no
difference: the greedy mesher only ever splits a boundary edge at its
midpoint, and only when that midpoint's error is over the tolerance.
That is the bigcurve rule, applied lazily. Bisection at midpoints also
nests across levels, since a finer tile's half-edge splits exactly where
the coarse edge would. So the shared error unit is all the seams need.

This suggests how the edge logic should relate to meshes in general. It
is an **edge oracle**: given an edge and a tolerance, it decides the
vertices by looking at that edge alone. A mesher can call it for its
boundary and constraint edges, either up front (bigcurve, then cdtr or
laridae) or lazily (this mesher). The mesh records the result through the
mesh spec's vertex origin (`densify`) and `edge_sources`, which link each
new piece of an edge back to the input edge it came from. That is a
linked capability, not one built into every mesher.

## Constrained seeds: domains that are not boxes

The README for the example lists projections whose valid area is not a
longitude/latitude box, such as an orthographic hemisphere, as
unsupported. The mesher already accepts any valid starting triangulation
(`initialTriangulation`, in delaunator's halfedge shape). So, for each
tile, the sandbox:

1. clips the tile box to the visible cap, traced as a small circle 89.5
   degrees from the view centre, at even spacing on the sphere;
2. triangulates the clipped polygon with constraints (Shewchuk's Triangle
   with the `p` switch, no refinement), and
3. hands that to the unchanged mesher, with the shared error unit.

![Orthographic view centred on Hobart. Box seeds (left) can only draw whole tiles, which leaves the yellow part of the visible disc empty. Constrained seeds (right) draw tiles cut at the horizon (blue) and cover the disc.](ortho.png)

| orthographic, centred on Hobart | box seeds (whole tiles only) | constrained seeds |
|---|---|---|
| tiles drawn | 51 | 77 |
| triangles | 44,886 | 63,911 |
| share of the visible disc covered | 92.3% | 100% |
| true worst error | 0.127 P | 0.129 P |

Three things had to be right. The seed triangles must be wound the same
way as delaunator's output, or the mesher stalls. The cap stops half a
degree short of the horizon, so the chords the mesher splits stay where
the projection is defined. And the horizon is traced at even spacing on
the sphere. A first version traced it at even steps of longitude, and the
mesher never converged on two tiles near the horizon. Even spacing fixed
that. The likely cause is chords that cut outside the hemisphere where
the traced points were far apart, but that has not been checked.

The same approach should handle the README's other limitation:
polar-native rasters in world projections, where one tile spans the
antimeridian and the pole. That needs a seed in two parts, cut along the
antimeridian with the cut as a constraint, and is the next thing to try.

## What our side adds

- **Sizing.** The density limit above is a sizing field for this warp,
  and here it is anisotropic. As the sizing page says, a projection
  cannot stand in for that, and a greedy refiner finds it by sampling.
  For analytic warps it could be computed up front, but the greedy result
  is already close to the limit, so speed is the only gain.
- **Constraints.** Clipped domains, the antimeridian, the pole and
  projection edges are constraint edges. They are cdtr and laridae
  territory, densified by the edge oracle.
- **The mesh spec.** A tile mesh is a mesh with `uv` as the input
  coordinates and map xy as derived positions. Densified vertices carry
  `origin = densify`, and seams can be checked from `edge_sources`
  without looking at geometry.
- **Not triangle shape.** Constrained refinement with a minimum angle
  would make the debug view prettier, and it would cost triangles for no
  gain in the picture.

## Running it

```sh
cd survey/dev-drafts/reprojection-mesh
sh fetch-upstream.sh && npm install
node --experimental-strip-types run.mjs
python3 ortho_seeds.py
node --experimental-strip-types ortho.mjs
python3 figures.py
```

`fetch-upstream.sh` gets the mesher at the pinned commit and applies
the patch; npm adds delaunator. The Python steps need numpy, shapely,
triangle and matplotlib. Node 22 runs the TypeScript mesher directly. `results/summary.csv`,
`results/tiles.csv` and `results/ortho-summary.csv` hold the numbers
quoted here.
