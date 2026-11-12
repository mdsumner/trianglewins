// Sandbox: deck.gl-raster's RasterReprojector on a ring of lon/lat tiles
// drawn in south polar stereographic, as in the custom-projection example
// with GEBCO (EPSG:4326) in EPSG:3031.
//
// Run: node --experimental-strip-types run.mjs
//
// Variants
//   B0  upstream: one mesh per tile, error unit = one source pixel on the map
//       measured at the tile centre, maxError 0.125
//   B1  same algorithm, one error unit shared by all tiles (P, below)
//   A   B1 plus tile edges densified first by a rule that depends only on
//       the edge, so neighbouring tiles carry identical edge vertices
//
// Outputs results/*.csv and results/meshes.json (for figures.py).

import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import * as upstream from "./delatin.upstream.ts";
import * as ours from "./delatin.ours.ts";
import Delaunator from "delaunator";

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = join(HERE, "results");
mkdirSync(OUT, { recursive: true });

// ---- projection: spherical south polar stereographic, lat_ts = -71 --------
const R = 6371008.8;
const D2R = Math.PI / 180;
const K0 = (1 - Math.sin(-71 * D2R)) / 2; // so that k = 1 at -71
function proj(lon, lat) {
  const rho = 2 * R * K0 * Math.tan((Math.PI / 2 + lat * D2R) / 2);
  return [rho * Math.sin(lon * D2R), rho * Math.cos(lon * D2R)];
}
function unproj(x, y) {
  const rho = Math.hypot(x, y);
  const lat = (2 * Math.atan(rho / (2 * R * K0)) - Math.PI / 2) / D2R;
  const lon = Math.atan2(x, y) / D2R;
  return [lon, lat];
}

// ---- tiles: 22.5 degree, 512 px, rows -45..-67.5 and -67.5..-90 ----------
const TILE_DEG = 22.5;
const W = 512;
const RES = TILE_DEG / (W - 1); // level-z pixel; uv 0..1 spans the tile edge to edge
const POLE_LAT = -89.5; // upstream MAX_MESH_LATITUDE guard
const MAX_ERROR = 0.125;
const NCOL = 360 / TILE_DEG;
const ROWS = [0, 1];

// P: one source pixel on the map at lat_ts, where k = 1. This is the shared
// error unit for B1 and A; a stand-in for "one screen pixel" at the zoom
// where the view's LOD would pick this source level.
const P = R * Math.sqrt(Math.cos(71 * D2R)) * RES * D2R;
// SCREEN: one screen pixel when the disc from 45 S to the pole fills a
// 1000-pixel-wide view (a phone, say). Variant S meshes to that unit.
const SCREEN = (2 * 2 * R * K0 * Math.tan((Math.PI / 2 - 45 * D2R) / 2)) / 1000;

// level 0 = 22.5 degree tiles; level 1 = 11.25 degree tiles (one LOD finer)
function tileGeo(col, row, level = 0) {
  const deg = TILE_DEG / 2 ** level;
  const lon0 = -180 + col * deg;
  const latTop = -45 - row * deg;
  return { col, row, level, deg, res: deg / (W - 1), lon0, latTop };
}
function fnsFor(t) {
  return {
    forwardTransform: (px, py) => [t.lon0 + px * t.res, t.latTop - py * t.res],
    inverseTransform: (lon, lat) => [(lon - t.lon0) / t.res, (t.latTop - lat) / t.res],
    forwardReproject: proj,
    inverseReproject: unproj,
  };
}
const uvToLonLat = (t, u, v) => [t.lon0 + u * t.deg, t.latTop - v * t.deg];
const vMaxFor = (t) => Math.min(1, (t.latTop - (t.poleLat ?? POLE_LAT)) / t.deg);

// ---- edge rule (variant A) ------------------------------------------------
// Bisect a straight source-space edge until the chord on the map is within
// tol of the projected midpoint. Inputs are the edge's lon/lat endpoints
// only, so both tiles that share the edge get the same vertices.
function densifyEdge(a, b, tol) {
  const out = [0];
  const pa = proj(...a), pb = proj(...b);
  (function rec(t0, t1, p0, p1) {
    const tm = (t0 + t1) / 2;
    const m = proj(a[0] + (b[0] - a[0]) * tm, a[1] + (b[1] - a[1]) * tm);
    const e = Math.hypot(m[0] - (p0[0] + p1[0]) / 2, m[1] - (p0[1] + p1[1]) / 2);
    if (e > tol) { rec(t0, tm, p0, m); out.push(tm); rec(tm, t1, m, p1); }
  })(0, 1, pa, pb);
  out.push(1);
  return out;
}

