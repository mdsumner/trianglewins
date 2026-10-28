# Point clouds and the vertex pool: notes for the GeoArrow discussion

*Development draft, 28 October 2026. Not submitted anywhere. A companion to
[Proposal: geoarrow.triangles](../geoarrow-triangles-proposal/) and its
background page [Triangles in GeoArrow](../geoarrow-triangles/). It asks
nothing new of that proposal. It asks whether the vertex pool (the dictionary
of coordinates that a mesh indexes into) has anything to offer point clouds,
and, since a point cloud likely needs a much more compact form than a plain
coordinate array, what the prior art is for compressed tiles of points
indexed by a small table.*

*Facts here are marked by how they were established. "Checked" means run here
(pyarrow 24) or read from the specification or documentation linked. The rest
is from working knowledge of the formats and should be confirmed before it is
quoted.*

## 1. The question

The triangles proposal stores a mesh as

```
FixedSizeList<Dictionary<int32, Coordinate>>[3]
```

so the dictionary is the vertex pool, and triangles are rows of three ids into
it. A point cloud is a vertex pool with nothing pointing into it. Does that
mean the pool type is the natural home for point clouds? Or is a cloud
different enough, in size, attributes, access pattern and compression, that it
needs its own representation, perhaps a chunked, compressed blob with an Arrow
vector as the index?

Short answer: the pool by itself adds nothing for a bare cloud. It does matter
when something else (a TIN, a mesh, a set of breaklines) refers to the cloud's
points. The compact representation is a separate problem, with a lot of prior
art. Almost all of it has the same shape: compressed tiles, plus a small table
saying where each tile is, what it covers and how many points it holds. That
is "very Zarr", and Zarr is one of the best places to look.

## 2. What the pool does and does not give a cloud

**A bare cloud does not need the dictionary.** With no triangles, a
`Dictionary<int32, Coordinate>` is a coordinate array with an identity index
on top. The indirection costs four bytes a point and buys nothing. A bare
cloud is just its dictionary values: `geoarrow.point` (separated or
interleaved) with sibling attribute columns, which is what PDAL writes today
(section 4).

**A cloud with something referring to it does fit the pool.** The common case
is a TIN or constrained triangulation over lidar ground returns: the
triangles index a subset of the cloud's points. The proposal already allows
it ("the dictionary may contain vertices that no triangle references"). Other
cases: breaklines or hydro-flattening edges snapped to cloud points;
neighbourhood graphs (k nearest neighbours, segment adjacency in
classification); a mesh reconstructed from a terrestrial scan, where the
cloud is far denser than the mesh.

Here the current proposal runs into four things:

1. **The Parquet default throws the cloud away.** The decoded layout drops
   unreferenced vertices. For a ground TIN over a full cloud, that is most of
   the points: vegetation, buildings, noise, everything not in the TIN. For
   point clouds, the proposal's option (c) (vertices stored apart from
   triangle indices) is the only one that keeps the data, not just the one
   that is 30% smaller. This is the strongest argument for (c) found so far.
2. **Arrow dictionaries are decoded in memory.** Arrow has no lazy or
   compressed child arrays. The only compression in the Arrow format is
   per-buffer LZ4 or ZSTD in IPC, which is a transport feature: the reader
   decompresses on receipt. So the pool cannot itself be the compact form.
3. **`int32` ids stop at about 2.1 billion.** That is fine for a tile and not
   for a survey: national lidar programmes run to hundreds of billions of
   points. The proposal allows `int64`, which works in memory, but a survey
   is never one in-memory array. That points to ids of the form (tile,
   local index), which is chunking again (section 8).
4. **The vertex identity rules (`vertex_identity`) do not apply.** In a mesh,
   two equal coordinates are presumed to be one vertex and the pool should
   not hold duplicates. In a cloud, two returns at the same quantized
   position are two measurements (different times, intensities, return
   numbers). A cloud used as a pool must allow duplicate coordinates.
   "The dictionary should not contain two entries with equal coordinates"
   would have to be a "should" for meshes and not apply to clouds.

