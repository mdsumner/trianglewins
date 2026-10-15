#!/bin/sh
## Environment for the UGRID-in-Zarr pilot (Linux x86_64). One conda-forge
## env holds both R and Python; micromamba itself came from conda-forge's
## micromamba package. xpublish-tiles is installed from a git clone.
set -e
PREFIX=${PREFIX:-/opt/mamba/envs/uz}
MM=${MM:-/tmp/cf/mm/bin/micromamba}
$MM create -y -p "$PREFIX" -c conda-forge \
  r-base r-wk r-sf r-jsonlite r-cpp11 compilers make gdal \
  python=3.12 xarray zarr uxarray xugrid icechunk numpy pip
export PATH="$PREFIX/bin:$PATH" PROJ_DATA="$PREFIX/share/proj"
git clone -q --depth 1 https://github.com/hypertidy/cdtr /tmp/cdtr && R CMD INSTALL /tmp/cdtr
git clone -q --depth 1 https://github.com/earth-mover/xpublish-tiles /tmp/xpublish-tiles
python -m pip install /tmp/xpublish-tiles
## inlandwaters test data from silicate
git clone -q --depth 1 --filter=blob:none --sparse https://github.com/hypertidy/silicate /tmp/silicate
(cd /tmp/silicate && git sparse-checkout set data)
