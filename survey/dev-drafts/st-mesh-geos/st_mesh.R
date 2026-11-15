## ST_* functions on a triangle mesh, built on wkpool, cdtr, polymer and
## geos only (no sf). Companion to the dev draft "ST_* on wkpool and geos".
##
## A mesh is the triangle form of the hypertidy mesh spec, as these
## functions read it:
##   x, y          vertex coordinates (the dictionary of geoarrow.triangles)
##   v0, v1, v2    1-based vertex rows per triangle, counter-clockwise
##   mem_start, mem  the features of each triangle (CSR): one each for a
##                 coverage, several where inputs overlap (set_features)
##   feat_start, feat_tri  the triangles of each feature (the same, inverted)
## Every function returns what the ST_* function returns per feature.
## Point location is cdtr::cdt_locate(), the dissolve wkpool::tri_dissolve(),
## overlay polymer::polymer(); geos does what a mesh cannot (fallback).

## ---- the mesh ----

## from a polymer of one or more layers; features are numbered across
## layers in order (layer 1 first)
mesh_from_polymer <- function(pm) {
  v <- wkpool::pool_vertices(pm$mesh)
  tr <- wkpool::pool_triangles(pm$mesh)
  row <- match(c(tr$.vx0, tr$.vx1, tr$.vx2), v$.vx)
  nt <- nrow(tr)
  ix <- pm$index
  n_layer <- vapply(pm$layers, nrow, 1L)
  offset <- c(0L, cumsum(n_layer))[ix$layer]
  f <- ix$feature + offset
  o <- order(ix$triangle, f)
  tri <- ix$triangle[o]; f <- f[o]
  mem_start <- c(1L, cumsum(tabulate(tri, nt)) + 1L)
  nf <- sum(n_layer)
  o2 <- order(f, tri)
  feat_start <- c(1L, cumsum(tabulate(f, nf)) + 1L)
  v0 <- row[seq_len(nt)]; v1 <- row[nt + seq_len(nt)]; v2 <- row[2 * nt + seq_len(nt)]
  structure(list(
    x = v$x, y = v$y, v0 = v0, v1 = v1, v2 = v2,
    ## the edge table E, derived once (spec: "edges derived from T in one sort")
    nbr = mesh_neighbours_c(v0, v1, v2, nrow(v)),
    mem_start = as.integer(mem_start), mem = as.integer(f),
    feat_start = as.integer(feat_start), feat_tri = as.integer(tri[o2]),
    n_feature = nf, n_layer = n_layer,
    ## coverage convenience: the single feature of each triangle (NA if 0 or > 1)
    feature = ifelse(diff(mem_start) == 1L, f[pmin(mem_start[-(nt + 1)], length(f))], NA_integer_),
    pool = pm$mesh, set_id = pm$set_id, crs = pm$crs
  ), class = "st_mesh")
}

## triangle -> feature long form (repeats triangles that are in several)
mem_tri <- function(m) rep(seq_along(m$v0), diff(m$mem_start))

## ---- native: closed form per triangle, then a group reduction ----

tri_area <- function(m) {
  x0 <- m$x[m$v0]; y0 <- m$y[m$v0]
  0.5 * ((m$x[m$v1] - x0) * (m$y[m$v2] - y0) - (m$x[m$v2] - x0) * (m$y[m$v1] - y0))
}

by_feature <- function(m, value) {
  t <- mem_tri(m)
  out <- numeric(m$n_feature)
  s <- rowsum(value[t], m$mem, reorder = TRUE)
  out[as.integer(rownames(s))] <- s[, 1]
  out
}

mesh_area <- function(m) by_feature(m, tri_area(m))

mesh_centroid <- function(m) {
  a <- tri_area(m)
  cx <- (m$x[m$v0] + m$x[m$v1] + m$x[m$v2]) / 3
  cy <- (m$y[m$v0] + m$y[m$v1] + m$y[m$v2]) / 3
  A <- by_feature(m, a)
  cbind(x = by_feature(m, a * cx) / A, y = by_feature(m, a * cy) / A)
}

## centroid of the feature's largest triangle: inside by construction
mesh_point_on_surface <- function(m) {
  t <- mem_tri(m); f <- m$mem
  a <- tri_area(m)[t]
  o <- order(f, -a)
  first <- o[!duplicated(f[o])]
  tt <- t[first]
  out <- matrix(NA_real_, m$n_feature, 2, dimnames = list(NULL, c("x", "y")))
  out[f[first], "x"] <- (m$x[m$v0[tt]] + m$x[m$v1[tt]] + m$x[m$v2[tt]]) / 3
  out[f[first], "y"] <- (m$y[m$v0[tt]] + m$y[m$v1[tt]] + m$y[m$v2[tt]]) / 3
  out
}

