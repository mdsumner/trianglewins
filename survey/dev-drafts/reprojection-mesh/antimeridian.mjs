// A polar-native raster (south polar stereographic) drawn in Equal Earth.
// Upstream offers such rasters only in their own polar projection: in a
// world projection the pole becomes a line and tiles straddle the
// antimeridian. Here:
//   one-mesh  upstream as is: one mesh per whole tile, box seed, per-tile
//             error unit, default iteration cap (10000)
//   cut       constrained seeds from am_seeds.py: tiles clipped to the
//             hemisphere, a sub-pixel cap removed at the pole, and tiles
//             the antimeridian crosses cut in two, each part with its own
//             longitude branch; shared error unit
//
// Run: python3 am_seeds.py && node --experimental-strip-types antimeridian.mjs

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import * as upstream from "./delatin.upstream.ts";
import * as ours from "./delatin.ours.ts";

const HERE = dirname(fileURLToPath(import.meta.url));
const S = JSON.parse(readFileSync(join(HERE, "results", "am-seeds.json"), "utf8"));
const { R, K0, W } = S;
const D2R = Math.PI / 180;

// Equal Earth (Savric, Patterson and Jenny 2018), spherical
const [A1, A2, A3, A4] = [1.340264, -0.081106, 0.000893, 0.003796];
const M = Math.sqrt(3) / 2;
function equalEarth(lon, lat) {
  const th = Math.asin(M * Math.sin(lat * D2R));
  const t2 = th * th, t6 = t2 * t2 * t2;
  const x = (2 * Math.sqrt(3) * lon * D2R * Math.cos(th)) / (3 * (9 * A4 * t6 * t2 + 7 * A3 * t6 + 3 * A2 * t2 + A1));
  const y = th * (A1 + A2 * t2 + t6 * (A3 + A4 * t2));
  return [R * x, R * y];
}
// polar stereographic x, y -> lon, lat, with a longitude branch:
// -1 sends longitudes past 90 to the west side (-180), +1 sends those past
// -90 to the east side (+180), 0 leaves atan2 alone. Only the antimeridian
// is cut, so near longitude 0 a part keeps atan2's own value.
function unstere(x, y, branch) {
  const r = Math.hypot(x, y);
  const lat = (2 * Math.atan(r / (2 * R * K0)) - Math.PI / 2) / D2R;
  let lon = Math.atan2(x, y) / D2R;
  if (branch < 0 && lon > 90) lon -= 360;
  if (branch > 0 && lon < -90) lon += 360;
  return [lon, lat];
}

const P = S.side / (W - 1); // one source pixel, metres (scale 1 at 71 S)

function fns(t, branch) {
  const res = t.side / (W - 1);
  return {
    forwardTransform: (px, py) => [t.x0 + px * res, t.yTop - py * res],
    inverseTransform: (x, y) => [(x - t.x0) / res, (t.yTop - y) / res],
    forwardReproject: (x, y) => equalEarth(...unstere(x, y, branch)),
    inverseReproject: () => { throw new Error("unused in output mode"); },
  };
}

function measure(t, r, branch) {
  const tri = r.triangles, uv = r.uvs, xy = r.exactOutputPositions;
  let emax = 0, area = 0, wide = 0;
  const N = 6, f = fns(t, branch);
  const worldHalf = equalEarth(180, 0)[0];
  for (let i = 0; i < tri.length; i += 3) {
    const [a, b, c] = [tri[i], tri[i + 1], tri[i + 2]];
    const xs = [xy[2 * a], xy[2 * b], xy[2 * c]];
    if (Math.max(...xs) - Math.min(...xs) > worldHalf) wide++;
    area += Math.abs((xy[2 * b] - xy[2 * a]) * (xy[2 * c + 1] - xy[2 * a + 1]) - (xy[2 * b + 1] - xy[2 * a + 1]) * (xy[2 * c] - xy[2 * a])) / 2;
    for (let p = 0; p <= N; p++) for (let q = 0; q <= N - p; q++) {
      const w0 = p / N, w1 = q / N, w2 = 1 - w0 - w1;
      const u = w0 * uv[2 * a] + w1 * uv[2 * b] + w2 * uv[2 * c];
      const v = w0 * uv[2 * a + 1] + w1 * uv[2 * b + 1] + w2 * uv[2 * c + 1];
      const e = f.forwardReproject(...f.forwardTransform(u * (W - 1), v * (W - 1)));
      const x = w0 * xy[2 * a] + w1 * xy[2 * b] + w2 * xy[2 * c];
      const y = w0 * xy[2 * a + 1] + w1 * xy[2 * b + 1] + w2 * xy[2 * c + 1];
      emax = Math.max(emax, Math.hypot(e[0] - x, e[1] - y));
    }
  }
  return { emax: emax / P, area, wide };
}

const hemisphere = 2 * Math.PI * R * R; // Equal Earth is equal-area
const rows = ["variant,tile_meshes,converged,triangles,triangles_spanning_half_the_world,true_max_error_P,area_share_of_hemisphere"];
const meshes = { P, worldHalf: equalEarth(180, 0)[0], variants: {} };
for (const variant of ["one-mesh", "cut"]) {
  let n = 0, conv = 0, tris = 0, wide = 0, emax = 0, area = 0;
  meshes.variants[variant] = [];
  for (const t of S.tiles) {
    const jobs = variant === "one-mesh"
      ? [{ branch: 0, seed: upstream.triangulateRectangle(0, 0, 1, 1) }]
      : t.parts;
    for (const job of jobs) {
      const warn = console.warn; let warned = false;
      console.warn = () => { warned = true; };
      const r = variant === "one-mesh"
        ? new upstream.RasterReprojector(fns(t, 0), W, W, { _errorSpace: "output", initialTriangulation: job.seed })
        : new ours.RasterReprojector(fns(t, job.branch), W, W, { _errorSpace: "output", _pixelSize: P, initialTriangulation: job.seed });
      let threw = false;
      try { r.run(0.125, variant === "one-mesh" ? {} : { maxIterations: 1e6 }); } catch { threw = true; }
      console.warn = warn;
      const m = measure(t, r, job.branch);
      n++; if (!warned && !threw) conv++;
      tris += r.triangles.length / 3; wide += m.wide; emax = Math.max(emax, m.emax);
      // count area inside the hemisphere only for the clipped variant; the
      // box seeds reach past the equator so their area is not comparable
      area += m.area;
      meshes.variants[variant].push({
        col: t.col, row: t.row, branch: job.branch, crosses: t.crosses, has_pole: t.has_pole,
        converged: !warned && !threw,
        xy: r.exactOutputPositions.map((v) => Math.round(v)), tri: r.triangles,
      });
    }
  }
  rows.push([variant, n, conv, tris, wide, emax.toFixed(3), (area / hemisphere).toFixed(4)].join(","));
}
writeFileSync(join(HERE, "results", "antimeridian-summary.csv"), rows.join("\n") + "\n");
writeFileSync(join(HERE, "results", "antimeridian-meshes.json"), JSON.stringify(meshes));
console.log(`P = ${P.toFixed(0)} m`);
console.log(rows.join("\n"));
