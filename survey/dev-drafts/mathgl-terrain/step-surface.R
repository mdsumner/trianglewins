W <- H <- 257L
th <- 30 * pi / 180
cx0 <- (W - 1) / 2; cy0 <- (H - 1) / 2
half <- 2
drop_m <- 40
surface <- function(x, y) {
  d <- -(x - cx0) * sin(th) + (y - cy0) * cos(th)
  20 * sin(x / 37) * cos(y / 41) + 0.05 * x + drop_m * pmin(pmax((d + half) / (2 * half), 0), 1)
}
