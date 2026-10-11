## Figures and measured numbers for survey/context.md
## (docs/context/index.html). Run from the repo root:
##   Rscript survey/context/figures.R
## Needs laridae, cdtr, decido, geos, wk, RTriangle and this package.
## Writes docs/context/*.png and survey/context/results.csv.

suppressPackageStartupMessages({
  library(laridae)
  library(trianglewins)
})
out <- "docs/context"
dir.create(out, showWarnings = FALSE, recursive = TRUE)
res <- list()
note <- function(key, value) res[[length(res) + 1L]] <<- data.frame(key = key, value = as.character(value))

## ---- helpers -------------------------------------------------------------

## one shape for every engine's output: vertices (x, y) and triangles (v0, v1, v2)
as_mesh <- function(x, y, tri, depth = NULL) {
  tri <- matrix(as.integer(tri), ncol = 3)
  list(vertices = data.frame(x = x, y = y),
       triangles = data.frame(v0 = tri[, 1], v1 = tri[, 2], v2 = tri[, 3],
                              depth = if (is.null(depth)) NA_integer_ else depth))
}
from_earcut <- function(x, y, idx) as_mesh(x, y, matrix(idx, ncol = 3, byrow = TRUE))
## GEOS returns triangle polygons: rebuild an index by exact coordinate match
from_geos <- function(g) {
  co <- wk::wk_coords(g)
  co <- co[duplicated(co[c("feature_id", "part_id", "ring_id")], fromLast = TRUE), ]  # drop closing coordinates
  key <- paste(co$x, co$y)
  u <- !duplicated(key)
  as_mesh(co$x[u], co$y[u], matrix(match(key, key[u]), ncol = 3, byrow = TRUE))
}
from_lari <- function(tab) list(vertices = tab$vertices, triangles = tab$triangles, segments = tab$segments)

depth_col <- function(d, n = 6) {
  pal <- hcl.colors(n, "YlGnBu", rev = TRUE)
  ifelse(is.na(d), "grey92", ifelse(d <= 0, "white", pal[pmin(d, n)]))
}
draw_mesh <- function(m, main = "", fill = NULL, lim = NULL, sx = NULL, sy = NULL, ss = NULL,
                      lwd_tri = 0.6, border = "grey35", pts = NULL) {
  v <- m$vertices; t <- m$triangles
  if (is.null(lim)) lim <- list(x = range(v$x), y = range(v$y))
  plot(lim$x, lim$y, type = "n", asp = 1, axes = FALSE, xlab = "", ylab = "", main = main,
       cex.main = 0.95, font.main = 1)
  if (is.null(fill)) fill <- depth_col(t$depth)
  xs <- rbind(v$x[t$v0], v$x[t$v1], v$x[t$v2], NA)
  ys <- rbind(v$y[t$v0], v$y[t$v1], v$y[t$v2], NA)
  polygon(xs, ys, col = fill, border = border, lwd = lwd_tri)
  if (!is.null(ss)) segments(sx[ss[, 1]], sy[ss[, 1]], sx[ss[, 2]], sy[ss[, 2]], lwd = 2.2, col = "black")
  if (!is.null(pts)) points(pts$x, pts$y, pch = pts$pch, cex = pts$cex, col = pts$col, bg = pts$bg)
}
blank <- function(main, msg, lim) {
  plot(lim$x, lim$y, type = "n", asp = 1, axes = FALSE, xlab = "", ylab = "", main = main,
       cex.main = 0.95, font.main = 1)
  text(mean(lim$x), mean(lim$y), msg, cex = 0.85, col = "grey30")
}
png_open <- function(file, w, h) png(file.path(out, file), width = w, height = h, res = 110)
min_angles <- function(m) {
  v <- m$vertices; t <- m$triangles
  ang <- function(a, b, c) {  # angle at a
    u <- cbind(v$x[b] - v$x[a], v$y[b] - v$y[a]); w <- cbind(v$x[c] - v$x[a], v$y[c] - v$y[a])
    acos(pmin(1, pmax(-1, rowSums(u * w) / sqrt(rowSums(u^2) * rowSums(w^2))))) * 180 / pi
  }
  pmin(ang(t$v0, t$v1, t$v2), ang(t$v1, t$v2, t$v0), ang(t$v2, t$v0, t$v1))
}

