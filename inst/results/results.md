# trianglewins results

Run 2026-11-16 22:24 UTC on R version 4.6.1 (2026-06-24), Ubuntu 24.04.5 LTS, 32 cores.

Backends: laridae 0.1.0 (ca6770f), cdtr 0.1.0.9002 (1b52f51), trowel 0.0.0.9000 (32e0fe8), RTriangle 1.6.0.15.

Steiner budget for every refinement: 100000. Area bound: bounding box area / 200 (synthetic) or / 5000 (nc, cont_tas, cad_tas). Angle bound: 25 degrees (20 in edit_refine).

## Time (ms, median)

Blank where the backend errored or was skipped; see the per-case tables.

| case | scenario | laridae | cdtr | trowel | RTriangle |
|---|---|---|---|---|---|
| square | constrained | 1.7 | 1.05 | 1.1 | 0.58 |
| square | area | 3.29 | 1.75 | 1.3 | 0.9 |
| square | angle | 2.3 | 1.15 | 1.1 | 0.6 |
| square | area_angle | 3.14 | 2.3 | 1.4 | 0.85 |
| square_hole | constrained | 1.6 | 1.05 | 1.05 | 0.58 |
| square_hole | area | 3.43 | 1.7 | 1.4 | 0.9 |
| square_hole | angle | 2.4 | 1.19 | 1.1 | 0.607 |
| square_hole | area_angle | 3.3 | 2.2 | 1.45 | 0.85 |
| nested3 | constrained | 1.7 | 1 | 1.05 | 0.597 |
| nested3 | area | 3.4 | 2 | 1.48 | 0.853 |
| nested3 | angle | 2.5 | 1.2 | 1.14 | 0.667 |
| nested3 | area_angle | 3.4 | 2.57 | 1.45 | 0.875 |
| grid3_doubled | constrained | 1.7 | 1.05 | 1.05 |  |
| grid3_doubled | area | 3.3 | 1.9 | 1.48 |  |
| grid3_doubled | angle | 2.43 | 1.19 | 1.19 |  |
| grid3_doubled | area_angle | 3.4 | 2.5 | 1.59 |  |
| grid3_dedup | constrained | 1.73 | 1 | 1.1 | 0.619 |
| grid3_dedup | area | 3.43 | 1.82 | 1.72 | 0.857 |
| grid3_dedup | angle | 2.57 | 1.15 | 1 | 0.638 |
| grid3_dedup | area_angle | 3.3 | 2.36 | 1.43 | 0.85 |
| crossing_rings | constrained | 1.6 | 1 | 1.02 | 0.6 |
| crossing_rings | area | 3 | 1.73 | 1.33 | 0.8 |
| crossing_rings | angle | 2.32 | 1.09 | 1.02 | 0.625 |
| crossing_rings | area_angle | 3.14 | 2.29 | 1.36 | 0.75 |
| crossing_x | constrained | 1.6 | 1 | 0.9 | 0.65 |
| crossing_x | area | 3.29 | 1.14 | 1.19 | 1 |
| crossing_x | angle | 2.29 | 1.1 | 0.905 | 0.7 |
| crossing_x | area_angle | 3.29 | 1.59 | 1.27 | 0.95 |
| collinear_overlap | constrained | 1.55 | 1.03 | 0.905 | 0.673 |
| collinear_overlap | area | 3.29 | 1.86 | 1.28 | 1.1 |
| collinear_overlap | angle | 2.29 | 1.09 | 1.05 | 0.65 |
| collinear_overlap | area_angle | 3.14 | 2.41 | 1.3 | 0.95 |
| dangling | constrained | 1.68 | 1.02 | 1.02 | 0.55 |
| dangling | area | 3.43 | 1.91 | 1.4 | 0.9 |
| dangling | angle | 2.3 | 1.18 | 1.1 | 0.571 |
| dangling | area_angle | 3.29 | 2.4 | 1.43 | 0.85 |
| sharp_corner | constrained | 1.64 | 1.05 | 1.05 | 0.571 |
| sharp_corner | area | 2.57 | 1.38 | 1.48 | 0.6 |
| sharp_corner | angle | 2.29 | 1.14 | 1.14 | 0.6 |
| sharp_corner | area_angle | 2.57 | 1.9 | 1.55 | 0.619 |
| grid_quads | constrained | 1.91 | 1.26 | 1.21 | 0.705 |
| grid_quads | area | 3.42 | 2 | 15 | 0.75 |
| grid_quads | angle | 2.8 | 1.45 | 25.5 | 0.714 |
| grid_quads | area_angle | 3.33 | 2.57 | 25.5 | 0.81 |
| grid_frames_lonlat | constrained | 1.82 | 1.1 | 1.1 | 0.714 |
| grid_frames_lonlat | area | 3.67 | 1.45 | 1.4 | 0.75 |
| grid_frames_lonlat | angle | 7.17 | 1.31 | 2.43 | 1.3 |
| grid_frames_lonlat | area_angle | 4 | 2 | 2.57 | 1.38 |
| grid_frames_3412 | constrained | 1.82 | 1.1 | 1.14 | 0.81 |
| grid_frames_3412 | area | 3.29 | 1.4 | 1.27 | 0.85 |
| grid_frames_3412 | angle | 2.57 | 1.33 | 1.1 | 0.762 |
| grid_frames_3412 | area_angle | 3.14 | 1.9 | 1.36 | 0.85 |
| grid_diagonal | constrained | 1.7 | 1.08 | 1 | 0.619 |
| grid_diagonal | area | 3.29 | 1.9 | 1.38 | 0.905 |
| grid_diagonal | angle | 2.3 | 1.2 | 1.07 | 0.65 |
| grid_diagonal | area_angle | 3.29 | 2.43 | 1.4 | 0.857 |
| points_only | constrained | 3 | 1.73 | 1.43 | 1.27 |
| points_only | area | 4.75 | 1.86 | 1.64 | 1.31 |
| points_only | angle | 6.33 | 2.09 | 2.14 | 1.6 |
| points_only | area_angle | 5 | 2.57 | 2.18 | 1.6 |
| nc | constrained | 7.67 | 4 | 2.57 | 2.79 |
| nc | area | 22 | 13 | 14.5 | 4.8 |
| nc | angle | 27 | 17.7 | 22 | 5.38 |
| nc | area_angle | 30 | 20.5 | 25 | 6.33 |
| nc_rings | constrained | 8 | 4.33 | 2.86 |  |
| nc_rings | area | 23 | 13.7 | 15 |  |
| nc_rings | angle | 28 | 19 | 22 |  |
| nc_rings | area_angle | 33 | 21.5 | 26 |  |
| cont_tas | constrained | 20.5 | 8.33 | 5.5 | 7.67 |
| cont_tas | area | 49 | 20 | 19.8 | 9.5 |
| cont_tas | angle | 64 | 32 | 51.5 | 17 |
| cont_tas | area_angle | 69 | 35 | 54.5 | 18.3 |
| cad_tas | constrained | 6.33 | 3.5 | 2.29 | 2.57 |
| cad_tas | area | 38 | 22 | 11 | 7.67 |
| cad_tas | angle | 26 | 17.5 | 15.5 | 8.83 |
| cad_tas | area_angle | 47 | 29 | 20 | 11.5 |
| nc | edit_refine | 18 | 17 | 17 | 6 |

## Depth

Harness depth is computed from the output triangles: crossing an edge costs the number of input segments on it (k) or 1 if there is any (1). `match` says which of the two the backend's own depth equals; where the backend also returns a distinct depth (a doubled boundary counted once), the match for that follows after a slash.

