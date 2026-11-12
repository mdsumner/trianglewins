// Core: projections, mesh building, error. No DOM.
const D2R = Math.PI / 180, R2D = 180 / Math.PI;
function wrap180(d) { d = ((d + 180) % 360 + 360) % 360 - 180; return d; }

function makeOrtho(lon0, lat0) {
  const p0 = lat0 * D2R, sp0 = Math.sin(p0), cp0 = Math.cos(p0);
  return {
    name: "ortho", lon0, poles: [[0, 90], [0, -90]],
    fwd(lon, lat) {
      const l = (lon - lon0) * D2R, p = lat * D2R;
      const cc = sp0 * Math.sin(p) + cp0 * Math.cos(p) * Math.cos(l);
      if (cc < -1e-12) return null;
      return [Math.cos(p) * Math.sin(l), cp0 * Math.sin(p) - sp0 * Math.cos(p) * Math.cos(l)];
    },
    inv(x, y) {
      const rho = Math.hypot(x, y);
      if (rho > 1) return null;
      if (rho < 1e-15) return [lon0, lat0];
      const c = Math.asin(rho), sc = Math.sin(c), cc = Math.cos(c);
      const lat = Math.asin(cc * sp0 + y * sc * cp0 / rho);
      const lon = lon0 * D2R + Math.atan2(x * sc, rho * cp0 * cc - y * sp0 * sc);
      return [wrap180(lon * R2D), lat * R2D];
    },
    extent: 1.0
  };
}
function makeStereS(lon0) {
  return {
    name: "stere", lon0, poles: [[0, -90]],
    fwd(lon, lat) {
      if (lat > 89.999) return null;
      const r = 2 * Math.tan(Math.PI / 4 + lat * D2R / 2), l = (lon - lon0) * D2R;
      return [r * Math.sin(l), r * Math.cos(l)];
    },
    inv(x, y) {
      const r = Math.hypot(x, y);
      return [wrap180(lon0 + Math.atan2(x, y) * R2D), (2 * Math.atan(r / 2) - Math.PI / 2) * R2D];
    },
    extent: 2.0
  };
}
// Equal Earth (Savric, Patterson, Jenny 2018)
const EA1 = 1.340264, EA2 = -0.081106, EA3 = 0.000893, EA4 = 0.003796, EM = Math.sqrt(3) / 2;
function makeEqualEarth(lon0) {
  const S = 1 / 2.7064; // scale so half width ~ 1
  return {
    name: "eqearth", lon0, poles: [], cutsAt() { return [wrap180(lon0 + 180)]; },
    fwd(lon, lat, side) {
      let d = wrap180(lon - lon0);
      if (side != null && Math.abs(Math.abs(d) - 180) < 1e-9) d = wrap180(side - lon0) >= 0 ? 180 : -180;
      const l = d * D2R, th = Math.asin(EM * Math.sin(lat * D2R));
      const t2 = th * th, t6 = t2 * t2 * t2;
      const x = l * Math.cos(th) / (EM * (EA1 + 3 * EA2 * t2 + t6 * (7 * EA3 + 9 * EA4 * t2)));
      const y = th * (EA1 + EA2 * t2 + t6 * (EA3 + EA4 * t2));
      return [x * S, y * S];
    },
    inv(x, y) {
      x /= S; y /= S;
      let th = y;
      for (let i = 0; i < 12; i++) {
        const t2 = th * th, t6 = t2 * t2 * t2;
        const f = th * (EA1 + EA2 * t2 + t6 * (EA3 + EA4 * t2)) - y;
        const fp = EA1 + 3 * EA2 * t2 + t6 * (7 * EA3 + 9 * EA4 * t2);
        th -= f / fp; if (Math.abs(f) < 1e-12) break;
      }
      if (Math.abs(th) > Math.asin(EM) + 1e-9) return null;
      const t2 = th * th, t6 = t2 * t2 * t2;
      const l = EM * x * (EA1 + 3 * EA2 * t2 + t6 * (7 * EA3 + 9 * EA4 * t2)) / Math.cos(th);
      if (Math.abs(l) > Math.PI + 1e-9) return null;
      return [wrap180(lon0 + l * R2D), Math.asin(Math.sin(th) / EM) * R2D];
    },
    extent: 1.0, xext: 1.0, yext: 0.49
  };
}


