## Static figures for the breaklines draft. Run from the repository root after
## step.R and coast.R (which leave their meshes in cache/).
source("survey/dev-drafts/mathgl-terrain/greedy-tin.R")
source("survey/dev-drafts/mathgl-terrain/step-surface.R")
out <- "docs/dev-drafts/mathgl-breaklines"
dir.create(out, showWarnings = FALSE, recursive = TRUE)

edges_of <- function(T) {
  e <- rbind(T[, 1:2], T[, 2:3], T[, c(3, 1)])
  e <- cbind(pmin(e[, 1], e[, 2]), pmax(e[, 1], e[, 2]))
  e[!duplicated(e), , drop = FALSE]
}
## draw mesh edges inside a window [x0, x1] x [y0, y1] (grid units, y down)
draw_edges <- function(P, T, col) {
  e <- edges_of(T)
  segments(P[e[, 1], 1], P[e[, 1], 2], P[e[, 2], 1], P[e[, 2], 2], col = col, lwd = 0.6)
}

## 1. cliff: |mesh - true surface| on a 4x lattice, with the mesh and breaklines
e1 <- readRDS("survey/dev-drafts/mathgl-terrain/cache/ex1-step.rds")
W <- ncol(e1$z); H <- nrow(e1$z); k <- 4L
W4 <- (W - 1L) * k + 1L; H4 <- (H - 1L) * k + 1L
x4 <- (seq_len(W4 * H4) - 1L) %% W4 / k; y4 <- (seq_len(W4 * H4) - 1L) %/% W4 / k
win <- c(96, 160, 96, 160)
errimg <- function(m) {
  zz <- mesh_at_cells(m$P[, 1:2] * k, m$P[, 3], m$T, W4, H4)$zhat
  matrix(abs(surface(x4, y4) - zz), H4, W4, byrow = TRUE)
}
pal <- hcl.colors(64, "YlOrRd", rev = TRUE)
png(file.path(out, "cliff.png"), width = 1600, height = 860, res = 150)
op <- par(mfrow = c(1, 2), mar = c(1, 1, 3, 1), bg = "white")
for (nm in c("delatin", "greedy + breaklines")) {
  m <- e1$meshes[[nm]]
  im <- errimg(m)
  xs <- seq(0, W - 1, by = 1 / k); ys <- seq(0, H - 1, by = 1 / k)
  sx <- xs >= win[1] & xs <= win[2]; sy <- ys >= win[3] & ys <= win[4]
  image(xs[sx], ys[sy], t(pmin(im[sy, sx], 2.5)), col = pal, zlim = c(0, 2.5), asp = 1,
        xlim = win[1:2], ylim = rev(win[3:4]), axes = FALSE, xlab = "", ylab = "", useRaster = TRUE)
  draw_edges(m$P, m$T, "#2c5d63")
  for (b in e1$breaklines) lines(b, col = "#b2451f", lwd = 2)
  title(sprintf("%s: %s triangles, surface max %.2f", if (nm == "delatin") "Delatin" else "cdtr + breaklines",
                format(nrow(m$T), big.mark = ","), max(im, na.rm = TRUE)), cex.main = 0.95, font.main = 1)
}
par(op); dev.off()

## 2. Hobart: where each mesh puts the sea (mesh height <= 0), with the coastline
e2 <- readRDS("survey/dev-drafts/mathgl-terrain/cache/ex2-coast.rds")
z <- e2$z; W <- ncol(z); H <- nrow(z)
W4 <- (W - 1L) * k + 1L; H4 <- (H - 1L) * k + 1L
co <- as.data.frame(e2$coast); sg <- as.data.frame(e2$segs)
win <- c(250, 350, 170, 270)
png(file.path(out, "coast.png"), width = 1600, height = 860, res = 150)
op <- par(mfrow = c(1, 2), mar = c(1, 1, 3, 1), bg = "white")
for (nm in c("delatin", "greedy + coastline")) {
  m <- e2$meshes[[nm]]
  zz <- matrix(mesh_at_cells(m$P[, 1:2] * k, m$P[, 3], m$T, W4, H4)$zhat, H4, W4, byrow = TRUE)
  xs <- seq(0, W - 1, by = 1 / k); ys <- seq(0, H - 1, by = 1 / k)
  sx <- xs >= win[1] & xs <= win[2]; sy <- ys >= win[3] & ys <= win[4]
  cls <- ifelse(is.na(zz[sy, sx]), 0, ifelse(zz[sy, sx] > 0, 2, 1))
  image(xs[sx], ys[sy], t(cls), col = c("#f2f2ef", "#9cc3d5", "#c9d8b6"), zlim = c(0, 2), asp = 1,
        xlim = win[1:2], ylim = rev(win[3:4]), axes = FALSE, xlab = "", ylab = "", useRaster = TRUE)
  draw_edges(m$P, m$T, "#2c5d63")
  segments(co$cx[sg$s0], co$cy[sg$s0], co$cx[sg$s1], co$cy[sg$s1],
           col = ifelse(co$coast[sg$s0] == 1 & co$coast[sg$s1] == 1, "#b2451f", NA), lwd = 2)
  title(sprintf("%s: %s triangles at 10 m", if (nm == "delatin") "Delatin" else "cdtr + coastline",
                format(nrow(m$T), big.mark = ",")), cex.main = 0.95, font.main = 1)
}
par(op); dev.off()
cat("wrote", file.path(out, c("cliff.png", "coast.png")), "\n")
