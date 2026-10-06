# Roadmap: cdtr, laridae, trowel and the R and Python communities

6 October 2026. A step back from the benchmark and the survey: which
development steps give the most improvement for the most people, which of
this project's packages should go to CRAN and in what order, what stands
in the way of each, and what this work can offer the authors of other
packages, in R and in Python. Claims about our packages were checked
against their repositories on this date (hypertidy/cdtr main,
hypertidy/laridae main, hypertidy/trowel main, mdsumner/trianglewins);
claims about other packages come from their source on the CRAN mirrors and
GitHub, or from PyPI metadata, and are marked (upstream docs) where they
rest on documentation alone.
"Dimension" is used in two senses, kept apart as in the
[survey](../survey/): geometric dimension is the number of coordinates per
vertex (xy, xyz, xyzt), topological dimension is that of the shape (0
point, 1 segment, 2 triangle, 3 tetrahedron). All three packages make
topologically 2-dimensional meshes from xy coordinates.

## In short

1. **Write the contract down before anything goes to CRAN.** The three
   packages agree on vertex / segment / triangle tables, depth and origin,
   but the meaning of depth on doubled boundaries already differs (cdtr and
   laridae count each copy, trowel counts one). Once a package is on CRAN
   its output columns are a promise. A short versioned spec plus the
   trianglewins cases as a conformance corpus fixes that, and is the thing
   other packages, in either language, can adopt.
2. **CRAN order: cdtr, then laridae, then trowel.** trianglewins stays off
   CRAN. Put all four on the hypertidy r-universe now, so users get
   binaries while the CRAN work proceeds.
3. **Two small upstream changes help more people than any feature of our
   own:** an `exclude_faces` set for spade's refinement, and a shared
   home for the CDT headers so the three CRAN packages that vendor CDT
   (RCDT, tulpaMesh, and cdtr when it lands) stop carrying three copies of
   three different versions.
4. **Python has no spade binding and no depth anywhere.** trowel's Rust
   code split into a core crate would give Python an editable constrained
   mesh through PyO3 with little new code, and the conformance corpus would
   let Python packages be judged by the same measures.

## 1. Where the three packages stand

| | cdtr | laridae | trowel |
|---|---|---|---|
| Engine | artem-ogre/CDT 2.0.1 (vendored, identical to upstream master of 21 Sep 2026) | CGAL >= 6.0, `Constrained_triangulation_plus_2`, `Delaunay_mesher_2` | spade 2.15 via extendr |
| Licence | MIT, with MPL-2.0 CDT files and BSD-3 predicates | GPL (>= 3) | MIT; spade MIT/Apache |
| Install needs | a C++ compiler | CGAL 6 and Boost headers (found by `configure`, falls back to RcppCGAL) | cargo and rustc |
| Unique value | refinement on a general PSLG without Triangle's licence; least memory (2.4 GB for the world, against 5.5 to 5.6 for RTriangle and laridae) | sizing field, exact predicates, step-wise mesher, fastest live insert (1000 points into the world mesh in 0.09 s) | editable mesh with stable ids, no CGAL |
| Known weak spots | about 3 ms R wrapper overhead per call; refines one criterion per pass | 8.9 GB peak inserting into the world mesh | slow on large unordered input (152 s for a million points, others 2 to 4 s); stalled on southern Africa with 0 degree triangles; some Steiner attributes take the nearest value |
| Tests | 40 tests, one file | five test files | 49 tests, one file |
| Version | 0.0.0.9000 | 0.1.0.9000 | 0.0.0.9000 |

Numbers are from the [benchmark](../bench/) and the state-of-three notes.

## 2. Development steps, ranked by how much they improve things overall

Ranked by reach (how many users and packages benefit) over cost.

1. **Contract v1 as a written spec and a conformance corpus.** One page:
   column names and types for the three tables in and the three out, what
   depth counts (per boundary copy, or per distinct boundary, or per tag),
   the origin codes, what "unrefined" reports, how attributes are
   interpolated. The trianglewins cases (inst/extdata) and the measures in
   R/measures.R become the corpus: each case is CSV, the expected
   invariants are stated, and the measures can be re-implemented in a few
   dozen lines of Python. Reach: every package here, every future binding,
   and any outside package that wants to be comparable. Cost: days.
   Decide the depth-multiplicity question here, not after release.
