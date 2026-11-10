## Study 2: the breaklines comparison on math.gl's own fixtures.
##
## pacific-streaming: 257 x 257 cell-registered samples from AWS terrain tile
##   8/40/98 (Northern California coast, about 609 m cells in Web Mercator),
##   with bathymetry. As for Hobart: the coastline (height > 0, simplified
##   within one cell) is a 0 m breakline and the mesh boundary.
## sierra-nodata-streaming: 257 x 257 from tile 8/43/98 with a manufactured
##   65 x 65 nodata block and single nodata samples every 16th row, 8th column.
##   math.gl's Delatin and MARTINI adapters refuse it; its regular mesh drops
##   every cell with a missing corner. We give the adaptive mesher exactly that
##   domain: the outline of the cells with four valid corners, whose vertices
##   are valid samples, so no height is invented.
source("survey/dev-drafts/mathgl-terrain/greedy-tin.R")
library(jsonlite)
here <- "survey/dev-drafts/mathgl-terrain"

read_fixture <- function(f) {
  d <- fromJSON(file.path(here, "cache", f), simplifyVector = TRUE)
  h <- d$heights; h[is.null(h)] <- NA
  z <- matrix(as.numeric(h), d$height, d$width, byrow = TRUE)   # row 1 at the top
  list(z = z, cell = abs(d$columnStep[1]), meta = d[c("source", "crs", "registration", "mask")])
}

## polygons (rings) -> vertices, segments; drop each ring's closing repeat
rings_to_pslg <- function(g) {
  ring <- paste(g[, "geom"], g[, "part"], g[, "hole"])
  keep <- !duplicated(cbind(ring, g[, "x"], g[, "y"]))
  g <- g[keep, ]; ring <- ring[keep]
  idx <- seq_len(nrow(g))
  list(x = g[, "x"], y = g[, "y"], s0 = idx, s1 = ave(idx, ring, FUN = function(i) c(i[-1], i[1])))
}
tri_class <- function(P, T, is_sample) {
  zt <- matrix(P[T, 3], ncol = 3)
  sea_v <- matrix(is_sample[T] & P[T, 3] <= 0, ncol = 3)
  c(straddle = sum(rowSums(sea_v) > 0 & apply(zt, 1, max) > 0))
}

res <- list(); keep_meshes <- list()