## ---- the three small inputs -------------------------------------------------

ring_seg <- function(n, off = 0) cbind(off + seq_len(n), off + c(seq_len(n)[-1], 1))
hole <- list(x = c(0, 1, 1, 0, .25, .75, .75, .25), y = c(0, 0, 1, 1, .25, .25, .75, .75))
hole$s <- rbind(ring_seg(4), ring_seg(4, 4))
pair <- list(x = c(0, 1, 1, 0, 1, 2, 2, 1), y = c(0, 0, 1, 1, 0, 0, 1, 1))
pair$s <- rbind(ring_seg(4), ring_seg(4, 4))           # both rings in full: the shared edge twice
line <- list(x = c(0, 1, 1, 0, .2, .5, 1.3), y = c(0, 0, 1, 1, .3, .6, .7))
line$s <- rbind(ring_seg(4), c(5, 6), c(6, 7))          # a polyline that leaves the square

wkt <- list(
  hole = "POLYGON ((0 0, 1 0, 1 1, 0 1, 0 0), (0.25 0.25, 0.75 0.25, 0.75 0.75, 0.25 0.75, 0.25 0.25))",
  pair = "MULTIPOLYGON (((0 0, 1 0, 1 1, 0 1, 0 0)), ((1 0, 2 0, 2 1, 1 1, 1 0)))",
  line = "GEOMETRYCOLLECTION (POLYGON ((0 0, 1 0, 1 1, 0 1, 0 0)), LINESTRING (0.2 0.3, 0.5 0.6, 1.3 0.7))"
)

## earcut: one polygon (shell plus holes) per call
ec_hole <- from_earcut(hole$x, hole$y, decido::earcut(cbind(hole$x, hole$y), holes = 5))
ec_pair <- local({
  a <- decido::earcut(cbind(pair$x[1:4], pair$y[1:4]))
  b <- decido::earcut(cbind(pair$x[5:8], pair$y[5:8])) + 4L
  from_earcut(pair$x, pair$y, c(a, b))
})
## GEOS
gc <- lapply(wkt, function(w) geos::geos_constrained_delaunay_triangles(geos::geos_read_wkt(w)))
gd_hole <- from_geos(geos::geos_delaunay_triangles(geos::geos_read_wkt(wkt$hole)))
gc_hole <- from_geos(gc$hole); gc_pair <- from_geos(gc$pair); gc_line <- from_geos(gc$line)
note("geos_version", format(geos::geos_version()))
note("geos_delaunay_hole_triangles", nrow(gd_hole$triangles))
note("geos_cdt_hole_triangles", nrow(gc_hole$triangles))
note("geos_cdt_line_triangles", nrow(gc_line$triangles))
note("geos_cdt_line_vertices", nrow(gc_line$vertices))
## laridae
lm <- lapply(list(hole = hole, pair = pair, line = line), function(p) {
  PA <- cbind(z = p$x + 2 * p$y)
  lari_new(p$x, p$y, p$s[, 1], p$s[, 2], PA = PA)
})
lt <- lapply(lm, lari_tables, erase = "hull")
note("lari_hole_depth", paste(names(table(lt$hole$triangles$depth)), table(lt$hole$triangles$depth), sep = ":", collapse = " "))
note("lari_pair_shared_count", max(lt$pair$segments$count))
note("lari_line_crossing", with(lt$line$vertices, paste(x[origin == "crossing"], y[origin == "crossing"], z[origin == "crossing"])))
note("ec_hole_triangles", nrow(ec_hole$triangles))

## figure: three ways
lims <- list(hole = list(x = c(0, 1), y = c(0, 1)), pair = list(x = c(0, 2), y = c(0, 1)),
             line = list(x = c(0, 1.3), y = c(0, 1)))
