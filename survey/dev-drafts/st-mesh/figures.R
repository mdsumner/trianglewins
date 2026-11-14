## Figures for the dev draft, from results/timings.csv and the nc mesh.
##   Rscript survey/dev-drafts/st-mesh/figures.R <outdir>
suppressMessages(library(sf))
sf_use_s2(FALSE)
args <- commandArgs(trailingOnly = TRUE)
out <- if (length(args) > 0) args[1] else "survey/dev-drafts/st-mesh/results"
here <- dirname(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE)))
source(file.path(here, "st_mesh.R"))
cpp11::cpp_source(file.path(here, "st_mesh.cpp"), quiet = TRUE)

ink <- "#3d3d3a"; muted <- "#8a897f"; grid <- "#e4e3dc"
cols <- c(nc = "#2a78d6", voronoi = "#eb6834", inlandwaters = "#1baf7a")

## ---- speedups ----
tm <- read.csv(file.path(here, "results", "timings.csv"))
ops <- rev(unique(tm$op))
png(file.path(out, "speedup.png"), width = 1800, height = 1100, res = 200)
par(mar = c(4.2, 15, 1.5, 1), family = "sans", col.axis = ink, col.lab = ink, fg = muted)
plot(NA, xlim = c(0.1, 100), ylim = c(0.5, length(ops) + 0.5), log = "x",
     axes = FALSE, xlab = "times faster than sf (GEOS), log scale", ylab = "")
abline(v = c(0.1, 0.3, 1, 3, 10, 30, 100), col = grid)
abline(v = 1, col = muted, lwd = 1.5)
axis(1, at = c(0.1, 0.3, 1, 3, 10, 30, 100), labels = c("0.1", "0.3", "1", "3", "10", "30", "100"),
     col = muted, lwd = 0, lwd.ticks = 1)
axis(2, at = seq_along(ops), labels = ops, las = 1, lwd = 0, cex.axis = 0.9)
off <- c(nc = 0.22, voronoi = 0, inlandwaters = -0.22)
for (l in names(cols)) {
  d <- tm[tm$layer == l, ]
  y <- match(d$op, ops) + off[[l]]
  points(pmax(d$speedup, 0.1), y, pch = 21, bg = cols[[l]], col = "white", cex = 1.6, lwd = 1.5)
}
legend("bottomright", legend = c("nc counties (100)", "Voronoi coverage (19,493)",
                                 "inlandwaters (6, holes)"),
       pt.bg = cols, pch = 21, col = "white", pt.cex = 1.5, bty = "n", text.col = ink, cex = 0.85)
dev.off()

## ---- the nc mesh, with what three native functions return ----
nc <- st_transform(st_geometry(st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)), 32119)
m <- mesh_from_polymer(polymer::polymer(st_sf(geometry = nc)))
grp <- as.integer(cut(st_coordinates(st_centroid(nc))[, 1], 8))
u <- st_set_crs(st_as_sfc(mesh_union2(m, grp)), 32119)
pos <- mesh_point_on_surface(m)
a <- tri_area(m)
o <- order(m$feature, -a)
big <- o[!duplicated(m$feature[o])]
fill <- rep("#f4f3ee", length(m$v0)); fill[big] <- "#cde2fb"
png(file.path(out, "nc-mesh.png"), width = 2000, height = 820, res = 200)
par(mar = c(0, 0, 0, 0))
plot(st_bbox(nc)[c(1, 3)], st_bbox(nc)[c(2, 4)], type = "n", asp = 1, axes = FALSE, xlab = "", ylab = "")
xx <- rbind(m$x[m$v0], m$x[m$v1], m$x[m$v2], NA); yy <- rbind(m$y[m$v0], m$y[m$v1], m$y[m$v2], NA)
polygon(xx, yy, col = fill, border = "#b9b8ae", lwd = 0.4)
plot(u, add = TRUE, border = ink, lwd = 1.6, col = NA)
points(pos, pch = 21, bg = "#2a78d6", col = "white", cex = 0.9, lwd = 0.8)
dev.off()
cat("wrote", file.path(out, c("speedup.png", "nc-mesh.png")), "\n")
