## Figures for study 2 (math.gl's fixtures). Run from the repository root
## after fixtures.R.
source("survey/dev-drafts/mathgl-terrain/greedy-tin.R")
out <- "docs/dev-drafts/mathgl-breaklines"
fx <- readRDS("survey/dev-drafts/mathgl-terrain/cache/fixtures.rds")
k <- 4L
edges_of <- function(T) {
  e <- rbind(T[, 1:2], T[, 2:3], T[, c(3, 1)])
  e <- cbind(pmin(e[, 1], e[, 2]), pmax(e[, 1], e[, 2]))
  e[!duplicated(e), , drop = FALSE]
}
draw_edges <- function(P, T, col, lwd = 0.6) {
  e <- edges_of(T)
  segments(P[e[, 1], 1], P[e[, 1], 2], P[e[, 2], 1], P[e[, 2], 2], col = col, lwd = lwd)
}

## pacific: where each mesh puts the sea, with the coastline
z <- fx$pacific$z; W <- ncol(z); H <- nrow(z)
W4 <- (W - 1L) * k + 1L; H4 <- (H - 1L) * k + 1L
co <- as.data.frame(fx$pacific$coast); names(co) <- c("x", "y", "z", "coast")
sg <- as.data.frame(fx$pacific$segs); names(sg) <- c("s0", "s1")
win <- c(120, 200, 140, 220)
png(file.path(out, "pacific.png"), width = 1600, height = 860, res = 150)
op <- par(mfrow = c(1, 2), mar = c(1, 1, 3, 1), bg = "white")
for (nm in c("pacific delatin", "pacific greedy + coastline")) {
  m <- fx$meshes[[nm]]
  zz <- matrix(mesh_at_cells(m$P[, 1:2] * k, m$P[, 3], m$T, W4, H4)$zhat, H4, W4, byrow = TRUE)
  xs <- seq(0, W - 1, by = 1 / k); ys <- seq(0, H - 1, by = 1 / k)
  sx <- xs >= win[1] & xs <= win[2]; sy <- ys >= win[3] & ys <= win[4]
  cls <- ifelse(is.na(zz[sy, sx]), 0, ifelse(zz[sy, sx] > 0, 2, 1))
  image(xs[sx], ys[sy], t(cls), col = c("#f2f2ef", "#9cc3d5", "#c9d8b6"), zlim = c(0, 2), asp = 1,
        xlim = win[1:2], ylim = rev(win[3:4]), axes = FALSE, xlab = "", ylab = "", useRaster = TRUE)
  draw_edges(m$P, m$T, "#2c5d63")
  cc <- co$coast[sg$s0] == 1 & co$coast[sg$s1] == 1
  segments(co$x[sg$s0[cc]], co$y[sg$s0[cc]], co$x[sg$s1[cc]], co$y[sg$s1[cc]], col = "#b2451f", lwd = 2)
  title(sprintf("%s: %s triangles at 20 m", if (grepl("delatin", nm)) "Delatin" else "cdtr + coastline",
                format(nrow(m$T), big.mark = ",")), cex.main = 0.95, font.main = 1)
}
par(op); dev.off()

## sierra-nodata: math.gl's regular mesh against the adaptive mesh on the same domain
s <- fx$sierra; z <- s$z; W <- ncol(z); H <- nrow(z); q <- s$q
win <- c(80, 136, 80, 136)
png(file.path(out, "sierra-nodata.png"), width = 1600, height = 860, res = 150)
op <- par(mfrow = c(1, 2), mar = c(1, 1, 3, 1), bg = "white")
okz <- !is.na(z)
for (panel in 1:2) {
  plot(NA, xlim = win[1:2], ylim = rev(win[3:4]), asp = 1, axes = FALSE, xlab = "", ylab = "")
  ## missing samples
  miss <- which(!okz, arr.ind = TRUE)
  inw <- miss[, 2] - 1 >= win[1] & miss[, 2] - 1 <= win[2] & miss[, 1] - 1 >= win[3] & miss[, 1] - 1 <= win[4]
  if (panel == 1) {
    ## regular mesh: two triangles per kept cell
    cells <- which(q, arr.ind = TRUE)
    cw <- cells[, 2] - 1 >= win[1] - 1 & cells[, 2] - 1 <= win[2] & cells[, 1] - 1 >= win[3] - 1 & cells[, 1] - 1 <= win[4]
    cx <- cells[cw, 2] - 1; cy <- cells[cw, 1] - 1
    rect(cx, cy, cx + 1, cy + 1, border = "#2c5d63", lwd = 0.4)
    segments(cx, cy, cx + 1, cy + 1, col = "#2c5d63", lwd = 0.4)
    title(sprintf("math.gl regular mesh: %s triangles", format(2 * sum(q), big.mark = ",")), cex.main = 0.95, font.main = 1)
  } else {
    m <- fx$meshes[["sierra greedy + nodata boundary"]]
    draw_edges(m$P, m$T, "#2c5d63", 0.5)
    sg <- s$segs
    segments(s$ring_x[sg[, 1]], s$ring_y[sg[, 1]], s$ring_x[sg[, 2]], s$ring_y[sg[, 2]], col = "#b2451f", lwd = 1.6)
    title(sprintf("cdtr, nodata outline as constraint: %s triangles at 20 m", format(nrow(m$T), big.mark = ",")),
          cex.main = 0.95, font.main = 1)
  }
  points(miss[inw, 2] - 1, miss[inw, 1] - 1, pch = 4, cex = 0.5, col = "#7a1f0b")
}
par(op); dev.off()
cat("wrote pacific.png, sierra-nodata.png\n")
