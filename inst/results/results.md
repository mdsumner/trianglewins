# trianglewins results

Run 2026-10-02 01:40 UTC on R version 4.3.3 (2024-02-29), Ubuntu 24.04.4 LTS, 4 cores.

Backends: laridae 0.1.0.9000, cdtr 0.0.0.9000, trowel 0.0.0.9000, RTriangle 1.6.0.15.

Steiner budget for every refinement: 100000. Area bound: bounding box area / 200 (synthetic) or / 5000 (nc, cont_tas, cad_tas). Angle bound: 25 degrees (20 in edit_refine).

## Time (ms, median)

Blank where the backend errored or was skipped; see the per-case tables.

| case | scenario | laridae | cdtr | trowel | RTriangle |
|---|---|---|---|---|---|
| square | constrained | 0.45 | 0.85 | 1.15 | 0.55 |
| square | area | 1.75 | 1.6 | 1.45 | 1.02 |
| square | angle | 1.1 | 1.15 | 1.15 | 0.7 |
| square | area_angle | 1.5 | 2.43 | 1.5 | 0.95 |
| square_hole | constrained | 0.476 | 0.9 | 1.4 | 0.6 |
| square_hole | area | 2 | 2.05 | 1.5 | 1.2 |
| square_hole | angle | 1.33 | 1.27 | 1.27 | 0.85 |
| square_hole | area_angle | 1.8 | 2.57 | 1.4 | 1 |
| nested3 | constrained | 0.615 | 1.1 | 1.14 | 1 |
| nested3 | area | 1.9 | 2 | 1.4 | 0.857 |
| nested3 | angle | 1.43 | 1.45 | 1.25 | 0.619 |
| nested3 | area_angle | 1.73 | 3 | 1.64 | 0.976 |
| grid3_doubled | constrained | 0.667 | 1.27 | 1.14 |  |
| grid3_doubled | area | 1.82 | 2.1 | 1.71 |  |
| grid3_doubled | angle | 1.36 | 1.31 | 1.27 |  |
| grid3_doubled | area_angle | 2 | 2.86 | 1.7 |  |
| grid3_dedup | constrained | 0.476 | 1.05 | 1.21 | 0.619 |
| grid3_dedup | area | 1.8 | 2.3 | 1.64 | 1.02 |
| grid3_dedup | angle | 1.45 | 1.22 | 1.09 | 0.571 |
| grid3_dedup | area_angle | 1.73 | 2.71 | 1.45 | 1.05 |
| crossing_rings | constrained | 0.545 | 1 | 1.18 | 0.881 |
| crossing_rings | area | 1.83 | 1.91 | 1.5 | 0.952 |
| crossing_rings | angle | 1.31 | 1.23 | 1.27 | 0.65 |
| crossing_rings | area_angle | 2.6 | 2.73 | 1.71 | 0.857 |
| crossing_x | constrained | 0.6 | 1.05 | 1.37 | 0.8 |
| crossing_x | area | 2.1 | 1.21 | 1.73 | 1.1 |
| crossing_x | angle | 1.57 | 1.15 | 1.36 | 0.7 |
| crossing_x | area_angle | 1.91 | 1.59 | 1.64 | 1.07 |
| collinear_overlap | constrained | 0.5 | 0.875 | 1.15 | 0.714 |
| collinear_overlap | area | 1.73 | 1.8 | 1.64 | 1.26 |
| collinear_overlap | angle | 1.03 | 0.95 | 1 | 1.15 |
| collinear_overlap | area_angle | 1.65 | 2.27 | 1.64 | 1.09 |
| dangling | constrained | 0.4 | 0.857 | 1 | 0.657 |
| dangling | area | 2.35 | 1.86 | 1.43 | 1.02 |
| dangling | angle | 1.19 | 1.05 | 1.14 | 0.714 |
| dangling | area_angle | 1.6 | 2.14 | 1.57 | 0.857 |
| sharp_corner | constrained | 0.429 | 0.818 | 1.29 | 0.682 |
| sharp_corner | area | 1.29 | 1.36 | 1.73 | 0.667 |
| sharp_corner | angle | 1.2 | 1 | 1.93 | 0.667 |
| sharp_corner | area_angle | 1.45 | 1.8 | 2.14 | 0.66 |
| points_only | constrained | 0.95 | 1.5 | 3.4 | 1.45 |
| points_only | area | 2.18 | 1.86 | 4.38 | 1.55 |
| points_only | angle | 3.2 | 2.29 | 4.9 | 1.67 |
| points_only | area_angle | 2.5 | 2.5 | 3.09 | 1.79 |
| nc | constrained | 3.17 | 3.2 | 4.1 | 3.29 |
| nc | area | 11.5 | 12.5 | 20 | 4.75 |
| nc | angle | 13.5 | 16.8 | 32.5 | 6 |
| nc | area_angle | 19 | 19.7 | 27 | 6.5 |
| nc_rings | constrained | 4.6 | 3.6 | 3 |  |
| nc_rings | area | 13.5 | 14 | 16.5 |  |
| nc_rings | angle | 15.5 | 19.5 | 23 |  |
| nc_rings | area_angle | 19 | 22 | 27 |  |
| cont_tas | constrained | 9 | 7.33 | 6.12 | 9.17 |
| cont_tas | area | 36.5 | 18.7 | 21 | 11 |
| cont_tas | angle | 84 | 31 | 79 | 17.7 |
| cont_tas | area_angle | 72 | 35 | 60 | 19 |
| cad_tas | constrained | 3.2 | 3 | 2.36 | 2.57 |
| cad_tas | area | 24 | 23 | 11.5 | 7.33 |
| cad_tas | angle | 17 | 17.5 | 15 | 8.5 |
| cad_tas | area_angle | 30 | 35 | 22 | 16.5 |
| nc | edit_refine | 5 | 17 | 18 | 6 |

## Depth

Harness depth is computed from the output triangles: crossing an edge costs the number of input segments on it (k) or 1 if there is any (1). `match` says which of the two the backend's own depth equals.

