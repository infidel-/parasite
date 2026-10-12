package render.military;

import three.Three;
import citygen.CityConfig;
import game.AreaGame;
import render.Textures;
import render.corp.CorpFurniture;
import render.corp.CorpStyle;
import render.facility.FacilityDetail;
import render.facility.FacilityGeom;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityStyle;
import render.military.MilitaryClutter.LidKind;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;
import render.Models.PropPlace;
import render.Models.InstancedProp;

// a military base's own furniture, emitted as quads off the saved grid (gen.military.MilitaryGen's
// row-19 tiles) and off its armory objects: the chain-link perimeter with its posts and razor wire,
// the corner watchtowers, the tents, the shipping containers, the camo nets over the motor pool, the
// helipad's concrete, and the armory's lockers, gun cabinet and safe. The rooms' furniture is
// render.military.MilitaryInterior, into these same buffers.
//
// every one of them is axis-aligned slabs or a rhythm of a material, so all of it is geometry plus a
// tiling texture rather than a glb (docs/3d-geometry.md): ONE MESH PER TEXTURE, the opaque ones
// through FacilityGeom.add and the alpha-cut ones (the mesh, the wire, the net) as one opaque
// alphaTest DoubleSide material each, the FacilityCable shape
class MilitaryGeom
{
  static inline var CELL = CityConfig.CELL;

  // the art (textures.json military/*). the lockers and the gun cabinet are corp's steel boxes at
  // corp's scale (CorpStyle.LOCKER_*), in the base's own olive
  static inline var TEX_CHAIN = 'textures/military/chainlink.png';
  static inline var TEX_TORN = 'textures/military/chainlink-torn.png';
  static inline var TEX_COIL = 'textures/military/razor-coil.png';
  static inline var TEX_GALV = 'textures/military/galvanized.png';
  static inline var TEX_NET = 'textures/military/camo-net.png';
  static inline var TEX_OLIVE = 'textures/military/wall-olive.png';
  static inline var TEX_CONCRETE = 'textures/military/wall-concrete.png';
  static inline var TEX_CANVAS = 'textures/military/tent-canvas.png';
  static inline var TEX_APRON = 'textures/military/apron.png';
  static inline var TEX_PAD_MARK = 'textures/military/helipad-h.png';

  // the fence: two cells high, the chain-link world-tiled at its crop's own aspect (CHAIN_TILE
  // across, CHAIN_V up: military/chainlink's 1020x905, five by four whole diamonds), and a post on
  // every POST_EVERY-th cell edge plus wherever a run stops or turns
  public static inline var FENCE_H = CELL * 2;
  static inline var CHAIN_TILE = 4.0;
  static inline var CHAIN_V = CHAIN_TILE * 905 / 1020;
  static inline var POST_R = 0.16;
  static inline var POST_EVERY = 2;
  // the razor-wire coil along its top: an alpha-cut tube of WIRE_SIDES faces whose art is a helix
  // (tools/razorcoil.py), so the front strands and the back ones seen through it cross like a coil's
  // from any side. u 0..1 is one turn round it, v repeats every COIL_LV along it, both the tool's
  static inline var WIRE_D = 1.12;
  static inline var WIRE_SIDES = 8;
  static inline var COIL_LV = 1.4;
  // the posts and ladders are round galvanised pipe, world-tiled at this
  static inline var GALV_TILE = 2.0;
  static inline var PIPE_SIDES = 8;
  // the alpha cut every see-through face here takes
  static inline var CUT = 0.3;

  // the corner watchtower over its 2x2 footprint: legs to the deck, a corrugated parapet round it,
  // posts to a flat roof, and a sandbag ring at its foot
  static inline var TOWER_INSET = 0.6;
  static inline var LEG_W = 0.6;
  static inline var DECK_Y = FENCE_H + 2.0;
  static inline var DECK_T = 0.5;
  static inline var PARAPET_H = 2.2;
  static inline var PARAPET_T = 0.2;
  static inline var ROOF_Y = DECK_Y + 5.0;
  static inline var ROOF_T = 0.2;
  static inline var ROOF_OVER = 0.6;
  static inline var OLIVE_TILE = 4.0;
  // the ring of sandbags round its foot: how far out past the legs, and how many courses
  static inline var BAGS_OUT = 0.5;
  static inline var TOWER_BAGS = 3;
  // its steel ladder, standing off the face toward the middle of the base, ground to over the
  // parapet
  static inline var LADDER_W = 0.9;
  static inline var LADDER_OFF = 0.2;
  static inline var RAIL_W = 0.1;
  static inline var RUNG_T = 0.08;
  static inline var RUNG_STEP = 0.6;

