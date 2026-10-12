package render.military;

import three.Three;
import citygen.CityConfig;
import game.AreaGame;
import render.Models;
import render.facility.FacilityDebris;
import render.facility.FacilityDetail;
import render.facility.FacilityEntry;
import render.facility.FacilityGeom;
import render.facility.FacilityGeom.Rect;
import render.facility.FacilityGeom.Shell;
import render.facility.FacilityRoof;
import render.facility.FacilityRoof.Roof;
import render.facility.FacilityRoof.RoofDeck;
import render.facility.FacilityStyle;
import render.facility.FacilityGround;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.MeshBuf.MeshBufTools;

// a military base's yard, emitted where the compound stands glbs: the checkpoint (a sandbagged guard
// post, the boom in the base's own bands, and the jersey barriers gen.military.MilitaryGen stamps
// on the pavement either side of the mouth), and the clutter on the lot's edge spots
// (FacilityDebris.spots: ammo crate stacks and fuel drums). All of it is slabs and prisms, so it is
// quads into MilitaryGeom's per-texture buffers, bar the sandbags (render.military.MilitaryBags)
class MilitaryYard
{
  static inline var CELL = CityConfig.CELL;

  // the base's own steels: galvanised for bare outdoor steel, gunmetal for the barrier's cabinet
  static inline var TEX_GALV = 'textures/military/galvanized.png';
  static inline var TEX_GUNMETAL = 'textures/military/gunmetal.png';
  static inline var TEX_OLIVE = 'textures/military/wall-olive.png';
  static inline var TEX_CONCRETE = 'textures/military/wall-concrete.png';
  static inline var TEX_ARM = 'textures/military/boom-arm.png';

  // the guard post over the booth's bay: a ring of POST_BAGS courses of sandbags, a post at each
  // inner corner, a corrugated roof over the lot, and a whip aerial off one corner
  static inline var POST_HALF = 2.0;
  static inline var POST_BAGS = 5;
  static inline var BAG_T = MilitaryBags.W;
  static inline var DOOR_W = 1.4;
  static inline var POST_W = 0.2;
  static inline var EAVE = 3.2;
  static inline var ROOF_T = 0.2;
  static inline var ROOF_OVER = 0.3;
  static inline var WHIP_W = 0.08;
  static inline var WHIP_TOP = 6.0;
  static inline var OLIVE_TILE = 4.0;

  // a jersey barrier's section: a straight foot, then the slope in to its top
  static inline var JERSEY_BASE = 0.9;
  static inline var JERSEY_TOP = 0.3;
  static inline var JERSEY_FOOT = 0.15;
  static inline var JERSEY_H = 1.1;
  static inline var JERSEY_GAP = 0.15;

  // how many cells round the gate's hole the yard clutter keeps clear of
  static inline var GATE_CLEAR = 4;

  // the hand-modelled ammo crate (models-src/military/yardkit_build.py): its body CRATE_W x CRATE_D,
  // and the height a stack steps by, lid and battens included
  public static inline var CRATE_W = 2.2;
  public static inline var CRATE_D = CRATE_W * 296 / 504;
  public static inline var CRATE_STEP = 1.195;
  // the step out of a cell toward each of its four walls: north, south, west, east
  static var DX = [ 0, 0, -1, 1 ];
  static var DZ = [ -1, 1, 0, 0 ];
  // and its fuel drum
  static inline var DRUM_R = 0.6;
  public static inline var DRUM_H = 1.6;
  // a hangar's drums along its wall: the step between two, and how far the row stands off the face
  static inline var DRUM_STEP = 1.3;
  static inline var DRUM_GAP = 0.08;

