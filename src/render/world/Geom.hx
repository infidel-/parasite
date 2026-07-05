package render.world;

import citygen.CityConfig;
import citygen.CityConfig.cellToWorld;
import citygen.CityModel.Tile;
import citygen.CityModel.Building;
import render.RenderConfig;

// pure tile/building spatial queries shared by every world sub-builder. Reads the
// current city via WorldCtx (tiles/buildings). No geometry emitted here — just the
// classifications (street faces, window/door runs, worn faces, covered edges) the
// render passes and the checklist agree on.
class Geom {
  static inline var GRID = CityConfig.GRID;
  static inline var CELL = CityConfig.CELL;
  static inline var OPEN_WIN_DEPTH = 3;
  static inline var MIN_OPEN_WIN_RUN = 2; // min exposed tiles to window (no single-column slivers)

  // dir: 0=+z,1=-z,2=+x,3=-x
  public static var DIRV = [[0, 1], [0, -1], [1, 0], [-1, 0]];

  public static inline function imax(a:Float, b:Float):Float return a > b ? a : b;

  // Street = the cells directly outside are road/walkway
  public static function faceIsStreet(b:Building, dir:Int):Bool {
    var tiles = WorldCtx.tiles;
    var dc = DIRV[dir][0], dr = DIRV[dir][1];
    if (dc != 0) {
      var col = (dc > 0 ? b.col + b.w - 1 : b.col) + dc;
      if (col < 0 || col >= GRID) return true;
      for (r in b.row...b.row + b.d) {
        var t = tiles[r][col];
        if (t != Tile.Road && t != Tile.Walkway) return false;
      }
      return true;
    }
    var row = (dr > 0 ? b.row + b.d - 1 : b.row) + dr;
    if (row < 0 || row >= GRID) return true;
    for (c in b.col...b.col + b.w) {
      var t = tiles[row][c];
      if (t != Tile.Road && t != Tile.Walkway) return false;
    }
    return true;
  }

  // does the wall `dir` have a clear straight path to a road? step out perpendicular across the
  // FULL face width: any Building tile in the corridor blocks it; a step where the whole width is
  // Road means the road is reached. unlike faceIsStreet (road/walkway ONE tile out), this tunnels
  // through alley + walkway up to DOOR_PATH_MAX_DEPTH tiles, so a wall facing a road across an
  // alley still earns a door. running off-grid before a road = no path (city boundary, not a road).
  public static function faceHasPathToRoad(b:Building, dir:Int):Bool {
    var tiles = WorldCtx.tiles;
    var dc = DIRV[dir][0], dr = DIRV[dir][1];
    for (step in 0...RenderConfig.DOOR_PATH_MAX_DEPTH) {
      var sawRoad = true;
      if (dc != 0) {
        var col = (dc > 0 ? b.col + b.w : b.col - 1) + dc * step;
        if (col < 0 || col >= GRID) return false;
        for (r in b.row...b.row + b.d) {
          var t = tiles[r][col];
          if (t == Tile.Building) return false;
          if (t != Tile.Road) sawRoad = false;
        }
      } else {
        var row = (dr > 0 ? b.row + b.d : b.row - 1) + dr * step;
        if (row < 0 || row >= GRID) return false;
        for (c in b.col...b.col + b.w) {
          var t = tiles[row][c];
          if (t == Tile.Building) return false;
          if (t != Tile.Road) sawRoad = false;
        }
      }
      if (sawRoad) return true;
    }
    return false;
  }

  // does wall `dir` carry a ground-floor storefront band (Buildings.addGround)? that band IS the
  // entrance — never place a pedestrian door + cover over it. mirrors addGround's per-building +
  // per-face gate EXACTLY (incl. composite T/L/+ pieces, which also draw bands — the old
  // `fi.simple` test missed them, so composites got a door slapped on top of their storefront).
  public static function storefrontFace(b:Building, dir:Int):Bool {
    if (b.shop >= 0 || b.facade == 3) return false;
    var fi = frontInfo(b);
    if (fi.simple && !fi.store) return false; // plain/small simple building: no band
    return faceIsStreet(b, dir)
      && !(b.winForce != null && b.winForce.indexOf(dir) >= 0)
      && !(b.winBlock != null && b.winBlock.indexOf(dir) >= 0);
  }

