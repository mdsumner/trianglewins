const C = require("../js/core.js");
function run(label, proj, opts, zoom=1) {
  const v = C.makeView(proj, 900, 900, zoom);
  const t0 = Date.now(); const m = C.buildMesh(proj, v, opts); const dt = Date.now()-t0;
  const errs = m.tris.map(t=>t[3]).sort((a,b)=>a-b);
  const area = t => Math.abs((t[1].x-t[0].x)*(t[2].y-t[0].y)-(t[2].x-t[0].x)*(t[1].y-t[0].y))/2;
  let A=0, Abad=0; for (const t of m.tris){const a=area(t);A+=a;if(t[3]>0.5)Abad+=a;}
  console.log(label, "tris", m.tris.length, "max", errs.at(-1).toFixed(2), "p99", errs[Math.floor(errs.length*.99)].toFixed(3), "bad%", (100*Abad/A).toFixed(2), "area", A.toFixed(0), JSON.stringify(m.stats), dt+"ms");
}
const base = {N:64, unwrap:true, poleFan:true, rimClip:true, refine:false, tol:0.25, maxDepth:10};
run("ortho hobart", C.makeOrtho(147,-42), base);
run("ortho pole -90", C.makeOrtho(0,-90), base);
run("ortho -80", C.makeOrtho(20,-80), base);
run("ortho -80 refine", C.makeOrtho(20,-80), {...base, refine:true});
run("ortho hobart refine", C.makeOrtho(147,-42), {...base, refine:true});
run("ortho -80 z4", C.makeOrtho(20,-80), base, 4);
run("stere", C.makeStereS(0), base);
run("stere refine", C.makeStereS(0), {...base, refine:true});
run("eqearth 150", C.makeEqualEarth(150), base);
run("eqearth nounwrap", C.makeEqualEarth(150), {...base, unwrap:false});
run("ortho noclip", C.makeOrtho(147,-42), {...base, rimClip:false});
