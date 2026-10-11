## Run the benchmark: every dataset x backend x scenario as its own R
## process, with a timeout and a memory cap, appending to
## bench/results/bench.csv. Rows already in the CSV are not run again, so an
## interrupted run resumes.
##
##   python3 -I bench/cgaz_pslg.py geoBoundariesCGAZ_ADM0.parquet <data dir>
##   Rscript bench/run.R <data dir>
##
## The parquet file is sds::CGAZ(). Environment: BENCH_TIMEOUT (seconds per
## job, default 900), BENCH_MEM_GB (address space cap, default 12),
## BENCH_BACKENDS, BENCH_DATASETS (comma-separated subsets).

args <- commandArgs(TRUE)
datadir <- if (length(args)) args[1] else "data"
out <- "bench/results/bench.csv"
timeout <- Sys.getenv("BENCH_TIMEOUT", "900")
mem_kb <- as.numeric(Sys.getenv("BENCH_MEM_GB", "12")) * 1024^2

ds <- utils::read.csv(file.path(datadir, "datasets.csv"), stringsAsFactors = FALSE)
backends <- c("laridae", "cdtr", "trowel", "RTriangle")
pick <- function(env, all) { v <- Sys.getenv(env); if (nzchar(v)) intersect(all, strsplit(v, ",")[[1]]) else all }
backends <- pick("BENCH_BACKENDS", backends)
datasets <- pick("BENCH_DATASETS", ds$name)
## smallest first, so the table fills in before the big jobs start
datasets <- datasets[order(ds$vertices[match(datasets, ds$name)])]

done <- if (file.exists(out)) utils::read.csv(out, stringsAsFactors = FALSE) else NULL
key <- function(d, b, s) paste(d, b, s)

for (d in datasets) {
  kind <- ds$kind[ds$name == d]
  scen <- if (kind == "points") c("constrained", "area", "quality") else c("constrained", "area", "quality", "insert_1k")
  for (s in scen) for (b in backends) {
    if (!is.null(done) && key(d, b, s) %in% key(done$dataset, done$backend, done$scenario)) next
    f <- tempfile(fileext = ".rds")
    code <- sprintf(paste0("source('bench/bench.R'); ",
                           "r <- bench_job('%s', '%s', '%s'); saveRDS(r, '%s')"),
                    file.path(datadir, paste0(d, ".bin")), b, s, f)
    cmd <- sprintf("ulimit -v %.0f; timeout %s %s -e %s", mem_kb, timeout,
                   file.path(R.home("bin"), "Rscript"), shQuote(code))
    t0 <- proc.time()[["elapsed"]]
    status <- system(cmd)
    wall <- proc.time()[["elapsed"]] - t0
    row <- if (status == 0 && file.exists(f)) readRDS(f) else
      data.frame(dataset = d, backend = b, scenario = s,
                 status = if (status == 124) "timeout" else "crashed",
                 message = if (status == 124) paste("over", timeout, "s") else
                   paste("exit status", status, "(memory cap", Sys.getenv("BENCH_MEM_GB", "12"), "GB)"),
                 stringsAsFactors = FALSE)
    row$job_wall_s <- wall
    row$run_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    done <- trianglewins:::bind_rows(c(if (!is.null(done)) list(done), list(row)))
    utils::write.csv(done, out, row.names = FALSE)
    message(sprintf("%-22s %-9s %-11s %-8s %8s s", d, b, s, row$status,
                    if (is.null(row$time_s)) "" else format(signif(row$time_s, 3))))
  }
}
