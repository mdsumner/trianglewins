## Benchmark the mesh ST_* suite (st_mesh.R, st_mesh.cpp) against the R
## geos package on three layers, and check that every answer agrees.
##   Rscript survey/dev-drafts/st-mesh-geos/bench.R <inlandwaters.rda> <outdir>
## inlandwaters.rda is in the silicate repository, data/ folder. sf is used
## only to read and project the nc shapefile; nothing timed touches it.
suppressMessages(library(geos))
args <- commandArgs(trailingOnly = TRUE)
iw_file <- if (length(args) > 0) args[1] else "/tmp/silicate/data/inlandwaters.rda"
out <- if (length(args) > 1) args[2] else "survey/dev-drafts/st-mesh-geos/results"
dir.create(out, showWarnings = FALSE, recursive = TRUE)
here <- dirname(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE)))
source(file.path(here, "st_mesh.R"))
cpp11::cpp_source(file.path(here, "st_mesh.cpp"), quiet = TRUE)

## ---- layers, held as geos geometries (converted once, not per call) ----
layers <- list()
nc <- sf::st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
layers$nc <- as_geos_geometry(sf::st_geometry(sf::st_transform(nc, 32119)))
set.seed(3)
pts <- geos_make_collection(geos_make_point(runif(20000, 0, 1e5), runif(20000, 0, 1e5)),
                            "multipoint")
sq <- geos_create_rectangle(0, 0, 1e5, 1e5)
vor <- geos_geometry_n(geos_voronoi_polygons(pts, env = sq),
                       seq_len(20000))
## whole cells only, no clipping. The WKB round trip makes each cell its own
## geometry: geos_touches_matrix() crashes on geos_geometry_n() parts (R geos
## 0.2.4.9000 on GEOS 3.11.1), although geos_touches() and the other
## predicate matrices are fine.
layers$voronoi <- geos_read_wkb(geos_write_wkb(vor[geos_within(vor, sq)]))
e <- new.env(); load(iw_file, envir = e)
layers$inlandwaters <- as_geos_geometry(e$inlandwaters$geom, crs = NULL)
for (nm in names(layers)) wk::wk_crs(layers[[nm]]) <- NULL

timeit <- function(f) {
  b <- bench::mark(f(), min_time = 0.3, max_iterations = 20,
                   check = FALSE, filter_gc = FALSE, memory = FALSE)
  as.numeric(b$median)
}
## the faster of the R and compiled versions (both are checked below)
best <- function(...) min(vapply(list(...), timeit, 0))
rel <- function(a, b) max(abs(a - b) / pmax(abs(b), 1e-300))
same_lists <- function(a, b) sum(!mapply(function(i, j) identical(sort(as.integer(i)), sort(as.integer(j))), a, b))

## candidate pairs from geos's tree: what a geos user does for "all pairs"
geos_pairs <- function(g) {
  k <- geos_inner_join_keys(g, g, "intersects")
  k[k$x < k$y, ]
}

timings <- list(); checks <- list(); sizes <- list()
add <- function(layer, op, tier, mesh_s, geos_s, check, note = "") {
  timings[[length(timings) + 1]] <<- data.frame(layer = layer, op = op, tier = tier,
                                                mesh_s = mesh_s, geos_s = geos_s,
                                                speedup = geos_s / mesh_s)
  checks[[length(checks) + 1]] <<- data.frame(layer = layer, op = op, check = check, note = note)
  cat(sprintf("%-14s %-34s %-13s mesh %9.5f  geos %9.5f  x%7.1f  check %.3g %s\n",
              layer, op, tier, mesh_s, geos_s, geos_s / mesh_s, check, note))
}

