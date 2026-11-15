## How much of sf's time is GEOS, and how much is converting to GEOS on
## every call? The same five operations three ways: sf on an sfc, the geos
## package converting from the sfc each call, and geos on geometries held
## as GEOS objects (what the mesh suite compares against).
##   Rscript survey/dev-drafts/st-mesh-geos/geos-vs-sf.R <inlandwaters.rda> <outdir>
suppressMessages({library(sf); library(geos)})
sf_use_s2(FALSE)
args <- commandArgs(trailingOnly = TRUE)
iw_file <- if (length(args) > 0) args[1] else "/tmp/silicate/data/inlandwaters.rda"
out <- if (length(args) > 1) args[2] else "survey/dev-drafts/st-mesh-geos/results"

layers <- list()
nc <- st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
layers$nc <- st_set_crs(st_geometry(st_transform(nc, 32119)), NA)
set.seed(3)
sq <- st_as_sfc(st_bbox(c(xmin = 0, ymin = 0, xmax = 1e5, ymax = 1e5)))
pts <- st_sfc(st_multipoint(cbind(runif(20000, 0, 1e5), runif(20000, 0, 1e5))))
vor <- st_collection_extract(st_voronoi(pts, envelope = sq))
layers$voronoi <- vor[lengths(st_within(vor, sq)) > 0]
e <- new.env(); load(iw_file, envir = e)
layers$inlandwaters <- st_set_crs(st_geometry(e$inlandwaters), NA)

timeit <- function(f) {
  b <- bench::mark(f(), min_time = 0.3, max_iterations = 20,
                   check = FALSE, filter_gc = FALSE, memory = FALSE)
  as.numeric(b$median)
}
res <- list()
for (nm in names(layers)) {
  s <- layers[[nm]]
  g <- as_geos_geometry(s)
  bb <- st_bbox(s)
  set.seed(1)
  px <- runif(1e5, bb[["xmin"]], bb[["xmax"]]); py <- runif(1e5, bb[["ymin"]], bb[["ymax"]])
  Psf <- st_as_sf(data.frame(x = px, y = py), coords = c("x", "y"))
  P <- geos_make_point(px, py)
  d <- 0.005 * max(bb[["xmax"]] - bb[["xmin"]], bb[["ymax"]] - bb[["ymin"]])
  grp <- if (length(s) > 10) as.integer(cut(st_coordinates(st_centroid(s))[, 1], 8)) else rep(1L, length(s))
  og <- order(grp)
  ops <- list(
    ST_Area = list(function() st_area(s), function() geos_area(as_geos_geometry(s)),
                   function() geos_area(g)),
    `ST_Touches (all pairs)` = list(function() st_touches(s),
                       function() { h <- as_geos_geometry(s); geos_touches_matrix(h, geos_strtree(h)) },
                       function() geos_touches_matrix(g, geos_strtree(g))),
    `ST_Intersects(point), 1e5` = list(function() st_intersects(Psf, s),
                       function() { h <- as_geos_geometry(s); geos_intersects_matrix(geos_make_point(px, py), geos_strtree(h)) },
                       function() geos_intersects_matrix(P, geos_strtree(g))),
    `ST_Union_Agg (grouped)` = list(function() lapply(split(s, grp), st_union),
                       function() { h <- as_geos_geometry(s); geos_unary_union(geos_make_collection(h[og], feature_id = grp[og])) },
                       function() geos_unary_union(geos_make_collection(g[og], feature_id = grp[og]))),
    ST_Buffer = list(function() st_buffer(s, d), function() geos_buffer(as_geos_geometry(s), d),
                     function() geos_buffer(g, d))
  )
  for (op in names(ops)) {
    t <- vapply(ops[[op]], timeit, 0)
    res[[length(res) + 1]] <- data.frame(layer = nm, op = op, sf_s = t[1], geos_convert_s = t[2],
                                         geos_held_s = t[3])
    cat(sprintf("%-13s %-28s sf %8.4f  geos+convert %8.4f  geos held %8.4f\n", nm, op, t[1], t[2], t[3]))
  }
}
res <- do.call(rbind, res)
write.csv(res, file.path(out, "geos-vs-sf.csv"), row.names = FALSE)
writeLines(paste("sf", packageVersion("sf"), "GEOS (sf)", sf_extSoftVersion()[["GEOS"]],
                 "geos", packageVersion("geos"), "GEOS (geos)", geos_version()),
           file.path(out, "geos-vs-sf-session.txt"))
