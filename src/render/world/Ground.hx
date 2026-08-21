package render.world;

import three.Three;
import citygen.CityConfig;
import citygen.CityModel.Tile;
import render.RenderConfig;
import render.RenderConfig.TEXTURES;
import render.Textures;
import render.world.MeshBuf.MeshBufTools;

// the shared merged-geometry buffer (render.world.MeshBuf), kept under its original local name
typedef GroundBuf = render.world.MeshBuf.MeshBuf;

// ground surfaces: one merged mesh per surface type (road/alley/walkway), plus the
// road-markings overlay and the mitered kerb-edging strip. Reads the tile grid only.
// each cell = one quad; walkway is raised CURB_H with curb side-faces where it meets a
// lower (road/alley) cell. A walkway cell with exactly one convex corner (both edge-
// neighbours lower) is chamfered: the jutting corner is sliced off on the diagonal,
// the road/alley underneath fills the cut, and the curb follows it.
class Ground {
  static inline var GRID = CityConfig.GRID;
  static inline var CELL = CityConfig.CELL;

  public static function build(scene:Scene):Void {
    var tiles = WorldCtx.tiles;
    // add a ground mesh that catches shadows (road/alley/walkway/markings all receive building + lamp
    // shadows; they never cast — flat surfaces)
    function addRecv(m:Mesh):Void
      {
        m.receiveShadow = true;
        scene.add(m);
      }
    var st = WorldCtx.style;
    var half = (GRID * CELL) / 2;
    var types = [
      { tile: Tile.Road, tex: st.asphalt, kind: 'asphalt', tileW: RenderConfig.ROAD_TILE, y: 0.0 },
      { tile: Tile.Alley, tex: st.alley, kind: 'asphalt', tileW: RenderConfig.ALLEY_TILE, y: 0.0 },
      { tile: Tile.Walkway, tex: st.walkway, kind: 'wall', tileW: RenderConfig.WALKWAY_TILE, y: RenderConfig.CURB_H },
    ];
    var bufs = [for (_ in types) MeshBufTools.make()];
    var borderBuf:GroundBuf = MeshBufTools.make(); // kerb-edging stripe on walkway tops (own mesh/tex)
    var markBuf:GroundBuf = MeshBufTools.make();   // road markings overlay (lane lines, crosswalks; own mesh/tex)
    function bidx(tile:Tile):Int { for (i in 0...types.length) if (types[i].tile == tile) return i; return -1; }

    // the emitters live in render.world.MeshBuf (shared with the sewer builder); bound to locals
    // so every call site below reads the same as when they were closures here
    var vtx = MeshBufTools.vtx;
    var tri = MeshBufTools.tri;
    var quad = MeshBufTools.quad;
    function isLower(rr:Int, cc:Int):Bool {
      if (rr < 0 || cc < 0 || rr >= GRID || cc >= GRID) return true;
      var t = tiles[rr][cc];
      return t == Tile.Road || t == Tile.Alley;
    }
    // buffer of the surface under a chamfer cut: prefer the diagonal cell, else an edge
    function underBuf(r:Int, c:Int, dc:Int, dr:Int):Int {
      inline function pick(rr:Int, cc:Int):Int {
        if (rr < 0 || cc < 0 || rr >= GRID || cc >= GRID) return bidx(Tile.Road);
        var t = tiles[rr][cc];
        return (t == Tile.Road || t == Tile.Alley) ? bidx(t) : -1;
      }
      var d = pick(r + dr, c + dc); if (d >= 0) return d;
      var e = pick(r, c + dc); if (e >= 0) return e;
      var s = pick(r + dr, c); if (s >= 0) return s;
      return bidx(Tile.Road);
    }

    var H = RenderConfig.CURB_H;
    var BW = RenderConfig.WALKWAY_BORDER_W, BT = RenderConfig.WALKWAY_BORDER_TILE;
    // unit outward normal of segment a→b, flipped to point toward (tx,tz) (road side)
    function outN(ax:Float, az:Float, bx:Float, bz:Float, tx:Float, tz:Float):{x:Float, z:Float} {
      var nx = bz - az, nz = -(bx - ax);                       // perpendicular to a→b
      if (nx * (tx - ax) + nz * (tz - az) < 0) { nx = -nx; nz = -nz; }
      var nl = Math.sqrt(nx * nx + nz * nz);
      return nl < 1e-6 ? { x: 0.0, z: 0.0 } : { x: nx / nl, z: nz / nl };
    }
    // collect every curb segment (inner edge a→b + unit outward normal) here; the
    // kerb-edging strip is emitted in one mitered post-pass so adjacent segments meet
    // exactly at shared vertices — no gaps at convex corners, no overlap at concave ones
    var curbs:Array<{ax:Float, az:Float, bx:Float, bz:Float, nx:Float, nz:Float}> = [];
    inline function lipN(ax:Float, az:Float, bx:Float, bz:Float, nx:Float, nz:Float):Void {
      if ((bx - ax) * (bx - ax) + (bz - az) * (bz - az) > 1e-9) curbs.push({ax: ax, az: az, bx: bx, bz: bz, nx: nx, nz: nz});
    }
    function lipSeg(ax:Float, az:Float, bx:Float, bz:Float, tx:Float, tz:Float):Void {
      var n = outN(ax, az, bx, bz, tx, tz); lipN(ax, az, bx, bz, n.x, n.z);
    }
    // a road cell with exactly one convex walkway corner is beveled: a diagonal half-
    // tile of walkway is dropped into corner O, so its two O-adjacent edges become
    // raised walkway (continuous with the neighbours that triggered the bevel). returns
    // the corner 0 SW · 1 SE · 2 NE · 3 NW, or -1
    inline function isWk(rr:Int, cc:Int):Bool return rr >= 0 && cc >= 0 && rr < GRID && cc < GRID && tiles[rr][cc] == Tile.Walkway;
    function bevelAt(r:Int, c:Int):Int {
      if (r < 0 || c < 0 || r >= GRID || c >= GRID) return -1; // off-grid (lowerSide probes the border): no corner to bevel
      if (tiles[r][c] != Tile.Road) return -1;
      var Nw = isWk(r - 1, c), Sw = isWk(r + 1, c), Ew = isWk(r, c + 1), Ww = isWk(r, c - 1);
      var O = -1, nC = 0;
      if (Ew && Sw) { O = 1; nC++; } if (Ww && Sw) { O = 0; nC++; }
      if (Ew && Nw) { O = 2; nC++; } if (Ww && Nw) { O = 3; nC++; }
      return nC == 1 ? O : -1;
    }
    // is the road/alley cell (r,c) lower (curbed) as seen across the edge facing it from
    // direction `from` (0=N 1=E 2=S 3=W neighbour of it)? a bevel leg is walkway → not lower
    function lowerSide(r:Int, c:Int, from:Int):Bool {
      if (!isLower(r, c)) return false;
      var O = bevelAt(r, c);
      if (O < 0) return true;
      // legs adjacent to O: O 0→S,W · 1→S,E · 2→N,E · 3→N,W. `from` edge is a leg → not lower
      var legA = (O == 2 || O == 3) ? 0 : 2;          // N for NE/NW else S
      var legB = (O == 1 || O == 2) ? 1 : 3;          // E for SE/NE else W
      return from != legA && from != legB;
    }
    for (r in 0...GRID) for (c in 0...GRID) {
      var ti = bidx(tiles[r][c]);
      if (ti < 0) continue; // building
      var T = types[ti].tileW;
      var b = bufs[ti];
      var x0 = c * CELL - half, x1 = x0 + CELL;
      var z0 = r * CELL - half, z1 = z0 + CELL;

      if (tiles[r][c] != Tile.Walkway) {
        var y = types[ti].y;
        // outer road-turn corner (a road cell with two adjacent walkway neighbours):
        // bevel it with a diagonal HALF-tile of walkway dropped into the road
        var O = bevelAt(r, c);
        if (O >= 0) {
          var wb = bidx(Tile.Walkway), wT = types[wb].tileW;
          var CXr = [x0, x1, x1, x0], CZr = [z1, z1, z0, z0];
          var pp = (O + 3) % 4, su = (O + 1) % 4, P = (O + 2) % 4;
          // road keeps the inner half (away from the corner), at road level
          tri(b, [CXr[su], y, CZr[su]], [CXr[P], y, CZr[P]], [CXr[pp], y, CZr[pp]],
            [CXr[su] / T, CZr[su] / T, CXr[P] / T, CZr[P] / T, CXr[pp] / T, CZr[pp] / T]);
          // walkway fills the corner half, raised
          tri(bufs[wb], [CXr[pp], H, CZr[pp]], [CXr[O], H, CZr[O]], [CXr[su], H, CZr[su]],
            [CXr[pp] / wT, CZr[pp] / wT, CXr[O] / wT, CZr[O] / wT, CXr[su] / wT, CZr[su] / wT]);
          // kerb lip along the diagonal cut, toward the road side (corner P). full length:
          // the mitered post-pass trims it where it meets the neighbours' straight lips
          // (and the opposite bevel's diagonal at an arrow tip)
          lipSeg(CXr[pp], CZr[pp], CXr[su], CZr[su], CXr[P], CZr[P]);
        } else {
          quad(b, [x0, y, z1], [x1, y, z1], [x1, y, z0], [x0, y, z0],
            [x0 / T, z1 / T, x1 / T, z1 / T, x1 / T, z0 / T, x0 / T, z0 / T]);
        }
        continue;
      }

      // open (curbed) edge: neighbour is road/alley AND not a bevel leg (raised walkway).
      // `from` = this cell's direction relative to that neighbour (opposite of the probe)
      var E = lowerSide(r, c + 1, 3), W = lowerSide(r, c - 1, 1), S = lowerSide(r + 1, c, 0), N = lowerSide(r - 1, c, 2);
      var se = E && S, sw = W && S, ne = E && N, nw = W && N;
      var nConvex = (se ? 1 : 0) + (sw ? 1 : 0) + (ne ? 1 : 0) + (nw ? 1 : 0);
      // corners 0=SW 1=SE 2=NE 3=NW (cyclic, CCW from above → +y normals)
      var CX = [x0, x1, x1, x0], CZ = [z1, z1, z0, z0];

      if (nConvex == 1) {
        var O = se ? 1 : sw ? 0 : ne ? 2 : 3;            // convex corner: clip a small bit off it
        var dc = (O == 1 || O == 2) ? 1 : -1, dr = (O == 0 || O == 1) ? 1 : -1;
        var pp = (O + 3) % 4, su = (O + 1) % 4;           // the two edges meeting at O
        var ub = underBuf(r, c, dc, dr);
        var ut = types[ub].tileW;
        var f = 1 / 3;                                    // clip one of the (imagined) 3x3 sub-tiles
        var inx = CX[O] + f * (CX[pp] - CX[O]), inz = CZ[O] + f * (CZ[pp] - CZ[O]); // clip point on pp-edge
        var oux = CX[O] + f * (CX[su] - CX[O]), ouz = CZ[O] + f * (CZ[su] - CZ[O]); // clip point on su-edge
        // walkway top = the cell pentagon (corner O replaced by the two clip points), triangle fan
        var px:Array<Float> = [], pz:Array<Float> = [];
        for (i in 0...4) if (i == O) { px.push(inx); pz.push(inz); px.push(oux); pz.push(ouz); }
          else { px.push(CX[i]); pz.push(CZ[i]); }
        for (t in 1...px.length - 1) tri(b,
          [px[0], H, pz[0]], [px[t], H, pz[t]], [px[t + 1], H, pz[t + 1]],
          [px[0] / T, pz[0] / T, px[t] / T, pz[t] / T, px[t + 1] / T, pz[t + 1] / T]);
        // road/alley fills the clipped corner triangle, at road level
        tri(bufs[ub], [inx, 0, inz], [CX[O], 0, CZ[O]], [oux, 0, ouz],
          [inx / ut, inz / ut, CX[O] / ut, CZ[O] / ut, oux / ut, ouz / ut]);
        // kerb lips along each curbed edge (both straight parts + the diagonal cut).
        // outward = away from the cell centre (2·mid − centre): correct for the two
        // straight edges too, where corner O is collinear with the edge (toward=O fails).
        // the mitered post-pass joins the diagonal to each straight lip cleanly
        var mx = (x0 + x1) / 2, mz = (z0 + z1) / 2;
        lipSeg(CX[pp], CZ[pp], inx, inz, CX[pp] + inx - mx, CZ[pp] + inz - mz);
        lipSeg(inx, inz, oux, ouz, inx + oux - mx, inz + ouz - mz);
        lipSeg(oux, ouz, CX[su], CZ[su], oux + CX[su] - mx, ouz + CZ[su] - mz);
      } else {
        // full walkway paving top at curb height
        quad(b, [x0, H, z1], [x1, H, z1], [x1, H, z0], [x0, H, z0],
          [x0 / T, z1 / T, x1 / T, z1 / T, x1 / T, z0 / T, x0 / T, z0 / T]);
        // kerb lip along each open edge (in nConvex==0 open edges are never
        // perpendicular, so lips never meet at a corner)
        var mx = (x0 + x1) / 2, mz = (z0 + z1) / 2;
        if (N) lipSeg(x0, z0, x1, z0, mx, z0 - 1);
        if (S) lipSeg(x0, z1, x1, z1, mx, z1 + 1);
        if (E) lipSeg(x1, z0, x1, z1, x1 + 1, mz);
        if (W) lipSeg(x0, z0, x0, z1, x0 - 1, mz);
      }
    }

    // --- road markings: lane lines + crosswalks (painted overlay) -----------
    // pattern is geometry (dashes/bars/double); fill is one worn-paint texture.
    // roads carry no width/orientation metadata, so classify each road cell by run
    // length: the perpendicular run is the band thickness (≤ MAIN_ROAD_W), the
    // along run is the corridor (longer). both runs long ⇒ a crossing box (skip)
    {
      var PY = RenderConfig.PAINT_Y, PT = RenderConfig.PAINT_TILE, LW = RenderConfig.LINE_W;
      var MW = CityConfig.MAIN_ROAD_W;
      inline function isR(rr:Int, cc:Int):Bool return rr >= 0 && cc >= 0 && rr < GRID && cc < GRID && tiles[rr][cc] == Tile.Road;
      function hrun(rr:Int, cc:Int):Int { if (!isR(rr, cc)) return 0; var a = cc; while (isR(rr, a - 1)) a--; var b = cc; while (isR(rr, b + 1)) b++; return b - a + 1; }
      function vrun(rr:Int, cc:Int):Int { if (!isR(rr, cc)) return 0; var a = rr; while (isR(a - 1, cc)) a--; var b = rr; while (isR(b + 1, cc)) b++; return b - a + 1; }
      inline function inter(rr:Int, cc:Int):Bool return isR(rr, cc) && hrun(rr, cc) > MW && vrun(rr, cc) > MW;
      // axis-aligned painted rect at PY; UV is WORLD-aligned on both axes (worldPos/PT) so the
      // worn-paint field samples at one consistent scale everywhere — no per-strip stretch.
      // alongX kept for call-site symmetry but no longer affects UV
      function mark(mx0:Float, mx1:Float, mz0:Float, mz1:Float, alongX:Bool):Void {
        quad(markBuf, [mx0, PY, mz1], [mx1, PY, mz1], [mx1, PY, mz0], [mx0, PY, mz0],
          [mx0 / PT, mz1 / PT, mx1 / PT, mz1 / PT, mx1 / PT, mz0 / PT, mx0 / PT, mz0 / PT]);
      }
      // dashed line of thickness LW centred on `fixed`, running a→b. alongX: a,b are x (fixed=z); else a,b are z (fixed=x)
      function dashed(a:Float, b:Float, fixed:Float, alongX:Bool):Void {
        var step = RenderConfig.DASH_LEN + RenderConfig.DASH_GAP;
        var p = a;
        while (p < b - 1e-4) {
          var q = Math.min(p + RenderConfig.DASH_LEN, b);
          if (alongX) mark(p, q, fixed - LW / 2, fixed + LW / 2, true);
          else mark(fixed - LW / 2, fixed + LW / 2, p, q, false);
          p += step;
        }
      }
      // centre/lane line at boundary `fixed` for a band of width W at lane index k
      inline function laneLine(a:Float, b:Float, fixed:Float, W:Int, k:Int, alongX:Bool):Void {
        if (W == 2) { if (k == 0) dashed(a, b, fixed, alongX); }
        else if (W == 4) {
          if (k == 0 || k == 2) dashed(a, b, fixed, alongX);
          else if (k == 1) { // double solid centre line
            var g = RenderConfig.DOUBLE_GAP / 2;
            if (alongX) { mark(a, b, fixed - g - LW / 2, fixed - g + LW / 2, true); mark(a, b, fixed + g - LW / 2, fixed + g + LW / 2, true); }
            else { mark(fixed - g - LW / 2, fixed - g + LW / 2, a, b, false); mark(fixed + g - LW / 2, fixed + g + LW / 2, a, b, false); }
          }
        }
      }
      // zebra band + stop line across a road of width [lo,hi], at the mouth facing the
      // intersection. dir +1 = intersection on the high side of `edge`, -1 = low side.
      // `edge` is the corridor/box boundary; bars run across the road (perpendicular to travel)
      function crossing(lo:Float, hi:Float, edge:Float, dir:Int, alongTravelX:Bool):Void {
        var ZD = RenderConfig.ZEBRA_DEPTH, ZB = RenderConfig.ZEBRA_BAR, SW = RenderConfig.STOP_W, SG = RenderConfig.STOP_GAP;
        var zb0 = dir > 0 ? edge - ZD : edge;          // zebra band extent along the travel axis
        var zb1 = dir > 0 ? edge : edge + ZD;
        // bars run PARALLEL to the road (long along travel), repeating across the width.
        // fit n equal paint strips with n+1 equal gaps (gap on each road edge ⇒ paint never
        // touches the curb): width = (2n+1)·s, pick n so s ≈ ZEBRA_BAR
        var W = hi - lo;
        var n = Math.round((W / ZB - 1) / 2); if (n < 1) n = 1;
        var s = W / (2 * n + 1);
        for (i in 0...n) {
          var p = lo + (2 * i + 1) * s, q = p + s;
          if (alongTravelX) mark(zb0, zb1, p, q, true); else mark(p, q, zb0, zb1, false);
        }
        var s0 = dir > 0 ? zb0 - SG - SW : zb1 + SG;   // stop bar set back from the zebra by SG
        if (alongTravelX) mark(s0, s0 + SW, lo, hi, false); else mark(lo, hi, s0, s0 + SW, true);
      }
      for (r in 0...GRID) for (c in 0...GRID) {
        if (!isR(r, c)) continue;
        var Lh = hrun(r, c), Lv = vrun(r, c);
        var hCorr = Lh > MW, vCorr = Lv > MW;
        if (hCorr == vCorr) continue;                  // crossing box, or tiny stub: no centre markings
        var x0 = c * CELL - half, x1 = x0 + CELL;
        var z0 = r * CELL - half, z1 = z0 + CELL;
        if (hCorr) {                                   // E-W corridor: band runs in z, lines along x
          var W = Lv; if (W != 2 && W != 4) continue;
          var r0 = r; while (isR(r0 - 1, c)) r0--;
          var k = r - r0;
          var mouth = inter(r, c + 1) || inter(r, c - 1);
          if (!mouth) laneLine(x0, x1, z1, W, k, true); // line at this cell's south edge (skip in the crosswalk cell)
          if (k == 0) {                                // crosswalk spans the full band once
            var zTop = r0 * CELL - half, zBot = (r0 + W) * CELL - half;
            if (inter(r, c + 1)) crossing(zTop, zBot, x1, 1, true);
            if (inter(r, c - 1)) crossing(zTop, zBot, x0, -1, true);
          }
        } else {                                       // N-S corridor: band runs in x, lines along z
          var W = Lh; if (W != 2 && W != 4) continue;
          var c0 = c; while (isR(r, c0 - 1)) c0--;
          var k = c - c0;
          var mouth = inter(r + 1, c) || inter(r - 1, c);
          if (!mouth) laneLine(z0, z1, x1, W, k, false); // line at this cell's east edge (skip in the crosswalk cell)
          if (k == 0) {
            var xL = c0 * CELL - half, xR = (c0 + W) * CELL - half;
            if (inter(r + 1, c)) crossing(xL, xR, z1, 1, false);
            if (inter(r - 1, c)) crossing(xL, xR, z0, -1, false);
          }
        }
      }
    }

    // --- emit the kerb-edging strip with mitered joins ----------------------
    // each curb segment's inner edge stays on the walkway boundary; its outer edge is
    // offset BW onto the road. at a shared boundary vertex the two segments' outer
    // edges meet at the miter point V + BW·(n1+n2)/(1+n1·n2) — the intersection of
    // their offset lines — so they abut exactly: no gap (convex) and no overlap (concave)
    inline function vkey(x:Float, z:Float):String return Std.string(Math.round(x * 16)) + '_' + Std.string(Math.round(z * 16));
    var vmap = new Map<String, Array<{s:Int, e:Int}>>();
    inline function addV(k:String, s:Int, e:Int):Void {
      var a = vmap.get(k); if (a == null) { a = []; vmap.set(k, a); } a.push({s: s, e: e});
    }
    for (i in 0...curbs.length) { var c = curbs[i]; addV(vkey(c.ax, c.az), i, 0); addV(vkey(c.bx, c.bz), i, 1); }
    function outer(i:Int, e:Int):{x:Float, z:Float} {
      var c = curbs[i];
      var vx = e == 0 ? c.ax : c.bx, vz = e == 0 ? c.az : c.bz;
      var list = vmap.get(vkey(vx, vz));
      var oj = -1, cnt = 0;
      if (list != null) for (it in list) if (!(it.s == i && it.e == e)) { oj = it.s; cnt++; }
      if (cnt == 1 && oj >= 0) {
        var nj = curbs[oj];
        var denom = 1 + c.nx * nj.nx + c.nz * nj.nz;
        if (denom > 0.25) return { x: vx + (c.nx + nj.nx) / denom * BW, z: vz + (c.nz + nj.nz) / denom * BW };
      }
      return { x: vx + c.nx * BW, z: vz + c.nz * BW }; // square end (dangling or >2-way junction)
    }
    for (i in 0...curbs.length) {
      var c = curbs[i];
      var oA = outer(i, 0), oB = outer(i, 1);
      var ul = Math.sqrt((c.bx - c.ax) * (c.bx - c.ax) + (c.bz - c.az) * (c.bz - c.az)) / BT;
      quad(borderBuf, [c.ax, H, c.az], [oA.x, H, oA.z], [oB.x, H, oB.z], [c.bx, H, c.bz], [0, 1, 0, 0, ul, 0, ul, 1]);
      quad(borderBuf, [oA.x, 0, oA.z], [oB.x, 0, oB.z], [oB.x, H, oB.z], [oA.x, H, oA.z], [0, 0, ul, 0, ul, 1, 0, 1]);
    }

    for (i in 0...types.length) {
      var b = bufs[i];
      if (b.idx.length == 0) continue;
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(b.pos, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(b.uv, 2));
      geo.setIndex(b.idx);
      geo.computeVertexNormals();
      var map = Textures.loadTexture(types[i].tex, types[i].kind, 1);
      addRecv(new Mesh(geo, new MeshLambertMaterial({ map: map, side: THREE.DoubleSide })));
    }

    if (borderBuf.idx.length > 0) {
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(borderBuf.pos, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(borderBuf.uv, 2));
      geo.setIndex(borderBuf.idx);
      geo.computeVertexNormals();
      var map = Textures.loadTexture(st.walkwayBorder, 'wall', 1);
      addRecv(new Mesh(geo, new MeshLambertMaterial({ map: map, side: THREE.DoubleSide })));
    }

    if (markBuf.idx.length > 0) {
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(markBuf.pos, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(markBuf.uv, 2));
      geo.setIndex(markBuf.idx);
      geo.computeVertexNormals();
      var map = Textures.loadTexture(st.roadPaint, 'asphalt', 1);
      // opaque + non-emissive: lit like the road, so it darkens at night / brightens by day with
      // the lighting. the texture's keyed scuff pixels render as opaque grey wear (no cutout jaggies)
      addRecv(new Mesh(geo, new MeshLambertMaterial({ map: map, side: THREE.DoubleSide })));
    }
  }
}
