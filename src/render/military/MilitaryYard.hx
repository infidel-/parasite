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

  static inline var TEX_STEEL = MilitaryStyle.WINDOW_HEAD;
  static inline var TEX_OLIVE = 'textures/military/wall-olive.png';
  static inline var TEX_CONCRETE = 'textures/military/wall-concrete.png';
  static inline var TEX_ARM = 'textures/military/boom-arm.png';
  static inline var TEX_CRATE_SIDE = 'textures/military/crate-side.png';
  static inline var TEX_CRATE_LID = 'textures/military/crate-lid.png';
  static inline var TEX_DRUM_SIDE = 'textures/military/drum-side.png';
  static inline var TEX_DRUM_TOP = 'textures/military/drum-top.png';

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

  // an ammo crate: its long side is military/crate-side's 2:1 crop and its lid crate-lid's 504x296
  static inline var CRATE_W = 2.2;
  static inline var CRATE_H = CRATE_W / 2;
  static inline var CRATE_D = CRATE_W * 296 / 504;
  // a fuel drum, an octagon
  static inline var DRUM_R = 0.6;
  static inline var DRUM_H = 1.6;
  static inline var DRUM_SIDES = 8;

  // the roof kit: a sandbag nest, water tanks, the aerial mast
  static inline var NEST_HALF = 1.8;
  static inline var NEST_BAGS = 4;
  static inline var TANK_R = 1.0;
  static inline var TANK_H = 2.0;
  static inline var TANK_PLINTH = 0.3;
  static inline var AERIAL_W = 0.14;
  static inline var AERIAL_H = 7.0;
  static inline var AERIAL_BASE = 0.5;
  static inline var AERIAL_BAR = 0.8;


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
          FacilityEntry.barrier(scene, gate, y, TEX_STEEL, TEX_ARM);
        }
      for (c in FacilityDebris.spots(m))
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
      var steel = MilitaryGeom.buf(TEX_STEEL);
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
              crate(c.x - hw + o, c.x + hw + o, c.z - hd - o, c.z + hd - o, y + i * CRATE_H, turn);
            }
          r = {
            x0: c.x - hw,
            x1: c.x + hw + 0.12,
            z0: c.z - hd - 0.12,
            z1: c.z + hd,
          };
          top = n * CRATE_H;
        }
      else
        {
          var n = 1 + (h >> 4) % 3;
          var at = [ [ 0.0, 0.0 ], [ -0.7, 0.0, 0.7, 0.25 ], [ -0.7, -0.5, 0.7, -0.4, 0.0, 0.7 ] ][n - 1];
          for (i in 0...n)
            drum(c.x + at[i * 2], c.z + at[i * 2 + 1], y);
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

// one ammo crate: the authored side on both long faces, plain olive steel ends, the lid on top
  static function crate(x0:Float, x1:Float, z0:Float, z1:Float, y:Float, turn:Bool):Void
    {
      var side = MilitaryGeom.buf(TEX_CRATE_SIDE);
      var steel = MilitaryGeom.buf(TEX_STEEL);
      for (d in 0...4)
        {
          // the long faces are the two across the crate's short axis
          var long = (turn ? d >= 2 : d < 2);
          if (long)
            FacilityGeom.pane(side, x0, x1, z0, z1, d, y, y + CRATE_H);
          else
            FacilityGeom.face(steel, x0, x1, z0, z1, d, y, y + CRATE_H, CELL);
        }
      var t = y + CRATE_H;
      // turned, the image's long axis follows z: a quarter ROTATION of the map, never a mirror
      var uv:Array<Float> = (turn ? [0, 1, 0, 0, 1, 0, 1, 1] : [0, 0, 1, 0, 1, 1, 0, 1]);
      MeshBufTools.quad(MilitaryGeom.buf(TEX_CRATE_LID), [x0, t, z1], [x1, t, z1], [x1, t, z0],
        [x0, t, z0], uv);
    }

// one fuel drum: an octagon, the side art once round it, the round lid fanned over the top
  static function drum(cx:Float, cz:Float, y:Float):Void
    {
      var side = MilitaryGeom.buf(TEX_DRUM_SIDE);
      var lid = MilitaryGeom.buf(TEX_DRUM_TOP);
      var t = y + DRUM_H;
      for (i in 0...DRUM_SIDES)
        {
          var a = i * Math.PI * 2 / DRUM_SIDES;
          var b = (i + 1) * Math.PI * 2 / DRUM_SIDES;
          var x0 = cx + Math.cos(a) * DRUM_R;
          var z0 = cz + Math.sin(a) * DRUM_R;
          var x1 = cx + Math.cos(b) * DRUM_R;
          var z1 = cz + Math.sin(b) * DRUM_R;
          var u0 = 1 - i / DRUM_SIDES;
          var u1 = 1 - (i + 1) / DRUM_SIDES;
          MeshBufTools.quad(side, [x1, y, z1], [x0, y, z0], [x0, t, z0], [x1, t, z1],
            [u1, 0, u0, 0, u0, 1, u1, 1]);
          MeshBufTools.tri(lid, [cx, t, cz], [x1, t, z1], [x0, t, z0],
            [0.5, 0.5, 0.5 + Math.cos(b) / 2, 0.5 - Math.sin(b) / 2, 0.5 + Math.cos(a) / 2,
              0.5 - Math.sin(a) / 2]);
        }
    }

// the roofs' kit on FacilityRoof's own spots, each piece onto its structure's deck so it fades with
// it: the first plant spot on a building is a sandbag nest, the rest water tanks; the dish pad an
// antenna mast; the hatch, isolator boxes, vents and duct run plain olive steel
  public static function roof(scene:Scene, deck:RoofDeck, out:Roof, shells:Array<Shell>):Void
    {
      var bufs = new Map<String, render.world.MeshBuf.MeshBuf>();
      var buf = function(si:Int, tex:String):render.world.MeshBuf.MeshBuf
        {
          var k = si + ' ' + tex;
          if (!bufs.exists(k))
            bufs.set(k, MeshBufTools.make());
          return bufs.get(k);
        };
      var nested = new Map<Int, Bool>();
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
              continue;
            }
          tank(buf(si, TEX_OLIVE), buf(si, TEX_STEEL), p.x, p.z, p.y);
        }
      for (i in 0...deck.tank.length)
        tank(buf(out.tankOf[i], TEX_OLIVE), buf(out.tankOf[i], TEX_STEEL), deck.tank[i].x,
          deck.tank[i].z, deck.tank[i].y);
      for (i in 0...deck.dish.length)
        {
          var p = deck.dish[i];
          var b = buf(out.dishOf[i], TEX_STEEL);
          var h = AERIAL_W / 2;
          MilitaryGeom.box(b, p.x - AERIAL_BASE, p.x + AERIAL_BASE, p.z - AERIAL_BASE,
            p.z + AERIAL_BASE, p.y, p.y + 0.3, CELL);
          MilitaryGeom.box(b, p.x - h, p.x + h, p.z - h, p.z + h, p.y, p.y + AERIAL_H, CELL);
          for (k in 1...4)
            {
              var y = p.y + AERIAL_H * k / 4;
              var w = AERIAL_BAR * (1 - k / 5);
              MilitaryGeom.box(b, p.x - w, p.x + w, p.z - h, p.z + h, y, y + h * 2, CELL);
            }
        }
      // the small steel kit: [ list, owners, w, d, h ], a quarter turn swapping w and d
      var kit:Array<{ at:Array<Models.PropPlace>, of:Array<Int>, w:Float, d:Float, h:Float }> = [
        {
          at: deck.hatch,
          of: out.hatchOf,
          w: FacilityStyle.HATCH_W,
          d: FacilityStyle.HATCH_D,
          h: 0.6,
        },
        {
          at: deck.jbox,
          of: out.jboxOf,
          w: 0.6,
          d: 0.4,
          h: 0.8,
        },
        {
          at: deck.vent,
          of: out.ventOf,
          w: 0.6,
          d: 0.6,
          h: 0.9,
        },
        {
          at: deck.duct,
          of: out.ductOf,
          w: CELL,
          d: FacilityStyle.ROOF_DUCT_PLAN_D,
          h: FacilityStyle.ROOF_DUCT_PLAN_D,
        },
      ];
      for (k in kit)
        for (i in 0...k.at.length)
          {
            var p = k.at[i];
            var turn = (Math.abs(Math.sin(p.yaw)) > 0.5);
            var hw = (turn ? k.d : k.w) / 2;
            var hd = (turn ? k.w : k.d) / 2;
            MilitaryGeom.box(buf(k.of[i], TEX_STEEL), p.x - hw, p.x + hw, p.z - hd, p.z + hd, p.y,
              p.y + k.h, CELL);
          }
      for (key in bufs.keys())
        {
          var sp = key.indexOf(' ');
          FacilityGeom.addDeck(scene, bufs.get(key), key.substr(sp + 1), true,
            shells[Std.parseInt(key.substr(0, sp))]);
        }
      out.bagB = MilitaryBags.batch(scene, bags);
    }

