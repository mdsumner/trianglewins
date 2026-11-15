// Compiled kernels for the wkpool + geos ST_* suite (st_mesh.R). Loaded
// with cpp11::cpp_source(). Indices are 1-based in and out, as in R.
//
// The mesh is the triangle form of the mesh spec: x, y (the vertex
// dictionary), v0, v1, v2 (counter-clockwise corners) and a membership of
// triangles in features, given as CSR: the features of triangle t are
// mem[mem_start[t] .. mem_start[t + 1] - 1]. A coverage has one feature
// per triangle; overlapping inputs (spec v0.2 set_features) have several.
// Point location and the dissolve are not here: they are cdtr::cdt_locate()
// and wkpool::tri_dissolve().
#include <cpp11.hpp>
#include <algorithm>
#include <cmath>
#include <string>
#include <unordered_map>
#include <vector>
#include <queue>
#include <functional>
using namespace cpp11;

namespace {

struct Mesh {
  int nt, nv;
  std::vector<int> v;           // 3 * nt corners, 0-based
  std::vector<int> nbr;         // 3 * nt: triangle across edge k (from corner k to k + 1), -1 at the hull
  std::vector<int> vt_start, vt; // triangles around each vertex (CSR)
  std::vector<char> hull_vertex; // vertex on an edge with no neighbour
};

std::vector<int> neighbours(const std::vector<int>& v, int nt, long long nv) {
  std::vector<int> nbr(3 * nt, -1);
  std::unordered_map<long long, int> he;
  he.reserve(3 * nt);
  for (int h = 0; h < 3 * nt; h++) {
    long long a = v[h], b = v[3 * (h / 3) + (h % 3 + 1) % 3];
    he.emplace(a * nv + b, h);
  }
  for (int h = 0; h < 3 * nt; h++) {
    long long a = v[h], b = v[3 * (h / 3) + (h % 3 + 1) % 3];
    auto it = he.find(b * nv + a);
    if (it != he.end()) nbr[h] = it->second / 3;
  }
  return nbr;
}

// nbr: the edge table, 1-based triangle across edge k of t at 3 * t + k
// (0 at the hull), derived once per mesh by mesh_neighbours_c()
Mesh build(const integers& v0, const integers& v1, const integers& v2, int nv,
           const integers& nbr, bool with_vertices = true) {
  Mesh m;
  m.nt = v0.size();
  m.nv = nv;
  m.v.resize(3 * m.nt);
  for (int t = 0; t < m.nt; t++) {
    m.v[3 * t] = v0[t] - 1; m.v[3 * t + 1] = v1[t] - 1; m.v[3 * t + 2] = v2[t] - 1;
  }
  m.nbr.resize(3 * m.nt);
  for (int h = 0; h < 3 * m.nt; h++) m.nbr[h] = nbr[h] - 1;
  if (!with_vertices) return m;
  m.vt_start.assign(nv + 1, 0);
  for (int h = 0; h < 3 * m.nt; h++) m.vt_start[m.v[h] + 1]++;
  for (int i = 0; i < nv; i++) m.vt_start[i + 1] += m.vt_start[i];
  m.vt.resize(3 * m.nt);
  std::vector<int> fill(m.vt_start.begin(), m.vt_start.end() - 1);
  for (int h = 0; h < 3 * m.nt; h++) m.vt[fill[m.v[h]]++] = h / 3;
  m.hull_vertex.assign(nv, 0);
  for (int h = 0; h < 3 * m.nt; h++) {
    if (m.nbr[h] < 0) {
      m.hull_vertex[m.v[h]] = 1;
      m.hull_vertex[m.v[3 * (h / 3) + (h % 3 + 1) % 3]] = 1;
    }
  }
  return m;
}

}  // namespace

