package render.military;

import three.Three;
import citygen.CityConfig;
import game.AreaGame;
import render.Textures;
import render.facility.ClutterSlot;
import render.facility.ClutterSlot.ClutterSlotTools;
import render.facility.FacilityGeom;
import render.facility.FacilityGround;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityStyle;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// one furniture top a base room's clutter may lie on, recorded by render.military.MilitaryInterior
// as it stands the piece: the lid's centre and turn, its extents in its own frame (w along local x,
// d along local z), its height, how many decals it takes, and what already stands on it
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
  // the most decals it rolls, and the fewest it keeps
  max:Int,
  min:Int,
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
// ONE MERGED MESH PER SHEET, so a base pays at most one call per room kind it has
class MilitaryClutter
{
  // the sheets' grid
  static inline var COLS = 4;
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

// every decal in the base's rooms, one mesh per room kind. returns how many landed
  public static function build(scene:Scene, m:Facility, area:AreaGame, lids:Array<MilitaryLid>):Int
    {
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
          // the room's furniture tops
          for (l in lids)
            if (l.col >= room.x1 &&
                l.col <= room.x2 &&
                l.row >= room.y1 &&
                l.row <= room.y2)
              n += lid(b, l);
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
                emit(b, c.x, c.z, FLOOR_SZ + ((h >> 7) % 1000 / 1000.0) * SZ_VAR,
                  (h >> 17) % 6283 / 1000.0, pick[(h >> 3) % pick.length],
                  FacilityGround.surfY(m.surf[row][col]) + FacilityStyle.CLUTTER_Y);
                n++;
              }
        }
      for (role in bufs.keys())
        add(scene, bufs.get(role), 'textures/military/' + role + '-clutter.png');
      return n;
    }

// one lid's worth, rejection-sampled in the lid's own frame round what already stands on it, then
// turned into the world. An item that finds no room in CLUTTER_TRIES is dropped
  static function lid(b:MeshBuf, l:MilitaryLid):Int
    {
      var g = FacilityModel.mix((l.col * 1103515245) ^ (l.row * 12345) ^
        Std.int(l.x * 31 + l.z * 17));
      var want = l.min + g % (l.max - l.min + 1);
      var spots = l.claims.copy();
      var lc = Math.cos(l.yaw), ls = Math.sin(l.yaw);
      var n = 0;
      for (i in 0...want)
        {
          var h = FacilityModel.mix(g ^ ((i + 1) * 40503));
          var sz = Math.min(SZ + ((h % 1000) / 1000) * SZ_VAR,
            Math.min(l.w, l.d) * FacilityStyle.CLUTTER_SLOT_FILL);
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
          emit(b, l.x + box.x * lc + box.z * ls, l.z - box.x * ls + box.z * lc, sz, yaw - l.yaw,
            (h >>> 22) % (COLS * COLS), l.y + FacilityStyle.CLUTTER_Y);
          n++;
        }
      return n;
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