| case | harness k | harness 1 | laridae | cdtr | trowel | RTriangle |
|---|---|---|---|---|---|---|
| square | 1:2 | 1:2 | k=1 / k=1 | k=1 / k=1 | k=1 |  |
| square_hole | 1:8 2:2 | 1:8 2:2 | k=1 / k=1 | k=1 / k=1 | k=1 |  |
| nested3 | 1:8 2:8 3:2 | 1:8 2:8 3:2 | k=1 / k=1 | k=1 / k=1 | k=1 |  |
| grid3_doubled | 1:16 3:2 | 1:16 2:2 | k / 1 | k / 1 | 1 |  |
| grid3_dedup | 1:16 2:2 | 1:16 2:2 | k=1 / k=1 | k=1 / k=1 | k=1 |  |
| crossing_rings | 1:8 2:2 | 1:8 2:2 | k=1 / k=1 | k=1 / k=1 | k=1 |  |
| crossing_x | 0:4 | 0:4 | k=1 / k=1 | k=1 / k=1 | k=1 |  |
| collinear_overlap | 0:4 | 0:4 | k=1 / k=1 | k=1 / k=1 | k=1 |  |
| dangling | 1:8 | 1:8 | k=1 / k=1 | k=1 / k=1 | k=1 |  |
| sharp_corner | 1:13 | 1:13 | k=1 / k=1 | k=1 / k=1 | k=1 |  |
| grid_quads | 1:64 2:48 3:32 4:16 5:2 | 1:64 2:48 3:32 4:16 5:2 | k=1 / k=1 | k=1 / k=1 | k=1 |  |
| grid_frames_lonlat | 0:186 | 0:186 | k=1 / k=1 | k=1 / k=1 | k=1 |  |
| grid_frames_3412 | 0:162 | 0:162 | k=1 / k=1 | k=1 / k=1 | k=1 |  |
| grid_diagonal | 1:16 2:2 | 1:16 2:2 | k=1 / k=1 | k=1 / k=1 | k=1 |  |
| points_only | 0:981 | 0:981 | k=1 / k=1 | k=1 / k=1 | k=1 |  |
| nc | 1:1205 2:707 3:293 | 1:1205 2:707 3:293 | k=1 / k=1 | k=1 / k=1 | k=1 |  |
| nc_rings | 1:1205 3:707 5:293 | 1:1205 2:707 3:293 | k / 1 | k / 1 | 1 |  |
| cont_tas | 0:7124 1:216 2:131 3:53 4:15 | 0:7124 1:216 2:131 3:53 4:15 | k=1 / k=1 | k=1 / k=1 | k=1 |  |
| cad_tas | 1:744 2:957 3:267 4:6 | 1:750 2:951 3:267 4:6 | k / 1 | k / 1 | 1 |  |

## Errors and skips

| backend | case | scenarios | status | message |
|---|---|---|---|---|
| RTriangle | grid3_doubled | constrained, area, angle, area_angle | error | Duplicated vertices in P. |
| RTriangle | nc_rings | constrained, area, angle, area_angle | error | Duplicated vertices in P. |

## Per case

verts, tris: output counts; added: vertices not in the input; area ok / angle ok: percent of triangles meeting the bound; min ang: smallest angle (degrees); segs: percent of input segments present as chains of edges; CD viol: unconstrained edges failing the empty-circle test; depth: the backend's own depth table (depth:count); attr err: largest relative error of a linear attribute carried onto new vertices; floor: the edge-length floor the refiner used (cdtr, laridae); unrefined: what the backend says it could not do.

### square

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | floor | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 4 | 2 | 0 |  | 45 |  | 100.0 | 0 | 1:2 | 0.0e+00 | 1.7 |  |  |
| area | laridae | 169 | 288 | 165 | 100.0 | 29.7 |  | 100.0 | 0 | 1:288 | 1.5e-16 | 3.29 | 0.0177 | none |
| angle | laridae | 4 | 2 | 0 |  | 45 | 100.0 | 100.0 | 0 | 1:2 | 0.0e+00 | 2.3 | 0.3 | none |
| area_angle | laridae | 169 | 288 | 165 | 100.0 | 29.7 | 100.0 | 100.0 | 0 | 1:288 | 1.5e-16 | 3.14 | 0.0177 | none |
| constrained | cdtr | 4 | 2 | 0 |  | 45 |  | 100.0 | 0 | 1:2 | 0.0e+00 | 1.05 |  |  |
| area | cdtr | 156 | 275 | 152 | 100.0 | 26.6 |  | 100.0 | 0 | 1:275 | 1.5e-16 | 1.75 | 0.0177 | none |
| angle | cdtr | 4 | 2 | 0 |  | 45 | 100.0 | 100.0 | 0 | 1:2 | 0.0e+00 | 1.15 | 0.3 | none |
| area_angle | cdtr | 156 | 275 | 152 | 100.0 | 26.6 | 100.0 | 100.0 | 0 | 1:275 | 1.5e-16 | 2.3 | 0.0177 | none |
| constrained | trowel | 4 | 2 | 0 |  | 45 |  | 100.0 | 0 | 1:2 | 0.0e+00 | 1.1 |  |  |
| area | trowel | 167 | 293 | 163 | 100.0 | 31 |  | 100.0 | 0 | 1:293 | 7.4e-17 | 1.3 |  | none |
| angle | trowel | 4 | 2 | 0 |  | 45 | 100.0 | 100.0 | 0 | 1:2 | 0.0e+00 | 1.1 |  | none |
| area_angle | trowel | 168 | 295 | 164 | 100.0 | 31 | 100.0 | 100.0 | 0 | 1:295 | 7.4e-17 | 1.4 |  | none |
| constrained | RTriangle | 4 | 2 | 0 |  | 45 |  | 100.0 | 0 |  | 0.0e+00 | 0.58 |  |  |
| area | RTriangle | 171 | 314 | 167 | 100.0 | 0.171 |  | 100.0 | 0 |  | 4.4e-16 | 0.9 |  |  |
| angle | RTriangle | 4 | 2 | 0 |  | 45 | 100.0 | 100.0 | 0 |  | 0.0e+00 | 0.6 |  |  |
| area_angle | RTriangle | 180 | 322 | 176 | 100.0 | 25.8 | 100.0 | 100.0 | 0 |  | 4.4e-16 | 0.85 |  |  |

### square_hole

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | floor | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 8 | 10 | 0 |  | 18.4 |  | 100.0 | 0 | 1:8 2:2 | 0.0e+00 | 1.6 |  |  |
| area | laridae | 186 | 317 | 178 | 100.0 | 27.4 |  | 100.0 | 0 | 1:237 2:80 | 1.5e-16 | 3.43 | 0.0177 | none |
| angle | laridae | 24 | 30 | 16 |  | 45 | 100.0 | 100.0 | 0 | 1:24 2:6 | 0.0e+00 | 2.4 | 0.225 | none |
| area_angle | laridae | 186 | 317 | 178 | 100.0 | 27.4 | 100.0 | 100.0 | 0 | 1:237 2:80 | 1.5e-16 | 3.3 | 0.0177 | none |
| constrained | cdtr | 8 | 10 | 0 |  | 18.4 |  | 100.0 | 0 | 1:8 2:2 | 0.0e+00 | 1.05 |  |  |
| area | cdtr | 152 | 268 | 144 | 100.0 | 26.6 |  | 100.0 | 0 | 1:202 2:66 | 0.0e+00 | 1.7 | 0.0177 | none |
| angle | cdtr | 12 | 14 | 4 |  | 45 | 100.0 | 100.0 | 0 | 1:12 2:2 | 0.0e+00 | 1.19 | 0.225 | none |
| area_angle | cdtr | 152 | 268 | 144 | 100.0 | 26.6 | 100.0 | 100.0 | 0 | 1:202 2:66 | 0.0e+00 | 2.2 | 0.0177 | none |
| constrained | trowel | 8 | 10 | 0 |  | 18.4 |  | 100.0 | 0 | 1:8 2:2 | 0.0e+00 | 1.05 |  |  |
| area | trowel | 155 | 274 | 147 | 100.0 | 26.6 |  | 100.0 | 0 | 1:201 2:73 | 7.4e-17 | 1.4 |  | none |
| angle | trowel | 12 | 14 | 4 |  | 45 | 100.0 | 100.0 | 0 | 1:12 2:2 | 0.0e+00 | 1.1 |  | none |
| area_angle | trowel | 155 | 274 | 147 | 100.0 | 26.6 | 100.0 | 100.0 | 0 | 1:201 2:73 | 7.4e-17 | 1.45 |  | none |
| constrained | RTriangle | 8 | 10 | 0 |  | 18.4 |  | 100.0 | 0 |  | 0.0e+00 | 0.58 |  |  |
| area | RTriangle | 174 | 320 | 166 | 100.0 | 1.06 |  | 100.0 | 0 |  | 1.5e-16 | 0.9 |  |  |
| angle | RTriangle | 12 | 14 | 4 |  | 45 | 100.0 | 100.0 | 0 |  | 0.0e+00 | 0.607 |  |  |
| area_angle | RTriangle | 175 | 313 | 167 | 100.0 | 26.1 | 100.0 | 100.0 | 0 |  | 3.0e-16 | 0.85 |  |  |