mark <- function(tab) {
  v <- tab$vertices
  if (is.null(v$origin)) return(NULL)
  k <- v$origin == "crossing"
  if (!any(k)) return(NULL)
  list(x = v$x[k], y = v$y[k], pch = 21, cex = 1.4, col = "black", bg = "#d95f02")
}
png_open("three-ways.png", 1000, 900)
par(mfrow = c(3, 3), mar = c(0.6, 0.6, 2.2, 0.6), oma = c(0, 4, 2, 0))
for (nm in c("hole", "pair", "line")) {
  p <- get(nm)
  ## earcut
  if (nm == "hole") draw_mesh(ec_hole, "", fill = "grey85", lim = lims[[nm]], sx = p$x, sy = p$y, ss = p$s)
  if (nm == "pair") draw_mesh(ec_pair, "", fill = c("grey85", "grey85", "grey70", "grey70"), lim = lims[[nm]], sx = p$x, sy = p$y, ss = p$s)
  if (nm == "line") blank("", "earcut takes rings only:\nthe line cannot be given", lims[[nm]])
  if (nm == "hole") mtext("decido::earcut()", side = 3, line = 0.4, outer = FALSE, cex = 0.85)
  ## GEOS
  g <- get(paste0("gc_", nm))
  draw_mesh(g, "", fill = "grey85", lim = lims[[nm]], sx = p$x, sy = p$y, ss = p$s)
  if (nm == "line") text(0.95, 0.12, "line ignored", adj = 1, cex = 0.85, col = "#b2182b")
  if (nm == "hole") mtext("geos_constrained_delaunay_triangles()", side = 3, line = 0.4, cex = 0.85)
  ## laridae
  draw_mesh(lt[[nm]], "", lim = lims[[nm]], sx = p$x, sy = p$y, ss = p$s, pts = mark(lt[[nm]]))
  if (nm == "hole") mtext("laridae, coloured by depth", side = 3, line = 0.4, cex = 0.85)
}
mtext(c("line", "pair", "hole"), side = 2, outer = TRUE, at = c(1/6, 0.5, 5/6), line = 1, las = 0, cex = 0.95)
dev.off()

## figure: GEOS point Delaunay vs polygon triangulation
png_open("geos-two.png", 900, 420)
par(mfrow = c(1, 2), mar = c(0.6, 0.6, 2.2, 0.6))
draw_mesh(gd_hole, "geos_delaunay_triangles(): vertices only", fill = "grey85", sx = hole$x, sy = hole$y, ss = hole$s)
draw_mesh(gc_hole, "geos_constrained_delaunay_triangles()", fill = "grey85", sx = hole$x, sy = hole$y, ss = hole$s)
dev.off()

## ---- refinement, stepping, sizing -------------------------------------------

m <- lari_new(hole$x, hole$y, hole$s[, 1], hole$s[, 2])
lari_refine(m, max_area = 0.004, min_angle = 25, max_steiner = 0, erase = "holes")
stages <- list(lari_tables(m, "holes"))
for (k in c(10, 30)) { lari_step(m, k); stages[[length(stages) + 1L]] <- lari_tables(m, "holes") }
lari_step(m, 1e5); stages[[length(stages) + 1L]] <- lari_tables(m, "holes")
nst <- vapply(stages, function(s) sum(s$vertices$origin == "steiner"), 1)
note("step_steiner", paste(nst, collapse = " "))
png_open("stepping.png", 1100, 330)
par(mfrow = c(1, 4), mar = c(0.4, 0.4, 2.2, 0.4))
for (i in seq_along(stages)) {
  s <- stages[[i]]
  st <- s$vertices$origin == "steiner"
  draw_mesh(s, sprintf("%d Steiner points", nst[i]), fill = "grey90", sx = hole$x, sy = hole$y, ss = hole$s,
            pts = list(x = s$vertices$x[st], y = s$vertices$y[st], pch = 19, cex = 0.45, col = "#d95f02", bg = NA))
}
dev.off()

