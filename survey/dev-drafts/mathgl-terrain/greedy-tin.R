## Greedy constrained TIN on a height grid, with cdtr.
##
## Grid sample (row i, col j) sits at x = j - 1, y = i - 1 (row 0 at the top),
## the same sample-lattice coordinates Delatin uses. Each round triangulates
## the current vertices plus constraint segments, measures the vertical error
## at every grid sample covered by a triangle, and inserts the worst sample of
## each triangle whose error exceeds `tol` (Garland-Heckbert, batched by round).

library(cdtr)
library(terra)

## triangle id for every grid cell centre, via terra polygon rasterization
cell_triangles <- function(P, T, W, H) {
  n <- nrow(T)
  id <- rep(seq_len(n), each = 4L)
  idx <- as.vector(t(cbind(T, T[, 1])))
  ## inflate a hair about the grid centre so sample centres lying exactly on the
  ## outer boundary fall inside (barycentrics below use the true coordinates)
  f <- 1 + 1e-7
  geom <- cbind(id, part = 1, x = (P[idx, 1] - (W - 1) / 2) * f + (W - 1) / 2,
                y = (P[idx, 2] - (H - 1) / 2) * f + (H - 1) / 2)
  v <- vect(geom, type = "polygons")
  v$tid <- seq_len(n)
  tmpl <- rast(ncols = W, nrows = H, xmin = -0.5, xmax = W - 0.5,
               ymin = -0.5, ymax = H - 0.5)
  r <- values(rasterize(v, tmpl, field = "tid", touches = FALSE))[, 1]
  ## terra's first row is the top (largest y = H - 1); ours is y = 0
  vals <- matrix(r, H, W, byrow = TRUE)[H:1, , drop = FALSE]
  as.vector(t(vals))
}

## interpolate mesh height at grid samples; returns zhat (NA where uncovered)
mesh_at_cells <- function(P, Z, T, W, H) {
  tid <- cell_triangles(P, T, W, H)
  k <- which(!is.na(tid))
  t <- tid[k]
  ## cell centres
  cx <- (k - 1L) %% W
  cy <- (k - 1L) %/% W
  a <- T[t, 1]; b <- T[t, 2]; c <- T[t, 3]
  x1 <- P[a, 1]; y1 <- P[a, 2]; x2 <- P[b, 1]; y2 <- P[b, 2]; x3 <- P[c, 1]; y3 <- P[c, 2]
  det <- (y2 - y3) * (x1 - x3) + (x3 - x2) * (y1 - y3)
  l1 <- ((y2 - y3) * (cx - x3) + (x3 - x2) * (cy - y3)) / det
  l2 <- ((y3 - y1) * (cx - x3) + (x1 - x3) * (cy - y3)) / det
  l3 <- 1 - l1 - l2
  zhat <- rep(NA_real_, W * H)
  zhat[k] <- l1 * Z[a] + l2 * Z[b] + l3 * Z[c]
  list(zhat = zhat, tid = tid)
}

## z: H x W matrix (row 1 at top). mask: logical H x W (FALSE = not measured).
## cx, cy, cz: constraint vertices; s0, s1: 1-based segments into them.
## Initial vertices: the grid corners (unless constraints bound the domain).
greedy_tin <- function(z, tol, cx = numeric(0), cy = numeric(0), cz = numeric(0),
                       s0 = integer(0), s1 = integer(0), mask = NULL,
                       erase = if (length(s0)) "outer" else "hull",
                       corners = TRUE, max_rounds = 500L, frac = 0.5, verbose = FALSE) {
  H <- nrow(z); W <- ncol(z)
  zv <- as.vector(t(z))                      # row-major, cell k = row*W + col + 1
  mv <- if (is.null(mask)) rep(TRUE, W * H) else as.vector(t(mask))
  mv <- mv & !is.na(zv)
  vx <- cx; vy <- cy; vz <- cz
  if (corners) {
    ck <- c(1, W, (H - 1) * W + 1, H * W)
    vx <- c(vx, (ck - 1) %% W); vy <- c(vy, (ck - 1) %/% W); vz <- c(vz, zv[ck])
  }
  t0 <- proc.time()[["elapsed"]]
  for (round in seq_len(max_rounds)) {
    tri <- cdt_triangulate(vx, vy, s0, s1, erase = erase, intersect = "error")
    stopifnot(tri$n_crossing == 0L, nrow(tri$P) == tri$n_input)
    Z <- numeric(nrow(tri$P)); Z[tri$input_map] <- vz
    m <- mesh_at_cells(tri$P, Z, tri$T, W, H)
    err <- abs(zv - m$zhat)
    err[!mv | is.na(err)] <- 0
    o <- order(m$tid, -err, na.last = NA)
    best <- o[!duplicated(m$tid[o])]
    best <- best[err[best] > tol]
    ## priority by rounds: only the candidates within `frac` of this round's
    ## worst, which approximates Delatin's one-at-a-time queue
    if (length(best)) best <- best[err[best] >= max(tol, frac * max(err[best]))]
    if (verbose) message(sprintf("round %d: %d triangles, max err %.3f, adding %d",
                                 round, nrow(tri$T), max(err), length(best)))
    if (!length(best)) break
    vx <- c(vx, (best - 1) %% W); vy <- c(vy, (best - 1) %/% W); vz <- c(vz, zv[best])
  }
  is_sample <- logical(nrow(tri$P)); is_sample[tri$input_map] <- seq_along(vx) > length(cx)
  list(P = cbind(tri$P, Z), T = tri$T, is_sample = is_sample, rounds = round, max_err = max(err),
       seconds = proc.time()[["elapsed"]] - t0, tri = tri)
}