// Goode Homolosine, interrupted (land lobes as in PROJ igh)
const GH_PHI = 0.71093078197902358062, GH_YC = 0.05280, MCX = 2 * Math.SQRT2 / Math.PI, MCY = Math.SQRT2;
const GH_LOBES = { n: [[-180, -40, -100], [-40, 180, 30]], s: [[-180, -100, -160], [-100, -20, -60], [-20, 80, 20], [80, 180, 140]] };
function homolosine(lam, phi) {
  if (Math.abs(phi) <= GH_PHI) return [lam * Math.cos(phi), phi];
  const k = Math.PI * Math.sin(phi);
  let th = phi;
  for (let i = 0; i < 30; i++) { const d = (th + Math.sin(th) - k) / (1 + Math.cos(th)); th -= d; if (Math.abs(d) < 1e-12) break; }
  th /= 2;
  return [MCX * lam * Math.cos(th), MCY * Math.sin(th) - Math.sign(phi) * GH_YC];
}
function homolosineInv(x, y) {
  if (Math.abs(y) <= GH_PHI) { const c = Math.cos(y); return c > 1e-12 ? [x / c, y] : null; }
  const yy = y + Math.sign(y) * GH_YC, s = yy / MCY;
  if (Math.abs(s) > 1) return null;
  const th = Math.asin(s), c = Math.cos(th);
  if (c < 1e-12) return [0, Math.sign(y) * Math.PI / 2];
  const lam = x / (MCX * c), t = (2 * th + Math.sin(2 * th)) / Math.PI;
  if (Math.abs(t) > 1) return null;
  return [lam, Math.asin(t)];
}
function makeGoode() {
  const S = 1 / 3.2;
  const lobeOf = (lon, lat, hint) => {
    const L = lat >= 0 ? GH_LOBES.n : GH_LOBES.s, q = hint != null ? wrap180(hint) : lon;
    for (const b of L) if (q >= b[0] && q <= b[1]) return b;
    return L[L.length - 1];
  };
  return {
    name: "goode", lon0: 0, poles: [],
    cutsAt(lat) { return (lat >= 0 ? GH_LOBES.n : GH_LOBES.s).map(b => b[1]); },
    fwd(lon, lat, hint) {
      if (lon > 180 + 1e-9 || lon < -180 - 1e-9) lon = wrap180(lon);
      const b = lobeOf(lon, lat, hint);
      const p = homolosine((lon - b[2]) * D2R, lat * D2R);
      return [(p[0] + b[2] * D2R) * S, p[1] * S];
    },
    inv(x, y) {
      x /= S; y /= S;
      const L = y >= 0 ? GH_LOBES.n : GH_LOBES.s;
      for (const b of L) {
        const r = homolosineInv(x - b[2] * D2R, y);
        if (!r) continue;
        const lon = b[2] + r[0] * R2D, lat = r[1] * R2D;
        if (lon >= b[0] - 1e-9 && lon <= b[1] + 1e-9 && (lat >= 0) === (y >= 0)) return [lon, lat];
      }
      return null;
    },
    extent: 1.0, xext: 0.99, yext: 0.43
  };
}