// a roof water tank: an olive corrugated octagon on a steel plinth, a steel lid
  static function tank(side:render.world.MeshBuf.MeshBuf, steel:render.world.MeshBuf.MeshBuf,
      cx:Float, cz:Float, y:Float):Void
    {
      MilitaryGeom.box(steel, cx - TANK_R, cx + TANK_R, cz - TANK_R, cz + TANK_R, y, y + TANK_PLINTH,
        CELL);
      var y0 = y + TANK_PLINTH;
      var t = y0 + TANK_H;
      for (i in 0...DRUM_SIDES)
        {
          var a = i * Math.PI * 2 / DRUM_SIDES;
          var b = (i + 1) * Math.PI * 2 / DRUM_SIDES;
          var x0 = cx + Math.cos(a) * TANK_R;
          var z0 = cz + Math.sin(a) * TANK_R;
          var x1 = cx + Math.cos(b) * TANK_R;
          var z1 = cz + Math.sin(b) * TANK_R;
          // world-tiled round the rim, so the corrugation keeps its pitch
          var u0 = -i * TANK_R * 0.765 / OLIVE_TILE;
          var u1 = -(i + 1) * TANK_R * 0.765 / OLIVE_TILE;
          MeshBufTools.quad(side, [x1, y0, z1], [x0, y0, z0], [x0, t, z0], [x1, t, z1],
            [u1, y0 / OLIVE_TILE, u0, y0 / OLIVE_TILE, u0, t / OLIVE_TILE, u1, t / OLIVE_TILE]);
          MeshBufTools.tri(steel, [cx, t, cz], [x1, t, z1], [x0, t, z0],
            [cx / CELL, cz / CELL, x1 / CELL, z1 / CELL, x0 / CELL, z0 / CELL]);
        }
    }
}
