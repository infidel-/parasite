package render.military;

import three.Three;
import citygen.CityConfig;
import game.AreaGame;
import render.Models.PropPlace;
import render.Textures;
import render.facility.ClutterSlot;
import render.facility.ClutterSlot.ClutterSlotTools;
import render.facility.FacilityDetail;
import render.facility.FacilityGeom;
import render.facility.FacilityGround;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityStyle;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// what a furniture top is, which sets how many decals it rolls, off which cells of its room's sheet,
// and whether a piece of the barracks gear may stand on it
enum LidKind
{
  // a desk or the operator desk, 1-3
  DESK;
  // a mess or briefing table, 2-4
  TABLE;
  // a bench's seat, 0-1
  SEAT;
  // a footlocker's lid, 0-2
  FOOTLOCKER;
  // a filing or medical cabinet's top, 0-1
  CABINET;
  // a store shelf unit's top board or a radio rack's top, 1-2
  SHELF;
  // a bunk deck's blanket or a cot's canvas, 0-2
  BED;
  // the floor under a bunk or a cot, 0-2 off the room's FLOOR_PICK
  UNDER;
  // a locker's or the gun cabinet's top, 0-1, and a piece of gear half the time
  LOCKER;
}

// one furniture top a base room's clutter may lie on, recorded by render.military.MilitaryInterior
// as it stands the piece: the lid's centre and turn, its extents in its own frame (w along local x,
// d along local z), its height, what kind of top it is, and what already stands on it
typedef MilitaryLid = {
  // centre, world
  x:Float,
  z:Float,
  // the piece's own turn, so local x is its length
  yaw:Float,
  // the usable top along local x and local z
  w:Float,
  d:Float,
  // the top's height off the floor
  y:Float,
  // the decal count and the cells it rolls
  kind:LidKind,
  // the cell it stands on, for its room and its rolls
  col:Int,
  row:Int,
  // boxes in the lid's own frame already taken, the comms desk's radio set
  claims:Array<ClutterSlot>,
};

// one pocket behind an armory piece's leaves (models-src/military/roomkit_build.py's THE INSIDES), in
// its placed glb's frame, and what lies in it (MilitaryClutter.insides)
typedef ArmoryPocket = {
  // its two side walls, local x
  x0:Float,
  x1:Float,
  // its mouth and its back wall, local z
  mouth:Float,
  back:Float,
  // the height of its floor, of its shelf's top and of the shelf's underside
  floor:Float,
  shelf:Float,
  under:Float,
  // the inside sheet's cells that lie flat in it, and how far one turns off square
  flat:Array<Int>,
  turn:Float,
};

