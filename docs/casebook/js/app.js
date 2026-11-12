const CASES = [
  { id: "flat", group: "grid", label: "Constant mesh", set: { proj: "ortho", lon0: 147, lat0: -42, zoom: 0, grid: 64, unwrap: 1, poleFan: 1, rimClip: 1, refine: 0, heat: 1, wire: 0 },
    verdict: ["right", "the constant-mesh model holds where the inverse is smooth"],
    what: "A 64 cell screen grid over a globe centred on Hobart, the ortho-cog-viewer default. Across most of the disc the error is a fraction of a pixel to about one pixel and it is even, as the constant-mesh model says. It rises at the limb and around the pole.",
    tryit: "Move <b>Grid cells</b>: error falls with the square of the cell size in the flat middle, but the limb and pole rings stay hot much longer." },
  { id: "pole", group: "grid", label: "Pole in view", set: { proj: "ortho", lon0: 25, lat0: -78, zoom: 1.2, grid: 64, unwrap: 1, poleFan: 1, rimClip: 1, refine: 0, heat: 1, wire: 1 },
    verdict: ["right", "the split is exact, its neighbours are not"],
    what: "Longitude curves like 1/r around the pole. The triangle that holds the pole is split into three, which is exact there. The ring of triangles around it each span tens of degrees of longitude and are several pixels off.",
    tryit: "Turn off <b>Split pole triangle</b> to see the old hole. Turn on <b>Refine</b> to see the error-driven fix: only the ring around the pole gets denser." },
  { id: "horizon", group: "grid", label: "Horizon", set: { proj: "ortho", lon0: 147, lat0: -42, zoom: 0, grid: 24, unwrap: 1, poleFan: 1, rimClip: 0, refine: 0, heat: 0, wire: 1 },
    verdict: ["right", "round trip test + bisected rim"],
    what: "Beyond the horizon the inverse does not exist. Dropping every triangle with an invalid corner leaves a staircase one cell deep. ortho-cog-viewer bisects each crossing edge to the rim and clips the triangle there.",
    tryit: "Turn on <b>Clip at the rim</b>. Then turn on <b>Error heat</b>: the limb is where the inverse is steepest, so the rim triangles carry the largest error on the globe." },
  { id: "am", group: "grid", label: "Antimeridian", set: { proj: "eqearth", lon0: 150, lat0: 0, zoom: 0, grid: 64, unwrap: 0, poleFan: 1, rimClip: 1, refine: 0, heat: 0, wire: 0 },
    verdict: ["right", "per-triangle unwrap, REPEAT sampling"],
    what: "Equal Earth centred on 150E puts the source raster's 180 meridian inside the map. Without unwrapping, a triangle with corners at 179E and 179W interpolates u across the whole texture and smears the world into a band.",
    tryit: "Turn on <b>Unwrap u per triangle</b>. The remaining heat sits at the map's own edge and its pole lines, where the inverse is again singular." },
  { id: "stere", group: "grid", label: "Polar stereographic", set: { proj: "stere", lon0: 0, lat0: -90, zoom: 0, grid: 64, unwrap: 1, poleFan: 1, rimClip: 1, refine: 0, heat: 1, wire: 0 },
    verdict: ["open", "grid size is not tied to error"],
    what: "South polar stereographic out to the equator. No horizon here, so the only hot spot is the pole ring. Elsewhere the 64 grid is close to a quarter pixel.",
    tryit: "Turn on <b>Refine</b> at 0.25 px: about a quarter more triangles, all near the pole, and the worst error drops from 11 px to a third of a pixel." },
  { id: "seams", group: "grid", label: "Tiles and seams", set: { proj: "ortho", lon0: 25, lat0: -78, zoom: 0.5, grid: 32, unwrap: 1, poleFan: 1, rimClip: 1, refine: 1, tol: -1, heat: 0, wire: 1 },
    verdict: ["right", "screen meshes cannot crack"],
    what: "Refinement leaves T-junctions where a split edge meets an unsplit one. In a screen mesh that is harmless: every vertex is placed in screen space, so the new vertex lies exactly on its neighbour's edge. A per-tile mesh built in source space places its vertices by forward projection, so the same T-junction opens a crack. ortho-cog-viewer also stitches one texture per layer, so there are no tile edges to meet.",
    tryit: "Zoom in on a refined patch with <b>Triangles</b> on: the T-junctions are visible and the image has no gaps." },
  { id: "goode", group: "grid", label: "Interrupted (Goode)", set: { proj: "goode", lon0: 0, lat0: 0, zoom: 0, grid: 64, unwrap: 1, poleFan: 1, rimClip: 1, refine: 0, heat: 1, wire: 0 },
    verdict: ["open", "the validity test only sees corners"],
    what: "Goode's interrupted homolosine cuts the oceans into gaps between six lobes. Most of a gap is just more rim, clipped like the horizon. Towards the equator each gap narrows to a point, and there a triangle can have every corner valid, one in each lobe, while straddling the gap. Its texture is interpolated across the cut, and the error jumps to tens of pixels.",
    tryit: "Turn on <b>Refine</b>: the cut tips stay hot, because splitting a triangle that straddles a cut gives smaller triangles that still straddle it. The fix is to know where the cuts are, which is what the source-tile version does." },
  { id: "t-polar", group: "tiles", label: "Polar tiles", set: { mesh: "tiles", proj: "stere", lon0: 0, lat0: -90, zoom: 0, maxErr: -3, unit: "tile", poleGuard: 1, cut: 1, conform: 0, tileEdges: 1, heat: 0, wire: 1 },
    verdict: ["note", "the picture in the custom-projection example"],
    what: "Lon/lat tiles picked by level of detail (a source pixel at most one screen pixel at the tile centre), each meshed on its own in source space from two seed triangles, split until the error at the centroid and edge midpoints is under 0.125 of one source pixel's size on screen. Near the pole, longitude bends fastest, so the disc is dense and the pole row collapses into needle fans.",
    tryit: "Turn on <b>Error heat</b>: every triangle is under tolerance, the density is what it costs. Compare the triangle count with the screen-grid cases." },
  { id: "t-unit", group: "tiles", label: "Tolerance unit", set: { mesh: "tiles", proj: "stere", lon0: 0, lat0: -90, zoom: 0, maxErr: -3, unit: "tile", poleGuard: 1, cut: 1, conform: 0, tileEdges: 1, heat: 0, wire: 1 },
    verdict: ["note", "a fraction of a source pixel, measured once per tile"],
    what: "The tolerance is 0.125 times one source pixel's size on screen, measured at the tile centre. Level of detail keeps that pixel at or under one screen pixel, so each tile is held to 0.125 screen px or tighter, and the unit changes from tile to tile and across a tile.",
    tryit: "Switch <b>Unit</b> to one screen pixel for every tile. Same picture within the tolerance, fewer triangles, and the T-junction count drops to zero because neighbours now apply the same test." },
  { id: "t-seams", group: "tiles", label: "Tile seams", set: { mesh: "tiles", proj: "ortho", lon0: 25, lat0: -78, zoom: 1.2, maxErr: -3, unit: "tile", poleGuard: 1, cut: 1, conform: 0, tileEdges: 1, tj: 1, heat: 0, wire: 0 },
    verdict: ["note", "T-junctions between independent tile meshes"],
    what: "Each tile is meshed alone, so a vertex on one side of a tile edge often has no partner on the other side. In a source-space mesh that vertex is projected exactly while the neighbour's edge is drawn straight, so a sliver opens between them. The markers show every such T-junction; the widest crack is in the stats. Because each tile meets its tolerance, the cracks stay below 0.125 px: hairline sparkle, not gaps.",
    tryit: "Turn on <b>Conform tile edges</b>: each T-junction forces the neighbour to split the same edge, and the count goes to zero for a handful of extra triangles." },
  { id: "t-guard", group: "tiles", label: "Pole guard", set: { mesh: "tiles", proj: "ortho", lon0: 25, lat0: -89.5, zoom: 4, maxErr: -3, unit: "tile", poleGuard: 1, cut: 1, conform: 0, tileEdges: 1, heat: 0, wire: 1 },
    verdict: ["note", "a leftover from input-pixel error"],
    what: "Geographic tiles stop 0.5 degrees short of each pole, a guard from when error was measured in input pixels through the inverse. Zoomed in on the South Pole it shows as a hole.",
    tryit: "Turn off <b>Pole guard</b>: with error measured forward, in output pixels, the pole row is fine and the hole closes." },
  { id: "t-horizon", group: "tiles", label: "Horizon", set: { mesh: "tiles", proj: "ortho", lon0: 147, lat0: -42, zoom: 0, maxErr: -3, unit: "tile", poleGuard: 1, cut: 1, conform: 0, tileEdges: 1, heat: 0, wire: 0 },
    verdict: ["note", "box seeds cannot follow a curved domain"],
    what: "A tile that crosses the horizon has corners with no forward projection. Here such triangles are split a few levels towards the limb and then dropped, which leaves a sliver of the disc uncovered (about 0.1% at this size). How big the sliver is depends only on how far the mesher chases the edge. deck.gl-raster does not offer an orthographic globe; seeds clipped to the visible hemisphere (as in the survey page) would fix it without touching the mesher.",
    tryit: "Compare the limb with the Horizon case under the screen grid, which bisects to the rim." },
  { id: "t-am", group: "tiles", label: "Antimeridian", set: { mesh: "tiles", proj: "eqearth", lon0: 150, lat0: 0, zoom: 0, maxErr: -3, unit: "tile", poleGuard: 1, cut: 0, conform: 0, tileEdges: 1, heat: 0, wire: 0 },
    verdict: ["note", "handled upstream by unwrap and clip"],
    what: "With the map centred on 150E, the map's own edge (30W) runs through a source tile. Projected as one piece, that tile's triangles stretch across the whole map. deck.gl-raster unwraps the projection and clips the mesh at the world edge; this page splits the tile at the edge meridian, which gives the same picture here.",
    tryit: "Turn on <b>Split at map edges / lobes</b>." },
  { id: "t-goode", group: "tiles", label: "Interrupted (Goode)", set: { mesh: "tiles", proj: "goode", lon0: 0, lat0: 0, zoom: 0, maxErr: -3, unit: "tile", poleGuard: 1, cut: 0, conform: 0, tileEdges: 1, heat: 0, wire: 0 },
    verdict: ["note", "cuts known in advance are easy in source space"],
    what: "Projected as whole tiles, every tile that spans an interruption pulls its triangles across the ocean gap between two lobes. In source space the cuts are meridians, one set for each hemisphere, so splitting each tile at those meridians and projecting each part into its own lobe is exact.",
    tryit: "Turn on <b>Split at map edges / lobes</b>. The gaps open cleanly, including the tips at the equator that defeat the screen grid." },
];

