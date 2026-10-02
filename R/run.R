#' Scenarios
#'
#' What each case is asked for: constrained only, an area bound (the
#' case's bounding box area divided by its `area_div`), an angle bound
#' (25 degrees), and both.
#' @param case a case
#' @return a named list of `list(max_area, min_angle)`
#' @export
tw_scenarios <- function(case) {
  A <- diff(range(case$x)) * diff(range(case$y)) / case$area_div
  ang <- 25
  list(constrained = list(max_area = NULL, min_angle = NULL),
       area = list(max_area = A, min_angle = NULL),
       angle = list(max_area = NULL, min_angle = ang),
       area_angle = list(max_area = A, min_angle = ang))
}

## median elapsed seconds of one f(), from batches repeated until min_time
## has passed (at most max_reps batches). The clock ticks in milliseconds,
## so fast calls are run several times per batch, enough for about 20 ms.
time_call <- function(f, min_time = 0.2, max_reps = 25L) {
  now <- function() proc.time()[["elapsed"]]
  t0 <- now(); f(); first <- now() - t0
  per <- if (first >= 0.02) 1L else as.integer(min(1000, ceiling(0.02 / max(first, 1e-4))))
  times <- double(0)
  start <- now()
  repeat {
    t0 <- now()
    for (i in seq_len(per)) f()
    times <- c(times, (now() - t0) / per)
    if (length(times) >= max_reps || now() - start >= min_time) break
  }
  stats::median(times)
}

#' Run the comparison
#'
#' Every backend on every case under every scenario. Each run is measured
#' with [tw_measure()], timed with a median over repeats, and run once more
#' with a linear attribute for [tw_attr_error()]. A backend that is not
#' installed gives rows with `status = "skipped"`; an error gives
#' `status = "error"` and the message.
#'
#' @param backends backend names (default all of [tw_backends()])
#' @param cases case names (default all of [tw_cases()])
#' @param scenarios scenario names (default all of [tw_scenarios()])
#' @param time whether to time the runs (FALSE runs each once)
#' @param min_time minimum total seconds spent timing one run
#' @param verbose print one line per run
#' @return a data frame, one row per backend x case x scenario
#' @export
tw_run <- function(backends = names(tw_backends()), cases = NULL, scenarios = NULL,
                   time = TRUE, min_time = 0.2, verbose = interactive()) {
  all_cases <- tw_cases(cases)
  avail <- tw_available()
  fns <- tw_backends()
  rows <- list()
  for (case in all_cases) {
    sc <- tw_scenarios(case)
    if (!is.null(scenarios)) sc <- sc[intersect(names(sc), scenarios)]
    for (snm in names(sc)) {
      s <- sc[[snm]]
      for (b in backends) {
        row <- data.frame(backend = b, case = case$name, scenario = snm,
                          max_area = if (is.null(s$max_area)) NA_real_ else s$max_area,
                          min_angle = if (is.null(s$min_angle)) NA_real_ else s$min_angle,
                          status = "ok", message = NA_character_, stringsAsFactors = FALSE)
        if (!isTRUE(avail[[b]])) {
          row$status <- "skipped"; row$message <- "package not installed"
          rows[[length(rows) + 1L]] <- row
          next
        }
        f <- function(attr = FALSE) fns[[b]](case, s$max_area, s$min_angle, attr = attr)
        warn <- character(0)
        out <- withCallingHandlers(
          tryCatch(f(), error = function(e) e),
          warning = function(w) { warn <<- c(warn, conditionMessage(w)); invokeRestart("muffleWarning") })
        if (inherits(out, "error")) {
          row$status <- "error"; row$message <- conditionMessage(out)
          rows[[length(rows) + 1L]] <- row
          if (verbose) message(sprintf("%-9s %-17s %-11s ERROR %s", b, case$name, snm, row$message))
          next
        }
        if (length(warn)) row$message <- paste(unique(warn), collapse = "; ")
        m <- tw_measure(case, out, s$max_area, s$min_angle)
        m$unrefined <- out$unrefined
        m$time_ms <- if (time) 1000 * time_call(function() suppressWarnings(f()), min_time) else NA_real_
        oa <- tryCatch(suppressWarnings(f(attr = TRUE)), error = function(e) NULL)
        m$attr_err <- if (is.null(oa)) NA_real_ else tw_attr_error(oa, case)
        row <- cbind(row, m)
        if (verbose) message(sprintf("%-9s %-17s %-11s %7d tris %8.2f ms", b, case$name, snm,
                                     row$n_triangles, row$time_ms))
        rows[[length(rows) + 1L]] <- row
      }
    }
  }
  bind_rows(rows)
}

## rbind data frames with differing columns (skipped/error rows are short)
bind_rows <- function(rows) {
  cols <- unique(unlist(lapply(rows, names)))
  rows <- lapply(rows, function(r) {
    for (cc in setdiff(cols, names(r))) r[[cc]] <- NA
    r[cols]
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}
