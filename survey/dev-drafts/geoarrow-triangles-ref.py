# Reference checks for the geoarrow.triangles proposal
# (survey/dev-drafts/geoarrow-triangles-proposal.md). Run with pyarrow:
#   python survey/dev-drafts/geoarrow-triangles-ref.py
import io, json
import pyarrow as pa, pyarrow.ipc as ipc, pyarrow.parquet as pq, pyarrow.compute as pc

COORD = pa.struct([pa.field("x", pa.float64(), nullable=False),
                   pa.field("y", pa.float64(), nullable=False)])

class Triangles(pa.ExtensionType):
    def __init__(self, storage, meta=None):
        self._meta = meta or {}
        super().__init__(storage, "geoarrow.triangles")
    def __arrow_ext_serialize__(self):
        return json.dumps(self._meta).encode()
    @classmethod
    def __arrow_ext_deserialize__(cls, storage, serialized):
        return cls(storage, json.loads(serialized.decode() or "{}"))

pa.register_extension_type(Triangles(pa.list_(pa.field("vertices", COORD), 3)))

def dict_storage(index_type=pa.int32()):
    return pa.list_(pa.field("vertices", pa.dictionary(index_type, COORD), nullable=False), 3)

META = {"vertex_identity": "exact_float"}

def mesh(idx, verts):
    d = pa.DictionaryArray.from_arrays(pa.array(idx, pa.int32()), pa.array(verts, COORD))
    st = pa.FixedSizeListArray.from_arrays(d, 3)
    st = st.cast(dict_storage())  # name the child "vertices"
    return pa.ExtensionArray.from_storage(Triangles(dict_storage(), META), st)

def kinds(buf):
    m = ipc.MessageReader.open_stream(pa.BufferReader(buf)); out = []
    while True:
        try: out.append(m.read_next_message().type)
        except StopIteration: return out

def signed_area2(a, b, c):
    return (b["x"] - a["x"]) * (c["y"] - a["y"]) - (c["x"] - a["x"]) * (b["y"] - a["y"])

V4 = [{"x": 0., "y": 0.}, {"x": 1., "y": 0.}, {"x": 0., "y": 1.}, {"x": 1., "y": 1.}]
V5 = V4 + [{"x": 2., "y": 0.}]
t1 = mesh([0, 1, 2], V4); t2 = mesh([1, 3, 2], V4)
print("1. type:", t1.type, "| storage:", t1.type.storage_type)

# 2. IPC stream, two batches, one dictionary
sch = pa.schema([pa.field("triangles", t1.type, nullable=False)])
b = io.BytesIO()
with ipc.new_stream(b, sch) as w:
    w.write_batch(pa.record_batch([t1], schema=sch)); w.write_batch(pa.record_batch([t2], schema=sch))
back = list(ipc.open_stream(b.getvalue()))
print("2. stream messages:", kinds(b.getvalue()), "| read back as:", type(back[0].column(0).type).__name__)

# 3. Delta dictionary: batch 2 adds a vertex (streaming a growing mesh)
t3 = mesh([1, 4, 3], V5)
opts = ipc.IpcWriteOptions(emit_dictionary_deltas=True)
b = io.BytesIO()
with ipc.new_stream(b, sch, options=opts) as w:
    w.write_batch(pa.record_batch([t1], schema=sch)); w.write_batch(pa.record_batch([t3], schema=sch))
print("3. delta stream messages:", kinds(b.getvalue()))
r = list(ipc.open_stream(b.getvalue()))
print("   batch 2 dictionary length:", len(r[1].column(0).storage.values.dictionary))
fb = io.BytesIO()
try:
    with ipc.new_file(fb, sch, options=opts) as w:
        w.write_batch(pa.record_batch([t1], schema=sch)); w.write_batch(pa.record_batch([t3], schema=sch))
    ft = ipc.open_file(fb.getvalue())
    print("   delta in IPC file: ok,", ft.num_record_batches, "batches")
except Exception as e:
    print("   delta in IPC file:", type(e).__name__, e)

# 4. A reader that does not know the type still sees storage plus metadata
pa.unregister_extension_type("geoarrow.triangles")
f = ipc.open_stream(b.getvalue()).schema.field("triangles")
print("4. unregistered reader:", f.type, "|", dict(f.metadata))
pa.register_extension_type(Triangles(pa.list_(pa.field("vertices", COORD), 3)))

# 5. Parquet: dictionary storage refused; decoded storage written and re-pooled
tab = pa.table({"triangles": pa.chunked_array([t1, t2])})
try:
    pq.write_table(tab, io.BytesIO()); print("5. parquet dictionary storage: ok")
except Exception as e:
    print("5. parquet dictionary storage:", type(e).__name__, e)

def decode(arr):
    st = arr.storage
    soup = pa.FixedSizeListArray.from_arrays(st.values.dictionary_decode(), 3)
    soup = soup.cast(pa.list_(pa.field("vertices", COORD), 3))
    return pa.ExtensionArray.from_storage(Triangles(soup.type, arr.type._meta), soup)

def repool(arr):
    flat = arr.storage.values.flatten()
    xs, ys = flat[0].to_pylist(), flat[1].to_pylist()
    ids, verts, seen = [], [], {}
    for k in zip(xs, ys):
        if k not in seen:
            seen[k] = len(verts); verts.append({"x": k[0], "y": k[1]})
        ids.append(seen[k])
    return ids, verts

soup = pa.concat_arrays([decode(t1).storage, decode(t2).storage])
soup = pa.ExtensionArray.from_storage(Triangles(soup.type, META), soup)
pb = io.BytesIO(); pq.write_table(pa.table({"triangles": soup}), pb); pb.seek(0)
got = pq.read_table(pb).column("triangles").combine_chunks()
print("   parquet decoded storage read as:", got.type, "| metadata kept:", got.type._meta)
ids, verts = repool(got)
print("   re-pooled:", len(verts), "vertices (4 written), ids", ids,
      "| same triangles:", [verts[i] for i in ids] == [V4[i] for i in [0, 1, 2, 1, 3, 2]])

# 6. Each row as a geoarrow.polygon (close the ring)
def to_polygon(arr):
    rows = []
    for tri in arr.storage.to_pylist():
        rows.append([tri + [tri[0]]])
    return pa.array(rows, pa.list_(pa.field("rings", pa.list_(pa.field("vertices", COORD)))))
print("6. as polygon:", to_polygon(t1).to_pylist()[0][0])

# 7. Winding: counter-clockwise has positive signed area
for name, t in (("t1", t1), ("t2", t2), ("t3", t3)):
    a, bb, c = t.storage.to_pylist()[0]
    print("7.", name, "CCW:", signed_area2(a, bb, c) > 0)
