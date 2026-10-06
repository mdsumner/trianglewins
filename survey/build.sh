#!/bin/sh
## Render the survey and the package guide into the Pages site:
## docs/survey/index.html and docs/choose/index.html.
##   sh survey/build.sh
set -e
render () {
  mkdir -p "docs/$2"
  pandoc -f gfm -t html5 --template survey/template.html \
    --metadata pagetitle="$3" -V crumb="$4" -V description="$5" \
    -o "docs/$2/index.html" "survey/$1"
  echo "wrote docs/$2/index.html"
}
render r-triangulation-survey.md survey "Triangulation in R" survey \
  "A survey of R packages that triangulate points, polygons and segment sets: algorithm, upstream library, input, constraints and output control."
render choosing-a-package.md choose "Choosing a triangulation package" "choosing a package" \
  "Which R package to try for each kind of triangulation problem, CRAN first."
