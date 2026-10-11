package render.military;

import three.Three;
import citygen.CityConfig;
import game.AreaGame;
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
  // a footlocker's lid, 0-2
  FOOTLOCKER;
  // a filing or medical cabinet's top, 0-1
  CABINET;
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

// every decal in the base's rooms, one mesh per room kind. returns how many landed
  public static function build(scene:Scene, m:Facility, area:AreaGame, lids:Array<MilitaryLid>):Int
    {
      fac = m;
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
          // and its bare floor, the odd cell
          var pick = FLOOR_PICK.get(room.role);
          if (pick == null)
            continue;
          for (row in room.y1...room.y2 + 1)
            for (col in room.x1...room.x2 + 1)
              {
                if (!area.isWalkable(col, row) ||
                    area.getObjectsAt(col, row).length > 0)
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
      for (role in bufs.keys())
        add(scene, bufs.get(role), 'textures/military/' + role + '-clutter.png');
      return n;
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
          case CABINET, LOCKER: [ 0, 1 ];
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
// way at all on a floor (`loose`). Its box in the lid's frame, or null when it found no room
  static function gear(l:MilitaryLid, spots:Array<ClutterSlot>, k:Int, h:Int, loose:Bool):ClutterSlot
    {
      var p = GEAR[k];
      var t = ((h >>> 3) % 1000) / 1000;
      // a locker's faces the way its doors do, or a rucksack up there showed the room its straps
      var flip = (l.kind == LOCKER ? 0 : (h >>> 13) % 2);
      var yaw = (loose ? t * 2 * Math.PI : flip * Math.PI + (t * 2 - 1) * GEAR_TURN);
      var box = ClutterSlotTools.turned(0.0, 0.0, p.w, p.d, yaw);
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
          MilitaryInterior.put(p.path, x, z, l.yaw + yaw, l.y);
          // and its shadow ("do these chests throw shadows? they should. and boots as well"): on a
          // floor the one call for anything standing there, on a top a round pool kept on the lid
          var t = ClutterSlotTools.turned(x, z, p.w, p.d, l.yaw + yaw);
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
              h: p.h,
              pool: GEAR_POOL,
            });
          else
            FacilityDetail.deck({
              cx: x,
              cz: z,
              hw: p.w / 2,
              hd: p.d / 2,
              yaw: l.yaw + yaw,
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

// one sheet's decals as one mesh, FacilityClutter.add's material and for its reasons
  static function add(scene:Scene, b:MeshBuf, tex:String):Void
    {
      if (b.idx.length == 0)
        return;
      var mesh = new Mesh(FacilityGeom.geom(b), VisionMask.patch(new MeshLambertMaterial({
        map: Textures.loadTexture(tex, 'wall', 1),
        alphaTest: FacilityStyle.CLUTTER_CUT,
        side: THREE.DoubleSide,
      })));
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }
}
