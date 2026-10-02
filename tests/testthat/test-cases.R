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