function edgeSeed(t, tol) {
  const vMax = vMaxFor(t);
  const ll = (u, v) => uvToLonLat(t, u, v);
  // boundary in uv, counterclockwise-agnostic; corners shared
  const sides = [
    [[0, 0], [1, 0]],
    [[1, 0], [1, vMax]],
    [[1, vMax], [0, vMax]],
    [[0, vMax], [0, 0]],
  ];
  const pts = [];
  const key = new Set();
  for (const [p, q] of sides) {
    // densify in a canonical direction so both neighbours agree exactly
    const [lp, lq] = [ll(...p), ll(...q)];
    const swap = lp[0] > lq[0] || (lp[0] === lq[0] && lp[1] > lq[1]);
    const ts = densifyEdge(swap ? lq : lp, swap ? lp : lq, tol);
    for (let s of ts) {
      if (swap) s = 1 - s;
      const u = p[0] + (q[0] - p[0]) * s, v = p[1] + (q[1] - p[1]) * s;
      const k = `${u},${v}`;
      if (!key.has(k)) { key.add(k); pts.push([u, v]); }
    }
  }
  const d = Delaunator.from(pts);
  if (new Set(d.triangles).size !== pts.length) throw new Error("seed dropped boundary points");
  return { uvs: Array.from(d.coords), triangles: Array.from(d.triangles), halfedges: Array.from(d.halfedges) };
}

// ---- build ----------------------------------------------------------------
function build(variant, t) {
  const fns = fnsFor(t);
  const t0 = performance.now();
  let r;
  const warn = console.warn; let warned = false;
  console.warn = () => { warned = true; };
  if (variant === "B0") {
    r = new upstream.RasterReprojector(fns, W, W, {
      _errorSpace: "output",
      initialTriangulation: upstream.triangulateRectangle(0, 0, 1, vMaxFor(t)),
    });
  } else if (variant === "B1") {
    r = new ours.RasterReprojector(fns, W, W, {
      _errorSpace: "output", _pixelSize: P,
      initialTriangulation: ours.triangulateRectangle(0, 0, 1, vMaxFor(t)),
    });
  } else if (variant === "S") {
    r = new ours.RasterReprojector(fns, W, W, {
      _errorSpace: "output", _pixelSize: SCREEN,
      initialTriangulation: ours.triangulateRectangle(0, 0, 1, vMaxFor(t)),
    });
  } else {
    r = new ours.RasterReprojector(fns, W, W, {
      _errorSpace: "output", _pixelSize: P,
      initialTriangulation: edgeSeed(t, MAX_ERROR * P),
    });
  }
  r.run(MAX_ERROR, { maxIterations: 1e6 });
  console.warn = warn;
  return { r, ms: performance.now() - t0, warned, pixelSize: r._pixelSize };
}

// true error, in units of P: dense barycentric sampling of every triangle
function trueError(t, r) {
  let max = 0;
  const N = 6;
  const tri = r.triangles, uv = r.uvs, xy = r.exactOutputPositions;
  for (let i = 0; i < tri.length; i += 3) {
    const [a, b, c] = [tri[i], tri[i + 1], tri[i + 2]];
    for (let p = 0; p <= N; p++) for (let q = 0; q <= N - p; q++) {
      const w0 = p / N, w1 = q / N, w2 = 1 - w0 - w1;
      const u = w0 * uv[2 * a] + w1 * uv[2 * b] + w2 * uv[2 * c];
      const v = w0 * uv[2 * a + 1] + w1 * uv[2 * b + 1] + w2 * uv[2 * c + 1];
      const x = w0 * xy[2 * a] + w1 * xy[2 * b] + w2 * xy[2 * c];
      const y = w0 * xy[2 * a + 1] + w1 * xy[2 * b + 1] + w2 * xy[2 * c + 1];
      const e = proj(...uvToLonLat(t, u, v));
      max = Math.max(max, Math.hypot(e[0] - x, e[1] - y));
    }
  }
  return max / P;
}