### nested3

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | floor | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 12 | 18 | 0 |  | 14 |  | 100.0 | 0 | 1:8 2:8 3:2 | 0.0e+00 | 1.7 |  |  |
| area | laridae | 179 | 308 | 167 | 100.0 | 26.6 |  | 100.0 | 0 | 1:184 2:107 3:17 | 3.0e-16 | 3.4 | 0.0177 | none |
| angle | laridae | 28 | 38 | 16 |  | 38.7 | 100.0 | 100.0 | 0 | 1:24 2:12 3:2 | 1.5e-16 | 2.5 | 0.18 | none |
| area_angle | laridae | 179 | 308 | 167 | 100.0 | 26.6 | 100.0 | 100.0 | 0 | 1:184 2:107 3:17 | 3.0e-16 | 3.4 | 0.0177 | none |
| constrained | cdtr | 12 | 18 | 0 |  | 14 |  | 100.0 | 0 | 1:8 2:8 3:2 | 0.0e+00 | 1 |  |  |
| area | cdtr | 190 | 326 | 178 | 100.0 | 5.98 |  | 100.0 | 0 | 1:205 2:106 3:15 | 1.5e-16 | 2 | 0.0177 | shortEdges=2 |
| angle | cdtr | 28 | 38 | 16 |  | 38.7 | 100.0 | 100.0 | 0 | 1:24 2:12 3:2 | 7.4e-17 | 1.2 | 0.18 | none |
| area_angle | cdtr | 194 | 334 | 182 | 99.7 | 10.5 | 98.8 | 100.0 | 0 | 1:209 2:110 3:15 | 1.5e-16 | 2.57 | 0.0177 | shortEdgeTriangles=9 shortEdges=2 |
| constrained | trowel | 12 | 18 | 0 |  | 14 |  | 100.0 | 0 | 1:8 2:8 3:2 | 0.0e+00 | 1.05 |  |  |
| area | trowel | 202 | 350 | 190 | 100.0 | 20.6 |  | 100.0 | 0 | 1:210 2:121 3:19 | 1.5e-16 | 1.48 |  | none |
| angle | trowel | 28 | 38 | 16 |  | 38.7 | 100.0 | 100.0 | 0 | 1:24 2:12 3:2 | 7.4e-17 | 1.14 |  | none |
| area_angle | trowel | 207 | 359 | 195 | 100.0 | 27.2 | 100.0 | 100.0 | 0 | 1:216 2:120 3:23 | 1.5e-16 | 1.45 |  | none |
| constrained | RTriangle | 12 | 18 | 0 |  | 14 |  | 100.0 | 0 |  | 0.0e+00 | 0.597 |  |  |
| area | RTriangle | 176 | 328 | 164 | 100.0 | 0.622 |  | 100.0 | 0 |  | 1.5e-16 | 0.853 |  |  |
| angle | RTriangle | 20 | 30 | 8 |  | 33.7 | 100.0 | 100.0 | 0 |  | 7.4e-17 | 0.667 |  |  |
| area_angle | RTriangle | 179 | 323 | 167 | 100.0 | 25.4 | 100.0 | 100.0 | 0 |  | 1.5e-16 | 0.875 |  |  |

### grid3_doubled

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | floor | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 16 | 18 | 0 |  | 45 |  | 100.0 | 0 | 1:16 3:2 | 0.0e+00 | 1.7 |  |  |
| area | laridae | 169 | 288 | 153 | 100.0 | 40.1 |  | 100.0 | 0 | 1:256 3:32 | 9.9e-17 | 3.3 | 0.053 | none |
| angle | laridae | 16 | 18 | 0 |  | 45 | 100.0 | 100.0 | 0 | 1:16 3:2 | 0.0e+00 | 2.43 | 0.3 | none |
| area_angle | laridae | 169 | 288 | 153 | 100.0 | 40.1 | 100.0 | 100.0 | 0 | 1:256 3:32 | 9.9e-17 | 3.4 | 0.053 | none |
| constrained | cdtr | 16 | 18 | 0 |  | 45 |  | 100.0 | 0 | 1:16 3:2 | 0.0e+00 | 1.05 |  |  |
| area | cdtr | 174 | 298 | 158 | 100.0 | 31 |  | 100.0 | 0 | 1:264 3:34 | 9.9e-17 | 1.9 | 0.053 | none |
| angle | cdtr | 16 | 18 | 0 |  | 45 | 100.0 | 100.0 | 0 | 1:16 3:2 | 0.0e+00 | 1.19 | 0.3 | none |
| area_angle | cdtr | 174 | 298 | 158 | 100.0 | 31 | 100.0 | 100.0 | 0 | 1:264 3:34 | 9.9e-17 | 2.5 | 0.053 | none |
| constrained | trowel | 16 | 18 | 0 |  | 45 |  | 100.0 | 0 | 1:16 2:2 | 0.0e+00 | 1.05 |  |  |
| area | trowel | 176 | 302 | 160 | 100.0 | 31 |  | 100.0 | 0 | 1:268 2:34 | 9.9e-17 | 1.48 |  | none |
| angle | trowel | 16 | 18 | 0 |  | 45 | 100.0 | 100.0 | 0 | 1:16 2:2 | 0.0e+00 | 1.19 |  | none |
| area_angle | trowel | 176 | 302 | 160 | 100.0 | 31 | 100.0 | 100.0 | 0 | 1:268 2:34 | 9.9e-17 | 1.59 |  | none |

### grid3_dedup

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | floor | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 16 | 18 | 0 |  | 45 |  | 100.0 | 0 | 1:16 2:2 | 0.0e+00 | 1.73 |  |  |
| area | laridae | 169 | 288 | 153 | 100.0 | 36.9 |  | 100.0 | 0 | 1:256 2:32 | 9.9e-17 | 3.43 | 0.053 | none |
| angle | laridae | 16 | 18 | 0 |  | 45 | 100.0 | 100.0 | 0 | 1:16 2:2 | 0.0e+00 | 2.57 | 0.3 | none |
| area_angle | laridae | 169 | 288 | 153 | 100.0 | 36.9 | 100.0 | 100.0 | 0 | 1:256 2:32 | 9.9e-17 | 3.3 | 0.053 | none |
| constrained | cdtr | 16 | 18 | 0 |  | 45 |  | 100.0 | 0 | 1:16 2:2 | 0.0e+00 | 1 |  |  |
| area | cdtr | 174 | 298 | 158 | 100.0 | 31 |  | 100.0 | 0 | 1:264 2:34 | 9.9e-17 | 1.82 | 0.053 | none |
| angle | cdtr | 16 | 18 | 0 |  | 45 | 100.0 | 100.0 | 0 | 1:16 2:2 | 0.0e+00 | 1.15 | 0.3 | none |
| area_angle | cdtr | 174 | 298 | 158 | 100.0 | 31 | 100.0 | 100.0 | 0 | 1:264 2:34 | 9.9e-17 | 2.36 | 0.053 | none |
| constrained | trowel | 16 | 18 | 0 |  | 45 |  | 100.0 | 0 | 1:16 2:2 | 0.0e+00 | 1.1 |  |  |
| area | trowel | 176 | 302 | 160 | 100.0 | 31 |  | 100.0 | 0 | 1:268 2:34 | 9.9e-17 | 1.72 |  | none |
| angle | trowel | 16 | 18 | 0 |  | 45 | 100.0 | 100.0 | 0 | 1:16 2:2 | 0.0e+00 | 1 |  | none |
| area_angle | trowel | 176 | 302 | 160 | 100.0 | 31 | 100.0 | 100.0 | 0 | 1:268 2:34 | 9.9e-17 | 1.43 |  | none |
| constrained | RTriangle | 16 | 18 | 0 |  | 45 |  | 100.0 | 0 |  | 0.0e+00 | 0.619 |  |  |
| area | RTriangle | 175 | 320 | 159 | 100.0 | 0.0775 |  | 100.0 | 0 |  | 2.0e-16 | 0.857 |  |  |
| angle | RTriangle | 16 | 18 | 0 |  | 45 | 100.0 | 100.0 | 0 |  | 0.0e+00 | 0.638 |  |  |
| area_angle | RTriangle | 168 | 301 | 152 | 100.0 | 25.6 | 100.0 | 100.0 | 0 |  | 2.0e-16 | 0.85 |  |  |

