## Pack the example meshes for the deck.gl viewer: Float32 positions (x, y, z
## in metres, y up, centred), Uint32 0-based triangle indices, base64.
library(jsonlite)
b64 <- function(x, what = c("f32", "u32")) {
  what <- match.arg(what)
  con <- rawConnection(raw(0), "wb")
  if (what == "f32") writeBin(as.double(x), con, size = 4) else writeBin(as.integer(x), con, size = 4)
  r <- rawConnectionValue(con); close(con)
  base64_enc(r)
}
pack_mesh <- function(m, W, H, cell) {
  x <- (m$P[, 1] - (W - 1) / 2) * cell
  y <- ((H - 1) / 2 - m$P[, 2]) * cell
  list(positions = b64(as.vector(rbind(x, y, m$P[, 3]))),
       indices = b64(as.vector(t(m$T)) - 1L, "u32"),
       triangles = nrow(m$T), vertices = nrow(m$P))
}
pack_line <- function(xy, z, W, H, cell) {
  as.vector(rbind(round((xy[, 1] - (W - 1) / 2) * cell, 3), round(((H - 1) / 2 - xy[, 2]) * cell, 3), round(z, 3)))
}

e1 <- readRDS("survey/dev-drafts/mathgl-terrain/cache/ex1-step.rds"); W <- ncol(e1$z); H <- nrow(e1$z)
src1 <- new.env(); sys.source("survey/dev-drafts/mathgl-terrain/step-surface.R", envir = src1)
step <- list(
  title = "Oblique cliff", tol = 0.5, cell = 1, units = "grid units",
  meshes = lapply(e1$meshes, pack_mesh, W = W, H = H, cell = 1),
  lines = lapply(e1$breaklines, function(b) pack_line(b, src1$surface(b[, 1], b[, 2]), W, H, 1)))

e2 <- readRDS("survey/dev-drafts/mathgl-terrain/cache/ex2-coast.rds"); W2 <- ncol(e2$z); H2 <- nrow(e2$z)
cell2 <- e2$res_m * cos(42.88 * pi / 180)          # Web Mercator cell to ground metres
co <- as.data.frame(e2$coast); sg <- as.data.frame(e2$segs)
## coastline rings as polylines (coast-to-coast segments only)
cs <- which(co$coast[sg$s0] == 1 & co$coast[sg$s1] == 1)
lines2 <- lapply(cs, function(i) pack_line(rbind(c(co$cx[sg$s0[i]], co$cy[sg$s0[i]]), c(co$cx[sg$s1[i]], co$cy[sg$s1[i]])), c(0, 0), W2, H2, cell2))
## merge consecutive segments into runs to keep the payload small
merge_runs <- function(segs) {
  out <- list(); cur <- segs[[1]]
  for (s in segs[-1]) {
    if (isTRUE(all.equal(tail(cur, 3), s[1:3]))) cur <- c(cur, s[4:6]) else { out[[length(out) + 1]] <- cur; cur <- s }
  }
  c(out, list(cur))
}
hobart <- list(
  title = "Hobart coast", tol = 10, cell = cell2, units = "m",
  meshes = lapply(e2$meshes, pack_mesh, W = W2, H = H2, cell = cell2),
  lines = merge_runs(lines2))

## study 2: math.gl's own fixtures (meshes keyed by viewer slot)
fx <- readRDS("survey/dev-drafts/mathgl-terrain/cache/fixtures.rds")
zp <- fx$pacific$z; Wp <- ncol(zp); Hp <- nrow(zp); cellp <- fx$pacific$cell * cos(38 * pi / 180)
cop <- as.data.frame(fx$pacific$coast); names(cop) <- c("x", "y", "z", "coast")
sgp <- as.data.frame(fx$pacific$segs); names(sgp) <- c("s0", "s1")
csp <- which(cop$coast[sgp$s0] == 1 & cop$coast[sgp$s1] == 1)
pacific <- list(
  title = "Pacific coast (math.gl fixture)", tol = 20, cell = cellp, units = "m",
  slots = list(delatin = "delatin", lines = "greedy + coastline"),
  meshes = list(delatin = pack_mesh(fx$meshes[["pacific delatin"]], Wp, Hp, cellp),
                lines = pack_mesh(fx$meshes[["pacific greedy + coastline"]], Wp, Hp, cellp)),
  lines = merge_runs(lapply(csp, function(i) pack_line(rbind(c(cop$x[sgp$s0[i]], cop$y[sgp$s0[i]]), c(cop$x[sgp$s1[i]], cop$y[sgp$s1[i]])), c(0, 0), Wp, Hp, cellp))))
s <- fx$sierra; zs <- s$z; Ws <- ncol(zs); Hs <- nrow(zs); cells <- s$cell * cos(37 * pi / 180)
sg <- s$segs
sierra <- list(
  title = "Sierra Nevada, nodata (math.gl fixture)", tol = 20, cell = cells, units = "m",
  slots = list(lines = "greedy + nodata boundary"),
  meshes = list(lines = pack_mesh(fx$meshes[["sierra greedy + nodata boundary"]], Ws, Hs, cells)),
  lines = merge_runs(lapply(seq_len(nrow(sg)), function(i) {
    xy <- rbind(c(s$ring_x[sg[i, 1]], s$ring_y[sg[i, 1]]), c(s$ring_x[sg[i, 2]], s$ring_y[sg[i, 2]]))
    pack_line(xy, zs[cbind(round(xy[, 2]) + 1, round(xy[, 1]) + 1)], Ws, Hs, cells)
  })))
fxs <- read.csv("survey/dev-drafts/mathgl-terrain/results/fixtures.csv")

stats <- list(step = read.csv("survey/dev-drafts/mathgl-terrain/results/step.csv"),
              hobart = read.csv("survey/dev-drafts/mathgl-terrain/results/coast.csv"),
              pacific = fxs[fxs$fixture == "pacific", ], sierra = fxs[fxs$fixture == "sierra-nodata", ])
writeLines(toJSON(list(fixtures = list(step = step, hobart = hobart, pacific = pacific, sierra = sierra), stats = stats),
                  auto_unbox = TRUE, digits = 6), "survey/dev-drafts/mathgl-terrain/cache/viewer-data.json")
cat(file.size("survey/dev-drafts/mathgl-terrain/cache/viewer-data.json") / 1e6, "MB\n")