function minAngleStats(r) {
  // smallest angle of each triangle, on the map
  const tri = r.triangles, xy = r.exactOutputPositions;
  const out = [];
  for (let i = 0; i < tri.length; i += 3) {
    const P3 = [tri[i], tri[i + 1], tri[i + 2]].map((k) => [xy[2 * k], xy[2 * k + 1]]);
    let m = 180;
    for (let j = 0; j < 3; j++) {
      const [o, p, q] = [P3[j], P3[(j + 1) % 3], P3[(j + 2) % 3]];
      const a = Math.atan2(p[1] - o[1], p[0] - o[0]) - Math.atan2(q[1] - o[1], q[0] - o[0]);
      let d = Math.abs(a) / D2R; if (d > 180) d = 360 - d;
      m = Math.min(m, d);
    }
    out.push(m);
  }
  out.sort((a, b) => a - b);
  return { median: out[out.length >> 1], under10: out.filter((x) => x < 10).length / out.length };
}

// The four sides of a tile as lon/lat segments, with the mesh vertices on each.
function sides(t, r) {
  const vMax = vMaxFor(t);
  const latBot = t.latTop - vMax * t.deg;
  const S = {
    W: { kind: "mer", at: t.lon0, lo: latBot, hi: t.latTop, verts: [] },
    E: { kind: "mer", at: t.lon0 + t.deg, lo: latBot, hi: t.latTop, verts: [] },
    N: { kind: "par", at: t.latTop, lo: t.lon0, hi: t.lon0 + t.deg, verts: [] },
    S: { kind: "par", at: latBot, lo: t.lon0, hi: t.lon0 + t.deg, verts: [] },
  };
  for (let i = 0; i < r.uvs.length; i += 2) {
    const u = r.uvs[i], v = r.uvs[i + 1];
    const ll = uvToLonLat(t, u, v);
    if (u === 0) S.W.verts.push(ll);
    if (u === 1) S.E.verts.push(ll);
    if (v === 0) S.N.verts.push(ll);
    if (v === vMax) S.S.verts.push(ll);
  }
  return S;
}

const near = (a, b) => Math.abs(a - b) < 1e-9;

// Gap between two piecewise-linear (on the map) versions of a shared piece of
// edge, plus the number of T-junctions (a vertex on one side only).
function seamGap(sa, sb, shift) {
  // coordinate along the edge: lat for meridians, lon for parallels
  const along = sa.kind === "mer" ? 1 : 0;
  const fix = (p) => (shift && along === 0 ? [p[0] + shift, p[1]] : shift ? [p[0] + shift, p[1]] : p);
  const A = [...sa.verts].sort((p, q) => p[along] - q[along]);
  const B = sb.verts.map(fix).sort((p, q) => p[along] - q[along]);
  const lo = Math.max(sa.lo, sb.lo + (along === 0 ? shift : 0));
  const hi = Math.min(sa.hi, sb.hi + (along === 0 ? shift : 0));
  if (!(hi - lo > 1e-9)) return null;
  const lerp = (s, x) => {
    let j = 0; while (j < s.length - 2 && s[j + 1][along] < x) j++;
    const p = proj(...s[j]), q = proj(...s[j + 1]);
    const f = (x - s[j][along]) / (s[j + 1][along] - s[j][along]);
    return [p[0] + (q[0] - p[0]) * f, p[1] + (q[1] - p[1]) * f];
  };
  const inR = (p) => p[along] >= lo - 1e-9 && p[along] <= hi + 1e-9;
  const xa = A.filter(inR).map((p) => p[along]), xb = B.filter(inR).map((p) => p[along]);
  let gap = 0;
  for (const x of [...xa, ...xb]) {
    const a = lerp(A, x), b = lerp(B, x);
    gap = Math.max(gap, Math.hypot(a[0] - b[0], a[1] - b[1]));
  }
  const has = (xs, x) => xs.some((y) => near(x, y));
  const tj = xa.filter((x) => !has(xb, x)).length + xb.filter((x) => !has(xa, x)).length;
  return { gap: gap / P, tjunctions: tj };
}

