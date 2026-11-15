# Prototype: ST_* on a mesh with wkpool and geos

Code for the dev drafts
[ST_* on a mesh with wkpool and geos](https://mdsumner.github.io/trianglewins/dev-drafts/st-mesh-geos/)
and [What geoarrow.triangles needs for ST_*](https://mdsumner.github.io/trianglewins/dev-drafts/geoarrow-triangles-st/).

| file | what |
|---|---|
| `st_mesh.R` | 24 ST_* functions on a mesh built by polymer: native measures, combinatorial relations, point location (cdtr `cdt_locate()`), dissolve (wkpool `tri_dissolve()`), clip by box, hull, distance, and the geos fallback |
| `st_mesh.cpp` | compiled kernels: edge table, DE-9IM from indices, boundary edges, measures, clip by box, convex hull, distance grid, vertex pairs; load with `cpp11::cpp_source()` |
| `bench.R` | runs every function against the geos package on three layers and an overlay, checks the answers, writes `results/` |
| `geos-vs-sf.R` | five functions three ways: sf, geos converting from sfc each call, geos on held geometries |
| `figures.R` | `speedup.png` and `relate.png` for the page |
| `feature-layout-check.py` | pyarrow check of the feature-per-row layout with one shared vertex dictionary |
| `results/` | `timings.csv` (median seconds), `checks.csv`, `sizes.csv`, `geos-vs-sf.csv`, session notes |

Run from the repository root:

```
git clone --depth 1 --filter=blob:none --sparse https://github.com/hypertidy/silicate /tmp/silicate
(cd /tmp/silicate && git sparse-checkout set data)
Rscript survey/dev-drafts/st-mesh-geos/bench.R /tmp/silicate/data/inlandwaters.rda survey/dev-drafts/st-mesh-geos/results
Rscript survey/dev-drafts/st-mesh-geos/geos-vs-sf.R /tmp/silicate/data/inlandwaters.rda survey/dev-drafts/st-mesh-geos/results
Rscript survey/dev-drafts/st-mesh-geos/figures.R docs/dev-drafts/st-mesh-geos
python3 survey/dev-drafts/st-mesh-geos/feature-layout-check.py
```

Needs geos (from GitHub, with libgeos; not on conda-forge), wk, bench,
cpp11 (with decor, for `cpp_source()`), and the development versions of
cdtr (with `cdt_locate()`, hypertidy/cdtr#9), wkpool (compiled
`tri_dissolve()`, hypertidy/wkpool#15) and polymer. sf is used only to read
and project `nc.shp`, and in `geos-vs-sf.R`. The results here came from
conda-forge R 4.5.3 with geos 0.2.5 on GEOS 3.11.1, sf 1.1.3 on GEOS 3.14.1,
on 4 cores (`results/session.txt`).

`checks.csv` holds one number per function and layer: 0, or a relative
difference near machine precision, when the mesh answer agrees with geos.