2. **r-universe for all four now.** The hypertidy universe builds binaries
   for Windows, macOS and Linux, including Rust (trowel) and packages that
   need CGAL headers from RcppCGAL (laridae). Users stop needing toolchains
   today. Cost: a line each in the universe's packages.json.
3. **cdtr to CRAN** (section 3). It closes the one real gap on CRAN that
   the survey found: quality refinement on an arbitrary segment set with a
   free licence and per-triangle depth. It also unparks anglr's cdtr
   backend, which lets anglr (and a revived sfdct, or its replacement)
   return to CRAN without the non-commercial clause.
4. **Upstream spade `exclude_faces`.** A small PR to spade's
   `RefinementParameters`; spade already keeps an excluded-face set
   internally. trowel's re-refine drops from about 8.4 ms to about 2 ms on
   nc (state-of-three estimate, not yet run), and every spade user gets
   caller-decided refinement regions. Reach: the whole spade user base,
   not only R.
5. **trowel: spatial sort or bulk load in `mesh_new()`.** laridae closed the
   same gap by sorting points before insertion. The benchmark shows this is
   the difference between 152 s and a few seconds on a million points. Fix
   the southern Africa stall and the nearest-value attribute cases in the
   same pass. Without this trowel is not ready for CRAN, whatever the
   toolchain story.
6. **Promote `pslg_from_wk()` out of the guide into cdtr** (wk in
   Suggests). The guide's reader takes any wk-handleable geometry (sf, terra
   via wkb, geos, geoarrow) to the input tables with shared vertices merged.
   Users meet the packages through their sf objects, not through index
   vectors, and this is the missing adapter. cdtr is the first to CRAN, so
   it is the natural home; laridae and trowel can call it.
7. **A shared CDT header package.** RCDT and tulpaMesh vendor pre-2.0 CDT
   (no `refineTriangles`, no `Unrefined` counts); cdtr vendors 2.0.1. A
   header-only package (in the pattern of BH for Boost and RcppCGAL for
   CGAL) that all three could LinkingTo would let one upgrade reach all of
   them. This is an offer to Stephane Laurent (RCDT) and Gilles Colling
   (tulpaMesh), not a precondition for cdtr; cdtr can switch to it later.
8. **CDT combined angle plus area in one pass.** Halves cdtr's refine cost
   (state-of-three estimate). tulpaMesh already does this in its own
   off-centre Ruppert loop (src/mesh.cpp); the useful move is to put a
   combined criterion into CDT itself, where RCDT, tulpaMesh, cdtr and
   PythonCDT all get it.
9. **trowel's Rust core as its own crate, then a PyO3 binding** (section 5).
10. **cdtr wrapper overhead.** About 3 ms per call in R code; worth fixing
    before CRAN only if it is simple, since it only matters for small
    inputs called many times.

Deliberately not on the list: tetrahedral meshing of xyz, periodic and conforming/Gabriel modes in
laridae (PLAN.md section 3.4), and the sphere. fmesher and tulpaMesh
already cover the sphere for statistical meshes; nothing in the benchmark
or the survey shows users of xy triangulation waiting on the others.

## 3. CRAN: order and what blocks each

### Order

| Order | Package | Why this position | Readiness |
|---|---|---|---|
| 1 | cdtr | No system dependency, permissive licence, smallest surface, fills the licence gap, unblocks anglr | Close: packaging items only |
| 2 | laridae | GPL is fine on CRAN; RcppCGAL 6.2.1 (CRAN, 5 Sep 2026) ships CGAL 6.2.1 headers, so CRAN machines can build it with no system CGAL | A decision (it is off CRAN by an earlier choice) and a build-cost check |
| 3 | trowel | Most novel, but the Rust policy is the heaviest and the performance gaps are real | Code work first, then vendoring |
| - | trianglewins | A harness, with every backend in Suggests and Remotes; CRAN would require all Suggests to be installable from CRAN or a declared repository, and the bench needs hours and gigabytes | Stay on GitHub and r-universe |

