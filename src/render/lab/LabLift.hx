package render.lab;

import three.Three;
import citygen.CityConfig;
import render.Area3DTickOpts;
import render.Models;
import render.RenderConfig;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.VisionMask;

// the freight lift the lab is reached by: its fixed shaft and the car that comes down it. The 2x2 of
// lift cells is found off the model (Surf.LIFT), not the objects.Elevator parts, so the warm's demo
// plate gets one too.
//
// THE CAR COMES DOWN ON ARRIVAL. A build starts it LabStyle.LIFT_DROP up the shaft and lowers it
// over BASE_MS * LIFT_MULT, eased in and out; render.world.WorldCtx.ground answers its deck for the
// lift cells (LabLift.ground), so whoever stands on it rides down with it rather than waiting on the
// floor for it.
//
// AND IT GOES BACK UP ON DEPARTURE. objects.Elevator hands its leave to depart (through
// render.View.liftDepart), and the car climbs the same eased LIFT_DROP with the player on it before
// the area is left, the view's zoom-in outro then playing over it at the top
typedef LabLiftSet = {
  deck:Models.InstancedProp,
  shaft:Models.InstancedProp,
  col:Int,                    // the 2x2's north-west cell, or -1 when the plate has no lift
  row:Int,
  x:Float,                    // the 2x2's centre in world
  z:Float,
  t:Float,                    // the descent, 0 at the top of the shaft to 1 landed
  y:Float,                    // the car's height this frame
  up:Void->Void,              // the leave the departure hands off to once the car is at the top; set
                              // for good by depart (the area is left), null until then
};

class LabLift
{
  static inline var CELL = CityConfig.CELL;

// the shaft and the car over the model's lift cells, the car up the shaft
  public static function build(scene:Scene, m:Facility):LabLiftSet
    {
      var col = -1, row = -1;
      for (r in 0...m.h)
        for (c in 0...m.w)
          if (col < 0 &&
              m.surf[r][c] == Surf.LIFT)
            {
              col = c;
              row = r;
            }
      var c = CityConfig.cellToWorld(col, row);
      var set:LabLiftSet = {
        deck: null,
        shaft: null,
        col: col,
        row: row,
        x: c.x + CELL / 2,
        z: c.z + CELL / 2,
        t: 0.0,
        y: LabStyle.LIFT_DROP,
        up: null,
      };
      var places:Array<Models.PropPlace> = (col < 0 ? [] : [{
        x: set.x,
        z: set.z,
        yaw: 0.0,
      }]);
      set.shaft = batch(scene, RenderConfig.MODELS.labLiftShaft, places, LabStyle.LIFT_SHAFT_H);
      // the car up the shaft; Models.instanced stood it on the floor
      places = [for (p in places) {
        x: p.x,
        z: p.z,
        yaw: p.yaw,
        y: LabStyle.LIFT_DROP,
      }];
      set.deck = batch(scene, RenderConfig.MODELS.labLiftDeck, places, LabStyle.LIFT_DECK_GLB_H);
      return set;
    }

// the shaft and the car at the origin, for render.lab.LabWarm — its demo plate has no lift cells.
// Returns the paths to wait on
  public static function warm(scene:Scene):Array<String>
    {
      var at:Array<Models.PropPlace> = [{
        x: 0.0,
        z: 0.0,
        yaw: 0.0,
      }];
      batch(scene, RenderConfig.MODELS.labLiftShaft, at, LabStyle.LIFT_SHAFT_H);
      batch(scene, RenderConfig.MODELS.labLiftDeck, at, LabStyle.LIFT_DECK_GLB_H);
      return [
        RenderConfig.MODELS.labLiftShaft,
        RenderConfig.MODELS.labLiftDeck,
      ];
    }

// one batch under the vision mask
  static function batch(scene:Scene, path:String, places:Array<Models.PropPlace>,
      h:Float):Models.InstancedProp
    {
      var p = Models.instanced(scene, path, places, h, SOLID);
      if (places.length > 0)
        Models.get(path, function(_)
          {
            VisionMask.patchMesh(p.mesh);
          });
      return p;
    }

// what render.world.WorldCtx.ground answers: the car's deck over the lift cells, the floor elsewhere
  public static function ground(set:LabLiftSet, x:Float, z:Float):Float
    {
      if (set.col < 0 ||
          Math.abs(x - set.x) > CELL ||
          Math.abs(z - set.z) > CELL)
        return 0.0;
      return set.y + LabStyle.LIFT_DECK_H;
    }

// carry the player back up the shaft and run `leave` once the car is at the top; a car still held up
// there (the arrival waiting on a window) leaves at once
  public static function depart(set:LabLiftSet, leave:Void->Void):Void
    {
      set.up = leave;
      if (set.t == 0)
        haxe.Timer.delay(leave, 0);
    }

// the descent or the departure, and the culls. `held` keeps the car at the top while a window is up:
// the entry's own message boxes open on the frame the area does, and a descent behind one is never
// seen. A departure runs regardless, the player having asked for it
  public static function tick(set:LabLiftSet, opts:Area3DTickOpts, held:Bool):Void
    {
      if (set.deck.mesh == null)
        return;
      var step = opts.dtMs * RenderConfig.ANIM_SPEED / (RenderConfig.BASE_MS * LabStyle.LIFT_MULT);
      if (set.up != null &&
          set.t > 0)
        {
          set.t = Math.max(0.0, set.t - step);
          pose(set);
          // out of the frame: the leave despawns the area this tick is still reading
          if (set.t == 0)
            haxe.Timer.delay(set.up, 0);
        }
      else if (set.up == null &&
          set.t < 1 &&
          !held)
        {
          set.t = Math.min(1.0, set.t + step);
          pose(set);
        }
      Models.cull(set.deck, opts.camera, LabStyle.LIFT_CULL_R);
      Models.cull(set.shaft, opts.camera, LabStyle.LIFT_CULL_R);
    }

// the car at its eased height off t
  static function pose(set:LabLiftSet):Void
    {
      var e = set.t * set.t * (3 - 2 * set.t);
      set.y = LabStyle.LIFT_DROP * (1 - e);
      set.deck.matrices[0].elements[13] = set.y;
    }

// drop the batches; their materials are the shared templates'
  public static function dispose(set:LabLiftSet):Void
    {
      for (p in [ set.deck, set.shaft ])
        if (p.mesh != null)
          p.mesh.removeFromParent();
    }
}
