## Benchmark the mesh-native ST_* prototypes in st_mesh.R against sf (GEOS)
## on three layers, and check that every answer agrees.
##   Rscript survey/dev-drafts/st-mesh/bench.R <inlandwaters.rda> <outdir>
## inlandwaters.rda is in the silicate repository, data/ folder.
suppressMessages(library(sf))
sf_use_s2(FALSE)                      # all three layers are projected
args <- commandArgs(trailingOnly = TRUE)
iw_file <- if (length(args) > 0) args[1] else "/tmp/silicate/data/inlandwaters.rda"
out <- if (length(args) > 1) args[2] else "survey/dev-drafts/st-mesh/results"
dir.create(out, showWarnings = FALSE, recursive = TRUE)
here <- dirname(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE)))
source(file.path(here, "st_mesh.R"))
cpp11::cpp_source(file.path(here, "st_mesh.cpp"), quiet = TRUE)

## ---- layers ----
layers <- list()
nc <- st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
layers$nc <- st_transform(st_geometry(nc), 32119)
set.seed(3)
sq <- st_as_sfc(st_bbox(c(xmin = 0, ymin = 0, xmax = 1e5, ymax = 1e5)))
pts <- st_sfc(st_multipoint(cbind(runif(20000, 0, 1e5), runif(20000, 0, 1e5))))
vor <- st_collection_extract(st_voronoi(pts, envelope = sq))
vor <- vor[lengths(st_within(vor, sq)) > 0]    # whole cells only, no clipping
layers$voronoi <- st_set_crs(st_cast(vor, "MULTIPOLYGON"), 32119)
e <- new.env(); load(iw_file, envir = e)
iw <- st_geometry(e$inlandwaters)
layers$inlandwaters <- st_set_crs(st_set_crs(iw, NA), st_crs(attr(iw, "crs")$proj4string))

## median time of f(); f is a function so each iteration re-runs it
timeit <- function(f) {
  b <- bench::mark(f(), min_time = 0.3, max_iterations = 20,
                   check = FALSE, filter_gc = FALSE, memory = FALSE)
  as.numeric(b$median)
}
as_list <- function(x) lapply(unclass(x), function(i) as.integer(sort(i)))
unname_list <- function(x) lapply(unname(x), as.integer)