// The edge table: for each triangle t and edge k (corner k to k + 1), the
// 1-based triangle across it, 0 at the hull, at position 3 * (t - 1) + k + 1.
// Derived from the triangles in one hash pass; part of the prepared mesh.
[[cpp11::register]]
integers mesh_neighbours_c(integers v0, integers v1, integers v2, int n_vertex) {
  const int nt = v0.size();
  std::vector<int> v(3 * nt);
  for (int t = 0; t < nt; t++) { v[3 * t] = v0[t] - 1; v[3 * t + 1] = v1[t] - 1; v[3 * t + 2] = v2[t] - 1; }
  std::vector<int> nbr = neighbours(v, nt, n_vertex);
  writable::integers out(3 * nt);
  for (int h = 0; h < 3 * nt; h++) out[h] = nbr[h] + 1;
  return out;
}

namespace {

// features of each triangle, as a sorted small vector lookup
struct Membership {
  const integers& start;
  const integers& mem;
  bool has(int t, int f) const {   // t 0-based, f 1-based
    for (int k = start[t] - 1; k < start[t + 1] - 1; k++) if (mem[k] == f) return true;
    return false;
  }
};

}  // namespace

// Full DE-9IM between pairs of features of one mesh, from the indices only.
// Every cell of the mesh (open triangle, open edge, vertex) lies wholly in
// the interior, boundary or exterior of a feature: a triangle is interior
// when it is a member; an edge is interior when both its sides are, boundary
// when one is (the outside of the mesh is a side that is never a member);
// a vertex is interior when every triangle round it is a member and it is
// not on the hull, boundary when some are, exterior when none. The matrix
// entry for (class in A, class in B) is the largest dimension of a cell in
// both classes; the exterior meets the exterior in the plane outside the
// mesh, so EE is always 2. Only cells of the two features' triangles can be
// anything but exterior to both, so a pair costs the size of its features.
[[cpp11::register]]
strings mesh_relate_c(integers v0, integers v1, integers v2, int n_vertex, integers nbr,
                      integers mem_start, integers mem, integers feat_start,
                      integers feat_tri, integers a, integers b) {
  Mesh m = build(v0, v1, v2, n_vertex, nbr);
  Membership M{mem_start, mem};
  const int np = a.size();
  writable::strings out(np);
  std::vector<int> stamp_t(m.nt, -1), stamp_v(m.nv, -1);
  for (int p = 0; p < np; p++) {
    const int fa = a[p], fb = b[p];
    int dim[3][3];
    for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) dim[i][j] = -1;
    dim[2][2] = 2;
    auto cls_tri = [&](int t, int f) { return (t >= 0 && M.has(t, f)) ? 0 : 2; };
    auto cls_side = [&](int n_in) { return n_in == 2 ? 0 : (n_in == 1 ? 1 : 2); };
    auto see = [&](int ca, int cb, int d) { if (d > dim[ca][cb]) dim[ca][cb] = d; };
    for (int which = 0; which < 2; which++) {
      const int f = which == 0 ? fa : fb;
      for (int k = feat_start[f - 1] - 1; k < feat_start[f] - 1; k++) {
        const int t = feat_tri[k] - 1;
        if (stamp_t[t] == p) continue;
        stamp_t[t] = p;
        see(cls_tri(t, fa), cls_tri(t, fb), 2);
        for (int e = 0; e < 3; e++) {
          const int u = m.nbr[3 * t + e];
          const int ina = (cls_tri(t, fa) == 0) + (cls_tri(u, fa) == 0);
          const int inb = (cls_tri(t, fb) == 0) + (cls_tri(u, fb) == 0);
          see(cls_side(ina), cls_side(inb), 1);
          const int vv = m.v[3 * t + e];
          if (stamp_v[vv] == p) continue;
          stamp_v[vv] = p;
          int n = 0, ka = 0, kb = 0;
          for (int q = m.vt_start[vv]; q < m.vt_start[vv + 1]; q++) {
            const int s = m.vt[q];
            n++;
            ka += cls_tri(s, fa) == 0;
            kb += cls_tri(s, fb) == 0;
          }
          const bool hull = m.hull_vertex[vv];
          auto vcls = [&](int k) { return k == 0 ? 2 : ((k == n && !hull) ? 0 : 1); };
          see(vcls(ka), vcls(kb), 0);
        }
      }
    }
    std::string s(9, 'F');
    for (int i = 0; i < 3; i++)
      for (int j = 0; j < 3; j++)
        if (dim[i][j] >= 0) s[3 * i + j] = (char) ('0' + dim[i][j]);
    out[p] = s;
  }
  return out;
}

