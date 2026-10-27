test_that("every case is a well-formed planar straight line graph", {
  for (cs in tw_cases()) {
    expect_equal(length(cs$x), length(cs$y), info = cs$name)
    expect_equal(length(cs$s0), length(cs$s1), info = cs$name)
    if (length(cs$s0)) {
      expect_true(all(c(cs$s0, cs$s1) >= 1 & c(cs$s0, cs$s1) <= length(cs$x)), info = cs$name)
    }
    expect_true(cs$region %in% c("outer", "hull"), info = cs$name)
    expect_true(nzchar(cs$note), info = cs$name)
  }
})

test_that("the doubled grid repeats what the deduplicated grid gives once", {
  d <- tw_case("grid3_doubled"); u <- tw_case("grid3_dedup")
  expect_equal(length(d$x), 36L); expect_equal(length(d$s0), 36L)
  expect_equal(length(u$x), 16L); expect_equal(length(u$s0), 24L)
})

test_that("the NSIDC inverse matches PROJ", {
  ## PROJ 9 (pyproj 3.8), EPSG:3412 to EPSG:4326
  ll <- ps_south_inverse(c(-112500, 12500, 990000, -112500),
                         c(3300000, -112500, -2000000, 3525000))
  expect_equal(ll[, "lon"], c(-1.95250905, 173.65980825, 153.66459, -1.82796824), tolerance = 1e-8)
  expect_equal(ll[, "lat"], c(-60.18411849, -88.95513968, -69.60906415, -58.24930224), tolerance = 1e-8)
})

test_that("grid cases carry their index and quad edges", {
  q <- tw_case("grid_quads")
  expect_equal(length(q$x), 100L)
  expect_equal(length(q$s0), 180L)
  expect_equal(dim(q$ij), c(100L, 2L))
  ## every constraint joins index neighbours
  expect_true(all(abs(q$ij[q$s0, 1] - q$ij[q$s1, 1]) + abs(q$ij[q$s0, 2] - q$ij[q$s1, 2]) == 1))
  expect_equal(tw_case("grid_frames_lonlat")$x, q$x)
  f <- tw_case("grid_frames_3412")
  expect_equal(diff(sort(unique(f$x))), rep(25000, 9))
  d <- tw_case("grid_diagonal")
  expect_equal(c(length(d$x), length(d$s0)), c(16L, 24L))
})

## an ni x nj grid of nodes split into triangles in index space
grid_split <- function(ni, nj, diagonal = c("ne", "nw")) {
  diagonal <- match.arg(diagonal)
  id <- function(i, j) i + ni * j + 1L
  c0 <- expand.grid(i = seq_len(ni - 1L) - 1L, j = seq_len(nj - 1L) - 1L)
  a <- id(c0$i, c0$j); b <- id(c0$i + 1L, c0$j)
  c <- id(c0$i + 1L, c0$j + 1L); d <- id(c0$i, c0$j + 1L)
  if (diagonal == "ne") data.frame(v0 = c(a, a), v1 = c(b, c), v2 = c(c, d))
  else data.frame(v0 = c(a, b), v1 = c(b, c), v2 = c(d, d))
}

test_that("tw_in_cell finds quad halves and their diagonal", {
  cs <- tw_case("grid_diagonal")
  v <- data.frame(x = cs$x, y = cs$y)
  ne <- tw_in_cell(list(vertices = v, triangles = grid_split(4, 4, "ne")), cs)
  nw <- tw_in_cell(list(vertices = v, triangles = grid_split(4, 4, "nw")), cs)
  expect_equal(unname(ne), c(1, 1))
  expect_equal(unname(nw), c(1, 0))
  ## a triangle across two cells, and one with a Steiner vertex
  tt <- rbind(grid_split(4, 4, "ne"), data.frame(v0 = 1L, v1 = 3L, v2 = 17L))
  v2 <- rbind(v, data.frame(x = 0.5, y = 0.5))
  expect_equal(tw_in_cell(list(vertices = v2, triangles = tt), cs)[["in_cell"]], 18 / 19)
  expect_true(all(is.na(tw_in_cell(list(vertices = v, triangles = grid_split(4, 4)),
                                   tw_case("square")))))
})
