## Build inst/extdata/<case>_vertices.csv and <case>_segments.csv from
## sf's nc.shp and anglr's cont_tas / cad_tas.
##
## Needs sf. anglr is archived on CRAN: point TRIANGLEWINS_ANGLR_DATA at the
## data/ folder of a clone of github.com/hypertidy/anglr if it is not
## installed. Run from the package root:
##   Rscript inst/scripts/make-extdata.R

library(sf)

## any sf lines or polygons -> deduplicated vertex pool + unique segments
## (the planar straight line graph silicate::SC0 gives anglr)
as_pslg_sf <- function(x) {
  g <- sf::st_geometry(x)
  if (any(sf::st_geometry_type(g) %in% c("POLYGON", "MULTIPOLYGON"))) g <- sf::st_cast(g, "MULTILINESTRING")
  co <- sf::st_coordinates(g)
  lcol <- grep("^L", colnames(co))
  path <- do.call(paste, as.data.frame(co[, lcol, drop = FALSE]))
  xy <- co[, 1:2]
  n <- nrow(xy)
  same <- c(path[-1] == path[-n], FALSE)
  s0 <- which(same); s1 <- s0 + 1L
  key <- paste(xy[, 1], xy[, 2])
  u <- !duplicated(key); map <- match(key, key[u])
  P <- xy[u, , drop = FALSE]; s0 <- map[s0]; s1 <- map[s1]
  seg <- cbind(pmin(s0, s1), pmax(s0, s1))
  seg <- seg[!duplicated(seg) & seg[, 1] != seg[, 2], , drop = FALSE]
  list(x = unname(P[, 1]), y = unname(P[, 2]), s0 = seg[, 1], s1 = seg[, 2])
}

## polygons -> every ring with its own vertices and segments, nothing
## deduplicated: shared boundaries come in twice, as rings in full
as_rings_sf <- function(x) {
  co <- sf::st_coordinates(sf::st_cast(sf::st_geometry(x), "MULTILINESTRING"))
  lcol <- grep("^L", colnames(co))
  path <- do.call(paste, as.data.frame(co[, lcol, drop = FALSE]))
  last <- c(path[-1] != path[-length(path)], TRUE)
  keep <- !last                      ## drop each ring's closing vertex
  xy <- co[keep, 1:2]; path <- path[keep]
  n <- nrow(xy)
  nxt <- c(path[-1] == path[-n], FALSE)
  first <- match(path, path)
  s1 <- ifelse(nxt, seq_len(n) + 1L, first)
  list(x = unname(xy[, 1]), y = unname(xy[, 2]), s0 = seq_len(n), s1 = s1)
}

anglr_data <- function(name) {
  if (requireNamespace("anglr", quietly = TRUE)) return(getExportedValue("anglr", name))
  dir <- Sys.getenv("TRIANGLEWINS_ANGLR_DATA")
  f <- file.path(dir, paste0(name, ".rda"))
  if (!nzchar(dir) || !file.exists(f)) stop("anglr data not found: set TRIANGLEWINS_ANGLR_DATA")
  e <- new.env(); load(f, envir = e); get(name, e)
}

write_case <- function(p, name, dir = "inst/extdata") {
  ## 17 significant digits round-trip doubles exactly
  v <- data.frame(x = format(p$x, digits = 17, trim = TRUE),
                  y = format(p$y, digits = 17, trim = TRUE))
  utils::write.csv(v, file.path(dir, paste0(name, "_vertices.csv")), row.names = FALSE, quote = FALSE)
  utils::write.csv(data.frame(s0 = p$s0, s1 = p$s1), file.path(dir, paste0(name, "_segments.csv")),
                   row.names = FALSE, quote = FALSE)
  cat(name, ":", length(p$x), "vertices,", length(p$s0), "segments\n")
}

nc <- sf::st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
write_case(as_pslg_sf(nc), "nc")
write_case(as_rings_sf(nc), "nc_rings")
write_case(as_pslg_sf(sf::st_as_sf(anglr_data("cont_tas"))), "cont_tas")
write_case(as_pslg_sf(sf::st_as_sf(anglr_data("cad_tas"))), "cad_tas")
