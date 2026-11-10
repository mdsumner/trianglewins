#!/bin/sh
## math.gl's own terrain fixtures (257 x 257 streaming inputs), pinned to a
## math.gl commit. Run from the repository root.
set -e
D=survey/dev-drafts/mathgl-terrain/cache
SHA=7c31b41d48ff7ac20ccd28850d28ad495f60f4ed
mkdir -p $D
for f in pacific-streaming.json sierra-nodata-streaming.json; do
  [ -f $D/$f ] || curl -sS -o $D/$f \
    https://raw.githubusercontent.com/visgl/math.gl/$SHA/modules/geospatial/test/terrain/fixtures/$f
done
echo "fetched math.gl fixtures at $SHA"
