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
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

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
  static inline var TEX_WIRE = 'textures/military/razor-wire.png';
  static inline var TEX_NET = 'textures/military/camo-net.png';
  static inline var TEX_OLIVE = 'textures/military/wall-olive.png';
  static inline var TEX_CONCRETE = 'textures/military/wall-concrete.png';
  static inline var TEX_CANVAS = 'textures/military/tent-canvas.png';
  static inline var TEX_CONT_SIDE = 'textures/military/container-side.png';
  static inline var TEX_CONT_DOOR = 'textures/military/container-door.png';
  static inline var TEX_SANDBAG = 'textures/military/sandbag.png';
  static inline var TEX_APRON = 'textures/military/apron.png';
  static inline var TEX_SAFE = 'textures/military/safe-front.png';
  static inline var TEX_LOCKER = 'textures/military/locker-front.png';
  static inline var TEX_GUNS = 'textures/military/gunrack-front.png';
  static inline var TEX_STEEL = MilitaryStyle.WINDOW_HEAD;
  static inline var TEX_PAD_MARK = 'textures/military/helipad-h.png';

  // the fence: two cells high, one sheet of eight diamonds per CHAIN_TILE units, and a post at
  // every cell edge
  public static inline var FENCE_H = CELL * 2;
  static inline var CHAIN_TILE = 4.0;
  static inline var POST_W = 0.35;
  // the razor-wire coil along its top: v 0..1 over WIRE_H, u at the 1024x640 source's own aspect
  static inline var WIRE_H = 1.6;
  static inline var WIRE_TILE = WIRE_H * 1.6;
  // the alpha cut every see-through face here takes
  static inline var CUT = 0.3;

  // the corner watchtower over its 2x2 footprint: legs to the deck, a corrugated parapet round it,
  // posts to a flat roof, and a sandbag ring at its foot
  static inline var TOWER_INSET = 0.6;
  static inline var LEG_W = 0.6;
  static inline var DECK_Y = FENCE_H + 2.0;
  static inline var DECK_T = 0.5;
  static inline var PARAPET_H = 2.2;
  static inline var ROOF_Y = DECK_Y + 5.0;
  static inline var ROOF_T = 0.4;
  static inline var ROOF_OVER = 0.6;
  static inline var OLIVE_TILE = 4.0;
  static inline var SANDBAG_H = 2.4;

  // a tent over its 2x3 cells: walls to the eave, a ridge along its long axis
  static inline var TENT_INSET = 0.4;
  static inline var TENT_EAVE = 2.2;
  static inline var TENT_RIDGE = 5.6;
  static inline var CANVAS_TILE = 4.0;

  // a 20 ft container: Const.MIL_CONTAINER_LEN cells long, its end face locked to the door art's
  // 508x546 crop (military/container-door)
  static inline var CONT_INSET = 0.2;
  static inline var CONT_W = CELL - CONT_INSET * 2;
  static inline var CONT_H = CONT_W * 546 / 508;
  static inline var CONT_TILE = 4.0;

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

  // the armory safe, against its wall, its front locked to the 510x546 crop (military/safe-front)
  static inline var SAFE_W = 1.8;
  static inline var SAFE_H = SAFE_W * 546 / 510;
  static inline var SAFE_D = 1.6;

  // the buffers being filled, one per texture
  static var opaque:Map<String, MeshBuf>;
  static var cut:Map<String, MeshBuf>;