// the small FLAT things lying about a base's rooms: paperwork on the HQ desks, trays and cutlery on
// the mess tables, a logbook and headphones beside a radio, a rifle and magazines on an armory
// footlocker, dog tags and playing cards on a barracks one, a puddle on the latrine floor.
//
// ONE PACK16 SHEET PER ROOM KIND (textures/military/<role>-clutter, a 4x4 of 256 px cut-outs), the
// sheet a room deals from being its generatorInfo role, so a mess hall never gets a rifle and an
// armory never gets a food tray. Reported from the game as an "empty fucking table", and a console
// whose radios and log were painted into its top.
//
// RENDER-ONLY like render.facility.FacilityClutter: every position, size, turn and pick is rolled off
// FacilityModel.mix on the cell, nothing is saved and nothing blocks. Its emit and add are that file's
// and FacilityStore's, copied for FacilityStore's reason, and the sheet is 4 wide where theirs is 8.
//
// ONE MERGED MESH PER SHEET, so a base pays at most one call per room kind it has.
//
// AND THE BARRACKS GEAR STANDS: its sheet's boots, rucksack and canteen were reported as wanting to be
// 3D, so a roll landing on one of those cells stands that glb instead (`SOLID`), on whatever top or
// floor it rolled for. Rolled off the sheet alone that is 3 cells in 16 and a barracks came out with no
// rucksack in it, so a top that takes gear (`kit`: a bunk's bedding, a footlocker, the floor under a
// bunk, and a locker in any room) also stands one piece of it half the time
class MilitaryClutter
{
  // the sheets' grid
  static inline var COLS = 4;
  static inline var CELL = CityConfig.CELL;
  // how far a top must reach into a room to be its
  static inline var EPS = 0.05;
  // a decal's drawn size and its spread, against a 256-px cell: 1.5 units is 171 texels per unit.
  // 0.9 read as crumbs on a 3.9 x 2.8 mess table
  static inline var SZ = 1.1;
  static inline var SZ_VAR = 0.4;
  // one bare room floor cell in this many hundred gets a decal, and how much bigger a floor one draws
  static inline var FLOOR_PCT = 15;
  static inline var FLOOR_SZ = 1.4;
  // the cells of each room kind's sheet that may lie on its FLOOR, in reading order: a telephone and
  // a stapler on the floor of an office read as dropped, not as litter. A kind not here has none
  static var FLOOR_PICK:Map<String, Array<Int>> = [
    'comms' => [ 7, 14 ],
    'briefing' => [ 11, 13 ],
    'mess' => [ 4, 9, 10, 14 ],
    'barracks' => [ 1, 3, 10, 12, 13 ],
    'armory' => [ 3, 9, 15 ],
    'supply' => [ 2, 6, 8, 13, 15 ],
    'medical' => [ 1, 7, 15 ],
    'latrine' => [ 0, 2, 7, 9, 12, 14 ],
  ];
  // the latrine sheet's puddle, laid under every shower's rose (MilitaryInterior.drains) at the floor
  // size
  static inline var PUDDLE = 9;
  // how far a lid's decal stays in from its edge
  static inline var INSET = 0.12;
  // the gear, models-src/military/roomkit_build.py's footprints (local x by local z) and heights, and
  // how far a piece on a top turns off square
  static var GEAR = [
    {
      path: RenderConfig.MODELS.militaryBoots,
      w: 0.68,
      d: 0.5,
      h: MilitaryInterior.BOOTS_H,
    },
    {
      path: RenderConfig.MODELS.militaryRucksack,
      w: 1.0,
      d: 0.55,
      h: MilitaryInterior.RUCKSACK_H,
    },
    {
      path: RenderConfig.MODELS.militaryCanteen,
      w: 0.28,
      d: 0.16,
      h: MilitaryInterior.CANTEEN_H,
    },
  ];
  static inline var GEAR_TURN = 0.35;
  // the gear that may lie on its back half the time, its straps or its flat side down ("allow
  // canteens and backpacks to also lie on their back"): the rucksack and the canteen, not the boots
  static inline var GEAR_LIES = 1;
  // the floor pool under a piece of gear against FacilityDetail.ground's own: a pair of boots' pool
  // was asked 30% smaller
  static inline var GEAR_POOL = 0.7;
  // the barracks sheet's cells that are GEAR, not decals: the boots, the rucksack and the canteen
  static var SOLID:Map<Int, Int> = [
    1 => 0,
    3 => 1,
    12 => 2,
  ];
  // the cells drawn SMALLER than the sheet's SZ, as a fraction of it: every cell fills the same 70%
  // of its square, so a hand of cards came out half a metre across ("cards need to be smaller. and
  // cigarette pack and watch"). Taken to their real size at the half-metre unit: the cards' fan 15
  // cm, a cigarette pack and lighter 12, a watch on its strap 10, the dog tags' chain 20, rolled
  // socks 18
  static var SMALL:Map<String, Map<Int, Float>> = [
    'barracks' => [
      4 => 0.45,
      5 => 0.35,
      10 => 0.4,
      14 => 0.3,
      15 => 0.25,
    ],
  ];
  // the facility the gear grounds itself on, for the build
  static var fac:Facility;
  // how far a clue's centre stays in from its top's edge, and the half-size of the patch round it no
  // decal may roll on
  static inline var CLUE_INSET = 0.55;
  static inline var CLUE_CLEAR = 0.8;
  // how much a unit of gap between a cell centre and a top outweighs a unit of the top's height when
  // picking the top a clue spot lies on: any top covering the centre beats one beside it
  static inline var CLUE_GAP_WEIGHT = 100.0;
  // how far over a bed's top a clue floats: a cot's folded blanket and pillow stand above the canvas
  // lid and cut a strip off the paper, which then drew as its through-wall mark
  static inline var CLUE_BED_LIFT = 0.2;
  // where the clues game.AreaGame lays on the base's furniture rest, by cell (key): the top's point
  // nearest the cell centre and its height. read by the actor pose through groundY and standOff
  static var rests = new Map<Int, { x:Float, z:Float, y:Float }>();