for (nm in names(layers)) {
  g <- layers[[nm]]
  cat("\n==", nm, "==\n")
  build <- timeit(function() polymer::polymer(g))
  pm <- polymer::polymer(g)
  m <- mesh_from_polymer(pm)
  ## the compiled versions give the R versions' answers
  stopifnot(isTRUE(all.equal(mesh_area(m), unname(mesh_area_c(m)))),
            isTRUE(all.equal(unname(mesh_centroid(m)), unname(mesh_centroid_c(m)))),
            isTRUE(all.equal(unname(mesh_point_on_surface(m)), unname(mesh_point_on_surface_c(m)))),
            isTRUE(all.equal(mesh_perimeter(m), unname(mesh_perimeter_c(m)))),
            identical(unname(mesh_num_parts(m)), unname(mesh_num_parts_c(m))))
  sizes[[nm]] <- data.frame(layer = nm, features = length(g),
                            polygon_coords = sum(geos_num_coordinates(g)),
                            mesh_vertices = length(m$x), triangles = length(m$v0),
                            build_s = build)
  print(sizes[[nm]])
  ext <- geos_extent(g)
  bb <- c(min(ext$xmin), min(ext$ymin), max(ext$xmax), max(ext$ymax))

  ## ---- native ----
  a <- geos_area(g)
  add(nm, "ST_Area", "native", best(function() mesh_area(m), function() mesh_area_c(m)), timeit(function() geos_area(g)),
      rel(mesh_area(m), a))
  gc_xy <- cbind(geos_x(geos_centroid(g)), geos_y(geos_centroid(g)))
  add(nm, "ST_Centroid", "native", best(function() mesh_centroid(m), function() mesh_centroid_c(m)),
      timeit(function() geos_centroid(g)),
      max(abs(mesh_centroid(m) - gc_xy)) / max(bb[3] - bb[1], bb[4] - bb[2]))
  pos <- mesh_point_on_surface(m)
  add(nm, "ST_PointOnSurface", "native",
      best(function() mesh_point_on_surface(m), function() mesh_point_on_surface_c(m)),
      timeit(function() geos_point_on_surface(g)),
      sum(!geos_within(geos_make_point(pos[, 1], pos[, 2]), g)), "points not inside own feature")
  add(nm, "ST_Envelope", "native", timeit(function() mesh_envelope(m)),
      timeit(function() geos_extent(g)),
      max(abs(mesh_envelope(m) - as.matrix(ext))))
  add(nm, "ST_IsValid", "native", timeit(function() mesh_is_valid(m)),
      timeit(function() geos_is_valid(g)),
      sum(mesh_is_valid(m) != geos_is_valid(g)), "features that differ")
  tr <- wk::wk_affine_compose(wk::wk_affine_rotate(30), wk::wk_affine_scale(2, 0.5))
  add(nm, "ST_Affine", "native", timeit(function() mesh_affine(m, tr)),
      timeit(function() geos_transform_xy(g, tr)),
      rel(abs(mesh_area(mesh_affine(m, tr))), geos_area(geos_transform_xy(g, tr))))

  ## ---- combinatorial ----
  add(nm, "ST_Perimeter", "combinatorial", best(function() mesh_perimeter(m), function() mesh_perimeter_c(m)),
      timeit(function() geos_length(g)), rel(mesh_perimeter(m), geos_length(g)))
  add(nm, "ST_Boundary", "combinatorial", timeit(function() mesh_boundary(m, once = FALSE)),
      timeit(function() geos_boundary(g)),
      rel(sum(geos_length(as_geos_geometry(mesh_boundary(m, once = FALSE)))),
          sum(geos_length(geos_boundary(g)))), "total length")
  np <- mesh_num_parts(m)
  ng <- geos_num_geometries(g)
  parts <- geos_geometry_n(rep(g, ng), sequence(ng))
  holes <- as.vector(rowsum(geos_num_interior_rings(parts), rep(seq_along(g), ng))[, 1])
  add(nm, "ST_NumGeometries + NumInteriorRings", "combinatorial",
      best(function() mesh_num_parts(m), function() mesh_num_parts_c(m)),
      timeit(function() {
        ng <- geos_num_geometries(g)
        rowsum(geos_num_interior_rings(geos_geometry_n(rep(g, ng), sequence(ng))), rep(seq_along(g), ng))
      }),
      sum(np[, "parts"] != ng | np[, "holes"] != holes), "features that differ")
  tree <- geos_strtree(g)
  gt <- geos_touches_matrix(g, tree)
  add(nm, "ST_Touches (all pairs)", "combinatorial", timeit(function() mesh_touches(m)),
      timeit(function() geos_touches_matrix(g, geos_strtree(g))),
      same_lists(mesh_touches(m), gt), "features whose lists differ")
  vp <- mesh_vertex_pairs(m)
  gp <- geos_pairs(g)
  r_mesh <- mesh_relate(m, gp$x, gp$y)
  r_geos <- geos_relate(g[gp$x], g[gp$y])
  add(nm, "ST_Relate (full DE-9IM)", "combinatorial",
      timeit(function() { p <- mesh_vertex_pairs(m); mesh_relate(m, p[, 1], p[, 2]) }),
      timeit(function() { k <- geos_pairs(g); geos_relate(g[k$x], g[k$y]) }),
      sum(r_mesh != r_geos), sprintf("pairs that differ of %d", nrow(gp)))
  cx <- geos_x(geos_centroid(g))
  grp <- if (length(g) > 10) as.integer(cut(cx, 8)) else rep(1L, length(g))
  check_union <- function(u, ref) {
    u <- as_geos_geometry(u)
    max(geos_area(geos_sym_difference(u, ref)) / geos_area(ref))
  }
  og <- order(grp)
  ref_union <- geos_unary_union(geos_make_collection(g[og], feature_id = grp[og]))
  add(nm, "ST_Union_Agg (grouped)", "combinatorial", timeit(function() mesh_union(m, grp)),
      timeit(function() geos_unary_union(geos_make_collection(g[og], feature_id = grp[og]))),
      check_union(mesh_union(m, grp), ref_union), "sym. difference / area")
  add(nm, "ST_CoverageUnion (grouped)", "combinatorial", timeit(function() mesh_union(m, grp)),
      timeit(function() geos_coverage_union(geos_make_collection(g[og], feature_id = grp[og]))),
      check_union(mesh_union(m, grp), ref_union), "sym. difference / area")

  ## ---- near-native ----
  set.seed(1)
  px <- runif(1e5, bb[1], bb[3]); py <- runif(1e5, bb[2], bb[4])
  P <- geos_make_point(px, py)
  hit <- geos_intersects_matrix(P, tree)
  first <- vapply(hit, function(i) if (length(i)) as.integer(i[1]) else NA_integer_, 1L)
  loc <- mesh_locate(m, px, py)
  add(nm, "ST_Intersects(point), 1e5 points", "near-native",
      timeit(function() mesh_locate(m, px, py)),
      min(timeit(function() geos_intersects_matrix(P, geos_strtree(g))),
          if (length(g) <= 100) timeit(function() lapply(seq_along(g), function(i) which(geos_prepared_intersects(g[i], P)))) else Inf),
      sum(xor(is.na(loc), is.na(first)) | (!is.na(loc) & !is.na(first) & loc != first)),
      "points in a different feature")
  big <- which.max(a)
  P4 <- P[1:1e4]
  dm <- mesh_distance(m, px[1:1e4], py[1:1e4], big)
  stopifnot(isTRUE(all.equal(dm, mesh_distance_grid(m, px[1:1e4], py[1:1e4], big))))
  dg <- geos_distance(P4, g[big])
  add(nm, "ST_Distance(point, feature), 1e4", "near-native",
      best(function() mesh_distance(m, px[1:1e4], py[1:1e4], big),
           function() mesh_distance_grid(m, px[1:1e4], py[1:1e4], big)),
      timeit(function() geos_prepared_distance(g[big], P4)),
      max(abs(dm - dg)) / max(bb[3] - bb[1], bb[4] - bb[2]))
  box <- c(bb[1] + 0.3 * (bb[3] - bb[1]), bb[2] + 0.2 * (bb[4] - bb[2]),
           bb[1] + 0.7 * (bb[3] - bb[1]), bb[2] + 0.6 * (bb[4] - bb[2]))
  rect <- geos_create_rectangle(box[1], box[2], box[3], box[4])
  ca <- geos_area(geos_clip_by_rect(g, wk::rct(box[1], box[2], box[3], box[4])))
  add(nm, "ST_ClipByBox2D", "near-native", timeit(function() mesh_clip_box(m, box)),
      timeit(function() geos_clip_by_rect(g, wk::rct(box[1], box[2], box[3], box[4]))),
      max(abs(mesh_clip_box(m, box)$area - ca)) / max(a), "area / largest feature")
  stopifnot(isTRUE(all.equal(mesh_convex_hull_area(m), mesh_convex_hull_area_c(m))))
  add(nm, "ST_ConvexHull", "near-native",
      best(function() mesh_convex_hull_area(m), function() mesh_convex_hull_area_c(m)),
      timeit(function() geos_convex_hull(g)),
      rel(mesh_convex_hull_area(m), geos_area(geos_convex_hull(g))), "area")

  ## ---- fallback: dissolve to polygons, then geos ----
  d <- 0.005 * max(bb[3] - bb[1], bb[4] - bb[2])
  add(nm, "ST_Buffer", "fallback", timeit(function() mesh_fallback(m, geos_buffer, d)),
      timeit(function() geos_buffer(g, d)),
      rel(geos_area(mesh_fallback(m, geos_buffer, d)), geos_area(geos_buffer(g, d))), "area")
  ## the answer depends on where each ring starts, which the dissolve sets,
  ## so it is checked as valid rather than equal
  add(nm, "ST_SimplifyPreserveTopology", "fallback",
      timeit(function() mesh_fallback(m, geos_simplify_preserve_topology, d / 10)),
      timeit(function() geos_simplify_preserve_topology(g, d / 10)),
      sum(!geos_is_valid(mesh_fallback(m, geos_simplify_preserve_topology, d / 10))),
      "invalid results (ring starts differ, so not compared)")

  ## ---- the producer: the mesh is what these return ----
  add(nm, "ST_ConstrainedDelaunayTriangles", "producer",
      build, timeit(function() geos_constrained_delaunay_triangles(g)),
      NA, "mesh: one polymer build of the whole layer; geos: per feature")
}

