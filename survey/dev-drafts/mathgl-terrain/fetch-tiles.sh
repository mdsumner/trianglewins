#!/bin/sh
## Four z10 tiles of the AWS open terrain tiles (GeoTIFF, Web Mercator) over
## Hobart, mosaicked into cache/mosaic.vrt. Run from the repository root.
set -e
D=survey/dev-drafts/mathgl-terrain/cache
mkdir -p $D
for xy in "930 647" "931 647" "930 648" "931 648"; do
  set -- $xy
  [ -f $D/z10_$1_$2.tif ] || curl -sS -o $D/z10_$1_$2.tif \
    https://s3.amazonaws.com/elevation-tiles-prod/geotiff/10/$1/$2.tif
done
gdalbuildvrt -q $D/mosaic.vrt $D/z10_*.tif
echo "wrote $D/mosaic.vrt"