const $ = id => document.getElementById(id);
const DEF = { mesh: "grid", proj: "ortho", lon0: 147, lat0: -42, zoom: 0, grid: 64, tol: -2, unwrap: 1, poleFan: 1, rimClip: 1, refine: 0, heat: 1, wire: 0,
  maxErr: -3, unit: "tile", poleGuard: 1, cut: 1, conform: 0, tileEdges: 0, tj: 1 };
const S = { ...DEF };
let mesh = null, view = null, projObj = null;

// ---------- texture ----------
function makeTexture() {
  const W = 4096, H = 2048, c = document.createElement("canvas"); c.width = W; c.height = H;
  const g = c.getContext("2d");
  const X = lon => (lon + 180) / 360 * W, Y = lat => (90 - lat) / 180 * H;
  for (let lat = -90; lat < 90; lat += 10) {
    const t = Math.abs(lat + 5) / 90;
    for (let lon = -180; lon < 180; lon += 30) {
      const odd = ((lon + 180) / 30 + (lat + 90) / 10) % 2;
      const hue = 205 - 160 * (1 - t), light = 78 - 18 * t + (odd ? 6 : 0);
      g.fillStyle = `hsl(${hue} ${30 + 20 * (1 - t)}% ${light}%)`;
      g.fillRect(X(lon), Y(lat + 10), W / 12 + 1, H / 18 + 1);
    }
  }
  g.strokeStyle = "rgba(20,30,40,0.35)"; g.lineWidth = 1.2;
  for (let lat = -90; lat <= 90; lat += 1) { if (Math.abs(lat) < 75 && lat % 10) continue; g.beginPath(); g.moveTo(0, Y(lat)); g.lineTo(W, Y(lat)); g.stroke(); }
  for (let lon = -180; lon <= 180; lon += 1) {
    if (lon % 10) { g.beginPath(); g.moveTo(X(lon), 0); g.lineTo(X(lon), Y(75)); g.moveTo(X(lon), Y(-75)); g.lineTo(X(lon), H); g.stroke(); }
  }
  g.strokeStyle = "rgba(15,25,35,0.85)"; g.lineWidth = 3;
  for (let lat = -80; lat <= 80; lat += 10) { g.beginPath(); g.moveTo(0, Y(lat)); g.lineTo(W, Y(lat)); g.stroke(); }
  for (let lon = -170; lon <= 170; lon += 10) { g.beginPath(); g.moveTo(X(lon), 0); g.lineTo(X(lon), H); g.stroke(); }
  g.strokeStyle = "#0f8ea8"; g.lineWidth = 10;
  for (const x of [2, W - 2]) { g.beginPath(); g.moveTo(x, 0); g.lineTo(x, H); g.stroke(); }
  g.fillStyle = "rgba(15,25,35,0.9)"; g.font = "600 34px sans-serif"; g.textAlign = "center"; g.textBaseline = "middle";
  for (let lon = -150; lon <= 180; lon += 30) for (const lat of [-65, -35, 5, 35, 65]) {
    const s = lon === 180 ? "180" : Math.abs(lon) + (lon < 0 ? "W" : lon > 0 ? "E" : "");
    g.fillText(s, X(lon) - (lon === 180 ? 60 : 0) + 60, Y(lat));
  }
  for (const lat of [-80, -70, -60, -50, 50, 60, 70, 80]) g.fillText(Math.abs(lat) + (lat < 0 ? "S" : "N"), X(-165) + 0, Y(lat) + 22);
  return c;
}

