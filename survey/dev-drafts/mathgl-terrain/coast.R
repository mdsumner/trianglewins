## Example 2: Hobart, kunanyi/Mount Wellington and the Derwent estuary, from the
## AWS open terrain tiles (z10 GeoTIFF, Web Mercator, about 56 m on the ground).
## The coastline (land = height > 0, simplified within one cell) is both a
## breakline at height 0 and the mesh boundary, so the sea is left out as nodata.
source("survey/dev-drafts/mathgl-terrain/greedy-tin.R")

r <- rast("survey/dev-drafts/mathgl-terrain/cache/mosaic.vrt")
win <- r[121:633, 251:763, drop = FALSE]          # 513 x 513 samples
z <- as.matrix(win, wide = TRUE) * 1.0
H <- nrow(z); W <- ncol(z)
res_m <- res(win)[1]

## land mask in sample coordinates (cell centres on integers, y down)
land <- rast(ncols = W, nrows = H, xmin = -0.5, xmax = W - 0.5, ymin = -0.5, ymax = H - 0.5)
values(land) <- as.vector(t(z[H:1, ] > 0))      # terra row 1 is the top = our last row
land <- classify(land, cbind(0, NA))
pol <- as.polygons(land, dissolve = TRUE)
pol <- disagg(pol)
pol <- pol[expanse(pol, transform = FALSE) > 25]   # drop islets under 25 cells
pol <- fillHoles(pol, inverse = FALSE)
pol <- simplifyGeom(pol, tolerance = 1, preserveTopology = TRUE)
pol <- crop(pol, ext(0, W - 1, 0, H - 1))
pol <- makeValid(pol)
pol <- pol[expanse(pol, transform = FALSE) > 25]
g <- geom(pol)
cat("land parts:", length(unique(g[, "part"])), " rings vertices:", nrow(g), "\n")

## rings -> vertices and segments (drop the closing repeat of each ring)
ring <- paste(g[, "geom"], g[, "part"], g[, "hole"])
keep <- !duplicated(cbind(ring, g[, "x"], g[, "y"]))
g <- g[keep, ]; ring <- ring[keep]
cx <- g[, "x"]; cy <- g[, "y"]
idx <- seq_along(cx)
nxt <- ave(idx, ring, FUN = function(i) c(i[-1], i[1]))
s0 <- idx; s1 <- nxt
## heights: 0 on the coast; on the window edge, bilinear from the grid
bilin <- function(x, y) {
  x0 <- pmin(floor(x), W - 2); y0 <- pmin(floor(y), H - 2); fx <- x - x0; fy <- y - y0
  z[cbind(y0 + 1, x0 + 1)] * (1 - fx) * (1 - fy) + z[cbind(y0 + 1, x0 + 2)] * fx * (1 - fy) +
    z[cbind(y0 + 2, x0 + 1)] * (1 - fx) * fy + z[cbind(y0 + 2, x0 + 2)] * fx * fy
}
eps <- 1e-9
edge <- cx < eps | cx > W - 1 - eps | cy < eps | cy > H - 1 - eps
cz <- ifelse(edge, bilin(cx, cy), 0)
coast <- !edge
cat("coast vertices:", sum(coast), " window-edge vertices:", sum(edge), "\n")

## measure on land samples inside the simplified coastline
## inflate a hair so samples on the window edge count as inside
pol_in <- rescale(pol, fx = 1 + 1e-6, x0 = (W - 1) / 2, y0 = (H - 1) / 2)
inside <- rasterize(pol_in, land, touches = FALSE)
inmask <- matrix(!is.na(values(inside)[, 1]), H, W, byrow = TRUE)[H:1, ]
mask <- inmask & z > 0