**IPC dictionary deltas already stream tiles.** In the proposal, later record
batches may add vertices by dictionary delta, and ids stay valid across the
stream. Read as a cloud, each delta is a tile of points appended to the pool,
and a vertex's id is its tile's offset plus its local index. So the pool
already has the shape of a tiled cloud. What it lacks is compression at rest,
lazy access, and a spatial index over the deltas.

## 3. How a cloud differs from a mesh's vertex pool

| | mesh vertex pool | point cloud |
|---|---|---|
| size | thousands to millions | millions per tile, billions per survey |
| identity | equal coordinates are one vertex | duplicates are legitimate |
| coordinates | float64, often constructed (crossings, Steiner points) | measured, quantized: LAS stores `int32` with a per-file scale and offset |
| attributes | few (origin, z, input row) | many: intensity, return number, number of returns, classification, flags, scan angle, GPS time, RGB, NIR, waveform pointers, plus extra bytes |
| order | first appearance, or input order | scan or acquisition order, often re-sorted spatially for access |
| access | by id, from the triangles | by space (bbox, tile) and by level of detail |
| multi-resolution | rarely | usually (octrees for rendering and fast overviews) |
| compression | generic is fine | specialised codecs (LAZ) beat generic ones by a large margin |

Two of these change the design: access is **by space, not by id**, and the
coordinates are **quantized integers**, not doubles. A design that serves
point clouds well puts a spatial index next to the tiles, and either keeps the
integers or says how the doubles were made.

## 4. Prior art

Every design below has compressed or packed tiles of points, and a small
index of where each tile is, what it covers and how many points it holds.

### Files