// ---------- GL ----------
const canvas = $("gl");
const gl = canvas.getContext("webgl", { antialias: true, premultipliedAlpha: false });
function sh(type, src) { const s = gl.createShader(type); gl.shaderSource(s, src); gl.compileShader(s); if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw gl.getShaderInfoLog(s); return s; }
function prog(vs, fs) { const p = gl.createProgram(); gl.attachShader(p, sh(gl.VERTEX_SHADER, vs)); gl.attachShader(p, sh(gl.FRAGMENT_SHADER, fs)); gl.linkProgram(p); return p; }
const P = prog(`attribute vec2 pos; attribute vec2 uv; attribute float err; uniform vec2 res; varying vec2 vuv; varying float verr;
  void main(){ vuv = uv; verr = err; gl_Position = vec4(pos.x/res.x*2.0-1.0, 1.0-pos.y/res.y*2.0, 0, 1); }`,
  `precision highp float; varying vec2 vuv; varying float verr; uniform sampler2D tex; uniform float heat;
  vec3 ramp(float t){ vec3 a=vec3(1.0,0.9,0.35), b=vec3(1.0,0.6,0.18), c=vec3(0.9,0.22,0.16), d=vec3(0.76,0.09,0.6);
    return t<0.33? mix(a,b,t/0.33) : t<0.66? mix(b,c,(t-0.33)/0.33) : mix(c,d,(t-0.66)/0.34); }
  void main(){ vec4 col = texture2D(tex, vuv);
    if (heat > 0.5) { float t = clamp((log2(max(verr,1e-4)) + 3.0) / 7.0, 0.0, 1.0);
      float a = verr < 0.125 ? 0.0 : 0.35 + 0.45 * smoothstep(0.0, 0.3, t); col.rgb = mix(col.rgb * 0.92, ramp(t), a); }
    gl_FragColor = vec4(col.rgb, 1.0); }`);