  // the roof kit: a sandbag nest, water tanks, the aerial mast
  static inline var NEST_HALF = 1.8;
  static inline var NEST_BAGS = 4;
  // the hand-modelled water tank, legs to manway
  public static inline var TANK_H = 2.79;
  // and models-src/military/roofkit_build.py's, each its built height, so render.Models.instanced
  // scales it by 1: the hatch, the isolator, the vent, one cell of duct and the aerial
  public static inline var HATCH_H = 0.4971;
  public static inline var JBOX_H = 1.15;
  public static inline var VENT_H = 1.03;
  public static inline var DUCT_H = 0.9;
  public static inline var AERIAL_H = 7.7;
  // their footprints as half extents along local x and z, for the pools under them: the hatch's lid,
  // the isolator's base plates, the vent's flashing, a duct cell's sleepers, the mast's base plate,
  // and the round tank's, small enough that the square pool's corners stay under its 1.0 radius
  static var KIT_HALF = [
    [ 1.29, 1.09 ],
    [ 0.375, 0.3 ],
    [ 0.35, 0.35 ],
    [ CELL / 2, 0.4 ],
    [ 0.6, 0.6 ],
  ];
  static inline var TANK_POOL = 0.62;
  // how much of a footprint a roof pool spans before FacilityRoof.pool grows it 40%: its dark core
  // ends inside the piece and only the falloff shows past its edge. The compound's own pools, laid at
  // the compound's footprints round the base's smaller kit, read as holes cut in the roof
  static inline var POOL_FIT = 0.8;


// the checkpoint and the yard clutter, into MilitaryGeom's buffers. runs inside MilitaryGeom.build,
// so before ContactMask.repaint like everything there
  public static function build(scene:Scene, m:Facility, area:AreaGame):Void
    {
      jerseys(m, area);
      var y = FacilityGround.surfY(Surf.LOT);
      var gate = FacilityEntry.find(m);
      if (gate != null)
        {
          post(m, gate.boothCol, gate.mouthRow, y);
          FacilityEntry.barrier(scene, gate, y, TEX_GUNMETAL, TEX_ARM);
        }
      // and none on the approach: a crate stack in front of the boom reads as a roadblock nobody set
      for (c in FacilityDebris.spots(m))
        if (gate == null ||
            c.col < gate.col - GATE_CLEAR ||
            c.col > gate.col + gate.w - 1 + GATE_CLEAR ||
            c.row < gate.row - GATE_CLEAR ||
            c.row > gate.row + gate.h - 1 + GATE_CLEAR)
          clutter(m, c.col, c.row, y);
    }

// the guard post standing on the booth's bay
  static function post(m:Facility, col:Int, row:Int, y:Float):Void
    {
      var c = CityConfig.cellToWorld(col, row);
      var x0 = c.x - POST_HALF;
      var x1 = c.x + POST_HALF;
      var z0 = c.z - POST_HALF;
      var z1 = c.z + POST_HALF;
      // the ring, its way in on the far side from the mouth (the booth is on its low-column flank)
      MilitaryBags.ring(MilitaryGeom.bags, {
        x0: x0,
        x1: x1,
        z0: z0,
        z1: z1,
      }, y, POST_BAGS, {
        dir: 2,
        a0: c.z - DOOR_W / 2,
        a1: c.z + DOOR_W / 2,
      });
      var steel = MilitaryGeom.buf(TEX_GALV);
      var eave = y + EAVE;
      for (px in [ x0 + BAG_T, x1 - BAG_T - POST_W ])
        for (pz in [ z0 + BAG_T, z1 - BAG_T - POST_W ])
          MilitaryGeom.box(steel, px, px + POST_W, pz, pz + POST_W, y, eave, CELL);
      // the roof, closed underneath so it casts (FacilityEntry.booth's lesson)
      var olive = MilitaryGeom.buf(TEX_OLIVE);
      var r0 = x0 - ROOF_OVER;
      var r1 = x1 + ROOF_OVER;
      var s0 = z0 - ROOF_OVER;
      var s1 = z1 + ROOF_OVER;
      MilitaryGeom.box(olive, r0, r1, s0, s1, eave, eave + ROOF_T, OLIVE_TILE);
      FacilityGeom.capDown(olive, r0, r1, s0, s1, eave, OLIVE_TILE);
      MilitaryGeom.box(steel, x1 - BAG_T, x1 - BAG_T + WHIP_W, z0 + BAG_T, z0 + BAG_T + WHIP_W,
        eave + ROOF_T, y + WHIP_TOP, CELL);
      FacilityDetail.ground(m, {
        col: col,
        row: row,
        len: 1,
        alongX: true,
        rect: {
          x0: x0,
          x1: x1,
          z0: z0,
          z1: z1,
        },
        h: EAVE,
      });
    }

// every jersey barrier on the grid: a segment per cell, one contact shadow per run
  static function jerseys(m:Facility, area:AreaGame):Void
    {
      var t = Const.TILE_MIL_JERSEY;
      var b = MilitaryGeom.buf(TEX_CONCRETE);
      for (row in 0...area.height)
        for (col in 0...area.width)
          {
            if (area.getCellType(col, row) != t)
              continue;
            var alongX = (area.getCellType(col - 1, row) == t ||
              area.getCellType(col + 1, row) == t);
            var c = CityConfig.cellToWorld(col, row);
            var y = FacilityGround.surfY(m.surf[row][col]);
            jersey(b, c.x, c.z, y, alongX);
            // the run's first cell takes the shadow for all of it
            if (area.getCellType(col - (alongX ? 1 : 0), row - (alongX ? 0 : 1)) == t)
              continue;
            var len = 1;
            while (area.getCellType(col + (alongX ? len : 0), row + (alongX ? 0 : len)) == t)
              len++;
            var hb = JERSEY_BASE / 2;
            FacilityDetail.ground(m, {
              col: col,
              row: row,
              len: len,
              alongX: alongX,
              rect: {
                x0: (alongX ? c.x - CELL / 2 : c.x - hb),
                x1: (alongX ? c.x - CELL / 2 + len * CELL : c.x + hb),
                z0: (alongX ? c.z - hb : c.z - CELL / 2),
                z1: (alongX ? c.z + hb : c.z - CELL / 2 + len * CELL),
              },
              h: JERSEY_H,
            });
          }
    }

// one jersey segment over a cell: two feet, two slopes, a top and two end faces, world-tiled.
// `a` runs along the barrier and `s` across it; the corner tables map them onto x and z
  static function jersey(b:render.world.MeshBuf.MeshBuf, cx:Float, cz:Float, y:Float, alongX:Bool):Void
    {
      var a0 = -CELL / 2 + JERSEY_GAP;
      var a1 = CELL / 2 - JERSEY_GAP;
      // the section's outline from one foot over the top to the other: (s, height)
      var sec = [
        [ -JERSEY_BASE / 2, 0.0 ],
        [ -JERSEY_BASE / 2, JERSEY_FOOT ],
        [ -JERSEY_TOP / 2, JERSEY_H ],
        [ JERSEY_TOP / 2, JERSEY_H ],
        [ JERSEY_BASE / 2, JERSEY_FOOT ],
        [ JERSEY_BASE / 2, 0.0 ],
      ];
      var at = function(a:Float, s:Float, h:Float):Array<Float>
        return (alongX ? [ cx + a, y + h, cz + s ] : [ cx + s, y + h, cz + a ]);
      var t = OLIVE_TILE;
      // the long faces, each section edge swept along the run. v is the edge's own length, so the
      // concrete keeps its scale up the slope
      var v = 0.0;
      for (i in 0...sec.length - 1)
        {
          var p = sec[i];
          var q = sec[i + 1];
          var len = Math.sqrt((q[0] - p[0]) * (q[0] - p[0]) + (q[1] - p[1]) * (q[1] - p[1]));
          var uv = [a0 / t, v / t, a1 / t, v / t, a1 / t, (v + len) / t, a0 / t, (v + len) / t];
          // wound so the face looks outward from the section, whichever axis the run takes
          if (alongX)
            MeshBufTools.quad(b, at(a1, p[0], p[1]), at(a0, p[0], p[1]), at(a0, q[0], q[1]),
              at(a1, q[0], q[1]), uv);
          else
            MeshBufTools.quad(b, at(a0, p[0], p[1]), at(a1, p[0], p[1]), at(a1, q[0], q[1]),
              at(a0, q[0], q[1]), uv);
          v += len;
        }
      // the two ends, the section as two quads (foot and slope), facing out along the run
      for (end in [ a0, a1 ])
        {
          var out = (end == a1) == alongX;
          for (k in [ [ 0, 1, 4, 5 ], [ 1, 2, 3, 4 ] ])
            {
              var ps = [for (i in k) at(end, sec[i][0], sec[i][1])];
              var uv = [for (i in k) for (c in [ sec[i][0] / t, sec[i][1] / t ]) c];
              if (out)
                MeshBufTools.quad(b, ps[0], ps[1], ps[2], ps[3], uv);
              else
                MeshBufTools.quad(b, ps[3], ps[2], ps[1], ps[0], [uv[6], uv[7], uv[4], uv[5],
                  uv[2], uv[3], uv[0], uv[1]]);
            }
        }
    }

// one lot edge spot: a stack of ammo crates or a cluster of fuel drums, picked off the cell's hash
  static function clutter(m:Facility, col:Int, row:Int, y:Float):Void
    {
      var h = FacilityModel.mix((col * 27644437) ^ (row * 67867979));
      var c = CityConfig.cellToWorld(col, row);
      var r:Rect = null;
      var top = 0.0;
      if (h % 3 < 2)
        {
          // up to three crates, each a whisker off the one under it, turned a quarter on half
          var n = 1 + (h >> 4) % 3;
          var turn = ((h >> 8) % 2 == 1);
          var hw = (turn ? CRATE_D : CRATE_W) / 2;
          var hd = (turn ? CRATE_W : CRATE_D) / 2;
          for (i in 0...n)
            {
              var o = (i % 2 == 1 ? 0.12 : 0.0);
              MilitaryGeom.crates.push({
                x: c.x + o,
                z: c.z - o,
                yaw: (turn ? Math.PI / 2 : 0.0),
                y: y + i * CRATE_STEP,
              });
            }
          r = {
            x0: c.x - hw,
            x1: c.x + hw + 0.12,
            z0: c.z - hd - 0.12,
            z1: c.z + hd,
          };
          top = n * CRATE_STEP;
        }
      else
        {
          var n = 1 + (h >> 4) % 3;
          var at = [ [ 0.0, 0.0 ], [ -0.7, 0.0, 0.7, 0.25 ], [ -0.7, -0.5, 0.7, -0.4, 0.0, 0.7 ] ][n - 1];
          // each turned off the hash, so the stencil does not face the same way on every drum
          for (i in 0...n)
            MilitaryGeom.drums.push({
              x: c.x + at[i * 2],
              z: c.z + at[i * 2 + 1],
              yaw: ((h >> (12 + i * 3)) % 8) * Math.PI / 4,
              y: y,
            });
          r = {
            x0: c.x - 0.7 - DRUM_R,
            x1: c.x + 0.7 + DRUM_R,
            z0: c.z - 0.5 - DRUM_R,
            z1: c.z + 0.7 + DRUM_R,
          };
          top = DRUM_H;
        }
      FacilityDetail.ground(m, {
        col: col,
        row: row,
        len: 1,
        alongX: true,
        rect: r,
        h: top,
      });
    }

// a hangar's fuel drums on one cell of its wall run (Const.TILE_MIL_DRUMS): two or three in a row
// along the wall beside it, a hair off its face, each nudged and turned off the hash
  public static function wallDrums(m:Facility, col:Int, row:Int):Void
    {
      var h = FacilityModel.mix((col * 27644437) ^ (row * 67867979));
      var c = CityConfig.cellToWorld(col, row);
      var y = FacilityGround.surfY(m.surf[row][col]);
      var dir = 0;
      while (dir < 3 &&
          !FacilityModel.isWall(m, col + DX[dir], row + DZ[dir]))
        dir++;
      var sl = FacilityGeom.slab(m, col + DX[dir], row + DZ[dir]);
      var off = DRUM_R + DRUM_GAP;
      // the row's line: x for a wall north or south, z for one west or east
      var along = (dir < 2);
      var line = switch (dir)
        {
          case 0: sl.z1 + off;
          case 1: sl.z0 - off;
          case 2: sl.x1 + off;
          default: sl.x0 - off;
        };
      var n = 2 + h % 2;
      for (i in 0...n)
        {
          var a = (i - (n - 1) / 2) * DRUM_STEP + ((h >> (4 + i * 2)) % 3 - 1) * 0.08;
          MilitaryGeom.drums.push({
            x: (along ? c.x + a : line),
            z: (along ? line : c.z + a),
            yaw: ((h >> (12 + i * 3)) % 8) * Math.PI / 4,
            y: y,
          });
        }
      var e = (n - 1) / 2 * DRUM_STEP + DRUM_R;
      FacilityDetail.ground(m, {
        col: col,
        row: row,
        len: 1,
        alongX: along,
        rect: (along ? {
          x0: c.x - e,
          x1: c.x + e,
          z0: line - DRUM_R,
          z1: line + DRUM_R,
        } : {
          x0: line - DRUM_R,
          x1: line + DRUM_R,
          z0: c.z - e,
          z1: c.z + e,
        }),
        h: DRUM_H,
      });
    }

// the roofs' kit on FacilityRoof's own spots: the first plant spot on a building is a sandbag nest
// and the rest water tanks (a glb, handed back on deck.tank); the hatch, isolators, vents, duct and
// the aerial on the dish spot are FacilityRoof's own batches drawing roofkit_build.py's glbs. Every
// piece's contact pool is laid here, fitted to the piece, into one fading mesh per deck
  public static function roof(scene:Scene, deck:RoofDeck, out:Roof, shells:Array<Shell>):Void
    {
      var pools = new Map<Int, render.world.MeshBuf.MeshBuf>();
      var pool = function(si:Int, x:Float, z:Float, hw:Float, hd:Float, yaw:Float):Void
        {
          if (!pools.exists(si))
            pools.set(si, MeshBufTools.make());
          FacilityRoof.pool(pools.get(si), x, z, hw, hd, yaw);
        };
      var nested = new Map<Int, Bool>();
      var tanks:Array<Models.PropPlace> = [];
      var tankOf:Array<Int> = [];
      // the nests' bags, one batch over every roof, each bag owned by its structure so it hides
      // with that roof (FacilityRoof.mask)
      var bags:Array<Models.PropPlace> = [];
      for (i in 0...deck.ac.length)
        {
          var p = deck.ac[i];
          var si = out.acOf[i];
          if (!nested.exists(si))
            {
              nested.set(si, true);
              var o = NEST_HALF;
              var n = bags.length;
              MilitaryBags.ring(bags, {
                x0: p.x - o,
                x1: p.x + o,
                z0: p.z - o,
                z1: p.z + o,
              }, p.y, NEST_BAGS, {
                dir: 3,
                a0: p.z - DOOR_W / 2,
                a1: p.z + DOOR_W / 2,
              });
              for (_ in n...bags.length)
                out.bagOf.push(si);
              // a pool under each of its walls and none in the middle, where the condenser's lay
              // ("holes under sandbags"): the two along x whole, the -x one between them, and the
              // +x one either side of its gap
              var w = MilitaryBags.W / 2 * POOL_FIT;
              var side = (o - MilitaryBags.W) * POOL_FIT;
              pool(si, p.x, p.z - o + MilitaryBags.W / 2, o * POOL_FIT, w, 0.0);
              pool(si, p.x, p.z + o - MilitaryBags.W / 2, o * POOL_FIT, w, 0.0);
              pool(si, p.x - o + MilitaryBags.W / 2, p.z, w, side, 0.0);
              var gap = (o - MilitaryBags.W - DOOR_W / 2) / 2;
              for (k in [ -1, 1 ])
                pool(si, p.x + o - MilitaryBags.W / 2, p.z + k * (DOOR_W / 2 + gap), w,
                  gap * POOL_FIT, 0.0);
              continue;
            }
          tanks.push(p);
          tankOf.push(si);
          pool(si, p.x, p.z, TANK_POOL * POOL_FIT, TANK_POOL * POOL_FIT, 0.0);
        }
      // the facility's own tank spots and every plant spot past the nest stand the base's water
      // tank, handed back on deck.tank for FacilityRoof to batch and mask like the compound's
      for (i in 0...deck.tank.length)
        pool(out.tankOf[i], deck.tank[i].x, deck.tank[i].z, TANK_POOL * POOL_FIT, TANK_POOL * POOL_FIT,
          0.0);
      deck.tank = tanks.concat(deck.tank);
      out.tankOf = tankOf.concat(out.tankOf);
      // and under the rest of the kit, each on its own spot and turn
      var kit = [ deck.hatch, deck.jbox, deck.vent, deck.duct, deck.dish ];
      var of = [ out.hatchOf, out.jboxOf, out.ventOf, out.ductOf, out.dishOf ];
      for (k in 0...kit.length)
        for (i in 0...kit[k].length)
          {
            var p = kit[k][i];
            pool(of[k][i], p.x, p.z, KIT_HALF[k][0] * POOL_FIT, KIT_HALF[k][1] * POOL_FIT, p.yaw);
          }
      for (si in pools.keys())
        FacilityRoof.shade(scene, pools.get(si), shells[si]);
      out.bagB = unmasked(MilitaryBags.batch(scene, bags), RenderConfig.MODELS.militarySandbag);
    }

// give a ROOF batch its own copy of the glb's material. SOLID batches share the template's, and the
// ground batches of the same glb (and View's warm-up) vision-mask it, which chains render.world
// .IndoorMask on as well: a bag or a tank standing on a roof over an interior was then lit by the
// indoor rig and the player's line of sight, and came out near black. A clone drops both hooks
// (Material.clone copies no onBeforeCompile), so the roof kit lights like the facility's own
  public static function unmasked(prop:InstancedProp, path:String):InstancedProp
    {
      Models.get(path, function(_)
        {
          if (prop.mesh != null)
            prop.mesh.material = prop.mesh.material.clone();
        });
      return prop;
    }

// the yard kit's glbs, for View's warm-up
  public static function warmProps():Array<{ path:String, h:Float }>
    {
      return [
        {
          path: RenderConfig.MODELS.militaryCrate,
          h: CRATE_STEP,
        },
        {
          path: RenderConfig.MODELS.militaryDrum,
          h: DRUM_H,
        },
        {
          path: RenderConfig.MODELS.militaryContainer,
          h: MilitaryGeom.CONT_H,
        },
        {
          path: RenderConfig.MODELS.militaryWaterTank,
          h: TANK_H,
        },
        {
          path: RenderConfig.MODELS.militaryRoofHatch,
          h: HATCH_H,
        },
        {
          path: RenderConfig.MODELS.militaryRoofJbox,
          h: JBOX_H,
        },
        {
          path: RenderConfig.MODELS.militaryRoofVent,
          h: VENT_H,
        },
        {
          path: RenderConfig.MODELS.militaryRoofDuct,
          h: DUCT_H,
        },
        {
          path: RenderConfig.MODELS.militaryRoofAerial,
          h: AERIAL_H,
        },
      ];
    }
}
