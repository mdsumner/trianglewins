// Compiled versions of the grouped mesh loops in st_mesh.R, so that the
// comparison with sf (GEOS, also compiled) is of algorithms rather than of
// R against C++. Loaded with cpp11::cpp_source(). All indices 1-based in,
// 1-based out, as in R.
#include <cpp11.hpp>
#include <vector>
#include <algorithm>
#include <cmath>
#include <functional>
using namespace cpp11;

// ST_Envelope per feature: one pass over the triangle corners
[[cpp11::register]]
doubles_matrix<> mesh_envelope_c(doubles x, doubles y, integers v0, integers v1,
                                 integers v2, integers feature, int n_feature) {
  writable::doubles_matrix<> out(n_feature, 4);
  for (int i = 0; i < n_feature; i++) {
    out(i, 0) = R_PosInf; out(i, 1) = R_PosInf; out(i, 2) = R_NegInf; out(i, 3) = R_NegInf;
  }
  int nt = v0.size();
  const integers* vs[3] = {&v0, &v1, &v2};
  for (int t = 0; t < nt; t++) {
    int f = feature[t];
    if (f == NA_INTEGER) continue;
    f--;
    for (int k = 0; k < 3; k++) {
      int v = (*vs[k])[t] - 1;
      double xv = x[v], yv = y[v];
      if (xv < out(f, 0)) out(f, 0) = xv;
      if (yv < out(f, 1)) out(f, 1) = yv;
      if (xv > out(f, 2)) out(f, 2) = xv;
      if (yv > out(f, 3)) out(f, 3) = yv;
    }
  }
  return out;
}

// ST_Touches for all feature pairs of a coverage: features that share a
// mesh vertex. Returns a two-column matrix of pairs (a, b), a != b, sorted.
[[cpp11::register]]
integers_matrix<> mesh_touches_c(integers v0, integers v1, integers v2,
                                 integers feature, int n_vertex) {
  int nt = v0.size();
  // (vertex, feature) incidences, then features per vertex
  std::vector<std::pair<int, int>> vf;
  vf.reserve(3 * nt);
  for (int t = 0; t < nt; t++) {
    int f = feature[t];
    if (f == NA_INTEGER) continue;
    vf.emplace_back(v0[t], f); vf.emplace_back(v1[t], f); vf.emplace_back(v2[t], f);
  }
  std::sort(vf.begin(), vf.end());
  vf.erase(std::unique(vf.begin(), vf.end()), vf.end());
  std::vector<std::pair<int, int>> pr;
  size_t i = 0;
  while (i < vf.size()) {
    size_t j = i;
    while (j < vf.size() && vf[j].first == vf[i].first) j++;
    for (size_t a = i; a < j; a++)
      for (size_t b = i; b < j; b++)
        if (a != b) pr.emplace_back(vf[a].second, vf[b].second);
    i = j;
  }
  std::sort(pr.begin(), pr.end());
  pr.erase(std::unique(pr.begin(), pr.end()), pr.end());
  writable::integers_matrix<> out(pr.size(), 2);
  for (size_t k = 0; k < pr.size(); k++) { out(k, 0) = pr[k].first; out(k, 1) = pr[k].second; }
  return out;
}

