## Backend adapters. Each takes a case and the targets and returns the
## common output shape that tw_measure() reads:
##   vertices   data frame x, y (and z when attributes were given)
##   triangles  data frame v0, v1, v2 (1-based rows of vertices), depth (NA
##              when the backend has none)
##   unrefined  one string summarising what the backend reports it could
##              not do (NA when it reports nothing)
## The region kept follows case$region: "outer" keeps triangles inside the
## constraints, "hull" the whole convex hull.

#' Backends
#'
#' `tw_backends()` lists the adapters; `tw_available()` says which of the
#' packages are installed.
#' @return a named list of adapter functions, or a named logical vector
#' @export
tw_backends <- function() {
  list(laridae = run_laridae, cdtr = run_cdtr, trowel = run_trowel, RTriangle = run_rtriangle)
}

#' @rdname tw_backends
#' @export
tw_available <- function() {
  vapply(names(tw_backends()), requireNamespace, TRUE, quietly = TRUE)
}

## the Steiner budget given to every backend, so that a cascading refinement
## stops at the same place everywhere
tw_budget <- function() getOption("trianglewins.max_steiner", 1e5)

nonzero_summary <- function(df) {
  if (is.null(df) || !length(df)) return(NA_character_)
  v <- unlist(lapply(df, function(col) if (is.numeric(col) || is.logical(col)) sum(col) else NULL))
  v <- v[!is.na(v) & v != 0]
  if (!length(v)) return("none")
  paste(paste0(names(v), "=", signif(v, 4)), collapse = " ")
}

xyz <- function(V, attr) {
  out <- data.frame(x = V$x, y = V$y)
  if (attr) out$z <- V$z
  out
}

seg_or_null <- function(s) if (length(s)) s else NULL

run_laridae <- function(case, max_area = NULL, min_angle = NULL, attr = FALSE) {
  PA <- if (attr) cbind(z = case$x + 2 * case$y) else NULL
  erase <- if (case$region == "hull") "hull" else "outer"
  r <- laridae::lari_triangulate(case$x, case$y, seg_or_null(case$s0), seg_or_null(case$s1),
                                 PA = PA, max_area = max_area, min_angle = min_angle,
                                 erase = erase, max_steiner = tw_budget())
  V <- r$vertices
  list(vertices = xyz(V, attr),
       triangles = data.frame(v0 = r$triangles$v0, v1 = r$triangles$v1,
                              v2 = r$triangles$v2, depth = r$triangles$depth),
       unrefined = if (is.null(r$unrefined)) NA_character_
                   else nonzero_summary(r$unrefined[setdiff(names(r$unrefined),
                                                      c("min_edge_length", "inserted"))]))
}

run_cdtr <- function(case, max_area = NULL, min_angle = NULL, attr = FALSE) {
  erase <- if (case$region == "hull") "hull" else "outer"
  args <- list(case$x, case$y, seg_or_null(case$s0), seg_or_null(case$s1),
               max_area = max_area, min_angle = min_angle,
               max_steiner = tw_budget(), erase = erase)
  if (attr) {
    r <- do.call(cdtr::cdt_triangulate_attr, c(args, list(PA = cbind(z = case$x + 2 * case$y))))
  } else {
    r <- do.call(cdtr::cdt_triangulate, args)
  }
  V <- data.frame(x = r$P[, 1], y = r$P[, 2])
  if (attr) V$z <- as.matrix(r$PA)[, 1]
  refining <- !is.null(max_area) || !is.null(min_angle)
  list(vertices = V,
       triangles = data.frame(v0 = r$T[, 1], v1 = r$T[, 2], v2 = r$T[, 3], depth = r$depth),
       unrefined = if (refining) nonzero_summary(r$unrefined) else NA_character_)
}

run_trowel <- function(case, max_area = NULL, min_angle = NULL, attr = FALSE) {
  PA <- if (attr) cbind(z = case$x + 2 * case$y) else NULL
  m <- trowel::mesh_new(case$x, case$y, seg_or_null(case$s0), seg_or_null(case$s1), PA = PA)
  unref <- NA_character_
  if (!is.null(max_area) || !is.null(min_angle)) {
    res <- trowel::mesh_refine(m, min_angle = min_angle, max_area = max_area,
                               max_steiner = tw_budget(),
                               inner_only = case$region == "outer" && length(case$s0) > 0L)
    unref <- if (isTRUE(res$complete)) "none" else "incomplete=1"
  }
  V <- trowel::mesh_vertices(m)
  Tr <- trowel::mesh_triangles(m)
  if (case$region == "outer" && length(case$s0)) Tr <- Tr[Tr$depth > 0, , drop = FALSE]
  list(vertices = xyz(V, attr),
       triangles = data.frame(v0 = match(Tr$v0, V$id), v1 = match(Tr$v1, V$id),
                              v2 = match(Tr$v2, V$id), depth = Tr$depth),
       unrefined = unref)
}

run_rtriangle <- function(case, max_area = NULL, min_angle = NULL, attr = FALSE) {
  P <- cbind(case$x, case$y)
  S <- if (length(case$s0)) cbind(case$s0, case$s1) else NULL
  ## RTriangle has no -c (enclose the convex hull): with segments Triangle
  ## always eats the outside, so for a hull case the hull is added as
  ## segments, which is what -c does
  if (!is.null(S) && case$region == "hull") {
    h <- grDevices::chull(P)
    S <- rbind(S, cbind(h, c(h[-1L], h[1L])))
  }
  PA <- if (attr) cbind(case$x + 2 * case$y) else NULL
  p <- do.call(RTriangle::pslg, c(list(P = P), if (!is.null(S)) list(S = S), if (attr) list(PA = PA)))
  args <- list(p, S = tw_budget())
  if (!is.null(max_area)) args$a <- max_area
  if (!is.null(min_angle)) args$q <- min_angle
  r <- do.call(RTriangle::triangulate, args)
  V <- data.frame(x = r$P[, 1], y = r$P[, 2])
  if (attr) V$z <- r$PA[, 1]
  list(vertices = V,
       triangles = data.frame(v0 = r$T[, 1], v1 = r$T[, 2], v2 = r$T[, 3], depth = rep(NA_integer_, nrow(r$T))),
       unrefined = NA_character_)
}
