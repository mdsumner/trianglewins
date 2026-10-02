## Example interfaces: real-world geometry in, constrained meshes out.
##
## Not a package. source() this file to get the functions; it needs wk, and
## whichever of cdtr, laridae, trowel, RTriangle you want to mesh with.
## The guide that goes with it is guide/README.md.
##
## The shape of it:
##
##   handleable --pslg_from_wk()--> pslg --tri_mesh()--> tri --tri_as_wk()--> wkb
##                                    |                    |
##                              pslg_split()          tri_faces(), tri_features()
##
## pslg  a list of plain tables (the contract the three meshers share):
##   vertices  x, y, and z / m when the geometry has them, plus any per-vertex
##             attribute columns; one row per distinct (x, y)
##   segments  s0, s1 (rows of vertices), path, edge: one row per input
##             segment, in the order the geometry gave them
##   edges     e0, e1 (rows of vertices, e0 < e1), count: one row per distinct
##             undirected edge, count = how many input segments lie on it
##   paths     path, feature, part, ring, role ("shell", "hole", "line",
##             "point"), n (vertices on the path)
##   features  feature, plus the non-geometry columns of the input
##   crs       whatever wk::wk_crs() said
##
## tri   the mesh, the same whichever backend made it:
##   vertices   x, y, attribute columns, origin ("input" or "added", or the
##              backend's own "crossing" / "steiner" when it reports them)
##   triangles  v0, v1, v2 (rows of vertices), depth (the backend's own; NA
##              for RTriangle)
##   constraint v0, v1: mesh edges that lie on an input edge
##   backend, crs, pslg (the input it was made from), unrefined, time

# ---------------------------------------------------------------- input --

#' wk handleable -> pslg
#'
#' @param handleable anything wk can handle: wkb, wkt, sf / sfc, geos,
#'   s2, a data frame with one geometry column, wk::xy, ...
#' @param attr optional per-vertex attributes: a function of the vertex table
#'   (x, y, z, ...) returning a data frame of new columns, applied after
#'   deduplication (e.g. function(v) data.frame(elev = dem_lookup(v$x, v$y)))
#' @param snap round coordinates to this grid before deduplicating (0 = exact
#'   match only); real layers often have near-coincident vertices that should
#'   be one
pslg_from_wk <- function(handleable, attr = NULL, snap = 0) {
  geom <- if (is.data.frame(handleable)) handleable[[wk_geom_col(handleable)]] else handleable
  co <- wk::wk_coords(geom)
  meta <- wk::wk_meta(geom)
  gt <- meta$geometry_type[co$feature_id]
  if (snap > 0) {
    co$x <- round(co$x / snap) * snap
    co$y <- round(co$y / snap) * snap
  }

  ## a path is one run of coordinates: a ring, a linestring, a point
  pkey <- paste(co$feature_id, co$part_id, co$ring_id)
  path <- match(pkey, unique(pkey))
  first <- !duplicated(path)
  last <- !duplicated(path, fromLast = TRUE)
  npath <- tabulate(path)
  is_ring <- gt %in% c(3L, 6L)
  ## WKB rings repeat their first coordinate: drop it, the closing segment
  ## is added back below
  keep <- !(last & is_ring & npath[path] > 1L)
  co <- co[keep, , drop = FALSE]
  path <- path[keep]; is_ring <- is_ring[keep]; gt <- gt[keep]
  first <- !duplicated(path); last <- !duplicated(path, fromLast = TRUE)

  ## paths table; for polygons the first ring of each part is the shell
  pp <- co[first, c("feature_id", "part_id", "ring_id")]
  role <- ifelse(gt[first] %in% c(3L, 6L),
                 ifelse(!duplicated(paste(pp$feature_id, pp$part_id)), "shell", "hole"),
                 ifelse(gt[first] %in% c(1L, 4L), "point", "line"))
  paths <- data.frame(path = seq_len(nrow(pp)), feature = pp$feature_id, part = pp$part_id,
                      ring = pp$ring_id, role = role, n = tabulate(path))

  ## vertices: one row per distinct (x, y); z and m keep the first value seen
  key <- paste(co$x, co$y)
  u <- !duplicated(key)
  vid <- match(key, key[u])
  vertices <- data.frame(x = co$x[u], y = co$y[u])
  for (zm in intersect(c("z", "m"), names(co))) {
    if (any(is.finite(co[[zm]]))) vertices[[zm]] <- co[[zm]][u]
  }

  ## segments: consecutive vertices along each path, closing segment for rings
  i <- which(!last)
  s0 <- vid[i]; s1 <- vid[i + 1L]; sp <- path[i]
  ring_end <- which(last & is_ring)
  if (length(ring_end)) {
    ring_start <- which(first)[match(path[ring_end], path[first])]
    s0 <- c(s0, vid[ring_end]); s1 <- c(s1, vid[ring_start]); sp <- c(sp, path[ring_end])
  }
  o <- order(sp)
  s0 <- s0[o]; s1 <- s1[o]; sp <- sp[o]
  ok <- s0 != s1      ## repeated consecutive coordinates
  s0 <- s0[ok]; s1 <- s1[ok]; sp <- sp[ok]

  ekey <- paste(pmin(s0, s1), pmax(s0, s1))
  ue <- !duplicated(ekey)
  edge <- match(ekey, ekey[ue])
  edges <- data.frame(e0 = pmin(s0, s1)[ue], e1 = pmax(s0, s1)[ue], count = tabulate(edge))
  segments <- data.frame(s0 = s0, s1 = s1, path = sp, edge = edge)

  features <- data.frame(feature = seq_along(geom))
  if (is.data.frame(handleable)) {
    a <- as.data.frame(handleable)[setdiff(names(handleable), wk_geom_col(handleable))]
    features <- cbind(features, a)
  }
  if (is.function(attr)) vertices <- cbind(vertices, attr(vertices))

  structure(list(vertices = vertices, segments = segments, edges = edges,
                 paths = paths, features = features, crs = wk::wk_crs(geom)),
            class = "pslg")
}

