## Mesh-native versions of a few ST_* functions, for the dev draft
## "ST_* functions on a triangle mesh". Base R only (plus wkpool for the
## dissolve), vectorised over triangles; no compiled code of our own.
##
## A mesh here is the triangle form of the hypertidy mesh spec, reduced to
## what these functions read:
##   x, y          vertex coordinates (the dictionary of geoarrow.triangles)
##   v0, v1, v2    1-based vertex rows per triangle, counter-clockwise
##   feature       covering feature per triangle (a coverage: one each), or
##   set_id + set_features  for overlapping inputs (spec v0.2 Annex A)
## Every function takes the mesh and returns what the ST_* function returns
## for each feature, so the triangles never have to be thought about.

mesh_from_polymer <- function(pm) {
  v <- wkpool::pool_vertices(pm$mesh)
  tr <- wkpool::pool_triangles(pm$mesh)
  ## pool ids to rows
  row <- match(c(tr$.vx0, tr$.vx1, tr$.vx2), v$.vx)
  nt <- nrow(tr)
  ix <- pm$index
  ## coverage case: one feature per triangle
  feat <- rep(NA_integer_, nt)
  feat[ix$triangle] <- ix$feature
  structure(list(
    x = v$x, y = v$y,
    v0 = row[seq_len(nt)], v1 = row[nt + seq_len(nt)], v2 = row[2 * nt + seq_len(nt)],
    feature = feat,
    n_feature = nrow(pm$layers[[1]]),
    set_id = pm$set_id,
    pool = pm$mesh
  ), class = "st_mesh")
}

## per-triangle signed area (positive for counter-clockwise)
tri_area <- function(m) {
  x0 <- m$x[m$v0]; y0 <- m$y[m$v0]
  0.5 * ((m$x[m$v1] - x0) * (m$y[m$v2] - y0) - (m$x[m$v2] - x0) * (m$y[m$v1] - y0))
}

## sum a per-triangle value by feature, keeping features with no triangles
by_feature <- function(m, value) {
  out <- numeric(m$n_feature)
  s <- rowsum(value, m$feature, reorder = TRUE)
  out[as.integer(rownames(s))] <- s[, 1]
  out
}

## ST_Area: a sum of triangle areas
mesh_area <- function(m) by_feature(m, tri_area(m))

## ST_Centroid: area-weighted mean of triangle centroids
mesh_centroid <- function(m) {
  a <- tri_area(m)
  cx <- (m$x[m$v0] + m$x[m$v1] + m$x[m$v2]) / 3
  cy <- (m$y[m$v0] + m$y[m$v1] + m$y[m$v2]) / 3
  A <- by_feature(m, a)
  cbind(x = by_feature(m, a * cx) / A, y = by_feature(m, a * cy) / A)
}

## ST_PointOnSurface: the centroid of the feature's largest triangle, which
## is strictly inside the feature by construction
mesh_point_on_surface <- function(m) {
  a <- tri_area(m)
  o <- order(m$feature, -a)
  first <- o[!duplicated(m$feature[o]) & !is.na(m$feature[o])]
  out <- matrix(NA_real_, m$n_feature, 2, dimnames = list(NULL, c("x", "y")))
  out[m$feature[first], "x"] <- (m$x[m$v0[first]] + m$x[m$v1[first]] + m$x[m$v2[first]]) / 3
  out[m$feature[first], "y"] <- (m$y[m$v0[first]] + m$y[m$v1[first]] + m$y[m$v2[first]]) / 3
  out
}

## ST_Envelope / ST_Extent per feature: min and max over triangle corners
mesh_envelope <- function(m) {
  f <- rep(m$feature, 3)
  vx <- c(m$v0, m$v1, m$v2)
  ok <- !is.na(f)
  xs <- m$x[vx[ok]]; ys <- m$y[vx[ok]]; f <- f[ok]
  ## grouped min and max by sorting once
  rng <- function(v) {
    o <- order(f, v)
    lo <- o[!duplicated(f[o])]
    hi <- rev(o)[!duplicated(f[rev(o)])]
    list(lo = v[lo][order(f[lo])], hi = v[hi][order(f[hi])])
  }
  rx <- rng(xs); ry <- rng(ys)
  cbind(xmin = rx$lo, ymin = ry$lo, xmax = rx$hi, ymax = ry$hi)
}

## undirected edges with the triangle on each side (half-edge pairing)
mesh_edges <- function(m) {
  nt <- length(m$v0)
  a <- c(m$v0, m$v1, m$v2)
  b <- c(m$v1, m$v2, m$v0)
  tri <- rep(seq_len(nt), 3)
  lo <- pmin(a, b); hi <- pmax(a, b)
  key <- (lo - 1) * length(m$x) + hi          # exact in double up to 2^53
  o <- order(key)
  k <- key[o]
  first <- !duplicated(k)
  e <- data.frame(v0 = lo[o][first], v1 = hi[o][first], left = tri[o][first],
                  right = NA_integer_)
  second <- which(!first)
  e$right[match(k[second], k[first])] <- tri[o][second]
  e
}

## ST_Touches for all pairs of features at once (the sparse predicate
## matrix sf returns). Two features of a coverage touch when they share a
## vertex of the mesh; no coordinate is read.
mesh_touches <- function(m) {
  f <- rep(m$feature, 3)
  vx <- c(m$v0, m$v1, m$v2)
  ok <- !is.na(f)
  vf <- unique(data.frame(v = vx[ok], f = f[ok]))
  ## features around each vertex, all pairs
  pairs <- merge(vf, vf, by = "v")
  pairs <- unique(pairs[pairs$f.x != pairs$f.y, c("f.x", "f.y")])
  out <- split(pairs$f.y, factor(pairs$f.x, levels = seq_len(m$n_feature)))
  lapply(out, sort)
}

