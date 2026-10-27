## Test cases: planar straight line graphs as plain vectors.
##
## A case is a list with
##   name    identifier
##   x, y    vertex coordinates (duplicates allowed, on purpose for some cases)
##   s0, s1  1-based segment end indices into x/y (may be empty)
##   region  "outer" (keep what is inside the constraints, Triangle's -p) or
##           "hull" (keep the convex hull: open linework, points only)
##   area_div   max_area for the refinement scenarios is bbox area / area_div
##   expect  optional named list of expected results (e.g. depth table)
##   note    one line on what the case is for
##   ij      optional two-column grid index (i, j) of each vertex, for cases
##           built from a grid (see tw_in_cell())

new_case <- function(name, x, y, s0 = integer(0), s1 = integer(0),
                     region = c("outer", "hull"), area_div = 200,
                     expect = list(), note = "", ij = NULL) {
  stopifnot(length(x) == length(y), length(s0) == length(s1),
            is.null(ij) || nrow(ij) == length(x))
  list(name = name, x = as.double(x), y = as.double(y),
       s0 = as.integer(s0), s1 = as.integer(s1),
       region = match.arg(region), area_div = area_div,
       expect = expect, note = note, ij = ij)
}

## closed rings -> one case's x, y, s0, s1 (each ring is a two-column matrix,
## not repeating its first vertex); vertices are not shared between rings
rings_pslg <- function(rings) {
  n <- vapply(rings, nrow, 1L)
  off <- cumsum(c(0L, n[-length(n)]))
  xy <- do.call(rbind, rings)
  s0 <- unlist(lapply(seq_along(n), function(k) off[k] + seq_len(n[k])))
  s1 <- unlist(lapply(seq_along(n), function(k) off[k] + c(seq_len(n[k])[-1L], 1L)))
  list(x = xy[, 1], y = xy[, 2], s0 = s0, s1 = s1)
}

## deduplicate vertices by exact coordinate and drop repeated / degenerate
## segments (direction ignored): the clean PSLG that silicate::SC0 gives
dedupe_pslg <- function(x, y, s0, s1) {
  key <- paste(x, y)
  u <- !duplicated(key)
  map <- match(key, key[u])
  a <- map[s0]; b <- map[s1]
  s <- cbind(pmin(a, b), pmax(a, b))
  keep <- !duplicated(s) & s[, 1] != s[, 2]
  list(x = x[u], y = y[u], s0 = s[keep, 1], s1 = s[keep, 2])
}

## the edges of an ni x nj grid of nodes, node (i, j) (from 0) being row
## i + ni * j + 1: every (i, j)-(i + 1, j) and (i, j)-(i, j + 1)
quad_edges <- function(ni, nj) {
  id <- function(i, j) as.integer(i + ni * j + 1L)
  h <- expand.grid(i = seq_len(ni - 1L) - 1L, j = seq_len(nj) - 1L)
  v <- expand.grid(i = seq_len(ni) - 1L, j = seq_len(nj - 1L) - 1L)
  list(s0 = c(id(h$i, h$j), id(v$i, v$j)), s1 = c(id(h$i + 1L, h$j), id(v$i, v$j + 1L)))
}

## longitude and latitude of south polar stereographic x, y on an ellipsoid:
## Snyder (1987) eq. 21-39 and 7-9 for the north pole, by symmetry. The
## defaults are EPSG:3412 (NSIDC, Hughes 1980 ellipsoid, true scale at 70 S),
## which this matches PROJ to 1e-8 degrees over the grid.
ps_south_inverse <- function(x, y, a = 6378273, rf = 298.279411123064, lat_ts = -70) {
  f <- 1 / rf; e2 <- f * (2 - f); e <- sqrt(e2)
  x <- -x; y <- -y; pc <- -lat_ts * pi / 180
  tc <- tan(pi / 4 - pc / 2) / ((1 - e * sin(pc)) / (1 + e * sin(pc)))^(e / 2)
  mc <- cos(pc) / sqrt(1 - e2 * sin(pc)^2)
  chi <- pi / 2 - 2 * atan(sqrt(x^2 + y^2) * tc / (a * mc))
  phi <- chi + (e2 / 2 + 5 * e2^2 / 24 + e2^3 / 12) * sin(2 * chi) +
    (7 * e2^2 / 48 + 29 * e2^3 / 240) * sin(4 * chi) + (7 * e2^3 / 120) * sin(6 * chi)
  cbind(lon = -atan2(x, -y) * 180 / pi, lat = -phi * 180 / pi)
}

