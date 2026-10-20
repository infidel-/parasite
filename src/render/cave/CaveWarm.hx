package render.cave;

import three.Three;
import render.RenderConfig;
import render.Warmup;
import render.Models.ModelVariant;

// the cave's warm scene: the real builders over CaveModel.demo(), so the compiled programs match a real
// cave entry by construction (render.sewer.SewerWarm's reasoning, and its two traps: the muzzle-flash
// point-light pool every real scene gets, and the object props warmed patched — in all three variants,
// the dressing in its one — after their glbs have landed). run once per session from render.View.warmKind on the first cave entry
class CaveWarm
{
// build the throwaway cave, wait for every prop glb, then compile
  public static function build(renderer:WebGLRenderer, camera:PerspectiveCamera, lampPool:Int):Dynamic
    {
      var model = CaveModel.demo();
      var sc = CaveScene.build(renderer, model, lampPool).scene;
      CaveGeom.build(sc, model);
      var fx = new Group();
      sc.add(fx);
      new render.particles.MuzzleLights(fx);
      return new js.lib.Promise(function(res, _)
        {
          var place = [{ x: 0.0, z: 0.0, yaw: 0.0 }];
          var C = RenderConfig.OBJMARK;
          var objModels = [for (m in render.world.ObjModels.MODELS) if (m.unmasked != true) m];
          var wallProps = CaveStyle.PROP_MODELS;
          var left = objModels.length + wallProps.length;
          var done = function()
            {
              left--;
              if (left == 0)
                res(null);
            };
          for (i in 0...objModels.length)
            {
              var m = objModels[i];
              render.Models.get(m.path, function(_)
                {
                  render.world.ObjModels.patchRow(m,
                    render.Models.instanced(sc, m.path, place, m.h, SOLID).mesh,
                    render.Models.instanced(sc, m.path, place, m.h, GHOST).mesh,
                    render.Models.instanced(sc, m.path, place, m.h, HULL(C.color, C.hullW)).mesh);
                  done();
                });
            }
          // the dressing (render.cave.CaveProps): decoration, so the SOLID variant only, patched as
          // the real build patches it
          for (i in 0...wallProps.length)
            {
              var p = wallProps[i];
              render.Models.get(p.path, function(_)
                {
                  render.world.VisionMask.patchMesh(render.Models.instanced(sc, p.path, place, p.h,
                    SOLID).mesh);
                  done();
                });
            }
        }).then(function(_) return Warmup.compile(renderer, camera, sc));
    }
}