### crossing_rings

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | floor | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 10 | 10 | 2 |  | 45 |  | 100.0 | 0 | 1:8 2:2 | 0.0e+00 | 1.6 |  |  |
| area | laridae | 143 | 236 | 135 | 100.0 | 32.3 |  | 100.0 | 0 | 1:204 2:32 | 9.9e-17 | 3 | 0.0265 | none |
| angle | laridae | 14 | 14 | 6 |  | 45 | 100.0 | 100.0 | 0 | 1:12 2:2 | 0.0e+00 | 2.32 | 0.3 | none |
| area_angle | laridae | 143 | 236 | 135 | 100.0 | 32.3 | 100.0 | 100.0 | 0 | 1:204 2:32 | 9.9e-17 | 3.14 | 0.0265 | none |
| constrained | cdtr | 10 | 10 | 2 |  | 45 |  | 100.0 | 0 | 1:8 2:2 | 0.0e+00 | 1 |  |  |
| area | cdtr | 139 | 228 | 131 | 100.0 | 33.7 |  | 100.0 | 0 | 1:196 2:32 | 0.0e+00 | 1.73 | 0.0265 | none |
| angle | cdtr | 10 | 10 | 2 |  | 45 | 100.0 | 100.0 | 0 | 1:8 2:2 | 0.0e+00 | 1.09 | 0.3 | none |
| area_angle | cdtr | 139 | 228 | 131 | 100.0 | 33.7 | 100.0 | 100.0 | 0 | 1:196 2:32 | 0.0e+00 | 2.29 | 0.0265 | none |
| constrained | trowel | 10 | 10 | 2 |  | 45 |  | 100.0 | 0 | 1:8 2:2 | 0.0e+00 | 1.02 |  |  |
| area | trowel | 143 | 236 | 135 | 100.0 | 30.6 |  | 100.0 | 0 | 1:204 2:32 | 9.9e-17 | 1.33 |  | none |
| angle | trowel | 10 | 10 | 2 |  | 45 | 100.0 | 100.0 | 0 | 1:8 2:2 | 0.0e+00 | 1.02 |  | none |
| area_angle | trowel | 143 | 236 | 135 | 100.0 | 30.6 | 100.0 | 100.0 | 0 | 1:204 2:32 | 9.9e-17 | 1.36 |  | none |
| constrained | RTriangle | 10 | 10 | 2 |  | 45 |  | 100.0 | 0 |  | 0.0e+00 | 0.6 |  |  |
| area | RTriangle | 144 | 259 | 136 | 100.0 | 0.0306 |  | 100.0 | 0 |  | 2.0e-16 | 0.8 |  |  |
| angle | RTriangle | 10 | 10 | 2 |  | 45 | 100.0 | 100.0 | 0 |  | 0.0e+00 | 0.625 |  |  |
| area_angle | RTriangle | 136 | 231 | 128 | 100.0 | 26.1 | 100.0 | 100.0 | 0 |  | 2.0e-16 | 0.75 |  |  |

### crossing_x

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | floor | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 5 | 4 | 1 |  | 45 |  | 100.0 | 0 | 0:4 | 0.0e+00 | 1.6 |  |  |
| area | laridae | 177 | 304 | 173 | 100.0 | 28.7 |  | 100.0 | 0 | 0:304 | 1.5e-16 | 3.29 | 0.0177 | none |
| angle | laridae | 21 | 24 | 17 |  | 28.7 | 100.0 | 100.0 | 0 | 0:24 | 7.4e-17 | 2.29 | 0.424 | none |
| area_angle | laridae | 177 | 304 | 173 | 100.0 | 28.7 | 100.0 | 100.0 | 0 | 0:304 | 1.5e-16 | 3.29 | 0.0177 | none |
| constrained | cdtr | 5 | 4 | 1 |  | 45 |  | 100.0 | 0 | 0:4 | 0.0e+00 | 1 |  |  |
| area | cdtr | 5 | 4 | 1 | 0.0 | 45 |  | 100.0 | 0 | 0:4 | 0.0e+00 | 1.14 | 0.0177 | circumcenterOutside=4 |
| angle | cdtr | 5 | 4 | 1 |  | 45 | 100.0 | 100.0 | 0 | 0:4 | 0.0e+00 | 1.1 | 0.424 | none |
| area_angle | cdtr | 5 | 4 | 1 | 0.0 | 45 | 100.0 | 100.0 | 0 | 0:4 | 0.0e+00 | 1.59 | 0.0177 | circumcenterOutside=4 |
| constrained | trowel | 5 | 4 | 1 |  | 45 |  | 100.0 | 0 | 0:4 | 0.0e+00 | 0.9 |  |  |
| area | trowel | 173 | 301 | 169 | 100.0 | 21.6 |  | 100.0 | 0 | 0:301 | 1.5e-16 | 1.19 |  | none |
| angle | trowel | 5 | 4 | 1 |  | 45 | 100.0 | 100.0 | 0 | 0:4 | 0.0e+00 | 0.905 |  | none |
| area_angle | trowel | 178 | 311 | 174 | 100.0 | 26.3 | 100.0 | 100.0 | 0 | 0:311 | 1.5e-16 | 1.27 |  | none |
| constrained | RTriangle | 5 | 4 | 1 |  | 45 |  | 100.0 | 0 |  | 0.0e+00 | 0.65 |  |  |
| area | RTriangle | 178 | 325 | 174 | 100.0 | 1.43 |  | 100.0 | 0 |  | 3.0e-16 | 1 |  |  |
| angle | RTriangle | 5 | 4 | 1 |  | 45 | 100.0 | 100.0 | 0 |  | 0.0e+00 | 0.7 |  |  |
| area_angle | RTriangle | 182 | 324 | 178 | 100.0 | 25.9 | 100.0 | 100.0 | 0 |  | 1.5e-16 | 0.95 |  |  |

### collinear_overlap

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | floor | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 6 | 4 | 0 |  | 18.4 |  | 100.0 | 0 | 0:4 | 0.0e+00 | 1.55 |  |  |
| area | laridae | 184 | 309 | 178 | 100.0 | 30.4 |  | 100.0 | 0 | 0:309 | 1.8e-16 | 3.29 | 0.0306 | none |
| angle | laridae | 7 | 5 | 1 |  | 45 | 100.0 | 100.0 | 0 | 0:5 | 0.0e+00 | 2.29 | 0.6 | none |
| area_angle | laridae | 184 | 309 | 178 | 100.0 | 30.4 | 100.0 | 100.0 | 0 | 0:309 | 1.8e-16 | 3.14 | 0.0306 | none |
| constrained | cdtr | 6 | 4 | 0 |  | 18.4 |  | 100.0 | 0 | 0:4 | 0.0e+00 | 1.03 |  |  |
| area | cdtr | 176 | 300 | 170 | 98.0 | 4.09 |  | 100.0 | 0 | 0:300 | 1.8e-16 | 1.86 | 0.0306 | circumcenterOutside=15 |
| angle | cdtr | 7 | 5 | 1 |  | 45 | 100.0 | 100.0 | 0 | 0:5 | 0.0e+00 | 1.09 | 0.6 | none |
| area_angle | cdtr | 180 | 308 | 174 | 97.7 | 0.25 | 97.4 | 100.0 | 0 | 0:308 | 1.8e-16 | 2.41 | 0.0306 | circumcenterOutside=28 |
| constrained | trowel | 6 | 4 | 0 |  | 18.4 |  | 100.0 | 0 | 0:4 | 0.0e+00 | 0.905 |  |  |
| area | trowel | 198 | 330 | 192 | 100.0 | 29 |  | 100.0 | 0 | 0:330 | 1.8e-16 | 1.28 |  | none |
| angle | trowel | 7 | 5 | 1 |  | 45 | 100.0 | 100.0 | 0 | 0:5 | 0.0e+00 | 1.05 |  | none |
| area_angle | trowel | 198 | 330 | 192 | 100.0 | 29 | 100.0 | 100.0 | 0 | 0:330 | 1.8e-16 | 1.3 |  | none |
| constrained | RTriangle | 6 | 4 | 0 |  | 18.4 |  | 100.0 | 0 |  | 0.0e+00 | 0.673 |  |  |
| area | RTriangle | 175 | 315 | 169 | 100.0 | 4.48 |  | 100.0 | 0 |  | 1.8e-16 | 1.1 |  |  |
| angle | RTriangle | 7 | 5 | 1 |  | 45 | 100.0 | 100.0 | 0 |  | 0.0e+00 | 0.65 |  |  |
| area_angle | RTriangle | 180 | 312 | 174 | 100.0 | 25.8 | 100.0 | 100.0 | 0 |  | 5.3e-16 | 0.95 |  |  |

