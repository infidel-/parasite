package citygen;

import citygen.CityConfig.*;
import citygen.CityModel;

// a road line: position + width along its own axis; [a, b) is the extent it
// occupies on the perpendicular axis (full span by default; shortened for dead-ends)
typedef RoadLine = { pos:Int, w:Int, a:Int, b:Int, ?turn:Bool };

// an L-turn footprint: the vertical stub remaining inside the partial band + the
// horizontal connector that carries it sideways to a neighbour road. Both rects are
// painted as road and subtracted from any overlapping building (reusing subtractRect)
typedef Turn = { sx0:Int, sy0:Int, sx1:Int, sy1:Int, cx0:Int, cy0:Int, cx1:Int, cy1:Int };

// seeded procedural city generator. Faithful port of the original config.js:
// variable-spaced roads divide the map into uneven blocks (one main road per
// axis); each block is recursively subdivided into building footprints with
// 1-cell alley gaps and road setbacks; some leaves become U-courtyards or L's,
// some finished blocks get a central courtyard carved out; free cells classify
// as walkway (touching a road) or alley; landlocked buildings are dropped.
// mulberry32(1337) keeps the layout stable across runs
class CityGen {
  static inline function imul(a:Int, b:Int):Int return js.Syntax.code("Math.imul({0}, {1})", a, b);

