package render.sewer;

import three.Three;
import render.RenderConfig;
import render.Warmup;
import render.Models.ModelVariant;
import render.world.VisionMask;

// the tunnels' warm scene. the tunnels get their OWN, NOT a corner of the city's: a sewer has no
// directional light at all, and NUM_DIR_LIGHTS / NUM_DIR_LIGHT_SHADOWS are part of every lit
// material's program key — so wall/floor/ledge warmed under the city's moon compile the wrong variant
// and recompile on the first real entry anyway (measured: 4 programs). real builders again, so the
// match is by construction rather than by bookkeeping.
// it sits HERE and not in render.View because everything it does is a mirror of SewerScene + SewerGeom
// + SewerArea's own prop pass — and a mirror that lives in another package silently rots when the
// original moves. run once per session, from render.View.warmKind on the first tunnel entry
class SewerWarm
{
// build the throwaway tunnel, wait for every prop glb, then compile
  public static function build(renderer:WebGLRenderer, camera:PerspectiveCamera, lampPool:Int):Dynamic
    {
      var model = SewerModel.demo();
      var sc = SewerScene.build(renderer, model, lampPool).scene;
      SewerGeom.build(sc, model);
      // and the muzzle-flash point-light pool, for the SAME reason the city warm scene parks one:
      // Actors adds it to every real scene, tunnels included, and NUM_POINT_LIGHTS is in every lit
      // material's program key. without it the whole shell warms at 0 point lights and recompiles at
      // 5 on the first entry — measured by diffing __progs() around a sewer entry, where every added
      // lambert/basic key differed from its warmed twin in that one field
      var fx = new Group();
      sc.add(fx);
      new render.particles.MuzzleLights(fx);
      // every tunnel prop's glb arrives over an async load, so the compile has to WAIT for them:
      // instanced after compileAsync had already walked the scene they would miss the warm entirely
      // and compile their PBR programs on the first real tunnel entry. the shared `left` counter is
      // what holds the compile back until the whole set has landed
      return new js.lib.Promise(function(res, _)
        {
          var place = [{ x: 0.0, z: 0.0, yaw: 0.0 }];
          var C = RenderConfig.OBJMARK;
          // patched exactly as the tunnel builders patch their own: the vision mask carries a
          // customProgramCacheKey, so a prop warmed UNPATCHED warms a program the game never uses
          // and recompiles on the first tunnel entry. it bites the SOLID variant hardest, which
          // reuses the glb template's own shared material — the very object the real build then
          // patches (render.sewer.SewerProps)
          var objModels = render.world.ObjModels.MODELS;
          var wallProps = SewerStyle.PROP_MODELS;
          var left = objModels.length + wallProps.length;
          var done = function()
            {
              left--;
              if (left == 0)
                res(null);
            };
          // the object-backed props (exit ladders, the habitat's grown objects) in all THREE
          // variants — `transparent` and BackSide are both folded into three's program cache key, so
          // the ghost and the outline hull each compile a program of their own, and without this
          // they would compile on the first step onto a prop / the first tactical toggle
          for (i in 0...objModels.length)
            {
              var m = objModels[i];
              render.Models.get(m.path, function(_)
                {
                  // patched through render.world.ObjModels.patchRow, the same call
                  // render.sewer.SewerArea's per-frame pass makes — the chain extends the material's
                  // program cache key, so a warm that ordered it differently would warm a key the
                  // game never asks for. a row with no `anim` is a no-op and keeps the plain program
                  render.world.ObjModels.patchRow(m,
                    render.Models.instanced(sc, m.path, place, m.h, SOLID).mesh,
                    render.Models.instanced(sc, m.path, place, m.h, GHOST).mesh,
                    render.Models.instanced(sc, m.path, place, m.h, HULL(C.color, C.hullW)).mesh);
                  done();
                });
            }
          // the wall props have the same trap, but only ONE variant each: they are decoration, so no
          // ghost and no hull
          for (i in 0...wallProps.length)
            {
              var p = wallProps[i];
              render.Models.get(p.path, function(_)
                {
                  VisionMask.patchMesh(render.Models.instanced(sc, p.path, place, p.h, SOLID).mesh);
                  done();
                });
            }
        }).then(function(_) return Warmup.compile(renderer, camera, sc));
    }
}
