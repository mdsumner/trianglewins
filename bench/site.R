## Build docs/index.html (the GitHub Pages site) from bench/results/bench.csv
## and bench/results/datasets.csv. Charts are drawn in the page by a small
## inline script from the embedded rows; no external libraries.
##   Rscript bench/site.R

r <- utils::read.csv("bench/results/bench.csv", stringsAsFactors = FALSE)
ds <- utils::read.csv("bench/results/datasets.csv", stringsAsFactors = FALSE)
meta <- if (file.exists("bench/results/meta.json")) readLines("bench/results/meta.json") else "{}"
keep <- c("dataset", "backend", "scenario", "n_in", "s_in", "reps", "status", "message",
          "time_s", "time_min_s", "peak_mb", "n_vertices", "n_triangles", "area_ok",
          "angle_ok", "angle_min", "segs_kept", "cd_violations", "flat", "depth_match", "unrefined")
for (k in setdiff(keep, names(r))) r[[k]] <- NA
r <- r[keep]
json_rows <- jsonlite::toJSON(r, dataframe = "rows", na = "null", digits = 6)
json_ds <- jsonlite::toJSON(ds, dataframe = "rows", na = "null")
tpl <- paste(readLines("bench/site-template.html"), collapse = "\n")
html <- sub("__ROWS__", json_rows, tpl, fixed = TRUE)
html <- sub("__DATASETS__", json_ds, html, fixed = TRUE)
findings <- if (file.exists("bench/findings.html")) readLines("bench/findings.html") else "<li>Run in progress.</li>"
html <- sub("__FINDINGS__", paste(findings, collapse = "\n"), html, fixed = TRUE)
html <- sub("__META__", paste(meta, collapse = "\n"), html, fixed = TRUE)
dir.create("docs", showWarnings = FALSE)
writeLines(html, "docs/index.html")
file.create("docs/.nojekyll")
cat("wrote docs/index.html\n")
