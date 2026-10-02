## hand-built meshes, so the measures are checked without any backend
sq <- trianglewins:::new_case("sq", c(0, 1, 1, 0), c(0, 0, 1, 1), 1:4, c(2L, 3L, 4L, 1L))
mesh <- function(x, y, v0, v1, v2, depth = NA_integer_) {
  list(vertices = data.frame(x = x, y = y),
       triangles = data.frame(v0 = v0, v1 = v1, v2 = v2, depth = depth))
}

test_that("a square split in two passes everything", {
  m <- tw_measure(sq, mesh(sq$x, sq$y, c(1, 1), c(2, 3), c(3, 4), depth = c(1L, 1L)),
                  max_area = 0.5, min_angle = 45)
  expect_equal(m$n_triangles, 2L)
  expect_equal(m$n_added, 0L)
  expect_equal(m$area_total, 1)
  expect_equal(m$area_ok, 1)
  expect_equal(m$angle_ok, 1)
  expect_equal(m$segs_kept, 1)
  expect_equal(m$cd_violations, 0L)
  expect_equal(m$depth_k, "1:2")
  expect_equal(m$depth_match, "k=1")
})

test_that("a missing constraint and a non-Delaunay edge are caught", {
  ## a rhombus with the long diagonal constrained, triangulated on the short one
  cs <- trianglewins:::new_case("rh", c(0, 2, 4, 2), c(0, -0.5, 0, 0.5),
                                c(1L, 2L, 3L, 4L, 1L), c(2L, 3L, 4L, 1L, 3L))
  m <- tw_measure(cs, mesh(cs$x, cs$y, c(1, 2), c(2, 3), c(4, 4)))
  expect_equal(m$segs_kept, 4 / 5)
  ## the same mesh with no constraint on the diagonal is not Delaunay
  cs2 <- trianglewins:::new_case("rh2", cs$x, cs$y, 1:4, c(2L, 3L, 4L, 1L))
  m2 <- tw_measure(cs2, mesh(cs$x, cs$y, c(1, 1), c(2, 3), c(3, 4)))
  expect_equal(m2$cd_violations, 1L)
  expect_true(is.na(m2$depth_match))
})

test_that("harness depth counts covering segments", {
  ## two unit squares side by side, each its own ring: the shared edge is
  ## covered twice, but both squares touch the outside
  x <- c(0, 1, 1, 0, 1, 2, 2, 1); y <- c(0, 0, 1, 1, 0, 0, 1, 1)
  cs <- trianglewins:::new_case("two", x, y, 1:8, c(2L, 3L, 4L, 1L, 6L, 7L, 8L, 5L))
  ux <- c(0, 1, 1, 0, 2, 2); uy <- c(0, 0, 1, 1, 0, 1)
  m <- tw_measure(cs, mesh(ux, uy, c(1, 1, 2, 2), c(2, 3, 5, 6), c(3, 4, 6, 3)))
  expect_equal(m$segs_kept, 1)
  expect_equal(m$depth_k, "1:4")
  expect_equal(m$input_missing, 0L)
})

test_that("attribute error is zero for an exact linear field", {
  out <- list(vertices = data.frame(x = c(0, 1, 0.3), y = c(0, 1, 0.2)))
  out$vertices$z <- out$vertices$x + 2 * out$vertices$y
  expect_equal(tw_attr_error(out, sq), 0)
  out$vertices$z[3] <- out$vertices$z[3] + 0.3
  expect_equal(tw_attr_error(out, sq), 0.1)
})