| case | harness k | harness 1 | laridae | cdtr | trowel | RTriangle |
|---|---|---|---|---|---|---|
| square | 1:2 | 1:2 | k=1 | k=1 | k=1 |  |
| square_hole | 1:8 2:2 | 1:8 2:2 | k=1 | k=1 | k=1 |  |
| nested3 | 1:8 2:8 3:2 | 1:8 2:8 3:2 | k=1 | k=1 | k=1 |  |
| grid3_doubled | 1:16 3:2 | 1:16 2:2 | k | k | 1 |  |
| grid3_dedup | 1:16 2:2 | 1:16 2:2 | k=1 | k=1 | k=1 |  |
| crossing_rings | 1:8 2:2 | 1:8 2:2 | k=1 | k=1 | k=1 |  |
| crossing_x | 0:4 | 0:4 | k=1 | k=1 | k=1 |  |
| collinear_overlap | 0:4 | 0:4 | k=1 | k=1 | k=1 |  |
| dangling | 1:8 | 1:8 | k=1 | k=1 | k=1 |  |
| sharp_corner | 1:13 | 1:13 | k=1 | k=1 | k=1 |  |
| points_only | 0:981 | 0:981 | k=1 | k=1 | k=1 |  |
| nc | 1:1205 2:707 3:293 | 1:1205 2:707 3:293 | k=1 | k=1 | k=1 |  |
| nc_rings | 1:1205 3:707 5:293 | 1:1205 2:707 3:293 | k | k | 1 |  |
| cont_tas | 0:7124 1:216 2:131 3:53 4:15 | 0:7124 1:216 2:131 3:53 4:15 | k=1 | k=1 | k=1 |  |
| cad_tas | 1:744 2:957 3:267 4:6 | 1:750 2:951 3:267 4:6 | k | k | 1 |  |

## Errors and skips

| backend | case | scenarios | status | message |
|---|---|---|---|---|
| RTriangle | grid3_doubled | constrained, area, angle, area_angle | error | Duplicated vertices in P. |
| RTriangle | nc_rings | constrained, area, angle, area_angle | error | Duplicated vertices in P. |

## Per case

verts, tris: output counts; added: vertices not in the input; area ok / angle ok: percent of triangles meeting the bound; min ang: smallest angle (degrees); segs: percent of input segments present as chains of edges; CD viol: unconstrained edges failing the empty-circle test; depth: the backend's own depth table (depth:count); attr err: largest relative error of a linear attribute carried onto new vertices; unrefined: what the backend says it could not do.

### square

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 4 | 2 | 0 |  | 45 |  | 100.0 | 0 | 1:2 | 0.0e+00 | 0.45 |  |
| area | laridae | 169 | 288 | 165 | 100.0 | 29.7 |  | 100.0 | 0 | 1:288 | 1.5e-16 | 1.75 | none |
| angle | laridae | 4 | 2 | 0 |  | 45 | 100.0 | 100.0 | 0 | 1:2 | 0.0e+00 | 1.1 | none |
| area_angle | laridae | 169 | 288 | 165 | 100.0 | 29.7 | 100.0 | 100.0 | 0 | 1:288 | 1.5e-16 | 1.5 | none |
| constrained | cdtr | 4 | 2 | 0 |  | 45 |  | 100.0 | 0 | 1:2 | 0.0e+00 | 0.85 |  |
| area | cdtr | 156 | 275 | 152 | 100.0 | 26.6 |  | 100.0 | 0 | 1:275 | 1.5e-16 | 1.6 | none |
| angle | cdtr | 4 | 2 | 0 |  | 45 | 100.0 | 100.0 | 0 | 1:2 | 0.0e+00 | 1.15 | none |
| area_angle | cdtr | 156 | 275 | 152 | 100.0 | 26.6 | 100.0 | 100.0 | 0 | 1:275 | 1.5e-16 | 2.43 | none |
| constrained | trowel | 4 | 2 | 0 |  | 45 |  | 100.0 | 0 | 1:2 | 0.0e+00 | 1.15 |  |
| area | trowel | 167 | 293 | 163 | 100.0 | 31 |  | 100.0 | 0 | 1:293 | 7.4e-17 | 1.45 | none |
| angle | trowel | 4 | 2 | 0 |  | 45 | 100.0 | 100.0 | 0 | 1:2 | 0.0e+00 | 1.15 | none |
| area_angle | trowel | 168 | 295 | 164 | 100.0 | 31 | 100.0 | 100.0 | 0 | 1:295 | 7.4e-17 | 1.5 | none |
| constrained | RTriangle | 4 | 2 | 0 |  | 45 |  | 100.0 | 0 |  | 0.0e+00 | 0.55 |  |
| area | RTriangle | 171 | 314 | 167 | 100.0 | 0.171 |  | 100.0 | 0 |  | 4.4e-16 | 1.02 |  |
| angle | RTriangle | 4 | 2 | 0 |  | 45 | 100.0 | 100.0 | 0 |  | 0.0e+00 | 0.7 |  |
| area_angle | RTriangle | 180 | 322 | 176 | 100.0 | 25.8 | 100.0 | 100.0 | 0 |  | 4.4e-16 | 0.95 |  |

### square_hole

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 8 | 10 | 0 |  | 18.4 |  | 100.0 | 0 | 1:8 2:2 | 0.0e+00 | 0.476 |  |
| area | laridae | 186 | 317 | 178 | 100.0 | 27.4 |  | 100.0 | 0 | 1:237 2:80 | 1.5e-16 | 2 | none |
| angle | laridae | 24 | 30 | 16 |  | 45 | 100.0 | 100.0 | 0 | 1:24 2:6 | 0.0e+00 | 1.33 | none |
| area_angle | laridae | 186 | 317 | 178 | 100.0 | 27.4 | 100.0 | 100.0 | 0 | 1:237 2:80 | 1.5e-16 | 1.8 | none |
| constrained | cdtr | 8 | 10 | 0 |  | 18.4 |  | 100.0 | 0 | 1:8 2:2 | 0.0e+00 | 0.9 |  |
| area | cdtr | 152 | 268 | 144 | 100.0 | 26.6 |  | 100.0 | 0 | 1:202 2:66 | 0.0e+00 | 2.05 | none |
| angle | cdtr | 12 | 14 | 4 |  | 45 | 100.0 | 100.0 | 0 | 1:12 2:2 | 0.0e+00 | 1.27 | none |
| area_angle | cdtr | 152 | 268 | 144 | 100.0 | 26.6 | 100.0 | 100.0 | 0 | 1:202 2:66 | 0.0e+00 | 2.57 | none |
| constrained | trowel | 8 | 10 | 0 |  | 18.4 |  | 100.0 | 0 | 1:8 2:2 | 0.0e+00 | 1.4 |  |
| area | trowel | 155 | 274 | 147 | 100.0 | 26.6 |  | 100.0 | 0 | 1:201 2:73 | 7.4e-17 | 1.5 | none |
| angle | trowel | 12 | 14 | 4 |  | 45 | 100.0 | 100.0 | 0 | 1:12 2:2 | 0.0e+00 | 1.27 | none |
| area_angle | trowel | 155 | 274 | 147 | 100.0 | 26.6 | 100.0 | 100.0 | 0 | 1:201 2:73 | 7.4e-17 | 1.4 | none |
| constrained | RTriangle | 8 | 10 | 0 |  | 18.4 |  | 100.0 | 0 |  | 0.0e+00 | 0.6 |  |
| area | RTriangle | 174 | 320 | 166 | 100.0 | 1.06 |  | 100.0 | 0 |  | 1.5e-16 | 1.2 |  |
| angle | RTriangle | 12 | 14 | 4 |  | 45 | 100.0 | 100.0 | 0 |  | 0.0e+00 | 0.85 |  |
| area_angle | RTriangle | 175 | 313 | 167 | 100.0 | 26.1 | 100.0 | 100.0 | 0 |  | 3.0e-16 | 1 |  |

