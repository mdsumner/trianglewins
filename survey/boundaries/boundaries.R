## Drawing each boundary once: the numbers and figures for survey/boundaries.md
##
## Needs sf (>= 1.0) and wkpool (>= 0.4.0). Natural Earth 10m layers are read
## from the natural-earth-vector repository on GitHub and cached in NE_DIR.
##   Rscript survey/boundaries/boundaries.R
## Writes docs/boundaries/*.png and survey/boundaries/results.txt.
suppressMessages({library(sf); library(wkpool)})
sf_use_s2(FALSE)
ne_dir <- Sys.getenv("NE_DIR", file.path(tempdir(), "ne"))
out <- "docs/boundaries"
dir.create(ne_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(out, showWarnings = FALSE, recursive = TRUE)
res <- file("survey/boundaries/results.txt", "w")
say <- function(...) { cat(..., "\n", sep = ""); cat(..., "\n", sep = "", file = res) }

ne_read <- function(layer) {
  base <- "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/10m_cultural/"
  for (ext in c("shp", "shx", "dbf", "prj")) {
    f <- file.path(ne_dir, paste0(layer, ".", ext))
    if (!file.exists(f)) download.file(paste0(base, layer, ".", ext), f, mode = "wb", quiet = TRUE)
  }
  st_read(file.path(ne_dir, paste0(layer, ".shp")), quiet = TRUE)
}

## ---- the edge table -------------------------------------------------------
## One row per distinct undirected edge of a polygon layer, with the number of
## features that own it (n) and the first two owners (a, b; b is NA when n = 1).
edge_table <- function(geom) {
  pool <- merge_coincident(establish_topology(wk::as_wkb(geom)))
  s <- pool_segments(pool)
  v <- pool_vertices(pool)
  lo <- pmin(s$.vx0, s$.vx1)
  hi <- pmax(s$.vx0, s$.vx1)
  key <- paste(lo, hi)
  o <- order(key, s$.feature)
  key <- key[o]; f <- s$.feature[o]; lo <- lo[o]; hi <- hi[o]
  first <- !duplicated(key)
  i1 <- which(first)
  e <- data.frame(lo = lo[i1], hi = hi[i1], a = f[i1], n = tabulate(cumsum(first)))
  e$b <- ifelse(e$n >= 2, f[pmin(i1 + 1L, length(f))], NA_integer_)
  i <- match(c(e$lo, e$hi), v$.vx)
  m <- nrow(e)
  e$x0 <- v$x[i[1:m]]; e$y0 <- v$y[i[1:m]]
  e$x1 <- v$x[i[m + 1:m]]; e$y1 <- v$y[i[m + 1:m]]
  e$len <- sqrt((e$x1 - e$x0)^2 + (e$y1 - e$y0)^2)
  structure(e, pool = pool)
}

## rank of an edge in a hierarchy: the first level (coarsest first) at which
## its two owners differ; edges with one owner are "outer"
edge_rank <- function(e, levels) {
  r <- rep("outer", nrow(e))
  sh <- which(e$n == 2)
  done <- rep(FALSE, length(sh))
  for (nm in names(levels)) {
    lv <- levels[[nm]]
    hit <- !done & lv[e$a[sh]] != lv[e$b[sh]]
    r[sh[hit]] <- nm
    done <- done | hit
  }
  r[sh[!done]] <- "same"
  r
}

## arcs (TopoJSON-style) with the rank of the edge they run along
arc_lines <- function(e, rank) {
  pool <- attr(e, "pool")
  arcs <- find_arcs(pool, quotient = TRUE)
  v <- pool_vertices(pool)
  k <- paste(pmin(e$lo, e$hi), pmax(e$lo, e$hi))
  a1 <- vapply(arcs, `[`, 1L, 1L); a2 <- vapply(arcs, `[`, 1L, 2L)
  ar <- rank[match(paste(pmin(a1, a2), pmax(a1, a2)), k)]
  geom <- lapply(arcs, function(ix) { j <- match(ix, v$.vx); st_linestring(cbind(v$x[j], v$y[j])) })
  st_sf(rank = ar, geometry = st_sfc(geom, crs = 4326))
}

## canonical coordinate key for an undirected segment
ckey <- function(x0, y0, x1, y1) {
  sw <- x0 > x1 | (x0 == x1 & y0 > y1)
  ifelse(sw, paste(x1, y1, x0, y0), paste(x0, y0, x1, y1))
}
## distance from each segment midpoint of A to the nearest segment of B
mid_distance <- function(A, B) {
  seg <- function(d) st_sfc(lapply(seq_len(nrow(d)), function(i)
    st_linestring(matrix(c(d$x0[i], d$x1[i], d$y0[i], d$y1[i]), 2))))
  Bl <- seg(B)
  mid <- st_sfc(lapply(seq_len(nrow(A)), function(i)
    st_point(c((A$x0[i] + A$x1[i]) / 2, (A$y0[i] + A$y1[i]) / 2))))
  nn <- st_nearest_feature(mid, Bl)
  as.numeric(st_distance(mid, Bl[nn], by_element = TRUE))
}
## A against B: share of A's length matched exactly, lying on B (<= 1e-9),
## and further away than 1e-9 and than 0.1 (coordinate units)
compare_edges <- function(A, B) {
  ex <- ckey(A$x0, A$y0, A$x1, A$y1) %in% ckey(B$x0, B$y0, B$x1, B$y1)
  d <- rep(0, nrow(A))
  if (any(!ex)) d[!ex] <- mid_distance(A[!ex, ], B)
  L <- sum(A$len)
  list(exact = sum(A$len[ex]) / L, on = sum(A$len[!ex & d <= 1e-9]) / L,
       off = sum(A$len[d > 1e-9]) / L, far = sum(A$len[d > 0.1]) / L,
       d = d, ex = ex)
}
pct <- function(x) sprintf("%.2f%%", 100 * x)

## ---- data -----------------------------------------------------------------
a0 <- ne_read("ne_10m_admin_0_countries")
a1 <- ne_read("ne_10m_admin_1_states_provinces")
a2 <- ne_read("ne_10m_admin_2_counties")

## ---- 1. US counties: one edge table -----------------------------------------
t <- system.time(ec <- edge_table(st_geometry(a2)))
say("US counties: ", nrow(a2), " features, ", nrow(pool_segments(attr(ec, "pool"))),
    " ring segments, ", nrow(ec), " distinct edges (", sum(ec$n == 2), " shared, ",
    sum(ec$n == 1), " outer, ", sum(ec$n > 2), " with more than two owners), ",
    sprintf("%.1f", t[["elapsed"]]), " s")
ec$rank <- edge_rank(ec, list(state = a2$REGION, county = a2$FIPS))
say("county edges by rank: ", paste(names(table(ec$rank)), table(ec$rank), collapse = ", "))

## ---- 2. counties + Canadian and Mexican provinces: a mixed hierarchy -------
nb <- a1[a1$adm0_a3 %in% c("CAN", "MEX"), ]
mix <- data.frame(country = c(rep("USA", nrow(a2)), nb$adm0_a3),
                  state = c(paste0("US-", a2$REGION), nb$adm1_code),
                  county = c(a2$FIPS, nb$adm1_code))
gm <- c(st_geometry(a2), st_geometry(nb))
em <- edge_table(gm)
em$rank <- edge_rank(em, list(country = mix$country, state = mix$state, county = mix$county))
say("counties + CAN/MEX provinces: ", nrow(em), " edges; by rank: ",
    paste(names(table(em$rank)), table(em$rank), collapse = ", "),
    "; more than two owners: ", sum(em$n > 2))

## the land border from counties and provinces against NE's admin0 polygons
e0us <- edge_table(st_geometry(a0[a0$ADM0_A3 %in% c("USA", "CAN", "MEX"), ]))
cu <- compare_edges(e0us[e0us$n == 2, ], em[em$rank == "country", ])
say("NE admin0 USA/CAN/MEX shared edges vs county/province-derived country edges: exact ",
    pct(cu$exact), ", on the line ", pct(cu$on), ", off ", pct(cu$off))
mu <- em[em$rank == "outer", ]
cm <- compare_edges(mu, e0us[e0us$n == 2, ])
say("county/province outer edges lying on an admin0 land border (should have been shared): ",
    round(sum(mu$len[cm$ex | cm$d <= 1e-9]), 2), " degrees of ", round(sum(e0us$len[e0us$n == 2]), 2))

## ---- 3. NE state polygons against the county-derived state lines ---------
us <- a1[a1$adm0_a3 == "USA", ]
es <- edge_table(st_geometry(us))
cs <- compare_edges(es[es$n == 2, ], ec[ec$rank == "state", ])
say("NE US state polygons, shared edges vs county-derived state edges: exact ",
    pct(cs$exact), ", on the line ", pct(cs$on), ", off ", pct(cs$off))

## ---- 4. world: admin0 shared edges against admin1-derived country edges ---
e0 <- edge_table(st_geometry(a0))
e1 <- edge_table(st_geometry(a1))
e1$rank <- edge_rank(e1, list(country = a1$adm0_a3))
say("admin0: ", nrow(e0), " edges, ", sum(e0$n == 2), " shared, max owners ", max(e0$n),
    "; admin1: ", nrow(e1), " edges, ", sum(e1$n == 2), " shared, max owners ", max(e1$n))
say("outer length (degrees) admin0 ", round(sum(e0$len[e0$n == 1]), 2),
    ", admin1 ", round(sum(e1$len[e1$n == 1]), 2))
cw <- compare_edges(e0[e0$n == 2, ], e1[e1$rank == "country", ])
say("admin0 shared edges vs admin1-derived country edges: exact ", pct(cw$exact),
    ", on the line ", pct(cw$on), ", off ", pct(cw$off), ", more than 0.1 degree off ", pct(cw$far))
A <- e0[e0$n == 2, ]
off <- A[cw$d > 1e-9, ]
pair <- paste(pmin(a0$ADM0_A3[off$a], a0$ADM0_A3[off$b]), pmax(a0$ADM0_A3[off$a], a0$ADM0_A3[off$b]), sep = "-")
tb <- sort(tapply(off$len, pair, sum), decreasing = TRUE)
say("largest disagreements (degrees of border): ", paste(names(tb)[1:6], round(tb[1:6], 2), collapse = ", "))

## ---- figures ----------------------------------------------------------------
crs <- 5070
pal <- c(country = "#1b1b1b", state = "#5a5a5a", county = "#b8b8b8", outer = "#2a6f97")
lwd <- c(country = 2.4, state = 1.3, county = 0.5, outer = 0.9)

## Figure 1: stroking polygons versus drawing arcs, a corner of Iowa
cen <- st_coordinates(suppressWarnings(st_point_on_surface(st_geometry(a2))))
sub <- a2[cen[, 1] > -96.7 & cen[, 1] < -94.1 & cen[, 2] > 40.3 & cen[, 2] < 42.1, ]
es1 <- edge_table(st_geometry(sub))
lc <- arc_lines(es1, rep("any", nrow(es1)))
say("Figure 1: ", nrow(sub), " counties, ", nrow(pool_segments(attr(es1, "pool"))), " ring segments, ",
    nrow(es1), " edges, ", nrow(lc), " arcs")
png(file.path(out, "stroke-vs-arcs.png"), width = 1600, height = 760, res = 150)
par(mfrow = c(1, 2), mar = c(0.5, 0.5, 2, 0.5))
plot(st_geometry(sub), border = adjustcolor("black", 0.45), lwd = 4, lty = 2,
     main = "each polygon stroked")
plot(st_geometry(sub), border = NA, main = "each arc drawn once")
plot(st_geometry(lc), add = TRUE, col = adjustcolor("black", 0.45), lwd = 4, lty = 2)
dev.off()

## Figure 2: county, state and country lines from one pool
la <- arc_lines(em, em$rank)
la <- st_transform(la[la$rank != "same", ], crs)
png(file.path(out, "ranks.png"), width = 1800, height = 1150, res = 150)
par(mar = c(0, 0, 0, 0))
box <- st_bbox(c(xmin = -2500000, xmax = 2350000, ymin = 150000, ymax = 3250000), crs = st_crs(crs))
plot(st_as_sfc(box), border = NA)
for (r in c("county", "outer", "state", "country")) {
  g <- la[la$rank == r, ]
  plot(st_geometry(g), add = TRUE, col = pal[[r]], lwd = lwd[[r]])
}
legend("bottomleft", legend = c("country", "state or province", "county", "coast or edge of data"),
       col = pal[c("country", "state", "county", "outer")], lwd = lwd[c("country", "state", "county", "outer")] + 0.5,
       bty = "n", cex = 0.9)
dev.off()

## Figure 3: where exact matching fails
png(file.path(out, "mismatch.png"), width = 1800, height = 800, res = 150)
layout(matrix(1:2, 1), widths = c(1, 1.6))
par(mar = c(0.5, 0.5, 2, 0.5))
## (a) a stretch of the Kansas/Nebraska line: one state edge, many county vertices
ks <- es[es$n == 2 & us$postal[es$a] %in% c("KS", "NE") & us$postal[es$b] %in% c("KS", "NE"), ]
miss <- ks[!(ckey(ks$x0, ks$y0, ks$x1, ks$y1) %in% ckey(ec$x0, ec$y0, ec$x1, ec$y1)), ]
n_on <- vapply(seq_len(nrow(miss)), function(i) {
  s <- miss[i, ]
  w <- ec$x0 > min(s$x0, s$x1) & ec$x0 < max(s$x0, s$x1) &
    abs((ec$x0 - s$x0) * (s$y1 - s$y0) - (ec$y0 - s$y0) * (s$x1 - s$x0)) < 1e-9
  sum(w)
}, 1L)
s1 <- miss[which.max(n_on), ]
xr <- range(c(s1$x0, s1$x1)) + c(-0.08, 0.08)
yr <- mean(c(s1$y0, s1$y1)) + c(-1, 1) * diff(xr) * 0.45
cv <- ec[(ec$x0 >= xr[1] & ec$x0 <= xr[2] & ec$y0 >= yr[1] & ec$y0 <= yr[2]) |
         (ec$x1 >= xr[1] & ec$x1 <= xr[2] & ec$y1 >= yr[1] & ec$y1 <= yr[2]), ]
plot(NA, xlim = xr, ylim = yr, asp = 1 / cos(mean(yr) * pi / 180), axes = FALSE, xlab = "", ylab = "",
     main = "a state edge spans county corners")
segments(cv$x0, cv$y0, cv$x1, cv$y1, col = "grey60", lwd = 1)
segments(s1$x0, s1$y0, s1$x1, s1$y1, col = adjustcolor("#2a6f97", 0.5), lwd = 9)
points(c(s1$x0, s1$x1), c(s1$y0, s1$y1), pch = 21, bg = "#2a6f97", cex = 2)
on <- abs((cv$x0 - s1$x0) * (s1$y1 - s1$y0) - (cv$y0 - s1$y0) * (s1$x1 - s1$x0)) < 1e-9
points(cv$x0[on], cv$y0[on], pch = 19, cex = 0.9, col = "#b5302a")
legend("bottom", c("NE state polygon edge and its two vertices", "county vertices on that edge"),
       pch = c(21, 19), pt.bg = c("#2a6f97", NA), col = c("black", "#b5302a"), bg = "white", box.col = NA, cex = 0.8)
## (b) world: admin0 shared edges with no exact partner in the admin1 country lines
plot(st_geometry(a0), col = "grey95", border = NA, main = "admin0 borders that admin1 does not repeat exactly",
     xlim = c(-170, 180), ylim = c(-56, 80))
A$cls <- ifelse(cw$ex, "exact", ifelse(cw$d <= 1e-9, "on", "off"))
w <- A$cls == "exact"; segments(A$x0[w], A$y0[w], A$x1[w], A$y1[w], col = "grey55", lwd = 0.6)
w <- A$cls == "on"; segments(A$x0[w], A$y0[w], A$x1[w], A$y1[w], col = "#2a6f97", lwd = 2.5)
w <- A$cls == "off"; segments(A$x0[w], A$y0[w], A$x1[w], A$y1[w], col = "#b5302a", lwd = 2.5)
legend("bottomleft", c("exact match", "on the line, different vertices", "different line"),
       col = c("grey55", "#2a6f97", "#b5302a"), lwd = c(1, 2.5, 2.5), bty = "n", cex = 0.8)
dev.off()
close(res)