// emit the whole base. runs BEFORE ContactMask.repaint in render.facility.FacilityArea.build: every
// unit here registers its footprint with the contact shadow
  public static function build(scene:Scene, m:Facility, area:AreaGame):Void
    {
      opaque = new Map();
      cut = new Map();
      var parked = 0;
      // the pad's square, off its cells, for the marking
      var pad = {
        x0: area.width,
        z0: area.height,
        x1: -1,
        z1: -1,
      };
      var f = gen.military.MilitaryGen.fenceOf(area.getCells(), area.width, area.height);
      for (row in 0...area.height)
        for (col in 0...area.width)
          {
            var t = area.getCellType(col, row);
            if (t == Const.TILE_MIL_FENCE ||
                t == Const.TILE_MIL_FENCE_TORN)
              fence(area, col, row, (row == f.y1 || row == f.y2), t == Const.TILE_MIL_FENCE_TORN);
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
          }
      if (pad.x1 >= 0)
        mark(pad.x0, pad.z0, pad.x1, pad.z1);
      MilitaryInterior.build(m, area);
      MilitaryYard.build(scene, m, area);
      // the armory: the lockers, the gun cabinet and the safe the generator stood against its walls.
      // ponytail: drawn shut whatever their state, an open one is told by its tooltip
      for (o in area.getObjects())
        if (o.type == 'locker' ||
            o.type == 'gunCabinet')
          locker(m, o.x, o.y, (o.type == 'locker' ? TEX_LOCKER : TEX_GUNS));
        else if (o.type == 'safe')
          safe(m, o.x, o.y);
      for (tex in opaque.keys())
        FacilityGeom.add(scene, opaque.get(tex), tex, true, false);
      for (tex in cut.keys())
        addCut(scene, cut.get(tex), tex);
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

// one cell of the perimeter: its chain-link (the torn panel's lower half on a breach), the coil of
// razor wire along its top, and a post at its low edge, plus its high edge where the run stops
  static function fence(area:AreaGame, col:Int, row:Int, alongX:Bool, torn:Bool):Void
    {
      var c = CityConfig.cellToWorld(col, row);
      var a0 = (alongX ? c.x : c.z) - CELL / 2;
      var a1 = a0 + CELL;
      var p = (alongX ? c.z : c.x);
      var lo = 0.0;
      if (torn)
        {
          upright(buf(TEX_TORN, true), alongX, p, a0, a1, 0, CELL, 0, 1, 0, 1);
          lo = CELL;
        }
      upright(buf(TEX_CHAIN, true), alongX, p, a0, a1, lo, FENCE_H, a0 / CHAIN_TILE,
        a1 / CHAIN_TILE, lo / CHAIN_TILE, FENCE_H / CHAIN_TILE);
      upright(buf(TEX_WIRE, true), alongX, p, a0, a1, FENCE_H, FENCE_H + WIRE_H, a0 / WIRE_TILE,
        a1 / WIRE_TILE, 0, 1);
      post(alongX, p, a0);
      var nc = col + (alongX ? 1 : 0);
      var nr = row + (alongX ? 0 : 1);
      var nt = area.getCellType(nc, nr);
      if (nt != Const.TILE_MIL_FENCE &&
          nt != Const.TILE_MIL_FENCE_TORN)
        post(alongX, p, a1);
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

// a fence post at `a` along the line
  static function post(alongX:Bool, p:Float, a:Float):Void
    {
      var h = POST_W / 2;
      box(buf(TEX_OLIVE), (alongX ? a - h : p - h), (alongX ? a + h : p + h),
        (alongX ? p - h : a - h), (alongX ? p + h : a + h), 0, FENCE_H + WIRE_H, OLIVE_TILE);
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
      // the sandbag ring at its foot, round the legs
      var sand = buf(TEX_SANDBAG);
      for (dir in 0...4)
        FacilityGeom.face(sand, x0, x1, z0, z1, dir, 0, SANDBAG_H, SANDBAG_H);
      FacilityGeom.cap(sand, x0, x1, z0, z1, SANDBAG_H, SANDBAG_H);
      // the four legs, then the deck slab, the parapet round it, the roof posts and the roof
      for (cx in [ x0, x1 - LEG_W ])
        for (cz in [ z0, z1 - LEG_W ])
          {
            box(buf(TEX_CONCRETE), cx, cx + LEG_W, cz, cz + LEG_W, SANDBAG_H, DECK_Y - DECK_T,
              OLIVE_TILE);
            box(olive, cx, cx + LEG_W, cz, cz + LEG_W, DECK_Y + PARAPET_H, ROOF_Y, OLIVE_TILE);
          }
      for (dir in 0...4)
        FacilityGeom.face(olive, x0, x1, z0, z1, dir, DECK_Y - DECK_T, DECK_Y + PARAPET_H,
          OLIVE_TILE);
      FacilityGeom.capDown(olive, x0, x1, z0, z1, DECK_Y - DECK_T, OLIVE_TILE);
      FacilityGeom.cap(buf(TEX_APRON), x0, x1, z0, z1, DECK_Y, PAD_TILE);
      var o = ROOF_OVER;
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
          x0: x0,
          x1: x1,
          z0: z0,
          z1: z1,
        },
        h: SANDBAG_H,
      });
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