### nested3

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 12 | 18 | 0 |  | 14 |  | 100.0 | 0 | 1:8 2:8 3:2 | 0.0e+00 | 0.615 |  |
| area | laridae | 179 | 308 | 167 | 100.0 | 26.6 |  | 100.0 | 0 | 1:184 2:107 3:17 | 3.0e-16 | 1.9 | none |
| angle | laridae | 28 | 38 | 16 |  | 38.7 | 100.0 | 100.0 | 0 | 1:24 2:12 3:2 | 1.5e-16 | 1.43 | none |
| area_angle | laridae | 179 | 308 | 167 | 100.0 | 26.6 | 100.0 | 100.0 | 0 | 1:184 2:107 3:17 | 3.0e-16 | 1.73 | none |
| constrained | cdtr | 12 | 18 | 0 |  | 14 |  | 100.0 | 0 | 1:8 2:8 3:2 | 0.0e+00 | 1.1 |  |
| area | cdtr | 190 | 326 | 178 | 100.0 | 5.98 |  | 100.0 | 0 | 1:205 2:106 3:15 | 1.5e-16 | 2 | shortEdges=2 |
| angle | cdtr | 28 | 38 | 16 |  | 38.7 | 100.0 | 100.0 | 0 | 1:24 2:12 3:2 | 7.4e-17 | 1.45 | none |
| area_angle | cdtr | 194 | 334 | 182 | 99.7 | 10.5 | 98.8 | 100.0 | 0 | 1:209 2:110 3:15 | 1.5e-16 | 3 | shortEdgeTriangles=9 shortEdges=2 |
| constrained | trowel | 12 | 18 | 0 |  | 14 |  | 100.0 | 0 | 1:8 2:8 3:2 | 0.0e+00 | 1.14 |  |
| area | trowel | 202 | 350 | 190 | 100.0 | 20.6 |  | 100.0 | 0 | 1:210 2:121 3:19 | 1.5e-16 | 1.4 | none |
| angle | trowel | 28 | 38 | 16 |  | 38.7 | 100.0 | 100.0 | 0 | 1:24 2:12 3:2 | 7.4e-17 | 1.25 | none |
| area_angle | trowel | 207 | 359 | 195 | 100.0 | 27.2 | 100.0 | 100.0 | 0 | 1:216 2:120 3:23 | 1.5e-16 | 1.64 | none |
| constrained | RTriangle | 12 | 18 | 0 |  | 14 |  | 100.0 | 0 |  | 0.0e+00 | 1 |  |
| area | RTriangle | 176 | 328 | 164 | 100.0 | 0.622 |  | 100.0 | 0 |  | 1.5e-16 | 0.857 |  |
| angle | RTriangle | 20 | 30 | 8 |  | 33.7 | 100.0 | 100.0 | 0 |  | 7.4e-17 | 0.619 |  |
| area_angle | RTriangle | 179 | 323 | 167 | 100.0 | 25.4 | 100.0 | 100.0 | 0 |  | 1.5e-16 | 0.976 |  |

### grid3_doubled

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 16 | 18 | 0 |  | 45 |  | 100.0 | 0 | 1:16 3:2 | 0.0e+00 | 0.667 |  |
| area | laridae | 169 | 288 | 153 | 100.0 | 40.1 |  | 100.0 | 0 | 1:256 3:32 | 9.9e-17 | 1.82 | none |
| angle | laridae | 16 | 18 | 0 |  | 45 | 100.0 | 100.0 | 0 | 1:16 3:2 | 0.0e+00 | 1.36 | none |
| area_angle | laridae | 169 | 288 | 153 | 100.0 | 40.1 | 100.0 | 100.0 | 0 | 1:256 3:32 | 9.9e-17 | 2 | none |
| constrained | cdtr | 16 | 18 | 0 |  | 45 |  | 100.0 | 0 | 1:16 3:2 | 0.0e+00 | 1.27 |  |
| area | cdtr | 174 | 298 | 158 | 100.0 | 31 |  | 100.0 | 0 | 1:264 3:34 | 9.9e-17 | 2.1 | none |
| angle | cdtr | 16 | 18 | 0 |  | 45 | 100.0 | 100.0 | 0 | 1:16 3:2 | 0.0e+00 | 1.31 | none |
| area_angle | cdtr | 174 | 298 | 158 | 100.0 | 31 | 100.0 | 100.0 | 0 | 1:264 3:34 | 9.9e-17 | 2.86 | none |
| constrained | trowel | 16 | 18 | 0 |  | 45 |  | 100.0 | 0 | 1:16 2:2 | 0.0e+00 | 1.14 |  |
| area | trowel | 176 | 302 | 160 | 100.0 | 31 |  | 100.0 | 0 | 1:268 2:34 | 9.9e-17 | 1.71 | none |
| angle | trowel | 16 | 18 | 0 |  | 45 | 100.0 | 100.0 | 0 | 1:16 2:2 | 0.0e+00 | 1.27 | none |
| area_angle | trowel | 176 | 302 | 160 | 100.0 | 31 | 100.0 | 100.0 | 0 | 1:268 2:34 | 9.9e-17 | 1.7 | none |

