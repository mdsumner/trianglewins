## UGRID-in-Zarr from R, with no Zarr library: JSON metadata plus gzip
## chunks. Writes Zarr v2 (default, widest reader support) or v3.
##
## A mesh here is the mesh spec v0.1 tables as a list:
##   vertices  data frame: x, y, origin (factor input/crossing/steiner),
##             input_row (integer, NA for added vertices)
##   triangles integer matrix (n, 3), 1-based, CCW
##   depth     integer per triangle (optional)
##   constraints integer matrix (n, 2), 1-based vertex pairs (optional)
##   crs       "OGC:CRS84" for lon/lat, else WKT or NA
##
## On disk: one UGRID 1.0 mesh topology. Keys are 0-based (start_index 0).
## Spec tables map to UGRID variables keyed by a mesh dimension:
##   vertices          -> node dimension (x, y, origin, input_row)
##   triangles         -> face_node_connectivity (n_face, 3)
##   depth             -> face variable
##   constraints       -> edge_constrained flag on UGRID edges (all triangle
##                        edges are written, so UGRID readers get a full edge set)
## Data are further variables on the node or face dimension.

uz_json <- function(x) jsonlite::toJSON(x, auto_unbox = TRUE, null = "null",
                                        digits = NA, pretty = TRUE)

## dtype per R vector, as Zarr v2 typestr and v3 data_type
uz_type <- function(v) {
  if (is.double(v)) return(c("<f8", "float64", "double", 8))
  if (inherits(v, "uz_int8")) return(c("|i1", "int8", "integer", 1))
  if (is.integer(v) || is.logical(v)) return(c("<i4", "int32", "integer", 4))
  stop("unsupported type: ", class(v)[1])
}

int8 <- function(x) structure(as.integer(x), class = "uz_int8")

## write one array: values in R order are C order for (n) and for (n, k)
## when given as a matrix (rows are the first, slow dimension)
uz_write_array <- function(root, name, values, dims, attrs = list(),
                           chunk_rows = 2^18, version = 2L) {
  shape <- if (is.matrix(values)) dim(values) else if (length(dims)) length(values) else integer(0)
  ty <- uz_type(values)
  path <- file.path(root, name)
  dir.create(path, showWarnings = FALSE, recursive = TRUE)
  ncol <- if (is.matrix(values)) ncol(values) else 1L
  flat <- if (is.matrix(values)) as.vector(t(values)) else values
  nrow <- if (length(shape)) shape[1] else 1L
  crow <- if (length(shape)) as.integer(min(max(nrow, 1L), chunk_rows)) else 1L
  chunks <- if (length(shape) == 2) c(crow, shape[2]) else if (length(shape)) crow else integer(0)
  nchunk <- if (length(shape)) ceiling(nrow / crow) else 1L
  sep <- if (version == 2L) "." else "/"
  ## an empty array has no chunks
  for (k in seq_len(if (length(shape)) nchunk else 1L) - 1L) {
    rows <- if (length(shape)) seq.int(k * crow + 1L, min((k + 1L) * crow, nrow)) else 1L
    idx <- as.vector(outer(seq_len(ncol), (rows - 1L) * ncol, "+"))
    v <- flat[idx]
    ## the last chunk is padded to full size
    pad <- if (length(shape)) (crow - length(rows)) * ncol else 0L
    if (pad > 0) v <- c(v, rep(if (is.double(v)) 0 else 0L, pad))
    key <- if (length(shape) == 2) paste(k, 0, sep = sep) else as.character(k)
    if (version == 3L) key <- paste0("c/", key)
    f <- file.path(path, key)
    dir.create(dirname(f), showWarnings = FALSE, recursive = TRUE)
    con <- gzfile(f, "wb")
    writeBin(if (ty[3] == "double") as.double(v) else as.integer(v), con,
             size = as.integer(ty[4]), endian = "little")
    close(con)
  }
  if (version == 2L) {
    zarray <- list(zarr_format = 2L, shape = I(shape), chunks = I(chunks), dtype = ty[1],
                   compressor = list(id = "gzip", level = 6L), fill_value = NULL,
                   order = "C", filters = NULL)
    zattrs <- c(list(`_ARRAY_DIMENSIONS` = I(dims)), attrs)
    writeLines(uz_json(zarray), file.path(path, ".zarray"))
    writeLines(uz_json(zattrs), file.path(path, ".zattrs"))
    list(zarray = zarray, zattrs = zattrs)
  } else {
    meta <- list(zarr_format = 3L, node_type = "array", shape = I(shape),
                 data_type = ty[2],
                 chunk_grid = list(name = "regular", configuration = list(chunk_shape = I(chunks))),
                 chunk_key_encoding = list(name = "default", configuration = list(separator = "/")),
                 fill_value = 0L,
                 codecs = list(list(name = "bytes", configuration = list(endian = "little")),
                               list(name = "gzip", configuration = list(level = 6L))),
                 attributes = attrs, dimension_names = I(dims))
    writeLines(uz_json(meta), file.path(path, "zarr.json"))
    list(meta = meta)
  }
}

