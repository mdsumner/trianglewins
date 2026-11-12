# Warp Mesh Casebook

An interactive comparison of two ways to draw a lon/lat raster in another
map projection with a GPU texture warp:

- **Screen grid**, as in ortho-cog-viewer: a constant grid in screen space,
  each vertex inverse-projected to lon/lat.
- **Source tiles**, in the style of deck.gl-raster: level-of-detail tiles in
  source lon/lat, each refined on its own until its error is under a
  fraction of a source pixel.

Both are reimplemented here from their published sources and docs
(ortho-cog-viewer c35b303, deck.gl-raster 5b55894); neither project's code
is used. The error heat layer shows how far the interpolated texture lands
from where it belongs, in screen pixels, measured at each triangle's
centroid and edge midpoints.

Cases: constant mesh, pole in view, horizon, antimeridian, polar
stereographic, tiles and seams, and interrupted Goode Homolosine, for each
meshing mode.

## Layout

- `index.html` - the page (no build step; plain scripts)
- `js/core.js` - projections (orthographic, south polar stereographic,
  Equal Earth, interrupted Goode Homolosine) and the screen-grid mesher
- `js/tiles.js` - tile selection, per-tile bintree refinement (a stand-in
  for Delatin: same error test, different triangle shapes), T-junction
  finder and edge conforming
- `js/app.js` - WebGL rendering, synthetic texture, cases and controls
- `tests/*.js` - Node scripts that print the numbers quoted on the page

Run the checks with `node tests/grid.js`, `node tests/tiles.js` and
`node tests/goode.js`.

## Publishing

Part of the trianglewins site: GitHub Pages serves `docs/`, so this page is
at `casebook/`. No build step.
