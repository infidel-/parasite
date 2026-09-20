package render.corp;

import three.Three;
import citygen.CityConfig;
import render.Models;
import render.RenderConfig;
import render.facility.ClutterSlot;
import render.facility.FacilityDetail;
import render.facility.FacilityGeom;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.ContactMask;
import render.world.VisionMask;

// what the pass placed, for __corp()
typedef CorpPropSet = {
  var chairs:Int;      // one per manned desk cell
  var monitors:Int;    // and one workstation each, monitor + keyboard
  var plants:Int;
  var coolers:Int;
  var printers:Int;
  var pans:Int;        // WC pans, one per stall
};

// one floor-standing family and where it is allowed to stand
typedef FloorProp = {
  var path:String;
  var h:Float;         // world height; render.Models.instanced scales by HEIGHT alone
  var d:Float;         // depth ACROSS the wall it backs onto
  var w:Float;         // and width ALONG it — the other half of the footprint the field darkens
  var on:Surf;         // the floor surface it belongs to
};

// the seven glb props of the corp tower: the workstation on a desk, the chair at it, the WC pan in
// a stall, and the three things that stand against a wall.
//
// ONE PASS AND NOT FIVE, which is the same call render.corp.CorpFurniture made for the emitted
// families. A prop pass is a walk of the grid, a hand test and a placement list; splitting it per
// family would clone the walk five times to save nothing, and every one of these has to agree with
// the others about which cell is taken.
//
// WALL-HUGGING, like every standing prop indoors: an actor may clip one only by walking into a
// wall, never by crossing a room. The placement comes off FacilityGeom.slab's own FACE and never
// off the cell boundary — a corp wall slab is centred in its cell, so a prop put on the boundary
// stands a whole unit inside the masonry.
//
// RENDER-ONLY AND UNSTAMPED, the contract render.facility.FacilityKit and FacilityDebris run on:
// nothing is written to the tiles, so a plant is walked straight through and every corp area
// already saved gets its props the moment it is drawn again.
class CorpProps
{
  static inline var CELL = CityConfig.CELL;

  // the four cell-edge directions, in FacilityGeom.face's numbering: 0 = -z, 1 = +z, 2 = -x, 3 = +x
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