### grid3_dedup

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 16 | 18 | 0 |  | 45 |  | 100.0 | 0 | 1:16 2:2 | 0.0e+00 | 0.476 |  |
| area | laridae | 169 | 288 | 153 | 100.0 | 36.9 |  | 100.0 | 0 | 1:256 2:32 | 9.9e-17 | 1.8 | none |
| angle | laridae | 16 | 18 | 0 |  | 45 | 100.0 | 100.0 | 0 | 1:16 2:2 | 0.0e+00 | 1.45 | none |
| area_angle | laridae | 169 | 288 | 153 | 100.0 | 36.9 | 100.0 | 100.0 | 0 | 1:256 2:32 | 9.9e-17 | 1.73 | none |
| constrained | cdtr | 16 | 18 | 0 |  | 45 |  | 100.0 | 0 | 1:16 2:2 | 0.0e+00 | 1.05 |  |
| area | cdtr | 174 | 298 | 158 | 100.0 | 31 |  | 100.0 | 0 | 1:264 2:34 | 9.9e-17 | 2.3 | none |
| angle | cdtr | 16 | 18 | 0 |  | 45 | 100.0 | 100.0 | 0 | 1:16 2:2 | 0.0e+00 | 1.22 | none |
| area_angle | cdtr | 174 | 298 | 158 | 100.0 | 31 | 100.0 | 100.0 | 0 | 1:264 2:34 | 9.9e-17 | 2.71 | none |
| constrained | trowel | 16 | 18 | 0 |  | 45 |  | 100.0 | 0 | 1:16 2:2 | 0.0e+00 | 1.21 |  |
| area | trowel | 176 | 302 | 160 | 100.0 | 31 |  | 100.0 | 0 | 1:268 2:34 | 9.9e-17 | 1.64 | none |
| angle | trowel | 16 | 18 | 0 |  | 45 | 100.0 | 100.0 | 0 | 1:16 2:2 | 0.0e+00 | 1.09 | none |
| area_angle | trowel | 176 | 302 | 160 | 100.0 | 31 | 100.0 | 100.0 | 0 | 1:268 2:34 | 9.9e-17 | 1.45 | none |
| constrained | RTriangle | 16 | 18 | 0 |  | 45 |  | 100.0 | 0 |  | 0.0e+00 | 0.619 |  |
| area | RTriangle | 175 | 320 | 159 | 100.0 | 0.0775 |  | 100.0 | 0 |  | 2.0e-16 | 1.02 |  |
| angle | RTriangle | 16 | 18 | 0 |  | 45 | 100.0 | 100.0 | 0 |  | 0.0e+00 | 0.571 |  |
| area_angle | RTriangle | 168 | 301 | 152 | 100.0 | 25.6 | 100.0 | 100.0 | 0 |  | 2.0e-16 | 1.05 |  |

### crossing_rings

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 10 | 10 | 2 |  | 45 |  | 100.0 | 0 | 1:8 2:2 | 0.0e+00 | 0.545 |  |
| area | laridae | 143 | 236 | 135 | 100.0 | 32.3 |  | 100.0 | 0 | 1:204 2:32 | 9.9e-17 | 1.83 | none |
| angle | laridae | 14 | 14 | 6 |  | 45 | 100.0 | 100.0 | 0 | 1:12 2:2 | 0.0e+00 | 1.31 | none |
| area_angle | laridae | 143 | 236 | 135 | 100.0 | 32.3 | 100.0 | 100.0 | 0 | 1:204 2:32 | 9.9e-17 | 2.6 | none |
| constrained | cdtr | 10 | 10 | 2 |  | 45 |  | 100.0 | 0 | 1:8 2:2 | 0.0e+00 | 1 |  |
| area | cdtr | 139 | 228 | 131 | 100.0 | 33.7 |  | 100.0 | 0 | 1:196 2:32 | 0.0e+00 | 1.91 | none |
| angle | cdtr | 10 | 10 | 2 |  | 45 | 100.0 | 100.0 | 0 | 1:8 2:2 | 0.0e+00 | 1.23 | none |
| area_angle | cdtr | 139 | 228 | 131 | 100.0 | 33.7 | 100.0 | 100.0 | 0 | 1:196 2:32 | 0.0e+00 | 2.73 | none |
| constrained | trowel | 10 | 10 | 2 |  | 45 |  | 100.0 | 0 | 1:8 2:2 | 0.0e+00 | 1.18 |  |
| area | trowel | 143 | 236 | 135 | 100.0 | 30.6 |  | 100.0 | 0 | 1:204 2:32 | 9.9e-17 | 1.5 | none |
| angle | trowel | 10 | 10 | 2 |  | 45 | 100.0 | 100.0 | 0 | 1:8 2:2 | 0.0e+00 | 1.27 | none |
| area_angle | trowel | 143 | 236 | 135 | 100.0 | 30.6 | 100.0 | 100.0 | 0 | 1:204 2:32 | 9.9e-17 | 1.71 | none |
| constrained | RTriangle | 10 | 10 | 2 |  | 45 |  | 100.0 | 0 |  | 0.0e+00 | 0.881 |  |
| area | RTriangle | 144 | 259 | 136 | 100.0 | 0.0306 |  | 100.0 | 0 |  | 2.0e-16 | 0.952 |  |
| angle | RTriangle | 10 | 10 | 2 |  | 45 | 100.0 | 100.0 | 0 |  | 0.0e+00 | 0.65 |  |
| area_angle | RTriangle | 136 | 231 | 128 | 100.0 | 26.1 | 100.0 | 100.0 | 0 |  | 2.0e-16 | 0.857 |  |

### crossing_x

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 5 | 4 | 1 |  | 45 |  | 100.0 | 0 | 0:4 | 0.0e+00 | 0.6 |  |
| area | laridae | 177 | 304 | 173 | 100.0 | 28.7 |  | 100.0 | 0 | 0:304 | 1.5e-16 | 2.1 | none |
| angle | laridae | 21 | 24 | 17 |  | 28.7 | 100.0 | 100.0 | 0 | 0:24 | 7.4e-17 | 1.57 | none |
| area_angle | laridae | 177 | 304 | 173 | 100.0 | 28.7 | 100.0 | 100.0 | 0 | 0:304 | 1.5e-16 | 1.91 | none |
| constrained | cdtr | 5 | 4 | 1 |  | 45 |  | 100.0 | 0 | 0:4 | 0.0e+00 | 1.05 |  |
| area | cdtr | 5 | 4 | 1 | 0.0 | 45 |  | 100.0 | 0 | 0:4 | 0.0e+00 | 1.21 | circumcenterOutside=4 |
| angle | cdtr | 5 | 4 | 1 |  | 45 | 100.0 | 100.0 | 0 | 0:4 | 0.0e+00 | 1.15 | none |
| area_angle | cdtr | 5 | 4 | 1 | 0.0 | 45 | 100.0 | 100.0 | 0 | 0:4 | 0.0e+00 | 1.59 | circumcenterOutside=4 |
| constrained | trowel | 5 | 4 | 1 |  | 45 |  | 100.0 | 0 | 0:4 | 0.0e+00 | 1.37 |  |
| area | trowel | 173 | 301 | 169 | 100.0 | 21.6 |  | 100.0 | 0 | 0:301 | 1.5e-16 | 1.73 | none |
| angle | trowel | 5 | 4 | 1 |  | 45 | 100.0 | 100.0 | 0 | 0:4 | 0.0e+00 | 1.36 | none |
| area_angle | trowel | 178 | 311 | 174 | 100.0 | 26.3 | 100.0 | 100.0 | 0 | 0:311 | 1.5e-16 | 1.64 | none |
| constrained | RTriangle | 5 | 4 | 1 |  | 45 |  | 100.0 | 0 |  | 0.0e+00 | 0.8 |  |
| area | RTriangle | 178 | 325 | 174 | 100.0 | 1.43 |  | 100.0 | 0 |  | 3.0e-16 | 1.1 |  |
| angle | RTriangle | 5 | 4 | 1 |  | 45 | 100.0 | 100.0 | 0 |  | 0.0e+00 | 0.7 |  |
| area_angle | RTriangle | 182 | 324 | 178 | 100.0 | 25.9 | 100.0 | 100.0 | 0 |  | 1.5e-16 | 1.07 |  |

