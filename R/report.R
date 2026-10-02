fmt_pct <- function(v) ifelse(is.na(v), "", sprintf("%.1f", 100 * v))
fmt_num <- function(v, d = 3) ifelse(is.na(v), "", trimws(formatC(v, digits = d, format = "g")))
fmt_int <- function(v) ifelse(is.na(v), "", as.character(as.integer(v)))
fmt_txt <- function(v) {
  v <- ifelse(is.na(v), "", as.character(v))
  gsub("|", "/", v, fixed = TRUE)
}

md_table <- function(df) {
  hdr <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|")
  body <- apply(df, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |"))
  c(hdr, sep, body)
}

#' Write the results as Markdown
#'
#' A timing matrix, a depth-semantics table, and one table per case with
#' every measure.
#' @param results a data frame from [tw_run()] (optionally with
#'   [tw_run_dynamic()] rows bound on)
#' @param file output path, or NULL to return the lines
#' @param header lines to put first (e.g. versions and machine)
#' @return the lines, invisibly
#' @export
tw_report <- function(results, file = NULL, header = character(0)) {
  r <- results
  out <- c(header, "")
  backends <- unique(r$backend)

  ## timing matrix
  out <- c(out, "## Time (ms, median)", "",
           "Blank where the backend errored or was skipped; see the per-case tables.", "")
  key <- unique(r[c("case", "scenario")])
  tm <- key
  for (b in backends) {
    tm[[b]] <- vapply(seq_len(nrow(key)), function(i) {
      w <- r$backend == b & r$case == key$case[i] & r$scenario == key$scenario[i]
      if (!any(w) || r$status[w][1] != "ok") return("")
      fmt_num(r$time_ms[w][1])
    }, "")
  }
  out <- c(out, md_table(tm), "")

  ## depth semantics on the constrained runs
  cr <- r[r$scenario == "constrained" & r$status == "ok", ]
  if (nrow(cr)) {
    out <- c(out, "## Depth", "",
             paste("Harness depth is computed from the output triangles: crossing an edge costs",
                   "the number of input segments on it (k) or 1 if there is any (1).",
                   "`match` says which of the two the backend's own depth equals."), "")
    ## harness depth from the backend with the most triangles (all agree on
    ## constrained meshes unless one dropped part of the region)
    cr <- cr[order(cr$case, -cr$n_triangles), ]
    dk <- cr[!duplicated(cr$case), c("case", "depth_k", "depth_1")]
    dk <- dk[order(match(dk$case, unique(r$case))), ]
    dt <- data.frame(case = dk$case, `harness k` = dk$depth_k, `harness 1` = dk$depth_1,
                     check.names = FALSE)
    for (b in backends) {
      dt[[b]] <- vapply(seq_len(nrow(dk)), function(i) {
        w <- cr$backend == b & cr$case == dk$case[i]
        if (!any(w)) return("")
        fmt_txt(cr$depth_match[w][1])
      }, "")
    }
    out <- c(out, md_table(dt), "")
  }

  ## errors and skips
  bad <- r[r$status != "ok", ]
  if (nrow(bad)) {
    out <- c(out, "## Errors and skips", "")
    agg <- unique(bad[c("backend", "case", "status", "message")])
    agg$scenarios <- vapply(seq_len(nrow(agg)), function(i) {
      w <- bad$backend == agg$backend[i] & bad$case == agg$case[i] & bad$message %in% agg$message[i]
      paste(unique(bad$scenario[w]), collapse = ", ")
    }, "")
    agg$message <- fmt_txt(agg$message)
    out <- c(out, md_table(agg[c("backend", "case", "scenarios", "status", "message")]), "")
  }

  ## per case
  out <- c(out, "## Per case", "",
           paste("verts, tris: output counts; added: vertices not in the input; area ok / angle ok:",
                 "percent of triangles meeting the bound; min ang: smallest angle (degrees);",
                 "segs: percent of input segments present as chains of edges; CD viol: unconstrained",
                 "edges failing the empty-circle test; depth: the backend's own depth table",
                 "(depth:count); attr err: largest relative error of a linear attribute carried onto",
                 "new vertices; unrefined: what the backend says it could not do."), "")
  for (cs in unique(r$case)) {
    rc <- r[r$case == cs & r$status == "ok", ]
    if (!nrow(rc)) next
    out <- c(out, paste0("### ", cs), "")
    tb <- data.frame(
      scenario = rc$scenario, backend = rc$backend,
      verts = fmt_int(rc$n_vertices), tris = fmt_int(rc$n_triangles), added = fmt_int(rc$n_added),
      `area ok` = fmt_pct(rc$area_ok), `min ang` = fmt_num(rc$angle_min),
      `angle ok` = fmt_pct(rc$angle_ok), segs = fmt_pct(rc$segs_kept),
      `CD viol` = fmt_int(rc$cd_violations), depth = fmt_txt(rc$depth_backend),
      `attr err` = ifelse(is.na(rc$attr_err), "", sprintf("%.1e", rc$attr_err)),
      ms = fmt_num(rc$time_ms), unrefined = fmt_txt(rc$unrefined),
      check.names = FALSE)
    out <- c(out, md_table(tb), "")
  }
  if (!is.null(file)) writeLines(out, file)
  invisible(out)
}
