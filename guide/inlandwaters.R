## Worked example for guide/README.md: silicate::inlandwaters through
## pslg_from_wk() and every installed backend.
##
## The layer comes in as anything wk can read. Here it is the .rda from
## silicate (sf), turned into a plain data frame with a wkb column, which is
## what a GeoParquet file gives you too (see the guide).

source("guide/mesh-wk.R")

if (requireNamespace("silicate", quietly = TRUE)) {
  iw_sf <- silicate::inlandwaters
} else {
  ## a clone of github.com/hypertidy/silicate next to this repo
  e <- new.env(); load(file.path("..", "silicate", "data", "inlandwaters.rda"), envir = e)
  iw_sf <- e$inlandwaters
}
iw <- data.frame(ID = iw_sf$ID, Province = iw_sf$Province, geometry = wk::as_wkb(iw_sf))

## 1. input tables
p <- pslg_from_wk(iw)
p
table(p$edges$count)      ## 2612 edges are given twice: shared boundaries

## 2. constrained only, then refined to about 50000 triangles at 20 degrees,
## by every backend that is installed
backends <- c("cdtr", "laridae", "trowel", "RTriangle")
backends <- backends[vapply(backends, requireNamespace, TRUE, quietly = TRUE)]
amax <- area_for(p, 5e4)
meshes <- lapply(backends, function(b) tri_mesh(p, b, max_area = amax, min_angle = 20))
names(meshes) <- backends
meshes

## 3. labels: which feature covers each triangle. Depth alone cannot say: the
## ACT polygon sits in a hole of the NSW polygon, so ACT is depth 2 and so
## are NSW's islands
m <- meshes[[1]]
lab <- tri_label(m)
table(depth = lab$depth, labelled = !is.na(lab$feature))
## area per feature reproduces the input exactly
a <- abs(tri_area(m$vertices, lab))
cbind(mesh = tapply(a, lab$feature, sum), input = vapply(pslg_split(p), pslg_area, 1))

## 4. out again: triangles as wkb with their labels (write with any wk
## consumer: sf::st_as_sf(), geoarrow, wk::wk_handle() into a writer)
tw <- tri_as_wk(m, lab[!is.na(lab$feature), ])
head(tw)

## 5. per-feature meshing: same answer for features that share nothing, and
## it parallelises. NSW, Victoria and SA share the Murray, so they are kept
## together here
grp <- ifelse(p$features$Province %in% c("New South Wales", "Victoria", "South Australia",
                                         "Australian Capital Territory"), "murray", p$features$Province)
parts <- pslg_split(p, grp)
pm <- lapply(parts, tri_mesh, backend = backends[1], max_area = amax, min_angle = 20)
vapply(pm, function(z) nrow(z$triangles), 1L)

## 6. attributes ride along: give the vertices a linear field and check that
## the added vertices carry it exactly
pz <- pslg_from_wk(iw, attr = function(v) data.frame(f = v$x + 2 * v$y))
mz <- tri_mesh(pz, backends[1], max_area = amax)
max(abs(mz$vertices$f - (mz$vertices$x + 2 * mz$vertices$y)))
tri_interpolate(mz, c(1116500, 0), c(-458000, 0))

## figures
png("guide/figures/inlandwaters-overview.png", width = 1400, height = 900, res = 120)
pal <- c("#1b9e77", "#d95f02", "#7570b3", "#e7298a", "#66a61e", "#e6ab02")
plot(m, col = ifelse(is.na(lab$feature), "grey90", pal[lab$feature]), border = NA, constraint = "grey20",
     xlim = c(-7e5, 1.8e6), ylim = c(-1.3e6, 5e5))
legend("bottomleft", legend = p$features$Province, fill = pal, bty = "n", cex = 0.8)
dev.off()

## zoom on the ACT: a polygon in another polygon's hole
act <- p$vertices[unique(p$segments$s0[path_info(p, p$segments$path, "feature") == 1L]), ]
bb <- c(range(act$x), range(act$y)) + c(-1, 1, -1, 1) * 2e4
png("guide/figures/inlandwaters-act.png", width = 1400, height = 700, res = 120)
op <- par(mfrow = c(1, 2), mar = c(0, 0, 2, 0))
for (k in 1:2) {
  mm <- if (k == 1) m else meshes[[min(3L, length(meshes))]]
  ll <- if (k == 1) lab else tri_label(mm)
  V <- mm$vertices
  keep <- with(mm$triangles, V$x[v0] > bb[1] & V$x[v0] < bb[2] & V$y[v0] > bb[3] & V$y[v0] < bb[4])
  sub <- mm; sub$triangles <- mm$triangles[keep, ]
  plot(sub, col = ifelse(is.na(ll$feature[keep]), "grey90", pal[ll$feature[keep]]),
       border = "grey40", main = mm$backend, xlim = bb[1:2], ylim = bb[3:4])
}
par(op)
dev.off()