const L = prog(`attribute vec2 pos; uniform vec2 res; uniform float psize; void main(){ gl_PointSize = psize; gl_Position = vec4(pos.x/res.x*2.0-1.0, 1.0-pos.y/res.y*2.0, 0, 1); }`,
  `precision mediump float; uniform vec4 col; void main(){ gl_FragColor = col; }`);
const tex = gl.createTexture();
gl.bindTexture(gl.TEXTURE_2D, tex);
gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, makeTexture());
gl.generateMipmap(gl.TEXTURE_2D);
gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
const ext = gl.getExtension("EXT_texture_filter_anisotropic");
if (ext) gl.texParameterf(gl.TEXTURE_2D, ext.TEXTURE_MAX_ANISOTROPY_EXT, 8);
const triBuf = gl.createBuffer(), lineBuf = gl.createBuffer(), ovBuf = gl.createBuffer(), ptBuf = gl.createBuffer();
let nTriV = 0, nLineV = 0, nOv = 0, nPt = 0;
// share of the map's valid area that the mesh covers, by sampling
function coverage() {
  const n = 300, W = view.W, H = view.H; let inMap = 0, A = 0;
  for (let j = 0; j < n; j++) for (let i = 0; i < n; i++) if (view.sinv((i + 0.5) * W / n, (j + 0.5) * H / n)) inMap++;
  const clip = (poly, f) => { const o = []; for (let k = 0; k < poly.length; k++) { const P = poly[k], Q = poly[(k + 1) % poly.length], a = f(P), b = f(Q);
    if (a >= 0) o.push(P); if ((a >= 0) !== (b >= 0)) { const t = a / (a - b); o.push([P[0] + t * (Q[0] - P[0]), P[1] + t * (Q[1] - P[1])]); } } return o; };
  for (const [p, q, r] of mesh.tris) {
    let poly = [[p.x, p.y], [q.x, q.y], [r.x, r.y]];
    for (const f of [v => v[0], v => W - v[0], v => v[1], v => H - v[1]]) { if (poly.length < 3) break; poly = clip(poly, f); }
    let s = 0; for (let k = 0; k < poly.length; k++) { const P = poly[k], Q = poly[(k + 1) % poly.length]; s += P[0] * Q[1] - Q[0] * P[1]; }
    A += Math.abs(s) / 2;
  }
  const valid = inMap * (W / n) * (H / n);
  return valid ? (100 * A / valid).toFixed(1) + "%" : "n/a";
}