// a shipping container from its origin cell: corrugated sides and lid along its length, the door
// art on its west end and the corrugation on its east one
  static function container(m:Facility, col:Int, row:Int):Void
    {
      var x0 = col * CELL - half() + CONT_INSET;
      var z0 = row * CELL - half() + CONT_INSET;
      var x1 = x0 + Const.MIL_CONTAINER_LEN * CELL - CONT_INSET * 2;
      var z1 = z0 + CONT_W;
      var side = buf(TEX_CONT_SIDE);
      FacilityGeom.face(side, x0, x1, z0, z1, 0, 0, CONT_H, CONT_TILE);
      FacilityGeom.face(side, x0, x1, z0, z1, 1, 0, CONT_H, CONT_TILE);
      FacilityGeom.face(side, x0, x1, z0, z1, 3, 0, CONT_H, CONT_TILE);
      FacilityGeom.cap(side, x0, x1, z0, z1, CONT_H, CONT_TILE);
      FacilityGeom.pane(buf(TEX_CONT_DOOR), x0, x1, z0, z1, 2, 0, CONT_H);
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

// one armory locker or the gun cabinet, the corp security room's emitter on the base's object: its
// wall, its cell's footprint off the slab, an olive steel box with `front` on its face
  static function locker(m:Facility, col:Int, row:Int, front:String):Void
    {
      var dir = CorpFurniture.lockerBack(m, col, row);
      if (dir < 0)
        return;
      var r = CorpFurniture.lockerRect(m, col, row, dir);
      FacilityGeom.cap(buf(TEX_STEEL), r.x0, r.x1, r.z0, r.z1, CorpStyle.LOCKER_H,
        CorpStyle.LOCKER_TILE);
      for (f in 0...4)
        if (f != dir &&
            f != (dir ^ 1))
          FacilityGeom.face(buf(TEX_STEEL), r.x0, r.x1, r.z0, r.z1, f, 0,
            CorpStyle.LOCKER_H, CorpStyle.LOCKER_TILE);
      FacilityGeom.pane(buf(front), r.x0, r.x1, r.z0, r.z1, dir ^ 1, 0, CorpStyle.LOCKER_H);
      FacilityDetail.ground(m, {
        col: col,
        row: row,
        len: 1,
        alongX: dir < 2,
        rect: r,
        h: CorpStyle.LOCKER_H,
      });
    }

// the HQ's safe: a squat steel box against its wall, the dial and handle on its front
  static function safe(m:Facility, col:Int, row:Int):Void
    {
      var dir = CorpFurniture.lockerBack(m, col, row);
      if (dir < 0)
        return;
      var cell = CorpFurniture.lockerRect(m, col, row, dir);
      // the locker's footprint, narrowed to the safe's width round the cell's centre and cut to its
      // depth off the wall
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
      var steel = buf(TEX_STEEL);
      for (f in 0...4)
        if (f != dir &&
            f != (dir ^ 1))
          FacilityGeom.face(steel, r.x0, r.x1, r.z0, r.z1, f, 0, SAFE_H, CorpStyle.LOCKER_TILE);
      FacilityGeom.cap(steel, r.x0, r.x1, r.z0, r.z1, SAFE_H,
        CorpStyle.LOCKER_TILE);
      FacilityGeom.pane(buf(TEX_SAFE), r.x0, r.x1, r.z0, r.z1, dir ^ 1, 0, SAFE_H);
      FacilityDetail.ground(m, {
        col: col,
        row: row,
        len: 1,
        alongX: dir < 2,
        rect: r,
        h: SAFE_H,
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
