# Polygons are just lines (and why that is a fact about the plane)

*Development draft, 4 November 2026.*

A polygon is a set of segments plus a fill rule. Rings, ring order, which
hole belongs to which shell, and the multipolygon grouping are all
bookkeeping on top of those segments, and the bookkeeping can be derived
from them. This page argues for that claim from what the software already
does. It then gives the reason it holds: the plane is special. The same
reason explains why the fast algorithms of planar geometry have no
equivalent for volumes in xyz.

The sections:

1. what "just lines" means, exactly;
2. the evidence: rasterizing, triangulating, sharing boundaries;
3. why it works: a dimension count and three facts about the plane;
4. where it stops working: volumes, graphs in xyz, and the sphere;
5. what follows for data models.

## What "just lines" means

Take the vertices (x, y) and the segments (index pairs) of a polygon
layer, the input contract used across this site. Drop the rings. What is
left decides the region completely:

- **Even-odd fill** needs only *unoriented* segments. A point is inside if
  a ray from it crosses an odd number of segments. Holes need no labels:
  a hole is wherever the count turns even again.
- **Nonzero (winding) fill** needs *oriented* segments. A point is inside
  if the signed crossings sum to something other than zero. That is still
  one sign per segment, not a ring structure.

What the rings add is a *decomposition*. They give one way to walk the
segments as closed paths. Where more than two segments meet at a vertex,
for example two shells touching at a point, more than one walk gives the
same region. Simple features stores one of those walks and calls it the
geometry. The region did not need the choice. That is the sense in which
simple features is a rendering format: rings are the form that a stroking
or filling library takes as input, not the information.

## The evidence

The working code on this site and around it already treats polygons this
way.

