"""Pilot implementation of the geoarrow.triangles proposal.

Two layouts under one extension name:
  dictionary  FixedSizeList<Dictionary<int32, Coordinate>>[3]  (IPC, memory)
  decoded     FixedSizeList<Coordinate>[3]                    (Parquet)

Writing Parquet decodes the dictionary; reading it back rebuilds the vertex
pool by exact match on the coordinate bit patterns, numbering vertices by
first appearance. If the producer already numbers vertices by first
appearance (canonical_order()), the round trip keeps vertex ids exactly.
"""
import json
import numpy as np
import pyarrow as pa
import pyarrow.ipc as ipc
import pyarrow.parquet as pq

EXT_NAME = "geoarrow.triangles"
COORD = pa.struct([pa.field("x", pa.float64(), nullable=False),
                   pa.field("y", pa.float64(), nullable=False)])
DECODED = pa.list_(pa.field("vertices", COORD, nullable=False), 3)


def dict_storage(index_type=pa.int32()):
    return pa.list_(pa.field("vertices", pa.dictionary(index_type, COORD),
                             nullable=False), 3)


class Triangles(pa.ExtensionType):
    def __init__(self, storage, meta=None):
        self.meta = dict(meta or {})
        super().__init__(storage, EXT_NAME)

    def __arrow_ext_serialize__(self):
        return json.dumps(self.meta).encode()

    @classmethod
    def __arrow_ext_deserialize__(cls, storage, serialized):
        return cls(storage, json.loads(serialized.decode() or "{}"))

    @property
    def is_dictionary(self):
        return pa.types.is_dictionary(self.storage_type.value_type)


def register():
    try:
        pa.register_extension_type(Triangles(DECODED))
    except pa.ArrowKeyError:
        pass


def unregister():
    try:
        pa.unregister_extension_type(EXT_NAME)
    except pa.ArrowKeyError:
        pass


# ---- building -------------------------------------------------------------

def _coords(xy):
    xy = np.ascontiguousarray(xy, dtype=np.float64)
    return pa.StructArray.from_arrays([pa.array(xy[:, 0]), pa.array(xy[:, 1])],
                                      fields=list(COORD))


def signed_area2(xy, tri):
    a, b, c = xy[tri[:, 0]], xy[tri[:, 1]], xy[tri[:, 2]]
    return (b[:, 0] - a[:, 0]) * (c[:, 1] - a[:, 1]) - (c[:, 0] - a[:, 0]) * (b[:, 1] - a[:, 1])


def orient_ccw(xy, tri):
    """Swap two vertices of each clockwise triangle."""
    tri = tri.copy()
    cw = signed_area2(xy, tri) < 0
    tri[cw, 1], tri[cw, 2] = tri[cw, 2], tri[cw, 1].copy()
    return tri


def canonical_order(xy, tri):
    """Renumber vertices by first appearance in the triangles; drop unused."""
    flat = tri.ravel()
    _, first = np.unique(flat, return_index=True)
    order = flat[np.sort(first)]             # old ids in first-appearance order
    new_id = np.full(len(xy), -1, dtype=np.int64)
    new_id[order] = np.arange(len(order))
    return xy[order], new_id[tri].astype(np.int32)


def from_mesh(xy, tri, meta=None):
    """Dictionary layout from a vertex array (n, 2) and triangles (m, 3)."""
    tri = np.ascontiguousarray(tri, dtype=np.int32)
    d = pa.DictionaryArray.from_arrays(pa.array(tri.ravel()), _coords(xy))
    st = pa.FixedSizeListArray.from_arrays(d, 3).cast(dict_storage())
    return pa.ExtensionArray.from_storage(Triangles(dict_storage(), meta), st)


def to_mesh(arr):
    """Vertices (n, 2) and triangles (m, 3) from the dictionary layout."""
    st = arr.storage if isinstance(arr, pa.ExtensionArray) else arr
    d = st.flatten()  # respects slice offsets, unlike .values
    dic = d.dictionary
    xy = np.column_stack([dic.field("x").to_numpy(), dic.field("y").to_numpy()])
    return xy, d.indices.to_numpy().reshape(-1, 3)


# ---- decoding and re-pooling ---------------------------------------------

def decode(arr):
    """Dictionary layout -> decoded layout (same extension name and metadata)."""
    xy, tri = to_mesh(arr)
    flat = xy[tri.ravel()]
    st = pa.FixedSizeListArray.from_arrays(_coords(flat), 3).cast(DECODED)
    return pa.ExtensionArray.from_storage(Triangles(DECODED, arr.type.meta), st)


def repool(decoded_chunks, meta=None):
    """Decoded layout -> dictionary layout, exact match on bit patterns.

    Vertices are numbered by first appearance across all chunks in order.
    Hash-based (Arrow dictionary_encode on the 16-byte x/y bit pattern).
    """
    xs, ys = [], []
    for ch in decoded_chunks:
        st = ch.storage if isinstance(ch, pa.ExtensionArray) else ch
        v = st.flatten()  # respects slice offsets, unlike .values
        xs.append(v.field("x").to_numpy(zero_copy_only=False))
        ys.append(v.field("y").to_numpy(zero_copy_only=False))
    xy = np.column_stack([np.concatenate(xs), np.concatenate(ys)])
    key = pa.FixedSizeBinaryArray.from_buffers(
        pa.binary(16), len(xy), [None, pa.py_buffer(np.ascontiguousarray(xy).tobytes())])
    enc = key.dictionary_encode()
    ids = enc.indices.to_numpy()
    pool = np.frombuffer(enc.dictionary.buffers()[1], dtype=np.float64,
                         count=2 * len(enc.dictionary)).reshape(-1, 2)
    return from_mesh(pool, ids.reshape(-1, 3), meta)


# ---- files ------------------------------------------------------------------

def write_ipc(path, arr, batch_rows=65536, deltas=True, extra=None):
    """IPC file, one mesh. With deltas, each batch adds only the vertices it
    first uses (requires first-appearance order, see canonical_order)."""
    xy, tri = to_mesh(arr)
    sch = pa.schema([pa.field("triangles", arr.type, nullable=False)] +
                    [pa.field(k, v.type) for k, v in (extra or {}).items()])
    opts = ipc.IpcWriteOptions(emit_dictionary_deltas=deltas)
    with ipc.new_file(path, sch, options=opts) as w:
        seen = 0
        for s in range(0, len(tri), batch_rows):
            t = tri[s:s + batch_rows]
            if deltas:
                seen = max(seen, int(t.max()) + 1)
                part = from_mesh(xy[:seen], t, arr.type.meta)
            else:
                part = from_mesh(xy, t, arr.type.meta)
            cols = [part] + [v[s:s + batch_rows] for v in (extra or {}).values()]
            w.write_batch(pa.record_batch(cols, schema=sch))


def read_ipc(path):
    t = ipc.open_file(path).read_all()
    return t


def write_parquet(path, arr, row_group_size=1 << 20, extra=None, **kw):
    dec = decode(arr) if arr.type.is_dictionary else arr
    cols = {"triangles": dec, **(extra or {})}
    pq.write_table(pa.table(cols), path, row_group_size=row_group_size, **kw)


def read_parquet(path, columns=None):
    """Read and re-pool the triangles column back to the dictionary layout."""
    t = pq.read_table(path, columns=columns)
    col = t.column("triangles")
    meta = col.type.meta if isinstance(col.type, Triangles) else {}
    return repool(col.chunks, meta), t
