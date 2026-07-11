package render;

import three.Three;
import citygen.CityConfig;
import citygen.CityConfig.cellToWorld;
import citygen.CityConfig.worldToCell;
import citygen.CityModel.Building;
import citygen.CityModel.Tile;

// one fadeable material + the base state we lerp its opacity down from and back to.
// curT tracks the live transparent flag so we recompile (needsUpdate) only when it flips
typedef FadeMat = { mat:Dynamic, opacity:Float, transparent:Bool, depthWrite:Bool, emissive:Float, curT:Bool };
// per-building fade record: its world AABB, its (de-shared) materials, and the eased fade
typedef Occ = {
  b:Building,
  minX:Float, maxX:Float, minZ:Float, maxZ:Float, maxY:Float, cx:Float, cz:Float,
  mats:Array<FadeMat>, fade:Float, target:Float
};

// fades a building to semi-transparent while it sits between the camera and the player, so
// the player never hides behind a wall. Built once per city: derives each building's world
// AABB and buckets every scene mesh into the building it belongs to (by userData.b, else by
// position), cloning any material shared between buildings so each fades independently. Each
// frame a segment/AABB slab test picks the occluders and eases their opacity. StreetView owns
// and drives it.
class Occlusion {
  static inline var CELL = CityConfig.CELL;
  static var checked = false;

  var occ:Array<Occ> = [];
  var tiles:Array<Array<Tile>>;
  var tactical = false;
  var tacticalSelected:haxe.ds.ObjectMap<Building, Bool> = new haxe.ds.ObjectMap();
  var tacticalCol = -1;
  var tacticalRow = -1;
  var tacticalColDir = 0;
  var tacticalRowDir = 0;

