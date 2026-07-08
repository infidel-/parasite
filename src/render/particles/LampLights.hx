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
  var activeList:Array<LampPost> = []; // lamps that got a live light this frame (drives fake shadows)
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
        }
    }

// the lamp spotlights, as plain Object3Ds, for the debug on/off toggles
  public function debugList():Array<Object3D>
    return [for (l in lights) (l : Object3D)];

// the lamps lit this frame — their bulb x/z feed the fake cast-shadow pass
  public inline function active():Array<LampPost>
    return activeList;

// park a pool light (aimed straight down) on each of the nearest lamps to the player within range;
// every other pool light idles at intensity 0. call once per frame before the actor pass
  public function update(lamps:Array<LampPost>, playerCol:Int, playerRow:Int):Void
    {
      var L = RenderConfig.LAMP_LIGHT;
      for (l in lights)
        untyped l.intensity = 0;
      activeList = [];
      if (lamps.length == 0)
        return;
      // lamps within range, nearest the player first, capped to the pool size (cell distance)
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
      var n = near.length < lights.length ? near.length : lights.length;
      for (i in 0...n)
        {
          var lp = near[i];
          lights[i].position.set(lp.x, bulbY, lp.z);
          targets[i].position.set(lp.x, 0, lp.z); // straight down
          untyped lights[i].intensity = L.intensity;
          activeList.push(lp);
        }
    }
}
