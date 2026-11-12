// Source-tile meshing in the style of deck.gl-raster: LOD tiles in lon/lat,
// one mesh per tile refined in source space, error in output pixels.
// Stand-in for Delatin: a bintree (split the longest edge at its midpoint,
// neighbours kept conforming inside the tile). Same error test and unit;
// different triangle shapes, which do not change the picture.
const TILE_PX = 256, RI = 1 << 20;

function selectTiles(proj, view, opts) {
  const { W, H } = view, out = [];
  const maxL = opts.maxLevel ?? 7, pad = 0.05 * W;
  const visit = (L, lo, la) => {
    const size = 90 / (1 << L);
    let minx = 1e9, miny = 1e9, maxx = -1e9, maxy = -1e9, best = null, bd = 1e9;
    const n = 8;
    for (let a = 0; a <= n; a++) for (let b = 0; b <= n; b++) {
      const lon = lo + size * a / n, lat = la + size * b / n, q = view.sfwd(lon, lat, null);
      if (!q) continue;
      minx = Math.min(minx, q[0]); maxx = Math.max(maxx, q[0]); miny = Math.min(miny, q[1]); maxy = Math.max(maxy, q[1]);
      const d = Math.abs(a - n / 2) + Math.abs(b - n / 2);
      if (d < bd && Math.abs(lat) < 89.99) { bd = d; best = [lon, lat]; }
    }
    if (maxx < -pad || minx > W + pad || maxy < -pad || miny > H + pad || minx > maxx) return;
    let unit = Infinity;
    if (best) {
      const e = size / 512, p = view.sfwd(best[0], best[1], null);
      let qx = view.sfwd(best[0] + e, best[1], null), qy = view.sfwd(best[0], best[1] + e, null), sx = 1, sy = 1;
      if (!qx) { qx = view.sfwd(best[0] - e, best[1], null); sx = -1; }
      if (!qy) { qy = view.sfwd(best[0], best[1] - e, null); sy = -1; }
      if (p && qx && qy) {
        const det = Math.abs((qx[0] - p[0]) * (qy[1] - p[1]) - (qx[1] - p[1]) * (qy[0] - p[0])) / (e * e);
        unit = Math.sqrt(det) * size / TILE_PX; // one source pixel on screen, px
      }
    }
    if (unit > 1 && L < maxL) {
      const h = size / 2;
      visit(L + 1, lo, la); visit(L + 1, lo + h, la); visit(L + 1, lo, la + h); visit(L + 1, lo + h, la + h);
      return;
    }
    out.push({ L, lon0: lo, lon1: lo + size, lat0: la, lat1: la + size, unit: isFinite(unit) ? unit : 1 });
  };
  for (let lo = -180; lo < 180; lo += 90) for (let la = -90; la < 90; la += 90) visit(0, lo, la);
  return out;
}

function prepTiles(proj, tiles, opts) {
  let res = tiles;
  if (opts.poleGuard) res = res.map(t => ({ ...t, lat0: Math.max(t.lat0, -89.5), lat1: Math.min(t.lat1, 89.5) }));
  if (!proj.cutsAt) return res.map(t => ({ ...t, side: null }));
  const out = [];
  for (const t of res) {
    // a tile never straddles the equator (level 0 tiles are 90 degrees)
    const cuts = proj.cutsAt((t.lat0 + t.lat1) / 2).map(l => [l, l - 360, l + 360]).flat()
      .filter(l => l > t.lon0 + 1e-9 && l < t.lon1 - 1e-9).sort((p, q) => p - q);
    if (!opts.cut) { out.push({ ...t, side: null }); continue; }
    const xs = [t.lon0, ...cuts, t.lon1];
    for (let k = 0; k + 1 < xs.length; k++) out.push({ ...t, lon0: xs[k], lon1: xs[k + 1], side: (xs[k] + xs[k + 1]) / 2, cutPart: cuts.length > 0 });
  }
  return out;
}

