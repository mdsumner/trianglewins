## Figures for the dev draft, from results/timings.csv and the nc x grid
## overlay mesh.  Rscript survey/dev-drafts/st-mesh-geos/figures.R <outdir>
suppressMessages(library(geos))
args <- commandArgs(trailingOnly = TRUE)
out <- if (length(args) > 0) args[1] else "survey/dev-drafts/st-mesh-geos/results"
dir.create(out, showWarnings = FALSE, recursive = TRUE)
here <- dirname(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE)))
source(file.path(here, "st_mesh.R"))
cpp11::cpp_source(file.path(here, "st_mesh.cpp"), quiet = TRUE)

ink <- "#3d3d3a"; muted <- "#8a897f"; grid <- "#e4e3dc"
cols <- c(nc = "#2a78d6", voronoi = "#eb6834", inlandwaters = "#1baf7a", `nc x grid` = "#8f5bd6")

## ---- speedups against geos ----
tm <- read.csv(file.path(here, "results", "timings.csv"))
tm <- tm[tm$tier != "producer", ]
ops <- rev(unique(tm$op))
tiers <- tm$tier[match(ops, tm$op)]
png(file.path(out, "speedup.png"), width = 1900, height = 1500, res = 200)
par(mar = c(4.2, 17, 1.5, 1), family = "sans", col.axis = ink, col.lab = ink, fg = muted)
lim <- c(0.01, 300)
plot(NA, xlim = lim, ylim = c(0.5, length(ops) + 0.5), log = "x",
     axes = FALSE, xlab = "times faster than the geos package, log scale", ylab = "")
## tier bands
for (k in seq_along(ops)) if (k > 1 && tiers[k] != tiers[k - 1]) abline(h = k - 0.5, col = muted, lty = 3)
abline(v = c(0.01, 0.03, 0.1, 0.3, 1, 3, 10, 30, 100, 300), col = grid)
abline(v = 1, col = muted, lwd = 1.5)
at <- c(0.01, 0.1, 1, 10, 100)
axis(1, at = at, labels = format(at, drop0trailing = TRUE, scientific = FALSE), col = muted, lwd = 0, lwd.ticks = 1)
axis(2, at = seq_along(ops), labels = ops, las = 1, lwd = 0, cex.axis = 0.85)
off <- c(nc = 0.24, voronoi = 0.08, inlandwaters = -0.08, `nc x grid` = 0)
for (l in names(cols)) {
  d <- tm[tm$layer == l, ]
  if (!nrow(d)) next
  y <- match(d$op, ops) + off[[l]]
  points(pmin(pmax(d$speedup, lim[1]), lim[2]), y, pch = 21, bg = cols[[l]], col = "white", cex = 1.5, lwd = 1.3)
}
legend("bottomright", legend = c("nc counties (100)", "Voronoi coverage (19,493)",
                                 "inlandwaters (6, holes)", "nc x rotated grid (overlay)"),
       pt.bg = cols, pch = 21, col = "white", pt.cex = 1.4, bty = "n", text.col = ink, cex = 0.8)
dev.off()

## ---- DE-9IM from the overlay mesh: one county against the grid ----
nc <- sf::st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
g <- as_geos_geometry(sf::st_geometry(sf::st_transform(nc, 32119)))
wk::wk_crs(g) <- NULL
ext <- geos_extent(g)
bb <- c(min(ext$xmin), min(ext$ymin), max(ext$xmax), max(ext$ymax))
gx <- seq(bb[1], bb[3], length.out = 81); gy <- seq(bb[2], bb[4], length.out = 33)
cells <- expand.grid(i = 1:80, j = 1:32)
cg <- geos_create_rectangle(gx[cells$i], gy[cells$j], gx[cells$i + 1], gy[cells$j + 1])
cg <- geos_transform_xy(cg, wk::wk_affine_compose(
  wk::wk_affine_translate(-mean(bb[c(1, 3)]), -mean(bb[c(2, 4)])), wk::wk_affine_scale(1.3, 1.6),
  wk::wk_affine_rotate(17),
  wk::wk_affine_translate(mean(bb[c(1, 3)]), mean(bb[c(2, 4)]))))
m2 <- mesh_from_polymer(polymer::polymer(g, cg))
## a county with a neighbour that touches it only at a point
m1 <- mesh_from_polymer(polymer::polymer(g))
p1 <- mesh_vertex_pairs(m1)
r1 <- mesh_relate(m1, p1[, 1], p1[, 2])
f <- p1[which(r1 == "FF2F01212")[1], 1]
## the county against every cell, and against every other county, all
## from the one overlay mesh
k <- seq_along(cg) + length(g)
rc <- mesh_relate(m2, rep(f, length(k)), k)
rn <- mesh_relate(m2, rep(f, length(g)), seq_along(g))
cell_cls <- ifelse(substr(rc, 1, 1) == "2",
                   ifelse(substr(rc, 7, 7) == "F", "cell within county", "cell overlaps county"), NA)
nb_cls <- ifelse(rn == "FF2F11212", "county shares an edge",
                 ifelse(rn == "FF2F01212", "county touches at a point", NA))
pal <- c(`cell within county` = "#2a78d6", `cell overlaps county` = "#cde2fb",
         `county shares an edge` = "#f6c9b4", `county touches at a point` = "#eb6834")
t <- mem_tri(m2); fm <- m2$mem
draw <- function(tri, col, border = col, lwd = 0.3) {
  polygon(rbind(m2$x[m2$v0[tri]], m2$x[m2$v1[tri]], m2$x[m2$v2[tri]], NA),
          rbind(m2$y[m2$v0[tri]], m2$y[m2$v1[tri]], m2$y[m2$v2[tri]], NA),
          col = col, border = border, lwd = lwd)
}
png(file.path(out, "relate.png"), width = 1800, height = 1000, res = 200)
par(mar = c(0, 0, 0, 0))
e <- geos_extent(g[f]); pad <- 0.45 * (e$xmax - e$xmin)
plot(c(e$xmin - pad, e$xmax + pad), c(e$ymin - 0.5 * pad, e$ymax + 0.25 * pad), type = "n", asp = 1,
     axes = FALSE, xlab = "", ylab = "")
for (j in which(!is.na(nb_cls))) draw(t[fm == j], pal[[nb_cls[j]]])
for (j in which(!is.na(cell_cls))) draw(intersect(t[fm == k[j]], t[fm == f]), pal[[cell_cls[j]]])
draw(t[fm == f], NA, "#ffffff", 0.3)
plot(g, add = TRUE, border = "#b9b8ae", lwd = 0.6, col = NA)
plot(g[f], add = TRUE, border = ink, lwd = 2, col = NA)
legend("topleft", legend = names(pal), fill = pal, border = NA, bty = "o", bg = "white", box.col = NA,
       text.col = ink, cex = 0.8, ncol = 2)
dev.off()
cat("wrote", file.path(out, c("speedup.png", "relate.png")), "\n")
