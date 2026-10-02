## Measures computed from a backend's output tables and the input case only.
## Nothing here calls a backend, so the same code judges all of them.

tri_area <- function(x, y, v0, v1, v2) {
  0.5 * ((x[v1] - x[v0]) * (y[v2] - y[v0]) - (x[v2] - x[v0]) * (y[v1] - y[v0]))
}

tri_min_angle <- function(x, y, v0, v1, v2) {
  l2 <- function(i, j) (x[i] - x[j])^2 + (y[i] - y[j])^2
  ab <- l2(v0, v1); bc <- l2(v1, v2); ca <- l2(v2, v0)
  ang <- function(opp, s1, s2) acos(pmin(1, pmax(-1, (s1 + s2 - opp) / (2 * sqrt(s1 * s2)))))
  pmin(ang(bc, ab, ca), ang(ca, ab, bc), ang(ab, bc, ca)) * 180 / pi
}

## undirected edge key for vertex rows a, b (n vertices)
edge_key <- function(a, b, n) {
  lo <- pmin(a, b); hi <- pmax(a, b)
  as.double(lo) * (n + 1) + hi
}

## every triangle edge once per triangle: tri (row), side, a, b, key, opposite vertex
tri_edges <- function(T, n) {
  v <- cbind(T$v0, T$v1, T$v2)
  nt <- nrow(v)
  a <- c(v[, 1], v[, 2], v[, 3])
  b <- c(v[, 2], v[, 3], v[, 1])
  o <- c(v[, 3], v[, 1], v[, 2])
  data.frame(tri = rep(seq_len(nt), 3), a = a, b = b, opp = o, key = edge_key(a, b, n))
}

## output vertex rows lying on segment (ax, ay)-(bx, by), ordered from a to b.
## xs/ord: the output x coordinates sorted, and the order that sorts them.
vertices_on_segment <- function(x, y, xs, ord, ax, ay, bx, by, tol) {
  lo <- findInterval(min(ax, bx) - tol, xs) + 1L
  hi <- findInterval(max(ax, bx) + tol, xs)
  if (hi < lo) return(integer(0))
  cand <- ord[lo:hi]
  cand <- cand[y[cand] >= min(ay, by) - tol & y[cand] <= max(ay, by) + tol]
  if (!length(cand)) return(integer(0))
  dx <- bx - ax; dy <- by - ay; len <- sqrt(dx * dx + dy * dy)
  if (len == 0) return(integer(0))
  d <- abs((x[cand] - ax) * dy - (y[cand] - ay) * dx) / len
  t <- ((x[cand] - ax) * dx + (y[cand] - ay) * dy) / (len * len)
  keep <- d <= tol & t >= -tol / len & t <= 1 + tol / len
  cand <- cand[keep]; t <- t[keep]
  cand[order(t)]
}