### collinear_overlap

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 6 | 4 | 0 |  | 18.4 |  | 100.0 | 0 | 0:4 | 0.0e+00 | 0.5 |  |
| area | laridae | 184 | 309 | 178 | 100.0 | 30.4 |  | 100.0 | 0 | 0:309 | 1.8e-16 | 1.73 | none |
| angle | laridae | 7 | 5 | 1 |  | 45 | 100.0 | 100.0 | 0 | 0:5 | 0.0e+00 | 1.03 | none |
| area_angle | laridae | 184 | 309 | 178 | 100.0 | 30.4 | 100.0 | 100.0 | 0 | 0:309 | 1.8e-16 | 1.65 | none |
| constrained | cdtr | 6 | 4 | 0 |  | 18.4 |  | 100.0 | 0 | 0:4 | 0.0e+00 | 0.875 |  |
| area | cdtr | 176 | 300 | 170 | 98.0 | 4.09 |  | 100.0 | 0 | 0:300 | 1.8e-16 | 1.8 | circumcenterOutside=15 |
| angle | cdtr | 7 | 5 | 1 |  | 45 | 100.0 | 100.0 | 0 | 0:5 | 0.0e+00 | 0.95 | none |
| area_angle | cdtr | 180 | 308 | 174 | 97.7 | 0.25 | 97.4 | 100.0 | 0 | 0:308 | 1.8e-16 | 2.27 | circumcenterOutside=28 |
| constrained | trowel | 6 | 4 | 0 |  | 18.4 |  | 100.0 | 0 | 0:4 | 0.0e+00 | 1.15 |  |
| area | trowel | 198 | 330 | 192 | 100.0 | 29 |  | 100.0 | 0 | 0:330 | 1.8e-16 | 1.64 | none |
| angle | trowel | 7 | 5 | 1 |  | 45 | 100.0 | 100.0 | 0 | 0:5 | 0.0e+00 | 1 | none |
| area_angle | trowel | 198 | 330 | 192 | 100.0 | 29 | 100.0 | 100.0 | 0 | 0:330 | 1.8e-16 | 1.64 | none |
| constrained | RTriangle | 6 | 4 | 0 |  | 18.4 |  | 100.0 | 0 |  | 0.0e+00 | 0.714 |  |
| area | RTriangle | 175 | 315 | 169 | 100.0 | 4.48 |  | 100.0 | 0 |  | 1.8e-16 | 1.26 |  |
| angle | RTriangle | 7 | 5 | 1 |  | 45 | 100.0 | 100.0 | 0 |  | 0.0e+00 | 1.15 |  |
| area_angle | RTriangle | 180 | 312 | 174 | 100.0 | 25.8 | 100.0 | 100.0 | 0 |  | 5.3e-16 | 1.09 |  |

### dangling

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 7 | 8 | 0 |  | 11.3 |  | 100.0 | 0 | 1:8 | 0.0e+00 | 0.4 |  |
| area | laridae | 188 | 320 | 181 | 100.0 | 29.6 |  | 100.0 | 0 | 1:320 | 1.5e-16 | 2.35 | none |
| angle | laridae | 10 | 11 | 3 |  | 11.3 | 45.5 | 100.0 | 0 | 1:11 | 0.0e+00 | 1.19 | bad=6 shortEdges=6 |
| area_angle | laridae | 188 | 320 | 181 | 100.0 | 29.6 | 100.0 | 100.0 | 0 | 1:320 | 1.5e-16 | 1.6 | none |
| constrained | cdtr | 7 | 8 | 0 |  | 11.3 |  | 100.0 | 0 | 1:8 | 0.0e+00 | 0.857 |  |
| area | cdtr | 183 | 318 | 176 | 100.0 | 28.3 |  | 100.0 | 0 | 1:318 | 3.0e-16 | 1.86 | none |
| angle | cdtr | 10 | 11 | 3 |  | 11.3 | 45.5 | 100.0 | 0 | 1:11 | 0.0e+00 | 1.05 | shortEdgeTriangles=6 |
| area_angle | cdtr | 183 | 318 | 176 | 100.0 | 28.3 | 100.0 | 100.0 | 0 | 1:318 | 3.0e-16 | 2.14 | none |
| constrained | trowel | 7 | 8 | 0 |  | 11.3 |  | 100.0 | 0 | 1:8 | 0.0e+00 | 1 |  |
| area | trowel | 182 | 315 | 175 | 100.0 | 23.8 |  | 100.0 | 0 | 1:315 | 1.5e-16 | 1.43 | none |
| angle | trowel | 25 | 32 | 18 |  | 26.6 | 100.0 | 100.0 | 0 | 1:32 | 1.5e-16 | 1.14 | none |
| area_angle | trowel | 183 | 317 | 176 | 100.0 | 26.6 | 100.0 | 100.0 | 0 | 1:317 | 1.5e-16 | 1.57 | none |
| constrained | RTriangle | 7 | 8 | 0 |  | 11.3 |  | 100.0 | 0 |  | 0.0e+00 | 0.657 |  |
| area | RTriangle | 173 | 320 | 166 | 100.0 | 1.08 |  | 100.0 | 0 |  | 1.5e-16 | 1.02 |  |
| angle | RTriangle | 23 | 29 | 16 |  | 25.8 | 100.0 | 100.0 | 0 |  | 1.5e-16 | 0.714 |  |
| area_angle | RTriangle | 178 | 319 | 171 | 100.0 | 26.6 | 100.0 | 100.0 | 0 |  | 5.2e-16 | 0.857 |  |

