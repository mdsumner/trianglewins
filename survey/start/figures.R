## Figures for survey/start.md (docs/start/index.html). Run from the repo root:
##   Rscript survey/start/figures.R
## Needs sf, decido, deldir and cdtr.

suppressPackageStartupMessages({
  library(sf)
})
out <- "docs/start"
dir.create(out, showWarnings = FALSE, recursive = TRUE)
set.seed(1)

nc <- st_transform(st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE), 32119)
one <- nc[nc$NAME == "Wake", ]

## the rings of one polygon as vertex and segment tables (closing point dropped)
rings <- function(g) {
  co <- as.data.frame(st_coordinates(g))
  key <- interaction(co$L1, co$L2, co$L3, drop = TRUE)
  co <- co[duplicated(key, fromLast = TRUE), ]
  key <- droplevels(key[duplicated(key, fromLast = TRUE)])
  n <- nrow(co)
  first <- !duplicated(key)
  start <- cumsum(first)
  s0 <- seq_len(n)
  s1 <- s0 + 1L
  last <- c(first[-1], TRUE)
  s1[last] <- which(first)[start[last]]
  list(x = co$X, y = co$Y, s0 = s0, s1 = s1, ring = as.integer(key))
}

lim_of <- function(x, y, pad = 0.03) {
  rx <- range(x); ry <- range(y)
  list(x = rx + c(-1, 1) * pad * diff(rx), y = ry + c(-1, 1) * pad * diff(ry))
}
frame <- function(lim, main) {
  plot(lim$x, lim$y, type = "n", asp = 1, axes = FALSE, xlab = "", ylab = "",
       main = main, cex.main = 1, font.main = 1)
}
tris <- function(x, y, tri, col = "#e6eef7", border = "grey40", lwd = 0.6) {
  tri <- matrix(tri, ncol = 3)
  xs <- rbind(x[tri[, 1]], x[tri[, 2]], x[tri[, 3]], NA)
  ys <- rbind(y[tri[, 1]], y[tri[, 2]], y[tri[, 3]], NA)
  polygon(xs, ys, col = col, border = border, lwd = lwd)
}
outline <- function(p, lwd = 2, col = "black") segments(p$x[p$s0], p$y[p$s0], p$x[p$s1], p$y[p$s1], lwd = lwd, col = col)
png_open <- function(file, w, h) png(file.path(out, file), width = w, height = h, res = 110)

p <- rings(st_geometry(one))
lim <- lim_of(p$x, p$y)
ear <- matrix(decido::earcut(cbind(p$x, p$y)), ncol = 3, byrow = TRUE)
pts <- st_coordinates(st_sample(st_geometry(one), 60))
dd <- deldir::deldir(pts[, 1], pts[, 2])
dtri <- do.call(rbind, lapply(deldir::triang.list(dd), function(t) t$ptNum))
mesh <- cdtr::cdt_triangulate(p$x, p$y, p$s0, p$s1,
                              max_area = st_area(one) |> as.numeric() / 300, min_angle = 25)

## ---- 1. the idea: a polygon becomes triangles, points become triangles ----
png_open("idea.png", 1100, 320)
op <- par(mfrow = c(1, 4), mar = c(0.5, 0.5, 2.2, 0.5))
frame(lim, "a polygon")
polygon(p$x, p$y, col = "#e6eef7", border = NA); outline(p)
frame(lim, "cut into triangles")
tris(p$x, p$y, ear); outline(p)
frame(lim, "some points")
outline(p, lwd = 1, col = "grey70"); points(pts, pch = 19, cex = 0.7)
frame(lim, "joined into triangles")
outline(p, lwd = 1, col = "grey70"); tris(pts[, 1], pts[, 2], dtri, col = NA, border = "grey20", lwd = 0.8)
points(pts, pch = 19, cex = 0.7)
par(op); dev.off()

## ---- 2. three questions, three kinds of answer ---------------------------
png_open("three.png", 1100, 400)
op <- par(mfrow = c(1, 3), mar = c(0.5, 0.5, 2.6, 0.5))
frame(lim, "fill my polygon\n(decido::earcut)")
tris(p$x, p$y, ear); outline(p)
frame(lim, "connect my points\n(deldir::deldir)")
outline(p, lwd = 1, col = "grey70"); tris(pts[, 1], pts[, 2], dtri, col = NA, border = "grey20", lwd = 0.8)
points(pts, pch = 19, cex = 0.6)
frame(lim, "keep my edges, make nice triangles\n(cdtr::cdt_triangulate)")
tris(mesh$P[, 1], mesh$P[, 2], mesh$T); outline(p)
par(op); dev.off()

## ---- 3. neighbours: one at a time, or together -----------------------------
two <- nc[nc$NAME %in% c("Wake", "Johnston"), ]
both <- rings(st_geometry(two))
## dedup vertices and segments so the shared boundary is given once
key <- paste(both$x, both$y)
u <- !duplicated(key)
id <- match(key, key[u])
s <- cbind(pmin(id[both$s0], id[both$s1]), pmax(id[both$s0], id[both$s1]))
s <- s[!duplicated(s), ]
bx <- both$x[u]; by <- both$y[u]
amax <- as.numeric(sum(st_area(two))) / 400
sep <- lapply(seq_len(nrow(two)), function(i) {
  r <- rings(st_geometry(two)[i])
  cdtr::cdt_triangulate(r$x, r$y, r$s0, r$s1, max_area = amax, min_angle = 25)
})
tog <- cdtr::cdt_triangulate(bx, by, s[, 1], s[, 2], max_area = amax, min_angle = 25)

## a window on the shared boundary
shared <- st_coordinates(st_intersection(st_boundary(st_geometry(two)[1]), st_boundary(st_geometry(two)[2])))
cx <- median(shared[, 1]); cy <- median(shared[, 2])
w <- 9000
win <- list(x = cx + c(-w, w), y = cy + c(-w, w) * 0.75)
cols <- c("#e6eef7", "#fbe7d6")
png_open("neighbours.png", 1100, 440)
op <- par(mfrow = c(1, 2), mar = c(0.5, 0.5, 2.6, 0.5))
frame(win, "each county on its own:\nthe two sides do not meet at the same points")
for (i in 1:2) tris(sep[[i]]$P[, 1], sep[[i]]$P[, 2], sep[[i]]$T, col = adjustcolor(cols[i], 0.85))
for (i in 1:2) points(sep[[i]]$P[, 1], sep[[i]]$P[, 2], pch = 19, cex = 0.35, col = c("#2a78d6", "#eb6834")[i])
frame(win, "both counties as one mesh:\nthe shared boundary is shared")
tris(tog$P[, 1], tog$P[, 2], tog$T, col = cols[1])
segments(bx[s[, 1]], by[s[, 1]], bx[s[, 2]], by[s[, 2]], lwd = 2)
par(op); dev.off()

cat("wrote", list.files(out, pattern = "png$", full.names = TRUE), sep = "\n")