## measure any mesh (P with x, y, z columns; T 1-based) against a grid
mesh_error <- function(P, T, z, mask = NULL) {
  H <- nrow(z); W <- ncol(z)
  zv <- as.vector(t(z))
  mv <- if (is.null(mask)) rep(TRUE, W * H) else as.vector(t(mask))
  m <- mesh_at_cells(P[, 1:2], P[, 3], T, W, H)
  e <- abs(zv - m$zhat)[mv]
  c(max = max(e, na.rm = TRUE), rmse = sqrt(mean(e^2, na.rm = TRUE)),
    uncovered = sum(is.na(e)))
}

## run Delatin (node) on the same grid; returns P (x, y, z) and 1-based T
run_delatin <- function(z, tol, script = "survey/dev-drafts/mathgl-terrain/delatin-run.mjs") {
  H <- nrow(z); W <- ncol(z)
  f <- tempfile(fileext = ".f64"); o <- tempfile(fileext = ".json")
  writeBin(as.double(t(z)), f, size = 8)
  info <- system2("node", c(script, f, W, H, tol, o), stdout = TRUE)
  d <- jsonlite::fromJSON(o)
  xy <- matrix(d$coords, ncol = 2, byrow = TRUE)
  T <- matrix(d$triangles, ncol = 3, byrow = TRUE) + 1L
  zz <- z[cbind(xy[, 2] + 1, xy[, 1] + 1)]
  list(P = cbind(xy, zz), T = T, is_sample = rep(TRUE, nrow(xy)), seconds = d$ms / 1000, max_err_reported = d$maxError)
}

## error against a known continuous surface f(x, y), on a lattice `k` times
## finer than the samples (the roadmap's point: sample error is not surface error)
surface_error <- function(P, T, f, W, H, k = 4L, keep = NULL) {
  W4 <- (W - 1L) * k + 1L; H4 <- (H - 1L) * k + 1L
  m <- mesh_at_cells(P[, 1:2] * k, P[, 3], T, W4, H4)
  x <- (seq_len(W4 * H4) - 1L) %% W4 / k; y <- (seq_len(W4 * H4) - 1L) %/% W4 / k
  e <- abs(f(x, y) - m$zhat)
  if (!is.null(keep)) e <- e[keep]
  c(cont_max = max(e, na.rm = TRUE), cont_rmse = sqrt(mean(e^2, na.rm = TRUE)))
}

## mesh height at arbitrary points (NA outside the mesh)
mesh_z_points <- function(P, T, xy) {
  n <- nrow(T)
  idx <- as.vector(t(cbind(T, T[, 1])))
  v <- vect(cbind(id = rep(seq_len(n), each = 4L), part = 1, x = P[idx, 1], y = P[idx, 2]),
            type = "polygons")
  hit <- terra::extract(v, vect(xy, type = "points"))
  hit <- hit[!duplicated(hit[, 1]), ]
  t <- hit[, 2]
  out <- rep(NA_real_, nrow(xy))
  ok <- !is.na(t)
  a <- T[t[ok], 1]; b <- T[t[ok], 2]; c <- T[t[ok], 3]
  px <- xy[ok, 1]; py <- xy[ok, 2]
  x1 <- P[a, 1]; y1 <- P[a, 2]; x2 <- P[b, 1]; y2 <- P[b, 2]; x3 <- P[c, 1]; y3 <- P[c, 2]
  det <- (y2 - y3) * (x1 - x3) + (x3 - x2) * (y1 - y3)
  l1 <- ((y2 - y3) * (px - x3) + (x3 - x2) * (py - y3)) / det
  l2 <- ((y3 - y1) * (px - x3) + (x1 - x3) * (py - y3)) / det
  out[ok] <- l1 * P[a, 3] + l2 * P[b, 3] + (1 - l1 - l2) * P[c, 3]
  out
}
