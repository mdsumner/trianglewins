#!/bin/sh
## Render the articles into the Pages site, and write redirect stubs for
## pages that were merged into others. render's optional 6th argument is the
## relative path back to the site root (default ../), for pages nested deeper.
##   sh survey/build.sh
set -e
render () {
  mkdir -p "docs/$2"
  pandoc -f gfm -t html5 --template survey/template.html \
    --metadata pagetitle="$3" -V crumb="$4" -V description="$5" \
    -V root="${6:-../}" \
    -o "docs/$2/index.html" "survey/$1"
  echo "wrote docs/$2/index.html"
}
redirect () {
  mkdir -p "docs/$1"
  cat > "docs/$1/index.html" <<HTML
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Moved</title>
<meta http-equiv="refresh" content="0; url=$2">
<link rel="canonical" href="$2">
</head>
<body><p>This page has moved to <a href="$2">$2</a>.</p></body>
</html>
HTML
  echo "wrote docs/$1/index.html (redirect)"
}
render start.md start "Start here: triangles for spatial data" "start here" \
  "A gentle introduction to triangulation for spatial users in R: what it is, the three common questions, the usual traps, and which package to try."
render r-triangulation-survey.md survey "Triangulation in R" survey \
  "R packages that triangulate points, polygons and segment sets: algorithm, upstream library, input, constraints and output control, with a look at Python."
render context.md context "Triangulation in context" "in context" \
  "Why triangles are everywhere, what earcut and the GEOS functions promise, what silicate and anglr tried, and why laridae builds on CGAL."
render notes.md notes "Notes: dimension and interpolation" notes \
  "Coordinate versus topological dimension, triangles on the sphere, and what linear interpolation on a mesh promises."
render curves.md curves "Curves: bigcurve and s2" curves \
  "What an edge between two longitude, latitude points is, how s2 measures it, and how bigcurve draws it in any map projection."
render grids.md grids "Grids as meshes: Delaunay in what?" grids \
  "Every logically rectangular grid is a mesh; triangulating its points gives a different mesh in every frame, measured on one polar grid block."
render validity.md validity "Polygon validity" validity \
  "What invalid means for polygons under OGC, ESRI and s2 rules, the three readings a repair can choose, what GEOS make_valid does from R and Python, and how triangulation reads parity."
render boundaries.md boundaries "Drawing each boundary once" boundaries \
  "Shared polygon edges as a table of owners: county, state and country lines from one layer, each drawn once, and where vertex identity breaks between layers."
render sizing.md sizing "Sizing fields and map projections" sizing \
  "When a map projection can stand in for a mesh sizing field, when it cannot, and what conformal and equal-area projections do to triangle size, shape and Delaunay."
render dev-drafts/geoarrow-triangles.md dev-drafts/geoarrow-triangles \
  "Triangles in GeoArrow (draft)" "dev draft" \
  "Development draft: what building triangle meshes with wkpool, laridae and cdtr suggests for storing triangles in GeoArrow." \
  ../../
render dev-drafts/geoarrow-triangles-proposal.md dev-drafts/geoarrow-triangles-proposal \
  "Proposal: geoarrow.triangles (draft)" "dev draft" \
  "Development draft: a geoarrow.triangles extension type, written in the shape of a GeoArrow spec proposal, with reference checks." \
  ../../
render dev-drafts/mathgl-terrain.md dev-drafts/mathgl-terrain \
  "math.gl terrain, read from the mesh side (draft)" "dev draft" \
  "Development draft: the math.gl terrain roadmap read against the mesh spec, cdtr and laridae, and the questions we test on our side first." \
  ../../
render dev-drafts/mathgl-breaklines.md dev-drafts/mathgl-breaklines \
  "Breaklines in terrain meshes (draft)" "dev draft" \
  "Development draft: Delatin against a constrained TIN from cdtr on an analytic cliff and the Hobart coast, with sample, surface and coastline error." \
  ../../
render dev-drafts/polygons-are-lines.md dev-drafts/polygons-are-lines \
  "Polygons are just lines (draft)" "dev draft" \
  "Development draft: a polygon is segments plus a fill rule, why that holds because the plane is special, and where it stops holding for volumes, graphs in xyz and the sphere." \
  ../../
render dev-drafts/reprojection-mesh.md dev-drafts/reprojection-mesh \
  "Reprojection meshes for raster tiles (draft)" "dev draft" \
  "Development draft: how GDAL, d3, OpenLayers, MapLibre and deck.gl-raster mesh the warp for raster tiles, measured on polar, hemispheric and antimeridian cases, and where bigcurve, cdtr, laridae and the mesh spec fit." \
  ../../
redirect choose ../start/#which-package
redirect dimension ../notes/#dimension
redirect interpolation ../notes/#interpolation
redirect roadmap https://github.com/hypertidy/meshcore/blob/main/docs/roadmap.md
