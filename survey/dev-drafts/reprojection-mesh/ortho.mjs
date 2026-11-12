// Lon/lat tiles in an orthographic hemisphere, which upstream does not handle
// (its seeds are lon/lat boxes). Seeds from ortho_seeds.py: each tile's
// visible part as a constrained triangulation; then the unchanged greedy
// refinement (delatin.ours.ts, shared error unit).
//
// Run: python3 ortho_seeds.py && node --experimental-strip-types ortho.mjs

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import * as ours from "./delatin.ours.ts";

const HERE = dirname(fileURLToPath(import.meta.url));
const S = JSON.parse(readFileSync(join(HERE, "results", "ortho-seeds.json"), "utf8"));

const R = 6371008.8, D2R = Math.PI / 180;
const [L0, P0] = [S.lon0 * D2R, S.lat0 * D2R];
function proj(lon, lat) {
  const l = lon * D2R - L0, p = lat * D2R;
  return [R * Math.cos(p) * Math.sin(l),
          R * (Math.cos(P0) * Math.sin(p) - Math.sin(P0) * Math.cos(p) * Math.cos(l))];
}
const W = 512, MAX_ERROR = 0.125;
const P = R * (22.5 / (W - 1)) * D2R; // one level-0 source pixel at the view centre (k = 1)

function run(t, seed) {
  const res = t.deg / (W - 1);
  const fns = {
    forwardTransform: (px, py) => [t.lon0 + px * res, t.latTop - py * res],
    inverseTransform: (lon, lat) => [(lon - t.lon0) / res, (t.latTop - lat) / res],
    forwardReproject: proj,
    inverseReproject: () => { throw new Error("unused in output mode"); },
  };
  const r = new ours.RasterReprojector(fns, W, W, { _errorSpace: "output", _pixelSize: P, initialTriangulation: seed });
  r.run(MAX_ERROR, { maxIterations: 1e6 });
  return r;
}

function measure(t, r) {
  const tri = r.triangles, uv = r.uvs, xy = r.exactOutputPositions;
  let emax = 0, area = 0;
  const N = 6;
  for (let i = 0; i < tri.length; i += 3) {
    const [a, b, c] = [tri[i], tri[i + 1], tri[i + 2]];
    area += Math.abs((xy[2 * b] - xy[2 * a]) * (xy[2 * c + 1] - xy[2 * a + 1]) - (xy[2 * b + 1] - xy[2 * a + 1]) * (xy[2 * c] - xy[2 * a])) / 2;
    for (let p = 0; p <= N; p++) for (let q = 0; q <= N - p; q++) {
      const w0 = p / N, w1 = q / N, w2 = 1 - w0 - w1;
      const u = w0 * uv[2 * a] + w1 * uv[2 * b] + w2 * uv[2 * c];
      const v = w0 * uv[2 * a + 1] + w1 * uv[2 * b + 1] + w2 * uv[2 * c + 1];
      const e = proj(t.lon0 + u * t.deg, t.latTop - v * t.deg);
      const x = w0 * xy[2 * a] + w1 * xy[2 * b] + w2 * xy[2 * c];
      const y = w0 * xy[2 * a + 1] + w1 * xy[2 * b + 1] + w2 * xy[2 * c + 1];
      emax = Math.max(emax, Math.hypot(e[0] - x, e[1] - y));
    }
  }
  return { emax: emax / P, area };
}

const disc = Math.PI * (R * Math.sin(S.cap * D2R)) ** 2;
const rows = ["variant,tiles,triangles,true_max_error_P,coverage_of_visible_disc,ms"];
const meshes = { P, variants: {} };
for (const variant of ["boxes-only", "constrained"]) {
  let n = 0, tris = 0, emax = 0, area = 0;
  const t0 = performance.now();
  meshes.variants[variant] = [];
  for (const t of S.tiles) {
    if (variant === "boxes-only" && !t.full) continue; // upstream can only seed a box
    const seed = variant === "boxes-only"
      ? ours.triangulateRectangle(0, 0, 1, 1)
      : t.seed;
    const r = run(t, seed);
    const m = measure(t, r);
    n++; tris += r.triangles.length / 3; emax = Math.max(emax, m.emax); area += m.area;
    meshes.variants[variant].push({ col: t.col, row: t.row, full: t.full,
      xy: r.exactOutputPositions.map((v) => Math.round(v)), tri: r.triangles });
  }
  rows.push([variant, n, tris, emax.toFixed(4), (area / disc).toFixed(4), (performance.now() - t0).toFixed(0)].join(","));
}
writeFileSync(join(HERE, "results", "ortho-summary.csv"), rows.join("\n") + "\n");
writeFileSync(join(HERE, "results", "ortho-meshes.json"), JSON.stringify(meshes));
console.log(rows.join("\n"));
