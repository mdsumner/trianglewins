## Run every backend on every case, one R process per backend (a crash or a
## runaway refinement in one backend cannot take the others with it), then
## write inst/results/results.csv and inst/results/results.md.
##
## From the package root, with trianglewins installed:
##   Rscript inst/scripts/run-all.R
## Environment: TRIANGLEWINS_TIMEOUT seconds per backend (default 3600),
## TRIANGLEWINS_BACKENDS comma-separated subset.

library(trianglewins)
outdir <- "inst/results"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
timeout <- Sys.getenv("TRIANGLEWINS_TIMEOUT", "3600")
backends <- names(tw_backends())
sel <- Sys.getenv("TRIANGLEWINS_BACKENDS")
if (nzchar(sel)) backends <- intersect(backends, strsplit(sel, ",")[[1]])

parts <- lapply(backends, function(b) {
  f <- tempfile(fileext = ".rds")
  code <- sprintf(paste0("library(trianglewins); r <- tw_run('%s', verbose = TRUE); ",
                         "d <- tw_run_dynamic(backends = '%s'); saveRDS(list(r, d), '%s')"),
                  b, b, f)
  status <- system2("timeout", c(timeout, file.path(R.home("bin"), "Rscript"), "-e", shQuote(code)))
  if (status == 0 && file.exists(f)) {
    x <- readRDS(f)
    return(trianglewins:::bind_rows(list(x[[1]], x[[2]])))
  }
  msg <- if (status == 124) paste("timed out after", timeout, "s") else paste("R process exited with status", status)
  message(b, ": ", msg)
  data.frame(backend = b, case = "(all)", scenario = "(all)", status = "crashed", message = msg)
})
res <- trianglewins:::bind_rows(parts)
utils::write.csv(res, file.path(outdir, "results.csv"), row.names = FALSE)

ver <- function(p) if (requireNamespace(p, quietly = TRUE)) as.character(utils::packageVersion(p)) else "not installed"
sha <- function(p) {
  d <- utils::packageDescription(p)
  if (is.list(d) && !is.null(d$RemoteSha)) substr(d$RemoteSha, 1, 7) else ""
}
header <- c("# trianglewins results", "",
            paste0("Run ", format(Sys.time(), "%Y-%m-%d %H:%M %Z"), " on ", R.version.string,
                   ", ", utils::sessionInfo()$running, ", ", parallel::detectCores(), " cores."),
            "",
            paste0("Backends: ", paste(vapply(names(tw_backends()), function(p) {
              paste0(p, " ", ver(p), if (nzchar(s <- tryCatch(sha(p), error = function(e) ""))) paste0(" (", s, ")") else "")
            }, ""), collapse = ", "), "."),
            "",
            paste0("Steiner budget for every refinement: ", format(getOption("trianglewins.max_steiner", 1e5), scientific = FALSE),
                   ". Area bound: bounding box area / 200 (synthetic) or / 5000 (nc, cont_tas, cad_tas).",
                   " Angle bound: 25 degrees (20 in edit_refine)."))
tw_report(res, file.path(outdir, "results.md"), header = header)
cat("wrote", file.path(outdir, "results.md"), "\n")
