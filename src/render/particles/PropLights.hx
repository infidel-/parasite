package render.particles;

import three.Three;
import citygen.CityConfig;
import game.Game;
import objects.AreaObject;
import render.RenderConfig;
import render.world.ObjModels;

// a fixed pool of COLOURED point lights for the object props that glow — the habitat's grown organs.
// same discipline as FlameLights/MuzzleLights/LampLights: created once, kept in the scene forever at
// intensity 0, never added/removed/hidden, so NUM_POINT_LIGHTS stays constant and three never
// recompiles the lit materials. each frame the nearest lighting props to the player claim a slot and
// the rest idle at 0, which is what lets a habitat grow any number of organs while only ever paying
// for RenderConfig.PROP_LIGHT.pool live lights.
//
// TWO things it deliberately does not do. It casts NO SHADOW — a point shadow is six cube faces per
// light, and the pool would cost more than every other shadow in the frame put together; reach
// (PROP_LIGHT.distCells) plus the vision mask are what keep an organ from lighting the corridor behind
// its wall. And it holds NO per-area state: update() walks the area's objects itself, so an organ grown
// under the player lights up on the frame it appears with no rebuild hook, and one destroyed fades out
// because it simply stops being found.
//
// colour and relative brightness come from the prop's own row in ObjModels.MODELS, not from here —
// this class knows about "props that light", never about which prop is which
class PropLights {
  var lights:Array<PointLight> = [];
  var owners:Array<AreaObject> = []; // the object each slot serves (null = free)
  var intens:Array<Float> = [];      // eased 0..1 claim level per slot, NOT the published intensity

  public function new(group:Object3D)
    {
      var P = RenderConfig.PROP_LIGHT;
      // NOTE: never toggle .visible — an invisible light drops out of NUM_POINT_LIGHTS and forces the
      // very recompile this fixed pool exists to avoid. idle == visible + intensity 0
      for (i in 0...P.pool)
        {
          // the seed colour only matters until a slot has an owner: update() republishes the owning
          // prop's tint every frame, and a light colour is a plain uniform, not part of the program key
          var l = new PointLight(0xffffff, 0, CityConfig.CELL * P.distCells, P.decay);
          group.add(l);
          lights.push(l);
          owners.push(null);
          intens.push(0);
        }
    }

// the pool as plain Object3Ds, for the debug light toggles (keys 5 and 0)
  public function debugList():Array<Object3D>
    return [for (l in lights) (l : Object3D)];

// park a pool light on each of the nearest lighting props to the player, easing so one entering or
// leaving the claim set fades instead of blinking. call once per frame from the area kind's tick
  public function update(game:Game, playerCol:Int, playerRow:Int, dtMs:Float):Void
    {
      // pool 0 turns the whole feature off (RenderConfig.PROP_LIGHT.pool) — take the object walk and
      // the sort out with it rather than running them to fill nothing
      if (lights.length == 0)
        return;
      var P = RenderConfig.PROP_LIGHT;
      // squared cell distance player->prop, shared by the in-range filter and the nearest-first order
      function d2(o:AreaObject):Int
        {
          var dc = o.x - playerCol;
          var dr = o.y - playerRow;
          return dc * dc + dr * dr;
        }
      // the in-range lighting props. walked from the area every frame rather than cached at area build:
      // the list is a handful of objects, render.Actors already asks modelFor() about every one of them
      // on the same frame, and caching it would need an invalidation hook on add/remove
      var range2 = Std.int(P.rangeCells * P.rangeCells);
      var near:Array<AreaObject> = [];
      for (o in game.area.getObjects())
        {
          var m = ObjModels.modelFor(o.getModelKey());
          if (m == null ||
              m.light == null)
            continue;
          if (d2(o) <= range2)
            near.push(o);
        }
      near.sort(function(a, b) return d2(a) - d2(b));
      var desired = near.length < lights.length ? near : near.slice(0, lights.length);
      // free a slot only once it has FADED OUT, so its light is never yanked off a prop mid-fade
      for (i in 0...lights.length)
        if (owners[i] != null &&
            intens[i] <= 0.001 &&
            desired.indexOf(owners[i]) < 0)
          owners[i] = null;
      // hand free slots to desired props nobody is serving yet, nearest first
      for (o in desired)
        {
          if (owners.indexOf(o) >= 0)
            continue;
          for (i in 0...lights.length)
            if (owners[i] == null)
              {
                owners[i] = o;
                break;
              }
        }
      var step = dtMs * RenderConfig.ANIM_SPEED / (RenderConfig.BASE_MS * P.fadeMul);
      for (i in 0...lights.length)
        {
          var o = owners[i];
          var tgt = (o != null && desired.indexOf(o) >= 0) ? 1.0 : 0.0;
          if (intens[i] < tgt)
            intens[i] = Math.min(tgt, intens[i] + step);
          else if (intens[i] > tgt)
            intens[i] = Math.max(tgt, intens[i] - step);
          if (o == null)
            {
              untyped lights[i].intensity = 0;
              continue;
            }
          // published fresh every frame: the prop's height decides the light height, so a table tweak
          // to `h` moves the light with the model instead of leaving it buried or floating
          var m = ObjModels.modelFor(o.getModelKey());
          var w = CityConfig.cellToWorld(o.x, o.y);
          lights[i].position.set(w.x, render.world.WorldCtx.floorY(o.x, o.y) + m.h * P.yMul, w.z);
          lights[i].color.setHex(m.light.color);
          untyped lights[i].intensity = P.intensity * m.light.mul * intens[i];
        }
    }
}
