const C = require("../js/core.js"); Object.assign(global, C);
const T = require("../js/tiles.js");
const g = C.makeGoode();
// round trips
let bad=0; for (let lon=-179.5; lon<180; lon+=7) for (let lat=-89; lat<90; lat+=7) { const p=g.fwd(lon,lat); const q=g.inv(p[0],p[1]); if(!q||Math.abs(q[0]-lon)>1e-6||Math.abs(q[1]-lat)>1e-6){bad++; if(bad<4) console.log(lon,lat,q);} }
console.log("roundtrip bad", bad, "corner", g.fwd(180,0), g.fwd(0,90), g.fwd(-100,-90));
const v = C.makeView(g, 900, 900, 1);
const base = {N:64, unwrap:true, poleFan:true, rimClip:true, refine:false, tol:0.25, maxDepth:10};
for (const o of [base, {...base, refine:true}]) { const m=C.buildMesh(g,v,o); let e=0; for(const t of m.tris) e=Math.max(e,t[3]); console.log("grid", m.tris.length, e.toFixed(2), JSON.stringify(m.stats)); }
for (const cut of [true,false]) { const m=T.buildTileMesh(g,v,{unit:"tile",maxError:0.125,poleGuard:true,cut,conform:false}); let e=0; for(const t of m.tris) e=Math.max(e,t[3]); console.log("tiles cut", cut, m.tris.length, e.toFixed(2), JSON.stringify(m.stats)); }
const ee = C.makeEqualEarth(150), ve = C.makeView(ee,900,900,1);
for (const cut of [true,false]) { const m=T.buildTileMesh(ee,ve,{unit:"tile",maxError:0.125,poleGuard:true,cut,conform:false}); let e=0; for(const t of m.tris) e=Math.max(e,t[3]); console.log("eqearth cut", cut, m.tris.length, e.toFixed(2), JSON.stringify(m.stats)); }