### cdtr

Blocking:

- **Copyright holders and component licences.** DESCRIPTION lists only
  Michael Sumner, but src/CDT carries Artem Amirkhanov's MPL-2.0 code and
  William C. Lenthe's BSD-3 predicates. Add both to Authors@R as
  `c("ctb", "cph")` with a comment naming the files, and add
  inst/COPYRIGHTS stating that the package is MIT and the CDT files remain
  MPL-2.0 under MPL section 3.3 (Larger Work). tulpaMesh did exactly this
  and is on CRAN; copy its wording. Record the CDT version (2.0.1, upstream
  commit 3765e08).
- **`CXX_STD = CXX11` in src/Makevars.** Current R warns on a C++11
  requirement and CRAN asks packages to drop it; remove the line (and
  "SystemRequirements: C++11") so the default C++17 is used.
- **Stray files in the build.** Rplots.pdf and README.html are in the repo
  and not in .Rbuildignore; R CMD check reports them. Delete Rplots.pdf and
  ignore README.html.
- **Contract v1 decided** (step 1 above), because cdtr's column names and
  depth meaning become fixed on release.
- Version 0.1.0, NEWS.md, examples that run in under 5 s, `\value` on
  every exported function (CRAN checks this by hand), single quotes around
  'CDT' and other software names in Description, a reference for the
  algorithms in Description (Chew; Ruppert 1995; the CDT repository).

Not blocking: the combined criterion, wrapper overhead, the shared header
package.

### laridae

The earlier decision to keep laridae off CRAN was made when the CGAL route
meant system headers. That has changed: RcppCGAL is current (6.2.1, with
CGAL 6.2.1 headers unpacked at install), and delaunay, cgalPolygons and
raybevel are on CRAN through it. laridae is header-only with Epick, so it
needs no gmp or mpfr. Reopening the decision is the user's call; if it is
reopened:

- **LinkingTo: RcppCGAL, BH** in DESCRIPTION, keeping `configure` as is (it
  already falls back to RcppCGAL), so CRAN machines find headers without
  CGAL_INCLUDE_DIR.
- **Build cost.** CRAN limits check time; CGAL template code is slow and
  memory-hungry to compile. Measure a clean `R CMD INSTALL` time and peak
  memory with the RcppCGAL headers; if it is long, split the translation
  units (mesher in one file, dynamic triangulation in another) so each
  compiles in less memory.
- **Warnings from CGAL headers** under CRAN's -Wall -pedantic flags, and on
  clang with the additional checks. Build with those flags locally and
  silence nothing in our own code. Warnings that come from CGAL itself go
  upstream to CGAL, as the earlier archived CGAL bindings learned.
- Peak memory on large edits (8.9 GB for the world) is not a CRAN issue,
  but worth a line in the documentation.

### trowel

- **Code first:** spatial sort or bulk load (step 5), the southern Africa
  stall, the nearest-value attribute cases. Ideally the spade
  `exclude_faces` change is in a released spade, so the vendored crates
  are a release, not a fork.
- **CRAN's Rust policy** (Using Rust in CRAN packages): vendor all crates
  into src/rust/vendor.tar.xz (the Makevars already has the unpacking
  branch; the tarball does not exist yet), build offline, at most two
  build jobs (`cargo build -j 2`), print `rustc --version` in the install
  log, declare the minimum Rust version in SystemRequirements, and list
  every vendored crate's authors and licence in inst/AUTHORS. `rextendr`
  produces most of this (`rextendr::vendor_pkgs()`); the size of the
  vendored extendr plus spade tarball must stay under CRAN's 5 MB package
  limit, which is usually fine for these two.
- Same packaging items as cdtr: Authors@R copyright holders for spade
  (Stefan Altmayer) and extendr, version, NEWS, `\value`.

## 4. The other R packages: what we could offer

