# Prototype: ST_* functions on a triangle mesh

Code for the dev draft
[ST_* functions on a triangle mesh](https://mdsumner.github.io/trianglewins/dev-drafts/st-mesh/).

| file | what |
|---|---|
| `st_mesh.R` | mesh-native versions of ten ST_* functions in vectorised base R, on a mesh built by polymer; plus R wrappers for the compiled versions |
| `st_mesh.cpp` | compiled grouped loops: extent, touches, point location (grid of triangle buckets), boundary edges and the dissolve walk; load with `cpp11::cpp_source()` |
| `bench.R` | runs every function against sf on three layers, checks the answers, writes `results/` |
| `figures.R` | `speedup.png` and `nc-mesh.png` for the page |
| `results/` | `timings.csv` (median seconds), `checks.csv`, `sizes.csv`, `session.txt` |

Run from the repository root:

```
git clone --depth 1 --filter=blob:none --sparse https://github.com/hypertidy/silicate /tmp/silicate
(cd /tmp/silicate && git sparse-checkout set data)
Rscript survey/dev-drafts/st-mesh/bench.R /tmp/silicate/data/inlandwaters.rda survey/dev-drafts/st-mesh/results
Rscript survey/dev-drafts/st-mesh/figures.R docs/dev-drafts/st-mesh
```

Needs sf, wk, bench, cpp11 (with decor, for `cpp_source()`), and the
development versions of cdtr, wkpool and polymer from GitHub. The results
here came from conda-forge R 4.5.3 with sf 1.1.3, GEOS 3.14.1 and PROJ 9.9.0
on 4 cores (`results/session.txt`).

`checks.csv` holds one number per function and layer, 0 or a relative
difference near machine precision when the mesh answer agrees with sf: the
relative area or coordinate difference, the count of features whose
predicate lists differ, the count of points located in a different feature,
or the symmetric difference area relative to the union's area.