// ST_Intersects(point, feature) for many points: a uniform grid of triangle
// buckets (built here, the mesh's "prepared" index), then three orientation
// tests per candidate. Returns the feature of each point, NA outside.
[[cpp11::register]]
integers mesh_locate_c(doubles x, doubles y, integers v0, integers v1, integers v2,
                       integers feature, doubles px, doubles py, double cells_per_triangle) {
  int nt = v0.size();
  double xmin = R_PosInf, ymin = R_PosInf, xmax = R_NegInf, ymax = R_NegInf;
  for (int i = 0; i < x.size(); i++) {
    xmin = std::min(xmin, (double) x[i]); xmax = std::max(xmax, (double) x[i]);
    ymin = std::min(ymin, (double) y[i]); ymax = std::max(ymax, (double) y[i]);
  }
  double w = xmax - xmin, h = ymax - ymin;
  int nx = std::max(1, (int) std::ceil(std::sqrt(nt * cells_per_triangle * w / h)));
  double s = w / nx;
  int ny = std::max(1, (int) std::ceil(h / s));
  auto cx = [&](double v) { return std::min(nx - 1, std::max(0, (int) ((v - xmin) / s))); };
  auto cy = [&](double v) { return std::min(ny - 1, std::max(0, (int) ((v - ymin) / s))); };
  // counting sort of (cell, triangle)
  std::vector<int> count((size_t) nx * ny + 1, 0);
  std::vector<int> bx0(nt), bx1(nt), by0(nt), by1(nt);
  for (int t = 0; t < nt; t++) {
    int a = v0[t] - 1, b = v1[t] - 1, c = v2[t] - 1;
    bx0[t] = cx(std::min({x[a], x[b], x[c]})); bx1[t] = cx(std::max({x[a], x[b], x[c]}));
    by0[t] = cy(std::min({y[a], y[b], y[c]})); by1[t] = cy(std::max({y[a], y[b], y[c]}));
    for (int j = by0[t]; j <= by1[t]; j++)
      for (int i = bx0[t]; i <= bx1[t]; i++) count[(size_t) j * nx + i + 1]++;
  }
  for (size_t k = 1; k < count.size(); k++) count[k] += count[k - 1];
  std::vector<int> fill(count.begin(), count.end() - 1), bucket(count.back());
  for (int t = 0; t < nt; t++)
    for (int j = by0[t]; j <= by1[t]; j++)
      for (int i = bx0[t]; i <= bx1[t]; i++) bucket[fill[(size_t) j * nx + i]++] = t;

  int np = px.size();
  writable::integers out(np);
  for (int p = 0; p < np; p++) {
    out[p] = NA_INTEGER;
    double X = px[p], Y = py[p];
    if (X < xmin || X > xmax || Y < ymin || Y > ymax) continue;
    size_t cell = (size_t) cy(Y) * nx + cx(X);
    for (int k = count[cell]; k < count[cell + 1]; k++) {
      int t = bucket[k];
      int a = v0[t] - 1, b = v1[t] - 1, c = v2[t] - 1;
      if ((x[b] - x[a]) * (Y - y[a]) - (y[b] - y[a]) * (X - x[a]) < 0) continue;
      if ((x[c] - x[b]) * (Y - y[b]) - (y[c] - y[b]) * (X - x[b]) < 0) continue;
      if ((x[a] - x[c]) * (Y - y[c]) - (y[a] - y[c]) * (X - x[c]) < 0) continue;
      out[p] = feature[t];
      break;
    }
  }
  return out;
}

// The boundary of each group (the edges a dissolve walks into rings): a
// directed edge whose twin is in another group, or has no twin. Returns
// (group, from, to) per boundary edge, with the group's interior on the left.
[[cpp11::register]]
integers_matrix<> mesh_boundary_c(integers v0, integers v1, integers v2, integers group,
                                  int n_vertex) {
  int nt = v0.size();
  struct He { long long key; int g; int a; int b; };
  std::vector<He> he;
  he.reserve(3 * nt);
  for (int t = 0; t < nt; t++) {
    int g = group[t];
    if (g == NA_INTEGER) continue;
    int v[3] = {v0[t], v1[t], v2[t]};
    for (int k = 0; k < 3; k++) {
      int a = v[k], b = v[(k + 1) % 3];
      long long lo = std::min(a, b), hi = std::max(a, b);
      he.push_back({lo * (long long) (n_vertex + 1) + hi, g, a, b});
    }
  }
  std::sort(he.begin(), he.end(), [](const He& p, const He& q) {
    return p.key < q.key || (p.key == q.key && p.g < q.g);
  });
  std::vector<int> keep;
  size_t i = 0;
  while (i < he.size()) {
    size_t j = i + 1;
    while (j < he.size() && he[j].key == he[i].key) j++;
    // an interior edge is two half-edges of the same group
    if (j - i == 2 && he[i].g == he[i + 1].g) { i = j; continue; }
    for (size_t k = i; k < j; k++) keep.push_back(k);
    i = j;
  }
  writable::integers_matrix<> out(keep.size(), 3);
  for (size_t k = 0; k < keep.size(); k++) {
    out(k, 0) = he[keep[k]].g; out(k, 1) = he[keep[k]].a; out(k, 2) = he[keep[k]].b;
  }
  return out;
}