Each item names the evidence and what would be offered (an issue, a PR, or
inclusion in the harness). None is a criticism of design choices made for
other purposes.

| Package (author) | Offer | Evidence |
|---|---|---|
| RCDT (Stephane Laurent) | Expose CDT's `calculateTriangleDepths()` as a triangle column; it is already in the library RCDT vendors. Parity (`eraseOuterTrianglesAndHoles`, RCDT src/delaunay.cpp line 95) cannot represent a coverage of neighbouring polygons; depth can. Offer the shared CDT header package. | survey section 4, state-of-three lesson 4 |
| delaunay (Stephane Laurent) | Same depth suggestion; CGAL's nesting level is available | survey section 4 |
| tulpaMesh (Gilles Colling) | Its combined Ruppert loop with off-centres over CDT is the feature CDT itself lacks; propose upstreaming the criterion to CDT, and the shared header package. Invite it into the harness (it takes a boundary and points, so it is a natural fit for the statistical-mesh cases) | tulpaMesh src/mesh.cpp, inst/COPYRIGHTS |
| fmesher (Finn Lindgren) | Harness inclusion; a compare of its `cutoff` and two-zone `max.edge` against cdtr's data-driven `min_edge_length` floor would inform both | survey section 5 |
| RTriangle (David Sterratt) | Merge or report duplicated vertices instead of refusing ("Duplicated vertices in P" was the cause of all four failed benchmark jobs); report what refinement could not do (it stops short of the angle bound on large coastlines without saying so) | bench findings |
| sf, geos, terra, gdalraster (GEOS interfaces) | A documentation line saying the constrained function is a polygon triangulation: no Steiner points, polygons triangulated independently, no loose segments. Users read "constrained Delaunay" as a PSLG triangulation | survey sections 4 and 10.5 |
| decido, silicate, anglr (hypertidy) | Align silicate's TRI0 columns with contract v1; anglr's cdtr backend becomes default once cdtr is on CRAN | state-of-three, anglr branch cdtr-backend |
| terrainmeshr (Tyler Morgan-Wall) | Its engine (hmm) is the same as Python's pydelatin; a constrained greedy-insertion TIN (hmm's criterion with segments kept) is a natural trowel use, and the adaptive-meshing notes propose it | survey section 6 |

How to make the offers: one issue per package, linking the survey and the
benchmark, with the measured case attached. The harness adapter for a new
backend is one function in R/backends.R returning vertices, triangles
(with depth, NA if none) and an unrefined string; offering to write it is
the lowest-friction invitation.

## 5. Python

### The landscape, briefly

| Python package (PyPI version) | Upstream | What it does | Overlap with this project |
|---|---|---|---|
| triangle (20250106) | Shewchuk's Triangle | CDT, refinement, attributes; dict input `vertices`, `segments`, `holes`, `regions` | Same table shape as the contract. PyPI metadata says LGPL-3.0, but the Triangle C code it builds carries Shewchuk's non-commercial terms, the same situation as RTriangle |
| meshpy (2026.1.1) | Triangle and TetGen | quality triangle meshing in xy (Triangle) and tetrahedral meshing in xyz (TetGen) | Triangle licence again; TetGen is AGPL (upstream docs) |
| scipy.spatial.Delaunay (1.18.1) | Qhull | point Delaunay, any number of coordinates | as R's geometry; no constraints |
| matplotlib.tri (3.11.2) | Qhull for Delaunay; accepts any triangle array | plotting, linear and cubic interpolation, uniform subdivision | Contract output plugs straight into `Triangulation(x, y, triangles)` |
| shapely 2.1 (2.1.2) | GEOS | `delaunay_triangles`, `constrained_delaunay_triangles` | Same GEOS polygon triangulation as sf (no Steiner, per polygon) |
| mapbox-earcut (2.1.0) | earcut.hpp | ear cutting | Same as decido |
| PythonCDT (GitHub artem-ogre/PythonCDT, not on PyPI) | CDT | CDT, by the CDT author | Same library as cdtr; whether it exposes 2.0's refinement and depths was not checked |
| cgal (cgal-swig-bindings, 5.6, February 2024) | CGAL 5.6 | includes a Mesh_2 module (`Delaunay_mesher_2`) | laridae's engine, two CGAL releases behind on PyPI |
| pygalmesh (0.10.7) | CGAL | mostly tetrahedral and surface meshing in xyz | GPL |
| jigsawpy (GitHub dengwirda/jigsaw-python, not on PyPI) | JIGSAW | sizing-field driven Delaunay refinement | laridae's sizing field is the same idea |
| pydelatin (0.3.0) | hmm | greedy-insertion TIN | Same as terrainmeshr |
| dmsh (0.3.8) | own | DistMesh-style | Same family as geometry::distmesh2d |
| trimesh, manifold3d, pyvista | earcut, Triangle, VTK | tooling for meshes in xyz that triangulates polygons on the side | consumers |