## The same, but only for features that share an edge (DE-9IM pattern
## F***1****, "rook" adjacency), from the edge table
mesh_edge_neighbours <- function(m) {
  e <- mesh_edges(m)
  e <- e[!is.na(e$right), ]
  fl <- m$feature[e$left]; fr <- m$feature[e$right]
  ok <- !is.na(fl) & !is.na(fr) & fl != fr
  p <- unique(data.frame(a = c(fl[ok], fr[ok]), b = c(fr[ok], fl[ok])))
  lapply(split(p$b, factor(p$a, levels = seq_len(m$n_feature))), sort)
}

## A uniform grid of triangle buckets: the mesh's "prepared" index.
mesh_locator <- function(m, cells_per_triangle = 1) {
  x0 <- m$x[m$v0]; x1 <- m$x[m$v1]; x2 <- m$x[m$v2]
  y0 <- m$y[m$v0]; y1 <- m$y[m$v1]; y2 <- m$y[m$v2]
  xmin <- min(m$x); ymin <- min(m$y)
  w <- max(m$x) - xmin; h <- max(m$y) - ymin
  n <- ceiling(sqrt(length(m$v0) * cells_per_triangle * w / h))
  s <- w / n
  nx <- n; ny <- ceiling(h / s)
  cx <- function(x) pmin(nx - 1L, as.integer((x - xmin) / s))
  cy <- function(y) pmin(ny - 1L, as.integer((y - ymin) / s))
  ix0 <- cx(pmin(x0, x1, x2)); ix1 <- cx(pmax(x0, x1, x2))
  iy0 <- cy(pmin(y0, y1, y2)); iy1 <- cy(pmax(y0, y1, y2))
  ## expand each triangle over the cells its bbox covers
  nxx <- ix1 - ix0 + 1L; nyy <- iy1 - iy0 + 1L
  cnt <- nxx * nyy
  tri <- rep(seq_along(x0), cnt)
  k <- sequence(cnt) - 1L
  cell <- (iy0[tri] + k %/% nxx[tri]) * nx + ix0[tri] + k %% nxx[tri]
  o <- order(cell)
  start <- findInterval(seq_len(nx * ny) - 1L, cell[o], left.open = TRUE) + 1L
  list(tri = tri[o], start = c(start, length(o) + 1L), cx = cx, cy = cy, nx = nx,
       ny = ny, xmin = xmin, ymin = ymin, s = s)
}

## ST_Intersects(point, feature) for many points: the feature each point is
## in (NA outside). Candidates from the grid, then three orientation tests.
mesh_locate <- function(m, px, py, loc = mesh_locator(m)) {
  inside_grid <- px >= loc$xmin & py >= loc$ymin &
    px <= loc$xmin + loc$nx * loc$s & py <= loc$ymin + loc$ny * loc$s
  out <- rep(NA_integer_, length(px))
  pid <- which(inside_grid)
  cell <- loc$cy(py[pid]) * loc$nx + loc$cx(px[pid]) + 1L
  n <- loc$start[cell + 1L] - loc$start[cell]
  p <- rep(pid, n)
  t <- loc$tri[sequence(n, loc$start[cell])]
  orient <- function(a, b) {
    (m$x[b[t]] - m$x[a[t]]) * (py[p] - m$y[a[t]]) - (m$y[b[t]] - m$y[a[t]]) * (px[p] - m$x[a[t]])
  }
  hit <- orient(m$v0, m$v1) >= 0 & orient(m$v1, m$v2) >= 0 & orient(m$v2, m$v0) >= 0
  hit_p <- p[hit]; hit_t <- t[hit]
  keep <- !duplicated(hit_p)
  out[hit_p[keep]] <- m$feature[hit_t[keep]]
  out
}

## ST_Union_Agg grouped (a dissolve): wkpool joins triangles across shared
## edges and walks the boundary edges into rings
mesh_union <- function(m, group) {
  wkpool::tri_dissolve(m$pool, group[m$feature])
}

## ST_Transform: project the vertex pool once; triangles are unchanged
mesh_transform <- function(m, from, to) {
  xy <- sf::sf_project(from, to, cbind(m$x, m$y))
  m$x <- xy[, 1]; m$y <- xy[, 2]
  m
}

## ---- compiled versions (st_mesh.cpp) ----
## cpp11::cpp_source(file.path(dir, "st_mesh.cpp")) defines the *_c functions

mesh_envelope2 <- function(m) {
  mesh_envelope_c(m$x, m$y, m$v0, m$v1, m$v2, m$feature, m$n_feature)
}

mesh_touches2 <- function(m) {
  p <- mesh_touches_c(m$v0, m$v1, m$v2, m$feature, length(m$x))
  ## same shape as sf's sparse predicate: one sorted vector per feature
  unname(split(p[, 2], factor(p[, 1], levels = seq_len(m$n_feature))))
}

mesh_locate2 <- function(m, px, py) {
  mesh_locate_c(m$x, m$y, m$v0, m$v1, m$v2, m$feature, px, py, 1)
}

## dissolve in C++: rings from the mesh, then wk builds the MULTIPOLYGONs
mesh_union2 <- function(m, group) {
  g <- group[m$feature]
  r <- mesh_dissolve_c(m$x, m$y, m$v0, m$v1, m$v2, g, length(m$x))
  poly <- r[, 2]
  pg <- r[!duplicated(poly), 1]
  p <- wk::wk_polygon(wk::xy(m$x[r[, 4]], m$y[r[, 4]]), feature_id = poly, ring_id = r[, 3])
  wk::wk_collection(p, wk::wk_geometry_type("multipolygon"), feature_id = pg)
}