### sharp_corner

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 17 | 13 | 0 |  | 1 |  | 100.0 | 0 | 1:13 | 0.0e+00 | 0.429 |  |
| area | laridae | 51 | 51 | 34 | 100.0 | 1 |  | 100.0 | 0 | 1:51 | 1.2e-16 | 1.29 | none |
| angle | laridae | 19 | 15 | 2 |  | 1 | 80.0 | 100.0 | 0 | 1:15 | 0.0e+00 | 1.2 | bad=3 shortEdges=3 sharpFixedCorner=1 |
| area_angle | laridae | 51 | 51 | 34 | 100.0 | 1 | 94.1 | 100.0 | 0 | 1:51 | 1.2e-16 | 1.45 | bad=3 shortEdges=3 sharpFixedCorner=1 |
| constrained | cdtr | 17 | 13 | 0 |  | 1 |  | 100.0 | 0 | 1:13 | 0.0e+00 | 0.818 |  |
| area | cdtr | 49 | 49 | 32 | 100.0 | 1 |  | 100.0 | 0 | 1:49 | 6.2e-17 | 1.36 | none |
| angle | cdtr | 17 | 13 | 0 |  | 1 | 92.3 | 100.0 | 0 | 1:13 | 0.0e+00 | 1 | sharpFixedCorner=1 |
| area_angle | cdtr | 49 | 49 | 32 | 100.0 | 1 | 98.0 | 100.0 | 0 | 1:49 | 6.2e-17 | 1.8 | sharpFixedCorner=1 |
| constrained | trowel | 17 | 13 | 0 |  | 1 |  | 100.0 | 0 | 1:13 | 0.0e+00 | 1.29 |  |
| area | trowel | 75 | 75 | 58 | 100.0 | 1 |  | 100.0 | 0 | 1:75 | 1.2e-16 | 1.73 | none |
| angle | trowel | 29 | 25 | 12 |  | 1 | 64.0 | 100.0 | 0 | 1:25 | 1.2e-16 | 1.93 | none |
| area_angle | trowel | 88 | 95 | 71 | 100.0 | 1 | 76.8 | 100.0 | 0 | 1:95 | 1.2e-16 | 2.14 | none |
| constrained | RTriangle | 17 | 13 | 0 |  | 1 |  | 100.0 | 0 |  | 0.0e+00 | 0.682 |  |
| area | RTriangle | 35 | 49 | 18 | 100.0 | 1 |  | 100.0 | 0 |  | 6.2e-17 | 0.667 |  |
| angle | RTriangle | 27 | 23 | 10 |  | 1 | 69.6 | 100.0 | 0 |  | 1.2e-16 | 0.667 |  |
| area_angle | RTriangle | 52 | 59 | 35 | 100.0 | 1 | 88.1 | 100.0 | 0 |  | 1.2e-16 | 0.66 |  |

### points_only

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 500 | 981 | 0 |  | 0.138 |  |  | 0 | 0:981 | 0.0e+00 | 0.95 |  |
| area | laridae | 644 | 1125 | 144 | 100.0 | 4.02 |  |  | 0 | 0:1125 | 1.1e-16 | 2.18 | none |
| angle | laridae | 905 | 1603 | 405 |  | 25 | 100.0 |  | 0 | 0:1603 | 1.5e-16 | 3.2 | none |
| area_angle | laridae | 659 | 1152 | 159 | 100.0 | 4.31 | 92.5 |  | 0 | 0:1152 | 1.1e-16 | 2.5 | bad=86 shortEdges=86 |
| constrained | cdtr | 500 | 981 | 0 |  | 0.138 |  |  | 0 | 0:981 | 0.0e+00 | 1.5 |  |
| area | cdtr | 500 | 981 | 0 | 100.0 | 0.138 |  |  | 0 | 0:981 | 0.0e+00 | 1.86 | none |
| angle | cdtr | 501 | 983 | 1 |  | 0.138 | 94.9 |  | 0 | 0:983 | 1.5e-16 | 2.29 | circumcenterOutside=52 |
| area_angle | cdtr | 501 | 983 | 1 | 100.0 | 0.138 | 94.9 |  | 0 | 0:983 | 1.5e-16 | 2.5 | circumcenterOutside=52 |
| constrained | trowel | 500 | 981 | 0 |  | 0.138 |  |  | 0 | 0:981 | 0.0e+00 | 3.4 |  |
| area | trowel | 646 | 1127 | 146 | 100.0 | 4.31 |  |  | 0 | 0:1127 | 3.7e-02 | 4.38 | none |
| angle | trowel | 949 | 1662 | 449 |  | 25 | 100.0 |  | 0 | 0:1662 | 3.7e-02 | 4.9 | none |
| area_angle | trowel | 949 | 1662 | 449 | 100.0 | 25 | 100.0 |  | 0 | 0:1662 | 3.7e-02 | 3.09 | none |
| constrained | RTriangle | 500 | 981 | 0 |  | 0.138 |  |  | 0 |  | 0.0e+00 | 1.45 |  |
| area | RTriangle | 500 | 981 | 0 | 100.0 | 0.138 |  |  | 0 |  | 0.0e+00 | 1.55 |  |
| angle | RTriangle | 792 | 1429 | 292 |  | 25 | 100.0 |  | 0 |  | 4.6e-16 | 1.67 |  |
| area_angle | RTriangle | 792 | 1429 | 292 | 100.0 | 25 | 100.0 |  | 0 |  | 4.6e-16 | 1.79 |  |