function cssSize() { const r = canvas.getBoundingClientRect(); return Math.max(200, Math.round(r.width)); }

function rebuild() {
  const W = cssSize(), dpr = Math.min(2, window.devicePixelRatio || 1);
  const world = S.proj === "eqearth" || S.proj === "goode", H = world ? Math.round(W * 0.5) : W;
  canvas.style.aspectRatio = world ? "2 / 1" : "1";
  if (canvas.width !== Math.round(W * dpr) || canvas.height !== Math.round(H * dpr)) { canvas.width = Math.round(W * dpr); canvas.height = Math.round(H * dpr); }
  projObj = S.proj === "ortho" ? makeOrtho(S.lon0, S.lat0) : S.proj === "stere" ? makeStereS(S.lon0) : S.proj === "goode" ? makeGoode() : makeEqualEarth(S.lon0);
  view = makeView(projObj, W, H, Math.pow(2, S.zoom));
  if (S.mesh === "tiles") mesh = buildTileMesh(projObj, view, { unit: S.unit, maxError: Math.pow(2, S.maxErr), poleGuard: !!S.poleGuard, cut: !!S.cut, conform: !!S.conform });
  else mesh = buildMesh(projObj, view, { N: S.grid, unwrap: !!S.unwrap, poleFan: !!S.poleFan, rimClip: !!S.rimClip,
    refine: !!S.refine, tol: Math.pow(2, S.tol), maxDepth: 12, showSmear: !S.unwrap });
  const t = mesh.tris, a = new Float32Array(t.length * 15), l = S.wire ? new Float32Array(t.length * 12) : null;
  let k = 0, m = 0, Atot = 0, Abad = 0, emax = 0;
  for (const tri of t) {
    const e = tri[3];
    for (let i = 0; i < 3; i++) { const v = tri[i]; a[k++] = v.x; a[k++] = v.y; a[k++] = (v.lon + 180) / 360; a[k++] = (90 - v.lat) / 180; a[k++] = e; }
    if (l) for (let i = 0; i < 3; i++) { const p = tri[i], q = tri[(i + 1) % 3]; l[m++] = p.x; l[m++] = p.y; l[m++] = q.x; l[m++] = q.y; }
    const ar = Math.abs((tri[1].x - tri[0].x) * (tri[2].y - tri[0].y) - (tri[2].x - tri[0].x) * (tri[1].y - tri[0].y)) / 2;
    Atot += ar; if (e > 0.5) Abad += ar; if (e > emax) emax = e;
  }
  gl.bindBuffer(gl.ARRAY_BUFFER, triBuf); gl.bufferData(gl.ARRAY_BUFFER, a, gl.DYNAMIC_DRAW); nTriV = t.length * 3;
  if (l) { gl.bindBuffer(gl.ARRAY_BUFFER, lineBuf); gl.bufferData(gl.ARRAY_BUFFER, l, gl.DYNAMIC_DRAW); nLineV = t.length * 6; } else nLineV = 0;
  const st = mesh.stats, fmt = n => n.toLocaleString("en-US");
  const px = e => e >= 100 ? fmt(Math.round(e)) + " px" : e.toFixed(e < 1 ? 3 : 2) + " px";
  const cov = coverage();
  const rows = [["Triangles", fmt(t.length)], ["Worst error", px(emax)], ["Area > 0.5 px", Atot ? (100 * Abad / Atot).toFixed(1) + "%" : "0%"]];
  if (S.mesh === "tiles") rows.push(["Tiles", fmt(st.tiles) + (st.levels > 1 ? " / " + st.levels + " lv" : "")], ["T-junctions", fmt(st.tjunctions)], ["Widest crack", px(st.crackMax)]);
  else rows.push(["Pole fans", fmt(st.fans)], ["Rim clipped", fmt(st.clipped)], ["Dropped", fmt(st.dropped)]);
  rows.push(["Mesh area / map", cov]);
  $("stats").innerHTML = rows.map(r => `<div class="stat"><span>${r[0]}</span><b>${r[1]}</b></div>`).join("");
  // overlays: tile outlines and T-junction markers
  const ov = [], pts = [];
  if (S.mesh === "tiles" && S.tileEdges) for (const tl of mesh.tiles) {
    const ring = [];
    const n = 24, side = tl.side;
    for (let k = 0; k < n; k++) ring.push([tl.lon0 + (tl.lon1 - tl.lon0) * k / n, tl.lat0]);
    for (let k = 0; k < n; k++) ring.push([tl.lon1, tl.lat0 + (tl.lat1 - tl.lat0) * k / n]);
    for (let k = 0; k < n; k++) ring.push([tl.lon1 - (tl.lon1 - tl.lon0) * k / n, tl.lat1]);
    for (let k = 0; k < n; k++) ring.push([tl.lon0, tl.lat1 - (tl.lat1 - tl.lat0) * k / n]);
    for (let k = 0; k < ring.length; k++) {
      const p = view.sfwd(ring[k][0], ring[k][1], side), q = view.sfwd(ring[(k + 1) % ring.length][0], ring[(k + 1) % ring.length][1], side);
      if (p && q && Math.hypot(p[0] - q[0], p[1] - q[1]) < W / 4) ov.push(p[0], p[1], q[0], q[1]);
    }
  }
  if (S.mesh === "tiles" && S.tj) for (const j of mesh.tj) if (j.P.ok) pts.push(j.P.x, j.P.y);
  gl.bindBuffer(gl.ARRAY_BUFFER, ovBuf); gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(ov), gl.DYNAMIC_DRAW); nOv = ov.length / 2;
  gl.bindBuffer(gl.ARRAY_BUFFER, ptBuf); gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(pts), gl.DYNAMIC_DRAW); nPt = pts.length / 2;
  draw();
}