## an n x n block of NSIDC 25 km cell centres starting at (x0, y0) in
## EPSG:3412, with each one's longitude and latitude and grid index. The
## default block is the 60 S block of survey/grids.md.
nsidc_block <- function(x0 = -112500, y0 = 3300000, n = 10L, step = 25000) {
  ij <- expand.grid(i = seq_len(n) - 1L, j = seq_len(n) - 1L)
  x <- x0 + ij$i * step; y <- y0 + ij$j * step
  ll <- ps_south_inverse(x, y)
  list(x = x, y = y, lon = unname(ll[, "lon"]), lat = unname(ll[, "lat"]),
       ij = cbind(i = ij$i, j = ij$j), edges = quad_edges(n, n))
}

square <- function(x0, y0, w, h = w) cbind(x0 + c(0, w, w, 0), y0 + c(0, 0, h, h))

#' Test cases
#'
#' `tw_cases()` returns every case, `tw_case()` one by name. Synthetic cases
#' are built in code; the real-data cases (`nc`, `cont_tas`, `cad_tas`) are
#' read from `inst/extdata` (see `inst/scripts/make-extdata.R` for how they
#' were made from sf's nc.shp and anglr's data).
#'
#' @param names case names, or NULL for all
#' @param name one case name
#' @return a list of cases (see the comment at the top of R/cases.R)
#' @export
tw_cases <- function(names = NULL) {
  all <- c(synthetic_case_names(), extdata_case_names())
  if (is.null(names)) names <- all
  bad <- setdiff(names, all)
  if (length(bad)) stop("unknown case: ", paste(bad, collapse = ", "))
  stats::setNames(lapply(names, tw_case), names)
}

#' @rdname tw_cases
#' @export
tw_case <- function(name) {
  if (name %in% extdata_case_names()) return(extdata_case(name))
  f <- synthetic_cases[[name]]
  if (is.null(f)) stop("unknown case: ", name)
  f()
}

synthetic_case_names <- function() names(synthetic_cases)

