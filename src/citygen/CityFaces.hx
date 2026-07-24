package citygen;

import citygen.CityModel.Tile;
import citygen.CityModel.Building;

// pure tile/face queries shared by the generator and the renderer: which walls front a street,
// and which earn windows. They live here rather than in render.world.Geom so CityGen can refuse
// to emit a building the renderer would have to draw as a blank box — the drop rule and the
// window rule are then the SAME code and cannot drift apart. Geom delegates to these, passing
// the live tile grid; nothing here touches the renderer.
class CityFaces {
  static inline var GRID = CityConfig.GRID;
  static inline var OPEN_WIN_DEPTH = 3;
  static inline var MIN_OPEN_WIN_RUN = 2; // min exposed tiles to window (no single-column slivers)

  // dir: 0=+z,1=-z,2=+x,3=-x
  public static var DIRV = [[0, 1], [0, -1], [1, 0], [-1, 0]];

  // street = the cells directly outside are road/walkway. off-grid reads as street: the city
  // edge is open sky, not a buried wall. (CityGen's own faceStreet counts off-grid as NOT
  // street — it guards composite retention at the city rim, a different question.)
  public static function faceIsStreet(tiles:Array<Array<Tile>>, b:Building, dir:Int):Bool {
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

  // tile-index runs of face `dir` that look onto open space (road / walkway / alley)
  // and so earn windows: each maximal run of columns (dir 0/1) or rows (dir 2/3)
  // with no building within OPEN_WIN_DEPTH tiles straight out. windows the OPEN part
  // of a partial face — e.g. both orthogonal inner walls of an L notch, where each
  // wall is half buried by the other wing and half open onto the notch. runs shorter
  // than MIN_OPEN_WIN_RUN are single-column slivers poking past a near neighbour →
  // dropped (full side or none). full-street faces never reach here. runs are
  // inclusive {lo,hi} along x for dir 0/1, along z for dir 2/3
  public static function openWinRuns(tiles:Array<Array<Tile>>, b:Building, dir:Int, allowPartial:Bool):Array<{lo:Int, hi:Int}> {
    if (faceIsStreet(tiles, b, dir)) return [];
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
    // PARTIAL face (part abutting a neighbour) is windowed when it's a notch inner
    // wall citygen flagged via winBlock (allowPartial), or when the open stretch
    // fronts the street — a half-buried wall whose exposed part faces a road/walkway
    // still reads as frontage (a blank wall there is a checklist FAIL). alley-facing
    // partial runs stay blank (incidental neighbour burial → no half-window)
    if (!buried || allowPartial) return runs;
    return [for (run in runs) if (runFrontsStreet(tiles, b, dir, run)) run];
  }

  // does every cell of face run [lo,hi] front a road/walkway one step out?
  static function runFrontsStreet(tiles:Array<Array<Tile>>, b:Building, dir:Int, run:{lo:Int, hi:Int}):Bool {
    var dc = DIRV[dir][0], dr = DIRV[dir][1];
    for (idx in run.lo...run.hi + 1) {
      var t:Tile;
      if (dc != 0) {
        var col = dc > 0 ? b.col + b.w : b.col - 1;
        if (col < 0 || col >= GRID) continue;
        t = tiles[idx][col];
      } else {
        var row = dr > 0 ? b.row + b.d : b.row - 1;
        if (row < 0 || row >= GRID) continue;
        t = tiles[row][idx];
      }
      if (t != Tile.Road &&
          t != Tile.Walkway) return false;
    }
    return true;
  }

  // can this building show at least one window? mirrors Windows.add's per-face gate exactly:
  // a forced courtyard wall, an unblocked street frontage, or an open L/T/+ inner run. shops and
  // metal warehouses show doors/art instead of windows, so they are never blank-box candidates.
  // CityGen drops what this rejects; Check FAILs anything that still reaches the renderer blank.
  public static function windowable(tiles:Array<Array<Tile>>, b:Building):Bool {
    if (b.shop >= 0 || b.facade == 3) return true;
    for (dir in 0...4) {
      var forced = b.winForce != null && b.winForce.indexOf(dir) >= 0;
      var blocked = b.winBlock != null && b.winBlock.indexOf(dir) >= 0;
      if (forced ||
          (faceIsStreet(tiles, b, dir) && !blocked) ||
          openWinRuns(tiles, b, dir, blocked).length > 0) return true;
    }
    return false;
  }
}