  // a tent over its 2x3 cells: walls to the eave, a ridge along its long axis
  static inline var TENT_INSET = 0.4;
  static inline var TENT_EAVE = 2.2;
  static inline var TENT_RIDGE = 5.6;
  static inline var CANVAS_TILE = 4.0;

  // a 20 ft container: Const.MIL_CONTAINER_LEN cells long, its end face locked to the door art's
  // 508x546 crop (military/container-door)
  static inline var CONT_INSET = 0.2;
  static inline var CONT_W = CELL - CONT_INSET * 2;
  public static inline var CONT_H = CONT_W * 546 / 508;

  // the camo net over a parked vehicle, on four poles, and how far past the footprint it reaches
  static inline var NET_Y = 6.4;
  static inline var NET_OVER = 0.6;
  static inline var NET_TILE = 6.0;
  static inline var POLE_W = 0.25;

  // the helipad's concrete, a whisker over the lot it is laid on
  static inline var PAD_Y = 0.02;
  static inline var PAD_TILE = 8.0;
  // the marking over it, inset off the pad's edge and a whisker over the concrete
  static inline var MARK_INSET = 0.5;
  static inline var MARK_Y = PAD_Y * 2;

  // the armory safe's footprint against its wall (models-src/military/roomkit_build.py's safe-hand)
  static inline var SAFE_W = 1.8;
  static inline var SAFE_D = 1.6;
  // and the top of a locker bank or the gun cabinet clutter lies on: its 4.0 x 1.34 lid less the
  // rounding and a margin
  static inline var LOCKER_TOP_W = 3.8;
  static inline var LOCKER_TOP_D = 1.14;