function meshTile(view, tile, tol, opts) {
  const V = [], vkey = new Map(), side = tile.side;
  const vert = (i, j) => {
    const k = i * (RI + 1) + j;
    let id = vkey.get(k);
    if (id !== undefined) return id;
    const lon = tile.lon0 + (tile.lon1 - tile.lon0) * i / RI, lat = tile.lat0 + (tile.lat1 - tile.lat0) * j / RI;
    const q = view.sfwd(lon, lat, side);
    id = V.length;
    V.push({ i, j, lon, lat, x: q ? q[0] : NaN, y: q ? q[1] : NaN, ok: !!q });
    vkey.set(k, id);
    return id;
  };
  const T = []; // {a,b0,b1,alive,err}
  const E = new Map(); // edge key -> Set of tri ids
  const ek = (p, q) => p < q ? p * 4194304 + q : q * 4194304 + p;
  const eadd = (p, q, t) => { const k = ek(p, q); let s = E.get(k); if (!s) E.set(k, s = new Set()); s.add(t); };
  const edel = (p, q, t) => { const s = E.get(ek(p, q)); if (s) s.delete(t); };
  const stack = [];
  const errOf = (t) => {
    const a = V[t.a], b = V[t.b0], c = V[t.b1];
    if (!a.ok || !b.ok || !c.ok) {
      // part of the triangle is off the map: refine towards the edge a few
      // levels (box seeds cannot follow a curved domain), then drop it
      if (a.ok || b.ok || c.ok) return -1;
      for (const w of SAMPLES) if (view.sfwd(w[0] * a.lon + w[1] * b.lon + w[2] * c.lon, w[0] * a.lat + w[1] * b.lat + w[2] * c.lat, side)) return -1;
      return 0;
    }
    let e = 0;
    for (const w of SAMPLES) {
      const sx = w[0] * a.x + w[1] * b.x + w[2] * c.x, sy = w[0] * a.y + w[1] * b.y + w[2] * c.y;
      const q = view.sfwd(w[0] * a.lon + w[1] * b.lon + w[2] * c.lon, w[0] * a.lat + w[1] * b.lat + w[2] * c.lat, side);
      const d = q ? Math.hypot(q[0] - sx, q[1] - sy) : Infinity;
      if (d > e) e = d;
    }
    return e;
  };
  const add = (a, b0, b1) => {
    const t = { a, b0, b1, alive: true, err: 0 };
    const id = T.length; T.push(t);
    eadd(a, b0, id); eadd(b0, b1, id); eadd(b1, a, id);
    t.err = errOf(t);
    stack.push(id);
    return id;
  };
  const kill = (id) => { const t = T[id]; t.alive = false; edel(t.a, t.b0, id); edel(t.b0, t.b1, id); edel(t.b1, t.a, id); };
  const minHyp = RI / TILE_PX * 1.5;
  const hypLen = (t) => { const p = V[t.b0], q = V[t.b1]; return Math.hypot(p.i - q.i, p.j - q.j); };
  const other = (id, p, q) => { const s = E.get(ek(p, q)); if (!s) return -1; for (const x of s) if (x !== id && T[x].alive) return x; return -1; };
  const split = (id, depth = 0) => {
    const t = T[id];
    if (!t.alive || depth > 64) return;
    let n = other(id, t.b0, t.b1);
    if (n >= 0 && ek(T[n].b0, T[n].b1) !== ek(t.b0, t.b1)) { split(n, depth + 1); n = other(id, t.b0, t.b1); }
    const p = V[t.b0], q = V[t.b1];
    const m = vert((p.i + q.i) / 2, (p.j + q.j) / 2);
    kill(id); add(m, t.b0, t.a); add(m, t.a, t.b1);
    if (n >= 0) { const u = T[n]; kill(n); add(m, u.b0, u.a); add(m, u.a, u.b1); }
  };
  const c00 = vert(0, 0), c10 = vert(RI, 0), c01 = vert(0, RI), c11 = vert(RI, RI);
  add(c00, c10, c01); add(c11, c01, c10);
  let guard = 0;
  while (stack.length && guard++ < 400000) {
    const id = stack.pop(), t = T[id];
    if (!t.alive) continue;
    if (t.err < 0 ? hypLen(t) > RI / 32 : (t.err > tol && hypLen(t) > minHyp)) split(id);
  }
  const splitEdge = (p, q) => {
    for (let k = 0; k < 40; k++) {
      const s = E.get(ek(p, q)); let id = -1;
      if (s) for (const x of s) if (T[x].alive) { id = x; break; }
      if (id < 0) return;
      const t = T[id];
      split(id);
      if (ek(t.b0, t.b1) === ek(p, q)) return;
    }
  };
  return { tile, V, T, E, splitEdge, ek };
}

