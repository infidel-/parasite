package render.lab;

import three.Three;
import citygen.CityConfig;
import gen.blocks.LabBlocks;
import render.Area3DTickOpts;
import render.Models;
import render.RenderConfig;
import render.facility.FacilityModel.Facility;
import render.particles.LampPost;

// what LabSpin turns: its two lamps (null where the plate has no lift or no workshop), the beacon's
// reflector and dome, and the fan's rotor batch
typedef LabSpinSet = {
  beacon:LampPost,              // the lift's amber beacon, its beam turning with its reflector
  reflector:Models.InstancedProp, // the beacon's mirror inside its dome, turned to face the beam
  dome:Models.InstancedProp,    // its amber glass over the reflector
  reflBase:Matrix4,             // the reflector's placement before its turn, taken once its glb lands
  lamp:LampPost,                // the work lamp over the workshop fan, pooled straight down
  body:Models.InstancedProp,    // the fan's canopy, rod and housing
  rotor:Models.InstancedProp,   // its blades, turned every frame
  base:Matrix4,                 // the rotor's placement before its turn, taken once its glb lands
  beaconAt:{ x:Float, z:Float },
  turn:Float,                   // the beacon's sweep and the rotor's turn, in turns
};

// the lab's two MOVING LIGHTS, for the shadows they throw across its walls and floor: the freight
// lift's beacon hung under the head frame, its reflector turning in its glass dome and its beam
// round the lobby with it, and a ceiling fan in the workshop turning under a work lamp, whose blades
// sweep the room below.
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
        reflector: null,
        dome: null,
        reflBase: null,
        lamp: null,
        body: null,
        rotor: null,
        base: null,
        beaconAt: null,
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
          set.beacon = post(set.beaconAt.x, set.beaconAt.z, LabStyle.SPIN_BEACON_Y,
            LabStyle.SPIN_BEACON_COLOR, LabStyle.SPIN_BEACON_MUL);
          set.beacon.beam = LabStyle.SPIN_BEACON_REACH;
          posts.push(set.beacon);
          set.reflector = Models.instanced(scene, RenderConfig.MODELS.labLiftBeacon, [{
            x: set.beaconAt.x,
            z: set.beaconAt.z,
            yaw: 0.0,
            y: LabStyle.SPIN_REFLECTOR_Y,
          }], LabStyle.SPIN_REFLECTOR_H, SOLID);
          set.dome = Models.instanced(scene, RenderConfig.MODELS.labLiftDome, [{
            x: set.beaconAt.x,
            z: set.beaconAt.z,
            yaw: 0.0,
            y: LabStyle.SPIN_DOME_Y,
          }], LabStyle.SPIN_DOME_H, SOLID);
          // neither casts: both hang round the bulb, and their shadow would be the beam's whole pool
          patch(RenderConfig.MODELS.labLiftBeacon, set.reflector, false);
          patch(RenderConfig.MODELS.labLiftDome, set.dome, false);
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

// the fan and the beacon's parts at the origin, for render.lab.LabWarm. Returns the paths to wait on
  public static function warm(scene:Scene):Array<String>
    {
      var paths = [
        RenderConfig.MODELS.labFan,
        RenderConfig.MODELS.labFanBlades,
        RenderConfig.MODELS.labLiftBeacon,
        RenderConfig.MODELS.labLiftDome,
      ];
      for (path in paths)
        patch(path, Models.instanced(scene, path, [{
          x: 0.0,
          z: 0.0,
          yaw: 0.0,
        }], 1.0, SOLID), true);
      return paths;
    }

// per frame: the beam swung and the rotor turned, both posts in the alarm's red while it is up, and
// the work lamp dimmed with the lab (the beacon is on the alarm's battery)
  public static function tick(set:LabSpinSet, opts:Area3DTickOpts, alarmed:Bool, dead:Float):Void
    {
      set.turn += opts.dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
      if (set.beacon != null)
        {
          // the beam goes where the reflector faces, round the full turn, dark while that is the wall
          var a = set.turn * LabStyle.SPIN_BEACON_RATE * Math.PI * 2;
          var face = Math.cos(a);
          set.beacon.tx = set.beaconAt.x + Math.sin(a) * LabStyle.SPIN_BEACON_OUT;
          set.beacon.tz = set.beaconAt.z + face * LabStyle.SPIN_BEACON_OUT;
          set.beacon.mul = LabStyle.SPIN_BEACON_MUL * Math.max(0.0, Math.min(1.0,
            (face + LabStyle.SPIN_BEACON_DARK) / LabStyle.SPIN_BEACON_FADE));
          set.beacon.color = (alarmed ? LabStyle.LAMP_ALARM : LabStyle.SPIN_BEACON_COLOR);
          beacon(set, a, alarmed);
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

// the reflector turned `a` round (its open side, the glb's front, faces +z at none), and the dome
// glowing the beam's colour
  static function beacon(set:LabSpinSet, a:Float, alarmed:Bool):Void
    {
      var p = set.reflector;
      if (p.mesh == null ||
          set.dome.mesh == null)
        return;
      if (set.reflBase == null)
        set.reflBase = p.matrices[0].clone();
      _r.makeRotationY(a);
      p.mesh.setMatrixAt(0, p.matrices[0].copy(set.reflBase).multiply(_r));
      untyped p.mesh.instanceMatrix.needsUpdate = true;
      // Dynamic: the dome's loaded Lambert, typed Material by the extern; emissive is its uniform
      var mat:Dynamic = set.dome.mesh.material;
      mat.emissive.setHex(alarmed ? LabStyle.LAMP_ALARM : LabStyle.SPIN_BEACON_COLOR);
      mat.emissive.multiplyScalar(LabStyle.SPIN_DOME_GLOW);
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

// a fan or beacon batch under the vision mask, casting or not; the dome as glass, the same treatment
// the lab's machines' shells take (LabInterior.glass), so it draws on their program
  static function patch(path:String, p:Models.InstancedProp, casts:Bool):Void
    {
      Models.get(path, function(_)
        {
          if (path == RenderConfig.MODELS.labLiftDome)
            LabInterior.glass(p.mesh.material);
          render.world.VisionMask.patchMesh(p.mesh);
          p.mesh.castShadow = casts;
        });
    }
}