## ---- pacific: coastline as breakline and boundary -------------------------
fx <- read_fixture("pacific-streaming.json"); z <- fx$z; H <- nrow(z); W <- ncol(z)
land <- rast(ncols = W, nrows = H, xmin = -0.5, xmax = W - 0.5, ymin = -0.5, ymax = H - 0.5)
values(land) <- as.vector(t(z[H:1, ] > 0))
land <- classify(land, cbind(0, NA))
pol <- disagg(as.polygons(land, dissolve = TRUE))
pol <- pol[expanse(pol, transform = FALSE) > 25]
pol <- fillHoles(pol)
pol <- simplifyGeom(pol, tolerance = 1, preserveTopology = TRUE)
pol <- makeValid(crop(pol, ext(0, W - 1, 0, H - 1)))
pol <- pol[expanse(pol, transform = FALSE) > 25]
ps <- rings_to_pslg(geom(pol))
bilin <- function(x, y) {
  x0 <- pmin(floor(x), W - 2); y0 <- pmin(floor(y), H - 2); fx <- x - x0; fy <- y - y0
  z[cbind(y0 + 1, x0 + 1)] * (1 - fx) * (1 - fy) + z[cbind(y0 + 1, x0 + 2)] * fx * (1 - fy) +
    z[cbind(y0 + 2, x0 + 1)] * (1 - fx) * fy + z[cbind(y0 + 2, x0 + 2)] * fx * fy
}
edge <- ps$x < 1e-9 | ps$x > W - 1 - 1e-9 | ps$y < 1e-9 | ps$y > H - 1 - 1e-9
cz <- ifelse(edge, bilin(ps$x, ps$y), 0)
coast <- !edge
cs <- which(coast[ps$s0] & coast[ps$s1])
cl <- do.call(rbind, lapply(cs, function(i) {
  n <- max(1, ceiling(4 * sqrt((ps$x[ps$s1[i]] - ps$x[ps$s0[i]])^2 + (ps$y[ps$s1[i]] - ps$y[ps$s0[i]])^2)))
  f <- (seq_len(n) - 1) / n
  cbind(ps$x[ps$s0[i]] + f * (ps$x[ps$s1[i]] - ps$x[ps$s0[i]]), ps$y[ps$s0[i]] + f * (ps$y[ps$s1[i]] - ps$y[ps$s0[i]]))
}))
pol_in <- rescale(pol, fx = 1 + 1e-6, x0 = (W - 1) / 2, y0 = (H - 1) / 2)
inmask <- matrix(!is.na(values(rasterize(pol_in, land))[, 1]), H, W, byrow = TRUE)[H:1, ]
mask <- inmask & z > 0
## samples lying exactly on a coast segment are not inserted: the coastline is
## the authority there (inserting one would split the 0 m edge at its own height)
on_coast <- function(i) {
  x0 <- ps$x[ps$s0[i]]; y0 <- ps$y[ps$s0[i]]; x1 <- ps$x[ps$s1[i]]; y1 <- ps$y[ps$s1[i]]
  gx <- seq(ceiling(min(x0, x1)), floor(max(x0, x1))); gy <- seq(ceiling(min(y0, y1)), floor(max(y0, y1)))
  if (!length(gx) || !length(gy) || ceiling(min(x0, x1)) > floor(max(x0, x1)) ||
      ceiling(min(y0, y1)) > floor(max(y0, y1))) return(NULL)
  g <- expand.grid(x = gx, y = gy)
  g[abs((x1 - x0) * (g$y - y0) - (y1 - y0) * (g$x - x0)) < 1e-9, , drop = FALSE]
}
oc <- do.call(rbind, lapply(cs, on_coast))
if (!is.null(oc) && nrow(oc)) mask[cbind(oc$y + 1, oc$x + 1)] <- FALSE
cat("pacific: samples on the coastline, not inserted:", if (is.null(oc)) 0 else nrow(oc), "\n")
cat("pacific: land samples", sum(mask), "coast vertices", sum(coast), "\n")
for (tol in c(10, 20, 40)) {
  d <- run_delatin(z, tol)
  b <- greedy_tin(z, tol, ps$x, ps$y, cz, ps$s0, ps$s1, mask = mask, erase = "holes",
                  corners = FALSE, frac = 0.7, max_rounds = 3000L)
  for (m in list(list("delatin", d), list("greedy + coastline", b))) {
    e <- mesh_error(m[[2]]$P, m[[2]]$T, z, mask = mask)
    zc <- if (is.null(m[[2]]$tri)) mesh_z_points(m[[2]]$P, m[[2]]$T, cl) else rep(0, nrow(cl))
    res[[length(res) + 1]] <- data.frame(fixture = "pacific", tol = tol, method = m[[1]],
      triangles = nrow(m[[2]]$T), max_err = e[["max"]], rmse = e[["rmse"]],
      coast_max_abs_z = max(abs(zc), na.rm = TRUE),
      straddle_tris = tri_class(m[[2]]$P, m[[2]]$T, m[[2]]$is_sample)[["straddle"]],
      seconds = m[[2]]$seconds)
    if (tol == 20) keep_meshes[[paste("pacific", m[[1]])]] <- m[[2]]
  }
}
## the constrained mesh holds the coast only if every coast segment is an unsplit edge
kept <- local({
  T <- keep_meshes[["pacific greedy + coastline"]]$T; im <- keep_meshes[["pacific greedy + coastline"]]$tri$input_map
  e <- rbind(T[, 1:2], T[, 2:3], T[, c(3, 1)]); key <- paste(pmin(e[, 1], e[, 2]), pmax(e[, 1], e[, 2]))
  a <- im[ps$s0[cs]]; b <- im[ps$s1[cs]]; mean(paste(pmin(a, b), pmax(a, b)) %in% key)
})
cat("pacific coast segments kept as edges:", kept, "\n")
stopifnot(kept == 1)
pacific <- list(z = z, cell = fx$cell, coast = cbind(ps$x, ps$y, cz, coast), segs = cbind(ps$s0, ps$s1))