// Boundary of each feature: the directed edges of its triangles whose
// other side is not in the feature, with the feature's interior on the
// left. Returns (feature, from, to) per edge. Each shared boundary edge
// appears once per feature it bounds, and once per pair in `once` mode
// (an edge between features a < b is kept only for a), which is the
// boundary drawn once.
[[cpp11::register]]
integers_matrix<> mesh_boundary_c(integers v0, integers v1, integers v2, int n_vertex,
                                  integers nbr, integers mem_start, integers mem, bool once) {
  Mesh m = build(v0, v1, v2, n_vertex, nbr, false);
  Membership M{mem_start, mem};
  std::vector<int> f_out, a_out, b_out;
  for (int t = 0; t < m.nt; t++) {
    for (int k = mem_start[t] - 1; k < mem_start[t + 1] - 1; k++) {
      const int f = mem[k];
      for (int e = 0; e < 3; e++) {
        const int u = m.nbr[3 * t + e];
        if (u >= 0 && M.has(u, f)) continue;
        if (once && u >= 0) {
          // the edge also bounds the features of u that are not in t; keep
          // it only for the smallest feature that it bounds
          int smallest = f;
          for (int j = mem_start[u] - 1; j < mem_start[u + 1] - 1; j++)
            if (!M.has(t, mem[j]) && mem[j] < smallest) smallest = mem[j];
          for (int j = mem_start[t] - 1; j < mem_start[t + 1] - 1; j++)
            if (!M.has(u, mem[j]) && mem[j] < smallest) smallest = mem[j];
          if (smallest != f) continue;
        }
        f_out.push_back(f);
        a_out.push_back(m.v[3 * t + e] + 1);
        b_out.push_back(m.v[3 * t + (e + 1) % 3] + 1);
      }
    }
  }
  writable::integers_matrix<> out(f_out.size(), 3);
  for (size_t i = 0; i < f_out.size(); i++) {
    out(i, 0) = f_out[i]; out(i, 1) = a_out[i]; out(i, 2) = b_out[i];
  }
  return out;
}

// Distance from each point to one feature: zero when the point's located
// triangle is in the feature, else the distance to the nearest of the
// feature's boundary edges (bx0, by0) - (bx1, by1).
[[cpp11::register]]
doubles mesh_distance_c(doubles px, doubles py, logicals inside, doubles bx0, doubles by0,
                        doubles bx1, doubles by1) {
  const int np = px.size(), ne = bx0.size();
  writable::doubles out(np);
  for (int p = 0; p < np; p++) {
    if (inside[p] == TRUE) { out[p] = 0; continue; }
    double best = R_PosInf;
    const double X = px[p], Y = py[p];
    for (int e = 0; e < ne; e++) {
      const double ax = bx0[e], ay = by0[e], dx = bx1[e] - ax, dy = by1[e] - ay;
      const double l2 = dx * dx + dy * dy;
      double s = l2 > 0 ? ((X - ax) * dx + (Y - ay) * dy) / l2 : 0;
      s = std::min(1.0, std::max(0.0, s));
      const double qx = ax + s * dx - X, qy = ay + s * dy - Y;
      const double d = qx * qx + qy * qy;
      if (d < best) best = d;
    }
    out[p] = std::sqrt(best);
  }
  return out;
}