  // the three that stand against a wall, each gated on ONE floor surface so no two families can
  // ever want the same cell however they are tuned later — the same no-arbitration trick
  // FacilityKit's header argues for
  static final FLOOR:Array<FloorProp> = [
    {
      path: RenderConfig.MODELS.corpPlant,
      h: CorpStyle.PLANT_H,
      d: CorpStyle.PLANT_W,
      w: CorpStyle.PLANT_W,
      on: Surf.CARPET,
    },
    {
      path: RenderConfig.MODELS.corpCooler,
      h: CorpStyle.COOLER_H,
      d: CorpStyle.COOLER_W,
      w: CorpStyle.COOLER_W,
      on: Surf.KITCHEN,
    },
    {
      path: RenderConfig.MODELS.corpPrinter,
      h: CorpStyle.PRINTER_H,
      d: CorpStyle.PRINTER_D,
      w: CorpStyle.PRINTER_W,
      on: Surf.OPEN,
    },
  ];

// every glb batch on the floor plate, and the census of what went into them
  public static function build(scene:Scene, m:Facility):{ batches:Array<Models.InstancedProp>,
      n:CorpPropSet }
    {
      var n:CorpPropSet = {
        chairs: 0,
        monitors: 0,
        plants: 0,
        coolers: 0,
        printers: 0,
        pans: 0,
      };
      var chairs = [];
      var mons = [];
      var keys = [];
      var pans = [];
      var floors = [for (_ in FLOOR) new Array<Models.PropPlace>()];
      desks(m, chairs, mons, keys);
      stalls(m, pans);
      standing(m, floors);
      n.chairs = chairs.length;
      n.monitors = mons.length;
      n.pans = pans.length;
      n.plants = floors[0].length;
      n.coolers = floors[1].length;
      n.printers = floors[2].length;

      var out = [];
      out.push(batch(scene, RenderConfig.MODELS.corpChair, chairs, CorpStyle.CHAIR_H));
      out.push(batch(scene, RenderConfig.MODELS.corpMonitor, mons, CorpStyle.MON_H));
      out.push(batch(scene, RenderConfig.MODELS.corpKeyboard, keys, CorpStyle.KEY_H));
      out.push(batch(scene, RenderConfig.MODELS.corpWc, pans, CorpStyle.WC_H));
      for (i in 0...FLOOR.length)
        out.push(batch(scene, FLOOR[i].path, floors[i], FLOOR[i].h));
      return {
        batches: out,
        n: n,
      };
    }

// one instanced batch, and the three things every indoor batch in this game does behind the loader
// callback — the mesh does not exist until the glb resolves
  static function batch(scene:Scene, path:String, places:Array<Models.PropPlace>,
      h:Float):Models.InstancedProp
    {
      var p = Models.instanced(scene, path, places, h, SOLID);
      if (places.length > 0)
        Models.get(path, function(_)
          {
            VisionMask.patchMesh(p.mesh);
            // the room, for anything on the prop that stayed MeshStandard to reflect
            render.world.PropEnv.apply(p.mesh.material);
            // AND NOTHING ON THE PLATE CASTS. an instanced batch is drawn into the moon's shadow
            // map as many times as into the frame, so a second draw is a second call the moment the
            // batch is on screen at all — and a tower floor has no moon over it in the first place
            p.mesh.castShadow = false;
          });
      return p;
    }

// the workstation and the seat at every manned desk cell.
//
// A DESK'S BACK IS NOT ALWAYS A WALL, which is the one thing this cannot borrow from the compound:
// an open-plan run backs onto a CUBICLE SPINE or onto the next desk, and FacilityTables.wallHand
// only knows about masonry. `backHand` takes the first hand that is not clear floor, so a spine
// serves exactly as a wall does, and the seat is the opposite hand — a desk nobody can sit at is
// not a desk, so it carries nothing at all rather than a monitor with no chair
  static function desks(m:Facility, chairs:Array<Models.PropPlace>, mons:Array<Models.PropPlace>,
      keys:Array<Models.PropPlace>):Void
    {
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!m.table[row][col])
              continue;
            var s = m.surf[row][col];
            if (s != Surf.OPEN &&
                s != Surf.CUBICLE &&
                s != Surf.EXEC)
              continue;
            var dir = backHand(m, col, row);
            if (dir < 0 ||
                !clear(m, col + DC[dir ^ 1], row + DR[dir ^ 1]))
              continue;
            var hash = FacilityModel.mix((col * 374761393) ^ (row * 40503));
            var c = CityConfig.cellToWorld(col, row);
            // the seat, in the cell in FRONT of the desk and pulled back toward it. it FACES the
            // desk, which is the hand the desk's back is on
            var cx = c.x + DC[dir ^ 1] * CorpStyle.CHAIR_OUT;
            var cz = c.z + DR[dir ^ 1] * CorpStyle.CHAIR_OUT;
            chairs.push({
              x: cx,
              z: cz,
              yaw: Math.atan2(DC[dir], DR[dir]) +
                (((hash >>> 8) % 1000) / 1000 - 0.5) * 2 * CorpStyle.CHAIR_YAW_JIT,
            });
            ContactMask.prop(cx - CorpStyle.CHAIR_W / 2, cx + CorpStyle.CHAIR_W / 2,
              cz - CorpStyle.CHAIR_W / 2, cz + CorpStyle.CHAIR_W / 2);
            if (hash % CorpStyle.WORK_EVERY != 0)
              continue;
            // and the workstation ON the top, which is the room's worktop height and not a
            // constant — a kitchen counter and a boardroom slab are the same table grid
            var y = CorpFurniture.topH(s);
            var back = CELL / 2 - CorpStyle.MON_BACK;
            mons.push({
              x: c.x + DC[dir] * back,
              z: c.z + DR[dir] * back,
              // the screen's BACK is on the desk's back hand, so its front looks the other way
              yaw: Math.atan2(DC[dir ^ 1], DR[dir ^ 1]),
              y: y,
            });
            keys.push({
              x: c.x + DC[dir] * (back - CorpStyle.KEY_FWD),
              z: c.z + DR[dir] * (back - CorpStyle.KEY_FWD),
              yaw: Math.atan2(DC[dir ^ 1], DR[dir ^ 1]),
              y: y,
            });
          }
    }