wk_geom_col <- function(x) {
  is_geom <- vapply(x, function(col) wk::is_handleable(col), TRUE)
  if (!any(is_geom)) stop("no geometry column")
  names(x)[which(is_geom)[1L]]
}

print.pslg <- function(x, ...) {
  cat(sprintf("<pslg> %d vertices, %d segments (%d distinct edges, %d shared), %d paths, %d features\n",
              nrow(x$vertices), nrow(x$segments), nrow(x$edges), sum(x$edges$count > 1L),
              nrow(x$paths), nrow(x$features)))
  cat("  roles:", paste(names(table(x$paths$role)), table(x$paths$role), collapse = ", "), "\n")
  if (ncol(x$vertices) > 2L) cat("  vertex attributes:", paste(names(x$vertices)[-(1:2)], collapse = ", "), "\n")
  invisible(x)
}

#' Split a pslg into one pslg per group of features (default: one per
#' feature). Features that share no boundary can be meshed independently,
#' in parallel, and a failure in one does not take out the rest.
pslg_split <- function(p, by = p$features$feature) {
  lapply(split(p$features$feature, by), function(f) pslg_subset(p, f))
}

pslg_subset <- function(p, features) {
  paths <- p$paths[p$paths$feature %in% features, , drop = FALSE]
  seg <- p$segments[p$segments$path %in% paths$path, , drop = FALSE]
  ## vertices used by the paths: segments for rings and lines, plus lone
  ## points (paths of one vertex have no segments, so they are found by
  ## re-running from the original vertex use, which a pslg does not keep;
  ## points-only features are dropped here)
  v <- sort(unique(c(seg$s0, seg$s1)))
  map <- match(seq_len(nrow(p$vertices)), v)
  seg$s0 <- map[seg$s0]; seg$s1 <- map[seg$s1]
  ekey <- paste(pmin(seg$s0, seg$s1), pmax(seg$s0, seg$s1))
  ue <- !duplicated(ekey)
  seg$edge <- match(ekey, ekey[ue])
  structure(list(vertices = p$vertices[v, , drop = FALSE],
                 segments = seg,
                 edges = data.frame(e0 = pmin(seg$s0, seg$s1)[ue], e1 = pmax(seg$s0, seg$s1)[ue],
                                    count = tabulate(seg$edge)),
                 paths = paths, features = p$features[p$features$feature %in% features, , drop = FALSE],
                 crs = p$crs), class = "pslg")
}