### dangling

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | floor | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 7 | 8 | 0 |  | 11.3 |  | 100.0 | 0 | 1:8 | 0.0e+00 | 1.68 |  |  |
| area | laridae | 188 | 320 | 181 | 100.0 | 29.6 |  | 100.0 | 0 | 1:320 | 1.5e-16 | 3.43 | 0.0177 | none |
| angle | laridae | 10 | 11 | 3 |  | 11.3 | 45.5 | 100.0 | 0 | 1:11 | 0.0e+00 | 2.3 | 0.3 | bad=6 short_edge=6 |
| area_angle | laridae | 188 | 320 | 181 | 100.0 | 29.6 | 100.0 | 100.0 | 0 | 1:320 | 1.5e-16 | 3.29 | 0.0177 | none |
| constrained | cdtr | 7 | 8 | 0 |  | 11.3 |  | 100.0 | 0 | 1:8 | 0.0e+00 | 1.02 |  |  |
| area | cdtr | 183 | 318 | 176 | 100.0 | 28.3 |  | 100.0 | 0 | 1:318 | 3.0e-16 | 1.91 | 0.0177 | none |
| angle | cdtr | 10 | 11 | 3 |  | 11.3 | 45.5 | 100.0 | 0 | 1:11 | 0.0e+00 | 1.18 | 0.3 | shortEdgeTriangles=6 |
| area_angle | cdtr | 183 | 318 | 176 | 100.0 | 28.3 | 100.0 | 100.0 | 0 | 1:318 | 3.0e-16 | 2.4 | 0.0177 | none |
| constrained | trowel | 7 | 8 | 0 |  | 11.3 |  | 100.0 | 0 | 1:8 | 0.0e+00 | 1.02 |  |  |
| area | trowel | 182 | 315 | 175 | 100.0 | 23.8 |  | 100.0 | 0 | 1:315 | 1.5e-16 | 1.4 |  | none |
| angle | trowel | 25 | 32 | 18 |  | 26.6 | 100.0 | 100.0 | 0 | 1:32 | 1.5e-16 | 1.1 |  | none |
| area_angle | trowel | 183 | 317 | 176 | 100.0 | 26.6 | 100.0 | 100.0 | 0 | 1:317 | 1.5e-16 | 1.43 |  | none |
| constrained | RTriangle | 7 | 8 | 0 |  | 11.3 |  | 100.0 | 0 |  | 0.0e+00 | 0.55 |  |  |
| area | RTriangle | 173 | 320 | 166 | 100.0 | 1.08 |  | 100.0 | 0 |  | 1.5e-16 | 0.9 |  |  |
| angle | RTriangle | 23 | 29 | 16 |  | 25.8 | 100.0 | 100.0 | 0 |  | 1.5e-16 | 0.571 |  |  |
| area_angle | RTriangle | 178 | 319 | 171 | 100.0 | 26.6 | 100.0 | 100.0 | 0 |  | 5.2e-16 | 0.85 |  |  |

### sharp_corner

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | floor | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 17 | 13 | 0 |  | 1 |  | 100.0 | 0 | 1:13 | 0.0e+00 | 1.64 |  |  |
| area | laridae | 51 | 51 | 34 | 100.0 | 1 |  | 100.0 | 0 | 1:51 | 1.2e-16 | 2.57 | 0.0518 | none |
| angle | laridae | 19 | 15 | 2 |  | 1 | 80.0 | 100.0 | 0 | 1:15 | 0.0e+00 | 2.29 | 0.21 | bad=3 short_edge=3 sharp_corner=1 |
| area_angle | laridae | 51 | 51 | 34 | 100.0 | 1 | 94.1 | 100.0 | 0 | 1:51 | 1.2e-16 | 2.57 | 0.0518 | bad=3 short_edge=3 sharp_corner=1 |
| constrained | cdtr | 17 | 13 | 0 |  | 1 |  | 100.0 | 0 | 1:13 | 0.0e+00 | 1.05 |  |  |
| area | cdtr | 49 | 49 | 32 | 100.0 | 1 |  | 100.0 | 0 | 1:49 | 6.2e-17 | 1.38 | 0.0518 | none |
| angle | cdtr | 17 | 13 | 0 |  | 1 | 92.3 | 100.0 | 0 | 1:13 | 0.0e+00 | 1.14 | 0.21 | sharpFixedCorner=1 |
| area_angle | cdtr | 49 | 49 | 32 | 100.0 | 1 | 98.0 | 100.0 | 0 | 1:49 | 6.2e-17 | 1.9 | 0.0518 | sharpFixedCorner=1 |
| constrained | trowel | 17 | 13 | 0 |  | 1 |  | 100.0 | 0 | 1:13 | 0.0e+00 | 1.05 |  |  |
| area | trowel | 75 | 75 | 58 | 100.0 | 1 |  | 100.0 | 0 | 1:75 | 1.2e-16 | 1.48 |  | none |
| angle | trowel | 29 | 25 | 12 |  | 1 | 64.0 | 100.0 | 0 | 1:25 | 1.2e-16 | 1.14 |  | none |
| area_angle | trowel | 88 | 95 | 71 | 100.0 | 1 | 76.8 | 100.0 | 0 | 1:95 | 1.2e-16 | 1.55 |  | none |
| constrained | RTriangle | 17 | 13 | 0 |  | 1 |  | 100.0 | 0 |  | 0.0e+00 | 0.571 |  |  |
| area | RTriangle | 35 | 49 | 18 | 100.0 | 1 |  | 100.0 | 0 |  | 6.2e-17 | 0.6 |  |  |
| angle | RTriangle | 27 | 23 | 10 |  | 1 | 69.6 | 100.0 | 0 |  | 1.2e-16 | 0.6 |  |  |
| area_angle | RTriangle | 52 | 59 | 35 | 100.0 | 1 | 88.1 | 100.0 | 0 |  | 1.2e-16 | 0.619 |  |  |

### grid_quads

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | floor | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 100 | 162 | 0 |  | 26.5 |  | 100.0 | 0 | 1:64 2:48 3:32 4:16 5:2 | 0.0e+00 | 1.91 |  |  |
| area | laridae | 190 | 324 | 90 | 100.0 | 43.5 |  | 100.0 | 0 | 1:128 2:96 3:64 4:32 5:4 | 1.2e-16 | 3.42 | 0.0488 | none |
| angle | laridae | 100 | 162 | 0 |  | 26.5 | 100.0 | 100.0 | 0 | 1:64 2:48 3:32 4:16 5:2 | 0.0e+00 | 2.8 | 0.0934 | none |
| area_angle | laridae | 190 | 324 | 90 | 100.0 | 43.5 | 100.0 | 100.0 | 0 | 1:128 2:96 3:64 4:32 5:4 | 1.2e-16 | 3.33 | 0.0488 | none |
| constrained | cdtr | 100 | 162 | 0 |  | 26.5 |  | 100.0 | 0 | 1:64 2:48 3:32 4:16 5:2 | 0.0e+00 | 1.26 |  |  |
| area | cdtr | 190 | 324 | 90 | 100.0 | 43.5 |  | 100.0 | 0 | 1:128 2:96 3:64 4:32 5:4 | 1.2e-16 | 2 | 0.0488 | none |
| angle | cdtr | 100 | 162 | 0 |  | 26.5 | 100.0 | 100.0 | 0 | 1:64 2:48 3:32 4:16 5:2 | 0.0e+00 | 1.45 | 0.0934 | none |
| area_angle | cdtr | 190 | 324 | 90 | 100.0 | 43.5 | 100.0 | 100.0 | 0 | 1:128 2:96 3:64 4:32 5:4 | 1.2e-16 | 2.57 | 0.0488 | none |
| constrained | trowel | 100 | 162 | 0 |  | 26.5 |  | 100.0 | 0 | 1:64 2:48 3:32 4:16 5:2 | 0.0e+00 | 1.21 |  |  |
| area | trowel | 1937 | 2109 | 1837 | 100.0 | 0.122 |  | 100.0 | 0 | 1:1913 2:96 3:64 4:32 5:4 | 1.8e-03 | 15 |  | none |
| angle | trowel | 5499 | 8916 | 5399 |  | 25 | 100.0 | 100.0 | 0 | 1:8711 2:141 3:45 4:17 5:2 | 1.8e-03 | 25.5 |  | none |
| area_angle | trowel | 5550 | 9012 | 5450 | 100.0 | 25 | 100.0 | 100.0 | 0 | 1:8726 2:158 3:82 4:42 5:4 | 1.8e-03 | 25.5 |  | none |
| constrained | RTriangle | 100 | 162 | 0 |  | 26.5 |  | 100.0 | 0 |  | 0.0e+00 | 0.705 |  |  |
| area | RTriangle | 181 | 324 | 81 | 100.0 | 24.1 |  | 100.0 | 0 |  | 1.2e-16 | 0.75 |  |  |
| angle | RTriangle | 100 | 162 | 0 |  | 26.5 | 100.0 | 100.0 | 0 |  | 0.0e+00 | 0.714 |  |  |
| area_angle | RTriangle | 185 | 324 | 85 | 100.0 | 25.1 | 100.0 | 100.0 | 0 |  | 1.2e-16 | 0.81 |  |  |

