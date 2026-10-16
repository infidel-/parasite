package render.lab;

import three.Three;
import citygen.CityConfig;
import gen.blocks.LabBlocks;
import render.Area3DTickOpts;
import render.Models;
import render.RenderConfig;
import render.facility.FacilityModel.Facility;
import render.particles.LampPost;

// what LabSpin turns: its two lamps (null where the plate has no lift or no workshop) and the fan's
// rotor batch
typedef LabSpinSet = {
  beacon:LampPost,              // the lift's amber beacon, its beam swinging round the shaft
  lamp:LampPost,                // the work lamp over the workshop fan, pooled straight down
  body:Models.InstancedProp,    // the fan's canopy, rod and housing
  rotor:Models.InstancedProp,   // its blades, turned every frame
  base:Matrix4,                 // the rotor's placement before its turn, taken once its glb lands
  beaconAt:{ x:Float, z:Float },
  sweepAt:{ x:Float, z:Float },  // the floor point the beam's pool circles: out in the lobby, so the
                                 // beam rakes the room and not the bedrock over the shaft's walls
  turn:Float,                   // the beacon's sweep and the rotor's turn, in turns
};

// the lab's two MOVING LIGHTS, for the shadows they throw across its walls and floor: the freight
// lift's beacon on the head frame, swinging its beam round the lobby, and a ceiling fan in the
// workshop turning under a work lamp, whose blades sweep the room below.
//
// THEY ARE POSTS IN THE SHARED POOL, NOT LIGHTS OF THEIR OWN. The lab matches the sewer's light
// counts so it shares every shared material's program (LabScene's note); two more shadow-casting
// SpotLights would have recompiled all of them for the lab alone. A post with `moving` set is served
// by one of the pool's caster slots like any casting post, and the pool re-renders that slot's map
// every frame it serves it (render.particles.LampLights) — the only map that has to, since only its
// light or what it lights moves.
//
// WHAT CASTS: the lift's shaft and car (Models.instanced's default) and the lab's furniture
// (LabInterior.batch). The clock is BASE_MS turns of ANIM_SPEED, the rates per BASE_MS in LabStyle
class LabSpin
{
  static inline var CELL = CityConfig.CELL;
  static var _r = new Matrix4();

// both spinners off the model and the lift; their posts pushed onto `posts`
  public static function build(scene:Scene, m:Facility, lift:LabLift.LabLiftSet,
      posts:Array<LampPost>):LabSpinSet
    {
      var set:LabSpinSet = {
        beacon: null,
        lamp: null,
        body: null,
        rotor: null,
        base: null,
        beaconAt: null,
        sweepAt: null,
        turn: 0.0,
      };
      // the beacon: on the head frame's back girder end (models-src/lab/mach/liftshaft.py), in the
      // shaft glb's own frame, which Models.normalize centres on the 2x2
      if (lift.col >= 0)
        {
          set.beaconAt = {
            x: lift.x + LabStyle.SPIN_BEACON_X,
            z: lift.z + LabStyle.SPIN_BEACON_Z,
          };
          set.sweepAt = {
            x: lift.x + LabStyle.SPIN_SWEEP_X,
            z: lift.z + LabStyle.SPIN_SWEEP_Z,
          };
          set.beacon = post(set.beaconAt.x, set.beaconAt.z, LabStyle.SPIN_BEACON_Y,
            LabStyle.SPIN_BEACON_COLOR, LabStyle.SPIN_BEACON_MUL);
          set.beacon.beam = LabStyle.SPIN_BEACON_REACH;
          posts.push(set.beacon);
        }
      // the fan: over the middle of the biggest workshop
      var best = null;
      for (r in m.rooms)
        if (r.role == LabBlocks.ROLE_WORKSHOP &&
            (best == null || r.w * r.h > best.w * best.h))
          best = r;
      if (best == null)
        return set;
      var a = CityConfig.cellToWorld(best.x1, best.y1);
      var b = CityConfig.cellToWorld(best.x2, best.y2);
      var x = (a.x + b.x) / 2, z = (a.z + b.z) / 2;
      set.lamp = post(x, z, LabStyle.FAN_Y + LabStyle.FAN_LAMP_UP, LabStyle.LAMP_WORKSHOP,
        LabStyle.FAN_LAMP_MUL);
      posts.push(set.lamp);
      set.rotor = Models.instanced(scene, RenderConfig.MODELS.labFanBlades, [{
        x: x,
        z: z,
        yaw: 0.0,
        y: LabStyle.FAN_Y,
      }], LabStyle.FAN_BLADES_H, SOLID);
      set.body = Models.instanced(scene, RenderConfig.MODELS.labFan, [{
        x: x,
        z: z,
        yaw: 0.0,
        y: LabStyle.FAN_Y + LabStyle.FAN_BLADES_H,
      }], LabStyle.FAN_BODY_H, SOLID);
      // only the rotor casts: the housing hangs straight under the lamp and its shadow, ten times
      // its size at the floor, swallowed the whole pool the blades are meant to sweep
      patch(RenderConfig.MODELS.labFan, set.body, false);
      patch(RenderConfig.MODELS.labFanBlades, set.rotor, true);
      return set;
    }

// the fan at the origin, for render.lab.LabWarm. Returns the paths to wait on
  public static function warm(scene:Scene):Array<String>
    {
      for (path in [ RenderConfig.MODELS.labFan, RenderConfig.MODELS.labFanBlades ])
        patch(path, Models.instanced(scene, path, [{
          x: 0.0,
          z: 0.0,
          yaw: 0.0,
        }], 1.0, SOLID), true);
      return [ RenderConfig.MODELS.labFan, RenderConfig.MODELS.labFanBlades ];
    }

// per frame: the beam swung and the rotor turned, both posts in the alarm's red while it is up, and
// the work lamp dimmed with the lab (the beacon is on the alarm's battery)
  public static function tick(set:LabSpinSet, opts:Area3DTickOpts, alarmed:Bool, dead:Float):Void
    {
      set.turn += opts.dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
      if (set.beacon != null)
        {
          var t = set.turn * LabStyle.SPIN_BEACON_RATE * Math.PI * 2;
          set.beacon.tx = set.sweepAt.x + Math.cos(t) * LabStyle.SPIN_BEACON_AIM;
          set.beacon.tz = set.sweepAt.z + Math.sin(t) * LabStyle.SPIN_BEACON_AIM;
          set.beacon.color = (alarmed ? LabStyle.LAMP_ALARM : LabStyle.SPIN_BEACON_COLOR);
        }
      if (set.lamp == null)
        return;
      set.lamp.color = (alarmed ? LabStyle.LAMP_ALARM : LabStyle.LAMP_WORKSHOP);
      set.lamp.mul = LabStyle.FAN_LAMP_MUL * (1 - dead * (1 - LabStyle.DEAD_DIM));
      var p = set.rotor;
      if (p.mesh == null)
        return;
      if (set.base == null)
        set.base = p.matrices[0].clone();
      // the fan slows to a stop as the lab's power goes
      _r.makeRotationY(set.turn * LabStyle.FAN_RATE * (1 - dead) * Math.PI * 2);
      p.mesh.setMatrixAt(0, p.matrices[0].copy(set.base).multiply(_r));
      untyped p.mesh.instanceMatrix.needsUpdate = true;
    }

// a moving, casting post
  static function post(x:Float, z:Float, y:Float, color:Int, mul:Float):LampPost
    {
      return {
        x: x,
        z: z,
        y: y,
        tx: x,
        tz: z,
        color: color,
        col: CityConfig.worldToCell(x, z).col,
        row: CityConfig.worldToCell(x, z).row,
        phase: 0.0,
        flick: 1.0,
        mul: mul,
        moving: true,
      };
    }

// a fan batch under the vision mask, casting or not
  static function patch(path:String, p:Models.InstancedProp, casts:Bool):Void
    {
      Models.get(path, function(_)
        {
          render.world.VisionMask.patchMesh(p.mesh);
          p.mesh.castShadow = casts;
        });
    }
}
