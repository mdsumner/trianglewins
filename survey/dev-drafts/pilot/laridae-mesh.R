## Real constrained meshes from laridae through the geoarrow.triangles pilot.
##   Rscript survey/dev-drafts/pilot/laridae-mesh.R <inlandwaters.rda> <outdir>
## Needs laridae from the exact-cdt branch (lari_cdt()).
args <- commandArgs(TRUE)
here <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))
source(file.path(here, "geoarrow_triangles.R"))
suppressMessages({library(wkpool); library(laridae)})
out <- args[2]; dir.create(out, showWarnings = FALSE)
res <- list()
clock <- function(label, expr) {
  t0 <- proc.time()[["elapsed"]]; v <- expr
  res[[label]] <<- round(proc.time()[["elapsed"]] - t0, 3); v
}

## Export laridae tables (1-based) as geoarrow.triangles plus a vertex table
## keyed by dictionary index. Vertices are renumbered by first appearance.
ga_export_lari <- function(tab, name, meta) {
  v <- tab$vertices; t <- tab$triangles
  ids <- cbind(t$v0, t$v1, t$v2)
  flat <- as.vector(t(ids)); order <- unique(flat)
  tri <- matrix(match(flat, order) - 1L, ncol = 3, byrow = TRUE)
  xy <- cbind(v$x, v$y)[order, , drop = FALSE]
  ## constrained flag for edge k = v[k] -> v[k + 1]
  key <- function(a, b) paste(pmin(a, b), pmax(a, b))
  seg <- key(tab$segments$v0, tab$segments$v1)
  cons <- cbind(key(ids[, 1], ids[, 2]) %in% seg, key(ids[, 2], ids[, 3]) %in% seg,
                key(ids[, 3], ids[, 1]) %in% seg)
  cons_arr <- as_nanoarrow_array(as.vector(t(cons)), schema = na_bool())
  cons_fsl <- nanoarrow_array_modify(nanoarrow_array_init(na_fixed_size_list(na_bool(), 3L)),
                                     list(length = nrow(tri), null_count = 0L,
                                          children = list(cons_arr)), validate = FALSE)
  cons_fsl <- nanoarrow_array_set_schema(cons_fsl,
    na_fixed_size_list(nanoarrow_schema_modify(na_bool(), list(flags = 0L)), 3L), validate = TRUE)
  sib <- list(constrained = cons_fsl)
  if (!is.null(t$depth)) sib$depth <- as.integer(t$depth)
  ## vertex table: one row per dictionary entry, in dictionary order
  vt <- data.frame(vertex = seq_along(order) - 1L, input_row = as.integer(order),
                   origin = factor(v$origin[order], levels = c("input", "crossing", "steiner")))
  for (k in intersect(c("x_num", "x_den", "y_num", "y_den"), names(v))) vt[[k]] <- v[[k]][order]
  a <- ga_triangles_array(xy, tri, meta)
  d <- ga_triangles_decoded(xy, tri, meta)
  arrow::write_ipc_file(arrow::as_record_batch(do.call(ga_table, c(list(a), sib))),
                        file.path(out, paste0(name, ".arrow")))
  arrow::write_parquet(arrow::as_arrow_table(do.call(ga_table, c(list(d), sib))),
                       file.path(out, paste0(name, ".parquet")), compression = "zstd")
  arrow::write_parquet(vt, file.path(out, paste0(name, "-vertices.parquet")), compression = "zstd")
  write.csv(data.frame(v0 = tri[, 1], v1 = tri[, 2], v2 = tri[, 3]),
            file.path(out, paste0(name, "-ids.csv")), row.names = FALSE)
  list(vertices = nrow(xy), unreferenced = nrow(v) - length(order), triangles = nrow(tri),
       origin = as.list(table(vt$origin)), constrained_edges = sum(cons),
       segments = nrow(tab$segments),
       ccw = all((xy[tri[, 2] + 1, 1] - xy[tri[, 1] + 1, 1]) * (xy[tri[, 3] + 1, 2] - xy[tri[, 1] + 1, 2]) -
                 (xy[tri[, 3] + 1, 1] - xy[tri[, 1] + 1, 1]) * (xy[tri[, 2] + 1, 2] - xy[tri[, 1] + 1, 2]) > 0))
}

## A. ACT, NSW (with Lord Howe Island) and Victoria from inlandwaters: a
## coverage with lakes, islands, and ACT as a hole in NSW filled by a polygon.
## B. minimal_mesh: the same properties, small enough to see the refinement.
lari_case <- function(g, name, n_target, data = args[1]) {
  pslg <- as_pslg(establish_topology(wk::as_wkb(g)))
  bb <- apply(pslg$P, 2, range)
  max_area <- prod(diff(bb)) / n_target
  tab <- clock(paste0(name, "_triangulate_s"),
               lari_triangulate(pslg$P[, 1], pslg$P[, 2], pslg$S[, 1], pslg$S[, 2],
                                max_area = max_area, min_angle = 25, erase = "outer"))
  c(list(input_vertices = nrow(pslg$P), input_segments = nrow(pslg$S),
         max_area = signif(max_area, 4)),
    ga_export_lari(tab, paste0("lari-", name), list(vertex_identity = "exact_float")))
}
d0 <- new.env(); load(args[1], envir = d0)
load(file.path(dirname(args[1]), "minimal_mesh.rda"), envir = d0)
res$vic_nsw_act <- lari_case(sf::st_geometry(d0$inlandwaters)[c(1, 3, 6)], "vic-nsw-act", 2e4)
res$minimal_mesh <- lari_case(sf::st_geometry(d0$minimal_mesh), "minimal-mesh", 400)

## B. polymer#7: 200 random lines buffered by 1 (flat caps), exact crossings
set.seed(1)
n <- 200
d <- data.frame(x = runif(n, -50, 50), y = runif(n, 0, 100), id = rep(seq_len(n / 2), each = 2))
ls <- sf::st_sfc(lapply(split(d, d$id), function(p) sf::st_linestring(cbind(p$x, p$y))))
b <- sf::st_buffer(ls, 1, endCapStyle = "FLAT")
res$polymer7_st_intersection <- tryCatch({sf::st_intersection(sf::st_sf(geometry = b)); "ok"},
                                         error = function(e) conditionMessage(e))
pb <- as_pslg(establish_topology(wk::as_wkb(b)))
for (exact in c(TRUE, FALSE)) {
  nm <- if (exact) "exact" else "double"
  B <- clock(paste0("polymer7_cdt_", nm, "_s"),
             lari_cdt(pb$P[, 1], pb$P[, 2], pb$S[, 1], pb$S[, 2], exact = exact))
  res[[paste0("polymer7_", nm)]] <- c(list(input_vertices = nrow(pb$P), input_segments = nrow(pb$S)),
    ga_export_lari(B, paste0("lari-polymer7-", nm),
                   list(vertex_identity = if (exact) "exact" else "noded")))
}
res$versions <- list(laridae = as.character(packageVersion("laridae")),
                     RcppCGAL = as.character(packageVersion("RcppCGAL")))
cat(jsonlite::toJSON(res, auto_unbox = TRUE, pretty = TRUE), "\n")
