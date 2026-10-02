## each installed backend on the small cases; the rest are skipped
for (b in names(tw_backends())) {
  test_that(paste(b, "keeps segments and depth on nested rings"), {
    skip_if_not_installed(b)
    r <- tw_run(b, cases = c("square_hole", "nested3"), scenarios = c("constrained", "area"),
                time = FALSE)
    expect_true(all(r$status == "ok"))
    expect_true(all(r$segs_kept == 1))
    expect_true(all(r$cd_violations == 0))
    expect_true(all(r$area_ok[r$scenario == "area"] == 1))
    if (b != "RTriangle") expect_true(all(r$depth_match == "k=1"))
  })
}

test_that("a missing backend gives skipped rows, not an error", {
  r <- trianglewins:::bind_rows(list(
    data.frame(backend = "a", status = "ok", n = 1),
    data.frame(backend = "b", status = "skipped")))
  expect_equal(nrow(r), 2L)
  expect_true(is.na(r$n[2]))
})
