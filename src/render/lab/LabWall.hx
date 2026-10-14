package render.lab;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.facility.FacilityGeom;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// what LabWall hung, and the two meshes the alarm swaps between
typedef LabWallSet = {
  signs:Int,        // safety and room signs, one per stretch of wall
  fittings:Int,     // the gauges, keypads, boxes and boards below them
  screens:Int,      // the monitors, each with its alarm twin
  lamps:Int,        // the bar lamps, neon tubes and caged lamps
  quiet:Mesh,       // the monitors as they read while the lab is quiet; null with none
  alarm:Mesh,       // the same quads on the alarm's four cells, shown instead while it is up
  glow:Array<Mesh>, // every emissive mesh, for the death's dimming
};

// the underground lab's WALLS: the signs, fittings, screens and lamps that were the 2D lab's wall
// overlays, as quads off three pack16 sheets (lab/wall-signs, lab/wall-fittings, lab/wall-screens).
//
// A TEXTURE AND NOT A PROP, render.corp.CorpSigns' reading of the silhouette-vs-surface guard: a
// sign, a keypad or a monitor is a rectangle on a wall, and everything that makes it one of them is
// on its face. So the whole family is quads, ONE MESH PER SHEET (and the screens' three: quiet,
// alarm, lamps), and its runs are CorpSigns' — a stretch of plain masonry a doorway ends.
//
// ONLY THE WALLS THE CAMERA SEES. A south wall's face looks away from the gameplay camera, which
// sees its back, so nothing hangs there (the generator's wall zones avoid it for the same reason).
//
// WHAT HANGS IS THE ROOM'S: each role deals off its own short list of each sheet, and the monitors go
// only where someone watched the vats or the research. Every pick is off the cell hash
// (FacilityModel.mix), nothing is saved, and nothing hangs over a piece standing against the wall,
// which would hide it.
//
// THE ALARM SWAPS THE SCREENS: every monitor has a twin on the same quad wearing one of the sheet's
// four alarm cells (LOCKDOWN, CONTAINMENT BREACH, ALERT, SEALED), shown instead while the lead's
// alarm is up. The lab's death dims every glow with the machines' (LabInterior.dim)
class LabWall
{
  static inline var CELL = CityConfig.CELL;
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

  // the sheets' cells, in reading order
  static inline var SIGN_BIO = 0;
  static inline var SIGN_LAB = 1;
  static inline var SIGN_SEC = 2;
  static inline var SIGN_QUARANTINE = 3;
  static inline var SIGN_EVAC = 4;
  static inline var SIGN_AUTH = 5;
  static inline var SIGN_RAD = 6;
  static inline var SIGN_CRYO = 7;
  static inline var SIGN_EYEWASH = 8;
  static inline var SIGN_LIFT = 9;
  static inline var SIGN_NO_ENTRY = 10;
  static inline var SIGN_CLONE = 11;
  static inline var SIGN_SUIT = 12;
  static inline var SIGN_DECON = 13;
  static inline var SIGN_CORROSIVE = 14;
  static inline var SIGN_VOLTAGE = 15;
  static inline var FIT_JUNCTION = 0;
  static inline var FIT_VENT = 1;
  static inline var FIT_GAUGE = 2;
  static inline var FIT_KEYPAD = 3;
  static inline var FIT_INTERCOM = 4;
  static inline var FIT_ALARM = 5;
  static inline var FIT_VALVE = 6;
  static inline var FIT_FUSE = 7;
  static inline var FIT_AID = 8;
  static inline var FIT_EYEWASH = 9;
  static inline var FIT_CLIPBOARD = 10;
  static inline var FIT_BOARD = 11;
  static inline var FIT_HOSE = 12;
  static inline var FIT_TRAY = 13;
  static inline var FIT_LOCKER = 14;
  static inline var FIT_HOOKS = 15;
  static inline var SCREEN_N = 8;
  static inline var LAMP_BAR = 8;
  static inline var LAMP_NEON = 9;
  static inline var LAMP_CAGE = 10;
  static inline var LAMP_AMBER = 11;
  static inline var ALARM_0 = 12;

  // the screens sheet's cells' width:height, measured off the drop (tools/pack16.py --fill); the
  // signs' are all within 3% of square and the fittings are cut at one scale, so neither needs one
  static var SCREEN_ASPECT = [1.0216, 1.0161, 1.0215, 1.0162, 1.0272, 1.0272, 1.0272, 1.0217,
    2.3140, 2.6835, 1.0068, 0.9658, 1.0107, 1.0053, 1.0053, 1.0];