  // tile-index runs of face `dir` that look onto open space (road / walkway / alley)
  // and so earn windows: each maximal run of columns (dir 0/1) or rows (dir 2/3)
  // with no building within OPEN_WIN_DEPTH tiles straight out. windows the OPEN part
  // of a partial face — e.g. both orthogonal inner walls of an L notch, where each
  // wall is half buried by the other wing and half open onto the notch. runs shorter
  // than MIN_OPEN_WIN_RUN are single-column slivers poking past a near neighbour →
  // dropped (full side or none). full-street faces never reach here. runs are
  // inclusive {lo,hi} along x for dir 0/1, along z for dir 2/3
  public static function openWinRuns(b:Building, dir:Int, allowPartial:Bool):Array<{lo:Int, hi:Int}> {
    if (faceIsStreet(b, dir)) return [];
    var tiles = WorldCtx.tiles;
    var dc = DIRV[dir][0], dr = DIRV[dir][1];
    // is the column/row at face index `idx` open (no building within 3 tiles out)?
    function exposed(idx:Int):Bool {
      for (step in 0...OPEN_WIN_DEPTH) {
        if (dc != 0) { // face runs along rows; step out along columns
          var col = (dc > 0 ? b.col + b.w : b.col - 1) + dc * step;
          if (col < 0 || col >= GRID) continue;
          if (tiles[idx][col] == Tile.Building) return false;
        } else { // face runs along columns; step out along rows
          var row = (dr > 0 ? b.row + b.d : b.row - 1) + dr * step;
          if (row < 0 || row >= GRID) continue;
          if (tiles[row][idx] == Tile.Building) return false;
        }
      }
      return true;
    }
    var runs:Array<{lo:Int, hi:Int}> = [];
    var lo = dc != 0 ? b.row : b.col;
    var hi = dc != 0 ? b.row + b.d : b.col + b.w; // exclusive
    inline function pushRun(from:Int, to:Int) if (to - from + 1 >= MIN_OPEN_WIN_RUN) runs.push({ lo: from, hi: to });
    var runStart = -1, buried = false;
    for (idx in lo...hi) {
      if (exposed(idx)) { if (runStart < 0) runStart = idx; }
      else { buried = true; if (runStart >= 0) { pushRun(runStart, idx - 1); runStart = -1; } }
    }
    if (runStart >= 0) pushRun(runStart, hi - 1);
    // whole face open (alley back wall, or an L/T/+ notch arm) → always window. a
    // PARTIAL face (part abutting a neighbour) is windowed only when it's a notch
    // inner wall citygen flagged via winBlock (allowPartial). otherwise it's just
    // an incidental wall half-buried by an unrelated neighbour → no half-window
    if (!buried) return runs;
    return allowPartial ? runs : [];
  }

  // tile-index runs of face `dir` whose cell ONE step straight out is open (not a Building) —
  // i.e. the wall fronts onto alley/road/walkway/edge, so a door there has space. Run ends mark
  // the corners: the building's own end, or where a sibling/neighbour wall abuts (T/L junction).
  // (depth-1, unlike openWinRuns' depth-3 window rule — a door is fine facing a near building
  // across an alley.) inclusive {lo,hi} along x for dir 0/1, along z for dir 2/3.
  public static function doorRuns(b:Building, dir:Int):Array<{lo:Int, hi:Int}> {
    var tiles = WorldCtx.tiles;
    var dc = DIRV[dir][0], dr = DIRV[dir][1];
    inline function clear(idx:Int):Bool {
      if (dc != 0) { var col = dc > 0 ? b.col + b.w : b.col - 1; return col < 0 || col >= GRID || tiles[idx][col] != Tile.Building; }
      var row = dr > 0 ? b.row + b.d : b.row - 1; return row < 0 || row >= GRID || tiles[row][idx] != Tile.Building;
    }
    var lo = dc != 0 ? b.row : b.col;
    var hi = dc != 0 ? b.row + b.d : b.col + b.w; // exclusive
    var runs:Array<{lo:Int, hi:Int}> = [];
    var runStart = -1;
    for (idx in lo...hi) {
      if (clear(idx)) { if (runStart < 0) runStart = idx; }
      else if (runStart >= 0) { runs.push({ lo: runStart, hi: idx - 1 }); runStart = -1; }
    }
    if (runStart >= 0) runs.push({ lo: runStart, hi: hi - 1 });
    return runs;
  }