### grid_frames_lonlat

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | floor | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 100 | 186 | 0 |  | 0.0244 |  |  | 0 | 0:186 | 0.0e+00 | 1.82 |  |  |
| area | laridae | 282 | 440 | 182 | 100.0 | 1.28 |  |  | 0 | 0:440 | 1.2e-16 | 3.67 | 0.0488 | none |
| angle | laridae | 920 | 1537 | 820 |  | 25 | 100.0 |  | 0 | 0:1537 | 7.0e-16 | 7.17 | 0 | none |
| area_angle | laridae | 308 | 492 | 208 | 100.0 | 1.28 | 82.1 |  | 0 | 0:492 | 1.2e-16 | 4 | 0.0488 | bad=88 short_edge=88 outside=18 |
| constrained | cdtr | 100 | 186 | 0 |  | 0.0244 |  |  | 0 | 0:186 | 0.0e+00 | 1.1 |  |  |
| area | cdtr | 181 | 348 | 81 | 100.0 | 0.0244 |  |  | 0 | 0:348 | 1.2e-16 | 1.45 | 0.0488 | none |
| angle | cdtr | 100 | 186 | 0 |  | 0.0244 | 87.1 |  | 0 | 0:186 | 0.0e+00 | 1.31 | 0 | circumcenterOutside=24 |
| area_angle | cdtr | 181 | 348 | 81 | 100.0 | 0.0244 | 91.1 |  | 0 | 0:348 | 1.2e-16 | 2 | 0.0488 | circumcenterOutside=31 |
| constrained | trowel | 100 | 186 | 0 |  | 0.0244 |  |  | 0 | 0:186 | 0.0e+00 | 1.1 |  |  |
| area | trowel | 323 | 472 | 223 | 100.0 | 1.14 |  |  | 0 | 0:472 | 1.8e-03 | 1.4 |  | none |
| angle | trowel | 982 | 1640 | 882 |  | 25 | 100.0 |  | 0 | 0:1640 | 1.8e-03 | 2.43 |  | none |
| area_angle | trowel | 1013 | 1690 | 913 | 100.0 | 25 | 100.0 |  | 0 | 0:1690 | 1.8e-03 | 2.57 |  | none |
| constrained | RTriangle | 100 | 186 | 0 |  | 0.0244 |  |  | 0 |  | 0.0e+00 | 0.714 |  |  |
| area | RTriangle | 181 | 348 | 81 | 100.0 | 0.0244 |  |  | 0 |  | 1.2e-16 | 0.75 |  |  |
| angle | RTriangle | 621 | 1017 | 521 |  | 25 | 100.0 |  | 0 |  | 4.4e-13 | 1.3 |  |  |
| area_angle | RTriangle | 672 | 1118 | 572 | 100.0 | 25 | 100.0 |  | 0 |  | 4.4e-13 | 1.38 |  |  |

### grid_frames_3412

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | floor | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 100 | 162 | 0 |  | 45 |  |  | 0 | 0:162 | 0.0e+00 | 1.82 |  |  |
| area | laridae | 213 | 352 | 113 | 100.0 | 26.6 |  |  | 0 | 0:352 | 0.0e+00 | 3.29 | 3.98e+03 | none |
| angle | laridae | 100 | 162 | 0 |  | 45 | 100.0 |  | 0 | 0:162 | 0.0e+00 | 2.57 | 0 | none |
| area_angle | laridae | 213 | 352 | 113 | 100.0 | 26.6 | 100.0 |  | 0 | 0:352 | 0.0e+00 | 3.14 | 3.98e+03 | none |
| constrained | cdtr | 100 | 162 | 0 |  | 45 |  |  | 0 | 0:162 | 0.0e+00 | 1.1 |  |  |
| area | cdtr | 181 | 324 | 81 | 100.0 | 45 |  |  | 0 | 0:324 | 0.0e+00 | 1.4 | 3.98e+03 | none |
| angle | cdtr | 100 | 162 | 0 |  | 45 | 100.0 |  | 0 | 0:162 | 0.0e+00 | 1.33 | 0 | none |
| area_angle | cdtr | 181 | 324 | 81 | 100.0 | 45 | 100.0 |  | 0 | 0:324 | 0.0e+00 | 1.9 | 3.98e+03 | none |
| constrained | trowel | 100 | 162 | 0 |  | 45 |  |  | 0 | 0:162 | 0.0e+00 | 1.14 |  |  |
| area | trowel | 181 | 324 | 81 | 100.0 | 45 |  |  | 0 | 0:324 | 0.0e+00 | 1.27 |  | none |
| angle | trowel | 100 | 162 | 0 |  | 45 | 100.0 |  | 0 | 0:162 | 0.0e+00 | 1.1 |  | none |
| area_angle | trowel | 181 | 324 | 81 | 100.0 | 45 | 100.0 |  | 0 | 0:324 | 0.0e+00 | 1.36 |  | none |
| constrained | RTriangle | 100 | 162 | 0 |  | 45 |  |  | 0 |  | 0.0e+00 | 0.81 |  |  |
| area | RTriangle | 181 | 324 | 81 | 100.0 | 45 |  |  | 0 |  | 0.0e+00 | 0.85 |  |  |
| angle | RTriangle | 100 | 162 | 0 |  | 45 | 100.0 |  | 0 |  | 0.0e+00 | 0.762 |  |  |
| area_angle | RTriangle | 181 | 324 | 81 | 100.0 | 45 | 100.0 |  | 0 |  | 0.0e+00 | 0.85 |  |  |

### grid_diagonal

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | floor | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 16 | 18 | 0 |  | 45 |  | 100.0 | 0 | 1:16 2:2 | 0.0e+00 | 1.7 |  |  |
| area | laridae | 169 | 288 | 153 | 100.0 | 40.1 |  | 100.0 | 0 | 1:256 2:32 | 9.9e-17 | 3.29 | 0.053 | none |
| angle | laridae | 16 | 18 | 0 |  | 45 | 100.0 | 100.0 | 0 | 1:16 2:2 | 0.0e+00 | 2.3 | 0.3 | none |
| area_angle | laridae | 169 | 288 | 153 | 100.0 | 40.1 | 100.0 | 100.0 | 0 | 1:256 2:32 | 9.9e-17 | 3.29 | 0.053 | none |
| constrained | cdtr | 16 | 18 | 0 |  | 45 |  | 100.0 | 0 | 1:16 2:2 | 0.0e+00 | 1.08 |  |  |
| area | cdtr | 174 | 298 | 158 | 100.0 | 33.7 |  | 100.0 | 0 | 1:264 2:34 | 0.0e+00 | 1.9 | 0.053 | none |
| angle | cdtr | 16 | 18 | 0 |  | 45 | 100.0 | 100.0 | 0 | 1:16 2:2 | 0.0e+00 | 1.2 | 0.3 | none |
| area_angle | cdtr | 174 | 298 | 158 | 100.0 | 33.7 | 100.0 | 100.0 | 0 | 1:264 2:34 | 0.0e+00 | 2.43 | 0.053 | none |
| constrained | trowel | 16 | 18 | 0 |  | 45 |  | 100.0 | 0 | 1:16 2:2 | 0.0e+00 | 1 |  |  |
| area | trowel | 172 | 294 | 156 | 100.0 | 30.1 |  | 100.0 | 0 | 1:262 2:32 | 9.9e-17 | 1.38 |  | none |
| angle | trowel | 16 | 18 | 0 |  | 45 | 100.0 | 100.0 | 0 | 1:16 2:2 | 0.0e+00 | 1.07 |  | none |
| area_angle | trowel | 174 | 298 | 158 | 100.0 | 31 | 100.0 | 100.0 | 0 | 1:266 2:32 | 9.9e-17 | 1.4 |  | none |
| constrained | RTriangle | 16 | 18 | 0 |  | 45 |  | 100.0 | 0 |  | 0.0e+00 | 0.619 |  |  |
| area | RTriangle | 175 | 320 | 159 | 100.0 | 0.0775 |  | 100.0 | 0 |  | 2.0e-16 | 0.905 |  |  |
| angle | RTriangle | 16 | 18 | 0 |  | 45 | 100.0 | 100.0 | 0 |  | 0.0e+00 | 0.65 |  |  |
| area_angle | RTriangle | 168 | 301 | 152 | 100.0 | 25.6 | 100.0 | 100.0 | 0 |  | 2.0e-16 | 0.857 |  |  |