// Clip a mesh by a box, keeping it a mesh: triangles inside are kept,
// triangles outside dropped, and each crossing triangle is cut by the four
// sides (Sutherland-Hodgman, convex against convex) and fanned back into
// triangles. A new vertex where an edge crosses a side is computed from the
// edge's endpoints in vertex-id order, so the two triangles sharing the
// edge get bit-identical coordinates and the pieces re-pool exactly.
// Returns one row per output triangle: triangle (input row), x0 y0 x1 y1 x2 y2.
[[cpp11::register]]
doubles_matrix<> mesh_clip_box_c(doubles x, doubles y, integers v0, integers v1, integers v2,
                                 double xmin, double ymin, double xmax, double ymax) {
  const int nt = v0.size();
  struct P { double x, y; int id; };   // id >= 0 for an input vertex
  std::vector<double> o;
  auto inside = [&](const P& p, int side) {
    switch (side) {
      case 0: return p.x >= xmin;
      case 1: return p.x <= xmax;
      case 2: return p.y >= ymin;
      default: return p.y <= ymax;
    }
  };
  auto cut = [&](P p, P q, int side) {
    // canonical order so both triangles of an edge compute the same point
    if (q.id >= 0 && (p.id < 0 || q.id < p.id)) std::swap(p, q);
    else if (q.id < 0 && p.id < 0 && (q.x < p.x || (q.x == p.x && q.y < p.y))) std::swap(p, q);
    double s;
    P r;
    if (side < 2) {
      const double c = side == 0 ? xmin : xmax;
      s = (c - p.x) / (q.x - p.x);
      r.x = c; r.y = p.y + s * (q.y - p.y);
    } else {
      const double c = side == 2 ? ymin : ymax;
      s = (c - p.y) / (q.y - p.y);
      r.y = c; r.x = p.x + s * (q.x - p.x);
    }
    r.id = -1;
    return r;
  };
  for (int t = 0; t < nt; t++) {
    const int a = v0[t] - 1, b = v1[t] - 1, c = v2[t] - 1;
    const double tx0 = std::min({x[a], x[b], x[c]}), tx1 = std::max({x[a], x[b], x[c]});
    const double ty0 = std::min({y[a], y[b], y[c]}), ty1 = std::max({y[a], y[b], y[c]});
    if (tx1 < xmin || tx0 > xmax || ty1 < ymin || ty0 > ymax) continue;
    std::vector<P> poly = {{x[a], y[a], a}, {x[b], y[b], b}, {x[c], y[c], c}};
    if (!(tx0 >= xmin && tx1 <= xmax && ty0 >= ymin && ty1 <= ymax)) {
      for (int side = 0; side < 4 && !poly.empty(); side++) {
        std::vector<P> next;
        const int n = poly.size();
        for (int i = 0; i < n; i++) {
          const P& p = poly[i];
          const P& q = poly[(i + 1) % n];
          const bool pin = inside(p, side), qin = inside(q, side);
          if (pin) next.push_back(p);
          if (pin != qin) next.push_back(cut(p, q, side));
        }
        poly.swap(next);
      }
    }
    if (poly.size() < 3) continue;
    for (size_t i = 1; i + 1 < poly.size(); i++) {
      const P& p = poly[0]; const P& q = poly[i]; const P& r = poly[i + 1];
      const double ar = (q.x - p.x) * (r.y - p.y) - (r.x - p.x) * (q.y - p.y);
      if (ar <= 0) continue;   // a sliver on a side
      o.push_back(t + 1);
      o.push_back(p.x); o.push_back(p.y); o.push_back(q.x); o.push_back(q.y);
      o.push_back(r.x); o.push_back(r.y);
    }
  }
  const size_t n = o.size() / 7;
  writable::doubles_matrix<> out(n, 7);
  for (size_t i = 0; i < n; i++) for (int j = 0; j < 7; j++) out(i, j) = o[7 * i + j];
  return out;
}