// view: {W, H, cx, cy, scale(px per unit)}
function makeView(proj, W, H, zoom) {
  const xe = proj.xext || proj.extent, ye = proj.yext || proj.extent;
  const s = Math.min(W / 2 / xe, H / 2 / ye) * zoom * 0.96;
  const toScreen = (x, y) => [W / 2 + s * x, H / 2 - s * y];
  const toMap = (sx, sy) => [(sx - W / 2) / s, (H / 2 - sy) / s];
  const sinv = (sx, sy) => {
    const m = toMap(sx, sy), ll = proj.inv(m[0], m[1]);
    if (!ll || !isFinite(ll[0]) || !isFinite(ll[1])) return null;
    const b = proj.fwd(ll[0], ll[1]);
    if (!b) return null;
    const q = toScreen(b[0], b[1]);
    if (Math.hypot(q[0] - sx, q[1] - sy) > 1e-3) return null; // round trip
    return ll;
  };
  const sfwd = (lon, lat, side) => { const m = proj.fwd(lon, lat, side); return m ? toScreen(m[0], m[1]) : null; };
  return { W, H, s, sinv, sfwd };
}

// unwrap b relative to a
function near(a, b) { while (b - a > 180) b -= 360; while (b - a < -180) b += 360; return b; }

// Screen error of a triangle (vertices {x,y,lon,lat}), max over centroid + edge midpoints.
const SAMPLES = [[1/3,1/3,1/3],[.5,.5,0],[0,.5,.5],[.5,0,.5]];
function triError(view, a, b, c) {
  let e = 0;
  for (const w of SAMPLES) {
    const sx = w[0]*a.x + w[1]*b.x + w[2]*c.x, sy = w[0]*a.y + w[1]*b.y + w[2]*c.y;
    const lon = w[0]*a.lon + w[1]*b.lon + w[2]*c.lon, lat = w[0]*a.lat + w[1]*b.lat + w[2]*c.lat;
    const q = view.sfwd(lon, lat);
    const d = q ? Math.hypot(q[0] - sx, q[1] - sy) : 1e9;
    if (d > e) e = d;
  }
  return e;
}

function pointInTri(px, py, a, b, c) {
  const d1 = (px - b.x) * (a.y - b.y) - (a.x - b.x) * (py - b.y);
  const d2 = (px - c.x) * (b.y - c.y) - (b.x - c.x) * (py - c.y);
  const d3 = (px - a.x) * (c.y - a.y) - (c.x - a.x) * (py - a.y);
  const neg = d1 < 0 || d2 < 0 || d3 < 0, pos = d1 > 0 || d2 > 0 || d3 > 0;
  return !(neg && pos);
}