  // THE INSIDES of the armory's lockers and safe: their own pack16, cells 0-5 laid on a locker's floor
  // and hat shelf, 6-9 hung on its walls, 10-15 in the safe ("add some random 2d decals in lockers and
  // safe", "we also want some locker wall clutter"). The pockets are roomkit_build.py's, less the bbox
  // centre render.Models.normalize takes off each glb (locker 0.03, safe 0.035, on z)
  static inline var INSIDE_TEX = 'textures/military/locker-clutter.png';
  static var LOCKER_POCKETS:Array<ArmoryPocket> = [
    {
      x0: -1.82,
      x1: -0.10,
      mouth: 0.62,
      back: -0.43,
      floor: 0.31,
      shelf: 3.25,
      under: 3.2,
      flat: [ 0, 1, 2, 3, 4, 5 ],
      turn: 0.6,
    },
    {
      x0: 0.10,
      x1: 1.82,
      mouth: 0.62,
      back: -0.43,
      floor: 0.31,
      shelf: 3.25,
      under: 3.2,
      flat: [ 0, 1, 2, 3, 4, 5 ],
      turn: 0.6,
    },
  ];
  static var SAFE_POCKET:ArmoryPocket = {
    x0: -0.70,
    x1: 0.70,
    mouth: 0.765,
    back: -0.435,
    floor: 0.28,
    shelf: 1.0286,
    under: 0.9786,
    flat: [ 10, 11, 12, 13, 14, 15 ],
    turn: 0.3,
  };
  // the cells a locker hangs on its walls
  static var LOCKER_WALL = [ 6, 7, 8, 9 ];
  // each cell's drawn size, the 70% its art fills taken to the real thing at the half-metre unit: a
  // folded shirt 30 cm, a photo 12, a ring of keys 14
  static var INSIDE_SZ = [ 0.9, 0.85, 0.55, 0.75, 0.6, 0.65, 0.4, 0.45, 0.5, 0.65, 0.6, 0.85, 0.75, 0.4,
    0.55, 0.65 ];
  // how far a thing keeps off a pocket's walls, and a picture's lowest edge over the floor, its
  // stand-off from the wall, how far a side wall's keeps from the mouth and how far it tilts
  static inline var INSIDE_GAP = 0.06;
  static inline var HANG_Y = 1.3;
  static inline var HANG_OFF = 0.01;
  static inline var HANG_MOUTH = 0.15;
  static inline var HANG_ROLL = 0.25;
  // what a pocket keeps of its colour at its mouth and at its back: roomkit_build.py's POCKET_MOUTH and
  // POCKET_DARK, which its walls carry in COLOR_0, so a thing lying in it darkens as the floor under it
  static inline var POCKET_MOUTH = 0.55;
  static inline var POCKET_DARK = 0.12;
  // the inside mesh being built
  static var inside:MeshBuf;

// every decal in the base's rooms, one mesh per room kind. returns how many landed
  public static function build(scene:Scene, m:Facility, area:AreaGame, lids:Array<MilitaryLid>):Int
    {
      fac = m;
      reserve(area, lids);
      var n = 0;
      var bufs = new Map<String, MeshBuf>();
      for (room in area.generatorInfo.rooms)
        {
          if (room.role == null)
            continue;
          var b = bufs.get(room.role);
          if (b == null)
            {
              b = MeshBufTools.make();
              bufs.set(room.role, b);
            }
          // the room's furniture tops: those whose footprint reaches into it, because a locker stands in
          // its wall cell's margin and its centre is not in the room at all
          var a = CityConfig.cellToWorld(room.x1, room.y1);
          var z = CityConfig.cellToWorld(room.x2, room.y2);
          for (l in lids)
            {
              var f = ClutterSlotTools.turned(l.x, l.z, l.w, l.d, l.yaw);
              if (f.x + f.hw > a.x - CELL / 2 + EPS &&
                  f.x - f.hw < z.x + CELL / 2 - EPS &&
                  f.z + f.hd > a.z - CELL / 2 + EPS &&
                  f.z - f.hd < z.z + CELL / 2 - EPS)
                n += lid(b, l, room.role);
            }
          // and its bare floor, the odd cell, never the one inside a doorway, which is walked over
          // ("dont spawn clutter right in front of doors")
          var pick = FLOOR_PICK.get(room.role);
          if (pick == null)
            continue;
          for (row in room.y1...room.y2 + 1)
            for (col in room.x1...room.x2 + 1)
              {
                if (!area.isWalkable(col, row) ||
                    area.getCellType(col, row) == Const.TILE_MIL_SHOWER ||
                    area.getObjectsAt(col, row).length > 0 ||
                    FacilityModel.nearDoor(m, col, row))
                  continue;
                var h = FacilityModel.mix((col * 374761393) ^ (row * 40503));
                if (h % 100 >= FLOOR_PCT)
                  continue;
                var c = CityConfig.cellToWorld(col, row);
                var idx = pick[(h >> 3) % pick.length];
                var y = FacilityGround.surfY(m.surf[row][col]);
                if (solid(room.role, idx) < 0)
                  {
                    emit(b, c.x, c.z, (FLOOR_SZ + ((h >> 7) % 1000 / 1000.0) * SZ_VAR) *
                      small(room.role, idx), (h >> 17) % 6283 / 1000.0, idx, y + FacilityStyle.CLUTTER_Y);
                    n++;
                    continue;
                  }
                // a piece of gear in the cell, standing on the floor like any other piece
                if (gear({
                  x: c.x,
                  z: c.z,
                  yaw: 0.0,
                  w: CELL - 1.0,
                  d: CELL - 1.0,
                  y: y,
                  kind: UNDER,
                  col: col,
                  row: row,
                  claims: [],
                }, [], solid(room.role, idx), h, true) != null)
                  n++;
              }
        }
      var wet = bufs.get('latrine');
      if (wet != null)
        for (p in MilitaryInterior.drains)
          {
            var at = CityConfig.worldToCell(p.x, p.z);
            var h = FacilityModel.mix((at.col * 374761393) ^ (at.row * 40503));
            emit(wet, p.x, p.z, FLOOR_SZ + (h % 1000 / 1000.0) * SZ_VAR, (h >> 11) % 6283 / 1000.0, PUDDLE,
              FacilityGround.surfY(m.surf[at.row][at.col]) + FacilityStyle.CLUTTER_Y);
            n++;
          }
      for (role in bufs.keys())
        add(scene, bufs.get(role), 'textures/military/' + role + '-clutter.png');
      return n;
    }

// keep each clue spot (game.AreaGame.clueSpawnPoints) bare on the top its cell holds: the point
// nearest the cell centre, inset from the edge, claimed in the lid's frame before any decal rolls,
// and remembered for the clue drawn there. A cell's top is the NEAREST lid to its centre, the HIGHEST
// of those covering it: a bunk's two decks are one lid each, both spanning its two cells, and a clue
// on the lower one lay under the upper and drew as its through-wall mark. The blanket also stops
// short of the pillow cell, whose clue then lies at the blanket's head end
  static function reserve(area:AreaGame, lids:Array<MilitaryLid>):Void
    {
      rests.clear();
      for (pt in area.clueSpawnPoints)
        {
          var c = CityConfig.cellToWorld(pt.x, pt.y);
          var best:MilitaryLid = null;
          var bestScore = CELL / 2 * CLUE_GAP_WEIGHT;
          for (l in lids)
            {
              if (l.kind == UNDER ||
                  l.kind == SHELF ||
                  l.kind == LOCKER)
                continue;
              // how far the centre lies outside the top, weighted far over its height
              var f = ClutterSlotTools.turned(l.x, l.z, l.w, l.d, l.yaw);
              var gap = Math.max(0.0, Math.abs(c.x - f.x) - f.hw) +
                Math.max(0.0, Math.abs(c.z - f.z) - f.hd);
              var score = gap * CLUE_GAP_WEIGHT - l.y;
              if (score < bestScore)
                {
                  best = l;
                  bestScore = score;
                }
            }
          if (best == null)
            continue;
          // the cell centre in the lid's frame (emit's turn, backwards), held inside the top
          var lc = Math.cos(best.yaw), ls = Math.sin(best.yaw);
          var dx = c.x - best.x, dz = c.z - best.z;
          var rx = Math.max(0.0, best.w / 2 - CLUE_INSET);
          var rz = Math.max(0.0, best.d / 2 - CLUE_INSET);
          var lx = Math.max(-rx, Math.min(rx, dx * lc - dz * ls));
          var lz = Math.max(-rz, Math.min(rz, dx * ls + dz * lc));
          best.claims.push({
            x: lx,
            z: lz,
            hw: CLUE_CLEAR,
            hd: CLUE_CLEAR,
          });
          rests.set(key(pt.x, pt.y), {
            x: best.x + lx * lc + lz * ls,
            z: best.z - lx * ls + lz * lc,
            y: best.y + (best.kind == BED ? CLUE_BED_LIFT : 0.0),
          });
        }
    }

