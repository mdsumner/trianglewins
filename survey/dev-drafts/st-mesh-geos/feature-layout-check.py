"""Can a feature-per-row mesh share one vertex dictionary across rows?

Checks the layout suggested in the dev draft "What geoarrow.triangles needs
for ST_*": List<FixedSizeList<Dictionary<int32, Coordinate>>[3]>, one row
per feature (a list of its triangles), every triangle indexing one
dictionary for the whole array. Run with pyarrow (checked with 26.0.1):

    python3 survey/dev-drafts/st-mesh-geos/feature-layout-check.py
"""
import io

import pyarrow as pa
import pyarrow.parquet as pq

coord = pa.struct([("x", pa.float64()), ("y", pa.float64())])
vertex = pa.dictionary(pa.int32(), coord)
tri = pa.list_(pa.field("vertices", vertex, nullable=False), 3)
feat = pa.list_(pa.field("triangles", tri, nullable=False))

# two unit squares side by side, two triangles each; vertices 1 and 2 are
# shared by the two features (their common edge)
xy = pa.array([{"x": 0.0, "y": 0.0}, {"x": 1.0, "y": 0.0}, {"x": 1.0, "y": 1.0},
               {"x": 0.0, "y": 1.0}, {"x": 2.0, "y": 0.0}, {"x": 2.0, "y": 1.0}], coord)
idx = pa.array([0, 1, 2, 0, 2, 3, 1, 4, 5, 1, 5, 2], pa.int32())
verts = pa.DictionaryArray.from_arrays(idx, xy)
tris = pa.FixedSizeListArray.from_arrays(verts, type=tri)
features = pa.ListArray.from_arrays(pa.array([0, 2, 4], pa.int32()), tris, type=feat)
assert features.type == feat
results = []
results.append(("rows (features)", len(features)))
results.append(("triangles in row 2", len(features[1].values)))


def dictionary_of(arr):
    return arr.values.values.dictionary


# one dictionary for the whole array, also seen from a slice of one row
d_all = dictionary_of(features)
row2 = features.slice(1, 1)
results.append(("slice keeps the shared dictionary",
                dictionary_of(row2).equals(d_all)))
ids_row1 = set(features[0].values.flatten().indices.to_pylist())
ids_row2 = set(features[1].values.flatten().indices.to_pylist())
results.append(("vertex ids shared by rows 1 and 2", sorted(ids_row1 & ids_row2)))

# IPC stream: two batches, one dictionary; then a delta for a third feature
schema = pa.schema([pa.field("geometry", feat)])
sink = io.BytesIO()
opts = pa.ipc.IpcWriteOptions(emit_dictionary_deltas=True)
with pa.ipc.new_stream(sink, schema, options=opts) as w:
    w.write_batch(pa.record_batch([features], schema=schema))
    xy3 = pa.concat_arrays([xy, pa.array([{"x": 3.0, "y": 0.5}], coord)])
    idx3 = pa.array([4, 6, 5], pa.int32())
    f3 = pa.ListArray.from_arrays(
        pa.array([0, 1], pa.int32()),
        pa.FixedSizeListArray.from_arrays(pa.DictionaryArray.from_arrays(idx3, xy3), type=tri),
        type=feat)
    w.write_batch(pa.record_batch([f3], schema=schema))
buf = sink.getvalue()
reader = pa.ipc.open_stream(buf)
batches = list(reader)
results.append(("IPC batches read", len(batches)))
results.append(("batch 2 dictionary size (delta added one vertex)",
                len(dictionary_of(batches[1].column(0)))))
results.append(("batch 2 triangle refers to shared vertex ids",
                batches[1].column(0)[0].values.flatten().indices.to_pylist()))

# Parquet: expected to refuse a dictionary nested in a list
try:
    pq.write_table(pa.table({"geometry": features}), io.BytesIO())
    results.append(("Parquet, nested dictionary", "written"))
except Exception as e:  # noqa: BLE001
    results.append(("Parquet, nested dictionary", "refused: " + type(e).__name__))

# the feature column of the row-per-triangle layout is these list offsets
results.append(("list offsets (feature -> triangle ranges)", features.offsets.to_pylist()))

for k, v in results:
    print(f"{k}: {v}")