synthetic_cases <- list(
  square = function() {
    p <- rings_pslg(list(square(0, 0, 1)))
    new_case("square", p$x, p$y, p$s0, p$s1,
             note = "unit square, sanity check")
  },
  square_hole = function() {
    p <- rings_pslg(list(square(0, 0, 1), square(0.25, 0.25, 0.5)))
    new_case("square_hole", p$x, p$y, p$s0, p$s1,
             note = "square with a square hole: depth 1 outside the hole, 2 inside")
  },
  nested3 = function() {
    p <- rings_pslg(list(square(0, 0, 1), square(0.2, 0.2, 0.6), square(0.4, 0.4, 0.2)))
    new_case("nested3", p$x, p$y, p$s0, p$s1,
             note = "rings nested three deep: depth 1, 2, 3 (parity: in, hole, in)")
  },
  grid3_doubled = function() {
    sq <- unlist(lapply(0:2, function(i) lapply(0:2, function(j) square(i, j, 1))), recursive = FALSE)
    p <- rings_pslg(sq)
    new_case("grid3_doubled", p$x, p$y, p$s0, p$s1,
             note = paste("3 x 3 coverage, every cell its own ring: shared vertices",
                          "repeated and shared edges given twice"))
  },
  grid3_dedup = function() {
    sq <- unlist(lapply(0:2, function(i) lapply(0:2, function(j) square(i, j, 1))), recursive = FALSE)
    p <- rings_pslg(sq)
    p <- dedupe_pslg(p$x, p$y, p$s0, p$s1)
    new_case("grid3_dedup", p$x, p$y, p$s0, p$s1,
             note = "the same 3 x 3 coverage with shared vertices and edges given once")
  },
  crossing_rings = function() {
    p <- rings_pslg(list(square(0, 0, 1), square(0.5, 0.5, 1)))
    new_case("crossing_rings", p$x, p$y, p$s0, p$s1,
             note = "two overlapping squares whose rings cross at two points")
  },
  crossing_x = function() {
    new_case("crossing_x", c(0, 1, 0, 1), c(0, 1, 1, 0), c(1L, 3L), c(2L, 4L),
             region = "hull", note = "two crossing segments, no enclosed region")
  },
  collinear_overlap = function() {
    new_case("collinear_overlap", c(0, 2, 1, 3, 0, 3), c(0, 0, 0, 0, 1, 1),
             c(1L, 3L, 5L), c(2L, 4L, 6L), region = "hull",
             note = "collinear overlapping segments (the case that crashed polymer)")
  },
  dangling = function() {
    p <- rings_pslg(list(square(0, 0, 1)))
    new_case("dangling", c(p$x, 0.2, 0.8, 0.5), c(p$y, 0.5, 0.5, 0.9),
             c(p$s0, 5L, 6L), c(p$s1, 6L, 7L),
             note = "square with an open polyline inside it (internal constraints)")
  },
  sharp_corner = function() {
    ## a star whose spikes have 5 degree tips, and a 1 degree sliver
    k <- 7
    a <- seq(0, 2 * pi, length.out = 2 * k + 1)[-(2 * k + 1)]
    r <- rep(c(1, 0.35), k)
    star <- cbind(r * cos(a), r * sin(a))
    th <- 1 * pi / 180
    sliver <- cbind(c(1.5, 3.5, 3.5), c(0, 0, 2 * tan(th)))
    p <- rings_pslg(list(star, sliver))
    new_case("sharp_corner", p$x, p$y, p$s0, p$s1,
             note = "star with sharp spikes and a 1 degree sliver: refinement cascades")
  },
  grid_quads = function() {
    b <- nsidc_block()
    new_case("grid_quads", b$lon, b$lat, b$edges$s0, b$edges$s1, ij = b$ij,
             expect = list(n_triangles = 162L, in_cell = 1),
             note = paste("10 x 10 NSIDC 3412 cell centres near 60 S in longitude and",
                          "latitude, the index's quad edges as constraints"))
  },
  grid_frames_lonlat = function() {
    b <- nsidc_block()
    new_case("grid_frames_lonlat", b$lon, b$lat, region = "hull", ij = b$ij,
             expect = list(n_triangles = 186L, in_cell = 162 / 186),
             note = "the same grid's points only, in longitude and latitude")
  },
  grid_frames_3412 = function() {
    b <- nsidc_block()
    new_case("grid_frames_3412", b$x, b$y, region = "hull", ij = b$ij,
             expect = list(n_triangles = 162L, in_cell = 1),
             note = "the same grid's points only, in EPSG:3412 where it is regular")
  },
  grid_diagonal = function() {
    ij <- as.matrix(expand.grid(i = 0:3, j = 0:3))
    e <- quad_edges(4L, 4L)
    new_case("grid_diagonal", ij[, 1], ij[, 2], e$s0, e$s1, ij = ij,
             expect = list(n_triangles = 18L, in_cell = 1),
             note = paste("3 x 3 unit cells with their edges as constraints: both",
                          "diagonals of every cell are Delaunay, so diag_ne is a tie-break"))
  },
  points_only = function() {
    ## a fixed low-discrepancy pattern, no RNG dependence
    n <- 500
    i <- seq_len(n)
    x <- (i * 0.6180339887498949) %% 1
    y <- (i * 0.7548776662466927) %% 1
    new_case("points_only", x, y, region = "hull", note = "500 points, no segments")
  }
)

extdata_case_names <- function() c("nc", "nc_rings", "cont_tas", "cad_tas")

extdata_case <- function(name) {
  vf <- system.file("extdata", paste0(name, "_vertices.csv"), package = "trianglewins")
  sf <- system.file("extdata", paste0(name, "_segments.csv"), package = "trianglewins")
  if (!nzchar(vf) || !nzchar(sf)) stop("extdata for case ", name, " not found")
  v <- utils::read.csv(vf)
  s <- utils::read.csv(sf)
  note <- switch(name,
                 nc = "North Carolina counties (sf's nc.shp), shared boundaries given once",
                 nc_rings = "the same counties as rings in full: shared vertices and boundaries twice",
                 cont_tas = "Tasmanian contour lines (anglr::cont_tas), meshed over their convex hull",
                 cad_tas = "Tasmanian cadastre parcels (anglr::cad_tas)")
  ## contours are open lines: the mesh wanted is the hull with them inside
  region <- if (name == "cont_tas") "hull" else "outer"
  new_case(name, v$x, v$y, s$s0, s$s1, region = region, area_div = 5000, note = note)
}
