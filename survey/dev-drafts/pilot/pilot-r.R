## R side of the pilot: wkpool as a producer and a consumer.
##   Rscript survey/dev-drafts/pilot/pilot-r.R <inlandwaters.rda> <outdir> [python-parquet]
args <- commandArgs(TRUE)
here <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))
source(file.path(here, "geoarrow_triangles.R"))
suppressMessages(library(wkpool))
out <- args[2]; dir.create(out, showWarnings = FALSE)
res <- list()
clock <- function(label, expr) {
  t0 <- proc.time()[["elapsed"]]; v <- expr
  res[[label]] <<- round(proc.time()[["elapsed"]] - t0, 3); v
}

## producer: inlandwaters -> wkpool_tri -> geoarrow.triangles
load(args[1])
g <- wk::as_wkb(sf::st_geometry(inlandwaters))
tri <- clock("triangulate_s", merge_coincident(pool_triangulate(establish_topology(g))))
m <- clock("export_s", ga_from_wkpool_tri(tri))
res$features <- length(g); res$vertices <- nrow(m$xy); res$triangles <- nrow(m$tri)
meta <- list(vertex_identity = "exact_float")
a <- clock("dictionary_array_s", ga_triangles_array(m$xy, m$tri, meta))
d <- clock("decoded_array_s", ga_triangles_decoded(m$xy, m$tri, meta))
tab_d <- ga_table(a, feature = as.integer(m$feature))
tab_p <- ga_table(d, feature = as.integer(m$feature))
arrow::write_ipc_file(arrow::as_record_batch(tab_d), file.path(out, "inlandwaters.arrow"))
arrow::write_parquet(arrow::as_arrow_table(tab_p), file.path(out, "inlandwaters.parquet"),
                     compression = "zstd")
write.csv(data.frame(v0 = m$tri[, 1], v1 = m$tri[, 2], v2 = m$tri[, 3]),
          file.path(out, "inlandwaters-ids.csv"), row.names = FALSE)

## consumer: read the decoded Parquet back and pool with wkpool
pt <- arrow::read_parquet(file.path(out, "inlandwaters.parquet"), as_data_frame = FALSE)
f <- pt$schema$GetFieldByName("triangles")
res$parquet_field_metadata <- f$metadata[["ARROW:extension:name"]]
back <- clock("parquet_read_pool_s", {
  pts <- ga_decoded_coords(pt$triangles)
  ga_decoded_to_wkpool_tri(pts$x, pts$y)
})
mb <- ga_from_wkpool_tri(back)
res$wkpool_ids_preserved <- identical(mb$tri, m$tri)
res$wkpool_coords_equal <- identical(mb$xy, m$xy)

## consumer: a Parquet file written by the Python pilot
if (length(args) > 2) {
  pp <- arrow::read_parquet(args[3], as_data_frame = FALSE)
  pb <- clock("python_parquet_pool_s", {pts <- ga_decoded_coords(pp$triangles)
 ga_decoded_to_wkpool_tri(pts$x, pts$y)})
  res$python_parquet_triangles <- length(pb)
  res$python_parquet_vertices <- nrow(pool_vertices(pb))
  ids_py <- as.matrix(read.csv(sub("\\.parquet$", "-ids.csv", args[3])))
  res$python_parquet_ids_equal <- identical(unname(ga_from_wkpool_tri(pb)$tri), unname(ids_py))
}
res$versions <- lapply(c("nanoarrow", "wkpool", "wk", "arrow"),
                       function(p) as.character(packageVersion(p)))
names(res$versions) <- c("nanoarrow", "wkpool", "wk", "arrow")
cat(jsonlite::toJSON(res, auto_unbox = TRUE, pretty = TRUE), "\n")