// ST_Envelope per feature: one pass over the triangle corners
[[cpp11::register]]
doubles_matrix<> mesh_envelope_c(doubles x, doubles y, integers v0, integers v1,
                                 integers v2, integers mem_start, integers mem, int n_feature) {
  writable::doubles_matrix<> out(n_feature, 4);
  for (int i = 0; i < n_feature; i++) {
    out(i, 0) = R_PosInf; out(i, 1) = R_PosInf; out(i, 2) = R_NegInf; out(i, 3) = R_NegInf;
  }
  const int nt = v0.size();
  for (int t = 0; t < nt; t++) {
    const int vs[3] = {v0[t] - 1, v1[t] - 1, v2[t] - 1};
    for (int k = mem_start[t] - 1; k < mem_start[t + 1] - 1; k++) {
      const int f = mem[k] - 1;
      for (int j = 0; j < 3; j++) {
        const double xv = x[vs[j]], yv = y[vs[j]];
        if (xv < out(f, 0)) out(f, 0) = xv;
        if (yv < out(f, 1)) out(f, 1) = yv;
        if (xv > out(f, 2)) out(f, 2) = xv;
        if (yv > out(f, 3)) out(f, 3) = yv;
      }
    }
  }
  return out;
}

// Pairs of features that share a mesh vertex (candidates for every
// relation but disjoint), as a two-column matrix (a, b), a < b.
[[cpp11::register]]
integers_matrix<> mesh_vertex_pairs_c(integers v0, integers v1, integers v2,
                                      integers mem_start, integers mem) {
  const int nt = v0.size();
  std::vector<std::pair<int, int>> vf;
  vf.reserve(3 * nt);
  for (int t = 0; t < nt; t++) {
    for (int k = mem_start[t] - 1; k < mem_start[t + 1] - 1; k++) {
      vf.emplace_back(v0[t], mem[k]); vf.emplace_back(v1[t], mem[k]); vf.emplace_back(v2[t], mem[k]);
    }
  }
  std::sort(vf.begin(), vf.end());
  vf.erase(std::unique(vf.begin(), vf.end()), vf.end());
  std::vector<std::pair<int, int>> pr;
  size_t i = 0;
  while (i < vf.size()) {
    size_t j = i;
    while (j < vf.size() && vf[j].first == vf[i].first) j++;
    for (size_t p = i; p < j; p++)
      for (size_t q = p + 1; q < j; q++) pr.emplace_back(vf[p].second, vf[q].second);
    i = j;
  }
  std::sort(pr.begin(), pr.end());
  pr.erase(std::unique(pr.begin(), pr.end()), pr.end());
  writable::integers_matrix<> out(pr.size(), 2);
  for (size_t k = 0; k < pr.size(); k++) { out(k, 0) = pr[k].first; out(k, 1) = pr[k].second; }
  return out;
}

// The native measures in one pass over the triangles: area, area-weighted
// centroid, the centroid of the largest triangle (point on surface) and the
// perimeter (edges whose other side is not in the feature). Returns an
// n_feature x 6 matrix: area, cx, cy, px, py, perimeter.
[[cpp11::register]]
doubles_matrix<> mesh_measures_c(doubles x, doubles y, integers v0, integers v1, integers v2,
                                 integers nbr, integers mem_start, integers mem, int n_feature,
                                 bool perimeter) {
  const int nt = v0.size();
  Mesh m = perimeter ? build(v0, v1, v2, x.size(), nbr, false) : Mesh();
  Membership M{mem_start, mem};
  writable::doubles_matrix<> out(n_feature, 6);
  std::vector<double> amax(n_feature, -1);
  for (int f = 0; f < n_feature; f++) for (int j = 0; j < 6; j++) out(f, j) = 0;
  for (int t = 0; t < nt; t++) {
    const int a = v0[t] - 1, b = v1[t] - 1, c = v2[t] - 1;
    const double ar = 0.5 * ((x[b] - x[a]) * (y[c] - y[a]) - (x[c] - x[a]) * (y[b] - y[a]));
    const double cx = (x[a] + x[b] + x[c]) / 3, cy = (y[a] + y[b] + y[c]) / 3;
    for (int k = mem_start[t] - 1; k < mem_start[t + 1] - 1; k++) {
      const int f = mem[k] - 1;
      out(f, 0) += ar; out(f, 1) += ar * cx; out(f, 2) += ar * cy;
      if (ar > amax[f]) { amax[f] = ar; out(f, 3) = cx; out(f, 4) = cy; }
      for (int e = 0; perimeter && e < 3; e++) {
        const int u = m.nbr[3 * t + e];
        if (u >= 0 && M.has(u, f + 1)) continue;
        const int p = m.v[3 * t + e], q = m.v[3 * t + (e + 1) % 3];
        out(f, 5) += std::sqrt((x[q] - x[p]) * (x[q] - x[p]) + (y[q] - y[p]) * (y[q] - y[p]));
      }
    }
  }
  for (int f = 0; f < n_feature; f++) { out(f, 1) /= out(f, 0); out(f, 2) /= out(f, 0); }
  return out;
}