### nc

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 1255 | 2205 | 0 |  | 0.774 |  | 100.0 | 0 | 1:1205 2:707 3:293 | 0.0e+00 | 3.17 |  |
| area | laridae | 2967 | 5308 | 1712 | 100.0 | 3.42 |  | 100.0 | 0 | 1:2857 2:1685 3:766 | 1.1e-17 | 11.5 | none |
| angle | laridae | 3577 | 6487 | 2322 |  | 2.1 | 98.4 | 100.0 | 0 | 1:3564 2:2045 3:878 | 1.1e-17 | 13.5 | bad=106 shortEdges=104 sharpFixedCorner=8 |
| area_angle | laridae | 4109 | 7514 | 2854 | 100.0 | 3.52 | 98.6 | 100.0 | 0 | 1:4053 2:2407 3:1054 | 1.1e-17 | 19 | bad=107 shortEdges=105 sharpFixedCorner=9 |
| edit_refine | laridae | 3481 | 6304 | 2224 | 100.0 | 2.58 | 98.4 | 100.0 | 0 | 1:3395 2:2005 3:904 |  | 5 |  |
| constrained | cdtr | 1255 | 2205 | 0 |  | 0.774 |  | 100.0 | 0 | 1:1205 2:707 3:293 | 0.0e+00 | 3.2 |  |
| area | cdtr | 3097 | 5460 | 1842 | 100.0 | 3.52 |  | 100.0 | 0 | 1:2976 2:1705 3:779 | 1.1e-17 | 12.5 | shortEdges=36 |
| angle | cdtr | 3778 | 6804 | 2523 |  | 3.52 | 98.0 | 100.0 | 0 | 1:3770 2:2091 3:943 | 1.1e-17 | 16.8 | shortEdgeTriangles=235 sharpFixedCorner=5 shortEdges=35 |
| area_angle | cdtr | 4309 | 7822 | 3054 | 100.0 | 3.52 | 98.2 | 100.0 | 0 | 1:4322 2:2417 3:1083 | 1.1e-17 | 19.7 | shortEdgeTriangles=201 sharpFixedCorner=5 shortEdges=61 |
| edit_refine | cdtr | 3635 | 6519 | 2378 | 100.0 | 3.52 | 98.2 | 100.0 | 0 | 1:3564 2:2036 3:919 |  | 17 |  |
| constrained | trowel | 1255 | 2205 | 0 |  | 0.774 |  | 100.0 | 0 | 1:1205 2:707 3:293 | 0.0e+00 | 4.1 |  |
| area | trowel | 3864 | 6257 | 2609 | 100.0 | 0.225 |  | 100.0 | 0 | 1:3739 2:1725 3:793 | 1.7e-03 | 20 | none |
| angle | trowel | 6440 | 11232 | 5185 |  | 3.51 | 99.8 | 100.0 | 0 | 1:7424 2:2590 3:1218 | 1.7e-03 | 32.5 | none |
| area_angle | trowel | 6831 | 11988 | 5576 | 100.0 | 3.51 | 99.8 | 100.0 | 0 | 1:7748 2:2922 3:1318 | 1.7e-03 | 27 | none |
| edit_refine | trowel | 5555 | 9406 | 4298 | 100.0 | 3.52 | 99.9 | 100.0 | 0 | 1:6171 2:2227 3:1008 |  | 18 |  |
| constrained | RTriangle | 1255 | 2205 | 0 |  | 0.774 |  | 100.0 | 0 |  | 0.0e+00 | 3.29 |  |
| area | RTriangle | 2716 | 5067 | 1461 | 100.0 | 0.154 |  | 100.0 | 0 |  | 1.7e-16 | 4.75 |  |
| angle | RTriangle | 3089 | 5613 | 1834 |  | 3.52 | 99.9 | 100.0 | 0 |  | 1.6e-15 | 6 |  |
| area_angle | RTriangle | 3710 | 6824 | 2455 | 100.0 | 3.52 | 99.9 | 100.0 | 0 |  | 1.6e-15 | 6.5 |  |
| edit_refine | RTriangle | 3299 | 6055 | 2042 | 100.0 | 3.52 | 99.9 | 100.0 | 0 |  |  | 6 |  |

### nc_rings

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 1255 | 2205 | 0 |  | 0.774 |  | 100.0 | 0 | 1:1205 3:707 5:293 | 0.0e+00 | 4.6 |  |
| area | laridae | 2967 | 5308 | 1712 | 100.0 | 3.42 |  | 100.0 | 0 | 1:2857 3:1685 5:766 | 1.1e-17 | 13.5 | none |
| angle | laridae | 3628 | 6582 | 2373 |  | 2.1 | 98.5 | 100.0 | 0 | 1:3581 3:2070 5:931 | 1.1e-17 | 15.5 | bad=100 shortEdges=97 sharpFixedCorner=8 |
| area_angle | laridae | 4156 | 7601 | 2901 | 100.0 | 3.52 | 98.7 | 100.0 | 0 | 1:4069 3:2427 5:1105 | 1.1e-17 | 19 | bad=100 shortEdges=97 sharpFixedCorner=9 |
| constrained | cdtr | 1255 | 2205 | 0 |  | 0.774 |  | 100.0 | 0 | 1:1205 3:707 5:293 | 0.0e+00 | 3.6 |  |
| area | cdtr | 3105 | 5469 | 1850 | 100.0 | 3.52 |  | 100.0 | 0 | 1:2984 3:1706 5:779 | 1.1e-17 | 14 | shortEdges=27 |
| angle | cdtr | 3849 | 6935 | 2594 |  | 3.52 | 98.2 | 100.0 | 0 | 1:3793 3:2124 5:1018 | 1.1e-17 | 19.5 | shortEdgeTriangles=220 sharpFixedCorner=5 shortEdges=27 |
| area_angle | cdtr | 4366 | 7925 | 3111 | 100.0 | 3.52 | 98.4 | 100.0 | 0 | 1:4339 3:2439 5:1147 | 1.1e-17 | 22 | shortEdgeTriangles=194 sharpFixedCorner=5 shortEdges=47 |
| constrained | trowel | 1255 | 2205 | 0 |  | 0.774 |  | 100.0 | 0 | 1:1205 2:707 3:293 | 0.0e+00 | 3 |  |
| area | trowel | 3863 | 6255 | 2608 | 100.0 | 0.225 |  | 100.0 | 0 | 1:3737 2:1726 3:792 | 1.7e-03 | 16.5 | none |
| angle | trowel | 6441 | 11234 | 5186 |  | 3.51 | 99.8 | 100.0 | 0 | 1:7424 2:2591 3:1219 | 1.7e-03 | 23 | none |
| area_angle | trowel | 6825 | 11976 | 5570 | 100.0 | 3.51 | 99.8 | 100.0 | 0 | 1:7747 2:2913 3:1316 | 1.7e-03 | 27 | none |