#' Measure a triangulation against its input
#'
#' @param case a case from [tw_case()]
#' @param out backend output: a list with `vertices` (data frame with `x`,
#'   `y`) and `triangles` (data frame with `v0`, `v1`, `v2` as 1-based rows
#'   of `vertices`, and `depth`, which may be NA)
#' @param max_area,min_angle the targets the run asked for (NULL for none)
#' @param tol relative tolerance (times the bounding box diagonal) for
#'   matching vertices to input vertices and segments
#' @return a one-row data frame of measures, and as attributes the harness
#'   depth vectors `depth_k` and `depth_1`
#' @export
tw_measure <- function(case, out, max_area = NULL, min_angle = NULL, tol = 1e-9) {
  V <- out$vertices; T <- out$triangles
  x <- V$x; y <- V$y; n <- length(x); nt <- nrow(T)
  diag <- sqrt(diff(range(case$x))^2 + diff(range(case$y))^2)
  if (!is.finite(diag) || diag == 0) diag <- 1
  tl <- tol * diag

  ## input vertices (exact duplicates collapsed) and where they went
  ukey <- !duplicated(paste(case$x, case$y))
  ix <- case$x[ukey]; iy <- case$y[ukey]
  ord <- order(x); xs <- x[ord]
  in_found <- vapply(seq_along(ix), function(i) {
    lo <- findInterval(ix[i] - tl, xs) + 1L
    hi <- findInterval(ix[i] + tl, xs)
    hi >= lo && any(abs(y[ord[lo:hi]] - iy[i]) <= tl)
  }, TRUE)

  ar <- if (nt) tri_area(x, y, T$v0, T$v1, T$v2) else double(0)
  ma <- if (nt) tri_min_angle(x, y, T$v0, T$v1, T$v2) else double(0)

  E <- tri_edges(T, n)
  ecount <- table(E$key)
  edges_bad <- sum(ecount > 2L)

  ## segment preservation and per-edge input cover count
  covered <- vector("list", length(case$s0))
  seg_ok <- logical(length(case$s0))
  ekeys <- unique(E$key)
  for (k in seq_along(case$s0)) {
    a <- case$s0[k]; b <- case$s1[k]
    if (case$x[a] == case$x[b] && case$y[a] == case$y[b]) { seg_ok[k] <- NA; next }
    on <- vertices_on_segment(x, y, xs, ord, case$x[a], case$y[a], case$x[b], case$y[b], tl)
    if (length(on) < 2L) next
    keys <- edge_key(on[-length(on)], on[-1L], n)
    ends <- c(on[1L], on[length(on)])
    end_ok <- abs(x[ends[1]] - case$x[a]) <= tl && abs(y[ends[1]] - case$y[a]) <= tl &&
      abs(x[ends[2]] - case$x[b]) <= tl && abs(y[ends[2]] - case$y[b]) <= tl
    seg_ok[k] <- end_ok && all(keys %in% ekeys)
    covered[[k]] <- keys
  }
  cover <- table(unlist(covered))
  cover <- stats::setNames(as.numeric(cover), names(cover))
  dk <- harness_depth(E, nt, cover, multiplicity = TRUE)
  d1 <- harness_depth(E, nt, cover, multiplicity = FALSE)

  ## constrained Delaunay: an unconstrained interior edge whose opposite
  ## vertex lies inside the other triangle's circumcircle
  cd_viol <- cdt_violations(x, y, E, cover, diag)

  bd <- T$depth
  has_bd <- !is.null(bd) && length(bd) == nt && !all(is.na(bd))
  depth_match <- if (!has_bd || !nt) NA_character_ else {
    mk <- all(bd == dk); m1 <- all(bd == d1)
    if (mk && m1) "k=1" else if (mk) "k" else if (m1) "1" else "neither"
  }

  data.frame(
    n_vertices = n,
    n_triangles = nt,
    n_added = n - sum(in_found),
    input_missing = sum(!in_found),
    area_total = sum(abs(ar)),
    area_max = if (nt) max(abs(ar)) else NA_real_,
    area_ok = if (is.null(max_area) || !nt) NA_real_ else mean(abs(ar) <= max_area * (1 + 1e-9)),
    angle_min = if (nt) min(ma) else NA_real_,
    angle_ok = if (is.null(min_angle) || !nt) NA_real_ else mean(ma >= min_angle - 1e-6),
    flat = sum(abs(ar) <= 1e-14 * diag^2),
    edges_bad = edges_bad,
    cd_violations = cd_viol,
    segs_kept = if (length(seg_ok)) mean(seg_ok, na.rm = TRUE) else NA_real_,
    depth_backend = if (has_bd) depth_table(bd) else NA_character_,
    depth_k = depth_table(dk),
    depth_1 = depth_table(d1),
    depth_match = depth_match,
    stringsAsFactors = FALSE
  )
}

depth_table <- function(d) {
  if (!length(d)) return("")
  tb <- table(d)
  paste(paste0(names(tb), ":", as.integer(tb)), collapse = " ")
}

