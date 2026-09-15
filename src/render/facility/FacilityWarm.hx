package render.facility;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;
import render.SceneSetup;
import render.Warmup;
import render.Models.ModelVariant;
import render.world.ContactMask;
import render.world.IndoorMask;
import render.world.MeshBuf.MeshBufTools;
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
      // the first entry. the CONTACT mask rides along with it and for the same reason one step
      // further in: it contributes a SECOND key and only the three interior FLOORS carry it, so
      // warming without it warms a floor key the game never asks for and leaves the one it does ask
      // for to compile on the frame the player walks in
      var masonry = FacilityDetail.masonry(model);
      var mask = function()
        {
          IndoorMask.attach(FacilityStyle.INDOOR, model.w, model.h,
            function(col, row) return FacilityModel.isInterior(model, col, row));
          ContactMask.attach(FacilityStyle.CONTACT, model.w, model.h, masonry.solid, masonry.holes);
        }
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
      // and the bench sinks, which are a program permutation NEITHER bench material covers: the sheet
      // is alpha-cut, and three defines USE_ALPHATEST off `alphaTest > 0`, so a mapped lambert with a
      // cut is a different program from the two mapped lamberts above it. the demo model's two bench
      // blocks are undecorated, so both find a free edge cell and this really does emit — which is
      // the whole reason the pass reads `m.table` and not `m.rooms`, that list being empty here
      FacilitySink.build(sc, model);
      // and the worktop clutter. NOT a new program permutation — it is the same mapped lambert with
      // the same alphaTest and the same DoubleSide as the sink above, so three hands back the cached
      // program. It is here for the TEXTURE: a 1024 sheet decoded and uploaded on first area entry is
      // a hitch whether or not anything had to compile. The demo model's two bench blocks take a sink
      // each and have cells left over, so this really does emit
      FacilityClutter.build(sc, model);
      // the room furniture, which is TWO program permutations the shell above does not cover — the
      // three families share one lambert but the shelving's is DOUBLE_SIDED, which three folds into
      // the program key — plus the rack lights' own patched additive material. the demo model stamps
      // one cell of each kind for exactly this reason, see FacilityModel.demo
      // and the workstations first, because their two borrowed buffers have to be filled before the
      // families that merge them run — the same ordering FacilityArea keeps, for the same reason
      var workLeds = MeshBufTools.make();
      var workCable = MeshBufTools.make();
      FacilityWork.build(model, workLeds, workCable);
      FacilityDeco.build(sc, model, workLeds);
      // and the electrical service, which is NOT a new program permutation either — the pack mesh is
      // FacilityClutter's alphaTest DoubleSide lambert and the cable is the shell's plain mapped one
      // — but IS a 1024 pack and a 256 tile to decode and upload, which is the reason FacilityClutter
      // is on this list too. It is placed after FacilityDeco because it asks that file for its
      // machine rects, though the call order does not actually matter: rectOf is a pure function of
      // the grid. Whether the demo model emits anything is NOT assumed: FacilityModel.demo leaves
      // `rooms` empty, which the socket's own roomKey falls back past, and its floor SCATTER lands on
      // free floor alone — so the pack mesh is warmed even in a model with no wall a socket will take
      FacilityCable.build(sc, model, workCable);
      // and the halos those three just handed over, which is a program permutation of its own (a
      // mask-patched transparent basic with an alphaMap) AND NOT OPTIONAL FOR A SECOND REASON:
      // FacilityDetail.halos is what CLEARS the collector, so skipping it here would carry these
      // three demo-model quads into the first real compound. the demo stamps its fittings against
      // the north room's wall, so all three land
      FacilityDetail.halos(sc, model);
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
      ContactMask.detach();
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
          // parked car, plus the lot's standing junk and the indoor lab kit, both appended off their
          // own tables so a fourth piece of junk needs no edit here. the two tables are re-laid into
          // this one's shape rather than concatenated whole: each carries fields of its own (a kit
          // prop's depth and yaw jitter) that the warm has no use for
          //
          // the KIT is patched with the rest, and it is the one family here that will really read
          // through the mask — everything else stands outdoors. what it must NOT do is skip the
          // warm on that account: the patch is a PROGRAM KEY, and an unpatched warm compiles a
          // permutation the first entry never asks for.
          // NOTHING from the gate is among them: the booth and the barrier are both merged geometry,
          // taking the cladding, roof and lit-window materials the shell already warms, plus the one
          // hazard-band material the boom adds
          var facProps = [
            {
              path: RenderConfig.MODELS.facilityLamp,
              h: FacilityStyle.LAMP_H,
            },
            {
              path: FacilityGround.FENCE_PATH,
              h: FacilityStyle.FENCE_H,
            },
            {
              path: FacilityGround.BIN_PATH,
              h: FacilityStyle.BIN_H,
            },
            {
              path: RenderConfig.MODELS.facilityCar,
              h: FacilityStyle.CAR_H,
            },
          ].concat([for (p in FacilityDebris.PROPS) { path: p.path, h: p.h }])
            .concat([for (p in FacilityKit.PROPS) { path: p.path, h: p.h }])
            .concat([for (p in FacilityJanitor.PROPS) { path: p.path, h: p.h }])
            // and the three hazard-barrel liveries on the LOW decoration cells, off their own table
            // like the two above. all three are the same MESH repainted, but each is its own path
            // and so its own material and its own program key — warming one would leave the other
            // two to compile on the frame they first appear
            .concat([for (p in FacilityDeco.PROPS)
              { path: p.path, h: FacilityStyle.DECO_ROUND_H }])
            // and the desk trinkets, off FacilityWork's own table rather than one row each — the mug
            // alone is three paths now (three liveries off one mesh, art/models.json
            // facility/desk-mug-b and -c) and the table is where a fifth trinket or a fourth glaze is
            // added. Every one of them is its own material and so its own program key, the drums'
            // reason for being listed at all
            .concat([for (p in FacilityWork.TRINKETS) { path: p.path, h: p.h }])
            // and the two ROOM TEMPLATE props, for the same reason as everything above them: a path
            // is a material is a program key
            .concat([
              {
                path: FacilityDeco.TOILET_PATH,
                h: FacilityStyle.TOILET_H,
              },
              {
                path: FacilityWork.CHAIR_PATH,
                h: FacilityStyle.CHAIR_H,
              },
              // and the three the workstation is made of, which are three paths and therefore three
              // materials and three program keys — the drums' own reason for being listed one by one
              {
                path: RenderConfig.MODELS.facilityMonitor,
                h: FacilityStyle.WORK_FOOT_H + FacilityStyle.WORK_STAND_H +
                  FacilityStyle.WORK_SCREEN_H,
              },
              {
                path: RenderConfig.MODELS.facilityTower,
                h: FacilityStyle.WORK_TOWER_H,
              },
              {
                path: RenderConfig.MODELS.facilityKeyboard,
                h: FacilityStyle.WORK_KEY_H,
              },
              // and the hand-modelled fittings, one path and so one program each — the low rack is
              // its own MESH (three chassis, not six squashed), see FacilityDeco.fittings
              {
                path: RenderConfig.MODELS.facilityRack,
                h: FacilityStyle.DECO_RACK_H,
              },
              {
                path: RenderConfig.MODELS.facilityRackLow,
                h: FacilityStyle.DECO_RACK_LOW_H,
              },
              {
                path: RenderConfig.MODELS.facilityCabinet,
                h: FacilityStyle.DECO_CABINET_H,
              },
              // the machine ONCE, even though it draws at two heights: a program is keyed by the
              // material and the variant, and both batches share one of each
              {
                path: RenderConfig.MODELS.facilityMachine,
                h: FacilityStyle.DECO_MACHINE_SZ,
              },
              {
                path: RenderConfig.MODELS.facilityBookcase,
                h: FacilityStyle.DECO_BOOKCASE_H,
              },
              {
                path: RenderConfig.MODELS.facilityShelving,
                h: FacilityStyle.DECO_SHELF_H,
              },
              {
                path: RenderConfig.MODELS.facilityBasin,
                h: FacilityStyle.BASIN_MESH_H,
              },
              // and the lounge's two, which share one packed sheet but are two paths and so two
              // programs — a path is a material is a program key, whatever image is behind it
              {
                path: RenderConfig.MODELS.facilitySofa,
                h: FacilityStyle.DECO_SOFA_H,
              },
              {
                path: RenderConfig.MODELS.facilityTableLow,
                h: FacilityStyle.DECO_TABLE_LOW_H,
              },
            ]);
          // and the two that stand on the ROOF, which are the only props here that are NOT
          // mask-patched — they follow the deck they stand on, which takes no mask either (see the
          // header of render.facility.FacilityRoof). the patch is a PROGRAM KEY, so warming them
          // patched would compile a permutation the first entry never asks for and leave the one it
          // does ask for to compile on the frame it appears
          var roofProps = [
            {
              path: RenderConfig.MODELS.facilityRoofAc,
              h: FacilityStyle.ROOF_AC_H,
            },
            {
              path: RenderConfig.MODELS.facilityRoofDish,
              h: FacilityStyle.ROOF_DISH_H,
            },
          ];
          var left = green.length + facProps.length + roofProps.length;
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
                  ContactMask.detach();
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
                  ContactMask.detach();
                  done();
                });
            }
          for (i in 0...roofProps.length)
            {
              var p = roofProps[i];
              render.Models.get(p.path, function(_)
                {
                  render.Models.instanced(sc, p.path, place, p.h, SOLID);
                  done();
                });
            }
        }).then(function(_) return Warmup.compile(renderer, camera, sc));
    }
}
