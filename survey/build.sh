#!/bin/sh
## Render the articles into the Pages site, and write redirect stubs for
## pages that were merged into others.
##   sh survey/build.sh
set -e
render () {
  mkdir -p "docs/$2"
  pandoc -f gfm -t html5 --template survey/template.html \
    --metadata pagetitle="$3" -V crumb="$4" -V description="$5" \
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
render r-triangulation-survey.md survey "Triangulation in R" survey \
  "R packages that triangulate points, polygons and segment sets: quick answers by problem, then algorithm, upstream library, input, constraints and output control, with a look at Python."
render context.md context "Triangulation in context" "in context" \
  "Why triangles are everywhere, what earcut and the GEOS functions promise, what silicate and anglr tried, and why laridae builds on CGAL."
render notes.md notes "Notes: dimension and interpolation" notes \
  "Coordinate versus topological dimension, triangles on the sphere, and what linear interpolation on a mesh promises."
redirect choose ../survey/#quick-answers
redirect dimension ../notes/#dimension
redirect interpolation ../notes/#interpolation
redirect roadmap https://github.com/hypertidy/meshcore/blob/main/docs/roadmap.md