- **Rasterizing.** A scanline rasterizer needs, for each row, where the
  segments cross it and with what sign. Ring membership never comes into
  it. Exact coverage fractions go through the same segment-by-cell walk.
  A line's length in a cell and a polygon's area in a cell are the same
  geometry-intersect-cell measure, taken at dimension 1 and at dimension 2. See
  [hypertidy/controlledburn](https://github.com/hypertidy/controlledburn).
- **Triangulating.** A constrained triangulation of all the segments,
  valid or not, gives each triangle a depth: the number of constraint
  edges crossed from outside. Odd depth is the even-odd reading. The mesh
  is never asked for valid rings, only segments. See
  [Triangles read parity](../../validity/#triangles-read-parity).
- **Sharing boundaries.** A boundary is a segment with owners: the region
  on its left and the region on its right. County, state and country lines
  come from one table of edges, each drawn once. Nesting becomes a lookup,
  not a geometry operation. See
  [Drawing each boundary once](../../boundaries/).
- **Repairing.** Choosing a repair for an invalid polygon is choosing a
  fill rule for its segments: parity, winding, or union of the rings. The
  segments are the same in every reading. See
  [Fixing is choosing a reading](../../validity/#fixing-is-choosing-a-reading).

In each case the segments are the data and the rings are, at most, an
output format.

## Why it works: the plane is special

All of this rests on a dimension count. Two pieces of dimension k in a
space of dimension n, in general position, meet in a set of dimension

    2k - n

(empty when that is negative). For segments (k = 1) in the plane (n = 2)
it is 0. Segments cross in isolated points, and a small move of a vertex
cannot remove a crossing. Three facts about the plane come with that
count, and every one of them gets used above.

- **A closed curve separates the plane** (the Jordan curve theorem). It
  has an inside and an outside, so a boundary made of segments determines
  a region. That is why the fill rules work.
- **Segments meet in points.** Overlay, noding and the depth labelling in
  a triangulation only add vertices; their output is still segments. The
  representation is closed under the operations we need.
- **Edges around a vertex have a cyclic order.** Turning left at each
  vertex walks a face, so faces (rings) can be rebuilt from the edges at
  any time. This is what half-edge structures, and the ring
  reconstruction in polygonize, rely on.

Euler's formula keeps all of it small. For a planar graph with at least
three vertices, E <= 3V - 6, so the segments, the faces, and any
triangulation of them grow linearly with the number of vertices.

The same facts explain the fast planar algorithms. A sweep line meets the
segments in a total order (above and below), which gives sweeps, point
location in O(log n) and trapezoidal maps. A simple polygon can always be
triangulated using only its own vertices. Constrained Delaunay
triangulations always exist.

## Where it stops working

### Volumes in xyz

A solid in xyz is bounded by surfaces, not lines. A closed curve in xyz
separates nothing; the Jordan-Brouwer theorem has a closed *surface*
separating space. So the version of the claim one dimension up is
"solids are just triangles": a set of oriented boundary triangles plus a
fill rule. The primitive moves up a dimension with the space.

The cheap algorithms do not come with it.

- Crossings of two surfaces are curves (2k - n = 1), not points, so
  overlay adds new edges, not just new vertices.
- The neighbourhood of a vertex is a sphere, not a circle. Ordering the
  faces around a vertex is a surface-embedding problem of its own.
- A sweep plane meets the geometry in a planar arrangement, not an
  ordered list.
- Size bounds are no longer linear. By the Upper Bound Theorem, a Delaunay
  triangulation of n points in d dimensions can have on the order of
  n^ceil(d/2) cells. In xyz that is already n^2 tetrahedra in the worst
  case.
- Triangulating a polyhedron can need extra (Steiner) vertices. The
  Schoenhardt polyhedron has no tetrahedralization using only its own
  vertices, and deciding whether one exists is NP-complete. Constrained
  Delaunay tetrahedralizations exist only under extra conditions on the
  input.

The general rule is: **a region is its codimension-1 boundary plus a fill
rule.** Lines are that boundary only when the region is a piece of the
plane, or of a surface such as the sphere.

### Graphs in xyz

A related question shows the same count from the other side: when can a
graph be drawn without crossings? In the plane that is planarity, a real
constraint with forbidden graphs (K5 and K3,3). In xyz every graph has a
crossing-free drawing: put the vertices on the curve (t, t^2, t^3) and
join them with straight segments. The question that survives is about
*linking*. Two disjoint cycles of edges in xyz can be linked, and graphs
that can be drawn with no two cycles linked have their own short list of
forbidden graphs (the seven graphs of the Petersen family). The stable
version of crossing comes back one level up: 2-dimensional complexes in
4 dimensions, where the 2-skeleton of the 6-simplex has no embedding (the
van Kampen-Flores theorem). Crossing as a stable, countable event lives
at 2k = n, and segments in the plane are the case k = 1.

### The sphere

A closed curve on the sphere separates it into two regions, but neither
one is the outside. Lines still determine the region only once something
picks which side is which: the orientation of the segments (interior on
the left, as in s2) or a stated convention. Even-odd fill, which needs no
orientation, gives two answers on the sphere, and a data model has to
choose between them. See [Curves: bigcurve and s2](../../curves/) for
what an edge is on the sphere in the first place.

## What follows for data models

- **Store the vertices and segments; derive the rings.** Rings, ring
  order and shell/hole membership can be rebuilt from the segments in the
  plane, so a format that requires them stores a choice, not information.
- **Say the fill rule and the orientation.** These are the only extra
  facts a set of segments needs to determine a region, and they are where
  the readers of one dataset really differ: parity against winding, and
  on the sphere, which side.
- **Keep shared edges shared.** A segment with a left and a right owner is
  stored once, which is what coverage simplification and level of detail
  need to keep neighbours consistent.
- **Do not build the plane into the schema.** A model whose primitive is
  "the boundary of dimension n - 1" carries over to triangles bounding
  volumes. A model whose primitive is "the ring" does not. In the plane
  the two models give the same thing, so a format built only for the
  plane cannot tell which one it is using.

The claim "polygons are just lines" is therefore not a general principle.
It is the 2-dimensional case of one, and the plane happens to be the case
where everything is cheap.
