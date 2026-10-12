package render.military;

import three.Three;
import render.Area3DTickOpts;
import render.Models;
import render.Models.InstancedProp;
import render.Models.PropPlace;
import render.facility.FacilityStyle;
import render.particles.Sprites;
import render.world.VisionMask;

// one stack in the container depot
typedef Stack = {
  // its world box: west, east, north, south and the topmost container's roof
  x0:Float,
  x1:Float,
  z0:Float,
  z1:Float,
  y1:Float,
  // its bottom container's index in the solid batch, and how many stand on it
  first:Int,
  n:Int,
  // the stack again in the GHOST material, drawn only while it fades (null until build)
  ghost:InstancedProp,
  // 0 solid .. 1 see-through
  t:Float,
};

// the depot's container stacks, which stand up to three high (11.6) and hid the player in the lane
// behind them ("high stacks of containers cover player. can we make them transparent?"). They draw
// as one solid batch, and a stack on the camera -> player sightline swaps into its own GHOST twin
// and eases see-through, the street's building fade (render.Occlusion) on that file's slab test. A
// twin PER STACK because a material's opacity is batch-wide and two stacks can be mid-fade at once,
// a player walking a lane handing one over to the next; a twin draws only while its stack fades, so
// a depot nobody stands behind costs the one call it always did. Off the ray and not off cells, so
// an RMB orbit fades whatever then stands in the way
class MilitaryStacks
{
  var solid:InstancedProp;
  var stacks:Array<Stack>;
  var mask:Array<Bool>;

  public function new(scene:Scene, places:Array<PropPlace>, stacks:Array<Stack>)
    {
      var path = RenderConfig.MODELS.militaryContainer;
      this.stacks = stacks;
      solid = Models.instanced(scene, path, places, MilitaryGeom.CONT_H, SOLID);
      mask = [for (_ in places) true];
      for (s in stacks)
        s.ghost = Models.instanced(scene, path, places.slice(s.first, s.first + s.n),
          MilitaryGeom.CONT_H, GHOST);
      // the vision mask on every batch, the twins too, or a stack brightens as it hands over
      Models.get(path, function(_)
        {
          for (p in batches())
            VisionMask.patchMesh(p.mesh);
        });
    }

// the solid batch and every twin, for the moon's count of landed casters (a twin casts, so a stack
// keeps its shadow while it fades)
  public function batches():Array<InstancedProp>
    {
      return [ solid ].concat([for (s in stacks) s.ghost]);
    }

// per frame: test every stack against the camera -> player line, ease each toward its target and
// repack the solid batch round the ones that have left it
  public function tick(opts:Area3DTickOpts, all:Bool):Void
    {
      if (solid.mesh == null)
        return;
      var G = RenderConfig.PROP_GHOST;
      var k = 1 - Math.pow(1 - G.lerp, opts.dtMs / (1000 / 30));
      // the sprite's centre and its top, which leans back off the centre by Sprites.TILT: a stack
      // that covers either covers the player. the fly cam traces nothing, as in the street
      var c = opts.camPos;
      var p = opts.player;
      var r = Sprites.SIZE / 2;
      var midY = p.y + r;
      var topY = midY + r * Math.cos(Sprites.TILT);
      var topZ = p.z - r * Math.sin(Sprites.TILT);
      for (s in stacks)
        {
          var hit = !opts.freeCam &&
            (Occlusion.segHitsBox(c.x, c.y, c.z, p.x, midY, p.z, s.x0, s.x1, s.z0, s.z1, s.y1) ||
            Occlusion.segHitsBox(c.x, c.y, c.z, p.x, topY, topZ, s.x0, s.x1, s.z0, s.z1, s.y1));
          s.t += ((hit ? 1.0 : 0.0) - s.t) * k;
          if (!hit &&
              s.t < G.snap)
            s.t = 0;
          for (i in s.first...s.first + s.n)
            mask[i] = s.t == 0;
          if (s.ghost.mesh == null)
            continue;
          if (s.t == 0)
            {
              s.ghost.mesh.visible = false;
              continue;
            }
          s.ghost.mesh.material.opacity = 1 - s.t * (1 - G.alpha);
          Models.cull(s.ghost, opts.camera, FacilityStyle.PROP_CULL_R, null, all);
        }
      Models.cull(solid, opts.camera, FacilityStyle.PROP_CULL_R, mask, all);
    }
}