  public static function mulberry32(seed:Int):Void->Float {
    var a = seed;
    return function():Float {
      a = a | 0; a = (a + 0x6D2B79F5) | 0;
      var t = imul(a ^ (a >>> 15), 1 | a);
      t = (t + imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  static function fillRect(tiles:Array<Array<Tile>>, x0:Int, y0:Int, w:Int, h:Int, val:Tile):Void {
    for (r in y0...y0 + h) for (c in x0...x0 + w)
      if (r >= 0 && c >= 0 && r < GRID && c < GRID) tiles[r][c] = val;
  }

  static function locatorFor(pieces:Array<Building>):PShape {
    var x0 = pieces[0].col, y0 = pieces[0].row;
    var x1 = pieces[0].col + pieces[0].w - 1, y1 = pieces[0].row + pieces[0].d - 1;
    for (b in pieces) {
      if (b.col < x0) x0 = b.col;
      if (b.row < y0) y0 = b.row;
      if (b.col + b.w - 1 > x1) x1 = b.col + b.w - 1;
      if (b.row + b.d - 1 > y1) y1 = b.row + b.d - 1;
    }
    var cw = cellToWorld((x0 + x1) / 2, (y0 + y1) / 2);
    var w = x1 - x0 + 1, d = y1 - y0 + 1;
    return { x: cw.x, z: cw.z, r: (w > d ? w : d) * CELL / 2 };
  }

  // recursively split a block rect into building footprints. `full` = still the
  // whole un-split block (so it shouldn't become an L with a back courtyard)
  static function subdivide(x0:Int, y0:Int, x1:Int, y1:Int, depth:Int, rng:Void->Float,
      out:Array<Building>, pOut:Array<PGroup>, lOut:Array<ShapeGroup>, tOut:Array<ShapeGroup>, plusOut:Array<ShapeGroup>,
      nearMaxStreet:(Int, Int, Int, Int, Bool) -> Bool, nearestStreetSide:(Int, Int, Int, Int) -> Int,
      full:Bool = true):Void {
    var w = x1 - x0 + 1;
    var d = y1 - y0 + 1;

    // floors/roof/facade draw rng ONLY when a leaf is produced (matches JS: these
    // live inside leaf()). Hoisting them would consume rng on internal nodes too
    // and desync the whole seeded stream
    function leaf():Void {
      var floors = MIN_FLOORS + Std.int(rng() * (MAX_FLOORS - MIN_FLOORS + 1));
      var roof = rng() < 0.5 ? 0 : 1;
      var facade = Std.int(rng() * 4); // 0 concrete, 1 brick, 2 stone, 3 metal (one rng draw → stream stays in sync)
      // small/thin footprints stay low: cap total floors by the smaller side
      inline function mk(col:Int, row:Int, bw:Int, bd:Int, ?winForce:Array<Int>, ?winBlock:Array<Int>, winInset:Float = 0):Building {
        var m = bw < bd ? bw : bd;
        var cap = m <= 3 ? m : MAX_FLOORS;
        var vc = MAX_FLOORS_VARIANT[facade]; if (cap > vc) cap = vc; // per-facade storey cap
        var f = floors < cap ? floors : cap;
        // metal warehouses: vary 2 or 3 stories (1–2 window floors) instead of always 2,
        // keyed off the existing floors draw (no extra rng → stream stays in sync)
        if (facade == 3) f = (floors % 2 == 0) ? 2 : 1;
        return new Building(col, row, bw, bd, GROUND_H + f * FLOOR_H + TOP_MARGIN, roof, facade, winForce, winBlock, winInset);
      }
      var t = COURTYARD_WALL;
      // courtyard: a U of 3 wall-strips (one side left open); inner faces get windows
      if (w >= 2 * t + 3 && d >= 2 * t + 3 && rng() < COURTYARD_CHANCE) {
        var strips = [
          mk(x0, y0, w, t, [0], null, t * CELL),            // top    (inner +z)
          mk(x0, y1 - t + 1, w, t, [1], null, t * CELL),    // bottom (inner -z)
          mk(x0, y0 + t, t, d - 2 * t, [2]),                // left   (inner +x)
          mk(x1 - t + 1, y0 + t, t, d - 2 * t, [3]),        // right  (inner -x)
        ];
        var omit = Std.int(rng() * 4);
        var grp:Array<Building> = [];
        for (i in 0...strips.length) if (i != omit) { out.push(strips[i]); grp.push(strips[i]); }
        // centre = the strip opposite the opening (top↔bottom, left↔right)
        finishP(grp, (omit == 0) ? 1 : (omit == 1) ? 0 : (omit == 2) ? 3 : 2, rng);
        var cw = cellToWorld(x0 + (w - 1) / 2, y0 + (d - 1) / 2);
        pOut.push({ strips: grp, ps: { x: cw.x, z: cw.z, r: (w > d ? w : d) * CELL / 2 } });
        return;
      }
      // L-shape with a back-courtyard notch (non-full-block leaves only)
      if (!full && w >= 7 && d >= 7 && rng() < L_CHANCE) {
        var right = rng() < 0.5;
        var bottom = rng() < 0.5;
        var nw = 3 + Std.int(rng() * (w - 5));
        var nh = 3 + Std.int(rng() * (d - 5));
        var colArm = right ? x0 : x0 + nw;
        var rowArm = bottom ? y0 + (d - nh) : y0;
        var rowBand = bottom ? y0 : y0 + nh;
        var grp = [
          mk(x0, rowBand, w, d - nh, null, [bottom ? 0 : 1]),     // full-width band
          mk(colArm, rowArm, w - nw, nh, null, [right ? 2 : 3]),  // arm beside the notch
        ];
        for (p in grp) out.push(p);
        lOut.push({ pieces: grp, ps: locatorFor(grp) });
        return;
      }
      // a shape piece at an explicit floor count (bypasses the small-side cap so a
      // narrow stem/centre can rise); clamped to the facade's storey max
      inline function piece(col:Int, row:Int, bw:Int, bd:Int, fl:Int):Building {
        var typeMax = MAX_FLOORS_VARIANT[facade];
        if (fl > typeMax) fl = typeMax;
        if ((bw < bd ? bw : bd) <= 2 && fl > 3) fl = 3; // 2-wide stem/arm stays <=3 storeys
        if (fl < MIN_FLOORS) fl = MIN_FLOORS;
        return new Building(col, row, bw, bd, GROUND_H + fl * FLOOR_H + TOP_MARGIN, roof, facade);
      }
      // T-shape: a full-width crossbar + a centred stem (the "middle line"), shorter
      // than the crossbar's side arms. Stem hangs below by default; CHANCE it sits above
      if (w >= 7 && d >= 7 && rng() < T_CHANCE) {
        var cb = 3, sw = 3;
        rng(); // ponytail: keep seeded stream stable after deterministic T orientation
        var grp:Array<Building>;
        var frontDir = nearestStreetSide(x0, y0, x1, y1);
        switch (frontDir) {
          case 2, 3:
            var arm = Std.int((d - sw) / 2);
            var barD = sw + 2 * arm;
            var by0 = y0 + Std.int((d - barD) / 2);
            var sy = by0 + arm;
            var sl = Std.int((w - cb) * 0.6);
            if (sl < 2) sl = 2;
            if (sl > arm) sl = arm;
            var rightStreet = frontDir == 2;
            var barCol = rightStreet ? (x1 - cb + 1) : x0;
            var stemCol = rightStreet ? (x1 - cb + 1 - sl) : (x0 + cb);
            grp = [
              piece(barCol, by0, cb, barD, floors),
              piece(stemCol, sy, sl, sw, floors),
            ];
          default:
            var arm = Std.int((w - sw) / 2);
            var barW = sw + 2 * arm;
            var bx0 = x0 + Std.int((w - barW) / 2);
            var sx = bx0 + arm;
            var sl = Std.int((d - cb) * 0.6);
            if (sl < 2) sl = 2;
            if (sl > arm) sl = arm;
            var bottomStreet = frontDir == 0;
            var barRow = bottomStreet ? (y1 - cb + 1) : y0;
            var stemRow = bottomStreet ? (y1 - cb + 1 - sl) : (y0 + cb);
            grp = [
              piece(bx0, barRow, barW, cb, floors),
              piece(sx, stemRow, sw, sl, floors),
            ];
        }
        for (p in grp) out.push(p);
        tOut.push({ pieces: grp, ps: locatorFor(grp), frontDir: frontDir });
        return;
      }
      // plus: crossing bars with an optionally taller centre ("middle point going up")
      if (w >= 7 && d >= 7 && rng() < PLUS_CHANCE) {
        var qx0 = x0, qy0 = y0, qx1 = x1, qy1 = y1;
        var side = w < d ? w : d;
        var arm = Std.int((side - 3) / 2);
        side = 3 + 2 * arm;
        if (w > side) {
          if (nearMaxStreet(x0, y0, x1, y1, true)) qx0 = x1 - side + 1;
          else qx1 = x0 + side - 1;
        }
        if (d > side) {
          if (nearMaxStreet(x0, y0, x1, y1, false)) qy0 = y1 - side + 1;
          else qy1 = y0 + side - 1;
        }
        var vb = 3, hb = 3;
        var pw = qx1 - qx0 + 1, pd = qy1 - qy0 + 1;
        var cx = qx0 + Std.int((pw - vb) / 2), cy = qy0 + Std.int((pd - hb) / 2);
        // centre rises 0/1/2 floors above the LEAVES — measured against the
        // shortest arm's actual (clamped) height, so a thin arm capped by the
        // 2-wide rule can't leave the centre towering far above it
        inline function effFloors(bw:Int, bd:Int):Int {
          var f = floors;
          var tm = MAX_FLOORS_VARIANT[facade];
          if (f > tm) f = tm;
          if ((bw < bd ? bw : bd) <= 2 && f > 3) f = 3;
          if (f < MIN_FLOORS) f = MIN_FLOORS;
          return f;
        }
        var leaf = effFloors(cx - qx0, hb);
        for (e in [effFloors(qx1 - (cx + vb) + 1, hb), effFloors(vb, cy - qy0), effFloors(vb, qy1 - (cy + hb) + 1)])
          if (e < leaf) leaf = e;
        var cf = leaf;
        if (rng() < 0.5) cf = leaf + 1 + Std.int(rng() * 2);            // centre rises
        var centre = piece(cx, cy, vb, hb, cf);
        if (cf > leaf) centre.skipWindowFloor = leaf;
        var grp = [
          piece(qx0, cy, cx - qx0, hb, floors),                    // left arm
          piece(cx + vb, cy, qx1 - (cx + vb) + 1, hb, floors),    // right arm
          piece(cx, qy0, vb, cy - qy0, floors),                    // top arm
          piece(cx, cy + hb, vb, qy1 - (cy + hb) + 1, floors),    // bottom arm
          centre,                                                // centre
        ];
        for (p in grp) p.winForce = [0, 1, 2, 3];
        for (p in grp) out.push(p);
        plusOut.push({ pieces: grp, ps: locatorFor(grp) });
        return;
      }
      var b = mk(x0, y0, w, d);
      // single-story shop: only when the STREET-facing side is 2 or 4 tiles, so a 2-cell-
      // wide 16:9 storefront tiles a whole number of times across it (no odd 3-tile face),
      // and the depth is shallow (<=2). street side chosen by nearestStreetSide.
      var front = nearestStreetSide(x0, y0, x1, y1);      // 0=+z,1=-z,2=+x,3=-x
      var streetLen = (front == 2 || front == 3) ? d : w; // tiles along the storefront face
      var shopDepth = (front == 2 || front == 3) ? w : d; // perpendicular depth
      if ((streetLen == 2 || streetLen == 4) && shopDepth <= 2 && rng() < DOWNGRADE_CHANCE) {
        b.shop = Std.int(rng() * SHOP_TYPES);
        b.shopOpen = rng() < SHOP_OPEN_CHANCE;
        b.shopDoor = Std.int(rng() * 0x7fffffff); // entrance-cell selector
        b.h = SHOP_H; // raised so the 16:9 storefront fills the face width edge-to-edge
      }
      out.push(b);
    }

    var big = w > SPLIT_OVER || d > SPLIT_OVER;
    var capW = w > MAX_BUILDING, capD = d > MAX_BUILDING; // hard cap on either axis
    if (!capW && !capD && (depth <= 0 || (w < 7 && d < 7) || (!full && !big && rng() < EARLY_LEAF_CHANCE))) { leaf(); return; }
    // force a split along any over-cap axis (wider one first); else normal big-block split
    if (capW || (!capD && w >= d && w >= 7)) {
      var cut = x0 + 3 + Std.int(rng() * (w - 6));
      subdivide(x0, y0, cut, y1, depth - 1, rng, out, pOut, lOut, tOut, plusOut, nearMaxStreet, nearestStreetSide, false);
      subdivide(cut + 2, y0, x1, y1, depth - 1, rng, out, pOut, lOut, tOut, plusOut, nearMaxStreet, nearestStreetSide, false);
    } else if (capD || d >= 7) {
      var cut = y0 + 3 + Std.int(rng() * (d - 6));
      subdivide(x0, y0, x1, cut, depth - 1, rng, out, pOut, lOut, tOut, plusOut, nearMaxStreet, nearestStreetSide, false);
      subdivide(x0, cut + 2, x1, y1, depth - 1, rng, out, pOut, lOut, tOut, plusOut, nearMaxStreet, nearestStreetSide, false);
    } else {
      leaf();
    }
  }

  // subtract courtyard rect from building b -> parts OUTSIDE the courtyard, each
  // tagged winBlock on its court-facing side. [b] if no overlap, [] if fully inside
  static function subtractRect(b:Building, cx0:Int, cy0:Int, cx1:Int, cy1:Int, tag:Bool = true):Array<Building> {
    var bx0 = b.col, by0 = b.row, bx1 = b.col + b.w - 1, by1 = b.row + b.d - 1;
    var ix0 = Std.int(Math.max(bx0, cx0)), iy0 = Std.int(Math.max(by0, cy0));
    var ix1 = Std.int(Math.min(bx1, cx1)), iy1 = Std.int(Math.min(by1, cy1));
    if (ix0 > ix1 || iy0 > iy1) return [b]; // no overlap
    var out = [];
    inline function piece(col:Int, row:Int, w:Int, d:Int, dir:Int)
      out.push(new Building(col, row, w, d, b.h, b.roof, b.facade, null, tag ? [dir] : null));
    if (ix0 > bx0) piece(bx0, by0, ix0 - bx0, b.d, 2);              // left strip  (court at +x)
    if (ix1 < bx1) piece(ix1 + 1, by0, bx1 - ix1, b.d, 3);         // right strip (court at -x)
    if (iy0 > by0) piece(ix0, by0, ix1 - ix0 + 1, iy0 - by0, 0);   // top strip   (court at +z)
    if (iy1 < by1) piece(ix0, iy1 + 1, ix1 - ix0 + 1, by1 - iy1, 1); // bottom strip (court at -z)
    return out;
  }

  // shared П finishing for both courtyard sources (leaf U + reshaped): (a) inner
  // courtyard-facing walls become windowed (winForce, windows on every floor but the
  // ground) and (b) the centre strip — the bar opposite the opening, identified by
  // centreDir — grows/shrinks ±2 floors, clamped to [MIN_FLOORS, type max]
  static function finishP(strips:Array<Building>, centreDir:Int, rng:Void->Float):Void {
    for (s in strips) if (s.winBlock != null) { s.winForce = s.winBlock; s.winBlock = null; }
    for (s in strips) if (s.winForce != null && s.winForce[0] == centreDir) {
      var typeMax = s.facade == 1 ? MAX_FLOORS_BRICK : MAX_FLOORS;
      var f = Math.round((s.h - GROUND_H - TOP_MARGIN) / FLOOR_H) + Std.int(rng() * 5) - 2;
      if (f < MIN_FLOORS) f = MIN_FLOORS;
      if (f > typeMax) f = typeMax;
      s.h = GROUND_H + f * FLOOR_H + TOP_MARGIN;
    }
  }

  // reshape one oversized plain rectangle: a П-shaped courtyard (COURT_RING frame on
  // three sides, open on one) when it fits, otherwise an L with one corner notched out.
  // `open` (0 top/1 bottom/2 left/3 right) = which edge the П opens toward — chosen by
  // the caller to face an interior side so the walled three sides face the street. ps
  // is the П locator (null for the L fallback)
  static function reshapeLarge(b:Building, rng:Void->Float, open:Int):{ pieces:Array<Building>, ps:PShape } {
    if (b.w >= 2 * COURT_RING + COURT_MIN && b.d >= 2 * COURT_RING + COURT_MIN && rng() < 0.6) {
      // cut flush to one edge → subtractRect drops that strip, leaving a П. baseDir =
      // the strip opposite the opening (the connecting bar = the П's centre piece)
      var cx0 = b.col + COURT_RING, cx1 = b.col + b.w - 1 - COURT_RING;
      var cy0 = b.row + COURT_RING, cy1 = b.row + b.d - 1 - COURT_RING;
      var baseDir = 0;
      switch (open) {
        case 0: cy0 = b.row; baseDir = 1;                 // open top   → base -z
        case 1: cy1 = b.row + b.d - 1; baseDir = 0;       // open bottom→ base +z
        case 2: cx0 = b.col; baseDir = 3;                 // open left  → base -x
        default: cx1 = b.col + b.w - 1; baseDir = 2;      // open right → base +x
      }
      var pieces = subtractRect(b, cx0, cy0, cx1, cy1);
      finishP(pieces, baseDir, rng);
      var cw = cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);
      return { pieces: pieces, ps: { x: cw.x, z: cw.z, r: (b.w > b.d ? b.w : b.d) * CELL / 2 } };
    }
    var nw = 3 + Std.int(rng() * (b.w - 5)); // notch sits at a corner, leaving >=3 on each kept band
    var nh = 3 + Std.int(rng() * (b.d - 5));
    var cx0 = rng() < 0.5 ? b.col : b.col + b.w - nw;
    var cy0 = rng() < 0.5 ? b.row : b.row + b.d - nh;
    return { pieces: subtractRect(b, cx0, cy0, cx0 + nw - 1, cy0 + nh - 1), ps: null };
  }

  // try to carve a central courtyard from an already-composed block. Returns the
  // new building list, or null if no carve leaves every CLIPPED building >= 3
  static function carveCourtyard(blockBuildings:Array<Building>, x0:Int, y0:Int, x1:Int, y1:Int, rng:Void->Float, courtOut:Array<CourtRect>):Array<Building> {
    var maxCw = (x1 - x0 + 1) - 2 * COURT_RING;
    var maxCh = (y1 - y0 + 1) - 2 * COURT_RING;
    if (maxCw < COURT_MIN || maxCh < COURT_MIN) return null;
    for (_ in 0...CARVE_TRIES) {
      var cw = COURT_MIN + Std.int(rng() * (maxCw - COURT_MIN + 1));
      var ch = COURT_MIN + Std.int(rng() * (maxCh - COURT_MIN + 1));
      var cx0 = x0 + COURT_RING + Std.int(rng() * (maxCw - cw + 1));
      var cy0 = y0 + COURT_RING + Std.int(rng() * (maxCh - ch + 1));
      var cx1 = cx0 + cw - 1, cy1 = cy0 + ch - 1;
      var result = [];
      var ok = true, carved = false;
      for (b in blockBuildings) {
        var pieces = subtractRect(b, cx0, cy0, cx1, cy1);
        var clipped = !(pieces.length == 1 && pieces[0] == b);
        if (clipped) carved = true;
        for (p in pieces) {
          if (clipped && (p.w < 3 || p.d < 3)) { ok = false; break; }
          result.push(p);
        }
        if (!ok) break;
      }
      if (ok && carved) { courtOut.push({ x0: cx0, y0: cy0, x1: cx1, y1: cy1 }); return result; }
    }
    return null;
  }

  // one axis of roads: intervals with variable gaps, one interior road widened to main
  static function roadLines(len:Int, rng:Void->Float):Array<RoadLine> {
    var lines:Array<RoadLine> = [];
    var p = 0;
    while (p < len) {
      lines.push({ pos: p, w: ROAD_W, a: 0, b: len });
      p += ROAD_W + MIN_BLOCK + Std.int(rng() * (MAX_BLOCK - MIN_BLOCK + 1));
    }
    if (lines.length > 2) lines[1 + Std.int(rng() * (lines.length - 2))].w = MAIN_ROAD_W;
    return lines;
  }

  public static function generate(seed:Int = 1337):City {
    var rng = mulberry32(seed);
    var vroads = roadLines(GRID, rng); // columns
    var hroads = roadLines(GRID, rng); // rows

    // each non-main interior vertical road gets ONE treatment: first try an L-turn
    // (bend mid-block, a horizontal connector carrying it to a full-span neighbour),
    // else maybe dead-end (drop a terminal block-band so it stops at an interior
    // intersection). Turn goes first so it draws from the whole pool, not the dead-end
    // leftovers. Both keep the map centre and every merged block rectangular
    var turns:Array<Turn> = [];
    var turnspots:Array<PShape> = [];
    for (vi in 1...vroads.length) {
      var v = vroads[vi];
      if (v.w == MAIN_ROAD_W) continue;

      // --- L-turn attempt -----------------------------------------------------
      if (hroads.length >= 3 && rng() < TURN_CHANCE) {
        // a full-span neighbour vertical road to connect into
        var cands = [];
        if (vi > 0) { var l = vroads[vi - 1]; if (l.a == 0 && l.b >= GRID) cands.push(l); }
        if (vi + 1 < vroads.length) { var rr = vroads[vi + 1]; if (rr.a == 0 && rr.b >= GRID) cands.push(rr); }
        // interior bands tall enough to keep a real (>=3-deep) building strip between
        // the connector and BOTH bordering roads — else a turn leaves a thin empty
        // pocket (6-cell margin each side once dilated)
        var bands = [for (bi in 1...hroads.length) {
          var a = hroads[bi].pos + hroads[bi].w;
          var b = (bi + 1 < hroads.length ? hroads[bi + 1].pos : GRID);
          if (b - a >= 14) bi else continue;
        }];
        if (cands.length > 0 && bands.length > 0) {
          var vn = cands[Std.int(rng() * cands.length)];
          var bi = bands[Std.int(rng() * bands.length)];
          var bandA = hroads[bi].pos + hroads[bi].w;
          var bandB = (bi + 1 < hroads.length ? hroads[bi + 1].pos : GRID);
          var turnRow = bandA + 6 + Std.int(rng() * (bandB - bandA - 12));
          var sx0 = v.pos, sx1 = v.pos + v.w - 1;
          var cx0 = (v.pos < vn.pos ? v.pos : vn.pos);
          var cx1 = (v.pos < vn.pos ? vn.pos + vn.w : v.pos + v.w) - 1;
          if (rng() < 0.5) { // top removed: road runs up from below to turnRow, then turns
            v.a = turnRow;
            turns.push({ sx0: sx0, sy0: turnRow, sx1: sx1, sy1: bandB - 1,
                         cx0: cx0, cy0: turnRow, cx1: cx1, cy1: turnRow + v.w - 1 });
          } else {           // bottom removed: road runs down from above to turnRow, then turns
            v.b = turnRow + v.w;
            turns.push({ sx0: sx0, sy0: bandA, sx1: sx1, sy1: turnRow + v.w - 1,
                         cx0: cx0, cy0: turnRow, cx1: cx1, cy1: turnRow + v.w - 1 });
          }
          v.turn = true;
          var cw = cellToWorld((cx0 + cx1) / 2, turnRow + (v.w - 1) / 2);
          turnspots.push({ x: cw.x, z: cw.z, r: (cx1 - cx0 + 1) * CELL / 2 + 8 });
          continue; // turned → no dead-end
        }
      }

      // --- dead-end fallback --------------------------------------------------
      if (hroads.length >= 2 && rng() < DEADEND_CHANCE) {
        if (rng() < 0.5) v.a = hroads[1].pos;                                          // top tip removed
        else v.b = hroads[hroads.length - 1].pos + hroads[hroads.length - 1].w;        // bottom tip removed
      }
    }

    // 2D road grid (vertical roads honour their [a, b) row extent; horizontals span)
    var road = [for (_ in 0...GRID) [for (_ in 0...GRID) false]];
    for (v in vroads) {
      var r = v.a;
      while (r < v.b && r < GRID) {
        var c = v.pos; while (c < v.pos + v.w && c < GRID) { road[r][c] = true; c++; }
        r++;
      }
    }
    for (h in hroads) { var r = h.pos; while (r < h.pos + h.w && r < GRID) { for (c in 0...GRID) road[r][c] = true; r++; } }
    for (t in turns) for (r in t.cy0...t.cy1 + 1) for (c in t.cx0...t.cx1 + 1) if (r < GRID && c < GRID) road[r][c] = true; // L-turn connectors
    inline function isRoad(c:Int, r:Int):Bool return road[r][c];
    function nearMaxStreet(x0:Int, y0:Int, x1:Int, y1:Int, wide:Bool):Bool {
      function distX(c0:Int, step:Int):Int {
        var c = c0, dist = 1;
        while (c >= 0 && c < GRID) {
          for (r in y0...y1 + 1) if (road[r][c]) return dist;
          c += step; dist++;
        }
        return GRID + 1;
      }
      function distY(r0:Int, step:Int):Int {
        var r = r0, dist = 1;
        while (r >= 0 && r < GRID) {
          for (c in x0...x1 + 1) if (road[r][c]) return dist;
          r += step; dist++;
        }
        return GRID + 1;
      }
      if (wide) return distX(x1 + 1, 1) <= distX(x0 - 1, -1);
      return distY(y1 + 1, 1) <= distY(y0 - 1, -1);
    }
    function nearestStreetSide(x0:Int, y0:Int, x1:Int, y1:Int):Int {
      function distX(c0:Int, step:Int):Int {
        var c = c0, dist = 1;
        while (c >= 0 && c < GRID) {
          for (r in y0...y1 + 1) if (road[r][c]) return dist;
          c += step; dist++;
        }
        return GRID + 1;
      }
      function distY(r0:Int, step:Int):Int {
        var r = r0, dist = 1;
        while (r >= 0 && r < GRID) {
          for (c in x0...x1 + 1) if (road[r][c]) return dist;
          r += step; dist++;
        }
        return GRID + 1;
      }
      var best = 1, bestDist = distY(y0 - 1, -1); // 1=-z/top
      var bottom = distY(y1 + 1, 1);
      if (bottom < bestDist) { best = 0; bestDist = bottom; } // 0=+z/bottom
      var right = distX(x1 + 1, 1);
      if (right < bestDist) { best = 2; bestDist = right; }  // 2=+x/right
      var left = distX(x0 - 1, -1);
      if (left < bestDist) best = 3;                         // 3=-x/left
      return best;
    }

    // blocks = rectangles between consecutive roads (set back), then maybe carve a
    // courtyard. Iterate row-bands so a dead-ended vertical road (absent in its
    // dropped band) simply isn't a cut there — its two neighbour blocks merge
    var buildings:Array<Building> = [];
    var courtyards:Array<CourtRect> = []; // carved inner-courtyard rects (enclosed open pockets)
    var pgroups:Array<PGroup> = []; // every П candidate (leaf U-courtyards + reshaped), validated later
    var lgroups:Array<ShapeGroup> = [], tgroups:Array<ShapeGroup> = [], plusgroups:Array<ShapeGroup> = []; // composite candidates, validated later
    for (hi in 0...hroads.length) {
      var y0 = hroads[hi].pos + hroads[hi].w + SETBACK;
      var y1 = (hi + 1 < hroads.length ? hroads[hi + 1].pos : GRID) - 1 - SETBACK;
      if (y1 - y0 < 2) continue;
      // the band's cross-road rows; a vertical road is a cut here only if it spans them
      var bandTop = hroads[hi].pos;
      // clamp to GRID: a road at the far edge (pos+w > GRID) would push bandBot past
      // any full road's b (= GRID), so the v.b >= bandBot cut filter finds nothing and
      // the whole band comes out empty
      var bandBot = Std.int(Math.min(GRID, (hi + 1 < hroads.length ? hroads[hi + 1].pos + hroads[hi + 1].w : GRID)));
      var cuts = [for (v in vroads) if (v.a <= bandTop && v.b >= bandBot) v];
      for (k in 0...cuts.length) {
        var x0 = cuts[k].pos + cuts[k].w + SETBACK;
        var x1 = (k + 1 < cuts.length ? cuts[k + 1].pos : GRID) - 1 - SETBACK;
        if (x1 - x0 < 2) continue;
        var block:Array<Building> = [];
        var blockP:Array<PGroup> = [];
        var blockL:Array<ShapeGroup> = [], blockT:Array<ShapeGroup> = [], blockPlus:Array<ShapeGroup> = [];
        subdivide(x0, y0, x1, y1, SUBDIV_DEPTH, rng, block, blockP, blockL, blockT, blockPlus, nearMaxStreet, nearestStreetSide);
        var carved = rng() < COURTYARD_BLOCK_CHANCE ? carveCourtyard(block, x0, y0, x1, y1, rng, courtyards) : null;
        // a carved block re-subtracts its buildings, so leaf-shape pieces may change
        // identity — only trust their locators when the block wasn't carved
        if (carved != null) for (b in carved) buildings.push(b);
        else {
          for (b in block) buildings.push(b);
          for (g in blockP) pgroups.push(g);
          for (g in blockL) lgroups.push(g);
          for (g in blockT) tgroups.push(g);
          for (g in blockPlus) plusgroups.push(g);
        }
      }
    }

    // carve the L-turn footprints out of any building they cross. Both rects are
    // dilated by SETBACK on ALL sides so a full pavement ring survives around the new
    // road — matching ordinary road setbacks — including the connector's free end,
    // which otherwise stops flush on a building wall (the truncated road left no
    // setback there). sub-2-wide slivers are dropped. tag=false: clipped faces front a
    // road, not a courtyard (no worn windows). Only the true cells were painted road
    for (t in turns) {
      var rects = [
        [t.sx0 - SETBACK, t.sy0 - SETBACK, t.sx1 + SETBACK, t.sy1 + SETBACK], // stub
        [t.cx0 - SETBACK, t.cy0 - SETBACK, t.cx1 + SETBACK, t.cy1 + SETBACK], // connector
      ];
      for (rect in rects) {
        var next:Array<Building> = [];
        for (b in buildings) for (p in subtractRect(b, rect[0], rect[1], rect[2], rect[3], false))
          if (p.w >= 2 && p.d >= 2) next.push(p);
        buildings = next;
      }
    }

    // no oversized blank boxes: any plain rectangle bigger than BIG_W x BIG_D becomes
    // an L or a П-courtyard (before tiling, so courtyard holes read as alley). The П
    // opening is steered toward a non-street side so its three walls face the street
    var occ = [for (_ in 0...GRID) [for (_ in 0...GRID) false]];
    for (b in buildings) for (rr in b.row...b.row + b.d) for (cc in b.col...b.col + b.w)
      if (rr >= 0 && cc >= 0 && rr < GRID && cc < GRID) occ[rr][cc] = true;
    inline function roadAt(c:Int, r:Int):Bool return c >= 0 && r >= 0 && c < GRID && r < GRID && road[r][c];
    inline function streetCell(c:Int, r:Int):Bool {
      if (roadAt(c, r)) return true;
      if (c < 0 || r < 0 || c >= GRID || r >= GRID || occ[r][c]) return false;
      return roadAt(c + 1, r) || roadAt(c - 1, r) || roadAt(c, r + 1) || roadAt(c, r - 1); // walkway
    }
    var shaped:Array<Building> = [];
    for (b in buildings) {
      var big = (b.w > BIG_W || b.d > BIG_W) && (b.w > BIG_D && b.d > BIG_D);
      if (b.winForce != null || b.winBlock != null || !big) { shaped.push(b); continue; }
      // which of b's four sides face a street; opening should avoid those
      var sN = false, sS = false, sW = false, sE = false;
      for (cc in b.col...b.col + b.w) { if (streetCell(cc, b.row - 1)) sN = true; if (streetCell(cc, b.row + b.d)) sS = true; }
      for (rr in b.row...b.row + b.d) { if (streetCell(b.col - 1, rr)) sW = true; if (streetCell(b.col + b.w, rr)) sE = true; }
      var cand = [];
      if (!sN) cand.push(0); if (!sS) cand.push(1); if (!sW) cand.push(2); if (!sE) cand.push(3);
      var open = cand.length > 0 ? cand[Std.int(rng() * cand.length)] : Std.int(rng() * 4);
      var res = reshapeLarge(b, rng, open);
      for (p in res.pieces) shaped.push(p);
      if (res.ps != null) pgroups.push({ strips: res.pieces, ps: res.ps });
    }
    buildings = shaped;

    // tile grid: roads, then buildings, then WALKWAY if touching a road else ALLEY
    var tiles:Array<Array<Tile>> = [for (r in 0...GRID) [for (c in 0...GRID) isRoad(c, r) ? Tile.Road : Tile.Walkway]];
    for (b in buildings) fillRect(tiles, b.col, b.row, b.w, b.d, Tile.Building);
    // 8-neighbour: diagonals included so the pavement wraps convex road corners
    // (an L-turn / dead-end tip outer corner touches its road only diagonally)
    function touchesRoad(c:Int, r:Int):Bool {
      for (dr in -1...2) for (dc in -1...2) {
        var cc = c + dc, rr = r + dr;
        if ((dc != 0 || dr != 0) && cc >= 0 && rr >= 0 && cc < GRID && rr < GRID && isRoad(cc, rr)) return true;
      }
      return false;
    }
    for (r in 0...GRID) for (c in 0...GRID)
      if (tiles[r][c] == Tile.Walkway && !touchesRoad(c, r)) tiles[r][c] = Tile.Alley;

    // drop landlocked buildings (no wall facing a road/walkway); cells revert to alley
    inline function isStreet(c:Int, r:Int):Bool
      return c >= 0 && r >= 0 && c < GRID && r < GRID && (tiles[r][c] == Tile.Road || tiles[r][c] == Tile.Walkway);
    function hasOuter(b:Building):Bool {
      for (c in b.col...b.col + b.w) if (isStreet(c, b.row - 1) || isStreet(c, b.row + b.d)) return true;
      for (r in b.row...b.row + b.d) if (isStreet(b.col - 1, r) || isStreet(b.col + b.w, r)) return true;
      return false;
    }
    function faceStreet(b:Building, dir:Int):Bool {
      switch (dir) {
        case 0:
          for (c in b.col...b.col + b.w) if (!isStreet(c, b.row + b.d)) return false;
        case 1:
          for (c in b.col...b.col + b.w) if (!isStreet(c, b.row - 1)) return false;
        case 2:
          for (r in b.row...b.row + b.d) if (!isStreet(b.col + b.w, r)) return false;
        default:
          for (r in b.row...b.row + b.d) if (!isStreet(b.col - 1, r)) return false;
      }
      return true;
    }
    // a П survives only if all three strips face the street; if any wouldn't, the rest
    // are a degenerate || — mark the whole group to drop and skip the locator entry
    // (an any-outer relaxation was tried and reverted: it kept П's buried against
    // neighbours, which read as broken blocks, not courtyards)
    var pshapes:Array<PShape> = [];
    for (g in pgroups) {
      var whole = true;
      for (s in g.strips) if (buildings.indexOf(s) < 0 || !hasOuter(s)) { whole = false; break; }
      if (whole) pshapes.push(g.ps);
      else for (s in g.strips) s.drop = true;
    }
    function keepComposite(groups:Array<ShapeGroup>):Array<PShape> {
      var out:Array<PShape> = [];
      for (g in groups) {
        var whole = true, outer = false;
        for (s in g.pieces) {
          if (buildings.indexOf(s) < 0) { whole = false; break; }
          if (hasOuter(s)) outer = true;
        }
        if (whole && g.frontDir != null && !faceStreet(g.pieces[0], g.frontDir)) whole = false;
        if (whole && outer) {
          for (s in g.pieces) s.shapeKeep = true;
          out.push(g.ps);
        } else {
          for (s in g.pieces) s.drop = true;
        }
      }
      return out;
    }
    var lshapes = keepComposite(lgroups);
    var tshapes = keepComposite(tgroups);
    var plusshapes = keepComposite(plusgroups);

    var kept:Array<Building> = [];
    for (b in buildings) {
      if (!b.drop && (b.shapeKeep || hasOuter(b))) { kept.push(b); continue; }
      fillRect(tiles, b.col, b.row, b.w, b.d, Tile.Alley);
    }
    buildings = kept;

    // metal warehouses must be clean STANDALONE rectangles (so they always gable + get a
    // door): drop the facade to concrete for thin footprints (either side < 3) AND for any
    // piece flush against a neighbouring building — an L/T/+/courtyard/carved fragment shares
    // an edge with a sibling, whereas a true standalone building has a SETBACK gap all round.
    function flushNeighbour(b:Building):Bool {
      inline function bld(c:Int, r:Int):Bool return c >= 0 && r >= 0 && c < GRID && r < GRID && tiles[r][c] == Tile.Building;
      for (c in b.col...b.col + b.w) if (bld(c, b.row - 1) || bld(c, b.row + b.d)) return true;
      for (r in b.row...b.row + b.d) if (bld(b.col - 1, r) || bld(b.col + b.w, r)) return true;
      return false;
    }
    for (b in buildings) if (b.facade == 3 && (b.w < 3 || b.d < 3 || flushNeighbour(b))) b.facade = 0;

    // drop blank boxes: a concrete/brick/stone building whose every wall is buried can show no
    // window at all (CityFaces.windowable is the same rule the render's window pass uses), and a
    // windowless box is an anomaly the checklist FAILs. runs AFTER the metal downgrade above so
    // `facade` is final — a warehouse demoted to concrete still owes windows — and after the
    // landlocked drop so `tiles` already reflect it. one pass suffices: reverting a footprint to
    // alley only ever UNBURIES its neighbours, so a drop can never create a new blank box.
    // shapeKeep composites are exempt, as at the landlocked drop: an L/T/+ survives or dies whole,
    // and pulling one buried piece out would leave a broken shape behind.
    var windowed:Array<Building> = [];
    for (b in buildings) {
      if (b.shapeKeep || CityFaces.windowable(tiles, b)) { windowed.push(b); continue; }
      fillRect(tiles, b.col, b.row, b.w, b.d, Tile.Alley);
    }
    buildings = windowed;

    // debug locators for the downgraded single-story shops (derived from the final
    // building list so it survives courtyard/L-turn re-subtraction). each carries a
    // `front` street cell (just outside the storefront) the cycler teleports the
    // player onto, so the building's real scale stays legible
    function shopSpot(b:Building):PShape {
      var ps = locatorFor([b]);
      var dir = -1;
      for (d in 0...4) if (faceStreet(b, d)) { dir = d; break; }
      if (dir < 0) return ps; // no street face → no player teleport
      var colC = Std.int(Math.round(b.col + (b.w - 1) / 2));
      var rowC = Std.int(Math.round(b.row + (b.d - 1) / 2));
      var fc = switch (dir) {     // street cell just outside the face centre
        case 0:  { col: colC, row: b.row + b.d };
        case 1:  { col: colC, row: b.row - 1 };
        case 2:  { col: b.col + b.w, row: rowC };
        default: { col: b.col - 1, row: rowC };
      };
      return { x: ps.x, z: ps.z, r: ps.r, front: fc };
    }
    var shopspots = [for (b in buildings) if (b.shop >= 0) shopSpot(b)];

    // lamp posts on the walkway edges flanking every road, both sides, ~LAMP_SPACING apart. dir points
    // from the post toward the road it lights. only on WALKWAY cells (not building/alley/road), deduped
    // where two roads' edges share a cell. posts+cones are instanced and lights pooled, so many is cheap
    var lamps:Array<Lamp> = [];
    var lampSet = new Map<Int, Bool>();
    inline function isRoad(c:Int, r:Int):Bool
      return c >= 0 && r >= 0 && c < GRID && r < GRID && tiles[r][c] == Tile.Road;
    inline function addLamp(c:Int, r:Int, dir:Int):Void {
      // never on a corner: if the walkway cell touches a crossing road along the walkway axis
      // (columns for h-roads, rows for v-roads), step one tile back down the walkway, away from it
      if (dir == 0 || dir == 1) {
        if (isRoad(c + 1, r)) c -= 1;
        else if (isRoad(c - 1, r)) c += 1;
      }
      else {
        if (isRoad(c, r + 1)) r -= 1;
        else if (isRoad(c, r - 1)) r += 1;
      }
      if (c < 0 || r < 0 || c >= GRID || r >= GRID) return;
      if (tiles[r][c] != Tile.Walkway) return;
      if (lamps.length >= MAX_LAMPS) return;
      var key = r * GRID + c;
      if (lampSet.exists(key)) return;
      lampSet.set(key, true);
      lamps.push({ col: c, row: r, dir: dir });
    }
    // horizontal roads span all columns: lamp on the walkway row above (road below = +z, dir 0) and
    // below (road above = -z, dir 1), stepping columns citywide-aligned so both edges line up
    for (h in hroads) {
      var c = 0;
      while (c < GRID) {
        addLamp(c, h.pos - 1, 0);
        addLamp(c, h.pos + h.w, 1);
        c += LAMP_SPACING;
      }
    }
    // vertical roads (row extent [a,b)): lamp on the walkway col left (road right = +x, dir 2) and
    // right (road left = -x, dir 3)
    for (v in vroads) {
      var r = v.a;
      while (r < v.b) {
        addLamp(v.pos - 1, r, 2);
        addLamp(v.pos + v.w, r, 3);
        r += LAMP_SPACING;
      }
    }

    // start on the road intersection nearest the center
    function near(arr:Array<RoadLine>):RoadLine {
      var a = arr[0];
      for (b in arr) if (Math.abs(b.pos - GRID / 2) < Math.abs(a.pos - GRID / 2)) a = b;
      return a;
    }
    var sv = near(vroads), sh = near(hroads);
    var deadends = 0;
    var turnCount = 0;
    for (v in vroads) {
      if (v.turn == true) turnCount++;
      else if (v.a > 0 || v.b < GRID) deadends++;
    }
    return {
      tiles: tiles, buildings: buildings, lamps: lamps,
      start: { col: sv.pos + (sv.w >> 1), row: sh.pos + (sh.w >> 1) },
      deadends: deadends,
      turns: turnCount,
      pshapes: pshapes,
      turnspots: turnspots,
      lshapes: lshapes,
      tshapes: tshapes,
      plusshapes: plusshapes,
      shopspots: shopspots,
      courtyards: courtyards,
    };
  }

  // reconstruct a City from a bare tile grid (old saves that predate the seed:
  // the rich shape metadata is gone, so buildings become plain greedy boxes with
  // deterministic per-cell height/facade). No debug locators.
  public static function fromTiles(tiles:Array<Array<Tile>>):City {
    var buildings:Array<Building> = [];
    var seen = [for (_ in 0...GRID) [for (_ in 0...GRID) false]];
    for (r in 0...GRID) for (c in 0...GRID) {
      if (tiles[r][c] != Tile.Building || seen[r][c]) continue;
      // grow a maximal rectangle of unclaimed building cells
      var w = 0;
      while (c + w < GRID && tiles[r][c + w] == Tile.Building && !seen[r][c + w]) w++;
      var d = 0;
      while (r + d < GRID) {
        var full = true;
        for (cc in c...c + w) if (tiles[r + d][cc] != Tile.Building || seen[r + d][cc]) { full = false; break; }
        if (!full) break;
        d++;
      }
      for (rr in r...r + d) for (cc in c...c + w) seen[rr][cc] = true;
      // deterministic look from the footprint origin (stable across reloads)
      var h = (c * 73856093) ^ (r * 19349663);
      var floors = 2 + ((h >>> 3) % 6);
      var facade = (h >>> 7) % 4;
      buildings.push(new Building(c, r, w, d, GROUND_H + floors * FLOOR_H + TOP_MARGIN, (h >>> 5) & 1, facade));
    }
    // start on a central-ish road cell (fallback to the grid centre)
    var start:Cell = { col: Std.int(GRID / 2), row: Std.int(GRID / 2) };
    return {
      tiles: tiles, buildings: buildings, lamps: [], start: start,
      deadends: 0, turns: 0,
      pshapes: [], turnspots: [], lshapes: [], tshapes: [], plusshapes: [], shopspots: [], courtyards: [],
    };
  }
}