## ---- overlay between two layers: relations and intersection areas ----
cat("\n== nc x grid ==\n")
g <- layers$nc
ext <- geos_extent(g)
bb <- c(min(ext$xmin), min(ext$ymin), max(ext$xmax), max(ext$ymax))
gx <- seq(bb[1], bb[3], length.out = 21); gy <- seq(bb[2], bb[4], length.out = 9)
cells <- expand.grid(i = 1:20, j = 1:8)
grid <- geos_create_rectangle(gx[cells$i], gy[cells$j], gx[cells$i + 1], gy[cells$j + 1])
## a rotated grid so that edges cross the counties at general angles
grid <- geos_transform_xy(grid, wk::wk_affine_compose(
  wk::wk_affine_translate(-mean(bb[c(1, 3)]), -mean(bb[c(2, 4)])), wk::wk_affine_rotate(17),
  wk::wk_affine_translate(mean(bb[c(1, 3)]), mean(bb[c(2, 4)]))))
ov_build <- timeit(function() polymer::polymer(g, grid))
pm2 <- polymer::polymer(g, grid)
m2 <- mesh_from_polymer(pm2)
sizes$overlay <- data.frame(layer = "nc x grid", features = length(g) + length(grid),
                            polygon_coords = sum(geos_num_coordinates(c(g, grid))),
                            mesh_vertices = length(m2$x), triangles = length(m2$v0),
                            build_s = ov_build)
