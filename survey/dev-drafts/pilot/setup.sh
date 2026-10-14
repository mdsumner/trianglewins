#!/bin/sh
## Environment for the pilot (Linux x86_64). conda-forge was reachable from
## the cloud container where CRAN was not; any R with these packages works.
set -e
PREFIX=${PREFIX:-/opt/mamba/envs/ga}
MM=${MM:-/tmp/cf/mm/bin/micromamba}   # micromamba from conda-forge's micromamba package
$MM create -y -p "$PREFIX" -c conda-forge \
  r-base r-nanoarrow r-wk r-vctrs r-arrow r-sf r-decido r-jsonlite compilers make
export PATH="$PREFIX/bin:$PATH"
git clone --depth 1 https://github.com/hypertidy/wkpool /tmp/wkpool
R CMD INSTALL /tmp/wkpool
## inlandwaters test data from silicate
git clone -q --depth 1 --filter=blob:none --sparse https://github.com/hypertidy/silicate /tmp/silicate
(cd /tmp/silicate && git sparse-checkout set data)
python3 -m pip install pyarrow numpy scipy shapely duckdb