Facts here come from PyPI metadata and the projects' repositories on this
date; behaviour was not run. Note that the PyPI names `spade`, `pyspade`
and `cdt` belong to unrelated projects (an agent framework, a gene
expression tool, a causal-discovery toolbox), so a binding would need a
different name.

### What is missing in Python, and what this project could offer

- **No editable constrained mesh and no spade binding.** Split trowel's
  Rust into a `trowel-core` crate (mesh handle, stable ids, segment
  chains, depth BFS, attribute interpolation) with the extendr layer on
  top; a PyO3 layer on the same crate gives Python the live mesh with
  little new code, built and published as wheels with maturin. This is
  the highest-leverage Python step, because the hard part (ids, chains,
  depth) is already written and tested once.
- **No depth anywhere.** Every Python mesher above decides inside and
  outside by hole seeds, regions or parity. A depth column in PythonCDT
  (`calculateTriangleDepths()` is already in CDT) is a small PR to
  artem-ogre and the same suggestion as for RCDT.
- **The conformance corpus in Python.** The cases are CSV; the measures
  (segment chains present, empty circumcircle, bound honoured, depth by
  an independent walk, attribute error) are simple array code. A small
  Python port lets triangle, PythonCDT, cgal and shapely be measured on
  the same cases, and makes the comparison a cross-language reference
  rather than an R page.
- **Interchange.** Plain numpy arrays for the three tables match what
  triangle, matplotlib and meshio already use; for files, GeoArrow or
  Parquet tables (the benchmark already reads GeoParquet with pyarrow) let
  R and Python exchange meshes without a mesh-specific format.
- **Advice upstream:** triangle and meshpy could state the Triangle
  licence in their own metadata; cgal-swig-bindings could publish wheels
  for CGAL 6; shapely's constrained function could carry the same
  documentation line as GEOS's R interfaces.

## 6. Proposed sequence

1. Contract v1 spec and conformance corpus in trianglewins; decide depth
   multiplicity.
2. r-universe entries for cdtr, laridae, trowel, trianglewins.
3. cdtr packaging fixes and CRAN submission; `pslg_from_wk()` moved in.
4. Issues offered to RCDT, tulpaMesh, RTriangle and the GEOS interfaces;
   the spade `exclude_faces` PR; the CDT combined criterion discussion.
5. anglr on cdtr, back to CRAN.
6. laridae: decide on CRAN; if yes, RcppCGAL LinkingTo, measure build
   cost, submit.
7. trowel: spatial sort, stall and attribute fixes, then vendoring and
   CRAN; in parallel, the core crate and the PyO3 binding.

## Method

Package DESCRIPTION, Makevars, configure and vendored headers read from
the four repositories on 6 October 2026. RcppCGAL, RCDT and tulpaMesh
read from their CRAN mirrors (github.com/cran); CDT upstream from
github.com/artem-ogre/CDT (tag list and master, diffed against cdtr's
src/CDT, no differences). Python facts from the PyPI JSON API and the
repositories named. Performance figures from the trianglewins benchmark
(180 jobs, CGAZ ADM0). Nothing in this page was submitted anywhere; each
offer above is a proposal.