  // extend a windowed face-tile run [lo,hi] to the full contiguous wall it belongs
  // to — including flush co-planar wall cells of NEIGHBOURING pieces (an L/T/+ seam)
  // — so windows can be centred on the WHOLE wall and line up across the join. a
  // neighbour cell joins when it sits on this face's wall plane and its outward cell
  // is open (a real exposed wall there). returns inclusive tile indices along the
  // face axis (x for dir 0/1, z for dir 2/3)
  public static function wallExtent(b:Building, dir:Int, lo:Int, hi:Int):{lo:Int, hi:Int} {
    var tiles = WorldCtx.tiles;
    if (dir < 2) { // face along columns; plane is a row, outward is a row
      var pr = dir == 0 ? b.row + b.d - 1 : b.row;
      var orr = dir == 0 ? b.row + b.d : b.row - 1;
      inline function wall(c:Int):Bool return c >= 0 && c < GRID && tiles[pr][c] == Tile.Building
        && (orr < 0 || orr >= GRID || tiles[orr][c] != Tile.Building);
      while (wall(lo - 1)) lo--;
      while (wall(hi + 1)) hi++;
    } else { // face along rows; plane is a column, outward is a column
      var pc = dir == 2 ? b.col + b.w - 1 : b.col;
      var oc = dir == 2 ? b.col + b.w : b.col - 1;
      inline function wall(r:Int):Bool return r >= 0 && r < GRID && tiles[r][pc] == Tile.Building
        && (oc < 0 || oc >= GRID || tiles[r][oc] != Tile.Building);
      while (wall(lo - 1)) lo--;
      while (wall(hi + 1)) hi++;
    }
    return { lo: lo, hi: hi };
  }

  // centred window-column world positions across [a,b] (margin at each end). same
  // count/centring as a single face, so a standalone wall is symmetric; fed the full
  // wall extent it stays continuous across seams (each piece emits its own slice)
  public static function centeredCols(a:Float, b:Float):Array<Float> {
    var pitch = RenderConfig.WIN_PITCH_X;
    var inner = (b - a) - 2 * RenderConfig.WIN_MARGIN;
    if (inner < 0) return [(a + b) / 2];
    var n = Std.int(imax(1, Math.round(inner / pitch)));
    while (n > 1 && (n - 1) * pitch + RenderConfig.WIN_W > inner) n--;
    var mid = (a + b) / 2;
    return [for (k in 0...n) mid + (k - (n - 1) / 2) * pitch];
  }

  // wall texture: clean wherever the face shows windows, worn otherwise. mirrors
  // the window rule in Windows.add — forced courtyard faces, street frontages (not
  // blocked), and inner walls opening onto a notch/alley are clean; everything
  // else (blocked frontages, cramped/buried back walls) is worn
  public static function isWornFace(b:Building, dir:Int):Bool {
    var forceWin = b.winForce != null && b.winForce.indexOf(dir) >= 0;
    var blockWin = b.winBlock != null && b.winBlock.indexOf(dir) >= 0;
    var hasWin = forceWin || (faceIsStreet(b, dir) && !blockWin) || openWinRuns(b, dir, blockWin).length > 0;
    return !hasWin;
  }