function allSeams(tiles, built) {
  const S = tiles.map((t) => sides(t, built.get(t).r));
  let gap = 0, tj = 0, n = 0;
  for (let i = 0; i < tiles.length; i++) for (let j = i + 1; j < tiles.length; j++) {
    for (const [ka, sa] of Object.entries(S[i])) for (const [kb, sb] of Object.entries(S[j])) {
      if (sa.kind !== sb.kind) continue;
      // opposite sides only (E of one against W of the other, N against S)
      if (!((ka === "E" && kb === "W") || (ka === "W" && kb === "E") || (ka === "N" && kb === "S") || (ka === "S" && kb === "N"))) continue;
      for (const shift of sa.kind === "mer" ? [0, 360, -360] : [0]) {
        if (sa.kind === "mer" && !near(sa.at, sb.at + shift)) continue;
        if (sa.kind === "par" && !near(sa.at, sb.at)) continue;
        const s = seamGap(sa, sb, 0); // lon +-360 projects to the same point
        if (!s) continue;
        n++; gap = Math.max(gap, s.gap); tj += s.tjunctions;
      }
    }
  }
  return { gap, tj, n };
}

// ---- scenarios --------------------------------------------------------------
// ring: 16 x 2 tiles at one level, -45 to the pole (the screenshot's layout)
// lod:  the outer row at level 0, the polar cap one level finer, as the
//       tileset does when it picks a finer overview near the pole
const SCENARIOS = {
  ring: [0, 1].flatMap((row) => Array.from({ length: NCOL }, (_, c) => tileGeo(c, row, 0))),
  lod: [
    ...Array.from({ length: NCOL }, (_, c) => tileGeo(c, 0, 0)),
    ...[2, 3].flatMap((row) => Array.from({ length: 2 * NCOL }, (_, c) => tileGeo(c, row, 1))),
  ],  // ring, but meshed all the way to the pole (no 0.5 degree guard)
  pole: [0, 1].flatMap((row) => Array.from({ length: NCOL }, (_, c) => ({ ...tileGeo(c, row, 0), poleLat: -90 }))),
};

const tileRows = ["scenario,variant,level,col,row,triangles,ms,true_max_error_P,unit_P"];
const summary = ["scenario,variant,triangles_outer,triangles_cap,triangles_total,ms_total,true_max_error_P,median_min_angle,share_under_10deg,seams_checked,seam_max_gap_P,seam_tjunctions"];
const meshes = { P, MAX_ERROR, scenarios: {} };

for (const [scen, tiles] of Object.entries(SCENARIOS)) {
  meshes.scenarios[scen] = {};
  for (const variant of ["B0", "B1", "A", "S"]) {
    const built = new Map();
    let outer = 0, cap = 0, ms = 0, emax = 0;
    const angles = [];
    meshes.scenarios[scen][variant] = [];
    for (const t of tiles) {
      const b = build(variant, t);
      built.set(t, b);
      const n = b.r.triangles.length / 3;
      const e = trueError(t, b.r);
      if (t.latTop > -67.5 + 1e-9) outer += n; else cap += n;
      ms += b.ms; emax = Math.max(emax, e);
      tileRows.push([scen, variant, t.level, t.col, t.row, n, b.ms.toFixed(1), e.toFixed(4), (b.pixelSize / P).toFixed(4)].join(","));
      angles.push(minAngleStats(b.r));
      meshes.scenarios[scen][variant].push({
        level: t.level, col: t.col, row: t.row, lon0: t.lon0, latTop: t.latTop, deg: t.deg,
        uv: b.r.uvs.map((v) => +v.toFixed(6)),
        xy: b.r.exactOutputPositions.map((v) => Math.round(v)),
        tri: b.r.triangles,
      });
    }
    const sm = allSeams(tiles, built);
    const medAngle = angles.map((a) => a.median).sort((a, b) => a - b)[angles.length >> 1];
    const under10 = angles.reduce((s, a) => s + a.under10, 0) / angles.length;
    summary.push([scen, variant, outer, cap, outer + cap, ms.toFixed(0), emax.toFixed(4), medAngle.toFixed(1), under10.toFixed(3), sm.n, sm.gap.toFixed(4), sm.tj].join(","));
  }
}

writeFileSync(join(OUT, "tiles.csv"), tileRows.join("\n") + "\n");
writeFileSync(join(OUT, "summary.csv"), summary.join("\n") + "\n");
writeFileSync(join(OUT, "meshes.json"), JSON.stringify(meshes));
console.log(`P = ${P.toFixed(1)} m, SCREEN = ${SCREEN.toFixed(1)} m`);
console.log(summary.join("\n"));
