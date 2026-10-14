## Pilot R side of the geoarrow.triangles proposal: wkpool_tri <-> Arrow,
## built with nanoarrow (no Arrow C++ needed to produce the arrays).

library(nanoarrow)

ga_coord <- function() {
  na_struct(list(x = na_double(nullable = FALSE), y = na_double(nullable = FALSE)))
}

ga_triangles_schema <- function(meta = list(), dictionary = TRUE) {
  value <- if (dictionary) {
    nanoarrow_schema_modify(na_dictionary(ga_coord(), index_type = na_int32()),
                            list(flags = 0L))
  } else {
    nanoarrow_schema_modify(ga_coord(), list(flags = 0L))
  }
  fsl <- nanoarrow_schema_modify(na_fixed_size_list(value, 3L, nullable = FALSE),
                                 list(children = list(vertices = value)))
  na_extension(fsl, "geoarrow.triangles",
               jsonlite::toJSON(meta, auto_unbox = TRUE))
}

## Renumber vertices by first appearance in the triangles (0-based), drop unused.
ga_canonical <- function(xy, tri) {
  flat <- as.vector(t(tri))
  order <- unique(flat)
  list(xy = xy[order, , drop = FALSE],
       tri = matrix(match(flat, order) - 1L, ncol = 3, byrow = TRUE))
}

## wkpool_tri -> list(xy, tri 0-based, feature)
ga_from_wkpool_tri <- function(x) {
  v <- wkpool::pool_vertices(x)
  t <- wkpool::pool_triangles(x)
  ids <- cbind(match(t$.vx0, v$.vx), match(t$.vx1, v$.vx), match(t$.vx2, v$.vx))
  out <- ga_canonical(cbind(v$x, v$y), ids)
  out$feature <- t$.feature
  out
}

## Dictionary layout as a nanoarrow array
ga_triangles_array <- function(xy, tri, meta = list()) {
  sch <- ga_triangles_schema(meta, dictionary = TRUE)
  verts <- as_nanoarrow_array(data.frame(x = xy[, 1], y = xy[, 2]), schema = ga_coord())
  idx <- as_nanoarrow_array(as.integer(t(tri)), schema = na_int32())
  dict <- nanoarrow_array_modify(idx, list(dictionary = verts))
  arr <- nanoarrow_array_init(na_fixed_size_list(na_int32(), 3L))
  arr <- nanoarrow_array_modify(arr, list(length = nrow(tri), null_count = 0L,
                                          children = list(dict)), validate = FALSE)
  nanoarrow_array_set_schema(arr, sch, validate = TRUE)
}

## Decoded layout (every vertex written out) as a nanoarrow array
ga_triangles_decoded <- function(xy, tri, meta = list()) {
  sch <- ga_triangles_schema(meta, dictionary = FALSE)
  flat <- xy[as.integer(t(tri)) + 1L, , drop = FALSE]
  pts <- as_nanoarrow_array(data.frame(x = flat[, 1], y = flat[, 2]), schema = ga_coord())
  arr <- nanoarrow_array_init(na_fixed_size_list(na_int32(), 3L))
  arr <- nanoarrow_array_modify(arr, list(length = nrow(tri), null_count = 0L,
                                          children = list(pts)), validate = FALSE)
  nanoarrow_array_set_schema(arr, sch, validate = TRUE)
}

## Table (struct array) with the triangles plus sibling columns
ga_table <- function(triangles, ...) {
  cols <- list(triangles = triangles, ...)
  cols[-1] <- lapply(cols[-1], as_nanoarrow_array)
  sch <- na_struct(lapply(cols, infer_nanoarrow_schema))
  arr <- nanoarrow_array_init(sch)
  nanoarrow_array_modify(arr, list(length = triangles$length, null_count = 0L,
                                   children = cols), validate = FALSE)
}

## Decoded coordinates -> wkpool_tri, pooled by exact bit pattern
## (wkpool::merge_coincident numbers vertices by first appearance).
ga_decoded_to_wkpool_tri <- function(x, y, feature = NULL) {
  n <- length(x) / 3L
  v <- data.frame(.vx = seq_along(x), x = x, y = y)
  k <- matrix(seq_along(x), ncol = 3, byrow = TRUE)
  soup <- wkpool::new_wkpool_tri(v, k[, 1], k[, 2], k[, 3], feature = feature)
  wkpool::merge_coincident(soup)
}

## x/y of every vertex of a decoded triangles column (an Arrow ChunkedArray
## or anything with chunks convertible by nanoarrow), respecting offsets.
ga_decoded_coords <- function(col) {
  chunks <- lapply(seq_len(col$num_chunks) - 1L, function(i) col$chunk(i))
  parts <- lapply(chunks, function(ch) {
    na <- as_nanoarrow_array(ch)
    pts <- convert_array(na$children[[1]])
    rows <- (na$offset * 3L) + seq_len(na$length * 3L)
    pts[rows, , drop = FALSE]
  })
  do.call(rbind, parts)
}