  // deterministic per-building front role (render-only; no rng → citygen stays byte-identical).
  // only "simple rectangle" non-shop non-metal buildings are reclassified; everyone else keeps
  // the prior path (store+windows). store ~STORE_PCT%; the rest are plain (maybe windows, maybe
  // an entrance door). a building with a tiny footprint (≤2 tiles BOTH axes) is "small": entrance
  // only — no store band, no windows. (NOT narrow-front: a 4-deep building with a 2-wide street
  // face is a real building and keeps windows.) hashed off col/row like the metal/grime picks.
  public static function frontInfo(b:Building):{ simple:Bool, small:Bool, store:Bool, windows:Bool } {
    if (b.shop >= 0 || b.facade == 3 || b.winForce != null || b.winBlock != null)
      return { simple: false, small: false, store: true, windows: true };
    var small = b.w <= 2 && b.d <= 2;
    var h = ((b.col * 73856093) ^ (b.row * 19349663)) & 0x7fffffff;
    var store = !small && (h % 100) < RenderConfig.STORE_PCT;
    // every concrete/brick/stone building gets windows — no blank plain boxes. only a buried
    // face (every wall against a neighbor) yields 0, which the checklist FAILs as a real anomaly.
    return { simple: true, small: small, store: store, windows: true };
  }

  // should this building show upper-floor windows? shops (storefront, no upper windows) and
  // metal warehouses (closed) never do; composites force them; simple buildings use frontInfo.
  public static function expectWindows(b:Building):Bool {
    if (b.shop >= 0 || b.facade == 3) return false;
    var fi = frontInfo(b);
    return fi.simple ? fi.windows : true; // composite (winForce/winBlock) forces windows
  }

  // standing-quad Y-rotation for a wall face dir (matches the rotY buildingFaces emits): a
  // decal quad set to this rotation.y faces outward along dir. shared by the static wall-decal
  // pass and the bullet-hole paint
  public static inline function faceRotY(dir:Int):Float
    return switch (dir) { case 0: 0.0; case 1: Math.PI; case 2: Math.PI / 2; default: -Math.PI / 2; }

  // which wall face dir a cell is struck on, given (ddx,ddy) = shooter - wallcell: the side
  // facing the shooter, chosen by the dominant axis. shared by the bullet-hole placement
  public static inline function faceToward(ddx:Int, ddy:Int):Int
    return (Math.abs(ddx) >= Math.abs(ddy)) ? (ddx > 0 ? 2 : 3) : (ddy > 0 ? 0 : 1);

  // self-check: faceRotY agrees with the rotY buildingFaces emits for all 4 dirs, and
  // faceToward picks the shooter-facing side on each axis
  public static function demo():Bool {
    for (f in buildingFaces({ x: 0.0, z: 0.0 }, 4, 4, 0))
      if (Math.abs(faceRotY(f.dir) - f.rotY) > 1e-9) return false;
    return faceToward(3, 0) == 2 && faceToward(-3, 0) == 3
      && faceToward(0, 3) == 0 && faceToward(0, -3) == 1;
  }

  // face placement: [faceWidth, rotationY, dir, faceCenterX, faceCenterZ]
  public static function buildingFaces(center:{x:Float, z:Float}, wWorld:Float, dWorld:Float, eps:Float):Array<{faceW:Float, rotY:Float, dir:Int, fx:Float, fz:Float}> {
    return [
      { faceW: wWorld, rotY: 0, dir: 0, fx: center.x, fz: center.z + dWorld / 2 + eps },
      { faceW: wWorld, rotY: Math.PI, dir: 1, fx: center.x, fz: center.z - dWorld / 2 - eps },
      { faceW: dWorld, rotY: Math.PI / 2, dir: 2, fx: center.x + wWorld / 2 + eps, fz: center.z },
      { faceW: dWorld, rotY: -Math.PI / 2, dir: 3, fx: center.x - wWorld / 2 - eps, fz: center.z },
    ];
  }

  // is the corner at (cornerX,cornerZ), nudged outward along (sx,sz), strictly
  // inside a same-height neighbour? such corners are buried in the merged roof —
  // their coping cap is hidden and the corner contact-shadow is skipped. a corner
  // merely on a covered seam's open end is exposed and keeps cap + shadow
  public static function cornerBuried(b:Building, cornerX:Float, cornerZ:Float, sx:Float, sz:Float):Bool {
    var buildings = WorldCtx.buildings;
    var px = cornerX + sx * 0.05, pz = cornerZ + sz * 0.05;
    for (o in buildings) if (o != b && Math.abs(o.h - b.h) < 0.001) {
      var oc = cellToWorld(o.col + (o.w - 1) / 2, o.row + (o.d - 1) / 2);
      var xmin = oc.x - o.w * CELL / 2, xmax = oc.x + o.w * CELL / 2;
      var zmin = oc.z - o.d * CELL / 2, zmax = oc.z + o.d * CELL / 2;
      if (xmin - 1e-6 < px && px < xmax + 1e-6 && zmin - 1e-6 < pz && pz < zmax + 1e-6) return true;
    }
    return false;
  }

