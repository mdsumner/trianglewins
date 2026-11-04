## A raster is a mesh: the vertex pool, segments, quads and triangles of
## a grid, computed from ncol, nrow and a bbox, with nothing stored but
## those six numbers. Base R only.
##   Rscript survey/grids/grid-mesh.R
## Indexing: i is the column (0 at the left), j is the row (0 at the top),
## as in a GDAL geotransform. Vertex ids are 1-based for R.

grid_mesh <- function(ncol, nrow, bbox) {
  ## bbox is c(xmin, ymin, xmax, ymax)
  vid <- function(i, j) j * (ncol + 1) + i + 1
  ## vertex pool: the (ncol + 1) x (nrow + 1) cell corners, each once
  vi <- rep(0:ncol, times = nrow + 1)
  vj <- rep(0:nrow, each = ncol + 1)
  vertex <- data.frame(
    x = bbox[1] + vi * (bbox[3] - bbox[1]) / ncol,
    y = bbox[4] - vj * (bbox[4] - bbox[2]) / nrow
  )
  ## cells, row-major from the top left
  ci <- rep(0:(ncol - 1), times = nrow)
  cj <- rep(0:(nrow - 1), each = ncol)
  a <- vid(ci, cj)          # top left
  b <- vid(ci + 1, cj)      # top right
  c <- vid(ci + 1, cj + 1)  # bottom right
  d <- vid(ci, cj + 1)      # bottom left
  quad <- cbind(a, b, c, d)
  ## two triangles per cell share the diagonal a-c: its two vertices
  ## are used by both triangles and stored once
  triangle <- rbind(cbind(a, b, c), cbind(a, c, d))
  ## segments: each edge once, as a pair of vertex ids
  hi <- rep(0:(ncol - 1), times = nrow + 1); hj <- rep(0:nrow, each = ncol)
  wi <- rep(0:ncol, times = nrow);           wj <- rep(0:(nrow - 1), each = ncol + 1)
  segment <- rbind(
    cbind(vid(hi, hj), vid(hi + 1, hj)),  # horizontal
    cbind(vid(wi, wj), vid(wi, wj + 1)),  # vertical
    cbind(a, c)                           # diagonal
  )
  list(vertex = vertex, segment = segment, quad = quad, triangle = triangle)
}

m <- grid_mesh(3, 2, c(0, 0, 3, 2))
str(m)

## counts follow from ncol and nrow alone
ncol <- 3; nrow <- 2
stopifnot(
  nrow(m$vertex)   == (ncol + 1) * (nrow + 1),
  nrow(m$segment)  == ncol * (nrow + 1) + (ncol + 1) * nrow + ncol * nrow,
  nrow(m$triangle) == 2 * ncol * nrow,
  ## every segment is unique, and every triangle edge is a segment
  !anyDuplicated(t(apply(m$segment, 1, sort))),
  ## Euler for a disc: V - E + F = 1 (F counts triangles, not the outside)
  nrow(m$vertex) - nrow(m$segment) + nrow(m$triangle) == 1
)
tri_edges <- rbind(m$triangle[, 1:2], m$triangle[, 2:3], m$triangle[, c(1, 3)])
key <- function(e) paste(pmin(e[, 1], e[, 2]), pmax(e[, 1], e[, 2]))
stopifnot(setequal(key(tri_edges), key(m$segment)))

## the same cells written out as closed polygon rings, as polygonizing a
## raster does: 5 coordinates per cell, and every interior edge twice
rings <- 5 * ncol * nrow
interior <- (ncol - 1) * nrow + ncol * (nrow - 1)
cat(sprintf("mesh: %d vertices; rings: %d coordinates; interior edges written twice: %d\n",
            nrow(m$vertex), rings, interior))