  // the buffers being filled, one per texture
  static var opaque:Map<String, MeshBuf>;
  static var cut:Map<String, MeshBuf>;
  // and the sandbags on the ground, one instanced batch (render.military.MilitaryBags)
  public static var bags:Array<PropPlace>;
  // and the instanced yard kit: MilitaryYard's crates and drums, this file's containers
  public static var crates:Array<PropPlace>;
  public static var drums:Array<PropPlace>;
  static var containers:Array<PropPlace>;

// emit the whole base. runs BEFORE ContactMask.repaint in render.facility.FacilityArea.build: every
// unit here registers its footprint with the contact shadow. returns the ground's sandbag batch,
// which the area's tick culls
  public static function build(scene:Scene, m:Facility, area:AreaGame):Array<InstancedProp>
    {
      opaque = new Map();
      cut = new Map();
      bags = [];
      crates = [];
      drums = [];
      containers = [];
      var parked = 0;
      // the pad's square, off its cells, for the marking
      var pad = {
        x0: area.width,
        z0: area.height,
        x1: -1,
        z1: -1,
      };
      for (row in 0...area.height)
        for (col in 0...area.width)
          {
            var t = area.getCellType(col, row);
            if (t == Const.TILE_MIL_FENCE ||
                t == Const.TILE_MIL_FENCE_TORN)
              fence(area, col, row, t == Const.TILE_MIL_FENCE_TORN);
            else if (t == Const.TILE_MIL_TOWER &&
                area.getCellType(col - 1, row) != t &&
                area.getCellType(col, row - 1) != t)
              tower(m, col, row);
            else if (t == Const.TILE_MIL_TENT &&
                area.getCellType(col - 1, row) != t &&
                area.getCellType(col, row - 1) != t)
              tent(m, area, col, row);
            else if (t == Const.TILE_MIL_CONTAINER_ORIGIN)
              container(m, col, row);
            // a net over every OTHER vehicle in the pool: netted all, the pool read from the
            // camera as five camo sheets with nothing under them
            else if (t == Const.TILE_MIL_TANK ||
                t == Const.TILE_MIL_HUMVEE)
              {
                if (parked++ % 2 == 1)
                  net(col, row, (t == Const.TILE_MIL_TANK ? Const.MIL_TANK_SIZE :
                    Const.MIL_HUMVEE_SIZE));
              }
            else if (t == Const.TILE_MIL_PAD)
              {
                apron(col, row, [ 1, 1 ]);
                pad.x0 = Std.int(Math.min(pad.x0, col));
                pad.z0 = Std.int(Math.min(pad.z0, row));
                pad.x1 = Std.int(Math.max(pad.x1, col));
                pad.z1 = Std.int(Math.max(pad.z1, row));
              }
            // the helicopter stands on the pad, so its footprint is pad too
            else if (t == Const.TILE_MIL_HELI)
              apron(col, row, Const.MIL_HELI_SIZE);
            else if (t == Const.TILE_MIL_DRUMS)
              MilitaryYard.wallDrums(m, col, row);
          }
      if (pad.x1 >= 0)
        mark(pad.x0, pad.z0, pad.x1, pad.z1);
      MilitaryInterior.build(scene, m, area);
      MilitaryYard.build(scene, m, area);
      // the armory: the lockers, the gun cabinet and the safe the generator stood against its walls.
      // ponytail: drawn shut whatever their state, an open one is told by its tooltip
      for (o in area.getObjects())
        if (o.type == 'locker' ||
            o.type == 'gunCabinet')
          locker(m, o.x, o.y, (o.type == 'locker' ? RenderConfig.MODELS.militaryLocker :
            RenderConfig.MODELS.militaryGunCabinet));
        else if (o.type == 'safe')
          safe(m, o.x, o.y);
      // after the lockers, whose tops are lids too
      MilitaryClutter.build(scene, m, area, MilitaryInterior.lids);
      // they all cast: a jersey, a tent or a tower under the moon with no shadow read as pasted on
      for (tex in opaque.keys())
        FacilityGeom.add(scene, opaque.get(tex), tex, true, true);
      for (tex in cut.keys())
        addCut(scene, cut.get(tex), tex);
      // the yard kit, each batch under the player's line of sight like every other ground prop
      var kit = [
        {
          prop: MilitaryBags.batch(scene, bags),
          path: RenderConfig.MODELS.militarySandbag,
        },
        {
          prop: Models.instanced(scene, RenderConfig.MODELS.militaryCrate, crates,
            MilitaryYard.CRATE_STEP, SOLID),
          path: RenderConfig.MODELS.militaryCrate,
        },
        {
          prop: Models.instanced(scene, RenderConfig.MODELS.militaryDrum, drums, MilitaryYard.DRUM_H,
            SOLID),
          path: RenderConfig.MODELS.militaryDrum,
        },
        {
          prop: Models.instanced(scene, RenderConfig.MODELS.militaryContainer, containers, CONT_H,
            SOLID),
          path: RenderConfig.MODELS.militaryContainer,
        },
      ];
      // and the rooms' furniture (MilitaryInterior)
      kit = kit.concat(MilitaryInterior.batches(scene));
      for (k in kit)
        {
          var p = k.prop;
          Models.get(k.path, function(_) VisionMask.patchMesh(p.mesh));
        }
      return [for (k in kit) k.prop];
    }

// does the base draw this object as geometry instead of its sprite? stateless, like
// render.facility.FacilityDeco.draws, so render.Actors can ask it per object
  public static function draws(area:AreaGame, o:objects.AreaObject):Bool
    {
      return area != null &&
        area.typeID == AREA_MILITARY_BASE &&
        (o.type == 'locker' ||
         o.type == 'gunCabinet' ||
         o.type == 'safe');
    }

// one cell of the perimeter and its posts. a straight cell spans its whole width along the line;
// a CORNER cell is two half-runs, one toward each neighbour, so the ring turns the corner closed
  static function fence(area:AreaGame, col:Int, row:Int, torn:Bool):Void
    {
      var c = CityConfig.cellToWorld(col, row);
      var w = isFence(area, col - 1, row);
      var e = isFence(area, col + 1, row);
      var n = isFence(area, col, row - 1);
      var s = isFence(area, col, row + 1);
      var h = CELL / 2;
      if ((w || e) &&
          (n || s))
        {
          run(true, c.z, (w ? c.x - h : c.x), (w ? c.x : c.x + h), false);
          run(false, c.x, (n ? c.z - h : c.z), (n ? c.z : c.z + h), false);
          post(true, c.z, c.x);
          return;
        }
      var alongX = (w || e);
      var a0 = (alongX ? c.x : c.z) - h;
      var a1 = a0 + CELL;
      var p = (alongX ? c.z : c.x);
      run(alongX, p, a0, a1, torn);
      if (!(alongX ? w : n) ||
          (alongX ? col : row) % POST_EVERY == 0)
        post(alongX, p, a0);
      if (!(alongX ? e : s))
        post(alongX, p, a1);
    }

// is this cell part of the ring?
  static inline function isFence(area:AreaGame, col:Int, row:Int):Bool
    {
      var t = area.getCellType(col, row);
      return t == Const.TILE_MIL_FENCE ||
        t == Const.TILE_MIL_FENCE_TORN;
    }

// the chain-link (the torn panel's lower half on a breach) and the razor wire over a0..a1 along a
// line at `p` across it
  static function run(alongX:Bool, p:Float, a0:Float, a1:Float, torn:Bool):Void
    {
      var lo = 0.0;
      if (torn)
        {
          upright(buf(TEX_TORN, true), alongX, p, a0, a1, 0, CELL, 0, 1, 0, 1);
          lo = CELL;
        }
      upright(buf(TEX_CHAIN, true), alongX, p, a0, a1, lo, FENCE_H, a0 / CHAIN_TILE,
        a1 / CHAIN_TILE, lo / CHAIN_V, FENCE_H / CHAIN_V);
      coil(alongX, p, a0, a1);
    }

// one see-through upright quad on a fence line, at `p` across it and a0..a1 along it
  static function upright(b:MeshBuf, alongX:Bool, p:Float, a0:Float, a1:Float, y0:Float, y1:Float,
      u0:Float, u1:Float, v0:Float, v1:Float):Void
    {
      if (alongX)
        MeshBufTools.quad(b, [a0, y0, p], [a1, y0, p], [a1, y1, p], [a0, y1, p],
          [u0, v0, u1, v0, u1, v1, u0, v1]);
      else
        MeshBufTools.quad(b, [p, y0, a1], [p, y0, a0], [p, y1, a0], [p, y1, a1],
          [u1, v0, u0, v0, u0, v1, u1, v1]);
    }

// the razor-wire tube over a0..a1, its underside resting on the fence's top
  static function coil(alongX:Bool, p:Float, a0:Float, a1:Float):Void
    {
      var b = buf(TEX_COIL, true);
      var r = WIRE_D / 2;
      var cy = FENCE_H + r;
      var at = function(a:Float, ang:Float):Array<Float>
        {
          var s = Math.cos(ang) * r;
          var y = cy + Math.sin(ang) * r;
          return (alongX ? [ a, y, p + s ] : [ p + s, y, a ]);
        };
      for (i in 0...WIRE_SIDES)
        {
          var t0 = i * Math.PI * 2 / WIRE_SIDES;
          var t1 = (i + 1) * Math.PI * 2 / WIRE_SIDES;
          var u0 = i / WIRE_SIDES;
          var u1 = (i + 1) / WIRE_SIDES;
          // wound outward on either axis: swapping x for z mirrors the winding
          if (alongX)
            MeshBufTools.quad(b, at(a0, t0), at(a1, t0), at(a1, t1), at(a0, t1),
              [u0, a0 / COIL_LV, u0, a1 / COIL_LV, u1, a1 / COIL_LV, u1, a0 / COIL_LV]);
          else
            MeshBufTools.quad(b, at(a1, t0), at(a0, t0), at(a0, t1), at(a1, t1),
              [u0, a1 / COIL_LV, u0, a0 / COIL_LV, u1, a0 / COIL_LV, u1, a1 / COIL_LV]);
        }
    }

// a fence post at `a` along the line, a galvanised pipe up to the coil's middle
  static function post(alongX:Bool, p:Float, a:Float):Void
    {
      pipe(buf(TEX_GALV), (alongX ? a : p), (alongX ? p : a), POST_R, 0, FENCE_H + WIRE_D / 2);
    }

// an upright round pipe of PIPE_SIDES faces and its lid, world-tiled at GALV_TILE
  public static function pipe(b:MeshBuf, cx:Float, cz:Float, r:Float, y0:Float, y1:Float):Void
    {
      var step = Math.PI * 2 / PIPE_SIDES;
      var du = r * 2 * Math.sin(step / 2) / GALV_TILE;
      for (i in 0...PIPE_SIDES)
        {
          var a = i * step;
          var c = (i + 1) * step;
          var x0 = cx + Math.cos(a) * r;
          var z0 = cz + Math.sin(a) * r;
          var x1 = cx + Math.cos(c) * r;
          var z1 = cz + Math.sin(c) * r;
          MeshBufTools.quad(b, [x1, y0, z1], [x0, y0, z0], [x0, y1, z0], [x1, y1, z1],
            [(i + 1) * du, y0 / GALV_TILE, i * du, y0 / GALV_TILE, i * du, y1 / GALV_TILE,
              (i + 1) * du, y1 / GALV_TILE]);
          MeshBufTools.tri(b, [cx, y1, cz], [x1, y1, z1], [x0, y1, z0],
            [cx / GALV_TILE, cz / GALV_TILE, x1 / GALV_TILE, z1 / GALV_TILE, x0 / GALV_TILE,
              z0 / GALV_TILE]);
        }
    }

// an upright box's four sides and its top, world-tiled. no bottom: the camera never sees one
  public static function box(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, y0:Float, y1:Float,
      t:Float):Void
    {
      for (dir in 0...4)
        FacilityGeom.face(b, x0, x1, z0, z1, dir, y0, y1, t);
      FacilityGeom.cap(b, x0, x1, z0, z1, y1, t);
    }

// a corner watchtower over the 2x2 block whose top-left cell this is
  static function tower(m:Facility, col:Int, row:Int):Void
    {
      var x0 = col * CELL - half() + TOWER_INSET;
      var z0 = row * CELL - half() + TOWER_INSET;
      var x1 = x0 + CELL * gen.military.MilitaryGen.TOWER - TOWER_INSET * 2;
      var z1 = z0 + CELL * gen.military.MilitaryGen.TOWER - TOWER_INSET * 2;
      var olive = buf(TEX_OLIVE);
      // the ladder's side, and the ring of bags round the legs with a way in at the ladder
      var side = ((x0 + x1) / 2 < 0 ? 3 : 2);
      var cz = (z0 + z1) / 2;
      var o = BAGS_OUT;
      MilitaryBags.ring(bags, {
        x0: x0 - o,
        x1: x1 + o,
        z0: z0 - o,
        z1: z1 + o,
      }, 0, TOWER_BAGS, {
        dir: side,
        a0: cz - LADDER_W,
        a1: cz + LADDER_W,
      });
      // the four legs from the ground, then the deck slab, the parapet round it, the roof posts and
      // the roof
      for (cx in [ x0, x1 - LEG_W ])
        for (cz in [ z0, z1 - LEG_W ])
          {
            box(buf(TEX_CONCRETE), cx, cx + LEG_W, cz, cz + LEG_W, 0, DECK_Y - DECK_T, OLIVE_TILE);
            box(olive, cx, cx + LEG_W, cz, cz + LEG_W, DECK_Y + PARAPET_H, ROOF_Y, OLIVE_TILE);
          }
      // the parapet: its outside from under the slab, its inside from the deck and its rim, so from
      // in the tower it is a wall and not the far side seen through a hole
      var top = DECK_Y + PARAPET_H;
      var t = PARAPET_T;
      for (dir in 0...4)
        {
          FacilityGeom.face(olive, x0, x1, z0, z1, dir, DECK_Y - DECK_T, top, OLIVE_TILE);
          faceIn(olive, x0 + t, x1 - t, z0 + t, z1 - t, dir, DECK_Y, top, OLIVE_TILE);
        }
      FacilityGeom.cap(olive, x0, x1, z0, z0 + t, top, OLIVE_TILE);
      FacilityGeom.cap(olive, x0, x1, z1 - t, z1, top, OLIVE_TILE);
      FacilityGeom.cap(olive, x0, x0 + t, z0 + t, z1 - t, top, OLIVE_TILE);
      FacilityGeom.cap(olive, x1 - t, x1, z0 + t, z1 - t, top, OLIVE_TILE);
      FacilityGeom.capDown(olive, x0, x1, z0, z1, DECK_Y - DECK_T, OLIVE_TILE);
      FacilityGeom.cap(buf(TEX_APRON), x0 + t, x1 - t, z0 + t, z1 - t, DECK_Y, PAD_TILE);
      ladder(x0, x1, z0, z1, side);
      o = ROOF_OVER;
      for (dir in 0...4)
        FacilityGeom.face(olive, x0 - o, x1 + o, z0 - o, z1 + o, dir, ROOF_Y, ROOF_Y + ROOF_T,
          OLIVE_TILE);
      FacilityGeom.cap(olive, x0 - o, x1 + o, z0 - o, z1 + o, ROOF_Y + ROOF_T, OLIVE_TILE);
      FacilityGeom.capDown(olive, x0 - o, x1 + o, z0 - o, z1 + o, ROOF_Y, OLIVE_TILE);
      FacilityDetail.ground(m, {
        col: col,
        row: row,
        len: 1,
        alongX: true,
        rect: {
          x0: x0 - BAGS_OUT,
          x1: x1 + BAGS_OUT,
          z0: z0 - BAGS_OUT,
          z1: z1 + BAGS_OUT,
        },
        h: TOWER_BAGS * MilitaryBags.H,
      });
    }

// a rect's side in `dir`, wound to face INTO the rect: a parapet's inside
  static function faceIn(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, dir:Int, y0:Float,
      y1:Float, t:Float):Void
    {
      var e = FacilityGeom.ends(x0, x1, z0, z1, dir);
      var us = (dir < 2 ? e[0] : e[1]) / t;
      var ue = (dir < 2 ? e[2] : e[3]) / t;
      MeshBufTools.quad(b, [e[2], y0, e[3]], [e[0], y0, e[1]], [e[0], y1, e[1]], [e[2], y1, e[3]],
        [ue, y0 / t, us, y0 / t, us, y1 / t, ue, y1 / t]);
    }

// a steel ladder standing off a tower's `dir` face (2 the -x one, 3 the +x one), from the ground to
// a rung over the parapet
  static function ladder(x0:Float, x1:Float, z0:Float, z1:Float, dir:Int):Void
    {
      var b = buf(TEX_GALV);
      var lx = (dir == 3 ? x1 + LADDER_OFF : x0 - LADDER_OFF);
      var cz = (z0 + z1) / 2;
      var w = LADDER_W / 2;
      var r = RAIL_W / 2;
      var top = DECK_Y + PARAPET_H + RUNG_STEP;
      for (rz in [ cz - w, cz + w ])
        pipe(b, lx, rz, r, 0, top);
      var y = RUNG_STEP;
      while (y < top)
        {
          box(b, lx - r, lx + r, cz - w, cz + w, y, y + RUNG_T, GALV_TILE);
          y += RUNG_STEP;
        }
    }

// a tent over the rect of tent cells whose top-left cell this is: canvas walls to the eave, two
// roof slopes up to a ridge along its LONG axis, and the gable triangles at both ends
  static function tent(m:Facility, area:AreaGame, col:Int, row:Int):Void
    {
      var w = 1;
      while (area.getCellType(col + w, row) == Const.TILE_MIL_TENT)
        w++;
      var h = 1;
      while (area.getCellType(col, row + h) == Const.TILE_MIL_TENT)
        h++;
      var x0 = col * CELL - half() + TENT_INSET;
      var z0 = row * CELL - half() + TENT_INSET;
      var x1 = x0 + w * CELL - TENT_INSET * 2;
      var z1 = z0 + h * CELL - TENT_INSET * 2;
      var b = buf(TEX_CANVAS);
      var t = CANVAS_TILE;
      for (dir in 0...4)
        FacilityGeom.face(b, x0, x1, z0, z1, dir, 0, TENT_EAVE, t);
      if (h >= w)
        {
          // the ridge runs along z
          var cx = (x0 + x1) / 2;
          MeshBufTools.quad(b, [x0, TENT_EAVE, z1], [cx, TENT_RIDGE, z1], [cx, TENT_RIDGE, z0],
            [x0, TENT_EAVE, z0], slopeUV(x0, cx, z0, z1, TENT_EAVE, TENT_RIDGE, true));
          MeshBufTools.quad(b, [cx, TENT_RIDGE, z1], [x1, TENT_EAVE, z1], [x1, TENT_EAVE, z0],
            [cx, TENT_RIDGE, z0], slopeUV(cx, x1, z0, z1, TENT_RIDGE, TENT_EAVE, true));
          MeshBufTools.quad(b, [x1, TENT_EAVE, z0], [x0, TENT_EAVE, z0], [cx, TENT_RIDGE, z0],
            [cx, TENT_RIDGE, z0], [x1 / t, TENT_EAVE / t, x0 / t, TENT_EAVE / t, cx / t,
            TENT_RIDGE / t, cx / t, TENT_RIDGE / t]);
          MeshBufTools.quad(b, [x0, TENT_EAVE, z1], [x1, TENT_EAVE, z1], [cx, TENT_RIDGE, z1],
            [cx, TENT_RIDGE, z1], [x0 / t, TENT_EAVE / t, x1 / t, TENT_EAVE / t, cx / t,
            TENT_RIDGE / t, cx / t, TENT_RIDGE / t]);
        }
      else
        {
          // the ridge runs along x
          var cz = (z0 + z1) / 2;
          MeshBufTools.quad(b, [x0, TENT_EAVE, z0], [x0, TENT_RIDGE, cz], [x1, TENT_RIDGE, cz],
            [x1, TENT_EAVE, z0], slopeUV(z0, cz, x0, x1, TENT_EAVE, TENT_RIDGE, false));
          MeshBufTools.quad(b, [x0, TENT_RIDGE, cz], [x0, TENT_EAVE, z1], [x1, TENT_EAVE, z1],
            [x1, TENT_RIDGE, cz], slopeUV(cz, z1, x0, x1, TENT_RIDGE, TENT_EAVE, false));
          MeshBufTools.quad(b, [x0, TENT_EAVE, z0], [x0, TENT_EAVE, z1], [x0, TENT_RIDGE, cz],
            [x0, TENT_RIDGE, cz], [z0 / t, TENT_EAVE / t, z1 / t, TENT_EAVE / t, cz / t,
            TENT_RIDGE / t, cz / t, TENT_RIDGE / t]);
          MeshBufTools.quad(b, [x1, TENT_EAVE, z1], [x1, TENT_EAVE, z0], [x1, TENT_RIDGE, cz],
            [x1, TENT_RIDGE, cz], [z1 / t, TENT_EAVE / t, z0 / t, TENT_EAVE / t, cz / t,
            TENT_RIDGE / t, cz / t, TENT_RIDGE / t]);
        }
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
        h: TENT_EAVE,
      });
    }