// opts: {N, unwrap, poleFan, rimClip, refine, tol, maxDepth}
function buildMesh(proj, view, opts) {
  const { W, H } = view, N = opts.N, M = Math.max(1, Math.round(N * H / W));
  const verts = [];
  for (let j = 0; j <= M; j++) for (let i = 0; i <= N; i++) {
    const x = i * W / N, y = j * H / M, ll = view.sinv(x, y);
    verts.push(ll ? { x, y, lon: ll[0], lat: ll[1], ok: true } : { x, y, ok: false });
  }
  const poleS = proj.poles.map(p => { const q = view.sfwd(p[0], p[1]); return q ? { x: q[0], y: q[1], lat: p[1] } : null; }).filter(Boolean);
  const out = []; // triangles [a,b,c,err,kind]
  const stats = { base: 0, dropped: 0, clipped: 0, fans: 0, smears: 0, refined: 0 };

  const bisect = (g, b) => { // g valid, b invalid -> boundary vertex
    let lo = [g.x, g.y], hi = [b.x, b.y], ll = [g.lon, g.lat];
    for (let k = 0; k < 14; k++) {
      const m = [(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2], r = view.sinv(m[0], m[1]);
      if (r) { lo = m; ll = r; } else hi = m;
    }
    return { x: lo[0], y: lo[1], lon: ll[0], lat: ll[1], ok: true };
  };

  const emit = (a, b, c, depth, kind) => {
    // a,b,c already unwrapped consistently
    const e = triError(view, a, b, c);
    if (opts.refine && e > opts.tol && depth < opts.maxDepth) {
      // split longest edge
      const L = [[a, b, c], [b, c, a], [c, a, b]].map(t => [Math.hypot(t[0].x - t[1].x, t[0].y - t[1].y), t]);
      L.sort((p, q) => q[0] - p[0]);
      const [p, q, r] = L[0][1];
      const mx = (p.x + q.x) / 2, my = (p.y + q.y) / 2;
      let ll = view.sinv(mx, my);
      let m;
      if (ll) {
        // a pole vertex has arbitrary lon; keep the meridian of the other end
        const ref = Math.abs(p.lat) > 89.9999 ? q.lon : p.lon;
        m = { x: mx, y: my, lon: Math.abs(ll[1]) > 89.9999 ? ref : near(ref, ll[0]), lat: ll[1] };
      } else { m = { x: mx, y: my, lon: (p.lon + q.lon) / 2, lat: (p.lat + q.lat) / 2 }; }
      stats.refined++;
      emit(p, m, r, depth + 1, kind); emit(m, q, r, depth + 1, kind);
      return;
    }
    out.push([a, b, c, e, kind]);
  };

  const handle = (tri, kind) => {
    // a vertex exactly on a pole has no longitude of its own: give it the
    // mean of the other corners (exact, as in the pole split)
    const isP = v => Math.abs(v.lat) > 89.9999;
    let ord = tri.slice();
    while (isP(ord[0]) && ord.some(v => !isP(v))) ord.push(ord.shift());
    let [a, b, c] = ord;
    let lb = b.lon, lc = c.lon;
    if (opts.unwrap) { lb = near(a.lon, b.lon); lc = near(a.lon, c.lon); }
    const A = { ...a }, B = { ...b, lon: lb }, C = { ...c, lon: lc };
    if (isP(B)) B.lon = (A.lon + C.lon) / 2;
    if (isP(C)) C.lon = (A.lon + B.lon) / 2;
    const span = Math.max(A.lon, B.lon, C.lon) - Math.min(A.lon, B.lon, C.lon);
    if (span > 180) {
      const pole = poleS.find(p => pointInTri(p.x, p.y, A, B, C));
      if (pole && opts.poleFan) {
        stats.fans++;
        for (const [p, q] of [[A, B], [B, C], [C, A]]) {
          const q2 = { ...q, lon: near(p.lon, q.lon) };
          const P = { x: pole.x, y: pole.y, lon: (p.lon + q2.lon) / 2, lat: pole.lat };
          emit(P, { ...p }, q2, 0, "fan");
        }
        return;
      }
      if (opts.unwrap && !opts.showSmear) { stats.dropped++; return; } // ocv-style hole
      stats.smears++;
    }
    emit(A, B, C, 0, kind);
  };

  for (let j = 0; j < M; j++) for (let i = 0; i < N; i++) {
    const k = j * (N + 1) + i, v00 = verts[k], v10 = verts[k + 1], v01 = verts[k + N + 1], v11 = verts[k + N + 2];
    for (const t of [[v00, v01, v10], [v10, v01, v11]]) {
      stats.base++;
      const okc = t.filter(v => v.ok).length;
      if (okc === 3) { handle(t, "grid"); continue; }
      if (okc === 0 || !opts.rimClip) { if (okc) stats.dropped++; continue; }
      // clip polygon to valid part
      const poly = [];
      for (let e = 0; e < 3; e++) {
        const p = t[e], q = t[(e + 1) % 3];
        if (p.ok) poly.push(p);
        if (p.ok !== q.ok) poly.push(p.ok ? bisect(p, q) : bisect(q, p));
      }
      stats.clipped++;
      for (let e = 1; e + 1 < poly.length; e++) handle([poly[0], poly[e], poly[e + 1]], "rim");
    }
  }
  return { tris: out, stats };
}
if (typeof module !== "undefined") module.exports = { makeOrtho, makeStereS, makeEqualEarth, makeGoode, makeView, buildMesh, wrap180, SAMPLES };
