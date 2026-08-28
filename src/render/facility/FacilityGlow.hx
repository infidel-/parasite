package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.particles.Sprites;
import render.facility.FacilityModel.Facility;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// every additive glow in a facility, in ONE draw call: the ceiling panels, the pool each panel
// throws on its own floor, and the light that falls out of a window or a door onto the ground
// outside it. the lamp HEADS are not here — they glow off the mast glb's own emissive map, see
// FacilityStyle's GLOW block.
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
class FacilityGlow
{
  static inline var CELL = CityConfig.CELL;

// build the whole glow layer. the room pair asks render.facility.FacilityLamps the same `lit`
// question the fixtures were placed off, so a panel and its bulb cannot drift apart
  public static function build(scene:Scene, m:Facility):Void
    {
      var b = MeshBufTools.make();
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
          spill(b, lo, hi, w.alongX, w.inDir);
        }
      // and out of a door, which needs no open/shut state at all: a facility door is glazed and
      // objects.Door.canSeeThrough is true for it, so the light crosses a shut leaf as readily as an
      // open one. that is what keeps this whole mesh static
      for (d in m.doors)
        {
          var out = outward(m, d);
          if (out == 0)
            continue;
          var c = CityConfig.cellToWorld(d.col, d.row);
          // `spill` speaks the window convention, where the sign points at the INTERIOR
          spill(b, c, c, d.alongX, -out);
        }
      add(scene, b);
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
// starting a cell-half further in buries that near fade inside the wall, which draws over it
  static function spill(b:MeshBuf, lo:{ x:Float, z:Float }, hi:{ x:Float, z:Float },
      alongX:Bool, inDir:Int):Void
    {
      var d = -inDir * FacilityStyle.SPILL_DEPTH;
      if (alongX)
        {
          var z = lo.z + d;
          quad(b, [lo.x - CELL / 2, FacilityStyle.GLOW_Y, lo.z], [hi.x + CELL / 2, FacilityStyle.GLOW_Y, lo.z],
            [hi.x + CELL / 2, FacilityStyle.GLOW_Y, z], [lo.x - CELL / 2, FacilityStyle.GLOW_Y, z],
            FacilityStyle.C_SPILL);
          return;
        }
      var x = lo.x + d;
      quad(b, [lo.x, FacilityStyle.GLOW_Y, lo.z - CELL / 2], [lo.x, FacilityStyle.GLOW_Y, hi.z + CELL / 2],
        [x, FacilityStyle.GLOW_Y, hi.z + CELL / 2], [x, FacilityStyle.GLOW_Y, lo.z - CELL / 2],
        FacilityStyle.C_SPILL);
    }

// which way is OUT of a door cell, as the +1/-1 an opening's `inDir` is expressed in — 0 when neither
// side is outdoors, which is every interior door and is what makes this the exterior-door test.
//
// DoorCell.inDir cannot answer it: that one is the side the LEAVES SWING into, and which way a door
// opens has nothing to do with which side the lot is on. and only the PERPENDICULAR axis is tested,
// picked off the same `alongX` the quad is then built on — along the wall line there is nothing but
// more wall, so reading a neighbour there would answer about the wrong axis and could spill a
// doorway's light out through the masonry beside it
  static function outward(m:Facility, d:FacilityModel.DoorCell):Int
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
        alphaMap: Textures.makeRectGlowGradient(),
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