// Boundary segments of a tile mesh on its four sides, in global lon/lat.
function boundarySegs(m) {
  const segs = [];
  const on = (v) => v.i === 0 ? 0 : v.i === RI ? 1 : -1;
  const onj = (v) => v.j === 0 ? 0 : v.j === RI ? 1 : -1;
  for (const t of m.T) {
    if (!t.alive) continue;
    for (const [p, q] of [[t.a, t.b0], [t.b0, t.b1], [t.b1, t.a]]) {
      const P = m.V[p], Q = m.V[q];
      if (on(P) >= 0 && on(P) === on(Q)) segs.push({ m, p, q, vert: true, line: normLon(P.lon), t0: Math.min(P.lat, Q.lat), t1: Math.max(P.lat, Q.lat) });
      else if (onj(P) >= 0 && onj(P) === onj(Q)) segs.push({ m, p, q, vert: false, line: P.lat, t0: Math.min(P.lon, Q.lon), t1: Math.max(P.lon, Q.lon) });
    }
  }
  return segs;
}
function normLon(l) { return Math.abs(l + 180) < 1e-9 ? 180 : l; }

function findTJunctions(meshes, isCut) {
  const lines = new Map();
  for (const m of meshes) for (const s of boundarySegs(m)) {
    if (s.vert && isCut && isCut(s.line, (s.t0 + s.t1) / 2)) continue;
    const key = (s.vert ? "v" : "h") + s.line.toFixed(9);
    let L = lines.get(key); if (!L) lines.set(key, L = []); L.push(s);
  }
  const tj = [];
  for (const L of lines.values()) {
    if (L.length < 2) continue;
    // vertices on this line, per mesh
    const pts = [];
    for (const s of L) for (const v of [s.p, s.q]) { const V = s.m.V[v]; pts.push({ m: s.m, V, t: s.vert ? V.lat : V.lon }); }
    L.sort((a, b) => a.t0 - b.t0);
    for (const pt of pts) for (const s of L) {
      if (s.m === pt.m || !(pt.t > s.t0 + 1e-10 && pt.t < s.t1 - 1e-10)) continue;
      const A = s.m.V[s.p], B = s.m.V[s.q], P = pt.V;
      let crack = NaN;
      if (A.ok && B.ok && P.ok) {
        const dx = B.x - A.x, dy = B.y - A.y, len = Math.hypot(dx, dy);
        crack = len > 0 ? Math.abs((P.x - A.x) * dy - (P.y - A.y) * dx) / len : Math.hypot(P.x - A.x, P.y - A.y);
      }
      tj.push({ seg: s, P, crack });
    }
  }
  return tj;
}

function buildTileMesh(proj, view, opts) {
  const sel = prepTiles(proj, selectTiles(proj, view, opts), opts);
  const meshes = sel.map(t => meshTile(view, t, opts.unit === "screen" ? opts.maxError : opts.maxError * t.unit, opts));
  const isCut = proj.cutsAt ? (lon, lat) => proj.cutsAt(lat).some(c => Math.abs(normLon(wrap180(c)) - lon) < 1e-9 || Math.abs(normLon(c) - lon) < 1e-9) : null;
  let tj = findTJunctions(meshes, isCut), passes = 0;
  if (opts.conform) {
    while (tj.length && passes++ < 40) {
      for (const j of tj) j.seg.m.splitEdge(j.seg.p, j.seg.q);
      tj = findTJunctions(meshes, isCut);
    }
  }
  const tris = [];
  let dropped = 0;
  for (const m of meshes) for (const t of m.T) {
    if (!t.alive) continue;
    const a = m.V[t.a], b = m.V[t.b0], c = m.V[t.b1];
    if (!a.ok || !b.ok || !c.ok) { dropped++; continue; }
    tris.push([a, b, c, t.err, "tile"]);
  }
  let crackMax = 0; for (const j of tj) if (j.crack > crackMax) crackMax = j.crack;
  const levels = new Set(sel.map(t => t.L));
  return { tris, tiles: sel, tj, stats: { tiles: sel.length, levels: levels.size, dropped, tjunctions: tj.length, crackMax } };
}
if (typeof module !== "undefined") module.exports = { buildTileMesh, selectTiles };