## Constraint depth from the output triangles alone: the least total cost of
## a path from outside the mesh to each triangle, where crossing an edge
## costs the number of input segments covering it (multiplicity = TRUE) or 1
## if any does (multiplicity = FALSE). Triangles on the mesh boundary start
## at the cost of their boundary edge.
harness_depth <- function(E, nt, cover, multiplicity = TRUE) {
  if (!nt) return(integer(0))
  w <- cover[as.character(E$key)]
  w[is.na(w)] <- 0
  if (!multiplicity) w <- pmin(w, 1)
  w <- unname(w)
  o <- order(E$key)
  key <- E$key[o]; tri <- E$tri[o]; w <- w[o]
  first <- !duplicated(key)
  last <- !duplicated(key, fromLast = TRUE)
  boundary <- first & last
  pair <- which(first & !last)  ## interior edges: rows pair and pair + 1
  a <- tri[pair]; b <- tri[pair + 1L]; wp <- w[pair]
  d <- rep(Inf, nt)
  bt <- tri[boundary]; bw <- w[boundary]
  ob <- order(-bw)
  d[bt[ob]] <- bw[ob]                   ## smallest boundary cost wins
  repeat {
    ca <- d[a] + wp; cb <- d[b] + wp
    to <- c(b, a); cand <- c(ca, cb)
    better <- cand < d[to]
    if (!any(better)) break
    to <- to[better]; cand <- cand[better]
    oc <- order(-cand)
    d[to[oc]] <- cand[oc]
  }
  as.integer(d)
}

cdt_violations <- function(x, y, E, cover, diag) {
  o <- order(E$key)
  key <- E$key[o]
  first <- !duplicated(key); last <- !duplicated(key, fromLast = TRUE)
  pair <- which(first & !last)
  if (!length(pair)) return(0L)
  constrained <- !is.na(cover[as.character(key[pair])])
  pair <- pair[!constrained]
  if (!length(pair)) return(0L)
  i <- o[pair]; j <- o[pair + 1L]
  a <- E$a[i]; b <- E$b[i]; c <- E$opp[i]; d <- E$opp[j]
  ## orient a, b, c counterclockwise, then test d against its circumcircle
  orient <- (x[b] - x[a]) * (y[c] - y[a]) - (x[c] - x[a]) * (y[b] - y[a])
  sw <- orient < 0
  tmp <- a[sw]; a[sw] <- b[sw]; b[sw] <- tmp
  adx <- x[a] - x[d]; ady <- y[a] - y[d]
  bdx <- x[b] - x[d]; bdy <- y[b] - y[d]
  cdx <- x[c] - x[d]; cdy <- y[c] - y[d]
  det <- (adx * adx + ady * ady) * (bdx * cdy - cdx * bdy) -
    (bdx * bdx + bdy * bdy) * (adx * cdy - cdx * ady) +
    (cdx * cdx + cdy * cdy) * (adx * bdy - bdx * ady)
  scale <- (abs(adx) + abs(ady) + abs(bdx) + abs(bdy) + abs(cdx) + abs(cdy))^4
  sum(det > 1e-10 * scale)
}

#' Attribute interpolation error
#'
#' Every case is run once more with the linear attribute `z = x + 2 y` on
#' the input vertices. Linear interpolation (along a segment for a crossing,
#' barycentric for a Steiner vertex) reproduces a linear field exactly, so
#' the largest deviation on the output vertices measures how attributes are
#' carried.
#' @param out backend output with a `z` column on `vertices`
#' @param case the case (for scaling)
#' @return relative maximum absolute error
#' @export
tw_attr_error <- function(out, case) {
  z <- out$vertices$z
  if (is.null(z)) return(NA_real_)
  scale <- max(abs(case$x) + 2 * abs(case$y))
  max(abs(z - (out$vertices$x + 2 * out$vertices$y))) / scale
}