## ---- sierra-nodata: the regular mesh's own domain, meshed adaptively -------
fx <- read_fixture("sierra-nodata-streaming.json"); z <- fx$z; H <- nrow(z); W <- ncol(z)
ok <- !is.na(z)
## a cell between samples is kept when all four corners are valid (math.gl's regular mesh rule)
q <- ok[-H, -W] & ok[-H, -1] & ok[-1, -W] & ok[-1, -1]
regular_tris <- 2L * sum(q)
qr <- rast(ncols = W - 1, nrows = H - 1, xmin = 0, xmax = W - 1, ymin = 0, ymax = H - 1)
values(qr) <- as.vector(t(q[(H - 1):1, ]))
qr <- classify(qr, cbind(0, NA))
dom <- as.polygons(qr, dissolve = TRUE)
g <- geom(dom)
cat("sierra-nodata: valid samples", sum(ok), "kept cells", sum(q), "domain rings",
    length(unique(paste(g[, "part"], g[, "hole"]))), "\n")
ps2 <- rings_to_pslg(g)
## ring vertices sit on sample centres: heights are the samples themselves
stopifnot(all(abs(ps2$x - round(ps2$x)) < 1e-9), all(abs(ps2$y - round(ps2$y)) < 1e-9))
cz2 <- z[cbind(round(ps2$y) + 1, round(ps2$x) + 1)]
stopifnot(!anyNA(cz2))
## measure only samples inside the domain (the regular mesh's samples)
inq <- matrix(FALSE, H, W)
inq[-H, -W] <- inq[-H, -W] | q; inq[-H, -1] <- inq[-H, -1] | q
inq[-1, -W] <- inq[-1, -W] | q; inq[-1, -1] <- inq[-1, -1] | q
for (tol in c(10, 20, 40)) {
  b <- greedy_tin(z, tol, ps2$x, ps2$y, cz2, ps2$s0, ps2$s1, mask = inq, erase = "holes",
                  corners = FALSE, frac = 0.7, max_rounds = 3000L)
  e <- mesh_error(b$P, b$T, z, mask = inq)
  res[[length(res) + 1]] <- data.frame(fixture = "sierra-nodata", tol = tol, method = "greedy + nodata boundary",
    triangles = nrow(b$T), max_err = e[["max"]], rmse = e[["rmse"]], coast_max_abs_z = NA,
    straddle_tris = NA, seconds = b$seconds)
  if (tol == 20) keep_meshes[["sierra greedy + nodata boundary"]] <- b
}
res[[length(res) + 1]] <- data.frame(fixture = "sierra-nodata", tol = 0, method = "math.gl regular mesh",
  triangles = regular_tris, max_err = 0, rmse = 0, coast_max_abs_z = NA, straddle_tris = NA, seconds = NA)
## the adaptive mesh covers exactly the regular mesh's area
area_tri <- function(P, T) sum(abs((P[T[, 2], 1] - P[T[, 1], 1]) * (P[T[, 3], 2] - P[T[, 1], 2]) -
                                   (P[T[, 3], 1] - P[T[, 1], 1]) * (P[T[, 2], 2] - P[T[, 1], 2]))) / 2
sm <- keep_meshes[["sierra greedy + nodata boundary"]]
cat("sierra-nodata: regular area", sum(q), "adaptive area", area_tri(sm$P, sm$T), "\n")
sierra <- list(z = z, cell = fx$cell, ring_x = ps2$x, ring_y = ps2$y, segs = cbind(ps2$s0, ps2$s1), q = q)

res <- do.call(rbind, res)
print(res, digits = 3)
write.csv(res, file.path(here, "results", "fixtures.csv"), row.names = FALSE)
saveRDS(list(meshes = keep_meshes, pacific = pacific, sierra = sierra), file.path(here, "cache", "fixtures.rds"))