  public function new(scene:Scene, buildings:Array<Building>, tiles:Array<Array<Tile>>)
    {
      this.tiles = tiles;
      if (!checked) { checked = true; if (!demo()) js.Browser.console.warn('[occlusion] self-check FAILED'); }
      // one fade record + world AABB per building; map Building -> index for userData bucketing
      var idxOf = new haxe.ds.ObjectMap<Building, Int>();
      for (i in 0...buildings.length)
        {
          var b = buildings[i];
          var c = cellToWorld(b.col + (b.w - 1) / 2, b.row + (b.d - 1) / 2);
          var hw = b.w * CELL / 2, hd = b.d * CELL / 2;
          // top the AABB at the parapet, not the roofline: the parapet rim sits above b.h and
          // can hide the player while the wall grazes clear — cover the tallest (brick) variant
          occ.push({
            b: b,
            minX: c.x - hw,
            maxX: c.x + hw,
            minZ: c.z - hd,
            maxZ: c.z + hd,
            maxY: b.h + RenderConfig.PARAPET_H_BRICK,
            cx: c.x,
            cz: c.z,
            mats: [],
            fade: 1.0,
            target: 1.0,
          });
          idxOf.set(b, i);
        }
      // bucket every mesh into its building and de-share its materials
      scene.traverse(function(o:Object3D) {
        if (untyped o.isMesh != true && o.isInstancedMesh != true) return;
        var bi = pick(o, idxOf);
        if (bi < 0) return;
        var m:Dynamic = o.material;
        if (m == null) return;
        if (Std.isOfType(m, Array))
          {
            var arr:Array<Dynamic> = m;
            for (k in 0...arr.length) arr[k] = own(arr[k], bi);
          }
        else o.material = own(m, bi);
      });
    }

// enable or clear the road-bounded tactical building selection
  public function setTactical(v:Bool):Void
    {
      if (tactical == v)
        return;
      tactical = v;
      tacticalCol = -1;
      tacticalRow = -1;
      if (!tactical)
        tacticalSelected = new haxe.ds.ObjectMap();
    }

// which building a mesh belongs to: its userData.b tag if present (box + window meshes),
// else the nearest-centre building whose AABB (margin-expanded for face-proud decals) holds it
  function pick(o:Object3D, idxOf:haxe.ds.ObjectMap<Building, Int>):Int
    {
      var b:Building = (o.userData != null) ? o.userData.b : null;
      if (b != null && idxOf.exists(b)) return idxOf.get(b);
      var px = o.position.x, pz = o.position.z, m = RenderConfig.OCCLUSION.margin;
      var best = -1;
      var bestD = 1e18;
      for (i in 0...occ.length)
        {
          var e = occ[i];
          if (px < e.minX - m || px > e.maxX + m || pz < e.minZ - m || pz > e.maxZ + m) continue;
          var dx = px - e.cx, dz = pz - e.cz, d = dx * dx + dz * dz;
          if (d < bestD) { bestD = d; best = i; }
        }
      return best;
    }

// hand back a material private to building bi, recording its base state once: return it as-is
// the first time (tagged owner=bi), skip if already ours, clone it if another building owns it
  function own(m:Dynamic, bi:Int):Dynamic
    {
      var owner:Null<Int> = untyped m.__occOwner;
      if (owner == bi) return m;               // already ours + recorded
      if (owner == null) { untyped m.__occOwner = bi; record(m, bi); return m; }
      var c:Dynamic = m.clone();               // shared with another building -> private copy
      untyped c.__occOwner = bi;
      record(c, bi);
      return c;
    }

// snapshot a material's solid-state values so fade can scale from them and restore them
  function record(m:Dynamic, bi:Int):Void
    {
      occ[bi].mats.push({ mat: m,
        opacity: (m.opacity == null ? 1.0 : m.opacity),
        transparent: (m.transparent == true),
        depthWrite: (m.depthWrite == null ? true : m.depthWrite),
        emissive: (m.emissiveIntensity == null ? -1.0 : m.emissiveIntensity),
        curT: (m.transparent == true) });
    }

// per frame: fade buildings blocking the camera->player sightline; while aiming (wide) widen
// the corridor so flanking buildings fade too, and always clear the camera->target line (nullable
// target). only foreground buildings (nearer the camera than the endpoint) fade — never the
// background. ease every non-resting building toward its target
  public function update(camPos:Vector3, player:Vector3, target:Vector3, wide:Bool, dtMs:Float):Void
    {
      // frame-rate-independent smoothing (same exponential decay as CameraRig zoom)
      var k = 1 - Math.pow(1 - RenderConfig.OCCLUSION.lerp, dtMs / (1000 / 30));
      var grow = wide ? RenderConfig.OCCLUSION.aimGrow * CELL : 0.0;
      if (tactical)
        updateTacticalSelection(camPos, player);
      for (o in occ)
        {
          // tactical fades the whole selected block, but the camera is not truly top-down —
          // keep the sightline fade on top so an adjacent tall building never hides the player
          var blocked = (tactical && tacticalSelected.exists(o.b)) ||
            occludes(o, camPos, player, grow) ||
            (target != null && occludes(o, camPos, target, grow));
          o.target = blocked ? RenderConfig.OCCLUSION.fade : 1.0;
          if (o.fade == o.target && o.target == 1.0) continue; // solid and staying solid
          o.fade += (o.target - o.fade) * k;
          if (Math.abs(o.fade - o.target) < RenderConfig.OCCLUSION.snap) o.fade = o.target;
          apply(o);
        }
    }

// select every building in the nearest camera-side block bounded by roads
  function updateTacticalSelection(cam:Vector3, player:Vector3):Void
    {
      var cell = worldToCell(player.x, player.z);
      var dx = cam.x - player.x;
      var dz = cam.z - player.z;
      var dc = 0;
      var dr = 0;
      if (Math.abs(dx) > Math.abs(dz))
        dc = dx > 0 ? 1 : -1;
      else
        dr = dz > 0 ? 1 : -1;
      if (cell.col == tacticalCol &&
          cell.row == tacticalRow &&
          dc == tacticalColDir &&
          dr == tacticalRowDir)
        return;
      tacticalCol = cell.col;
      tacticalRow = cell.row;
      tacticalColDir = dc;
      tacticalRowDir = dr;
      tacticalSelected = new haxe.ds.ObjectMap();

      var onRoad = nearRoad(cell.col, cell.row);
      // inside a block the scans stay road-bounded: an alley must select the SURROUNDING
      // block, not wander down its length across roads to some block across town
      selectBlock(cell.col, cell.row, dc, dr, !onRoad);
      // fade the flanking blocks too: on/beside a road the view corridor runs along it and
      // the camera-side scan misses them; inside a block the side scans find the alley's own
      // walls. road-bounded so a scan along the road degrades to a no-op
      selectBlock(cell.col, cell.row, dr, dc, true);
      selectBlock(cell.col, cell.row, -dr, -dc, true);
    }

// player cell is a road, or a walkway bordering one (a sidewalk); deep-in-block walkways and
// alleys don't count — flanking fades there would strip cover the player is actually behind
  function nearRoad(col:Int, row:Int):Bool
    {
      if (tiles[row][col] == Tile.Road)
        return true;
      if (tiles[row][col] != Tile.Walkway)
        return false;
      var rows = tiles.length;
      var cols = tiles[0].length;
      for (dir in 0...4)
        {
          var c = col + (dir == 0 ? 1 : dir == 1 ? -1 : 0);
          var r = row + (dir == 2 ? 1 : dir == 3 ? -1 : 0);
          if (c >= 0 &&
              r >= 0 &&
              c < cols &&
              r < rows &&
              tiles[r][c] == Tile.Road)
            return true;
        }
      return false;
    }

// add every building of the first road-bounded block hit scanning from a cell in a direction
  function selectBlock(col:Int, row:Int, dc:Int, dr:Int, stopAtRoad:Bool):Void
    {
      var seen = tacticalBlock(tiles, col, row, dc, dr, stopAtRoad);
      if (seen == null)
        return;
      for (o in occ)
        if (isSelected(o.b, seen))
          tacticalSelected.set(o.b, true);
    }

// find the road-bounded city block first reached from a player cell in one direction;
// stopAtRoad keeps the scan inside the starting block (null once it would cross a road)
  static function tacticalBlock(tiles:Array<Array<Tile>>, playerCol:Int, playerRow:Int,
      dc:Int, dr:Int, stopAtRoad:Bool = false):Array<Array<Bool>>
    {
      var rows = tiles.length;
      var cols = tiles[0].length;
      var col = playerCol + dc;
      var row = playerRow + dr;
      var scan = rows + cols;
      for (_ in 0...scan)
        {
          if (col < 0 ||
              row < 0 ||
              col >= cols ||
              row >= rows)
            return null;
          if (tiles[row][col] == Tile.Building)
            break;
          if (stopAtRoad &&
              tiles[row][col] == Tile.Road)
            return null;
          col += dc;
          row += dr;
        }
      if (col < 0 ||
          row < 0 ||
          col >= cols ||
          row >= rows ||
          tiles[row][col] != Tile.Building)
        return null;

      var seen = [for (_ in 0...rows) [for (_ in 0...cols) false]];
      var queue:Array<{ col:Int, row:Int }> = [
        {
          col: col,
          row: row,
        },
      ];
      seen[row][col] = true;
      var next = 0;
      while (next < queue.length)
        {
          var here = queue[next++];
          for (dir in 0...4)
            {
              var nextCol = here.col + (dir == 0 ? 1 : dir == 1 ? -1 : 0);
              var nextRow = here.row + (dir == 2 ? 1 : dir == 3 ? -1 : 0);
              if (nextCol < 0 ||
                  nextRow < 0 ||
                  nextCol >= cols ||
                  nextRow >= rows ||
                  seen[nextRow][nextCol] ||
                  tiles[nextRow][nextCol] == Tile.Road)
                continue;
              seen[nextRow][nextCol] = true;
              queue.push({
                col: nextCol,
                row: nextRow,
              });
            }
        }
      return seen;
    }

// return whether any cell in a building belongs to the selected road-bounded block
  function isSelected(b:Building, seen:Array<Array<Bool>>):Bool
    {
      for (row in b.row...b.row + b.d)
        for (col in b.col...b.col + b.w)
          if (seen[row][col])
            return true;
      return false;
    }

// building o blocks camera->endpoint? only counts if o is in FRONT of the endpoint (its centre
// projects nearer the camera than the endpoint) so a grown corridor never fades the background
  inline function occludes(o:Occ, cam:Vector3, e:Vector3, grow:Float):Bool
    {
      var dx = e.x - cam.x, dz = e.z - cam.z, d2 = dx * dx + dz * dz;
      if (d2 < 1e-6) return false;
      var proj = ((o.cx - cam.x) * dx + (o.cz - cam.z) * dz) / d2; // 0=camera, 1=endpoint
      if (proj >= 1.0) return false;                               // at/behind endpoint = background
      return segHitsBox(cam.x, cam.y, cam.z, e.x, e.y, e.z,
        o.minX, o.maxX, o.minZ, o.maxZ, o.maxY, grow);
    }

// push the current fade onto a building's materials (opacity + see-through depth + bloom cut)
  function apply(o:Occ):Void
    {
      var f = o.fade, faded = f < 0.999;
      for (fm in o.mats)
        {
          var m = fm.mat;
          var wantT = fm.transparent || faded;
          // three keeps the opaque shader until needsUpdate; only recompile on the actual flip
          if (wantT != fm.curT) { fm.curT = wantT; m.needsUpdate = true; }
          m.transparent = wantT;
          m.opacity = fm.opacity * f;
          m.depthWrite = faded ? false : fm.depthWrite;
          if (fm.emissive >= 0) m.emissiveIntensity = fm.emissive * f; // lit windows stop blooming
        }
    }

// does segment a->b pass through the box (strictly between the endpoints)? slab clip. grow
// inflates the XZ slabs, widening the corridor (used to fade near-line, not just strict, hits)
  static function segHitsBox(ax:Float, ay:Float, az:Float, bx:Float, by:Float, bz:Float,
    x0:Float, x1:Float, z0:Float, z1:Float, y1:Float, grow:Float = 0.0):Bool
    {
      var t = [0.0, 1.0];
      if (!clip(ax, bx, x0 - grow, x1 + grow, t)) return false;
      if (!clip(ay, by, 0, y1, t)) return false;
      if (!clip(az, bz, z0 - grow, z1 + grow, t)) return false;
      return t[1] > 0.001 && t[0] < 0.999 && t[0] <= t[1];
    }

// clip param range t=[enter,exit] against one axis slab [lo,hi]; false if it empties the range
  static function clip(p0:Float, p1:Float, lo:Float, hi:Float, t:Array<Float>):Bool
    {
      var d = p1 - p0;
      if (d > -1e-9 && d < 1e-9) return p0 >= lo && p0 <= hi; // parallel: inside slab or miss
      var ta = (lo - p0) / d, tb = (hi - p0) / d;
      if (ta > tb) { var tmp = ta; ta = tb; tb = tmp; }
      if (ta > t[0]) t[0] = ta;
      if (tb < t[1]) t[1] = tb;
      return t[0] <= t[1];
    }

// self-check for the slab test: a box on the line hits, boxes beside/behind it miss
  static function demo():Bool
    {
      // box [-1..1]^3-ish straddling the segment from (0,0,-10) to (0,0,10)
      var hit = segHitsBox(0, 0, -10, 0, 0, 10, -1, 1, -1, 1, 2);
      // box off to the side of the same line
      var side = segHitsBox(0, 0, -10, 0, 0, 10, 5, 7, -1, 1, 2);
      // box beyond the far endpoint (player at z=10, box at z=20..22)
      var beyond = segHitsBox(0, 0, -10, 0, 0, 10, -1, 1, 20, 22, 2);
      var tiles:Array<Array<Tile>> = [
        [Tile.Road, Tile.Road, Tile.Road, Tile.Road, Tile.Road, Tile.Road],
        [Tile.Road, Tile.Walkway, Tile.Building, Tile.Alley, Tile.Building, Tile.Road],
        [Tile.Road, Tile.Road, Tile.Road, Tile.Road, Tile.Road, Tile.Road],
      ];
      var block = tacticalBlock(tiles, 1, 1, 1, 0);
      var tactical = block != null &&
        block[1][2] &&
        block[1][4] &&
        !block[1][0] &&
        !block[1][5];
      // road-bounded scan: walking toward the road must yield nothing, not cross it
      var stopped = tacticalBlock(tiles, 1, 1, -1, 0, true);
      return hit && !side && !beyond && tactical && stopped == null;
    }
}