sq <- lari_new(c(0, 1, 1, 0), c(0, 0, 1, 1), 1:4, c(2, 3, 4, 1))
## with only a sizing field the default edge floor comes from the segments
## (0.3 of the median length), which stops this square at 32 triangles and
## says so in the report; give the floor explicitly
u_default <- lari_refine(sq, size = function(x, y) 0.0002 + 0.01 * x^2)
note("sizing_default_floor", u_default$min_edge_length)
note("sizing_default_triangles", nrow(lari_triangles(sq)))
note("sizing_default_bad_short", u_default$shortEdges)
sq <- lari_new(c(0, 1, 1, 0), c(0, 0, 1, 1), 1:4, c(2, 3, 4, 1))
lari_refine(sq, size = function(x, y) 0.0002 + 0.01 * x^2, min_edge_length = 0.002)
sz <- lari_tables(sq)
note("sizing_triangles", nrow(sz$triangles))
png_open("sizing.png", 520, 520)
par(mar = c(0.4, 0.4, 2.2, 0.4))
draw_mesh(sz, "size = function(x, y) 0.0002 + 0.01 * x^2", fill = "grey92", lwd_tri = 0.4)
mtext("min_edge_length = 0.002", side = 1, line = -0.6, cex = 0.8)
dev.off()

## attributes reproduced exactly on new vertices
ma <- lari_new(line$x, line$y, line$s[, 1], line$s[, 2], PA = cbind(z = line$x + 2 * line$y))
lari_refine(ma, max_area = 0.005, min_angle = 25)
va <- lari_vertices(ma)
note("attr_max_abs_err", signif(max(abs(va$z - (va$x + 2 * va$y))), 3))
note("attr_new_vertices", sum(va$origin != "input"))

## ---- North Carolina as a coverage -------------------------------------------

ncr <- tw_case("nc_rings"); nc <- tw_case("nc")
note("nc_rings_vertices", length(ncr$x)); note("nc_rings_segments", length(ncr$s0))
note("nc_vertices", length(nc$x)); note("nc_segments", length(nc$s0))
t_r <- lari_tables(lari_new(ncr$x, ncr$y, ncr$s0, ncr$s1))
t_d <- lari_tables(lari_new(nc$x, nc$y, nc$s0, nc$s1))
tab <- function(d) paste(names(table(d)), table(d), sep = ":", collapse = " ")
note("nc_rings_depth", tab(t_r$triangles$depth)); note("nc_depth", tab(t_d$triangles$depth))

## per-ring earcut and GEOS on the same rings (nc has no holes)
ring <- cumsum(c(1L, head(ncr$s1 < ncr$s0, -1)))
ring_rows <- split(seq_along(ncr$x), ring[ncr$s0])
ec_idx <- unlist(lapply(ring_rows, function(r) r[decido::earcut(cbind(ncr$x[r], ncr$y[r]))]))
ec_nc <- from_earcut(ncr$x, ncr$y, ec_idx)
polys <- vapply(ring_rows, function(r) {
  xy <- rbind(cbind(ncr$x[r], ncr$y[r]), c(ncr$x[r[1]], ncr$y[r[1]]))
  sprintf("POLYGON ((%s))", paste(sprintf("%.17g %.17g", xy[, 1], xy[, 2]), collapse = ", "))
}, "")
gc_nc <- from_geos(geos::geos_constrained_delaunay_triangles(geos::geos_read_wkt(polys)))
note("nc_rings_count", length(ring_rows))
cmp <- list(earcut = ec_nc, geos = gc_nc, laridae = from_lari(t_d))
for (nm in names(cmp)) {
  a <- min_angles(cmp[[nm]])
  note(paste0("nc_", nm, "_triangles"), nrow(cmp[[nm]]$triangles))
  note(paste0("nc_", nm, "_minangle_q"), paste(round(quantile(a, c(0, 0.05, 0.5)), 2), collapse = " "))
  note(paste0("nc_", nm, "_below10"), round(100 * mean(a < 10), 1))
}
note("nc_geos_vertices", nrow(gc_nc$vertices))
## are GEOS's per-polygon triangles the same set as laridae's CDT?
tri_key <- function(m) {
  v <- m$vertices; t <- as.matrix(m$triangles[c("v0", "v1", "v2")])
  k <- matrix(paste(v$x[t], v$y[t]), ncol = 3)
  sort(apply(k, 1, function(r) paste(sort(r), collapse = "|")))
}
note("nc_geos_equals_laridae", identical(tri_key(gc_nc), tri_key(cmp$laridae)))
note("nc_earcut_equals_laridae_share", round(mean(tri_key(ec_nc) %in% tri_key(cmp$laridae)), 3))