## a column of the paths table for path ids (ids survive pslg_subset(), row
## positions do not)
path_info <- function(p, path, column) p$paths[[column]][match(path, p$paths$path)]

#' Area enclosed by the polygon paths (shells minus holes), in CRS units
pslg_area <- function(p) {
  s <- p$segments[path_info(p, p$segments$path, "role") %in% c("shell", "hole"), , drop = FALSE]
  v <- p$vertices
  a <- tapply(v$x[s$s0] * v$y[s$s1] - v$x[s$s1] * v$y[s$s0], s$path, sum) / 2
  sum(abs(a) * ifelse(path_info(p, as.integer(names(a)), "role") == "hole", -1, 1))
}

#' A max_area that gives roughly n triangles over the polygon area
area_for <- function(p, n) pslg_area(p) / n

# ----------------------------------------------------------------- mesh --

#' pslg -> tri, by any backend
#'
#' @param boundaries "unique": every distinct edge once, so a boundary two
#'   polygons share counts as one crossing for every backend; "as_given": every
#'   input segment, so a doubled boundary reaches the backend twice (laridae
#'   and cdtr then count depth k, trowel 1; that choice is still open)
#' @param region "inside": triangles inside the constraints; "hull": the
#'   convex hull (open linework, points)
#' @param attributes vertex columns carried through and interpolated onto new
#'   vertices (default: everything but x, y)
tri_mesh <- function(p, backend = c("cdtr", "laridae", "trowel", "RTriangle"),
                     max_area = NULL, min_angle = NULL, max_steiner = 1e6,
                     boundaries = c("unique", "as_given"), region = c("inside", "hull"),
                     attributes = setdiff(names(p$vertices), c("x", "y"))) {
  backend <- match.arg(backend)
  boundaries <- match.arg(boundaries)
  region <- match.arg(region)
  if (!nrow(p$segments)) region <- "hull"
  S <- if (boundaries == "unique") cbind(p$edges$e0, p$edges$e1) else cbind(p$segments$s0, p$segments$s1)
  PA <- if (length(attributes)) as.matrix(p$vertices[attributes]) else NULL
  run <- switch(backend, cdtr = tri_cdtr, laridae = tri_laridae,
                trowel = tri_trowel, RTriangle = tri_rtriangle)
  t0 <- proc.time()[["elapsed"]]
  out <- run(p$vertices$x, p$vertices$y, S, PA, max_area, min_angle, max_steiner, region)
  out$time <- proc.time()[["elapsed"]] - t0
  out$backend <- backend
  out$crs <- p$crs
  out$pslg <- p
  structure(out, class = "tri")
}

erase_mode <- function(region) if (region == "inside") "outer" else "hull"

tri_cdtr <- function(x, y, S, PA, max_area, min_angle, max_steiner, region) {
  r <- cdtr::cdt_triangulate_attr(x, y, S[, 1], S[, 2], PA = PA, max_area = max_area,
                                  min_angle = min_angle, max_steiner = max_steiner,
                                  erase = erase_mode(region))
  V <- data.frame(x = r$P[, 1], y = r$P[, 2])
  if (!is.null(PA)) V <- cbind(V, as.data.frame(as.matrix(r$PA)))
  V$origin <- ifelse(seq_len(nrow(V)) <= r$n_input, "input", "added")
  list(vertices = V,
       triangles = data.frame(v0 = r$T[, 1], v1 = r$T[, 2], v2 = r$T[, 3], depth = r$depth),
       constraint = data.frame(v0 = r$S[, 1], v1 = r$S[, 2]),
       unrefined = r$unrefined)
}