// world-tiled UVs down one roof slope, u along the ridge and v up the slope's own length so the
// canvas is not squashed by the pitch. `a0..a1` is the slope across the ridge, `r0..r1` along it,
// in the vertex order the caller winds
  static function slopeUV(a0:Float, a1:Float, r0:Float, r1:Float, y0:Float, y1:Float,
      ridgeZ:Bool):Array<Float>
    {
      var t = CANVAS_TILE;
      var len = Math.sqrt((a1 - a0) * (a1 - a0) + (y1 - y0) * (y1 - y0));
      return (ridgeZ ?
        [r1 / t, 0, r1 / t, len / t, r0 / t, len / t, r0 / t, 0] :
        [r0 / t, 0, r0 / t, len / t, r1 / t, len / t, r1 / t, 0]);
    }

// a shipping container from its origin cell, the hand-modelled one (models-src/military/
// yardkit_build.py) along its length with the door on its west end
  static function container(m:Facility, col:Int, row:Int):Void
    {
      var x0 = col * CELL - half() + CONT_INSET;
      var z0 = row * CELL - half() + CONT_INSET;
      var x1 = x0 + Const.MIL_CONTAINER_LEN * CELL - CONT_INSET * 2;
      var z1 = z0 + CONT_W;
      containers.push({
        x: (x0 + x1) / 2,
        z: (z0 + z1) / 2,
        yaw: 0.0,
        y: 0.0,
      });
      FacilityDetail.ground(m, {
        col: col,
        row: row,
        len: Const.MIL_CONTAINER_LEN,
        alongX: true,
        rect: {
          x0: x0,
          x1: x1,
          z0: z0,
          z1: z1,
        },
        h: CONT_H,
      });
    }