mesh_envelope <- function(m) {
  mesh_envelope_c(m$x, m$y, m$v0, m$v1, m$v2, m$mem_start, m$mem, m$n_feature)
}

## per triangle: non-degenerate and counter-clockwise. A feature built by a
## constrained triangulation is valid by construction; this is the one pass
## a consumer that cannot trust the producer would run.
mesh_is_valid <- function(m) {
  ok <- tri_area(m) > 0
  as.logical(rowsum(as.integer(!ok[mem_tri(m)]), m$mem, reorder = TRUE)[, 1] == 0)
}

## ST_Affine / ST_Transform: the dictionary only
mesh_affine <- function(m, trans) {
  xy <- wk::wk_transform(wk::xy(m$x, m$y), trans)
  m$x <- unclass(xy)$x; m$y <- unclass(xy)$y
  m
}

## ---- combinatorial: indices only ----

## boundary edges (feature, from, to), interior on the left
mesh_boundary_edges <- function(m, once = FALSE) {
  mesh_boundary_c(m$v0, m$v1, m$v2, length(m$x), m$nbr, m$mem_start, m$mem, once)
}

## ST_Perimeter: boundary edge lengths
mesh_perimeter <- function(m) {
  b <- mesh_boundary_edges(m)
  len <- sqrt((m$x[b[, 3]] - m$x[b[, 2]])^2 + (m$y[b[, 3]] - m$y[b[, 2]])^2)
  out <- numeric(m$n_feature)
  s <- rowsum(len, b[, 1], reorder = TRUE)
  out[as.integer(rownames(s))] <- s[, 1]
  out
}

## ST_Boundary as lines, every shared edge once: a MULTILINESTRING of
## two-point segments per feature (merging into longer lines is wkpool's
## arc-node work and is not timed here)
mesh_boundary <- function(m, once = TRUE) {
  b <- mesh_boundary_edges(m, once = once)
  n <- nrow(b)
  seg <- rep(seq_len(n), each = 2)
  vx <- as.vector(rbind(b[, 2], b[, 3]))
  wk::wk_linestring(wk::xy(m$x[vx], m$y[vx]), feature_id = seg)
}

## The dissolve back to features: wkpool's compiled walk. For a coverage
## the group is the feature; overlapping features need one dissolve each.
mesh_union <- function(m, group) {
  stopifnot(all(diff(m$mem_start) <= 1L))
  wkpool::tri_dissolve(m$pool, group[m$feature])
}

## ST_NumGeometries and ST_NumInteriorRings from the rings of the dissolve
## (outer rings are counter-clockwise, holes clockwise)
mesh_num_parts <- function(m) {
  d <- mesh_union(m, seq_len(m$n_feature))
  meta <- wk::wk_meta(d)
  co <- wk::wk_coords(d)
  ring <- paste(co$feature_id, co$part_id, co$ring_id)
  first_ring <- !duplicated(co[c("feature_id", "part_id")])
  r1 <- !duplicated(ring)
  holes <- tabulate(co$feature_id[r1], m$n_feature) - tabulate(co$feature_id[first_ring & r1], m$n_feature)
  cbind(parts = meta$size, holes = holes)
}

## ST_Relate (full DE-9IM) for pairs of features of one mesh
mesh_relate <- function(m, a, b) {
  mesh_relate_c(m$v0, m$v1, m$v2, length(m$x), m$nbr, m$mem_start, m$mem,
                m$feat_start, m$feat_tri, as.integer(a), as.integer(b))
}

## every pair that is not disjoint shares a vertex: the candidates
mesh_vertex_pairs <- function(m) {
  mesh_vertex_pairs_c(m$v0, m$v1, m$v2, m$mem_start, m$mem)
}

## ST_Touches for all features: pairs sharing a vertex but no triangle
## (II = F); in a coverage that is every vertex pair
mesh_touches <- function(m) {
  p <- mesh_vertex_pairs(m)
  r <- mesh_relate(m, p[, 1], p[, 2])
  p <- p[substr(r, 1, 1) == "F", , drop = FALSE]
  both <- rbind(p, p[, 2:1])
  unname(split(both[, 2], factor(both[, 1], levels = seq_len(m$n_feature))))
}