function draw() {
  const W = cssSize();
  gl.viewport(0, 0, canvas.width, canvas.height);
  const dark = getComputedStyle(document.documentElement).colorScheme.includes("dark") && matchesDark();
  const bg = dark ? [0.09, 0.125, 0.16] : [1, 1, 1];
  gl.clearColor(bg[0], bg[1], bg[2], 1); gl.clear(gl.COLOR_BUFFER_BIT);
  gl.useProgram(P);
  gl.bindBuffer(gl.ARRAY_BUFFER, triBuf);
  const ap = gl.getAttribLocation(P, "pos"), au = gl.getAttribLocation(P, "uv"), ae = gl.getAttribLocation(P, "err");
  gl.enableVertexAttribArray(ap); gl.enableVertexAttribArray(au); gl.enableVertexAttribArray(ae);
  gl.vertexAttribPointer(ap, 2, gl.FLOAT, false, 20, 0); gl.vertexAttribPointer(au, 2, gl.FLOAT, false, 20, 8); gl.vertexAttribPointer(ae, 1, gl.FLOAT, false, 20, 16);
  gl.uniform2f(gl.getUniformLocation(P, "res"), W, view.H); gl.uniform1f(gl.getUniformLocation(P, "heat"), S.heat ? 1 : 0);
  gl.uniform1i(gl.getUniformLocation(P, "tex"), 0);
  gl.drawArrays(gl.TRIANGLES, 0, nTriV);
  gl.disableVertexAttribArray(au); gl.disableVertexAttribArray(ae);
  if (nLineV) {
    gl.useProgram(L); gl.enable(gl.BLEND); gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    gl.bindBuffer(gl.ARRAY_BUFFER, lineBuf);
    const lp = gl.getAttribLocation(L, "pos"); gl.enableVertexAttribArray(lp); gl.vertexAttribPointer(lp, 2, gl.FLOAT, false, 8, 0);
    gl.uniform2f(gl.getUniformLocation(L, "res"), W, view.H); gl.uniform4f(gl.getUniformLocation(L, "col"), 0.05, 0.12, 0.18, 0.45);
    gl.uniform1f(gl.getUniformLocation(L, "psize"), 1.0);
    gl.drawArrays(gl.LINES, 0, nLineV); gl.disable(gl.BLEND);
  }
  const dpr = canvas.width / W;
  const overlay = (buf, n, mode, col, ps) => {
    if (!n) return;
    gl.useProgram(L); gl.enable(gl.BLEND); gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    gl.bindBuffer(gl.ARRAY_BUFFER, buf);
    const lp = gl.getAttribLocation(L, "pos"); gl.enableVertexAttribArray(lp); gl.vertexAttribPointer(lp, 2, gl.FLOAT, false, 8, 0);
    gl.uniform2f(gl.getUniformLocation(L, "res"), W, view.H); gl.uniform4f(gl.getUniformLocation(L, "col"), col[0], col[1], col[2], col[3]);
    gl.uniform1f(gl.getUniformLocation(L, "psize"), ps * dpr);
    gl.drawArrays(mode, 0, n); gl.disable(gl.BLEND);
  };
  overlay(ovBuf, nOv, gl.LINES, [0.93, 0.25, 0.6, 0.95], 1);
  overlay(ptBuf, nPt, gl.POINTS, [0.75, 0.05, 0.55, 0.95], 5);
}
function matchesDark() {
  const t = document.documentElement.getAttribute("data-theme");
  if (t) return t === "dark";
  return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
}

