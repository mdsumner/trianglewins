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
render dev-drafts/geoarrow-triangles.md dev-drafts/geoarrow-triangles \
  "Triangles in GeoArrow (draft)" "dev draft" \
  "Development draft: what building triangle meshes with wkpool, laridae and cdtr suggests for storing triangles in GeoArrow." \
  ../../
render dev-drafts/geoarrow-triangles-proposal.md dev-drafts/geoarrow-triangles-proposal \
  "Proposal: geoarrow.triangles (draft)" "dev draft" \
  "Development draft: a geoarrow.triangles extension type, written in the shape of a GeoArrow spec proposal, with reference checks." \
  ../../
render dev-drafts/geoarrow-pointclouds.md dev-drafts/geoarrow-pointclouds \
  "Point clouds and the vertex pool (draft)" "dev draft" \
  "Development draft: whether the geoarrow.triangles vertex pool suits point clouds, and prior art for compressed tiles of points indexed by a table (COPC, pgpointcloud, Zarr sharding, zarr-vectors)." \
  ../../
redirect choose../start/#which-package
redirect dimension ../notes/#dimension
redirect interpolation ../notes/#interpolation
redirect roadmap https://github.com/hypertidy/meshcore/blob/main/docs/roadmap.md
