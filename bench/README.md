# bench: triangulation at scale

The performance benchmark behind the Pages site (`docs/bench/index.html`). Inputs
are country boundaries from geoBoundaries CGAZ ADM0, the GeoParquet that
`sds::CGAZ()` points to, made into vertex and segment tables at sizes from
23 thousand to 6.8 million vertices, plus point clouds sampled from them.

| file | what it does |
|---|---|
| `cgaz_pslg.py` | CGAZ GeoParquet to `<dataset>.bin` (vertices and segments) and `datasets.csv`. Needs pyarrow, shapely, numpy |
| `bench.R` | one job: read a dataset, run one backend on one scenario, time it, measure the output |
| `run.R` | every dataset x backend x scenario, each in its own R process with a timeout and a memory cap; appends to `results/bench.csv` and resumes where it stopped |
| `site.R`, `site-template.html`, `findings.html` | build `docs/bench/index.html` from the results |

```sh
curl -LO https://github.com/mdsumner/geoboundaries/releases/download/latest/geoBoundariesCGAZ_ADM0.parquet
python3 -I bench/cgaz_pslg.py geoBoundariesCGAZ_ADM0.parquet data
Rscript bench/run.R data          # hours, for the large datasets
cp data/datasets.csv bench/results/
Rscript bench/site.R
```

Scenarios: `constrained` (triangulate, drop the outside); `area` (refine
until no triangle exceeds bounding box area / 1e5); `quality` (that bound
plus a 20 degree minimum angle); `insert_1k` (1000 points added to the
constrained mesh, by the live handle for laridae and trowel, by a rebuild
for cdtr and RTriangle). `BENCH_TIMEOUT`, `BENCH_MEM_GB`, `BENCH_BACKENDS`
and `BENCH_DATASETS` adjust a run.