  static inline function key(col:Int, row:Int):Int
    {
      return (row << 16) | col;
    }

// a clue spot's top height, else the compound's own ground. the base's render.world.WorldCtx.ground
  public static function groundY(m:Facility, x:Float, z:Float):Float
    {
      var c = CityConfig.worldToCell(x, z);
      var r = rests.get(key(c.col, c.row));
      return (r != null ? r.y : render.facility.FacilityTables.groundY(m, x, z));
    }

// a clue spot's resting point off its cell centre, else the compound's own. the base's
// render.world.WorldCtx.standOff
  public static function standOff(m:Facility, col:Int, row:Int):{ x:Float, z:Float }
    {
      var r = rests.get(key(col, row));
      if (r == null)
        return render.facility.FacilityDeco.standOff(m, col, row);
      var c = CityConfig.cellToWorld(col, row);
      return {
        x: r.x - c.x,
        z: r.z - c.z,
      };
    }

// one lid's worth, rejection-sampled in the lid's own frame round what already stands on it, then
// turned into the world. An item that finds no room in CLUTTER_TRIES is dropped
  static function lid(b:MeshBuf, l:MilitaryLid, role:String):Int
    {
      // its height in the seed too, or a bunk's two decks roll the same bedding
      var g = FacilityModel.mix((l.col * 1103515245) ^ (l.row * 12345) ^
        Std.int(l.x * 31 + l.z * 17 + l.y * 53));
      var range = switch (l.kind)
        {
          case DESK: [ 1, 3 ];
          case TABLE: [ 2, 4 ];
          case CABINET, LOCKER, SEAT: [ 0, 1 ];
          case SHELF: [ 1, 2 ];
          default: [ 0, 2 ];
        };
      var want = range[0] + g % (range[1] - range[0] + 1);
      var pick = (l.kind == UNDER ? FLOOR_PICK.get(role) : null);
      if (l.kind == UNDER &&
          pick == null)
        return 0;
      var spots = l.claims.copy();
      var lc = Math.cos(l.yaw), ls = Math.sin(l.yaw);
      var n = 0;
      // the gear first, half the time where the top takes any: it is the bigger piece, so it claims
      // before the decals roll
      var k = kit(l.kind, role);
      if (k.length > 0 &&
          (g >>> 9) % 2 == 0 &&
          gear(l, spots, k[(g >>> 17) % k.length], g, l.kind == UNDER) != null)
        n++;
      for (i in 0...want)
        {
          var h = FacilityModel.mix(g ^ ((i + 1) * 40503));
          var idx = (pick != null ? pick[(h >>> 22) % pick.length] : (h >>> 22) % (COLS * COLS));
          // gear in place of its decal, where it fits
          if (solid(role, idx) >= 0)
            {
              if (fits(l.kind, solid(role, idx)) &&
                  gear(l, spots, solid(role, idx), h, l.kind == UNDER) != null)
                n++;
              continue;
            }
          var sz = Math.min(SZ + ((h % 1000) / 1000) * SZ_VAR,
            Math.min(l.w, l.d) * FacilityStyle.CLUTTER_SLOT_FILL) * small(role, idx);
          var rx = l.w / 2 - sz * 0.5 - INSET;
          var rz = l.d / 2 - sz * 0.5 - INSET;
          if (rx <= 0 ||
              rz <= 0)
            continue;
          var yaw = ((h >>> 12) % 1000) / 1000 * 2 * Math.PI;
          var box = ClutterSlotTools.turned(0.0, 0.0, sz, sz, yaw);
          var ok = false;
          for (t in 0...FacilityStyle.CLUTTER_TRIES)
            {
              var hh = FacilityModel.mix(h ^ ((t + 1) * 83492791));
              box.x = (((hh % 1000) / 1000) * 2 - 1) * rx;
              box.z = ((((hh >>> 10) % 1000) / 1000) * 2 - 1) * rz;
              ok = !ClutterSlotTools.hits(spots, box.x, box.z, box.hw, box.hd);
              if (ok)
                break;
            }
          if (!ok)
            continue;
          spots.push(box);
          // the lid's frame into the world, MilitaryInterior.stood's turn, which is emit's backwards
          emit(b, l.x + box.x * lc + box.z * ls, l.z - box.x * ls + box.z * lc, sz, yaw - l.yaw, idx,
            l.y + FacilityStyle.CLUTTER_Y);
          n++;
        }
      return n;
    }

// the GEAR a top of this kind may stand: any locker's, and in the barracks the bedding, a footlocker's
// lid and the floor under a bunk
  static function kit(kind:LidKind, role:String):Array<Int>
    {
      if (kind != LOCKER &&
          role != 'barracks')
        return [];
      return [for (k in 0...GEAR.length) if (fits(kind, k)) k];
    }

// may gear `k` stand on a top of this kind? no boots on a blanket, and only boots under a bunk: the
// 1.21 rucksack stood through its 0.9 bottom deck, and a canteen down there is lost
  static inline function fits(kind:LidKind, k:Int):Bool
    {
      return !(kind == BED && k == 0) &&
        !(kind == UNDER && k > 0);
    }

// how much smaller than the sheet's size this role's cell draws, 1 for most
  static inline function small(role:String, idx:Int):Float
    {
      var k = SMALL.get(role);
      return (k != null &&
        k.exists(idx) ? k.get(idx) : 1.0);
    }

// which GEAR piece a cell of this role's sheet stands as, -1 for a decal
  static inline function solid(role:String, idx:Int):Int
    {
      return (role == 'barracks' &&
        SOLID.exists(idx) ? SOLID.get(idx) : -1);
    }

// one piece of gear `k` stood on the lid, rejection-sampled round `spots` like a decal and claimed in
// it: square to the lid give or take GEAR_TURN (either way round, but a locker's facing out), or any
// way at all on a floor (`loose`). From GEAR_LIES on it lies on its back half the time, pitched a
// quarter turn so its depth is its height and its height runs along the lid. Its box in the lid's
// frame, or null when it found no room
  static function gear(l:MilitaryLid, spots:Array<ClutterSlot>, k:Int, h:Int, loose:Bool):ClutterSlot
    {
      var p = GEAR[k];
      var t = ((h >>> 3) % 1000) / 1000;
      var lie = (k >= GEAR_LIES &&
        (h >>> 23) % 2 == 0);
      // its footprint across, and how tall it stands
      var pd = (lie ? p.h : p.d);
      var ph = (lie ? p.d : p.h);
      // a locker's faces the way its doors do, or a rucksack up there showed the room its straps; one
      // on its back may lie either way along the lid
      var flip = (l.kind == LOCKER ? 0 : (h >>> 13) % 2);
      var yaw = (loose ? t * 2 * Math.PI : flip * Math.PI + (t * 2 - 1) * GEAR_TURN) +
        (lie ? ((h >>> 24) % 2) * Math.PI / 2 : 0.0);
      var box = ClutterSlotTools.turned(0.0, 0.0, p.w, pd, yaw);
      var rx = l.w / 2 - box.hw - INSET;
      var rz = l.d / 2 - box.hd - INSET;
      if (rx < 0 ||
          rz < 0)
        return null;
      for (i in 0...FacilityStyle.CLUTTER_TRIES)
        {
          var hh = FacilityModel.mix(h ^ ((i + 1) * 668265263));
          box.x = (((hh % 1000) / 1000) * 2 - 1) * rx;
          box.z = ((((hh >>> 10) % 1000) / 1000) * 2 - 1) * rz;
          if (ClutterSlotTools.hits(spots, box.x, box.z, box.hw, box.hd))
            continue;
          spots.push(box);
          var lc = Math.cos(l.yaw), ls = Math.sin(l.yaw);
          var x = l.x + box.x * lc + box.z * ls;
          var z = l.z - box.x * ls + box.z * lc;
          // pitched back about its base's centre it lies half its depth down and its height out
          // toward its local -z, so it is lifted by the one and its place moved back by half the other
          var a = l.yaw + yaw;
          MilitaryInterior.place(p.path, {
            x: x + (lie ? p.h / 2 * Math.sin(a) : 0.0),
            z: z + (lie ? p.h / 2 * Math.cos(a) : 0.0),
            yaw: a,
            y: l.y + (lie ? p.d / 2 : 0.0),
            pitch: (lie ? -Math.PI / 2 : null),
          });
          // and its shadow ("do these chests throw shadows? they should. and boots as well"): on a
          // floor the one call for anything standing there, on a top a round pool kept on the lid
          var t = ClutterSlotTools.turned(x, z, p.w, pd, a);
          var f = ClutterSlotTools.turned(l.x, l.z, l.w, l.d, l.yaw);
          if (l.kind == UNDER)
            FacilityDetail.ground(fac, {
              col: l.col,
              row: l.row,
              len: 1,
              alongX: true,
              rect: {
                x0: x - t.hw,
                x1: x + t.hw,
                z0: z - t.hd,
                z1: z + t.hd,
              },
              h: ph,
              pool: GEAR_POOL,
            });
          else
            FacilityDetail.deck({
              cx: x,
              cz: z,
              hw: p.w / 2,
              hd: pd / 2,
              yaw: a,
              y: l.y,
              plate: {
                x0: l.x - f.hw,
                x1: l.x + f.hw,
                z0: l.z - f.hd,
                z1: l.z + f.hd,
              },
            });
          return box;
        }
      return null;
    }

// one pack16 cell as a yawed quad lying flat at height `y`, v flipped (FacilityClutter.emit's)
  static function emit(b:MeshBuf, x:Float, z:Float, sz:Float, yaw:Float, idx:Int, y:Float):Void
    {
      var hs = sz * 0.5;
      var cs = Math.cos(yaw), sn = Math.sin(yaw);
      var lx = [ -hs, hs, hs, -hs ];
      var lz = [ hs, hs, -hs, -hs ];
      var wx = [], wz = [];
      for (i in 0...4)
        {
          wx.push(x + lx[i] * cs - lz[i] * sn);
          wz.push(z + lx[i] * sn + lz[i] * cs);
        }
      var cc = idx % COLS, cr = Std.int(idx / COLS);
      var u0 = cc / COLS, u1 = (cc + 1) / COLS;
      var v0 = 1 - (cr + 1) / COLS, v1 = 1 - cr / COLS;
      MeshBufTools.quad(b,
        [wx[0], y, wz[0]], [wx[1], y, wz[1]], [wx[2], y, wz[2]], [wx[3], y, wz[3]],
        [u0, v0, u1, v0, u1, v1, u0, v1]);
    }

// the small things in the armory's lockers and its safe, one mesh off their own sheet: on a pocket's
// floor and its shelf, and on a locker's walls under the shelf, every one shaded down the pocket's
// depth as its walls are. Behind shut leaves they are simply not seen
  public static function insides(scene:Scene, lockers:Array<PropPlace>, safes:Array<PropPlace>):Void
    {
      inside = MeshBufTools.make();
      for (p in lockers)
        for (k in 0...LOCKER_POCKETS.length)
          {
            var q = LOCKER_POCKETS[k];
            var h = FacilityModel.mix(Std.int(p.x * 131) ^ (Std.int(p.z * 197) << 8) ^
              ((k + 1) * 40503));
            lay(p, q, q.floor, h % 3, h);
            lay(p, q, q.shelf, (h >>> 4) % 2, FacilityModel.mix(h + 1));
            hang(p, q, (h >>> 6) % 3, FacilityModel.mix(h + 2));
          }
      // a safe is never empty
      for (p in safes)
        {
          var q = SAFE_POCKET;
          var h = FacilityModel.mix(Std.int(p.x * 131) ^ (Std.int(p.z * 197) << 8));
          lay(p, q, q.floor, 1 + h % 2, h);
          lay(p, q, q.shelf, 1 + (h >>> 4) % 2, FacilityModel.mix(h + 1));
        }
      add(scene, inside, INSIDE_TEX, true);
    }

// one inside quad, for render.facility.FacilityWarm: the room sheets' cut lambert with vertexColors,
// which three folds into the program key
  public static function warmInside(scene:Scene):Void
    {
      inside = MeshBufTools.make();
      square({
        x: 0.0,
        z: 0.0,
        yaw: 0.0,
        y: 0.0,
      }, SAFE_POCKET, [ 0.0, SAFE_POCKET.floor, 0.0 ], [ 1.0, 0.0, 0.0 ], [ 0.0, 0.0, -1.0 ], 0.3, 10);
      add(scene, inside, INSIDE_TEX, true);
    }

// up to `n` flat things on a pocket surface at height `y`, one to each of n equal slots across it
  static function lay(p:PropPlace, q:ArmoryPocket, y:Float, n:Int, h:Int):Void
    {
      var span = (q.x1 - q.x0) / Math.max(1, n);
      for (i in 0...n)
        {
          h = FacilityModel.mix(h + i + 1);
          var idx = q.flat[h % q.flat.length];
          var a = (unit(h, 4) * 2 - 1) * q.turn;
          var c = Math.cos(a), sn = Math.sin(a);
          var reach = Math.abs(c) + Math.abs(sn);
          var sz = Math.min(INSIDE_SZ[idx], Math.min(span, q.mouth - q.back) / reach - INSIDE_GAP * 2);
          var he = sz / 2 * reach;
          var x0 = q.x0 + i * span + he + INSIDE_GAP;
          var x1 = q.x0 + (i + 1) * span - he - INSIDE_GAP;
          var z0 = q.back + he + INSIDE_GAP;
          var z1 = q.mouth - he - INSIDE_GAP;
          if (sz <= 0 ||
              x1 < x0 ||
              z1 < z0)
            continue;
          var at = [ x0 + (x1 - x0) * unit(h, 12), y + FacilityStyle.CLUTTER_Y,
            z0 + (z1 - z0) * unit(h, 20) ];
          square(p, q, at, [ c, 0.0, -sn ], [ -sn, 0.0, -c ], sz / 2, idx);
        }
    }

// up to `n` pictures on a locker pocket's walls under its shelf, each on a wall of its own: the back,
// or a side wall toward the mouth
  static function hang(p:PropPlace, q:ArmoryPocket, n:Int, h:Int):Void
    {
      var first = h % 3;
      for (i in 0...n)
        {
          h = FacilityModel.mix(h + i + 1);
          var wall = (first + i) % 3;
          var idx = LOCKER_WALL[h % LOCKER_WALL.length];
          var hs = INSIDE_SZ[idx] / 2;
          var y = q.floor + HANG_Y + hs +
            (q.under - INSIDE_GAP - q.floor - HANG_Y - hs * 2) * unit(h, 4);
          var along = unit(h, 20);
          // the wall's inward normal, and the picture's centre on it
          var nx = (wall == 1 ? 1.0 : wall == 2 ? -1.0 : 0.0);
          var nz = (wall == 0 ? 1.0 : 0.0);
          var room = hs + INSIDE_GAP;
          var at = (wall == 0 ?
            [ q.x0 + room + (q.x1 - q.x0 - room * 2) * along, y, q.back + HANG_OFF ] :
            [ (wall == 1 ? q.x0 + HANG_OFF : q.x1 - HANG_OFF), y,
              q.back + room + (q.mouth - q.back - room - hs - HANG_MOUTH) * along ]);
          // its right as it is looked at from inside the pocket, and up, tilted together
          var r = (unit(h, 12) * 2 - 1) * HANG_ROLL;
          var c = Math.cos(r), sn = Math.sin(r);
          square(p, q, at, [ nz * c, sn, -nx * c ], [ -nz * sn, c, nx * sn ], hs, idx);
        }
    }

// one square of the inside sheet's cell `idx` round `at`, its right `u` and its up `v`, all in the
// placed glb's frame: into the world on the placement's turn, each corner shaded at its depth
  static function square(p:PropPlace, q:ArmoryPocket, at:Array<Float>, u:Array<Float>, v:Array<Float>,
      hs:Float, idx:Int):Void
    {
      var cs = Math.cos(p.yaw), sn = Math.sin(p.yaw);
      var local = [for (k in [ [ -1, -1 ], [ 1, -1 ], [ 1, 1 ], [ -1, 1 ] ])
        [for (j in 0...3) at[j] + (u[j] * k[0] + v[j] * k[1]) * hs]];
      var w = [for (l in local)
        [ p.x + l[0] * cs + l[2] * sn, p.y + l[1], p.z - l[0] * sn + l[2] * cs ]];
      var cc = idx % COLS, cr = Std.int(idx / COLS);
      var u0 = cc / COLS, u1 = (cc + 1) / COLS;
      var v0 = 1 - (cr + 1) / COLS, v1 = 1 - cr / COLS;
      MeshBufTools.quadC(inside, w[0], w[1], w[2], w[3], [ u0, v0, u1, v0, u1, v1, u0, v1 ],
        [for (l in local) dark(q, l[2])]);
    }

// what a pocket keeps of its colour at local depth z, roomkit_build.py's `shade`: POCKET_MOUTH at its
// mouth, falling straight to POCKET_DARK at its back
  static inline function dark(q:ArmoryPocket, z:Float):Float
    {
      var t = Math.max(0.0, Math.min(1.0, (q.mouth - z) / (q.mouth - q.back)));
      return POCKET_MOUTH + (POCKET_DARK - POCKET_MOUTH) * t;
    }

// a 0..1 roll off bits `s` up of hash `h`
  static inline function unit(h:Int, s:Int):Float
    {
      return ((h >>> s) % 1000) / 1000;
    }

// one sheet's decals as one mesh, FacilityClutter.add's material and for its reasons; `colors` takes
// the buffer's per-vertex tint (the insides' depth shading)
  static function add(scene:Scene, b:MeshBuf, tex:String, ?colors:Bool):Void
    {
      if (b.idx.length == 0)
        return;
      var mesh = new Mesh(FacilityGeom.geom(b), VisionMask.patch(new MeshLambertMaterial({
        map: Textures.loadTexture(tex, 'wall', 1),
        alphaTest: FacilityStyle.CLUTTER_CUT,
        side: THREE.DoubleSide,
        vertexColors: colors == true,
      })));
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }
}
