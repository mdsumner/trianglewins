## Draw a mesh read back from its geoarrow.triangles Parquet file.
##   Rscript survey/dev-drafts/pilot/plot-mesh.R <outdir> <name> <png>
args <- commandArgs(TRUE)
here <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))
source(file.path(here, "geoarrow_triangles.R"))
pt <- arrow::read_parquet(file.path(args[1], paste0(args[2], ".parquet")), as_data_frame = FALSE)
vt <- arrow::read_parquet(file.path(args[1], paste0(args[2], "-vertices.parquet")))
pts <- ga_decoded_coords(pt$triangles)
tri <- ga_decoded_to_wkpool_tri(pts$x, pts$y)
m <- ga_from_wkpool_tri(tri)
depth <- as.vector(pt$depth)
cons <- matrix(unlist(as.vector(pt$constrained)), ncol = 3, byrow = TRUE)
xy <- m$xy; t0 <- m$tri + 1L
png(args[3], width = 1400, height = 1000, res = 150)
par(mar = rep(0.5, 4))
plot(xy, type = "n", asp = 1, axes = FALSE, xlab = "", ylab = "")
pal <- c("1" = "#cfe3f3", "2" = "#f6d6a8", "3" = "#c9e7c0")
idx <- rbind(t(t0), NA)
polygon(xy[idx, 1], xy[idx, 2], col = pal[as.character(depth)], border = if (nrow(t0) > 5000) NA else "grey55", lwd = 0.5)
for (k in 1:3) {
  a <- t0[, k]; b <- t0[, k %% 3 + 1]; on <- cons[, k]
  segments(xy[a[on], 1], xy[a[on], 2], xy[b[on], 1], xy[b[on], 2], lwd = if (nrow(t0) > 5000) 0.6 else 2)
}
st <- vt$origin == "steiner"
if (sum(st) > 2000) st[] <- FALSE
points(xy[st, , drop = FALSE], pch = 19, cex = 0.35, col = "firebrick")
legend("topright", bty = "n", cex = 0.8,
       fill = c(pal, NA, NA), border = c(NA, NA, NA, NA, NA),
       legend = c("depth 1", "depth 2", "depth 3", "constrained edge", "Steiner vertex"),
       lwd = c(NA, NA, NA, 2, NA), pch = c(NA, NA, NA, NA, 19),
       col = c(NA, NA, NA, "black", "firebrick"))
dev.off()