  // exposed sub-spans of [lo,hi] after subtracting edge `dir`'s covered intervals.
  // each sub-span end that came from a covered cut (a junction with a neighbour,
  // not the edge's own end) is grown outward by `extend` so a wall/shadow placed
  // there reaches into the concave corner instead of stopping at the neighbour line
  public static function exposedSpans(covered:Array<Array<{a:Float, b:Float}>>, dir:Int, lo:Float, hi:Float, extend:Float):Array<{a:Float, b:Float}> {
    var cuts:Array<{a:Float, b:Float}> = [];
    if (covered != null && covered[dir] != null) for (iv in covered[dir]) {
      var a = lo > iv.a ? lo : iv.a, b = hi < iv.b ? hi : iv.b;
      if (b > a) cuts.push({ a: a, b: b });
    }
    cuts.sort((p, q) -> p.a < q.a ? -1 : (p.a > q.a ? 1 : 0));
    var out:Array<{a:Float, b:Float}> = [];
    var cur = lo;
    for (c in cuts) { if (c.a > cur) out.push({ a: cur, b: c.a }); if (c.b > cur) cur = c.b; }
    if (cur < hi) out.push({ a: cur, b: hi });
    if (extend > 0) for (s in out) {
      if (s.a > lo + 1e-6) s.a -= extend;
      if (s.b < hi - 1e-6) s.b += extend;
    }
    return out;
  }

  // per edge (dir 0..3) the world-axis intervals shared with a same-height
  // neighbour: where another building's footprint covers this edge line. dir 0/1
  // intervals are along x; dir 2/3 along z. These are the parts of the parapet
  // rim that would go onto another building and must be cut so the two attach
  public static function coveredEdges(b:Building):Array<Array<{a:Float, b:Float}>> {
    var buildings = WorldCtx.buildings;
    var bc = cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);
    var bxMin = bc.x - b.w * CELL / 2, bxMax = bc.x + b.w * CELL / 2;
    var bzMin = bc.z - b.d * CELL / 2, bzMax = bc.z + b.d * CELL / 2;
    var nb:Array<{xmin:Float, xmax:Float, zmin:Float, zmax:Float}> = [];
    for (o in buildings) if (o != b && Math.abs(o.h - b.h) < 0.001) {
      var oc = cellToWorld(o.col + (o.w - 1) / 2, o.row + (o.d - 1) / 2);
      nb.push({ xmin: oc.x - o.w * CELL / 2, xmax: oc.x + o.w * CELL / 2,
                zmin: oc.z - o.d * CELL / 2, zmax: oc.z + o.d * CELL / 2 });
    }
    inline function inters(axisMin:Float, axisMax:Float, alongX:Bool, edgeZ:Float, edgeX:Float):Array<{a:Float, b:Float}> {
      var out:Array<{a:Float, b:Float}> = [];
      for (o in nb) {
        var coversPerp = alongX ? (o.zmin <= edgeZ + 1e-6 && edgeZ - 1e-6 <= o.zmax)
                                : (o.xmin <= edgeX + 1e-6 && edgeX - 1e-6 <= o.xmax);
        if (!coversPerp) continue;
        var a = alongX ? o.xmin : o.zmin, b = alongX ? o.xmax : o.zmax;
        var lo = axisMin > a ? axisMin : a, hi = axisMax < b ? axisMax : b;
        if (hi > lo) out.push({ a: lo, b: hi });
      }
      return out;
    }
    return [
      inters(bxMin, bxMax, true,  bzMax, 0),   // dir 0 (+z)
      inters(bxMin, bxMax, true,  bzMin, 0),   // dir 1 (-z)
      inters(bzMin, bzMax, false, 0, bxMax),   // dir 2 (+x)
      inters(bzMin, bzMax, false, 0, bxMin),   // dir 3 (-x)
    ];
  }
}