### points_only

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | floor | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 500 | 981 | 0 |  | 0.138 |  |  | 0 | 0:981 | 0.0e+00 | 3 |  |  |
| area | laridae | 616 | 1097 | 116 | 100.0 | 4.02 |  |  | 0 | 0:1097 | 1.1e-16 | 4.75 | 0.0176 | none |
| angle | laridae | 905 | 1603 | 405 |  | 25 | 100.0 |  | 0 | 0:1603 | 1.5e-16 | 6.33 | 0 | none |
| area_angle | laridae | 631 | 1124 | 131 | 100.0 | 4.31 | 93.1 |  | 0 | 0:1124 | 1.1e-16 | 5 | 0.0176 | bad=78 short_edge=78 outside=12 |
| constrained | cdtr | 500 | 981 | 0 |  | 0.138 |  |  | 0 | 0:981 | 0.0e+00 | 1.73 |  |  |
| area | cdtr | 500 | 981 | 0 | 100.0 | 0.138 |  |  | 0 | 0:981 | 0.0e+00 | 1.86 | 0.0176 | none |
| angle | cdtr | 501 | 983 | 1 |  | 0.138 | 94.9 |  | 0 | 0:983 | 1.5e-16 | 2.09 | 0 | circumcenterOutside=52 |
| area_angle | cdtr | 501 | 983 | 1 | 100.0 | 0.138 | 94.9 |  | 0 | 0:983 | 1.5e-16 | 2.57 | 0.0176 | circumcenterOutside=52 |
| constrained | trowel | 500 | 981 | 0 |  | 0.138 |  |  | 0 | 0:981 | 0.0e+00 | 1.43 |  |  |
| area | trowel | 646 | 1127 | 146 | 100.0 | 4.31 |  |  | 0 | 0:1127 | 3.7e-02 | 1.64 |  | none |
| angle | trowel | 949 | 1662 | 449 |  | 25 | 100.0 |  | 0 | 0:1662 | 3.7e-02 | 2.14 |  | none |
| area_angle | trowel | 949 | 1662 | 449 | 100.0 | 25 | 100.0 |  | 0 | 0:1662 | 3.7e-02 | 2.18 |  | none |
| constrained | RTriangle | 500 | 981 | 0 |  | 0.138 |  |  | 0 |  | 0.0e+00 | 1.27 |  |  |
| area | RTriangle | 500 | 981 | 0 | 100.0 | 0.138 |  |  | 0 |  | 0.0e+00 | 1.31 |  |  |
| angle | RTriangle | 792 | 1429 | 292 |  | 25 | 100.0 |  | 0 |  | 4.6e-16 | 1.6 |  |  |
| area_angle | RTriangle | 792 | 1429 | 292 | 100.0 | 25 | 100.0 |  | 0 |  | 4.6e-16 | 1.6 |  |  |

### nc

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | floor | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 1255 | 2205 | 0 |  | 0.774 |  | 100.0 | 0 | 1:1205 2:707 3:293 | 0.0e+00 | 7.67 |  |  |
| area | laridae | 2960 | 5300 | 1705 | 100.0 | 3.52 |  | 100.0 | 0 | 1:2849 2:1685 3:766 | 1.1e-17 | 22 | 0.0138 | none |
| angle | laridae | 3570 | 6479 | 2315 |  | 2.1 | 98.4 | 100.0 | 0 | 1:3556 2:2045 3:878 | 1.1e-17 | 27 | 0.0138 | bad=104 short_edge=102 sharp_corner=8 |
| area_angle | laridae | 4102 | 7506 | 2847 | 100.0 | 3.52 | 98.6 | 100.0 | 0 | 1:4045 2:2407 3:1054 | 1.1e-17 | 30 | 0.0138 | bad=105 short_edge=103 sharp_corner=9 |
| edit_refine | laridae | 3472 | 6292 | 2215 | 100.0 | 3.07 | 98.4 | 100.0 | 0 | 1:3387 2:2001 3:904 |  | 18 |  |  |
| constrained | cdtr | 1255 | 2205 | 0 |  | 0.774 |  | 100.0 | 0 | 1:1205 2:707 3:293 | 0.0e+00 | 4 |  |  |
| area | cdtr | 3097 | 5460 | 1842 | 100.0 | 3.52 |  | 100.0 | 0 | 1:2976 2:1705 3:779 | 1.1e-17 | 13 | 0.0138 | shortEdges=36 |
| angle | cdtr | 3778 | 6804 | 2523 |  | 3.52 | 98.0 | 100.0 | 0 | 1:3770 2:2091 3:943 | 1.1e-17 | 17.7 | 0.0138 | shortEdgeTriangles=235 sharpFixedCorner=5 shortEdges=35 |
| area_angle | cdtr | 4309 | 7822 | 3054 | 100.0 | 3.52 | 98.2 | 100.0 | 0 | 1:4322 2:2417 3:1083 | 1.1e-17 | 20.5 | 0.0138 | shortEdgeTriangles=201 sharpFixedCorner=5 shortEdges=61 |
| edit_refine | cdtr | 3635 | 6519 | 2378 | 100.0 | 3.52 | 98.2 | 100.0 | 0 | 1:3564 2:2036 3:919 |  | 17 |  |  |
| constrained | trowel | 1255 | 2205 | 0 |  | 0.774 |  | 100.0 | 0 | 1:1205 2:707 3:293 | 0.0e+00 | 2.57 |  |  |
| area | trowel | 3864 | 6257 | 2609 | 100.0 | 0.225 |  | 100.0 | 0 | 1:3739 2:1725 3:793 | 1.7e-03 | 14.5 |  | none |
| angle | trowel | 6440 | 11232 | 5185 |  | 3.51 | 99.8 | 100.0 | 0 | 1:7424 2:2590 3:1218 | 1.7e-03 | 22 |  | none |
| area_angle | trowel | 6831 | 11988 | 5576 | 100.0 | 3.51 | 99.8 | 100.0 | 0 | 1:7748 2:2922 3:1318 | 1.7e-03 | 25 |  | none |
| edit_refine | trowel | 5555 | 9406 | 4298 | 100.0 | 3.52 | 99.9 | 100.0 | 0 | 1:6171 2:2227 3:1008 |  | 17 |  |  |
| constrained | RTriangle | 1255 | 2205 | 0 |  | 0.774 |  | 100.0 | 0 |  | 0.0e+00 | 2.79 |  |  |
| area | RTriangle | 2716 | 5067 | 1461 | 100.0 | 0.154 |  | 100.0 | 0 |  | 1.7e-16 | 4.8 |  |  |
| angle | RTriangle | 3089 | 5613 | 1834 |  | 3.52 | 99.9 | 100.0 | 0 |  | 1.6e-15 | 5.38 |  |  |
| area_angle | RTriangle | 3710 | 6824 | 2455 | 100.0 | 3.52 | 99.9 | 100.0 | 0 |  | 1.6e-15 | 6.33 |  |  |
| edit_refine | RTriangle | 3299 | 6055 | 2042 | 100.0 | 3.52 | 99.9 | 100.0 | 0 |  |  | 6 |  |  |

### nc_rings

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | floor | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 1255 | 2205 | 0 |  | 0.774 |  | 100.0 | 0 | 1:1205 3:707 5:293 | 0.0e+00 | 8 |  |  |
| area | laridae | 2960 | 5300 | 1705 | 100.0 | 3.52 |  | 100.0 | 0 | 1:2849 3:1685 5:766 | 1.1e-17 | 23 | 0.0131 | none |
| angle | laridae | 3621 | 6574 | 2366 |  | 2.1 | 98.5 | 100.0 | 0 | 1:3573 3:2070 5:931 | 1.1e-17 | 28 | 0.0131 | bad=98 short_edge=95 sharp_corner=8 |
| area_angle | laridae | 4149 | 7593 | 2894 | 100.0 | 3.52 | 98.7 | 100.0 | 0 | 1:4061 3:2427 5:1105 | 1.1e-17 | 33 | 0.0131 | bad=98 short_edge=95 sharp_corner=9 |
| constrained | cdtr | 1255 | 2205 | 0 |  | 0.774 |  | 100.0 | 0 | 1:1205 3:707 5:293 | 0.0e+00 | 4.33 |  |  |
| area | cdtr | 3105 | 5469 | 1850 | 100.0 | 3.52 |  | 100.0 | 0 | 1:2984 3:1706 5:779 | 1.1e-17 | 13.7 | 0.0131 | shortEdges=27 |
| angle | cdtr | 3849 | 6935 | 2594 |  | 3.52 | 98.2 | 100.0 | 0 | 1:3793 3:2124 5:1018 | 1.1e-17 | 19 | 0.0131 | shortEdgeTriangles=220 sharpFixedCorner=5 shortEdges=27 |
| area_angle | cdtr | 4366 | 7925 | 3111 | 100.0 | 3.52 | 98.4 | 100.0 | 0 | 1:4339 3:2439 5:1147 | 1.1e-17 | 21.5 | 0.0131 | shortEdgeTriangles=194 sharpFixedCorner=5 shortEdges=47 |
| constrained | trowel | 1255 | 2205 | 0 |  | 0.774 |  | 100.0 | 0 | 1:1205 2:707 3:293 | 0.0e+00 | 2.86 |  |  |
| area | trowel | 3863 | 6255 | 2608 | 100.0 | 0.225 |  | 100.0 | 0 | 1:3737 2:1726 3:792 | 1.7e-03 | 15 |  | none |
| angle | trowel | 6441 | 11234 | 5186 |  | 3.51 | 99.8 | 100.0 | 0 | 1:7424 2:2591 3:1219 | 1.7e-03 | 22 |  | none |
| area_angle | trowel | 6825 | 11976 | 5570 | 100.0 | 3.51 | 99.8 | 100.0 | 0 | 1:7747 2:2913 3:1316 | 1.7e-03 | 26 |  | none |

