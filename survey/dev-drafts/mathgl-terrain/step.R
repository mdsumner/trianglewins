## Example 1: an oblique cliff (the roadmap's "step" fixture) on a curved
## background, 257 x 257 samples. Compare Delatin, the same greedy refinement
## without constraints, and greedy refinement with the cliff's top and bottom
## edges as 3D breaklines.
source("survey/dev-drafts/mathgl-terrain/greedy-tin.R")

source("survey/dev-drafts/mathgl-terrain/step-surface.R")
g <- expand.grid(x = 0:(W - 1), y = 0:(H - 1))
z <- matrix(surface(g$x, g$y), H, W, byrow = TRUE)

## breaklines: lines d = -half and d = +half, clipped to the grid, one vertex per 4 cells
breakline <- function(off, step = 4) {
  ux <- cos(th); uy <- sin(th); px <- cx0 - off * sin(th); py <- cy0 + off * cos(th)
  tt <- c((0 - px) / ux, (W - 1 - px) / ux, (0 - py) / uy, (H - 1 - py) / uy)
  tt <- sort(tt)[2:3]                       # entry and exit of the square
  n <- ceiling(diff(tt) / step)
  s <- seq(tt[1], tt[2], length.out = n + 1)
  cbind(x = px + s * ux, y = py + s * uy)
}
bl <- list(breakline(-half), breakline(half))
cx <- unlist(lapply(bl, `[`, , 1)); cy <- unlist(lapply(bl, `[`, , 2))
cz <- surface(cx, cy)
n1 <- nrow(bl[[1]]); n2 <- nrow(bl[[2]])
s0 <- c(seq_len(n1 - 1), n1 + seq_len(n2 - 1)); s1 <- s0 + 1L

res <- list(); meshes <- list()
for (tol in c(0.25, 0.5, 1, 2)) {
  d <- run_delatin(z, tol)
  a <- greedy_tin(z, tol, frac = 0.85)
  b <- greedy_tin(z, tol, cx, cy, cz, s0, s1, erase = "hull", frac = 0.85)
  for (m in list(list("delatin", d), list("greedy", a), list("greedy + breaklines", b))) {
    e <- mesh_error(m[[2]]$P, m[[2]]$T, z)
    ce <- surface_error(m[[2]]$P, m[[2]]$T, surface, W, H)
    res[[length(res) + 1]] <- data.frame(fixture = "step", tol = tol, method = m[[1]],
      triangles = nrow(m[[2]]$T), vertices = nrow(m[[2]]$P),
      max_err = e[["max"]], rmse = e[["rmse"]],
      cont_max = ce[["cont_max"]], cont_rmse = ce[["cont_rmse"]], seconds = m[[2]]$seconds)
    if (tol == 0.5) meshes[[m[[1]]]] <- m[[2]]
  }
}
res <- do.call(rbind, res)
print(res, digits = 3)
dir.create("survey/dev-drafts/mathgl-terrain/results", showWarnings = FALSE)
write.csv(res, "survey/dev-drafts/mathgl-terrain/results/step.csv", row.names = FALSE)
saveRDS(list(z = z, meshes = meshes, breaklines = bl), "survey/dev-drafts/mathgl-terrain/cache/ex1-step.rds")