// a WC pan in every stall, backed onto the cubicle's own masonry.
//
// the stall is the fixture cell that is NOT part of a run — the same contiguity test CorpFurniture
// .washroom splits basins from cubicles with, asked again rather than cached, because both passes
// are pure functions of the saved grid and neither may depend on having run first
  static function stalls(m:Facility, pans:Array<Models.PropPlace>):Void
    {
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!CorpFurniture.fixture(m, col, row) ||
                CorpFurniture.run(m, col, row))
              continue;
            var dir = -1;
            for (d in 0...4)
              if (FacilityModel.isWall(m, col + DC[d], row + DR[d]))
                {
                  dir = d;
                  break;
                }
            if (dir < 0)
              continue;
            // off the wall's own slab face, with the cistern's back on it: WC_D is what the mesh
            // was built to, so half of it plus the gap is where the centre goes
            var sl = FacilityGeom.slab(m, col + DC[dir], row + DR[dir]);
            var off = CorpStyle.WC_D / 2 + CorpStyle.PROP_GAP;
            var c = CityConfig.cellToWorld(col, row);
            var x = (dir == 2 ? sl.x1 + off : (dir == 3 ? sl.x0 - off : c.x));
            var z = (dir == 0 ? sl.z1 + off : (dir == 1 ? sl.z0 - off : c.z));
            pans.push({
              x: x,
              z: z,
              yaw: Math.atan2(DC[dir ^ 1], DR[dir ^ 1]),
            });
            var pw = (dir < 2 ? CorpStyle.WC_W : CorpStyle.WC_D) / 2;
            var pd = (dir < 2 ? CorpStyle.WC_D : CorpStyle.WC_W) / 2;
            ContactMask.prop(x - pw, x + pw, z - pd, z + pd);
          }
    }

// the three wall-hugging families, thinned by a stride over the whole candidate list
  static function standing(m:Facility, places:Array<Array<Models.PropPlace>>):Void
    {
      for (i in 0...FLOOR.length)
        {
          var p = FLOOR[i];
          var cand = [];
          for (row in 0...m.h)
            for (col in 0...m.w)
              {
                var dir = wall(m, col, row, p.on);
                if (dir < 0)
                  continue;
                cand.push({
                  col: col,
                  row: row,
                  dir: dir,
                });
              }
          var step = Std.int(Math.ceil(cand.length / CorpStyle.FLOOR_MAX));
          if (step > 1)
            cand = [for (k in 0...cand.length) if (k % step == 0) cand[k]];
          for (c in cand)
            {
              var sl = FacilityGeom.slab(m, c.col + DC[c.dir], c.row + DR[c.dir]);
              var off = p.d / 2 + CorpStyle.PROP_GAP;
              var w = CityConfig.cellToWorld(c.col, c.row);
              var x = (c.dir == 2 ? sl.x1 + off : (c.dir == 3 ? sl.x0 - off : w.x));
              var z = (c.dir == 0 ? sl.z1 + off : (c.dir == 1 ? sl.z0 - off : w.z));
              places[i].push({
                x: x,
                z: z,
                yaw: Math.atan2(DC[c.dir ^ 1], DR[c.dir ^ 1]),
              });
              var pw = (c.dir < 2 ? p.w : p.d) / 2;
              var pd = (c.dir < 2 ? p.d : p.w) / 2;
              ContactMask.prop(x - pw, x + pw, z - pd, z + pd);
              // and the shadow on the masonry behind it, which a top-down field cannot reach
              FacilityDetail.stand({
                col: c.col,
                row: c.row,
                dir: c.dir,
                a0: (c.dir < 2 ? x : z) - p.w / 2,
                a1: (c.dir < 2 ? x : z) + p.w / 2,
                len: 1,
                y: 0.0,
                h: p.h,
              });
            }
        }
    }