tri_laridae <- function(x, y, S, PA, max_area, min_angle, max_steiner, region) {
  r <- laridae::lari_triangulate(x, y, S[, 1], S[, 2], PA = PA, max_area = max_area,
                                 min_angle = min_angle, max_steiner = max_steiner,
                                 erase = erase_mode(region))
  list(vertices = r$vertices[setdiff(names(r$vertices), "id")],
       triangles = r$triangles,
       constraint = r$segments[c("v0", "v1")],
       unrefined = r$unrefined)
}

tri_trowel <- function(x, y, S, PA, max_area, min_angle, max_steiner, region) {
  m <- trowel::mesh_new(x, y, S[, 1], S[, 2], PA = PA)
  unref <- NULL
  if (!is.null(max_area) || !is.null(min_angle)) {
    res <- trowel::mesh_refine(m, min_angle = min_angle, max_area = max_area,
                               max_steiner = max_steiner, inner_only = region == "inside")
    unref <- data.frame(complete = isTRUE(res$complete))
  }
  V <- trowel::mesh_vertices(m)
  Tr <- trowel::mesh_triangles(m)
  if (region == "inside") Tr <- Tr[Tr$depth > 0, , drop = FALSE]
  E <- trowel::mesh_constraint_edges(m)
  list(vertices = V[setdiff(names(V), "id")],
       triangles = data.frame(v0 = match(Tr$v0, V$id), v1 = match(Tr$v1, V$id),
                              v2 = match(Tr$v2, V$id), depth = Tr$depth),
       constraint = data.frame(v0 = match(E$a, V$id), v1 = match(E$b, V$id)),
       unrefined = unref)
}

tri_rtriangle <- function(x, y, S, PA, max_area, min_angle, max_steiner, region) {
  P <- cbind(x, y)
  if (region == "hull") {
    h <- grDevices::chull(P)
    S <- rbind(S, cbind(h, c(h[-1L], h[1L])))
  }
  p <- if (is.null(PA)) RTriangle::pslg(P = P, S = S) else RTriangle::pslg(P = P, S = S, PA = PA)
  args <- list(p, S = max_steiner)
  if (!is.null(max_area)) args$a <- max_area
  if (!is.null(min_angle)) args$q <- min_angle
  r <- do.call(RTriangle::triangulate, args)
  V <- data.frame(x = r$P[, 1], y = r$P[, 2])
  if (!is.null(PA)) V <- cbind(V, stats::setNames(as.data.frame(r$PA), colnames(PA)))
  V$origin <- ifelse(seq_len(nrow(V)) <= length(x), "input", "added")
  list(vertices = V,
       triangles = data.frame(v0 = r$T[, 1], v1 = r$T[, 2], v2 = r$T[, 3],
                              depth = rep(NA_integer_, nrow(r$T))),
       constraint = data.frame(v0 = r$S[, 1], v1 = r$S[, 2]),
       unrefined = NULL)
}

print.tri <- function(x, ...) {
  v <- x$vertices; tr <- x$triangles
  cat(sprintf("<tri> %s: %d vertices (%s), %d triangles, %.3f s\n", x$backend, nrow(v),
              paste(names(table(v$origin)), table(v$origin), collapse = " "), nrow(tr), x$time))
  if (!all(is.na(tr$depth))) cat("  depth:", paste(names(table(tr$depth)), table(tr$depth), sep = "=", collapse = " "), "\n")
  invisible(x)
}

# --------------------------------------------------------------- labels --

## triangle adjacency across edges that are not constraints: two columns of
## triangle rows
tri_adjacent <- function(tr, constraint, nv) {
  a <- c(tr$v0, tr$v1, tr$v2); b <- c(tr$v1, tr$v2, tr$v0)
  tid <- rep(seq_len(nrow(tr)), 3L)
  ekey <- pmin(a, b) * (nv + 1) + pmax(a, b)
  ckey <- pmin(constraint$v0, constraint$v1) * (nv + 1) + pmax(constraint$v0, constraint$v1)
  o <- order(ekey)
  ek <- ekey[o]; tt <- tid[o]
  pair <- which(ek[-1L] == ek[-length(ek)])
  keep <- !(ek[pair] %in% ckey)
  cbind(tt[pair][keep], tt[pair + 1L][keep])
}

