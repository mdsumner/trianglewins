#!/bin/sh
## Fetch deck.gl-raster's RasterReprojector (MIT, Development Seed; itself
## from mapbox/delatin, ISC) at a pinned commit, and make the sandbox copy
## with one added option (_pixelSize, see pixel-size.patch). Nothing here is
## vendored into trianglewins.
##   sh fetch-upstream.sh && npm install
set -e
cd "$(dirname "$0")"
COMMIT=5b55894f3306867f2ae77166f6b71d2d8f6535f9
curl -fsSL -o delatin.upstream.ts \
  "https://raw.githubusercontent.com/developmentseed/deck.gl-raster/$COMMIT/packages/raster-reproject/src/delatin.ts"
cp delatin.upstream.ts delatin.ts
patch -s delatin.ts < pixel-size.patch
mv delatin.ts delatin.ours.ts
echo "wrote delatin.upstream.ts and delatin.ours.ts"