## refined, three engines, the trianglewins real-data setting
A <- diff(range(nc$x)) * diff(range(nc$y)) / 5000
r_l <- lari_triangulate(nc$x, nc$y, nc$s0, nc$s1, max_area = A, min_angle = 20)
r_c <- cdtr::cdt_triangulate(nc$x, nc$y, nc$s0, nc$s1, max_area = A, min_angle = 20)
r_t <- RTriangle::triangulate(RTriangle::pslg(P = cbind(nc$x, nc$y), S = cbind(nc$s0, nc$s1)), a = A, q = 20)
eng <- list(
  laridae = from_lari(r_l),
  cdtr = as_mesh(r_c$P[, 1], r_c$P[, 2], r_c$T),
  RTriangle = as_mesh(r_t$P[, 1], r_t$P[, 2], r_t$T)
)
for (nm in names(eng)) note(paste0("nc_refined_", nm, "_triangles"), nrow(eng[[nm]]$triangles))

png_open("nc-depth.png", 1100, 380)
par(mfrow = c(1, 2), mar = c(0.4, 0.4, 2.2, 0.4))
draw_mesh(from_lari(t_r), sprintf("rings in full: depth %s", paste(sort(unique(t_r$triangles$depth)), collapse = ", ")), lwd_tri = 0.15, border = "grey60")
draw_mesh(from_lari(t_d), sprintf("shared segments once: depth %s", paste(sort(unique(t_d$triangles$depth)), collapse = ", ")), lwd_tri = 0.15, border = "grey60")
dev.off()

png_open("nc-three.png", 1100, 900)
par(mfrow = c(2, 2), mar = c(0.4, 0.4, 2.2, 0.4))
lim <- list(x = c(-80.2, -78.8), y = c(35.4, 36.3))   # a window in the middle of the state
nm_main <- c(earcut = "decido::earcut(), ring by ring", geos = "GEOS polygon triangulation, ring by ring",
             laridae = "laridae, one CDT of all segments")
for (nm in names(cmp)) {
  draw_mesh(cmp[[nm]], sprintf("%s (%d triangles)", nm_main[[nm]], nrow(cmp[[nm]]$triangles)),
            fill = "grey92", lim = lim, lwd_tri = 0.5, sx = nc$x, sy = nc$y, ss = cbind(nc$s0, nc$s1))
}
draw_mesh(eng$laridae, sprintf("laridae refined: max_area A/5000, min_angle 20 (%d)", nrow(eng$laridae$triangles)),
          fill = "grey92", lim = lim, lwd_tri = 0.4, sx = nc$x, sy = nc$y, ss = cbind(nc$s0, nc$s1))
dev.off()

## edit and re-refine on nc
mn <- lari_new(nc$x, nc$y, nc$s0, nc$s1)
lari_refine(mn, max_area = A, min_angle = 20)
n0 <- lari_counts(mn)
ids <- lari_add_points(mn, c(-79.5, -79.3), c(35.8, 35.9))
lari_add_segments(mn, ids[1], ids[2])
lari_refine(mn, max_area = A, min_angle = 20)
n1 <- lari_counts(mn)
note("nc_edit_new_steiner", n1$steiner - n0$steiner)

res <- do.call(rbind, res)
write.csv(res, "survey/context/results.csv", row.names = FALSE)
print(res, right = FALSE)