| design | tile | index | notes |
|---|---|---|---|
| **LAZ** (LASzip) | chunks of points, 50,000 by default, each compressed independently | chunk table at the end of the file: byte offsets, and point counts for variable-size chunks | point-to-point predictive coding: each field is predicted from the previous point and the residual entropy-coded. Typically 7 to 20% of LAS size |
| **COPC** ([copc.io](https://copc.io/)) | one LAZ chunk per octree node | hierarchy pages of 32-byte entries: `VoxelKey{level, x, y, z}`, `offset`, `byteSize`, `pointCount`. `pointCount = -1` means the entry points to a child hierarchy page, so the hierarchy is fetched lazily (checked) | a valid LAZ 1.4 file that is also range-readable over HTTP. The hierarchy is a table already |
| **EPT** (Entwine Point Tiles) | one file per octree node, encoded as LAZ, raw binary or zstandard binary | JSON hierarchy files, keyed `level-x-y-z`, values are point counts | COPC took its keys from EPT. Many objects instead of one file |
| **Potree 2** | octree nodes as byte ranges in one `octree.bin` | `hierarchy.bin`: per node, type, child mask, point count, byte offset, byte size | built for the browser renderer |
| **I3S point cloud layers** (OGC) | nodes, geometry and attributes in separate resources, LEPCC-compressed | node pages | LEPCC is Esri's limited-error point cloud compression: lossy within a stated error |
| **3D Tiles / glTF** | `pnts` tiles (3D Tiles 1.0), or glTF point primitives (1.1) | the tileset JSON tree with bounding volumes | glTF buffers can use Draco (`KHR_draco_mesh_compression`), meshopt (`EXT_meshopt_compression`) and integer quantization (`KHR_mesh_quantization`) |
| **E57** | scans as compressed vectors | XML section describing scans and poses | terrestrial scanner interchange; not tiled spatially |

### Databases and array stores

| design | tile | index | notes |
|---|---|---|---|
| **pgpointcloud** | `PcPatch`: one row per patch, compressed as none, dimensional (run-length, common-bits removal, zlib, chosen per dimension) or LAZ (checked) | patch bounds plus a GiST index on the patch envelope; the schema is stored once in `pointcloud_formats` and each patch carries only its `pcid` (checked) | **the closest prior art to "a compressed blob per row, indexed by a table".** The schema-once, key-per-row pattern is exactly an Arrow schema plus a dictionary |
| **Oracle `SDO_PC`** | blocks of points in a block table | spatial index on block extents | same pattern, earlier |
| **TileDB** | sparse array tiles, compressed per attribute | built-in spatial index on tile MBRs | PDAL can write and read it directly |
| **Zarr v3 sharding** ([spec](https://zarr-specs.readthedocs.io/en/latest/v3/codecs/sharding-indexed/index.html)) | inner chunks packed into a shard object | the shard index: per inner chunk, `offset` and `nbytes` as uint64, at the start or end of the shard; an empty chunk is both set to 2^64 - 1 (checked) | the COPC hierarchy without the octree: a byte-range table over compressed tiles |
| **zarr-vectors** ([point cloud type](https://zarr-vectors-py.readthedocs.io/en/latest/spec/geometry_types/point_cloud.html)) | `vertices/` (N, D) float32 per spatial chunk; `attributes/<name>/` per vertex; a `vertex_fragments/` uint8 blob per chunk indexing bins inside the chunk (checked) | spatial chunks (e.g. 200 units) with bins inside them (e.g. 50 units), and a multi-resolution pyramid that replaces each bin's points with one point at the centroid (checked) | from the Allen Institute ecosystem. A worked Zarr answer to "tiles of points" |
| **CF ragged arrays** (discrete sampling geometries) | a contiguous ragged array: all elements in one 1-D array, with a `count` variable giving each instance's length | the count variable: its cumulative sum gives offsets | the netCDF answer to variable-length groups, decades old and widely read. Also an indexed variant, where each element carries its instance number |
| **Kerchunk / VirtualiZarr** | any byte range in any file | a manifest of (path, offset, length) per chunk | a way to give existing files a Zarr view without copying them |

### Arrow and Parquet today

- **PDAL [`writers.arrow`](https://pdal.io/en/latest/stages/writers.arrow.html)**
  writes Feather or Parquet with one column per dimension, in batches of
  262,144 points by default. For Feather it can write a GeoArrow struct of the
  coordinates (named by `geoarrow_dimension_name`, default `xyz`). For Parquet
  with GeoParquet metadata, current documentation says it always writes WKB
  points instead (checked). There is a matching `readers.arrow`. Batches carry
  no spatial meaning.
- **copc-core** (Rust) decodes COPC's LAZ chunks into owned column buffers and
  [leaves Arrow conversion out on purpose](https://docs.rs/crate/copc-core/latest)
  (checked).
- No GeoArrow or GeoParquet discussion of point clouds was found in a short
  search. It looks like open ground, not something already settled.

### Codecs for coordinates in general

- **Parquet `BYTE_STREAM_SPLIT`** splits each value's bytes into separate
  streams before compression, which helps floats and, more recently, integers.
  pyarrow 24 writes it for `int32` and `float64` columns (checked).
- **Float codecs**: ALP (adaptive lossless floating point) and FastLanes
  integer encodings, used by newer columnar formats (Vortex; Lance has similar
  aims), give random access to compressed values. DuckDB uses ALP internally.
- **Quantize, then delta-code**: what LAZ, Draco and meshopt all do in some
  form. Spatially sorted, quantized coordinates have small deltas, and small
  deltas compress well under any entropy coder.

## 5. The common shape

All of this prior art reduces to five parts:

1. **A schema, stated once.** LAS point formats and extra bytes, the
   pgpointcloud `pcid`, a Zarr array's metadata, an Arrow schema.
2. **Tiles.** A set of points, encoded and compressed as one unit.
3. **An index of tiles.** Per tile: a key, its bounds, its point count, and
   where its bytes are (or the bytes themselves).
4. **A codec name.** How to decode a tile: LAZ, Draco, dimensional, zstd,
   none.
5. **Optionally, a hierarchy.** Octree keys and coarse levels for rendering
   and overviews (COPC, EPT, Potree, I3S, 3D Tiles, zarr-vectors pyramids).

Part 3 is always a small, regular table, and Arrow is very good at small
regular tables. Written as Arrow:

```
tile_index: struct<
  key:       struct<level: int8, x: int32, y: int32, z: int32>  -- or a plain tile id
  bbox:      struct<xmin, ymin, zmin, xmax, ymax, zmax: double>
  count:     int64
  offset:    int64        -- cumulative count: global id of the tile's first point
  codec:     dictionary<int8, utf8>
  location:  one of
               binary                                   -- the tile bytes inline
               struct<path: utf8, byte_offset: int64, byte_length: int64>  -- a reference
>
```

That is the COPC hierarchy, the pgpointcloud patch table, a Zarr shard index
and a Kerchunk manifest, written as one Arrow table. The question for GeoArrow
is not whether this table can be written (it obviously can) but whether
anything in it deserves a name, and if so which part.

## 6. The Zarr reading

Compressed tiles of points are the easiest thing to put in object storage and
keep track of, and that is exactly what Zarr does for arrays. Read as Zarr:

- **Each dimension is a 1-D array** of length N (`x`, `y`, `z`, `intensity`,
  `classification`, ...), as zarr-vectors and the
  [UGRID-in-Zarr pilot](https://github.com/mdsumner/trianglewins/tree/main/survey/dev-drafts/ugrid-zarr)
  do for mesh nodes.
- **Sort the points by tile**, so each tile is a contiguous run.
- **Zarr chunks are the tiles.** Each chunk is compressed with its own codec
  pipeline. Quantized `int32` coordinates with a delta filter and zstd are
  plain Zarr today. A LAZ-like predictive codec would be a new Zarr codec.
- **The index comes free.** A Zarr chunk's key is its position in the chunk
  grid, and the store (or a shard index) knows where its bytes are. Only
  bounds and counts need to be added: a small `tile_bbox` array and a CF-style
  `tile_count` array, whose cumulative sum is the offset array.

The difficulty is that **tiles hold different numbers of points, and Zarr
chunks are regular in index space.** Three ways around that:

1. **Rectilinear chunk grids** (ZEP 0003, variable chunk sizes). zarr-python
   implements them behind an experimental flag (`array.rectilinear_chunks`),
   zarrs (Rust) supports the draft ZEP, and the extension's status in the
   spec is still being worked out (checked against the
   [zarr-python release notes](https://zarr.readthedocs.io/en/stable/release-notes/)).
   With them, chunk *i* is exactly tile *i*, and the chunk sizes are the count
   array.
2. **Regular chunks plus a ragged index.** Keep chunks of a fixed point count
   (like LAZ's 50,000), sort points spatially, and keep a CF contiguous ragged
   count per tile. A tile then spans one or more chunks, read by byte range.
   This is how LAZ works.
3. **Sharding with ragged inner chunks**, i.e. a padded grid where each inner
   chunk is a tile and empty space is the fill value. This wastes the index on
   empty chunks, but the shard index already marks empty chunks as
   2^64 - 1.

**Virtual Zarr over COPC.** A COPC file's hierarchy is already a list of
(offset, byte size, point count) per node. A VirtualiZarr-style manifest could
point Zarr chunks at COPC's LAZ chunks without copying anything, given a LAZ
chunk codec (LAZ chunks depend on the file's point format and LASzip settings,
which would have to go in the codec configuration). The cloud stays a COPC
file, readable by every lidar tool, and gains a Zarr and Arrow-friendly index.
Icechunk could then version it. Nobody seems to have done this yet; it is a
small, concrete experiment.

**Where Zarr and Arrow meet.** In Zarr the chunk is the compressed unit and
the index is the store. In Arrow the record batch is the decoded unit, and
there is no index across batches. The tile-index table above can sit in
either. A mesh over the cloud is then exactly the UGRID-in-Zarr pilot, with
`mesh_node` chunked by tile and `mesh_face_nodes` holding global ids.

## 7. Arrow-side options

From least to most new.

### A. Plain columns, record batch = tile

One Arrow table, a `geoarrow.point` column plus attribute columns, with each
record batch holding one spatial tile. Tile bounds and keys go in per-batch
custom metadata: Arrow IPC messages carry it, and pyarrow writes and reads it
(`write_batch(batch, custom_metadata=...)`, `read_next_batch_with_custom_metadata()`;
checked). IPC body compression (LZ4 or ZSTD per buffer) gives some
compression at rest.

- For: nothing new; any Arrow reader reads it; a mesh pool is the same thing
  with dictionary deltas.
- Against: per-batch metadata is an IPC detail that most tools drop; Parquet
  has no per-row-group custom metadata (only statistics); generic compression
  of floats is weak; an IPC file has to be read in order to find a tile,
  unless a footer or side index is added.

### B. One row per tile, decoded

```
struct<
  key:    ...,
  bbox:   ...,
  points: list<geoarrow.point>,     -- or a struct of lists, one per dimension
  intensity: list<uint16>, ...
>
```

The decoded form of a pgpointcloud patch, and the point-cloud twin of the
per-feature mesh (form B in the background page).

- For: the table is the index; spatial filters work row by row; a GeoParquet
  bbox covering column filters tiles.
- Against: rows are huge (a million points per row), which many tools handle
  badly; the same weak compression as A.

### C. One row per tile, opaque bytes

```
key, bbox, count, offset, codec: dictionary<int8, utf8>, payload: binary
```

with the extension name on `payload`, say `geoarrow.pointpatch` (a
placeholder), and the codec and schema in the extension metadata or the codec
column. `geoarrow.wkb` is the precedent: GeoArrow already names an opaque
binary encoding.

Payload codecs, each a real choice:

| codec | for | against |
|---|---|---|
| a LAZ chunk | best compression for lidar; COPC chunks copy in without re-encoding | needs the LAS point format and LASzip settings as shared metadata; LAS attribute model only |
| Draco or meshopt | what glTF and renderers already read; quantization built in | lossy by default; aimed at rendering, not archives |
| LEPCC | bounded-error compression; I3S compatibility | Esri specification; lossy |
| a nested Arrow IPC stream | self-describing; any attributes; decodes to option A; IPC compression inside | tile schema repeated per row unless stripped; generic compression only |
| a Zarr codec pipeline (e.g. delta then zstd on quantized ints) | reuses Zarr codec definitions and names | an Arrow column depending on Zarr codec metadata is new |
| a Parquet file per tile | best generic compression and encodings | heavy per-tile overhead (footer, schema) |

- For: compact; tiles are independent; the index is ordinary Arrow and
  queryable by any engine; the bytes can move between COPC, glTF and Arrow
  without re-encoding.
- Against: opaque to every engine that does not know the codec (as WKB is to
  engines without geometry support); "the cloud" is no longer columns; a
  codec registry becomes part of the spec.

### D. Index in Arrow, payload elsewhere

As C, but `payload` is replaced by `struct<path, byte_offset, byte_length>`
referring to COPC files, LAZ chunks, Zarr chunks or EPT nodes. The Arrow table
is a manifest, as in Kerchunk and VirtualiZarr.

- For: no copy; existing archives stay authoritative; the manifest is small
  enough to put in a catalogue, a STAC item or a GeoParquet file.
- Against: GeoArrow has never had external references; a reader needs storage
  access and the payload's decoder; consistency between the manifest and the
  files is someone else's problem (Icechunk does solve this for Zarr).

### E. Quantized coordinates

Independent of tiling: a coordinate stored as `int32` with a scale and offset,
like LAS and `KHR_mesh_quantization`. As GeoArrow this could be a storage type
for `Coordinate` (separated `int32` children) with `scale` and `offset` keys
in the extension metadata, decoded as `value * scale + offset`.

- For: halves the size of float64 before any compression; integers compress
  far better under delta and byte-stream-split encodings; the original LAS
  values are kept exactly instead of being rounded through doubles. **It helps
  the triangles proposal too:** glTF and other renderers want quantized
  vertex buffers, and the triangle dictionary could hold quantized
  coordinates.
- Against: a change to coordinates, the most widely implemented part of
  GeoArrow; every kernel has to apply scale and offset or decode first; the
  rounding rule (round, not floor) has to be fixed; the scale is per array,
  which is awkward when merging arrays with different scales. Precision
  traps are well known from LAS: a value only fits if
  `(value - offset) / scale` is an integer.

Possibly lighter: leave coordinates as doubles but record in metadata that
they came from a quantized grid (`scale`, `offset`), so a writer can
re-quantize exactly. That is information, not a new layout.

### F. Parquet as the compressed tile store

Use Parquet as it is: points sorted by a space-filling curve (Morton or
Hilbert) at tile level, one row group (or a run of pages) per tile, quantized
`int32` coordinates with `BYTE_STREAM_SPLIT` or delta encoding and zstd,
column statistics, the page index, and a GeoParquet bbox covering column, so
that readers prune by bounds. Parquet's newer native geometry types carry
bounding-box statistics as well.

- For: no new type; every engine already reads it (DuckDB, Polars, Spark,
  SedonaDB); row groups and pages are the compressed chunks and the footer is
  the index; works today.
- Against: predictive codecs like LAZ will very likely still be smaller,
  though this has not been measured here (section 10); row groups are not
  addressable as tiles by key, only by statistics; no multi-resolution.

### Summary

| option | new in GeoArrow | compact | spatial index | engines read it today |
|---|---|---|---|---|
| A. batch = tile | nothing | weak | per-batch metadata (IPC only) | yes |
| B. row = decoded tile | a convention | weak | the table | yes, with big rows |
| C. row = opaque tile | an extension type plus codec list | strong | the table | the index only |
| D. manifest | external references | as the source | the table | the index only |
| E. quantized coordinates | coordinate storage | better, for A, B and F | none | no |
| F. Parquet as tile store | nothing (a recipe) | moderate | row group statistics, bbox covering | yes |

These combine. A plausible stack: **F for analysis, C or D for archives and
streaming, E underneath both.** Option A is what happens in memory once a tile
is decoded.

## 8. Ids across tiles: how a mesh refers to a tiled cloud

If the triangles proposal is to index a tiled cloud, a vertex id must survive
tiling. Choices:

1. **Global id = tile offset + local index.** The `offset` column in the tile
   index is a cumulative count, exactly like Arrow `List` offsets: the cloud
   is a `List<Coordinate>` with list *i* being tile *i*, and flattening it
   gives global ids. Finding a vertex's tile is a binary search on the
   offsets. Ids change if tiles are re-cut or points added mid-stream, so
   they are valid only for one version of the tiling. This is what the
   proposal's IPC deltas already do.
2. **A composite id**, `struct<tile: int32, index: int32>`, as COPC addresses
   points by node key and position in the node. It survives appending tiles
   but not re-tiling. Triangles become `FixedSizeList<struct<tile, index>>[3]`,
   which is no longer a dictionary type.
3. **A mesh per tile**, with the tile's points as its dictionary. Simple and
   local, but the seams are the "batch seams" trap from the background page:
   triangles crossing a tile boundary need both tiles' points, or ids that
   agree across the seam.
4. **A persistent point id column** (GPS time plus return number is close to
   unique in lidar, or an explicit `uint64`). Survives anything, costs a
   column and a join.

Choice 1 needs nothing new, and is the natural default. It should state that
ids are tied to one version of the tiling, as the proposal already says that a
dictionary replacement starts a new mesh.

## 9. What this suggests for the triangles proposal

No change is requested. Things to bear in mind:

- **Parquet option (c) gains weight.** Two tables (or a vertex table plus
  index triangles) is the only Parquet layout that keeps a cloud a mesh was
  built on.
- **Duplicate coordinates.** The rule against duplicate dictionary entries
  should stay a "should", and say that it is about meshes.
- **`int64` indexes are real**, not hypothetical, once clouds are involved.
- **Vertex attributes in a vertex table keyed by id** already fits clouds:
  the vertex table *is* the cloud, with its intensity, classification and
  time.
- **Quantized coordinates (option E)** would serve renderers of triangles as
  much as clouds.

## 10. Not measured yet

This page has no size or speed comparisons. The obvious experiment, on a
public lidar tile (the PDAL test data, or a USGS 3DEP tile), would compare:

- LAZ and COPC as the baseline;
- Parquet with float64 coordinates, zstd;
- Parquet with quantized `int32` coordinates, `BYTE_STREAM_SPLIT` or delta,
  zstd, sorted spatially and not;
- Arrow IPC with ZSTD body compression;
- Zarr v3 with quantized `int32`, a delta filter and zstd, chunked by tile;
- one tile as a nested IPC blob (option C) against the same tile as a LAZ chunk;

for size, time to decode one tile, and time to answer a bbox query from cold
object storage. The machinery for the Arrow and Zarr cases is in the
[pilot](https://github.com/mdsumner/trianglewins/tree/main/survey/dev-drafts/pilot)
and the
[UGRID-in-Zarr pilot](https://github.com/mdsumner/trianglewins/tree/main/survey/dev-drafts/ugrid-zarr).
LAZ needs laspy and lazrs, or PDAL.

## To do

Follow-ups, roughly in order of cost:

- [ ] **Measure** (section 10): LAZ and COPC against Parquet (float64; quantized
  `int32` with `BYTE_STREAM_SPLIT` or delta; sorted spatially and not), Arrow
  IPC with ZSTD, and Zarr v3 chunked by tile. Size, time to decode one tile,
  and a cold bbox query.
- [ ] **Option A pilot**: write a tiled cloud as Arrow IPC with one tile per
  record batch and the tile key and bbox in per-batch custom metadata; check
  which readers (pyarrow, nanoarrow, arrow-rs, DuckDB) keep that metadata.
- [ ] **Option F recipe**: Parquet with one row group per tile, a bbox covering
  column, quantized coordinates; check pruning in DuckDB and SedonaDB.
- [ ] **Option C pilot**: the same tiles as one row each, payload a nested
  Arrow IPC stream and, for comparison, the tile's COPC LAZ chunk copied as is.
- [ ] **Option D / virtual Zarr over COPC**: a manifest from a COPC hierarchy
  (offset, byte size, point count per node) as an Arrow table, and as a
  VirtualiZarr manifest. What would a LAZ chunk codec for Zarr need in its
  configuration?
- [ ] **Zarr layouts** (section 6): rectilinear chunks against fixed-size
  chunks plus a ragged count, using the UGRID-in-Zarr pilot code; compare
  with zarr-vectors on the same tile.
- [ ] **Option E**: quantized coordinates through the triangles pilot (an
  `int32` dictionary with scale and offset); round trip exactly against the
  LAS values.
- [ ] **Ids across tiles** (section 8): a ground TIN over a two-tile cloud with
  global ids (offset plus local), written with IPC dictionary deltas; check
  seam triangles.
- [ ] Confirm the facts marked "from working knowledge" before quoting them.
- [ ] Decide whether any of this goes to the GeoArrow discussion, and in what
  form (questions only, or a tile index recommendation).

## 11. Questions for the GeoArrow side

1. Is a point cloud in scope for GeoArrow at all, beyond "a `geoarrow.point`
   column with attributes"? Or is it a GeoParquet (file-level) concern, or
   not a GeoArrow concern?
2. Would a tile index convention (section 5) be welcome as a recommendation,
   without an extension type?
3. Is an opaque binary extension type for tiles of points (option C), with a
   codec key, acceptable in the way `geoarrow.wkb` is? If so, which codecs
   would anyone implement: LAZ, Draco, nested IPC?
4. Would quantized coordinate storage (option E) be considered, or the lighter
   form of recording the grid in metadata?
5. Are external byte-range references (option D) ever in scope, or should
   that stay with Kerchunk, VirtualiZarr and STAC?
6. For the triangles proposal: should vertex ids be defined as global across a
   tiled pool (offset plus local index), so that a mesh can refer to a tiled
   cloud?

## Sources

- [COPC specification](https://copc.io/)
- [Zarr v3 sharding codec](https://zarr-specs.readthedocs.io/en/latest/v3/codecs/sharding-indexed/index.html)
- [zarr-python release notes (rectilinear chunks)](https://zarr.readthedocs.io/en/stable/release-notes/)
- [zarr-vectors: point cloud type](https://zarr-vectors-py.readthedocs.io/en/latest/spec/geometry_types/point_cloud.html)
- [PDAL writers.arrow](https://pdal.io/en/latest/stages/writers.arrow.html)
- [PDAL writers.pgpointcloud](https://pdal.io/stages/writers.pgpointcloud.html)
- [pgpointcloud (via Pigsty extension docs)](https://doc.pigsty.io/ext/e/pointcloud)
- [copc-core crate](https://docs.rs/crate/copc-core/latest)
- From working knowledge, to confirm before quoting: LAZ chunking and
  compression ratios, EPT, Potree 2, I3S and LEPCC, 3D Tiles and the glTF
  compression extensions, E57, Oracle `SDO_PC`, TileDB, CF ragged arrays,
  Kerchunk and VirtualiZarr, ALP, FastLanes, Vortex and Lance.
