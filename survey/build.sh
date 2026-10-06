#!/bin/sh
## Render the survey to docs/survey/index.html (part of the Pages site).
##   sh survey/build.sh
set -e
mkdir -p docs/survey
pandoc -f gfm -t html5 --template survey/template.html --metadata title="Triangulation in R" \
  -o docs/survey/index.html survey/r-triangulation-survey.md
echo "wrote docs/survey/index.html"
