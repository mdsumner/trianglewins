## Timing-focused benchmark on large real inputs (CGAZ country boundaries).
## One job = one dataset x backend x scenario, run in its own R process by
## bench/run.R so that peak memory is per job and a timeout or crash cannot
## take the others down.

read_pslg_bin <- function(path) {
  con <- file(path, "rb"); on.exit(close(con))
  h <- readBin(con, "integer", 2L, size = 4L, endian = "little")
  x <- readBin(con, "double", h[1], size = 8L, endian = "little")
  y <- readBin(con, "double", h[1], size = 8L, endian = "little")
  s0 <- readBin(con, "integer", h[2], size = 4L, endian = "little")
  s1 <- readBin(con, "integer", h[2], size = 4L, endian = "little")
  name <- sub("\\.bin$", "", basename(path))
  trianglewins:::new_case(name, x, y, s0, s1,
                          region = if (length(s0)) "outer" else "hull",
                          area_div = 1e5, note = "CGAZ")
}

## the scenarios: constrained only; an area bound of bbox area / 1e5;
## that bound plus a 20 degree angle bound; and 1000 points inserted into
## the constrained mesh (by a live handle, or by rebuilding with them)
bench_scenarios <- function(case) {
  A <- diff(range(case$x)) * diff(range(case$y)) / case$area_div
  list(constrained = list(),
       area = list(max_area = A),
       quality = list(max_area = A, min_angle = 20),
       insert_1k = list(insert = 1000L))
}

insert_points <- function(case, n) {
  set.seed(1)
  list(x = stats::runif(n, min(case$x), max(case$x)),
       y = stats::runif(n, min(case$y), max(case$y)))
}

peak_rss_mb <- function() {
  st <- tryCatch(readLines("/proc/self/status"), error = function(e) character(0))
  v <- grep("^VmHWM", st, value = TRUE)
  if (!length(v)) return(NA_real_)
  as.numeric(gsub("[^0-9]", "", v)) / 1024
}

## returns list(build = function() handle, run = function(handle) result)
insert_job <- function(backend, case, p) {
  s0 <- if (length(case$s0)) case$s0 else NULL
  s1 <- if (length(case$s1)) case$s1 else NULL
  switch(backend,
    laridae = list(build = function() laridae::lari_new(case$x, case$y, s0, s1),
                   run = function(m) laridae::lari_add_points(m, p$x, p$y)),
    trowel = list(build = function() trowel::mesh_new(case$x, case$y, s0, s1),
                  run = function(m) trowel::mesh_add_points(m, p$x, p$y)),
    cdtr = list(build = function() NULL,
                run = function(m) cdtr::cdt_triangulate(c(case$x, p$x), c(case$y, p$y), s0, s1,
                                                        erase = if (is.null(s0)) "hull" else "outer")),
    RTriangle = list(build = function() NULL,
                     run = function(m) {
                       P <- cbind(c(case$x, p$x), c(case$y, p$y))
                       pp <- if (is.null(s0)) RTriangle::pslg(P = P) else RTriangle::pslg(P = P, S = cbind(s0, s1))
                       RTriangle::triangulate(pp)
                     }))
}

#' one job: returns a one-row data frame
bench_job <- function(file, backend, scenario, reps = NULL, check_max = 5e4) {
  case <- read_pslg_bin(file)
  s <- bench_scenarios(case)[[scenario]]
  n_in <- length(case$x)
  if (is.null(reps)) reps <- if (n_in > 2e5) 3L else if (n_in > 2e4) 5L else 10L
  row <- data.frame(dataset = case$name, backend = backend, scenario = scenario,
                    n_in = n_in, s_in = length(case$s0), reps = reps,
                    status = "ok", message = NA_character_, stringsAsFactors = FALSE)
  if (!requireNamespace(backend, quietly = TRUE)) {
    row$status <- "skipped"; row$message <- "not installed"; return(row)
  }
  times <- double(reps); out <- NULL
  res <- tryCatch({
    if (!is.null(s$insert)) {
      j <- insert_job(backend, case, insert_points(case, s$insert))
      for (i in seq_len(reps)) {
        m <- j$build(); gc(FALSE)
        t0 <- proc.time()[["elapsed"]]; j$run(m); times[i] <- proc.time()[["elapsed"]] - t0
      }
    } else {
      f <- trianglewins::tw_backends()[[backend]]
      for (i in seq_len(reps)) {
        gc(FALSE)
        t0 <- proc.time()[["elapsed"]]
        out <- suppressWarnings(f(case, s$max_area, s$min_angle))
        times[i] <- proc.time()[["elapsed"]] - t0
      }
    }
    TRUE
  }, error = function(e) e)
  if (inherits(res, "error")) {
    row$status <- "error"; row$message <- conditionMessage(res); return(row)
  }
  row$time_s <- stats::median(times)
  row$time_min_s <- min(times)
  row$peak_mb <- peak_rss_mb()
  if (!is.null(out)) {
    V <- out$vertices; T <- out$triangles
    ar <- abs(trianglewins:::tri_area(V$x, V$y, T$v0, T$v1, T$v2))
    ma <- trianglewins:::tri_min_angle(V$x, V$y, T$v0, T$v1, T$v2)
    row$n_vertices <- nrow(V); row$n_triangles <- nrow(T)
    row$area_ok <- if (is.null(s$max_area)) NA_real_ else mean(ar <= s$max_area * (1 + 1e-9))
    row$angle_ok <- if (is.null(s$min_angle)) NA_real_ else mean(ma >= s$min_angle - 1e-6)
    row$angle_min <- min(ma)
    row$unrefined <- out$unrefined
    if (n_in <= check_max) {
      m <- trianglewins::tw_measure(case, out, s$max_area, s$min_angle)
      row$segs_kept <- m$segs_kept; row$cd_violations <- m$cd_violations
      row$flat <- m$flat; row$depth_match <- m$depth_match
    }
  }
  row
}