// may a floor prop of this family stand on this cell, and against which wall? the first hand that
// answers is taken: a cell with masonry on two hands is a room corner and either face puts the
// prop in the same corner
  static function wall(m:Facility, col:Int, row:Int, on:Surf):Int
    {
      if (!FacilityModel.inside(m, col, row) ||
          m.surf[row][col] != on ||
          m.table[row][col] ||
          m.fit[row][col] != 0 ||
          FacilityModel.nearDoor(m, col, row))
        return -1;
      for (dir in 0...4)
        {
          var c = col + DC[dir];
          var r = row + DR[dir];
          if (!FacilityModel.isSolidWall(m, c, r))
            continue;
          // and the wall line has to RUN ON past this cell BOTH ways, or FacilityGeom.slab insets
          // that face by a unit and the prop hangs off the end of the wall it backs onto
          var sc = (dir < 2 ? 1 : 0);
          var sr = (dir < 2 ? 0 : 1);
          if (FacilityGeom.carries(m, c - sc, r - sr) &&
              FacilityGeom.carries(m, c + sc, r + sr))
            return dir;
        }
      return -1;
    }

// what the WORKSTATION on this worktop cell claims, as boxes, or empty for a cell carrying none.
//
// A PURE RE-RUN OF `desks` AND NOT A CACHED LIST, the discipline every other pure-function-of-the-
// grid pass in this layer keeps: render.corp.CorpClutter has to scatter AROUND the monitor and the
// keyboard, and neither pass may depend on having run first. The alternative is a shared claim
// list, which is a second thing to keep in step
  public static function claims(m:Facility, col:Int, row:Int):Array<ClutterSlot>
    {
      if (!m.table[row][col])
        return [];
      var s = m.surf[row][col];
      if (s != Surf.OPEN &&
          s != Surf.CUBICLE &&
          s != Surf.EXEC)
        return [];
      var dir = backHand(m, col, row);
      if (dir < 0 ||
          !clear(m, col + DC[dir ^ 1], row + DR[dir ^ 1]))
        return [];
      var hash = FacilityModel.mix((col * 374761393) ^ (row * 40503));
      if (hash % CorpStyle.WORK_EVERY != 0)
        return [];
      var c = CityConfig.cellToWorld(col, row);
      var back = CELL / 2 - CorpStyle.MON_BACK;
      // the two boxes, each at the yaw it is really drawn at: a monitor runs WIDE across the desk
      // and a keyboard likewise, so which of the two world axes each spans is what `dir` says
      var alongX = (dir < 2);
      var mw = (alongX ? CorpStyle.MON_W : CorpStyle.MON_D) / 2;
      var md = (alongX ? CorpStyle.MON_D : CorpStyle.MON_W) / 2;
      var kw = (alongX ? CorpStyle.KEY_W : CorpStyle.KEY_D) / 2;
      var kd = (alongX ? CorpStyle.KEY_D : CorpStyle.KEY_W) / 2;
      return [
        {
          x: c.x + DC[dir] * back,
          z: c.z + DR[dir] * back,
          hw: mw,
          hd: md,
        },
        {
          x: c.x + DC[dir] * (back - CorpStyle.KEY_FWD),
          z: c.z + DR[dir] * (back - CorpStyle.KEY_FWD),
          hw: kw,
          hd: kd,
        },
      ];
    }

// which hand a worktop cell has its back on — masonry, a cubicle spine, or the next worktop
  static function backHand(m:Facility, col:Int, row:Int):Int
    {
      for (d in 0...4)
        if (!clear(m, col + DC[d], row + DR[d]))
          return d;
      return -1;
    }

// is this cell floor somebody can stand on?
  static inline function clear(m:Facility, col:Int, row:Int):Bool
    {
      return FacilityModel.inside(m, col, row) &&
        !FacilityModel.isWall(m, col, row) &&
        !m.table[row][col] &&
        m.fit[row][col] == 0;
    }
}