// a camo net on four poles over a parked vehicle's footprint, its origin cell and size given
  static function net(col:Int, row:Int, size:Array<Int>):Void
    {
      var x0 = col * CELL - half() - NET_OVER;
      var z0 = row * CELL - half() - NET_OVER;
      var x1 = x0 + size[0] * CELL + NET_OVER * 2;
      var z1 = z0 + size[1] * CELL + NET_OVER * 2;
      FacilityGeom.cap(buf(TEX_NET, true), x0, x1, z0, z1, NET_Y, NET_TILE);
      for (px in [ x0, x1 - POLE_W ])
        for (pz in [ z0, z1 - POLE_W ])
          box(buf(TEX_OLIVE), px, px + POLE_W, pz, pz + POLE_W, 0, NET_Y, OLIVE_TILE);
    }

// an armory locker bank or the gun cabinet, as its glb with its back to its wall, on its object's cell
// or on a gun locker tile (render.military.MilitaryInterior)
  public static function locker(m:Facility, col:Int, row:Int, path:String):Void
    {
      var dir = CorpFurniture.lockerBack(m, col, row);
      if (dir < 0)
        return;
      var r = CorpFurniture.lockerRect(m, col, row, dir);
      MilitaryInterior.put(path, (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2, MilitaryInterior.YAW[dir], 0.0);
      // its top takes clutter, 2D and a piece of gear ("top of the locker needs clutter spots")
      MilitaryInterior.top((r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2, MilitaryInterior.YAW[dir], LOCKER_TOP_W,
        LOCKER_TOP_D, MilitaryInterior.LOCKER_H, LOCKER, []);
      MilitaryInterior.shade(m, {
        col: col,
        row: row,
        len: 1,
        alongX: dir < 2,
        rect: r,
        h: MilitaryInterior.LOCKER_H,
      });
    }

// the HQ's safe: its glb against its wall, on the locker's footprint narrowed to its width round the
// cell's centre and cut to its depth off the wall
  static function safe(m:Facility, col:Int, row:Int):Void
    {
      var dir = CorpFurniture.lockerBack(m, col, row);
      if (dir < 0)
        return;
      var cell = CorpFurniture.lockerRect(m, col, row, dir);
      var cx = (cell.x0 + cell.x1) / 2;
      var cz = (cell.z0 + cell.z1) / 2;
      var hw = SAFE_W / 2;
      var r = switch (dir)
        {
          case 0: { x0: cx - hw, x1: cx + hw, z0: cell.z0, z1: cell.z0 + SAFE_D };
          case 1: { x0: cx - hw, x1: cx + hw, z0: cell.z1 - SAFE_D, z1: cell.z1 };
          case 2: { x0: cell.x0, x1: cell.x0 + SAFE_D, z0: cz - hw, z1: cz + hw };
          default: { x0: cell.x1 - SAFE_D, x1: cell.x1, z0: cz - hw, z1: cz + hw };
        };
      MilitaryInterior.put(RenderConfig.MODELS.militarySafe, (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2,
        MilitaryInterior.YAW[dir], 0.0);
      MilitaryInterior.shade(m, {
        col: col,
        row: row,
        len: 1,
        alongX: dir < 2,
        rect: r,
        h: MilitaryInterior.SAFE_H,
      });
    }

// the helipad's concrete over a rect of cells from its top-left one, a whisker over the lot
  static function apron(col:Int, row:Int, size:Array<Int>):Void
    {
      var x0 = col * CELL - half();
      var z0 = row * CELL - half();
      FacilityGeom.cap(buf(TEX_APRON), x0, x0 + size[0] * CELL, z0, z0 + size[1] * CELL,
        -FacilityStyle.KERB_DROP + PAD_Y, PAD_TILE);
    }

// the helipad's painted ring and H over its square of cells, upright with the grid
  static function mark(c0:Int, r0:Int, c1:Int, r1:Int):Void
    {
      var x0 = c0 * CELL - half() + MARK_INSET;
      var z0 = r0 * CELL - half() + MARK_INSET;
      var x1 = (c1 + 1) * CELL - half() - MARK_INSET;
      var z1 = (r1 + 1) * CELL - half() - MARK_INSET;
      var y = -FacilityStyle.KERB_DROP + MARK_Y;
      MeshBufTools.quad(buf(TEX_PAD_MARK, true), [x0, y, z1], [x1, y, z1], [x1, y, z0], [x0, y, z0],
        [0, 0, 1, 0, 1, 1, 0, 1]);
    }

// half the city grid's span, the world offset of cell (0, 0)'s low corner
  static inline function half():Float
    return (CityConfig.GRID * CELL) / 2;

// the buffer for a texture, opaque or alpha-cut
  public static function buf(tex:String, ?isCut:Bool = false):MeshBuf
    {
      var map = (isCut ? cut : opaque);
      if (!map.exists(tex))
        map.set(tex, MeshBufTools.make());
      return map.get(tex);
    }

// one alpha-cut family as one mesh: opaque alphaTest DoubleSide, FacilityCable.add's shape — one
// pass, depth written, VisionMask on its darkening branch
  static function addCut(scene:Scene, b:MeshBuf, tex:String):Void
    {
      if (b.idx.length == 0)
        return;
      var mesh = new Mesh(FacilityGeom.geom(b), VisionMask.patch(new MeshLambertMaterial({
        map: Textures.loadTexture(tex, 'wall', 1),
        alphaTest: CUT,
        side: THREE.DoubleSide,
      })));
      mesh.name = 'military ' + tex;
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }
}