## connected components: hook each root to the smallest neighbouring root,
## then pointer-jump until every label is a root; repeat until no edge joins
## two labels
components <- function(n, adj) {
  lab <- seq_len(n)
  repeat {
    ra <- lab[adj[, 1]]; rb <- lab[adj[, 2]]
    d <- ra != rb
    if (!any(d)) break
    hi <- pmax(ra[d], rb[d]); lo <- pmin(ra[d], rb[d])
    o <- order(lo, decreasing = TRUE)
    lab[hi[o]] <- lo[o]     ## the last write, the smallest, wins
    repeat { nl <- lab[lab]; if (identical(nl, lab)) break; lab <- nl }
  }
  match(lab, unique(lab))
}

#' Faces: maximal sets of triangles connected without crossing a constraint.
#' Every triangle in a face is covered by the same set of input polygons, so
#' labelling needs one test per face, not one per triangle.
tri_faces <- function(m) {
  tr <- m$triangles
  components(nrow(tr), tri_adjacent(tr, m$constraint, nrow(m$vertices)))
}

#' Which input features cover each face: a long table (face, feature). A face
#' covered by no feature is absent; an overlap gives several rows. Decided by
#' even-odd crossings of one interior point per face against each feature's
#' own rings, so it works for coverages, holes, overlaps and multipolygons,
#' and never consults depth.
tri_features <- function(m, face = tri_faces(m)) {
  p <- m$pslg
  V <- m$vertices; tr <- m$triangles
  ## centroid of the face's largest triangle: inside the face, away from edges
  ar <- abs(tri_area(V, tr))
  rep_tri <- tapply(seq_len(nrow(tr)), face, function(i) i[which.max(ar[i])])
  px <- (V$x[tr$v0[rep_tri]] + V$x[tr$v1[rep_tri]] + V$x[tr$v2[rep_tri]]) / 3
  py <- (V$y[tr$v0[rep_tri]] + V$y[tr$v1[rep_tri]] + V$y[tr$v2[rep_tri]]) / 3
  s <- p$segments[path_info(p, p$segments$path, "role") %in% c("shell", "hole"), , drop = FALSE]
  if (!nrow(s)) return(data.frame(face = integer(0), feature = integer(0)))
  x0 <- p$vertices$x[s$s0]; y0 <- p$vertices$y[s$s0]
  x1 <- p$vertices$x[s$s1]; y1 <- p$vertices$y[s$s1]
  sf <- path_info(p, s$path, "feature")
  out <- lapply(seq_along(px), function(k) {
    straddle <- (y0 > py[k]) != (y1 > py[k])
    xc <- x0[straddle] + (py[k] - y0[straddle]) * (x1[straddle] - x0[straddle]) / (y1[straddle] - y0[straddle])
    hit <- tabulate(match(sf[straddle][xc > px[k]], unique(sf)), length(unique(sf)))
    f <- unique(sf)[hit %% 2L == 1L]
    if (length(f)) data.frame(face = k, feature = f) else NULL
  })
  do.call(rbind, out)
}

tri_area <- function(V, tr) {
  ((V$x[tr$v1] - V$x[tr$v0]) * (V$y[tr$v2] - V$y[tr$v0]) -
     (V$x[tr$v2] - V$x[tr$v0]) * (V$y[tr$v1] - V$y[tr$v0])) / 2
}

#' Triangle table with face, feature and the feature attributes joined on.
#' Where features overlap the triangle appears once per covering feature.
tri_label <- function(m) {
  tr <- m$triangles
  tr$triangle <- seq_len(nrow(tr))
  tr$face <- tri_faces(m)
  ff <- tri_features(m, tr$face)
  out <- merge(tr, ff, by = "face", all.x = TRUE, sort = FALSE)
  out <- merge(out, m$pslg$features, by = "feature", all.x = TRUE, sort = FALSE)
  out[order(out$triangle), c("triangle", "v0", "v1", "v2", "depth", "face", "feature",
                             setdiff(names(m$pslg$features), "feature"))]
}

