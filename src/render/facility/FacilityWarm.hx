package render.facility;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;
import render.SceneSetup;
import render.Warmup;
import render.Models.ModelVariant;
import render.world.IndoorMask;
import render.world.VisionMask;

// the facility's warm scene. it gets its OWN for a reason the tunnels' one only half covers: a
// facility DOES have a moon, so the light COUNTS match the city's — what differs is that every lit
// surface out there carries the vision-mask patch, and the mask contributes a customProgramCacheKey.
// so a facility floor warmed as a city ground material warms a key the game never asks for. measured
// before this scene existed: 91 programs at boot, 101 after the first facility entry.
// it sits HERE and not in render.View because everything it does is a mirror of FacilityScene +
// Ground/Geom/Tables/Doors/Glow and FacilityArea's own prop pass — and a mirror that lives in another
// package silently rots when the original moves. run once per session, from render.View.warmKind on
// the first facility entry
class FacilityWarm
{
// build the throwaway compound, wait for every prop glb, then compile
  public static function build(renderer:WebGLRenderer, camera:PerspectiveCamera, lampPool:Int):Dynamic
    {
      var model = FacilityModel.demo();
      // the indoor mask goes over the warm model, for the SAME reason the vision mask makes this scene
      // necessary at all: it contributes a customProgramCacheKey of its own, so a facility wall warmed
      // without it warms a key the game never asks for and every lit surface in there recompiles on
      // the first entry
      var mask = function()
        IndoorMask.attach(FacilityStyle.INDOOR, model.w, model.h,
          function(col, row) return FacilityModel.isInterior(model, col, row));
      mask();
      var bundle = FacilityScene.build(renderer, lampPool);
      var sc = bundle.scene;
      FacilityGround.build(sc, model);
      // the park's two dressing layers, which are TWO program permutations neither of the four ground
      // surfaces covers: the overlay is transparent with an alphaMap, which flips the vision mask to
      // its alpha-scale mode and so to a different customProgramCacheKey, and the tufts carry
      // WildGrass' own wind hook and 'wildGrass' key on top of that. no area behind the demo model,
      // so every marked cell counts as plain lawn and the tufts all land
      FacilityLawn.build(sc, model);
      FacilityGeom.build(sc, model);
      FacilityTables.build(sc, model);
      // the door leaves are an INSTANCED mask-patched lambert, which the merged shell above does not
      // cover: USE_INSTANCING is a program define, so the walls' own program is a different one. no
      // area behind the demo model, so every leaf here is shut and stays that way
      FacilityDoors.build(sc, model, null);
      // the additive glow layer, which is a program permutation of its own on TWO counts: it is
      // vision-mask patched (a customProgramCacheKey) and it carries vertexColors, which three folds
      // into the key as well. the demo model has rooms and windows, so this emits real quads; the
      // MAST heads are absent here because the mast glb has not loaded yet — same material either
      // way, so the program is warmed regardless
      FacilityGlow.build(sc, model);
      // and one lamp cone, for the same reason: a cone is a MeshBasicMaterial with an alphaMap and
      // additive blending, which no other material in this scene is
      render.LightCone.instanced({
        group: sc,
        bulbs: [{ x: 0.0, z: 0.0 }],
        bulbY: FacilityStyle.LAMP_H * FacilityStyle.LAMP_HEAD_Y,
        radius: 1.0,
        topR: RenderConfig.LAMP_CONE.topR,
        color: FacilityStyle.LAMP_COLOR,
      });
      var fx = new Group();
      sc.add(fx);
      new render.particles.MuzzleLights(fx);
      // and off again: the glb callbacks below re-attach around themselves, and nothing else in this
      // process may warm with an indoor swap the area it belongs to does not render with
      IndoorMask.detach();
      // park the moon's shadow box over the compound, so Warmup.compile's render actually runs the
      // shadow depth pass — otherwise the box sits at world origin, the caster falls outside it and
      // the position-only depth programs compile on the first real frame instead. the compound is
      // laid out from -half, so its centre is half a model away from there
      var half = CityConfig.GRID * CityConfig.CELL / 2;
      SceneSetup.fitMoon(bundle.moon, new Vector3(
        model.w * CityConfig.CELL / 2 - half, 0, model.h * CityConfig.CELL / 2 - half));
      return new js.lib.Promise(function(res, _)
        {
          var place = [{ x: 0.0, z: 0.0, yaw: 0.0 }];
          // the park plants, which are the wilderness's own tree and bush glbs — mask-patched here,
          // which is why they cannot ride the city scene
          var green = FacilityGround.GREEN;
          // and the compound's own props — the lamp mast, the park railing, the litter bin and the
          // barrier at the gate. the booth is not among them: it is merged geometry taking the same
          // cladding, roof and lit-window materials the shell already warms
          var facProps = [
            {
              path: RenderConfig.MODELS.facilityLamp,
              h: FacilityStyle.LAMP_H,
            },
            {
              path: RenderConfig.MODELS.facilityFence,
              h: FacilityStyle.FENCE_H,
            },
            {
              path: RenderConfig.MODELS.facilityBin,
              h: FacilityStyle.BIN_H,
            },
            {
              path: RenderConfig.MODELS.facilityBarrier,
              h: FacilityStyle.BARRIER_H,
            },
          ];
          var left = green.length + facProps.length;
          var done = function()
            {
              left--;
              if (left == 0)
                res(null);
            };
          // a prop's glb lands long after the block above put the indoor mask away — and a real
          // facility keeps the mask attached for as long as it is shown, so its own props ARE
          // patched. re-attach around each instance or the warm compiles a key the first entry never
          // asks for. they all stand outdoors and read inAmt 0, so this is about the PROGRAM and not
          // about how they look
          for (i in 0...green.length)
            {
              var p = green[i];
              render.Models.get(p.path, function(_)
                {
                  mask();
                  VisionMask.patchMesh(render.Models.instanced(sc, p.path, place, p.h, SOLID).mesh);
                  IndoorMask.detach();
                  done();
                });
            }
          for (i in 0...facProps.length)
            {
              var p = facProps[i];
              render.Models.get(p.path, function(_)
                {
                  mask();
                  VisionMask.patchMesh(render.Models.instanced(sc, p.path, place, p.h, SOLID).mesh);
                  IndoorMask.detach();
                  done();
                });
            }
        }).then(function(_) return Warmup.compile(renderer, camera, sc));
    }
}
