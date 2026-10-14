# Checks behind "Triangles in GeoArrow" section 1 (form D). Run with pyarrow:
#   python survey/dev-drafts/geoarrow-dict-check.py
import pyarrow as pa, pyarrow.ipc as ipc, pyarrow.parquet as pq, io
pt = pa.struct([("x", pa.float64()), ("y", pa.float64())])
verts = pa.array([{"x":0.,"y":0.},{"x":1.,"y":0.},{"x":0.,"y":1.},{"x":1.,"y":1.}], type=pt)
def tri(idx):
    d = pa.DictionaryArray.from_arrays(pa.array(idx, pa.int32()), verts)
    return pa.FixedSizeListArray.from_arrays(d, 3)
t1 = tri([0,1,2]); t2 = tri([1,3,2])
print("type:", t1.type)
sch = pa.schema([("tri", t1.type)])
# IPC stream, two batches sharing one dictionary
buf = io.BytesIO()
with ipc.new_stream(buf, sch) as w:
    w.write_batch(pa.record_batch([t1], schema=sch)); w.write_batch(pa.record_batch([t2], schema=sch))
r = ipc.open_stream(buf.getvalue()); bs = list(r)
print("stream batches:", len(bs), "dict same object:", bs[0].column(0).values.dictionary.equals(bs[1].column(0).values.dictionary))
# count dictionary messages in stream
msgs = ipc.MessageReader.open_stream(pa.BufferReader(buf.getvalue()))
kinds = []
while True:
    try: kinds.append(msgs.read_next_message().type)
    except StopIteration: break
print("stream messages:", kinds)
# IPC file
fb = io.BytesIO()
with ipc.new_file(fb, sch) as w:
    w.write_batch(pa.record_batch([t1], schema=sch)); w.write_batch(pa.record_batch([t2], schema=sch))
ft = ipc.open_file(fb.getvalue()).read_all()
print("ipc file read:", ft.schema.field("tri").type)
# Parquet
tab = pa.Table.from_batches([pa.record_batch([t1], schema=sch), pa.record_batch([t2], schema=sch)])
pb = io.BytesIO()
try:
    pq.write_table(tab, pb); pb.seek(0); back = pq.read_table(pb)
    print("parquet read type:", back.schema.field("tri").type)
except Exception as e:
    print("parquet write error:", type(e).__name__, e)
# second column (constraint edges) over the same vertices
e = pa.FixedSizeListArray.from_arrays(pa.DictionaryArray.from_arrays(pa.array([0,1,1,3], pa.int32()), verts), 2)
s2 = pa.schema([("tri", t1.type), ("edges", e.type)])
b2 = io.BytesIO()
with ipc.new_stream(b2, s2) as w:
    w.write_batch(pa.record_batch([t1, pa.FixedSizeListArray.from_arrays(pa.DictionaryArray.from_arrays(pa.array([0,1], pa.int32()), verts), 2)], schema=s2))
m = ipc.MessageReader.open_stream(pa.BufferReader(b2.getvalue())); k=[]
while True:
    try: k.append(m.read_next_message().type)
    except StopIteration: break
print("two columns, stream messages:", k)
# fallback for parquet: decode to plain points (soup)
soup = pa.FixedSizeListArray.from_arrays(t1.values.dictionary_decode(), 3)
pb = io.BytesIO(); pq.write_table(pa.table({"tri": soup}), pb); pb.seek(0)
print("soup parquet ok:", pq.read_table(pb).schema.field("tri").type)
