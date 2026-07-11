package render.particles;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;

// fixed pool of K spotlights for street lamps — same discipline as FlameLights/MuzzleLights: created
// once, kept in the scene forever at intensity 0, never added/removed/hidden, so NUM_SPOT_LIGHTS stays
// constant and three never recompiles the lit materials. each frame the K nearest lamps to the player
// claim a light aimed straight down; the rest idle at 0. lets the city place HUNDREDS of lamp posts
// (models + cones are instanced) while only ever paying for K live spotlights
class LampLights {
  var lights:Array<SpotLight> = [];
  var targets:Array<Group> = [];
  var owners:Array<LampPost> = [];        // the lamp each slot currently serves (null = free)
  var intens:Array<Float> = [];           // eased intensity per slot (ramps toward its target)
  var activeList:Array<LampPost> = []; // lamps lit above epsilon this frame (drives fake shadows)
  var bulbY:Float;

  public function new(group:Object3D)
    {
      var L = RenderConfig.LAMP_LIGHT;
      bulbY = CityConfig.CELL * L.yMul;
      // NOTE: never toggle .visible — an invisible spotlight drops out of NUM_SPOT_LIGHTS and forces
      // the very recompile this pool exists to avoid. idle == visible + intensity 0
      for (i in 0...L.pool)
        {
          var t = new Group();
          group.add(t);
          var l = new SpotLight(0xffb866, 0, CityConfig.CELL * 12, L.angle, L.penumbra, 1.6);
          l.target = t;
          group.add(l);
          lights.push(l);
          targets.push(t);
          owners.push(null);
          intens.push(0);
        }
    }

// the lamp spotlights, as plain Object3Ds, for the debug on/off toggles
  public function debugList():Array<Object3D>
    return [for (l in lights) (l : Object3D)];

// the lamps lit this frame — their bulb x/z feed the fake cast-shadow pass
  public inline function active():Array<LampPost>
    return activeList;

// pool slots stick to their lamp and ramp intensity so lamps fade in/out instead of blinking: each
// frame the POOL nearest in-range lamps are "desired"; a slot keeps serving its lamp (target = full)
// until the lamp leaves the desired set (target = 0, fades out), then frees for a new lamp. call once
// per frame before the actor pass
  public function update(lamps:Array<LampPost>, playerCol:Int, playerRow:Int, dtMs:Float):Void
    {
      var L = RenderConfig.LAMP_LIGHT;
      // desired = the pool-nearest in-range lamps, nearest first
      var range2 = L.lightRangeCells * L.lightRangeCells;
      var near:Array<LampPost> = [];
      for (lp in lamps)
        {
          var dc = lp.col - playerCol;
          var dr = lp.row - playerRow;
          if (dc * dc + dr * dr <= range2)
            near.push(lp);
        }
      near.sort(function(a, b)
        {
          var da = (a.col - playerCol) * (a.col - playerCol) + (a.row - playerRow) * (a.row - playerRow);
          var db = (b.col - playerCol) * (b.col - playerCol) + (b.row - playerRow) * (b.row - playerRow);
          return da - db;
        });
      var desired = near.length < lights.length ? near : near.slice(0, lights.length);
      // targets: an owned slot stays lit while its lamp is still desired, else fades out
      var targetI = [for (i in 0...lights.length) (owners[i] != null && desired.indexOf(owners[i]) >= 0) ? L.intensity : 0.0];
      // hand faded-out / free slots to desired lamps that no owner is serving yet (nearest first)
      for (lp in desired)
        {
          var served = false;
          for (o in owners)
            if (o == lp) { served = true; break; }
          if (served)
            continue;
          for (i in 0...lights.length)
            if (intens[i] <= 0.001 && (owners[i] == null || desired.indexOf(owners[i]) < 0))
              {
                owners[i] = lp;
                lights[i].position.set(lp.x, bulbY, lp.z); // teleport while dark — no visible jump
                targets[i].position.set(lp.x, 0, lp.z);    // straight down
                targetI[i] = L.intensity;
                break;
              }
        }
      // ease every slot toward its target and publish the lit lamps
      var step = L.intensity * dtMs * RenderConfig.ANIM_SPEED / (RenderConfig.BASE_MS * L.fadeMul);
      activeList = [];
      for (i in 0...lights.length)
        {
          var tgt = targetI[i];
          if (intens[i] < tgt)
            intens[i] = Math.min(tgt, intens[i] + step);
          else if (intens[i] > tgt)
            intens[i] = Math.max(tgt, intens[i] - step);
          untyped lights[i].intensity = intens[i];
          if (intens[i] <= 0.001)
            owners[i] = null; // fully dark → free for reuse
          else if (owners[i] != null)
            activeList.push(owners[i]);
        }
    }
}