## ---- near-native: one more structure ----

## ST_Intersects(point, feature) for many points: cdtr's locator, then the
## triangle's feature
mesh_locate <- function(m, px, py) {
  t <- cdtr::cdt_locate(cbind(m$x, m$y), cbind(m$v0, m$v1, m$v2), px, py)
  m$feature[t]
}

## ST_Distance(point, feature): 0 inside, else nearest boundary edge
mesh_distance <- function(m, px, py, f) {
  b <- mesh_boundary_edges(m)
  b <- b[b[, 1] == f, , drop = FALSE]
  inside <- mesh_locate(m, px, py)
  inside <- !is.na(inside) & inside == f
  mesh_distance_c(px, py, inside, m$x[b[, 2]], m$y[b[, 2]], m$x[b[, 3]], m$y[b[, 3]])
}

## the same with a grid over the boundary edges (built per call)
mesh_distance_grid <- function(m, px, py, f) {
  b <- mesh_boundary_edges(m)
  b <- b[b[, 1] == f, , drop = FALSE]
  inside <- mesh_locate(m, px, py)
  inside <- !is.na(inside) & inside == f
  mesh_distance_grid_c(px, py, inside, m$x[b[, 2]], m$y[b[, 2]], m$x[b[, 3]], m$y[b[, 3]])
}

mesh_convex_hull_area_c <- function(m) {
  mesh_hull_area_c(m$x, m$y, m$v0, m$v1, m$v2, m$feat_start, m$feat_tri, m$n_feature)
}

## ST_ClipByBox2D: a mesh again, plus the area per feature
mesh_clip_box <- function(m, box) {
  r <- mesh_clip_box_c(m$x, m$y, m$v0, m$v1, m$v2, box[[1]], box[[2]], box[[3]], box[[4]])
  a <- 0.5 * ((r[, 4] - r[, 2]) * (r[, 7] - r[, 3]) - (r[, 6] - r[, 2]) * (r[, 5] - r[, 3]))
  f <- m$feature[r[, 1]]
  area <- numeric(m$n_feature)
  s <- rowsum(a, f, reorder = TRUE)
  area[as.integer(rownames(s))] <- s[, 1]
  list(triangles = r, feature = f, area = area)
}

## ST_ConvexHull per feature: hull of the feature's boundary vertices
mesh_convex_hull_area <- function(m) {
  b <- mesh_boundary_edges(m)
  vf <- split(b[, 2], b[, 1])
  out <- numeric(m$n_feature)
  out[as.integer(names(vf))] <- vapply(vf, function(v) {
    v <- unique(v)
    h <- v[grDevices::chull(m$x[v], m$y[v])]
    x <- m$x[h]; y <- m$y[h]
    j <- c(seq_along(x)[-1], 1L)
    abs(sum(x * y[j] - x[j] * y)) / 2
  }, 0)
  out
}

## ---- fallback: dissolve, then geos ----

mesh_fallback <- function(m, op, ...) {
  op(geos::as_geos_geometry(mesh_union(m, seq_len(m$n_feature))), ...)
}

## ---- compiled versions of the native measures (st_mesh.cpp) ----
mesh_measures <- function(m, perimeter = FALSE) {
  r <- mesh_measures_c(m$x, m$y, m$v0, m$v1, m$v2, m$nbr, m$mem_start, m$mem, m$n_feature, perimeter)
  colnames(r) <- c("area", "cx", "cy", "px", "py", "perimeter")
  r
}
mesh_area_c <- function(m) mesh_measures(m)[, "area"]
mesh_centroid_c <- function(m) mesh_measures(m)[, c("cx", "cy")]
mesh_point_on_surface_c <- function(m) mesh_measures(m)[, c("px", "py")]
mesh_perimeter_c <- function(m) mesh_measures(m, perimeter = TRUE)[, "perimeter"]

## parts and holes straight from wkpool's ring kernel, without building WKB
mesh_num_parts_c <- function(m) {
  stopifnot(all(diff(m$mem_start) <= 1L))
  ok <- !is.na(m$feature)
  r <- wkpool:::dissolve_rings(m$v0[ok], m$v1[ok], m$v2[ok], m$feature[ok], m$x, m$y)
  first <- !duplicated(r$ring)
  pf <- r$group[first & !duplicated(r$poly)]
  rings <- tabulate(r$group[first], m$n_feature)
  parts <- tabulate(pf, m$n_feature)
  cbind(parts = parts, holes = rings - parts)
}