### cont_tas

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 3827 | 7539 | 0 |  | 0.0089 |  | 100.0 | 0 | 0:7124 1:216 2:131 3:53 4:15 | 0.0e+00 | 9 |  |
| area | laridae | 11488 | 22550 | 7661 | 100.0 | 0 |  | 100.0 | 0 | 0:21909 1:331 2:219 3:76 4:15 | 4.0e-06 | 36.5 | none |
| angle | laridae | 13300 | 26143 | 9473 |  | 0 | 76.1 | 100.0 | 0 | 0:25212 1:464 2:312 3:128 4:27 | 4.0e-06 | 84 | bad=3597 shortEdges=3595 sharpFixedCorner=23 |
| area_angle | laridae | 13773 | 27068 | 9946 | 100.0 | 0 | 76.9 | 100.0 | 0 | 0:26078 1:498 2:336 3:129 4:27 | 4.0e-06 | 72 | bad=3597 shortEdges=3595 sharpFixedCorner=24 |
| constrained | cdtr | 3827 | 7539 | 0 |  | 0.0089 |  | 100.0 | 0 | 0:7124 1:216 2:131 3:53 4:15 | 0.0e+00 | 7.33 |  |
| area | cdtr | 5835 | 11555 | 2008 | 99.7 | 0.00609 |  | 100.0 | 0 | 0:10915 1:329 2:218 3:78 4:15 | 3.4e-16 | 18.7 | circumcenterOutside=69 shortEdges=30 |
| angle | cdtr | 7755 | 15395 | 3928 |  | 0.00609 | 95.6 | 100.0 | 0 | 0:14416 1:499 2:320 3:128 4:32 | 3.4e-16 | 31 | shortEdgeTriangles=905 circumcenterOutside=349 sharpFixedCorner=1 shortEdges=32 |
| area_angle | cdtr | 8089 | 16063 | 4262 | 99.7 | 0.00609 | 95.7 | 100.0 | 0 | 0:15059 1:502 2:339 3:131 4:32 | 3.4e-16 | 35 | shortEdgeTriangles=790 circumcenterOutside=370 sharpFixedCorner=1 shortEdges=44 |
| constrained | trowel | 3827 | 7539 | 0 |  | 0.0089 |  | 100.0 | 0 | 0:7124 1:216 2:131 3:53 4:15 | 0.0e+00 | 6.12 |  |
| area | trowel | 13925 | 23622 | 10098 | 100.0 | 0.0107 |  | 100.0 | 0 | 0:22982 1:324 2:219 3:82 4:15 | 1.5e-05 | 21 | none |
| angle | trowel | 24719 | 45010 | 20892 |  | 0.0185 | 99.8 | 100.0 | 0 | 0:43800 1:591 2:427 3:165 4:27 | 4.0e-06 | 79 | none |
| area_angle | trowel | 25104 | 45769 | 21277 | 100.0 | 0.0185 | 99.8 | 100.0 | 0 | 0:44526 1:607 2:438 3:171 4:27 | 1.5e-05 | 60 | none |
| constrained | RTriangle | 3827 | 7539 | 0 |  | 0.0089 |  | 100.0 | 0 |  | 0.0e+00 | 9.17 |  |
| area | RTriangle | 5343 | 10532 | 1516 | 100.0 | 0.0104 |  | 100.0 | 0 |  | 8.4e-16 | 11 |  |
| angle | RTriangle | 11342 | 21247 | 7515 |  | 0.0185 | 94.2 | 100.0 | 0 |  | 1.8e-11 | 17.7 |  |
| area_angle | RTriangle | 11819 | 22191 | 7992 | 100.0 | 0.0185 | 94.5 | 100.0 | 0 |  | 1.8e-11 | 19 |  |

### cad_tas

| scenario | backend | verts | tris | added | area ok | min ang | angle ok | segs | CD viol | depth | attr err | ms | unrefined |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| constrained | laridae | 1029 | 1974 | 0 |  | 0.0683 |  | 100.0 | 0 | 1:744 2:957 3:267 4:6 | 0.0e+00 | 3.2 |  |
| area | laridae | 5275 | 10177 | 4246 | 100.0 | 0.0901 |  | 100.0 | 0 | 1:6653 2:2767 3:738 4:19 | 3.4e-16 | 24 | none |
| angle | laridae | 3422 | 6550 | 2393 |  | 0.0901 | 86.1 | 100.0 | 0 | 1:2909 2:2826 3:791 4:24 | 3.4e-16 | 17 | bad=912 shortEdges=904 sharpFixedCorner=42 |
| area_angle | laridae | 6059 | 11720 | 5030 | 100.0 | 0.0901 | 92.6 | 100.0 | 0 | 1:7360 2:3385 3:946 4:29 | 3.4e-16 | 30 | bad=865 shortEdges=861 sharpFixedCorner=40 |
| constrained | cdtr | 1029 | 1974 | 0 |  | 0.0683 |  | 100.0 | 0 | 1:744 2:957 3:267 4:6 | 0.0e+00 | 3 |  |
| area | cdtr | 5314 | 10275 | 4285 | 100.0 | 0.0901 |  | 100.0 | 0 | 1:6693 2:2821 3:734 4:27 | 3.4e-16 | 23 | shortEdgeTriangles=1 shortEdges=192 |
| angle | cdtr | 3603 | 6915 | 2574 |  | 0.0901 | 85.9 | 100.0 | 0 | 1:3132 2:2956 3:800 4:27 | 3.4e-16 | 17.5 | shortEdgeTriangles=1735 sharpFixedCorner=27 shortEdges=210 |
| area_angle | cdtr | 6212 | 12036 | 5183 | 100.0 | 0.0901 | 92.2 | 100.0 | 0 | 1:7492 2:3555 3:961 4:28 | 3.4e-16 | 35 | shortEdgeTriangles=1271 sharpFixedCorner=27 shortEdges=286 |
| constrained | trowel | 1029 | 1974 | 0 |  | 0.0683 |  | 100.0 | 0 | 1:750 2:951 3:267 4:6 | 0.0e+00 | 2.36 |  |
| area | trowel | 5453 | 10522 | 4424 | 100.0 | 0.115 |  | 100.0 | 0 | 1:6827 2:2906 3:762 4:27 | 3.4e-16 | 11.5 | none |
| angle | trowel | 7254 | 14094 | 6225 |  | 1.31 | 99.3 | 100.0 | 0 | 1:5671 2:6369 3:2015 4:39 | 3.4e-16 | 15 | none |
| area_angle | trowel | 9501 | 18523 | 8472 | 100.0 | 1.31 | 99.5 | 100.0 | 0 | 1:9625 2:6727 3:2134 4:37 | 3.4e-16 | 22 | none |
| constrained | RTriangle | 1029 | 1974 | 0 |  | 0.0683 |  | 100.0 | 0 |  | 0.0e+00 | 2.57 |  |
| area | RTriangle | 4532 | 8893 | 3503 | 100.0 | 0.0645 |  | 100.0 | 0 |  | 3.0e-15 | 7.33 |  |
| angle | RTriangle | 4839 | 9364 | 3810 |  | 1.31 | 99.2 | 100.0 | 0 |  | 7.4e-13 | 8.5 |  |
| area_angle | RTriangle | 7371 | 14362 | 6342 | 100.0 | 1.31 | 99.5 | 100.0 | 0 |  | 7.6e-13 | 16.5 |  |