## points along the supplied coastline (coast-to-coast segments only), every 1/4 cell
cs <- which(coast[s0] & coast[s1])
cl <- do.call(rbind, lapply(cs, function(i) {
  n <- max(1, ceiling(4 * sqrt((cx[s1[i]] - cx[s0[i]])^2 + (cy[s1[i]] - cy[s0[i]])^2)))
  f <- (seq_len(n) - 1) / n
  cbind(cx[s0[i]] + f * (cx[s1[i]] - cx[s0[i]]), cy[s0[i]] + f * (cy[s1[i]] - cy[s0[i]]))
}))
## triangles mixing land and sea, and triangles wholly at sea
## (a grid sample at or below 0 is sea; supplied coast vertices are not samples)
tri_class <- function(P, T, is_sample) {
  zt <- matrix(P[T, 3], ncol = 3)
  sea_v <- matrix(is_sample[T] & P[T, 3] <= 0, ncol = 3)
  c(straddle = sum(rowSums(sea_v) > 0 & apply(zt, 1, max) > 0),
    sea = sum(rowSums(sea_v) == 3))
}
## for a mesh built on the coastline: are all coast segments unsplit mesh edges?
coast_edges_kept <- function(T, input_map) {
  e <- rbind(T[, 1:2], T[, 2:3], T[, c(3, 1)])
  key <- paste(pmin(e[, 1], e[, 2]), pmax(e[, 1], e[, 2]))
  a <- input_map[s0[cs]]; b <- input_map[s1[cs]]
  mean(paste(pmin(a, b), pmax(a, b)) %in% key)
}

## the continuous surface the grid stands for: bilinear between samples.
## Measured on a 4x lattice, at points inside the coastline with height > 0
k4 <- 4L; W4 <- (W - 1L) * k4 + 1L; H4 <- (H - 1L) * k4 + 1L
t4 <- rast(ncols = W4, nrows = H4, xmin = -0.5 / k4, xmax = W - 1 + 0.5 / k4,
           ymin = -0.5 / k4, ymax = H - 1 + 0.5 / k4)
in4 <- matrix(!is.na(values(rasterize(pol_in, t4))[, 1]), H4, W4, byrow = TRUE)[H4:1, ]
x4 <- (seq_len(W4 * H4) - 1L) %% W4 / k4; y4 <- (seq_len(W4 * H4) - 1L) %/% W4 / k4
keep4 <- as.vector(t(in4)) & bilin(x4, y4) > 0

res <- list(); meshes <- list()
for (tol in c(5, 10, 20)) {
  d <- run_delatin(z, tol)
  a <- greedy_tin(z, tol, frac = 0.7, max_rounds = 3000L)
  b <- greedy_tin(z, tol, cx, cy, cz, s0, s1, mask = mask, erase = "holes",
                  corners = FALSE, frac = 0.7, max_rounds = 3000L)
  for (m in list(list("delatin", d), list("greedy", a), list("greedy + coastline", b))) {
    e <- mesh_error(m[[2]]$P, m[[2]]$T, z, mask = mask)
    be <- surface_error(m[[2]]$P, m[[2]]$T, bilin, W, H, keep = keep4)
    tc <- tri_class(m[[2]]$P, m[[2]]$T, m[[2]]$is_sample)
    if (is.null(m[[2]]$tri)) {
      zc <- mesh_z_points(m[[2]]$P, m[[2]]$T, cl)
    } else {
      ## the coastline is in the mesh: heights along it are exactly 0 when every
      ## coast segment survives as an unsplit edge with 0 m at both ends
      kept <- coast_edges_kept(m[[2]]$T, m[[2]]$tri$input_map)
      cat("coast segments kept as edges:", kept, "\n")
      zc <- if (kept == 1) rep(0, nrow(cl)) else mesh_z_points(m[[2]]$P, m[[2]]$T, cl)
    }
    res[[length(res) + 1]] <- data.frame(fixture = "hobart", tol = tol, method = m[[1]],
      triangles = nrow(m[[2]]$T), vertices = nrow(m[[2]]$P),
      land_max_err = e[["max"]], land_rmse = e[["rmse"]],
      bilinear_max = be[["cont_max"]], bilinear_rmse = be[["cont_rmse"]],
      coast_max_abs_z = max(abs(zc), na.rm = TRUE), coast_mean_abs_z = mean(abs(zc), na.rm = TRUE),
straddle_tris = tc[["straddle"]], sea_tris = tc[["sea"]],
      seconds = m[[2]]$seconds)
    if (tol == 10) meshes[[m[[1]]]] <- m[[2]]
  }
}
res <- do.call(rbind, res)
print(res, digits = 3)
write.csv(res, "survey/dev-drafts/mathgl-terrain/results/coast.csv", row.names = FALSE)
saveRDS(list(z = z, res_m = res_m, ext = as.vector(ext(win)), meshes = meshes,
             coast = cbind(cx, cy, cz, coast), segs = cbind(s0, s1)), "survey/dev-drafts/mathgl-terrain/cache/ex2-coast.rds")