// ST_ConvexHull area per feature: Andrew's monotone chain over the
// feature's vertices (boundary vertices suffice; all corners are passed).
[[cpp11::register]]
doubles mesh_hull_area_c(doubles x, doubles y, integers v0, integers v1, integers v2,
                         integers feat_start, integers feat_tri, int n_feature) {
  writable::doubles out(n_feature);
  std::vector<int> pts, hull;
  for (int f = 0; f < n_feature; f++) {
    pts.clear();
    for (int k = feat_start[f] - 1; k < feat_start[f + 1] - 1; k++) {
      const int t = feat_tri[k] - 1;
      pts.push_back(v0[t] - 1); pts.push_back(v1[t] - 1); pts.push_back(v2[t] - 1);
    }
    std::sort(pts.begin(), pts.end(), [&](int a, int b) {
      return x[a] < x[b] || (x[a] == x[b] && y[a] < y[b]);
    });
    pts.erase(std::unique(pts.begin(), pts.end(), [&](int a, int b) {
      return x[a] == x[b] && y[a] == y[b];
    }), pts.end());
    const int n = pts.size();
    if (n < 3) { out[f] = 0; continue; }
    hull.assign(2 * n, 0);
    int k = 0;
    auto cross = [&](int o, int a, int b) {
      return (x[a] - x[o]) * (y[b] - y[o]) - (y[a] - y[o]) * (x[b] - x[o]);
    };
    for (int i = 0; i < n; i++) {
      while (k >= 2 && cross(hull[k - 2], hull[k - 1], pts[i]) <= 0) k--;
      hull[k++] = pts[i];
    }
    for (int i = n - 2, lo = k + 1; i >= 0; i--) {
      while (k >= lo && cross(hull[k - 2], hull[k - 1], pts[i]) <= 0) k--;
      hull[k++] = pts[i];
    }
    double a = 0;
    const double x0 = x[hull[0]], y0 = y[hull[0]];
    for (int i = 0; i + 1 < k; i++) {
      a += (x[hull[i]] - x0) * (y[hull[i + 1]] - y0) - (x[hull[i + 1]] - x0) * (y[hull[i]] - y0);
    }
    out[f] = a / 2;
  }
  return out;
}

