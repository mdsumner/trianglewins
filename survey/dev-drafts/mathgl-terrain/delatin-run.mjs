// Run Delatin (the backend math.gl vendored from loaders.gl) on a raw grid.
// usage: node delatin-run.mjs grid.f64 W H tol out.json
import fs from 'node:fs';
import Delatin from 'delatin';
const [file, W, H, tol, out] = process.argv.slice(2);
const buf = fs.readFileSync(file);
const data = new Float64Array(buf.buffer, buf.byteOffset, buf.byteLength / 8);
const t0 = performance.now();
const tin = new Delatin(data, +W, +H);
tin.run(+tol);
const ms = performance.now() - t0;
fs.writeFileSync(out, JSON.stringify({
  coords: Array.from(tin.coords), triangles: Array.from(tin.triangles),
  ms, maxError: tin.getMaxError()
}));
console.log(JSON.stringify({triangles: tin.triangles.length / 3, vertices: tin.coords.length / 2, ms, maxError: tin.getMaxError()}));
