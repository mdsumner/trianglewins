## The live-mesh question: what does a small edit cost once a mesh is
## refined? A handle backend (laridae, trowel) adds a short constraint to its
## refined mesh and refines again; a one-shot backend (cdtr, RTriangle) has
## to rebuild from the input with the new constraint added. Both end with
## the same constraints and the same targets, so the measures compare.

## a short segment from the bounding box centre (on nc: 0.05 by 0.02 degrees,
## the edit laridae's dynamic benchmark uses)
edit_segment <- function(case, frac = c(0.0056, 0.0075)) {
  cx <- mean(range(case$x)); cy <- mean(range(case$y))
  w <- diff(range(case$x)) * frac[1]; h <- diff(range(case$y)) * frac[2]
  list(x = cx + c(0, w), y = cy + c(0, h))
}

## the case with the edit's two points and one segment appended
with_edit <- function(case, e) {
  n <- length(case$x)
  case$x <- c(case$x, e$x); case$y <- c(case$y, e$y)
  case$s0 <- c(case$s0, n + 1L); case$s1 <- c(case$s1, n + 2L)
  case
}

dynamic_fns <- function(case, e, max_area, min_angle) {
  edited <- with_edit(case, e)
  list(
    laridae = list(
      build = function() {
        m <- laridae::lari_new(case$x, case$y, case$s0, case$s1)
        laridae::lari_refine(m, max_area = max_area, min_angle = min_angle,
                             max_steiner = tw_budget())
        m
      },
      edit = function(m) {
        ids <- laridae::lari_add_points(m, e$x, e$y)
        laridae::lari_add_segments(m, ids[1], ids[2])
        laridae::lari_refine(m, max_area = max_area, min_angle = min_angle,
                             max_steiner = tw_budget())
        tb <- laridae::lari_tables(m)
        list(vertices = tb$vertices[c("x", "y")], triangles = tb$triangles)
      }),
    trowel = list(
      build = function() {
        m <- trowel::mesh_new(case$x, case$y, case$s0, case$s1)
        trowel::mesh_refine(m, min_angle = min_angle, max_area = max_area,
                            max_steiner = tw_budget())
        m
      },
      edit = function(m) {
        ids <- trowel::mesh_add_points(m, e$x, e$y)
        trowel::mesh_add_segments(m, ids[1], ids[2])
        trowel::mesh_refine(m, min_angle = min_angle, max_area = max_area,
                            max_steiner = tw_budget())
        V <- trowel::mesh_vertices(m); Tr <- trowel::mesh_triangles(m)
        Tr <- Tr[Tr$depth > 0, , drop = FALSE]
        list(vertices = V[c("x", "y")],
             triangles = data.frame(v0 = match(Tr$v0, V$id), v1 = match(Tr$v1, V$id),
                                    v2 = match(Tr$v2, V$id), depth = Tr$depth))
      }),
    cdtr = list(build = function() NULL,
                edit = function(m) run_cdtr(edited, max_area, min_angle)),
    RTriangle = list(build = function() NULL,
                     edit = function(m) run_rtriangle(edited, max_area, min_angle))
  )
}

#' Edit-then-refine against rebuild
#'
#' Refine a case (area bound bbox area / `area_div`, angle 20), add one short
#' constraint near the middle, and get the refined mesh again: by editing
#' the live handle (laridae, trowel) or by rebuilding (cdtr, RTriangle). The
#' build before the edit is not timed; everything after it is, including
#' reading the tables back.
#' @param case a case name
#' @param backends backend names
#' @param reps timed repeats (each on a freshly built mesh)
#' @param min_angle angle bound for both refinements
#' @return a data frame, one row per backend, with the [tw_measure()]
#'   columns for the edited mesh, measured against the edited input
#' @export
tw_run_dynamic <- function(case = "nc", backends = names(tw_backends()), reps = 5L,
                           min_angle = 20) {
  cs <- tw_case(case)
  A <- diff(range(cs$x)) * diff(range(cs$y)) / cs$area_div
  e <- edit_segment(cs)
  fns <- dynamic_fns(cs, e, A, min_angle)
  avail <- tw_available()
  rows <- lapply(backends, function(b) {
    row <- data.frame(backend = b, case = cs$name, scenario = "edit_refine",
                      max_area = A, min_angle = min_angle,
                      status = "ok", message = NA_character_, stringsAsFactors = FALSE)
    if (!isTRUE(avail[[b]])) {
      row$status <- "skipped"; row$message <- "package not installed"
      return(row)
    }
    f <- fns[[b]]
    res <- tryCatch({
      times <- double(reps)
      for (i in seq_len(reps)) {
        m <- f$build()
        t0 <- proc.time()[["elapsed"]]
        out <- f$edit(m)
        times[i] <- proc.time()[["elapsed"]] - t0
      }
      list(out = out, time = stats::median(times))
    }, error = function(e) e)
    if (inherits(res, "error")) {
      row$status <- "error"; row$message <- conditionMessage(res)
      return(row)
    }
    m <- tw_measure(with_edit(cs, e), res$out, A, min_angle)
    m$unrefined <- NA_character_
    m$time_ms <- 1000 * res$time
    m$attr_err <- NA_real_
    cbind(row, m)
  })
  bind_rows(rows)
}