print(sizes$overlay)
k <- geos_inner_join_keys(g, grid, "intersects")
r_mesh <- mesh_relate(m2, k$x, length(g) + k$y)
r_geos <- geos_relate(g[k$x], grid[k$y])
add("nc x grid", "ST_Relate (between layers)", "near-native",
    ov_build + timeit(function() mesh_relate(m2, k$x, length(g) + k$y)),
    timeit(function() { k <- geos_inner_join_keys(g, grid, "intersects"); geos_relate(g[k$x], grid[k$y]) }),
    sum(r_mesh != r_geos), sprintf("pairs that differ of %d (mesh time includes the build)", nrow(k)))
## intersection area of every county x cell pair, from triangle labels
pair_area <- function(m2, n1) {
  t <- mem_tri(m2); f <- m2$mem
  a1 <- f <= n1
  t1 <- t[a1]; f1 <- f[a1]; t2 <- t[!a1]; f2 <- f[!a1] - n1
  j <- match(t1, t2)   # one grid cell per triangle at most (the grid is a coverage)
  ok <- !is.na(j)
  s <- rowsum(tri_area(m2)[t1[ok]], paste(f1[ok], f2[j[ok]]))
  s[, 1]
}
pa <- pair_area(m2, length(g))
gi <- geos_area(geos_intersection(g[k$x], grid[k$y]))
names(gi) <- paste(k$x, k$y)
gi <- gi[gi > 0]
add("nc x grid", "ST_Intersection (areas, all pairs)", "near-native",
    ov_build + timeit(function() pair_area(m2, length(g))),
    timeit(function() { k <- geos_inner_join_keys(g, grid, "intersects")
                        geos_area(geos_intersection(g[k$x], grid[k$y])) }),
    max(abs(pa[names(gi)] - gi) / gi), sprintf("%d pieces (mesh time includes the build)", length(gi)))

timings <- do.call(rbind, timings); checks <- do.call(rbind, checks); sizes <- do.call(rbind, sizes)
write.csv(timings, file.path(out, "timings.csv"), row.names = FALSE)
write.csv(checks, file.path(out, "checks.csv"), row.names = FALSE)
write.csv(sizes, file.path(out, "sizes.csv"), row.names = FALSE)
writeLines(c(R.version.string,
             paste("geos", packageVersion("geos"), "GEOS", geos_version()),
             paste("wk", packageVersion("wk"), "wkpool", packageVersion("wkpool"),
                   "polymer", packageVersion("polymer"), "cdtr", packageVersion("cdtr")),
             paste("cores", parallel::detectCores())),
           file.path(out, "session.txt"))