timings <- list(); checks <- list(); sizes <- list()
for (nm in names(layers)) {
  g <- layers[[nm]]
  cat("\n==", nm, "==\n")
  build <- system.time(pm <- polymer::polymer(st_sf(geometry = g)))[["elapsed"]]
  m <- mesh_from_polymer(pm)
  loc_build <- timeit(function() mesh_locator(m))
  loc <- mesh_locator(m)
  n_coord <- nrow(st_coordinates(g))
  sizes[[nm]] <- data.frame(layer = nm, features = length(g), polygon_coords = n_coord,
                            mesh_vertices = length(m$x), triangles = length(m$v0),
                            build_s = build, locator_s = loc_build)
  print(sizes[[nm]])

  ## points for the point-in-polygon join
  bb <- st_bbox(g)
  set.seed(1)
  px <- runif(1e5, bb[["xmin"]], bb[["xmax"]]); py <- runif(1e5, bb[["ymin"]], bb[["ymax"]])
  P <- st_as_sf(data.frame(x = px, y = py), coords = c("x", "y"), crs = st_crs(g))
  ## groups for the dissolve: 8 bands of centroid x (all one group for 6 features)
  cx <- st_coordinates(st_centroid(g))[, 1]
  grp <- if (length(g) > 10) as.integer(cut(cx, 8)) else rep(1L, length(g))

  ops <- list(
    ST_Area = list(
      mesh = function() mesh_area(m),
      sf = function() st_area(g),
      check = function(a, b) max(abs(a - as.numeric(b)) / as.numeric(b))),
    ST_Centroid = list(
      mesh = function() mesh_centroid(m),
      sf = function() st_centroid(g),
      check = function(a, b) max(abs(a - st_coordinates(b))) / max(bb[3] - bb[1], bb[4] - bb[2])),
    ST_PointOnSurface = list(
      mesh = function() mesh_point_on_surface(m),
      sf = function() st_point_on_surface(g),
      ## check: each mesh point is inside its own feature (0 = all are)
      check = function(a, b) {
        w <- st_within(st_as_sf(as.data.frame(a), coords = c("x", "y"), crs = st_crs(g)), g)
        sum(!mapply(function(i, j) j %in% i, unclass(w), seq_along(g)))
      }),
    ST_Envelope = list(
      mesh = function() mesh_envelope(m),
      mesh_c = function() mesh_envelope2(m),
      sf = function() wk::wk_envelope(g),
      check = function(a, b) {
        r <- unclass(b)
        max(abs(a - cbind(r$xmin, r$ymin, r$xmax, r$ymax)))
      }),
    ST_Touches = list(
      mesh = function() mesh_touches(m),
      mesh_c = function() mesh_touches2(m),
      sf = function() st_touches(g),
      check = function(a, b) sum(!mapply(identical, unname_list(a), as_list(b)))),
    `ST_Relate F***1****` = list(
      mesh = function() mesh_edge_neighbours(m),
      sf = function() st_relate(g, g, pattern = "F***1****"),
      check = function(a, b) sum(!mapply(identical, unname_list(a), as_list(b)))),
    `ST_Intersects(point, polygon)` = list(
      mesh = function() mesh_locate(m, px, py, loc),
      mesh_c = function() mesh_locate2(m, px, py),
      sf = function() st_intersects(P, g),
      check = function(a, b) {
        b1 <- vapply(unclass(b), function(i) if (length(i)) i[1] else NA_integer_, 1L)
        sum(xor(is.na(a), is.na(b1)) | (!is.na(a) & !is.na(b1) & a != b1))
      }),
    `ST_Union_Agg (grouped)` = list(
      mesh = function() mesh_union(m, grp),
      mesh_c = function() mesh_union2(m, grp),
      sf = function() st_sfc(lapply(split(g, grp), function(x) st_union(x)[[1]]), crs = st_crs(g)),
      ## check: area of symmetric difference relative to the area
      check = function(a, b) {
        a <- st_set_crs(st_as_sfc(a), st_crs(g))
        max(vapply(seq_along(b), function(i) {
          sum(as.numeric(st_area(st_sym_difference(a[i], b[i])))) / as.numeric(st_area(b[i]))
        }, 0))
      }),
    `ST_CoverageUnion (grouped)` = list(
      mesh = function() mesh_union(m, grp),
      mesh_c = function() mesh_union2(m, grp),
      sf = function() st_sfc(lapply(split(g, grp), function(x) st_union(x, is_coverage = TRUE)[[1]]),
                             crs = st_crs(g)),
      check = function(a, b) {
        a <- st_set_crs(st_as_sfc(a), st_crs(g))
        max(vapply(seq_along(b), function(i) {
          sum(as.numeric(st_area(st_sym_difference(a[i], b[i])))) / as.numeric(st_area(b[i]))
        }, 0))
      }),
    ST_Transform = list(
      mesh = function() mesh_transform(m, st_crs(g)$wkt, "EPSG:4326"),
      sf = function() st_transform(g, 4326),
      ## check: the transformed mesh area against the transformed polygons, planar in degrees
      check = function(a, b) {
        old <- sf_use_s2(FALSE); on.exit(sf_use_s2(old))
        ar <- as.numeric(suppressMessages(st_area(st_set_crs(b, NA))))
        max(abs(mesh_area(a) - ar) / ar)
      })
  )

  for (op in names(ops)) {
    o <- ops[[op]]
    b <- o$sf()
    chk <- o$check(o$mesh(), b)
    tm <- timeit(o$mesh); ts <- timeit(o$sf)
    tc <- NA_real_; chk_c <- NA_real_
    if (!is.null(o$mesh_c)) {
      chk_c <- o$check(o$mesh_c(), b)
      tc <- timeit(o$mesh_c)
    }
    best <- min(tm, tc, na.rm = TRUE)
    cat(sprintf("%-32s R %8.4f s  C++ %8.4f s  sf %8.4f s  x%6.1f  check %.3g / %.3g\n",
                op, tm, tc, ts, ts / best, chk, chk_c))
    timings[[length(timings) + 1]] <- data.frame(layer = nm, op = op, mesh_r_s = tm,
                                                 mesh_cpp_s = tc, sf_s = ts,
                                                 speedup = ts / best)
    checks[[length(checks) + 1]] <- data.frame(layer = nm, op = op, check_r = chk,
                                               check_cpp = chk_c)
  }
}
timings <- do.call(rbind, timings); checks <- do.call(rbind, checks); sizes <- do.call(rbind, sizes)
write.csv(timings, file.path(out, "timings.csv"), row.names = FALSE)
write.csv(checks, file.path(out, "checks.csv"), row.names = FALSE)
write.csv(sizes, file.path(out, "sizes.csv"), row.names = FALSE)
writeLines(c(R.version.string,
             paste("sf", packageVersion("sf"), "GEOS", sf_extSoftVersion()[["GEOS"]],
                   "PROJ", sf_extSoftVersion()[["PROJ"]]),
             paste("wk", packageVersion("wk"), "wkpool", packageVersion("wkpool"),
                   "polymer", packageVersion("polymer"), "cdtr", packageVersion("cdtr")),
             paste("cores", parallel::detectCores())),
           file.path(out, "session.txt"))
