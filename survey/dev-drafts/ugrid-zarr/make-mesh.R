## A constrained, refined mesh of inlandwaters (holes kept as holes) in
## lon/lat, written as UGRID-in-Zarr v2 and v3, then read back in R.
##   Rscript survey/dev-drafts/ugrid-zarr/make-mesh.R <inlandwaters.rda> <outdir>
args <- commandArgs(TRUE)
here <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))
source(file.path(here, "ugrid_zarr.R"))
suppressMessages({library(sf); library(cdtr)})
out <- args[2]; dir.create(out, showWarnings = FALSE)
res <- list()

load(args[1])
## silicate stores an old-style crs; rebuild it from its proj4string
st_crs(inlandwaters) <- st_crs(unclass(st_crs(inlandwaters))$proj4string %||% st_crs(inlandwaters)$input)
iw <- st_transform(inlandwaters, "OGC:CRS84")
## PSLG: every ring, closing vertex dropped, segments joining ring neighbours
co <- st_coordinates(iw)
ring <- paste(co[, "L3"], co[, "L2"], co[, "L1"])
keep <- duplicated(ring, fromLast = TRUE)           # drop each ring's closing vertex
co <- co[keep, ]; ring <- ring[keep]
n <- nrow(co)
nxt <- seq_len(n) + 1L
last <- !duplicated(ring, fromLast = TRUE)
first <- match(ring, ring)
nxt[last] <- first[last]

bb <- st_bbox(iw)
target <- 2e5                                          # about this many triangles
max_area <- (bb[["xmax"]] - bb[["xmin"]]) * (bb[["ymax"]] - bb[["ymin"]]) / target * 0.25
t0 <- proc.time()[["elapsed"]]
r <- cdt_triangulate(co[, "X"], co[, "Y"], seq_len(n), nxt,
                     erase = "holes", max_area = max_area, min_angle = 25)
res$triangulate_s <- round(proc.time()[["elapsed"]] - t0, 2)

## mesh spec tables: input-first vertices, origin, input_row
P <- r$P; nv <- nrow(P)
input_row <- rep(NA_integer_, nv)
## first input row that landed on each deduplicated input vertex
im <- r$input_map
input_row[im[!duplicated(im)]] <- which(!duplicated(im))
mesh <- list(
  vertices = data.frame(x = P[, 1], y = P[, 2], origin = r$origin, input_row = input_row),
  triangles = r$T, depth = r$depth, constraints = r$S, crs = "OGC:CRS84")

## CCW check (mesh spec decision 3)
a <- P[r$T[, 1], ]; b <- P[r$T[, 2], ]; cc <- P[r$T[, 3], ]
cross <- (b[, 1] - a[, 1]) * (cc[, 2] - a[, 2]) - (b[, 2] - a[, 2]) * (cc[, 1] - a[, 1])
res$ccw_all <- all(cross > 0)

## data: a smooth field on nodes and the triangle area on faces
field <- sin(P[, 1] * 2) * cos(P[, 2] * 3)
area <- cross / 2

res$n_vertices <- nv; res$n_triangles <- nrow(r$T); res$n_constraint_edges <- nrow(r$S)
res$origin <- as.list(table(r$origin))
res$depth <- as.list(table(r$depth))

for (ver in 2:3) {
  dsn <- file.path(out, sprintf("inlandwaters-v%d.zarr", ver))
  t0 <- proc.time()[["elapsed"]]
  uz_write_mesh(mesh, dsn, node = list(field = field), face = list(area = area),
                version = ver, chunk_rows = 50000)
  res[[sprintf("write_v%d_s", ver)]] <- round(proc.time()[["elapsed"]] - t0, 2)
  res[[sprintf("bytes_v%d", ver)]] <- sum(file.size(list.files(dsn, recursive = TRUE,
                                                                 all.files = TRUE, full.names = TRUE)))
  back <- uz_read_mesh(dsn)
  res[[sprintf("roundtrip_v%d", ver)]] <- identical(back$vertices$x, mesh$vertices$x) &&
    identical(back$vertices$y, mesh$vertices$y) &&
    identical(unname(back$triangles), unname(matrix(as.integer(mesh$triangles), ncol = 3))) &&
    identical(back$depth, as.integer(mesh$depth)) &&
    identical(back$vertices$origin, factor(as.character(mesh$vertices$origin),
                                           levels = levels(back$vertices$origin))) &&
    identical(back$vertices$input_row, mesh$vertices$input_row) &&
    ## constraints come back as flagged edges: same set, sorted, lower vertex first
    setequal(paste(back$constraints[, 1], back$constraints[, 2]),
             paste(pmin(mesh$constraints[, 1], mesh$constraints[, 2]),
                   pmax(mesh$constraints[, 1], mesh$constraints[, 2]))) &&
    nrow(back$constraints) == nrow(mesh$constraints)
}
## a tiny one for eyeballing the layout
sq <- cdt_triangulate(c(0, 1, 1, 0, 0.25, 0.75, 0.75, 0.25), c(0, 0, 1, 1, 0.25, 0.25, 0.75, 0.75),
                      1:8, c(2, 3, 4, 1, 6, 7, 8, 5), erase = "holes")
uz_write_mesh(list(vertices = data.frame(x = sq$P[, 1], y = sq$P[, 2], origin = sq$origin,
                                         input_row = seq_len(nrow(sq$P))),
                   triangles = sq$T, depth = sq$depth, constraints = sq$S, crs = "OGC:CRS84"),
              file.path(out, "square-hole-v2.zarr"), node = list(field = sq$P[, 1]))

saveRDS(mesh, file.path(out, "mesh.rds"))
writeLines(jsonlite::toJSON(res, auto_unbox = TRUE, pretty = TRUE), file.path(out, "r-write.json"))
print(str(res))