### cont_tas

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | floor | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 3827 | 7539 | 0 |  | 0.0089 |  | 100.0 | 0 | 0:7124 1:216 2:131 3:53 4:15 | 0.0e+00 | 20.5 |  |  |
| area | laridae | 6204 | 11982 | 2377 | 100.0 | 0.0185 |  | 100.0 | 0 | 0:11341 1:331 2:219 3:76 4:15 | 3.4e-16 | 49 | 2.8 | none |
| angle | laridae | 8015 | 15574 | 4188 |  | 0.0185 | 96.3 | 100.0 | 0 | 0:14643 1:464 2:312 3:128 4:27 | 3.4e-16 | 64 | 2.8 | bad=579 short_edge=577 sharp_corner=24 outside=33 |
| area_angle | laridae | 8489 | 16500 | 4662 | 100.0 | 0.0185 | 96.5 | 100.0 | 0 | 0:15510 1:498 2:336 3:129 4:27 | 3.4e-16 | 69 | 2.8 | bad=579 short_edge=577 sharp_corner=24 outside=33 |
| constrained | cdtr | 3827 | 7539 | 0 |  | 0.0089 |  | 100.0 | 0 | 0:7124 1:216 2:131 3:53 4:15 | 0.0e+00 | 8.33 |  |  |
| area | cdtr | 5835 | 11555 | 2008 | 99.7 | 0.00609 |  | 100.0 | 0 | 0:10915 1:329 2:218 3:78 4:15 | 3.4e-16 | 20 | 2.8 | circumcenterOutside=69 shortEdges=30 |
| angle | cdtr | 7755 | 15395 | 3928 |  | 0.00609 | 95.6 | 100.0 | 0 | 0:14416 1:499 2:320 3:128 4:32 | 3.4e-16 | 32 | 2.8 | shortEdgeTriangles=905 circumcenterOutside=349 sharpFixedCorner=1 shortEdges=32 |
| area_angle | cdtr | 8089 | 16063 | 4262 | 99.7 | 0.00609 | 95.7 | 100.0 | 0 | 0:15059 1:502 2:339 3:131 4:32 | 3.4e-16 | 35 | 2.8 | shortEdgeTriangles=790 circumcenterOutside=370 sharpFixedCorner=1 shortEdges=44 |
| constrained | trowel | 3827 | 7539 | 0 |  | 0.0089 |  | 100.0 | 0 | 0:7124 1:216 2:131 3:53 4:15 | 0.0e+00 | 5.5 |  |  |
| area | trowel | 13925 | 23622 | 10098 | 100.0 | 0.0107 |  | 100.0 | 0 | 0:22982 1:324 2:219 3:82 4:15 | 1.5e-05 | 19.8 |  | none |
| angle | trowel | 24719 | 45010 | 20892 |  | 0.0185 | 99.8 | 100.0 | 0 | 0:43800 1:591 2:427 3:165 4:27 | 4.0e-06 | 51.5 |  | none |
| area_angle | trowel | 25104 | 45769 | 21277 | 100.0 | 0.0185 | 99.8 | 100.0 | 0 | 0:44526 1:607 2:438 3:171 4:27 | 1.5e-05 | 54.5 |  | none |
| constrained | RTriangle | 3827 | 7539 | 0 |  | 0.0089 |  | 100.0 | 0 |  | 0.0e+00 | 7.67 |  |  |
| area | RTriangle | 5343 | 10532 | 1516 | 100.0 | 0.0104 |  | 100.0 | 0 |  | 8.4e-16 | 9.5 |  |  |
| angle | RTriangle | 11342 | 21247 | 7515 |  | 0.0185 | 94.2 | 100.0 | 0 |  | 1.8e-11 | 17 |  |  |
| area_angle | RTriangle | 11819 | 22191 | 7992 | 100.0 | 0.0185 | 94.5 | 100.0 | 0 |  | 1.8e-11 | 18.3 |  |  |

### cad_tas

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | floor | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 1029 | 1974 | 0 |  | 0.0683 |  | 100.0 | 0 | 1:744 2:957 3:267 4:6 | 0.0e+00 | 6.33 |  |  |
| area | laridae | 5166 | 9987 | 4137 | 100.0 | 0.0901 |  | 100.0 | 0 | 1:6564 2:2690 3:714 4:19 | 3.4e-16 | 38 | 3.01 | none |
| angle | laridae | 3310 | 6356 | 2281 |  | 0.0901 | 87.1 | 100.0 | 0 | 1:2814 2:2751 3:767 4:24 | 3.4e-16 | 26 | 3.18 | bad=819 short_edge=811 sharp_corner=40 outside=6 |
| area_angle | laridae | 5951 | 11532 | 4922 | 100.0 | 0.0901 | 93.3 | 100.0 | 0 | 1:7270 2:3311 3:922 4:29 | 3.4e-16 | 47 | 3.01 | bad=772 short_edge=768 sharp_corner=38 outside=6 |
| constrained | cdtr | 1029 | 1974 | 0 |  | 0.0683 |  | 100.0 | 0 | 1:744 2:957 3:267 4:6 | 0.0e+00 | 3.5 |  |  |
| area | cdtr | 5314 | 10275 | 4285 | 100.0 | 0.0901 |  | 100.0 | 0 | 1:6693 2:2821 3:734 4:27 | 3.4e-16 | 22 | 3.01 | shortEdgeTriangles=1 shortEdges=192 |
| angle | cdtr | 3603 | 6915 | 2574 |  | 0.0901 | 85.9 | 100.0 | 0 | 1:3132 2:2956 3:800 4:27 | 3.4e-16 | 17.5 | 3.18 | shortEdgeTriangles=1735 sharpFixedCorner=27 shortEdges=210 |
| area_angle | cdtr | 6212 | 12036 | 5183 | 100.0 | 0.0901 | 92.2 | 100.0 | 0 | 1:7492 2:3555 3:961 4:28 | 3.4e-16 | 29 | 3.01 | shortEdgeTriangles=1271 sharpFixedCorner=27 shortEdges=286 |
| constrained | trowel | 1029 | 1974 | 0 |  | 0.0683 |  | 100.0 | 0 | 1:750 2:951 3:267 4:6 | 0.0e+00 | 2.29 |  |  |
| area | trowel | 5453 | 10522 | 4424 | 100.0 | 0.115 |  | 100.0 | 0 | 1:6827 2:2906 3:762 4:27 | 3.4e-16 | 11 |  | none |
| angle | trowel | 7254 | 14094 | 6225 |  | 1.31 | 99.3 | 100.0 | 0 | 1:5671 2:6369 3:2015 4:39 | 3.4e-16 | 15.5 |  | none |
| area_angle | trowel | 9501 | 18523 | 8472 | 100.0 | 1.31 | 99.5 | 100.0 | 0 | 1:9625 2:6727 3:2134 4:37 | 3.4e-16 | 20 |  | none |
| constrained | RTriangle | 1029 | 1974 | 0 |  | 0.0683 |  | 100.0 | 0 |  | 0.0e+00 | 2.57 |  |  |
| area | RTriangle | 4532 | 8893 | 3503 | 100.0 | 0.0645 |  | 100.0 | 0 |  | 3.0e-15 | 7.67 |  |  |
| angle | RTriangle | 4839 | 9364 | 3810 |  | 1.31 | 99.2 | 100.0 | 0 |  | 7.4e-13 | 8.83 |  |  |
| area_angle | RTriangle | 7371 | 14362 | 6342 | 100.0 | 1.31 | 99.5 | 100.0 | 0 |  | 7.6e-13 | 11.5 |  |  |

