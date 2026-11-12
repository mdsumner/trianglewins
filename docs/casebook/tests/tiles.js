const C = require("../js/core.js"); Object.assign(global, C);
const T = require("../js/tiles.js");
function run(label, proj, opts, zoom=1) {
  const v = C.makeView(proj, 900, 900, zoom);
  const t0 = Date.now(); const m = T.buildTileMesh(proj, v, opts); const dt = Date.now()-t0;
  let emax=0; for (const t of m.tris) if (t[3]>emax) emax=t[3];
  console.log(label, "tris", m.tris.length, "max", emax.toFixed(3), JSON.stringify(m.stats), dt+"ms");
}
const base = {unit:"tile", maxError:0.125, poleGuard:true, cut:true, conform:false};
run("stere tile", C.makeStereS(0), base);
run("stere screen", C.makeStereS(0), {...base, unit:"screen"});
run("stere tile conform", C.makeStereS(0), {...base, conform:true});
run("stere noguard", C.makeStereS(0), {...base, poleGuard:false});
run("ortho -78 z2.3", C.makeOrtho(25,-78), base, 2.3);
run("ortho hobart", C.makeOrtho(147,-42), base);
run("eqearth cut", C.makeEqualEarth(150), base);
run("eqearth nocut", C.makeEqualEarth(150), {...base, cut:false});
