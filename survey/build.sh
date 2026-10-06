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
render dimension.md dimension "On dimension" "on dimension" \
  "Coordinate dimension versus topological dimension: how GIS, geometry, graphics, finite elements and array tools use the word, and where it matters for triangulation."
render roadmap.md roadmap "Roadmap for R and Python" roadmap \
  "Development steps, CRAN order and blockers for cdtr, laridae and trowel, and what this work can offer other R and Python triangulation packages."
