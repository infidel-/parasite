package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.particles.LampPost;
import render.particles.Sprites;
import render.facility.FacilityModel.Facility;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// every additive glow in a facility, in ONE draw call: the ceiling panels, the pool each panel
// throws on its own floor, the light that falls out of a WINDOW onto the ground outside it, and the
// lens of the bulkhead lamp over each exterior door. the lamp HEADS are not here — they glow off the
// mast glb's own emissive map, see FacilityStyle's GLOW block. nor is anything on the ground under a
// DOOR: a doorway has a fitting over it and the fitting's own cone and spotlight light the asphalt,
// where a window is a hole and has nothing but this.
//
// they are one mesh because they differ only in BRIGHTNESS, and brightness is a per-vertex grey
// (render.world.MeshBuf.quadC, the channel render.sewer.SewerGeom already uses for its wall bands).
// so the material carries the hue and the HDR multiplier once and each quad scales them — which is
// also what decides what BLOOMS: see FacilityStyle.GLOW for the arithmetic, and change nothing here
// without redoing it.
//
// this is the layer that makes the place read as OCCUPIED. phase 3a lifted every interior uniformly,
// which says the lights are on but never says WHERE they are; the pooled spotlights say where, but
// only for the 12 fixtures nearest the player and only over about a cell each. these quads cover
// both gaps for one call and no per-frame work at all — nothing here moves, fades or is repacked
// where the bulkhead lamp over an exterior door hangs, and which way it faces. shared rather than
// re-derived, because THREE passes need the same point and would drift apart: FacilityGeom emits the
// hood, this file lights its lens and the ground under it, and FacilityLamps hangs the spotlight and
// its cone off it
typedef DoorLamp = {
  x:Float,      // the lens centre — the wall face pushed out by the hood's own depth
  y:Float,
  z:Float,
  nx:Float,     // the outward normal, one of the four axis directions
  nz:Float,
  dir:Int,      // and the same direction in FacilityGeom's cell-edge numbering
};