// Distance from points to a set of segments with a uniform grid over the
// segments (the "one more structure" for distance): visit cells nearest
// first until no unvisited cell can hold a closer segment. Points with
// inside = TRUE get 0.
[[cpp11::register]]
doubles mesh_distance_grid_c(doubles px, doubles py, logicals inside, doubles bx0, doubles by0,
                             doubles bx1, doubles by1) {
  const int np = px.size(), ne = bx0.size();
  writable::doubles out(np);
  if (ne == 0) { for (int p = 0; p < np; p++) out[p] = inside[p] == TRUE ? 0 : R_PosInf; return out; }
  double xmin = R_PosInf, ymin = R_PosInf, xmax = R_NegInf, ymax = R_NegInf;
  for (int e = 0; e < ne; e++) {
    xmin = std::min({xmin, (double) bx0[e], (double) bx1[e]}); xmax = std::max({xmax, (double) bx0[e], (double) bx1[e]});
    ymin = std::min({ymin, (double) by0[e], (double) by1[e]}); ymax = std::max({ymax, (double) by0[e], (double) by1[e]});
  }
  const int n = std::max(1, (int) std::sqrt((double) ne));
  const double cw = std::max((xmax - xmin) / n, (ymax - ymin) / n) * (1 + 1e-12) + 1e-300;
  const int nx = std::max(1, (int) std::ceil((xmax - xmin) / cw)), ny = std::max(1, (int) std::ceil((ymax - ymin) / cw));
  auto cxi = [&](double v) { return std::min(nx - 1, std::max(0, (int) std::floor((v - xmin) / cw))); };
  auto cyi = [&](double v) { return std::min(ny - 1, std::max(0, (int) std::floor((v - ymin) / cw))); };
  std::vector<int> start((size_t) nx * ny + 1, 0), seg;
  std::vector<int> i0(ne), i1(ne), j0(ne), j1(ne);
  for (int e = 0; e < ne; e++) {
    i0[e] = cxi(std::min(bx0[e], bx1[e])); i1[e] = cxi(std::max(bx0[e], bx1[e]));
    j0[e] = cyi(std::min(by0[e], by1[e])); j1[e] = cyi(std::max(by0[e], by1[e]));
    for (int j = j0[e]; j <= j1[e]; j++) for (int i = i0[e]; i <= i1[e]; i++) start[(size_t) j * nx + i + 1]++;
  }
  for (size_t k = 1; k < start.size(); k++) start[k] += start[k - 1];
  seg.resize(start.back());
  std::vector<int> fill(start.begin(), start.end() - 1);
  for (int e = 0; e < ne; e++)
    for (int j = j0[e]; j <= j1[e]; j++) for (int i = i0[e]; i <= i1[e]; i++) seg[fill[(size_t) j * nx + i]++] = e;
  auto d2 = [&](int e, double X, double Y) {
    const double ax = bx0[e], ay = by0[e], dx = bx1[e] - ax, dy = by1[e] - ay;
    const double l2 = dx * dx + dy * dy;
    double s = l2 > 0 ? ((X - ax) * dx + (Y - ay) * dy) / l2 : 0;
    s = std::min(1.0, std::max(0.0, s));
    const double qx = ax + s * dx - X, qy = ay + s * dy - Y;
    return qx * qx + qy * qy;
  };
  // best-first search over cells by their distance to the point, from the
  // nearest cell outward through 4-neighbours; stop when the nearest
  // unvisited cell is further than the best segment so far
  std::vector<int> seen((size_t) nx * ny, -1);
  auto cell_d2 = [&](int i, int j, double X, double Y) {
    const double x0 = xmin + i * cw, y0 = ymin + j * cw;
    const double dx = std::max({x0 - X, 0.0, X - (x0 + cw)});
    const double dy = std::max({y0 - Y, 0.0, Y - (y0 + cw)});
    return dx * dx + dy * dy;
  };
  typedef std::pair<double, int> Q;
  for (int p = 0; p < np; p++) {
    if (inside[p] == TRUE) { out[p] = 0; continue; }
    const double X = px[p], Y = py[p];
    std::priority_queue<Q, std::vector<Q>, std::greater<Q>> pq;
    const int c0 = cyi(Y) * nx + cxi(X);
    pq.emplace(cell_d2(c0 % nx, c0 / nx, X, Y), c0);
    seen[c0] = p;
    double best = R_PosInf;
    while (!pq.empty()) {
      const Q q = pq.top(); pq.pop();
      if (q.first >= best) break;
      const int c = q.second, i = c % nx, j = c / nx;
      for (int k = start[c]; k < start[c + 1]; k++) best = std::min(best, d2(seg[k], X, Y));
      const int ni[4] = {i - 1, i + 1, i, i}, nj[4] = {j, j, j - 1, j + 1};
      for (int k = 0; k < 4; k++) {
        if (ni[k] < 0 || ni[k] >= nx || nj[k] < 0 || nj[k] >= ny) continue;
        const int cn = nj[k] * nx + ni[k];
        if (seen[cn] == p) continue;
        seen[cn] = p;
        pq.emplace(cell_d2(ni[k], nj[k], X, Y), cn);
      }
    }
    out[p] = std::sqrt(best);
  }
  return out;
}
