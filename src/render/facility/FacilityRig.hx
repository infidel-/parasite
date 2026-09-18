// the study rig's leads: one glowing violet cord from the scenario's console and from each of its
// three slots to the ship's dais.
//
// WHY IT IS NOT render.facility.FacilityHangar's cable fan. That fan is DERIVED — it reads `deco`
// off the finished grid and runs a lead from every machine standing in the shed — and the four
// things this draws for are not on the grid at all: they are area OBJECTS the scenario spawns
// (src/scenario/GoalsAlienCrashLanding.hx), they can appear in a compound the player is already
// standing in, and one of them CHANGES STATE when a part is installed. So it is built off
// game.AreaGame's object list, on the same trigger the object props are (FacilityArea.refreshObjects).
//
// TWO MESHES AND NOT ONE, which is the whole of how "brighter once the part is in" is expressed: the
// brightness is a property of the MATERIAL, so the runs are split into the two states at build time
// and each half gets its own. That costs one extra draw call and no per-vertex data, and a filled
// slot rebuilds the pair anyway — the scenario flips the object's infoID, which is what tells this
// which bucket a run belongs in.
//
// the ribbon itself is render.facility.FacilityCable.strip, unchanged and at the fan's own height,
// so a rig lead and a machine lead are the same cord in two colours.

package render.facility;

import three.Three;
import citygen.CityConfig;
import game.AreaGame;
import render.RenderConfig;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

typedef Rig = {
  // the runs to the start console and to a slot still waiting for its part, and the runs to a slot
  // that has one. either may be null when nothing landed in that bucket
  dim:Mesh,
  lit:Mesh,
  // the shared breath, in RenderConfig.BASE_MS units
  t:Float,
};

class FacilityRig
{
  // the scenario's own ids, as render.world.ObjModels spells them minus its `event_` prefix. read
  // here rather than imported because scenario code is game-side and this is a renderer
  public static inline var SHIP = 'spaceshipStudyShip';
  public static inline var START = 'spaceshipStudyStart';
  public static inline var SLOT = 'spaceshipStudySlot';
  public static inline var SLOT_FULL = 'spaceshipStudySlotFull';

// lay every lead the rig standing in this compound needs. answers null when the scenario is not
// here, which is every compound but one
  public static function build(scene:Scene, area:AreaGame):Rig
    {
      var ship = null;
      var ends = [];
      for (o in area.getObjects())
        {
          var e = Std.downcast(o, objects.EventObject);
          if (e == null)
            continue;
          if (e.infoID == SHIP)
            ship = e;
          else if (e.infoID == START ||
                   e.infoID == SLOT ||
                   e.infoID == SLOT_FULL)
            ends.push(e);
        }
      if (ship == null ||
          ends.length == 0)
        return null;
      var dim = MeshBufTools.make();
      var lit = MeshBufTools.make();
      var mid = CityConfig.cellToWorld(ship.x, ship.y);
      // the run STOPS AT THE DAIS RIM, the fan's own arithmetic and for the fan's own reason: the
      // last span has to arrive at the port band the lower step wears rather than climbing the tread
      var r = FacilityStyle.PODIUM_H * 0.5 * 5.60 * FacilityStyle.PODIUM_CABLE_R;
      for (e in ends)
        {
          var a = CityConfig.cellToWorld(e.x, e.y);
          var dx = mid.x - a.x, dz = mid.z - a.z;
          var d = Math.sqrt(dx * dx + dz * dz);
          if (d < r)
            continue;
          FacilityCable.strip(e.infoID == SLOT_FULL ? lit : dim, {
            a: [ a.x, FacilityStyle.PODIUM_CABLE_Y, a.z ],
            c: [ mid.x - dx / d * r, FacilityStyle.PODIUM_CABLE_Y, mid.z - dz / d * r ],
            n: [ 0.0, 1.0, 0.0 ],
            side: null,
            bow: FacilityStyle.RIG_CABLE_BOW,
            wave: FacilityStyle.RIG_CABLE_WAVE,
            seed: FacilityModel.mix((e.x * 70001) ^ (e.y * 30011)),
          });
        }
      return {
        dim: mesh(scene, dim, FacilityStyle.RIG_CABLE_GLOW),
        lit: mesh(scene, lit, FacilityStyle.RIG_CABLE_GLOW_LIT),
        t: 0.0,
      };
    }

// one half of the rig as a mesh, or null when that half is empty.
//
// UNLIT, and that is what the emissive on a black Lambert is: a cord that is a LIGHT reads the same
// in the shed's dark corner as it does under a lamp, which is the whole signal. The level is HDR so
// the composer's bloom catches the peak — see FacilityStyle.RIG_CABLE_GLOW
  static function mesh(scene:Scene, b:MeshBuf, glow:Float):Mesh
    {
      if (b.idx.length == 0)
        return null;
      var mat = new MeshLambertMaterial({
        color: 0x000000,
        emissive: FacilityStyle.RIG_CABLE_COL,
        emissiveIntensity: glow,
      });
      var out = new Mesh(FacilityGeom.geom(b), VisionMask.patch(mat));
      out.castShadow = false;
      out.receiveShadow = false;
      scene.add(out);
      return out;
    }

// advance the breath. one sine over both halves: this is ONE circuit, and the ship's own families
// are the thing that disagrees
  public static function tick(r:Rig, dtMs:Float):Void
    {
      if (r == null)
        return;
      r.t += dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
      var k = 0.5 + 0.5 * Math.sin(r.t * FacilityStyle.RIG_CABLE_RATE * 2 * Math.PI);
      var p = FacilityStyle.RIG_CABLE_PULSE;
      if (r.dim != null)
        untyped r.dim.material.emissiveIntensity = FacilityStyle.RIG_CABLE_GLOW * (1 - p + p * k);
      if (r.lit != null)
        untyped r.lit.material.emissiveIntensity = FacilityStyle.RIG_CABLE_GLOW_LIT * (1 - p + p * k);
    }

// and drop it, so a rebuild on an install does not leave the old pair in the scene.
//
// UNPARENTED OFF ITS OWN PARENT and not off the scene it was added to, which is not the same object
// as often as it looks: render.Chunks.build reparents what it finds into per-chunk groups, so a
// mesh built before that pass is no longer the scene's child and scene.remove() is a silent no-op
// (measured — it left the first build's runs in the frame beside the rebuilt ones)
  public static function dispose(scene:Scene, r:Rig):Void
    {
      if (r == null)
        return;
      for (o in [ r.dim, r.lit ])
        if (o != null)
          {
            if (o.parent != null)
              o.parent.remove(o);
            o.geometry.dispose();
            untyped o.material.dispose();
          }
    }
}