# --------------------------------------------------------------- output --

#' tri -> wkb triangles (polygons), with a data frame of columns alongside
tri_as_wk <- function(m, labels = NULL) {
  V <- m$vertices
  tr <- if (is.null(labels)) m$triangles else labels
  n <- nrow(tr)
  idx <- as.vector(rbind(tr$v0, tr$v1, tr$v2))
  geom <- wk::wk_polygon(wk::xy(V$x[idx], V$y[idx], crs = m$crs),
                         feature_id = rep(seq_len(n), each = 3L))
  out <- as.data.frame(tr[setdiff(names(tr), c("v0", "v1", "v2"))])
  out$geometry <- geom
  out
}

#' tri -> wkb linestrings, one per mesh edge, with constraint = TRUE on edges
#' that lie on an input boundary
tri_edges_wk <- function(m) {
  V <- m$vertices; tr <- m$triangles; nv <- nrow(V)
  a <- c(tr$v0, tr$v1, tr$v2); b <- c(tr$v1, tr$v2, tr$v0)
  k <- pmin(a, b) * (nv + 1) + pmax(a, b)
  u <- !duplicated(k)
  e0 <- pmin(a, b)[u]; e1 <- pmax(a, b)[u]
  ck <- pmin(m$constraint$v0, m$constraint$v1) * (nv + 1) + pmax(m$constraint$v0, m$constraint$v1)
  idx <- as.vector(rbind(e0, e1))
  data.frame(constraint = k[u] %in% ck,
             geometry = wk::wk_linestring(wk::xy(V$x[idx], V$y[idx], crs = m$crs),
                                          feature_id = rep(seq_along(e0), each = 2L)))
}

#' Interpolate the mesh's vertex attributes at query points (linear within
#' the containing triangle; NA outside the mesh). Brute force over a bbox
#' prefilter: fine for thousands of points, use a backend locator for more.
tri_interpolate <- function(m, x, y, columns = setdiff(names(m$vertices), c("x", "y", "origin"))) {
  V <- m$vertices; tr <- m$triangles
  x0 <- V$x[tr$v0]; y0 <- V$y[tr$v0]; x1 <- V$x[tr$v1]; y1 <- V$y[tr$v1]
  x2 <- V$x[tr$v2]; y2 <- V$y[tr$v2]
  d <- (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
  out <- matrix(NA_real_, length(x), length(columns), dimnames = list(NULL, columns))
  for (i in seq_along(x)) {
    l0 <- ((y1 - y2) * (x[i] - x2) + (x2 - x1) * (y[i] - y2)) / d
    l1 <- ((y2 - y0) * (x[i] - x2) + (x0 - x2) * (y[i] - y2)) / d
    l2 <- 1 - l0 - l1
    k <- which(l0 >= -1e-12 & l1 >= -1e-12 & l2 >= -1e-12)[1L]
    if (is.na(k)) next
    for (cc in columns) {
      out[i, cc] <- l0[k] * V[[cc]][tr$v0[k]] + l1[k] * V[[cc]][tr$v1[k]] + l2[k] * V[[cc]][tr$v2[k]]
    }
  }
  as.data.frame(out)
}

plot.tri <- function(x, col = NA, border = "grey60", constraint = "black", ...) {
  V <- x$vertices; tr <- x$triangles
  plot(V$x, V$y, type = "n", asp = 1, axes = FALSE, xlab = "", ylab = "", ...)
  xx <- rbind(V$x[tr$v0], V$x[tr$v1], V$x[tr$v2], NA)
  yy <- rbind(V$y[tr$v0], V$y[tr$v1], V$y[tr$v2], NA)
  graphics::polygon(as.vector(xx), as.vector(yy), col = col, border = border, lwd = 0.3)
  if (!is.null(constraint)) {
    cs <- x$constraint
    graphics::segments(V$x[cs$v0], V$y[cs$v0], V$x[cs$v1], V$y[cs$v1], col = constraint, lwd = 0.6)
  }
  invisible(x)
}