#' Write a mesh as UGRID 1.0 in a Zarr store
#'
#' @param mesh mesh tables (see top of file)
#' @param dsn output directory (.zarr)
#' @param node,face named lists of numeric vectors, data on nodes or faces
#' @param mesh_name UGRID topology variable name
#' @param version Zarr format, 2 or 3
uz_write_mesh <- function(mesh, dsn, node = list(), face = list(),
                          mesh_name = "mesh", version = 2L, chunk_rows = 2^18) {
  version <- as.integer(version)
  if (dir.exists(dsn)) unlink(dsn, recursive = TRUE)
  dir.create(dsn, recursive = TRUE)
  v <- mesh$vertices; tri <- mesh$triangles
  stopifnot(ncol(tri) == 3L, all(tri >= 1L), all(tri <= nrow(v)))
  dn <- paste0(mesh_name, c("_node", "_face", "_edge"))  # dimension names
  nm <- function(s) paste0(mesh_name, "_", s)
  lonlat <- isTRUE(mesh$crs %in% c("OGC:CRS84", "EPSG:4326"))
  meta <- list()
  put <- function(name, values, dims, attrs = list()) {
    meta[[name]] <<- uz_write_array(dsn, name, values, dims, attrs, chunk_rows, version)
  }
  xy_attrs <- function(i) {
    a <- if (lonlat) list(standard_name = c("longitude", "latitude")[i],
                          units = c("degrees_east", "degrees_north")[i])
         else list(standard_name = c("projection_x_coordinate", "projection_y_coordinate")[i])
    c(a, list(mesh = mesh_name, location = "node"))
  }
  topo <- list(cf_role = "mesh_topology", topology_dimension = 2L,
               node_coordinates = paste(nm("node_x"), nm("node_y")),
               node_dimension = dn[1],
               face_node_connectivity = nm("face_nodes"),
               face_dimension = dn[2],
               meshspec = "0.1", vertex_order = "input-first")
  has_edges <- nrow(tri) > 0
  if (has_edges) {
    topo$edge_node_connectivity <- nm("edge_nodes")
    topo$edge_dimension <- dn[3]
  }
  put(mesh_name, 0L, character(0), topo)
  put(nm("node_x"), as.double(v$x), dn[1], xy_attrs(1))
  put(nm("node_y"), as.double(v$y), dn[1], xy_attrs(2))
  put(nm("face_nodes"), matrix(as.integer(tri) - 1L, ncol = 3), c(dn[2], "three"),
      list(cf_role = "face_node_connectivity", start_index = 0L,
           long_name = "triangle vertices, counter-clockwise"))
  if (!is.null(v$origin)) {
    lev <- c("input", "crossing", "steiner", "grid", "lattice")
    put(nm("node_origin"), int8(match(as.character(v$origin), lev) - 1L), dn[1],
        list(mesh = mesh_name, location = "node", long_name = "vertex origin",
             flag_values = I(0:4), flag_meanings = paste(lev, collapse = " ")))
  }
  if (!is.null(v$input_row)) {
    ir <- as.integer(v$input_row) - 1L
    ir[is.na(ir)] <- -1L
    put(nm("node_input_row"), ir, dn[1],
        list(mesh = mesh_name, location = "node",
             long_name = "0-based input row of this vertex, -1 for added vertices"))
  }
  if (!is.null(mesh$depth)) {
    put(nm("face_depth"), as.integer(mesh$depth), dn[2],
        list(mesh = mesh_name, location = "face",
             long_name = "constraint layer depth: odd inside, even in a hole"))
  }
  if (has_edges) {
    ## every triangle edge once, lower vertex first; the spec's constraints
    ## table becomes a flag on these edges
    e <- rbind(tri[, 1:2], tri[, 2:3], tri[, c(3, 1)])
    e <- unique(cbind(pmin(e[, 1], e[, 2]), pmax(e[, 1], e[, 2])))
    e <- e[order(e[, 1], e[, 2]), , drop = FALSE]
    flag <- rep(0L, nrow(e))
    if (!is.null(mesh$constraints) && nrow(mesh$constraints)) {
      s <- mesh$constraints
      key <- function(a, b) paste(pmin(a, b), pmax(a, b))
      flag[key(e[, 1], e[, 2]) %in% key(s[, 1], s[, 2])] <- 1L
    }
    put(nm("edge_nodes"), matrix(as.integer(e) - 1L, ncol = 2), c(dn[3], "two"),
        list(cf_role = "edge_node_connectivity", start_index = 0L))
    put(nm("edge_constrained"), int8(flag), dn[3],
        list(mesh = mesh_name, location = "edge", long_name = "edge lies on a constraint",
             flag_values = I(0:1), flag_meanings = "free constrained"))
  }
  coords <- paste(nm("node_x"), nm("node_y"))
  ## valid_min/valid_max let a renderer pick a colour scale without asking
  rng <- function(x) list(valid_min = min(x, na.rm = TRUE), valid_max = max(x, na.rm = TRUE))
  for (k in names(node)) {
    stopifnot(length(node[[k]]) == nrow(v))
    put(k, as.double(node[[k]]), dn[1], c(list(mesh = mesh_name, location = "node",
                                               coordinates = coords), rng(node[[k]])))
  }
  for (k in names(face)) {
    stopifnot(length(face[[k]]) == nrow(tri))
    put(k, as.double(face[[k]]), dn[2], c(list(mesh = mesh_name, location = "face"),
                                          rng(face[[k]])))
  }
  gattrs <- list(Conventions = "CF-1.8 UGRID-1.0",
                 source = "trianglewins ugrid-zarr pilot (R, no Zarr library)")
  if (!is.na(mesh$crs %||% NA) && !lonlat) gattrs$crs_wkt <- mesh$crs
  if (version == 2L) {
    writeLines(uz_json(list(zarr_format = 2L)), file.path(dsn, ".zgroup"))
    writeLines(uz_json(gattrs), file.path(dsn, ".zattrs"))
    ## consolidated metadata, as xarray and GDAL look for it
    md <- list(.zgroup = list(zarr_format = 2L), .zattrs = gattrs)
    for (k in names(meta)) {
      md[[paste0(k, "/.zarray")]] <- meta[[k]]$zarray
      md[[paste0(k, "/.zattrs")]] <- meta[[k]]$zattrs
    }
    writeLines(uz_json(list(metadata = md, zarr_consolidated_format = 1L)),
               file.path(dsn, ".zmetadata"))
  } else {
    writeLines(uz_json(list(zarr_format = 3L, node_type = "group", attributes = gattrs)),
               file.path(dsn, "zarr.json"))
  }
  invisible(dsn)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

## Minimal reader for what the writer produces (v2 or v3, gzip or no
## compressor), enough for a round trip without a Zarr library.
uz_read_array <- function(dsn, name) {
  p <- file.path(dsn, name)
  if (file.exists(file.path(p, ".zarray"))) {
    za <- jsonlite::fromJSON(file.path(p, ".zarray"))
    at <- jsonlite::fromJSON(file.path(p, ".zattrs"), simplifyVector = FALSE)
    shape <- za$shape; chunks <- za$chunks; ty <- za$dtype; sep <- za$dimension_separator %||% "."
    prefix <- ""
    gz <- !is.null(za$compressor)
  } else {
    za <- jsonlite::fromJSON(file.path(p, "zarr.json"))
    at <- za$attributes
    shape <- za$shape; chunks <- za$chunk_grid$configuration$chunk_shape
    ty <- c(float64 = "<f8", int32 = "<i4", int8 = "|i1")[[za$data_type]]
    sep <- "/"; prefix <- "c/"
    gz <- "gzip" %in% za$codecs$name
  }
  size <- c("<f8" = 8L, "<i4" = 4L, "|i1" = 1L)[[ty]]
  what <- if (ty == "<f8") "double" else "integer"
  ncol <- if (length(shape) == 2) shape[2] else 1L
  nrow <- if (length(shape)) shape[1] else 1L
  crow <- if (length(shape)) chunks[1] else 1L
  out <- vector("list", if (nrow) ceiling(nrow / crow) else 0L)
  for (k in seq_along(out) - 1L) {
    key <- if (length(shape) == 2) paste(k, 0, sep = sep) else as.character(k)
    f <- file.path(p, paste0(prefix, key))
    con <- if (gz) gzfile(f, "rb") else file(f, "rb")
    out[[k + 1]] <- readBin(con, what, n = crow * ncol, size = size, endian = "little")
    close(con)
  }
  vals <- unlist(out)[seq_len(nrow * ncol)]
  if (length(shape) == 2) vals <- matrix(vals, ncol = ncol, byrow = TRUE)
  if (!length(shape)) vals <- vals[1]
  attr(vals, "zattrs") <- at
  vals
}

uz_read_mesh <- function(dsn, mesh_name = "mesh") {
  topo <- attr(uz_read_array(dsn, mesh_name), "zattrs")
  xy <- strsplit(topo$node_coordinates, " ")[[1]]
  rd <- function(n) { a <- uz_read_array(dsn, n); attr(a, "zattrs") <- NULL; a }
  start <- attr(uz_read_array(dsn, topo$face_node_connectivity), "zattrs")$start_index %||% 0L
  v <- data.frame(x = rd(xy[1]), y = rd(xy[2]))
  on <- paste0(mesh_name, "_node_origin")
  if (dir.exists(file.path(dsn, on))) {
    v$origin <- factor(c("input", "crossing", "steiner", "grid", "lattice")[rd(on) + 1L],
                       levels = c("input", "crossing", "steiner", "grid", "lattice"))
  }
  ir <- paste0(mesh_name, "_node_input_row")
  if (dir.exists(file.path(dsn, ir))) { r <- rd(ir); r[r < 0] <- NA; v$input_row <- r + 1L }
  out <- list(vertices = v, triangles = rd(topo$face_node_connectivity) - start + 1L)
  dp <- paste0(mesh_name, "_face_depth")
  if (dir.exists(file.path(dsn, dp))) out$depth <- rd(dp)
  if (!is.null(topo$edge_node_connectivity)) {
    e <- rd(topo$edge_node_connectivity) + 1L
    fl <- paste0(mesh_name, "_edge_constrained")
    if (dir.exists(file.path(dsn, fl))) out$constraints <- e[rd(fl) == 1L, , drop = FALSE]
  }
  out
}