  // per room role (corridor, entrance, vat, workshop, storage, research): the signs, the fittings
  // and the lamp each deals from
  static var SIGNS = [
    [ SIGN_LAB, SIGN_SEC, SIGN_EVAC, SIGN_AUTH, SIGN_LIFT, SIGN_NO_ENTRY, SIGN_DECON ],
    [ SIGN_LIFT, SIGN_EVAC, SIGN_AUTH, SIGN_SUIT, SIGN_DECON, SIGN_QUARANTINE ],
    [ SIGN_BIO, SIGN_CLONE, SIGN_QUARANTINE, SIGN_SUIT, SIGN_EYEWASH ],
    [ SIGN_VOLTAGE, SIGN_CORROSIVE, SIGN_RAD, SIGN_EYEWASH, SIGN_LAB ],
    [ SIGN_CRYO, SIGN_BIO, SIGN_RAD, SIGN_CORROSIVE, SIGN_SEC ],
    [ SIGN_BIO, SIGN_EYEWASH, SIGN_SUIT, SIGN_LAB, SIGN_CRYO ],
  ];
  static var FITTINGS = [
    [ FIT_JUNCTION, FIT_VENT, FIT_KEYPAD, FIT_INTERCOM, FIT_ALARM, FIT_FUSE, FIT_HOSE, FIT_TRAY ],
    [ FIT_INTERCOM, FIT_KEYPAD, FIT_ALARM, FIT_BOARD, FIT_HOOKS, FIT_LOCKER, FIT_AID ],
    [ FIT_VALVE, FIT_GAUGE, FIT_JUNCTION, FIT_VENT, FIT_ALARM ],
    [ FIT_FUSE, FIT_JUNCTION, FIT_TRAY, FIT_HOSE, FIT_VALVE, FIT_GAUGE, FIT_CLIPBOARD ],
    [ FIT_CLIPBOARD, FIT_LOCKER, FIT_GAUGE, FIT_VENT, FIT_AID ],
    [ FIT_BOARD, FIT_CLIPBOARD, FIT_AID, FIT_EYEWASH, FIT_HOOKS, FIT_INTERCOM ],
  ];
  static var LAMPS = [ LAMP_BAR, LAMP_CAGE, LAMP_CAGE, LAMP_AMBER, LAMP_AMBER, LAMP_CAGE ];

// every sign, fitting, screen and lamp on the lab's walls. `tile` is the area's cell type, for the
// floor in front of a wall: a piece standing there hides the wall behind it
  public static function build(scene:Scene, m:Facility, tile:(Int, Int)->Int):LabWallSet
    {
      var signs = MeshBufTools.make();
      var fits = MeshBufTools.make();
      var quiet = MeshBufTools.make();
      var alarm = MeshBufTools.make();
      var lamps = MeshBufTools.make();
      var n = [0, 0, 0, 0];
      var seen = new Map<Int, Bool>();
      for (dir in [ 0, 2, 3 ])
        {
          // a run follows the WALL: along x for a wall in z, along z for one in x
          var sc = (dir < 2 ? 1 : 0);
          var sr = (dir < 2 ? 0 : 1);
          for (row in 0...m.h)
            for (col in 0...m.w)
              {
                var k = (dir * m.h + row) * m.w + col;
                if (seen.exists(k) ||
                    !hangs(m, col, row, dir))
                  continue;
                var len = 0;
                while (hangs(m, col + sc * len, row + sr * len, dir))
                  {
                    seen.set((dir * m.h + row + sr * len) * m.w + col + sc * len, true);
                    len++;
                  }
                if (len < LabStyle.WALL_RUN_MIN)
                  continue;
                // the run's clear cells, the ones with bare floor in front, middle-out so a lone
                // sign centres on its wall
                var free = [];
                for (i in 0...len)
                  {
                    var d = Std.int(len / 2) + (i % 2 == 0 ? Std.int(i / 2) : -Std.int(i / 2) - 1);
                    if (d >= 0 &&
                        d < len &&
                        bare(tile(col + sc * d, row + sr * d)))
                      free.push(d);
                  }
                if (free.length == 0)
                  continue;
                var role = roleOf(m, col, row);
                var h = FacilityModel.mix((col * 668265263) ^ (row * 1103515245) ^ (dir * 374761393));
                // the sign: one per WALL_SIGN_SPACING cells of run
                var want = Std.int(Math.max(1, Math.round(len / LabStyle.WALL_SIGN_SPACING)));
                var used = 0;
                var taken = [];
                while (used < want &&
                    used < free.length)
                  {
                    var at = free[Std.int(used * free.length / want)];
                    taken.push(at);
                    var l = SIGNS[role];
                    put(signs, m, col + sc * at, row + sr * at, dir, LabStyle.WALL_SIGN_Y,
                      LabStyle.WALL_SIGN_W, LabStyle.WALL_SIGN_W, l[(h >>> (3 + used * 3)) % l.length], 4);
                    n[0]++;
                    used++;
                  }
                // the rest of the free cells, past the signs', in hashed order: a fitting, a screen
                // where the room watched something, a lamp
                var rest = [for (d in free) if (taken.indexOf(d) < 0) d];
                if (rest.length > 0 &&
                    (h >>> 9) % 100 < LabStyle.WALL_FIT_PCT)
                  {
                    var at = rest.shift();
                    var l = FITTINGS[role];
                    put(fits, m, col + sc * at, row + sr * at, dir, LabStyle.WALL_FIT_Y,
                      LabStyle.WALL_FIT_W, LabStyle.WALL_FIT_W, l[(h >>> 12) % l.length], 4);
                    n[1]++;
                  }
                if (rest.length > 0 &&
                    (role == 2 || role == 5) &&
                    (h >>> 16) % 100 < LabStyle.WALL_SCREEN_PCT)
                  {
                    var at = rest.shift();
                    var s = (h >>> 19) % SCREEN_N;
                    screen(quiet, m, col + sc * at, row + sr * at, dir, s);
                    screen(alarm, m, col + sc * at, row + sr * at, dir, ALARM_0 + (h >>> 22) % 4);
                    n[2]++;
                  }
                if (rest.length > 0 &&
                    (h >>> 24) % 100 < LabStyle.WALL_LAMP_PCT)
                  {
                    var at = rest.shift();
                    // the corridor alternates the bar lamp and the neon tube
                    var s = (role == 0 && (h >>> 27) % 2 == 1 ? LAMP_NEON : LAMPS[role]);
                    screen(lamps, m, col + sc * at, row + sr * at, dir, s);
                    n[3]++;
                  }
              }
        }
      add(scene, signs, LabStyle.WALL_SIGNS_TEX, false);
      add(scene, fits, LabStyle.WALL_FITTINGS_TEX, false);
      var q = add(scene, quiet, LabStyle.WALL_SCREENS_TEX, true);
      var a = add(scene, alarm, LabStyle.WALL_SCREENS_TEX, true);
      var l = add(scene, lamps, LabStyle.WALL_SCREENS_TEX, true);
      if (a != null)
        a.visible = false;
      return {
        signs: n[0],
        fittings: n[1],
        screens: n[2],
        lamps: n[3],
        quiet: q,
        alarm: a,
        glow: [for (g in [ q, a, l ]) if (g != null) g],
      };
    }

// one quad off each sheet at the origin, for render.lab.LabWarm
  public static function warm(scene:Scene):Void
    {
      for (s in [ LabStyle.WALL_SIGNS_TEX, LabStyle.WALL_FITTINGS_TEX, LabStyle.WALL_SCREENS_TEX ])
        {
          var b = MeshBufTools.make();
          pane(b, -1.0, 1.0, 0.0, 0.0, 1, 1.0, 3.0, 0, 4);
          add(scene, b, s, s == LabStyle.WALL_SCREENS_TEX);
        }
    }

// per frame: the alarm's screens instead of the monitors once it is up, and every glow dimmed by `f`
// as the lab dies
  public static function tick(set:LabWallSet, alarmed:Bool, f:Float):Void
    {
      if (set.quiet != null)
        {
          set.quiet.visible = !alarmed;
          set.alarm.visible = alarmed;
        }
      for (g in set.glow)
        {
          var mat:MeshLambertMaterial = cast g.material;
          mat.emissiveIntensity = LabStyle.WALL_GLOW * f;
        }
    }

// can something hang on the `dir` wall of this cell: lab floor looking at plain masonry whose wall
// line carries on past it both ways (CorpSigns.hangs' rule: slab() insets a face where the line stops,
// and a quad centred on that cell would overhang the wall's end)
  static function hangs(m:Facility, col:Int, row:Int, dir:Int):Bool
    {
      if (!FacilityModel.inside(m, col, row))
        return false;
      var s = m.surf[row][col];
      if (s != Surf.LINO &&
          !FacilityModel.isLabRoom(s))
        return false;
      var c = col + DC[dir];
      var r = row + DR[dir];
      if (!FacilityModel.isSolidWall(m, c, r))
        return false;
      var sc = (dir < 2 ? 1 : 0);
      var sr = (dir < 2 ? 0 : 1);
      return FacilityGeom.carries(m, c - sc, r - sr) &&
        FacilityGeom.carries(m, c + sc, r + sr);
    }

// is this a bare lab floor tile, nothing standing on it to hide the wall behind
  static inline function bare(t:Int):Bool
    {
      return t >= Const.TILE_LAB_CORRIDOR &&
        t <= Const.TILE_LAB_FLOOR_RESEARCH;
    }

// the room role a cell's surface names, as SIGNS' row: 0 the corridor, then entrance, vat, workshop,
// storage, research
  static function roleOf(m:Facility, col:Int, row:Int):Int
    {
      return switch (m.surf[row][col])
        {
          case Surf.LAB_ENTRANCE: 1;
          case Surf.LAB_VAT: 2;
          case Surf.LAB_WORKSHOP: 3;
          case Surf.LAB_STORAGE: 4;
          case Surf.LAB_RESEARCH: 5;
          default: 0;
        }
    }

// a screens-sheet cell on the wall at its own aspect: a monitor's longest edge WALL_SCREEN_W, a strip
// lamp's WALL_LAMP_W and a caged one's WALL_CAGE_W, the lamps up at WALL_LAMP_Y
  static function screen(b:MeshBuf, m:Facility, col:Int, row:Int, dir:Int, cell:Int):Void
    {
      var lamp = (cell >= LAMP_BAR && cell < ALARM_0);
      var mx = (cell >= LAMP_CAGE && lamp ? LabStyle.WALL_CAGE_W :
        lamp ? LabStyle.WALL_LAMP_W : LabStyle.WALL_SCREEN_W);
      var a = SCREEN_ASPECT[cell];
      var w = (a >= 1 ? mx : mx * a);
      put(b, m, col, row, dir, (lamp ? LabStyle.WALL_LAMP_Y : LabStyle.WALL_SCREEN_Y), w, w / a, cell, 4);
    }

// one quad `w` wide and `h` tall centred `y` up the masonry beside (col, row), WALL_PROUD off the
// slab's face, wearing cell `cell` of a cols x cols sheet
  static function put(b:MeshBuf, m:Facility, col:Int, row:Int, dir:Int, y:Float, w:Float, h:Float,
      cell:Int, cols:Int):Void
    {
      var s = FacilityGeom.slab(m, col + DC[dir], row + DR[dir]);
      var c = CityConfig.cellToWorld(col, row);
      var e = LabStyle.WALL_PROUD;
      // the face looks BACK at the cell it is read from, the opposite of the side the masonry is on
      var d = dir ^ 1;
      if (d < 2)
        {
          var z = (d == 0 ? s.z0 - e : s.z1 + e);
          pane(b, c.x - w / 2, c.x + w / 2, z, z, d, y - h / 2, y + h / 2, cell, cols);
          return;
        }
      var x = (d == 2 ? s.x0 - e : s.x1 + e);
      pane(b, x, x, c.z - w / 2, c.z + w / 2, d, y - h / 2, y + h / 2, cell, cols);
    }

// one upright quad wearing one cell of a cols x cols sheet, v flipped to reading order
  static function pane(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, dir:Int, y0:Float, y1:Float,
      cell:Int, cols:Int):Void
    {
      var e = FacilityGeom.ends(x0, x1, z0, z1, dir);
      var u0 = (cell % cols) / cols;
      var v0 = 1 - (Std.int(cell / cols) + 1) / cols;
      var u1 = u0 + 1 / cols;
      var v1 = v0 + 1 / cols;
      MeshBufTools.quad(b,
        [e[0], y0, e[1]], [e[2], y0, e[3]], [e[2], y1, e[3]], [e[0], y1, e[1]],
        [u0, v0, u1, v0, u1, v1, u0, v1]);
    }

// one sheet's quads as one mesh: alphaTest for the cut-out fittings (opaque, so it writes depth and
// VisionMask keeps its darkening branch), and the screens sheet lit by its own map
  static function add(scene:Scene, b:MeshBuf, tex:String, glow:Bool):Mesh
    {
      if (b.idx.length == 0)
        return null;
      var map = Textures.loadTexture(tex, 'wall', 1);
      var mat = new MeshLambertMaterial({
        map: map,
        alphaTest: (tex == LabStyle.WALL_FITTINGS_TEX ? LabStyle.DECAL_CUT : 0.0),
      });
      if (glow)
        {
          mat.emissiveMap = map;
          mat.emissive = new Color(0xffffff);
          mat.emissiveIntensity = LabStyle.WALL_GLOW;
        }
      var mesh = new Mesh(FacilityGeom.geom(b), VisionMask.patch(mat));
      mesh.name = 'lab wall ' + tex;
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
      return mesh;
    }
}