class FacilityGlow
{
  static inline var CELL = CityConfig.CELL;
  // the door lamp's hue as a MULTIPLIER on the shared mesh's own colour, so one additive material
  // draws two lights. the merged mesh is `new Color(LAMP_COLOR) * GLOW` and multiplies a per-vertex
  // colour on top, so this ratio turns any quad that carries it into `new Color(DOOR_LAMP_COLOR) *
  // GLOW` exactly — and it is right whatever colour space `new Color` works in, both terms being in
  // the same one
  static var WARM:Array<Float> = null;

// build the whole glow layer, and return the openings as fake-shadow sources — see `opening`. the
// room pair asks render.facility.FacilityLamps the same `lit` question the fixtures were placed off,
// so a panel and its bulb cannot drift apart
  public static function build(scene:Scene, m:Facility):Array<LampPost>
    {
      var b = MeshBufTools.make();
      var lamps = [];
      for (r in m.rooms)
        {
          if (!FacilityStyle.CEIL_GLOW ||
              !FacilityLamps.lit(m, r))
            continue;
          var c = CityConfig.cellToWorld(Std.int((r.x1 + r.x2) / 2), Std.int((r.y1 + r.y2) / 2));
          // the fitting, and the long axis of a panel follows the long axis of the room it lights
          var w = (r.w >= r.h ? FacilityStyle.PANEL_W : FacilityStyle.PANEL_H) / 2;
          var d = (r.w >= r.h ? FacilityStyle.PANEL_H : FacilityStyle.PANEL_W) / 2;
          flat(b, c.x - w, c.x + w, c.z - d, c.z + d,
            FacilityStyle.ROOF_Y - FacilityStyle.PANEL_DROP, FacilityStyle.C_PANEL);
          // and the pool it throws, over the room's own rect. the rect is INCLUSIVE of x2/y2 (see
          // _Room), so the far edge is that cell's far boundary and not its centre
          var lo = CityConfig.cellToWorld(r.x1, r.y1);
          var hi = CityConfig.cellToWorld(r.x2, r.y2);
          var i = FacilityStyle.POOL_INSET;
          flat(b, lo.x - CELL / 2 + i, hi.x + CELL / 2 - i, lo.z - CELL / 2 + i, hi.z + CELL / 2 - i,
            FacilityStyle.GLOW_Y, FacilityStyle.C_POOL);
        }
      // what falls out of the glazing. a run is emitted as ONE rect over its whole length, the same
      // granularity render.facility.FacilityGeom cuts the opening at
      for (w in m.windows)
        {
          var lo = CityConfig.cellToWorld(w.col, w.row);
          var hi = CityConfig.cellToWorld(w.col + (w.alongX ? w.len - 1 : 0),
            w.row + (w.alongX ? 0 : w.len - 1));
          spill(b, m, lo, hi, w.alongX, w.inDir);
          // one shadow source per CELL of the run rather than one at its centre. it matters: the
          // reach is 3 cells and a 3-cell run is 3 cells LONG, so an actor standing off one end of a
          // centred source would be shadowed along the wall instead of away from it
          for (i in 0...w.len)
            lamps.push(opening(w.col + (w.alongX ? i : 0), w.row + (w.alongX ? 0 : i)));
        }
      // a door gets ONLY its lamp's lens. NO SPILL PATCH AND NO SHADOW SOURCE, and both went for the
      // same reason: an exterior doorway is now lit by a real fitting — a hood, a lens, a half cone
      // and a pooled spotlight (render.facility.FacilityLamps) — so the flat trapezoid a window
      // throws is a SECOND light in the same place, drawn from a different height, with an unrelated
      // shape. Reported from the game as exactly that, a rectangle on the ground under the lamp.
      //
      // it had already been cut back once, from every exterior doorway to the glazed ones alone
      // (the hangar's solid METAL shutter was spilling light out of a sheet of steel). What that
      // pass got wrong is that GLAZING was never the question either: a lit doorway is lit by the
      // thing over it whatever the leaves are made of, and a window's spill exists because a window
      // has no fitting of its own.
      //
      // the fake-shadow source goes with it. `opening` puts one at the wall CELL CENTRE at
      // SPILL_Y — the right stand-in for a light that IS the aperture, and a duplicate of the
      // hood's own LampPost, which is a metre and a half further out and a metre and a half higher.
      // Windows keep both; they are still the only thing here that lights the ground by being a hole
      for (d in m.doors)
        {
          if (outward(m, d) == 0)
            continue;
          door(b, m, d);
        }
      add(scene, b);
      return lamps;
    }

// where the hood over an exterior door hangs, or null for an interior one.
//
// the point is the LENS PLANE — the wall's outer face pushed out by the hood's whole depth, that
// face being PARAPET_INSET in from the cell boundary, which is `slab`'s own plane on a door cell.
// so the hood hangs BACK from it to the masonry, the lens sits a hair proud of it, and the cone
// and the spotlight hang under it. one point, three files, nothing to drift
  public static function lamp(m:Facility, d:FacilityModel.DoorCell):DoorLamp
    {
      var out = outward(m, d);
      if (out == 0)
        return null;
      var c = CityConfig.cellToWorld(d.col, d.row);
      var nx = (d.alongX ? 0.0 : out * 1.0);
      var nz = (d.alongX ? out * 1.0 : 0.0);
      var r = CELL / 2 - FacilityStyle.PARAPET_INSET + FacilityStyle.DOOR_LAMP_D;
      return {
        x: c.x + nx * r,
        y: FacilityStyle.DOOR_LAMP_Y + FacilityStyle.DOOR_LAMP_H / 2,
        z: c.z + nz * r,
        nx: nx,
        nz: nz,
        dir: (d.alongX ? (out > 0 ? 1 : 0) : (out > 0 ? 3 : 2)),
      };
    }

// the door lamp's LENS, on the front of its hood, carrying the WARM tint — so one additive mesh
// draws the compound's cool installation and this one amber fitting for the same draw call.
//
// ONE quad and not two: it had a ground pool under it for a build, and that is not how an outdoor
// lamp works in this compound. A mast draws a CONE and claims a spotlight and puts no additive quad
// on the ground at all; C_POOL and C_SPILL are for a room seen through its own faded roof and for
// what falls out of a window, neither of which this is. Built, the pool read as exactly what it was
// — a flat amber card lying on the asphalt with the cone's own shaft landing inside it
  static function door(b:MeshBuf, m:Facility, d:FacilityModel.DoorCell):Void
    {
      var l = lamp(m, d);
      if (l == null)
        return;
      // the lens, a fraction of the hood's face so the housing round it stays dark
      var hw = FacilityStyle.DOOR_LAMP_W * FacilityStyle.DOOR_LENS_W / 2;
      var hh = FacilityStyle.DOOR_LAMP_H * FacilityStyle.DOOR_LENS_H / 2;
      var e = FacilityStyle.DOOR_LENS_EPS;
      // along the wall line, which is the axis the normal is NOT on
      var ax = (l.nx != 0 ? 0.0 : 1.0);
      var az = (l.nx != 0 ? 1.0 : 0.0);
      var px = l.x + l.nx * e;
      var pz = l.z + l.nz * e;
      warm(b,
        [px - ax * hw, l.y - hh, pz - az * hw],
        [px + ax * hw, l.y - hh, pz + az * hw],
        [px + ax * hw, l.y + hh, pz + az * hw],
        [px - ax * hw, l.y + hh, pz - az * hw],
        FacilityStyle.C_DOOR_LENS);
    }

// one quad at a brightness the door lamp's hue is folded into. the shared `quad` below pushes a
// GREY, which is all the cool installation needs; this pushes the ratio that recolours the material
  static function warm(b:MeshBuf, p0:Array<Float>, p1:Array<Float>, p2:Array<Float>,
      p3:Array<Float>, c:Float):Void
    {
      if (WARM == null)
        {
          var a = new Color(FacilityStyle.LAMP_COLOR);
          var w = new Color(FacilityStyle.DOOR_LAMP_COLOR);
          WARM = [w.r / a.r, w.g / a.g, w.b / a.b];
        }
      MeshBufTools.quad(b, p0, p1, p2, p3, [0, 0, 1, 0, 1, 1, 0, 1]);
      for (i in 0...4)
        for (k in 0...3)
          b.col.push(WARM[k] * c);
    }

// one WINDOW cell as a fake actor-shadow source: a LampPost that never goes near the spotlight pool
// and so never claims one of its 12 slots, handed straight to render.actors.LampShadows through
// render.Area3D.shadowLamps.
//
// windows only. a door had one too and it was a second light in the same place as the hood's own
// pooled LampPost, an aperture stand-in for a doorway that is no longer lit by being an aperture.
//
// it sits at the wall CELL CENTRE, which is what makes the shadow point out of the building: the
// projector's only input is the direction away from the light. steady (phase/flick are the STEADY
// markers), because a window does not sputter, and `mul` is meaningless here — nothing ever reads it
  static function opening(col:Int, row:Int):LampPost
    {
      var c = CityConfig.cellToWorld(col, row);
      return {
        x: c.x,
        z: c.z,
        y: FacilityStyle.SPILL_Y,
        tx: c.x,
        tz: c.z,
        color: FacilityStyle.LAMP_COLOR,
        col: col,
        row: row,
        phase: 0.0,
        flick: 1.0,
        mul: 1.0,
      };
    }

// one horizontal quad at height y — a ceiling panel seen from above through the faded roof, or a
// pool lying on the floor. wound like render.facility.FacilityGeom.cap, though the material is
// DoubleSide and additive so nothing here depends on that
  static function flat(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, y:Float, c:Float):Void
    {
      if (x1 - x0 < 0.01 ||
          z1 - z0 < 0.01)
        return;
      quad(b, [x0, y, z1], [x1, y, z1], [x1, y, z0], [x0, y, z0], c);
    }

// the ground patch outside one opening. `lo`/`hi` are the world centres of the run's first and last
// cell and `inDir` points at the INTERIOR, so the light goes the other way.
//
// the patch starts at the wall CELL CENTRE rather than at the outer face of the masonry. that is
// deliberate and free: the rounded-box gradient this mesh uses as its alpha map fades all four
// edges, so a patch that began at the face would go dark exactly where it should be brightest —
// starting a cell-half further in buries that near fade inside the wall, which draws over it.
//
// it is a TRAPEZOID, not a rectangle: the far edge is FacilityStyle.SPILL_SPREAD wider per side, so
// the patch fans the way light out of an aperture actually does. the uv stays 0..1 across the quad,
// so the shared gradient still fits it — the fan costs two numbers and no extra geometry.
//
// it lies at the height of the surface it falls ON, sampled at the cell immediately outside the
// opening — ONE sample, not four. a patch on a window facing the park would otherwise float the
// kerb step; and a corner sample is worthless anyway, because a quad corner sits exactly on a cell
// boundary where CityConfig.worldToCell rounds either way (see FacilityTables.hatchY)
  static function spill(b:MeshBuf, m:Facility, lo:{ x:Float, z:Float }, hi:{ x:Float, z:Float },
      alongX:Bool, inDir:Int):Void
    {
      var d = -inDir * FacilityStyle.SPILL_DEPTH;
      var e = FacilityStyle.SPILL_SPREAD;
      var o = CityConfig.worldToCell(lo.x - (alongX ? 0 : inDir * CELL),
        lo.z - (alongX ? inDir * CELL : 0));
      var y = FacilityStyle.GLOW_Y + (FacilityModel.inside(m, o.col, o.row)
        ? FacilityGround.surfY(m.surf[o.row][o.col]) : 0.0);
      if (alongX)
        {
          var z = lo.z + d;
          quad(b, [lo.x - CELL / 2, y, lo.z], [hi.x + CELL / 2, y, lo.z],
            [hi.x + CELL / 2 + e, y, z], [lo.x - CELL / 2 - e, y, z],
            FacilityStyle.C_SPILL);
          return;
        }
      var x = lo.x + d;
      quad(b, [lo.x, y, lo.z - CELL / 2], [lo.x, y, hi.z + CELL / 2],
        [x, y, hi.z + CELL / 2 + e], [x, y, lo.z - CELL / 2 - e],
        FacilityStyle.C_SPILL);
    }

// which way is OUT of a door cell, as the +1/-1 an opening's `inDir` is expressed in — 0 when neither
// side is outdoors, which is every interior door and is what makes this the exterior-door test.
//
// DoorCell.inDir cannot answer it: that one is the side the LEAVES SWING into, and which way a door
// opens has nothing to do with which side the lot is on. and only the PERPENDICULAR axis is tested,
// picked off the same `alongX` the quad is then built on — along the wall line there is nothing but
// more wall, so reading a neighbour there would answer about the wrong axis and could spill a
// doorway's light out through the masonry beside it.
//
// public for render.facility.FacilityExit, which needs the same question for a different reason: an
// exit sign belongs over a door that IS an exit, and "leads outdoors" is exactly that test
  public static function outward(m:Facility, d:FacilityModel.DoorCell):Int
    {
      for (s in [-1, 1])
        if (d.alongX ? open(m, d.col, d.row + s) : open(m, d.col + s, d.row))
          return s;
      return 0;
    }

// is this cell outdoor ground: inside the grid, no wall, and not one of the indoor floor surfaces
  static inline function open(m:Facility, col:Int, row:Int):Bool
    return FacilityModel.inside(m, col, row) &&
      !FacilityModel.isWall(m, col, row) &&
      !FacilityModel.isIndoor(m, col, row);

// one quad with its own 0..1 uv (so the shared gradient fits it whatever its size) and a flat
// per-vertex brightness
  static inline function quad(b:MeshBuf, p0:Array<Float>, p1:Array<Float>, p2:Array<Float>,
      p3:Array<Float>, c:Float):Void
    MeshBufTools.quadC(b, p0, p1, p2, p3, [0, 0, 1, 0, 1, 1, 0, 1], [c, c, c, c]);

// merge the buffer into the one additive mesh
  static function add(scene:Scene, b:MeshBuf):Void
    {
      if (b.idx.length == 0)
        return;
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(b.pos, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(b.uv, 2));
      geo.setAttribute('color', new Float32BufferAttribute(b.col, 3));
      geo.setIndex(b.idx);
      // the vision mask, and it is not decoration here: hiddenAdd is 0.0 in FacilityStyle.MASK, so a
      // glow the player cannot see is cut to a true zero rather than merely dimmed. without it every
      // lit room in the compound would shine through its own walls
      var mesh = new Mesh(geo, VisionMask.patch(new MeshBasicMaterial({
        color: new Color(FacilityStyle.LAMP_COLOR).multiplyScalar(FacilityStyle.GLOW),
        transparent: true,
        // square corners: a spill patch is cut by the straight jambs of the opening it falls out of,
        // and the default rounded box left it reading as a blob
        alphaMap: Textures.makeRectGlowGradient(0.0),
        vertexColors: true,
        depthWrite: false,
        side: THREE.DoubleSide,
        blending: untyped THREE.AdditiveBlending,
      })));
      // BELOW the actors, for the reason render.sewer.SewerLamps records for its wall fixtures:
      // nothing in the sprite pool writes depth, so a glow drawn at the actors' own order paints its
      // bright core straight through anyone standing in front of it
      mesh.renderOrder = Sprites.ORD_FIXTURE;
      scene.add(mesh);
    }
}