// ---------- probe ----------
function probe(sx, sy) {
  if (!mesh) return;
  let hit = null;
  for (const t of mesh.tris) if (pointInTriExact(sx, sy, t[0], t[1], t[2])) { hit = t; break; }
  const ll = view.sinv(sx, sy);
  if (!ll) { $("probe").textContent = "off the map"; return; }
  const f = (lon, lat) => `${Math.abs(lat).toFixed(3)}${lat < 0 ? "S" : "N"} ${Math.abs(wrapLon(lon)).toFixed(3)}${wrapLon(lon) < 0 ? "W" : "E"}`;
  let txt = "exact inverse  " + f(ll[0], ll[1]);
  if (hit) {
    const [a, b, c] = hit, den = (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y);
    const w0 = ((b.y - c.y) * (sx - c.x) + (c.x - b.x) * (sy - c.y)) / den, w1 = ((c.y - a.y) * (sx - c.x) + (a.x - c.x) * (sy - c.y)) / den, w2 = 1 - w0 - w1;
    const lon = w0 * a.lon + w1 * b.lon + w2 * c.lon, lat = w0 * a.lat + w1 * b.lat + w2 * c.lat;
    const q = view.sfwd(lon, lat), d = q ? Math.hypot(q[0] - sx, q[1] - sy) : NaN;
    txt += "\nmesh texture   " + f(lon, lat) + "\noffset here    " + (isFinite(d) ? d.toFixed(2) + " px" : "n/a") + "   triangle " + hit[3].toFixed(2) + " px";
  } else txt += "\nno triangle here";
  $("probe").textContent = txt;
}
function wrapLon(l) { return ((l + 180) % 360 + 360) % 360 - 180; }
function pointInTriExact(px, py, a, b, c) {
  const d1 = (px - b.x) * (a.y - b.y) - (a.x - b.x) * (py - b.y), d2 = (px - c.x) * (b.y - c.y) - (b.x - c.x) * (py - c.y), d3 = (px - a.x) * (c.y - a.y) - (c.x - a.x) * (py - a.y);
  return !((d1 < 0 || d2 < 0 || d3 < 0) && (d1 > 0 || d2 > 0 || d3 > 0));
}

