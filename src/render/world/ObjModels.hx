package render.world;

import three.Three;
import citygen.CityConfig;
import game.Game;
import render.Models;
import render.RenderConfig;

// area objects that render as a real 3D prop instead of their atlas sprite. the mapping lives here,
// in the render layer, keyed on the object TYPE — objects.AreaObject knows nothing about glbs, the
// same way it knows nothing about which texture its sprite comes from.
//
// props are placed once at area build (these objects never move) and instanced per model path, so a
// level pays one draw call per distinct prop however many of them stand in it. render.Actors asks
// modelFor() and paints the object's marks WITHOUT its icon quad, so the teal tactical ring and the
// through-wall silhouette still find the object while the prop takes over its body
class ObjModels
{
// the baked glb an object type draws as, or null for the ordinary sprite path
  public static function modelFor(type:String):String
    {
      return switch (type)
        {
          case 'sewer_exit', 'habitat_exit': RenderConfig.MODELS.sewerExit;
          default: null;
        };
    }

// place every prop-backed object in the area, grouped per model path. `yaw` decides which way a prop
// faces from its cell (a ladder wants its back to a wall); the area kind owns that rule, because only
// it knows what is solid
  public static function build(scene:Scene, game:Game, targetH:Float, yaw:Int->Int->Float):Void
    {
      var byPath:Map<String, Array<{ x:Float, z:Float, yaw:Float }>> = new Map();
      for (o in game.area.getObjects())
        {
          var path = modelFor(o.type);
          if (path == null)
            continue;
          if (!byPath.exists(path))
            byPath.set(path, []);
          var w = CityConfig.cellToWorld(o.x, o.y);
          byPath.get(path).push({ x: w.x, z: w.z, yaw: yaw(o.x, o.y) });
        }
      for (path => places in byPath)
        Models.instanced(scene, path, places, targetH);
    }
}