// A dissolve with no coordinates read except for ring orientation:
// boundary half-edges are chained by rotating around each vertex through
// the group's own triangles (so a vertex where the boundary pinches is
// passed through correctly), and each ring takes the edge-connected
// component of its triangles as its polygon, so holes are assigned to
// shells without a point-in-polygon test. Returns one row per ring vertex:
// (group, polygon, ring, vertex), shells first within each polygon.
[[cpp11::register]]
integers_matrix<> mesh_dissolve_c(doubles x, doubles y, integers v0, integers v1,
                                  integers v2, integers group, int n_vertex) {
  int nt = v0.size();
  auto vert = [&](int t, int k) { int v = (k == 0) ? v0[t] : (k == 1) ? v1[t] : v2[t]; return v; };
  // twin of half-edge h = 3t + k (from vert(t,k) to vert(t,k+1)), same group only
  std::vector<int> twin(3 * nt, -1);
  {
    std::vector<std::pair<long long, int>> key;
    key.reserve(3 * nt);
    for (int t = 0; t < nt; t++) {
      if (group[t] == NA_INTEGER) continue;
      for (int k = 0; k < 3; k++) {
        long long a = vert(t, k), b = vert(t, (k + 1) % 3);
        long long lo = std::min(a, b), hi = std::max(a, b);
        key.emplace_back(lo * (long long) (n_vertex + 1) + hi, 3 * t + k);
      }
    }
    std::sort(key.begin(), key.end());
    for (size_t i = 0; i + 1 < key.size(); i++) {
      if (key[i].first == key[i + 1].first) {
        int h = key[i].second, g = key[i + 1].second;
        if (group[h / 3] == group[g / 3]) { twin[h] = g; twin[g] = h; }
      }
    }
  }
  // edge-connected components of each group's triangles (union-find)
  std::vector<int> parent(nt);
  for (int t = 0; t < nt; t++) parent[t] = t;
  std::function<int(int)> find = [&](int a) {
    while (parent[a] != a) { parent[a] = parent[parent[a]]; a = parent[a]; }
    return a;
  };
  for (int h = 0; h < 3 * nt; h++)
    if (twin[h] >= 0) { int a = find(h / 3), b = find(twin[h] / 3); if (a != b) parent[a] = b; }
  // chain boundary half-edges into rings
  std::vector<char> used(3 * nt, 0);
  struct Ring { int g; int comp; double area; std::vector<int> v; };
  std::vector<Ring> rings;
  for (int h0 = 0; h0 < 3 * nt; h0++) {
    int t0 = h0 / 3;
    if (group[t0] == NA_INTEGER || twin[h0] >= 0 || used[h0]) continue;
    Ring r; r.g = group[t0]; r.comp = find(t0); r.area = 0;
    int h = h0;
    do {
      used[h] = 1;
      r.v.push_back(vert(h / 3, h % 3));
      // next boundary half-edge leaving the head of h, rotating through the group
      int n = 3 * (h / 3) + (h % 3 + 1) % 3;
      while (twin[n] >= 0) { int tw = twin[n]; n = 3 * (tw / 3) + (tw % 3 + 1) % 3; }
      h = n;
    } while (h != h0);
    for (size_t i = 0; i < r.v.size(); i++) {
      int a = r.v[i] - 1, b = r.v[(i + 1) % r.v.size()] - 1;
      r.area += x[a] * y[b] - x[b] * y[a];
    }
    rings.push_back(std::move(r));
  }
  // order: group, polygon, shell (positive area) first
  std::vector<int> o(rings.size());
  for (size_t i = 0; i < o.size(); i++) o[i] = i;
  std::sort(o.begin(), o.end(), [&](int a, int b) {
    if (rings[a].g != rings[b].g) return rings[a].g < rings[b].g;
    if (rings[a].comp != rings[b].comp) return rings[a].comp < rings[b].comp;
    return rings[a].area > rings[b].area;
  });
  size_t nrow = 0;
  for (auto& r : rings) nrow += r.v.size() + 1;
  writable::integers_matrix<> out(nrow, 4);
  size_t row = 0; int poly = 0, last_comp = -1, last_g = -1;
  for (size_t i = 0; i < o.size(); i++) {
    Ring& r = rings[o[i]];
    if (r.comp != last_comp || r.g != last_g) { poly++; last_comp = r.comp; last_g = r.g; }
    for (size_t k = 0; k <= r.v.size(); k++) {   // closed ring
      out(row, 0) = r.g; out(row, 1) = poly; out(row, 2) = (int) i + 1;
      out(row, 3) = r.v[k % r.v.size()];
      row++;
    }
  }
  return out;
}