// ---------- UI ----------
const toggles = ["unwrap", "poleFan", "rimClip", "refine", "heat", "wire", "poleGuard", "cut", "conform", "tileEdges", "tj"];
function syncUI() {
  $("mesh").value = S.mesh; $("unit").value = S.unit;
  $("maxErr").value = S.maxErr; $("maxErrOut").textContent = Math.pow(2, S.maxErr).toFixed(3).replace(/0+$/, "").replace(/\.$/, "");
  for (const el of document.querySelectorAll("[data-mode]")) el.hidden = el.dataset.mode !== S.mesh;
  $("proj").value = S.proj; $("grid").value = S.grid; $("gridOut").textContent = S.grid;
  $("zoom").value = S.zoom; $("zoomOut").textContent = Math.pow(2, S.zoom).toFixed(1) + "x";
  $("tol").value = S.tol; $("tolOut").textContent = Math.pow(2, S.tol).toFixed(3).replace(/0+$/, "").replace(/\.$/, "") + " px";
  $("tol").disabled = !S.refine;
  for (const k of toggles) $(k).checked = !!S[k];
}
function setCase(c) {
  Object.assign(S, DEF, c.set);
  for (const b of document.querySelectorAll(".cases button")) b.setAttribute("aria-pressed", b.dataset.id === c.id ? "true" : "false");
  $("note").innerHTML = `<div class="eyebrow">${c.group === "tiles" ? "Source tiles, deck.gl-raster style" : "Screen grid, ortho-cog-viewer style"}</div><h3>${c.label}</h3><span class="verdict ${c.verdict[0]}">${c.verdict[0] === "note" ? "" : c.verdict[0] + ": "}${c.verdict[1]}</span><p>${c.what}</p><p class="try">${c.tryit}</p>`;
  try { localStorage.setItem("wmc-case", c.id); } catch (e) {}
  syncUI(); rebuild();
}
for (const c of CASES) { const b = document.createElement("button"); b.type = "button"; b.textContent = c.label; b.dataset.id = c.id; b.onclick = () => setCase(c); $(c.group === "tiles" ? "casesT" : "casesG").appendChild(b); }
$("mesh").onchange = e => { S.mesh = e.target.value; syncUI(); rebuild(); };
$("unit").onchange = e => { S.unit = e.target.value; syncUI(); rebuild(); };
$("maxErr").oninput = e => { S.maxErr = +e.target.value; syncUI(); rebuild(); };
$("proj").onchange = e => { S.proj = e.target.value; if (S.proj !== "ortho") S.lat0 = 0; syncUI(); rebuild(); };
for (const id of ["grid", "zoom", "tol"]) $(id).oninput = e => { S[id] = +e.target.value; syncUI(); rebuild(); };
for (const k of toggles) $(k).onchange = e => { S[k] = e.target.checked ? 1 : 0; syncUI(); rebuild(); };

let drag = null, pending = false;
const local = e => { const r = canvas.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; };
canvas.addEventListener("pointerdown", e => { drag = { p: local(e), lon0: S.lon0, lat0: S.lat0 }; canvas.setPointerCapture(e.pointerId); canvas.style.cursor = "grabbing"; });
canvas.addEventListener("pointermove", e => {
  const p = local(e);
  if (drag && S.proj !== "goode") {
    const k = 180 / (view.s * Math.PI) * (S.proj === "eqearth" ? 2.7 : S.proj === "stere" ? 2 : 1);
    S.lon0 = wrapLon(drag.lon0 - (p[0] - drag.p[0]) * k);
    if (S.proj === "ortho") S.lat0 = Math.max(-90, Math.min(90, drag.lat0 + (p[1] - drag.p[1]) * k));
    if (!pending) { pending = true; requestAnimationFrame(() => { pending = false; rebuild(); }); }
  } else probe(p[0], p[1]);
});
const end = () => { drag = null; canvas.style.cursor = "grab"; };
canvas.addEventListener("pointerup", end); canvas.addEventListener("pointercancel", end);
window.addEventListener("resize", () => rebuild());
if (window.matchMedia) window.matchMedia("(prefers-color-scheme: dark)").addEventListener?.("change", draw);
new MutationObserver(draw).observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] });

let start = CASES[0];
try { const id = localStorage.getItem("wmc-case"); start = CASES.find(c => c.id === id) || start; } catch (e) {}
setCase(start);
