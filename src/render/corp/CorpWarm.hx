package render.corp;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;
import render.SceneSetup;
import render.Warmup;
import render.facility.FacilityDetail;
import render.facility.FacilityDoors;
import render.facility.FacilityGeom;
import render.facility.FacilityScene;
import render.facility.FacilityStyle;
import render.world.MeshBuf.MeshBufTools;
import render.world.ContactMask;
import render.world.IndoorMask;

// the corp tower's warm scene. it gets its OWN and does not ride the compound's for the reason that
// scene's header gives one step further in: a warm compiles a PROGRAM KEY, and the key carries the
// indoor swap, the contact field and the vision mask — but the MATERIAL also carries a map, and a
// 1024 sheet decoded and uploaded on first area entry is a hitch whether or not anything compiled.
// so this exists for the corp art set even where the permutations match the compound's exactly.
//
// it is a mirror of CorpArea.build's pass list, and it rots the moment that list grows without this
// one growing with it — the same warning render.facility.FacilityWarm carries. run once per session,
// from render.View.warmKind on the first corp entry
class CorpWarm
{
// build the throwaway floor plate and compile it
  public static function build(renderer:WebGLRenderer, camera:PerspectiveCamera, lampPool:Int):Dynamic
    {
      var model = CorpModel.demo();
      // both masks go on BEFORE the builders, exactly as in CorpArea.build: each reads `on` at
      // material-creation time, so a surface warmed without one warms a key the game never asks for
      var masonry = FacilityDetail.masonry(model);
      IndoorMask.attach(CorpStyle.INDOOR, model.w, model.h,
        function(col, row) return render.facility.FacilityModel.isInterior(model, col, row));
      ContactMask.attach(FacilityStyle.CONTACT, model.w, model.h, masonry.solid, masonry.holes);
      var bundle = FacilityScene.build(renderer, lampPool,
        CorpStyle.SKY, CorpStyle.FOG_NEAR, CorpStyle.FOG_FAR);
      var sc = bundle.scene;
      FacilityGeom.build(sc, model);
      // the nine fitting materials, which the shell above covers none of: each is its own mapped
      // lambert with its own texture, and a 512 decoded on first area entry is a hitch whether or
      // not anything had to compile. CorpModel.demo carries one cell of every kind for this
      CorpFurniture.build(sc, model);
      // and the whiteboard's own face, which CorpDeco only emits off an area's decoration objects
      // and so the demo plate never carries: one pane, for its map
      var board = MeshBufTools.make();
      FacilityGeom.pane(board, 0, 1, 0, 0, 0, 0, 1);
      FacilityGeom.add(sc, board, CorpStyle.WHITEBOARD, true, true);
      // and the security room's video wall, the same way: its emissive lambert, with the feed patch,
      // is a program of its own
      var screens = MeshBufTools.make();
      FacilityGeom.pane(screens, 0, 1, 0, 0, 0, 0, 1);
      CorpSecurity.addScreens(sc, screens);
      // and the doorway header, a plain emissive lambert with no feed patch: a second program key
      var sign = MeshBufTools.make();
      FacilityGeom.pane(sign, 0, 1, 0, 0, 0, 0, 1);
      CorpSecurity.addGlow(sc, sign, CorpStyle.SECURITY_SIGN, CorpStyle.SEC_SIGN_EMISSIVE, 'corp security sign');
      // the two flat dressing materials, each its own alphaTest / mapped lambert and each a 1024
      // or 512 decoded on first entry
      CorpClutter.build(sc, model);
      // and the exec rug's contact-patched alphaTest lambert, which no material above shares
      CorpRugs.build(sc, model);
      CorpSigns.build(sc, model);
      // and the additive glow, which is its own material: AdditiveBlending, vertexColors and an
      // alphaMap are all in three's program key, so none of the mapped lamberts above cover it
      CorpLamps.build(sc, model);
      // and the facade, which is the one UNLIT material in the kind: MeshBasicMaterial is its own
      // program key and no lambert above it covers one
      CorpFacade.build(sc, model);
      // and the street's two crowd programs, which are an INSTANCED additive basic — three's key
      // carries USE_INSTANCING, the blend and the map, so the facade above covers none of it. no
      // city is generated for the warm: a one-instance batch compiles the same program
      CorpCrowd.warm(sc);
      // and the street's LIT panes, the one lit material down there: an emissive map plus
      // alphaTest on a lambert, which neither the facade's basic nor the shell's plain lamberts
      // cover. no city for this either — one quad per facade family is the same program
      CorpStreet.warm(sc);
      FacilityDetail.corners(sc, model);
      // and the collector those corners feed, which is NOT optional: FacilityDetail.halos is what
      // CLEARS it, so skipping it here carries these demo quads into the first real tower
      FacilityDetail.halos(sc, model);
      // the door leaves, an INSTANCED mask-patched lambert — USE_INSTANCING is a program define, so
      // the merged shell above does not cover it. no area behind the demo model, so the leaf is shut
      FacilityDoors.build(sc, model, null);
      // and the same meshes merged onto texture arrays, a program per bucket that none above covers
      CorpMerge.merge(sc, true);
      IndoorMask.detach();
      ContactMask.detach();
      // park the moon's shadow box over the demo plate, so Warmup.compile's render actually runs
      // the shadow depth pass. Nothing on this plate CAST until the furniture and the glb batches
      // started casting off the ceiling fixtures, and a casting mesh whose depth program compiles
      // on the first real frame is the hitch this whole file exists to avoid — the box sits at
      // world origin otherwise and every caster falls outside it. FacilityWarm's own line, for its
      // own reason: the pool's spotlights hold shadow.autoUpdate = false and render nothing here
      var half = CityConfig.GRID * CityConfig.CELL / 2;
      SceneSetup.fitMoon(bundle.moon, new Vector3(
        model.w * CityConfig.CELL / 2 - half, 0, model.h * CityConfig.CELL / 2 - half));
      // and the SEVEN glb props, one entry per path, each patched exactly as CorpProps.batch
      // patches it. the mask goes back on around each instance: a glb resolves long after the
      // block above put it away, and VisionMask.patch chains the indoor swap onto every material
      // it takes while IndoorMask is attached — so a prop warmed OUTSIDE the mask compiles a
      // program key the first real tower never asks for, and leaves the one it does ask for to
      // compile on the frame the prop appears
      var paths = [
        { path: RenderConfig.MODELS.corpChair, h: CorpStyle.CHAIR_H },
        { path: RenderConfig.MODELS.corpMonitor, h: CorpStyle.MON_H },
        { path: RenderConfig.MODELS.corpKeyboard, h: CorpStyle.KEY_H },
        { path: RenderConfig.MODELS.corpWc, h: CorpStyle.WC_H },
        { path: RenderConfig.MODELS.corpVanity, h: CorpStyle.VANITY_GLB_H },
        { path: RenderConfig.MODELS.corpPlant, h: CorpStyle.PLANT_H },
        { path: RenderConfig.MODELS.corpCooler, h: CorpStyle.COOLER_H },
        { path: RenderConfig.MODELS.corpPrinter, h: CorpStyle.PRINTER_H },
        { path: RenderConfig.MODELS.corpDesk, h: CorpStyle.DESK_GLB_H },
        { path: RenderConfig.MODELS.corpTableLeg, h: CorpStyle.LEG_H },
        { path: RenderConfig.MODELS.corpBin, h: CorpStyle.BIN_H },
        { path: RenderConfig.MODELS.corpCase, h: render.corp.CorpDeco.CASE_CABINET[2] },
        // and the CCTV camera, which the demo plate's two corridor walls may or may not seat
        { path: RenderConfig.MODELS.corpWallCam, h: CorpStyle.CAM_H },
        // the exec office's seven, which the demo model cannot place (render.corp.CorpExec reads
        // the generator's decorations and the demo has none), so a path each here is their warm
        { path: RenderConfig.MODELS.corpExecDesk, h: CorpStyle.EXEC_DESK_H },
        { path: RenderConfig.MODELS.corpExecDesk3, h: CorpStyle.EXEC_DESK_H },
        { path: RenderConfig.MODELS.corpExecDesk2, h: CorpStyle.EXEC_DESK_H },
        { path: RenderConfig.MODELS.corpExecChair, h: CorpStyle.EXEC_CHAIR_H },
        { path: RenderConfig.MODELS.corpExecArmchair, h: CorpStyle.ARMCHAIR_H },
        { path: RenderConfig.MODELS.corpExecSofa, h: CorpStyle.SOFA_H },
        { path: RenderConfig.MODELS.corpExecTableLow, h: CorpStyle.TABLE_LOW_H },
        { path: RenderConfig.MODELS.corpExecPlaque, h: CorpStyle.PLAQUE_H },
        { path: RenderConfig.MODELS.corpExecPhoto, h: CorpStyle.PHOTO_H },
        // and the reception counter's three trinkets
        { path: RenderConfig.MODELS.corpRecPhone, h: CorpStyle.REC_PHONE_H },
        { path: RenderConfig.MODELS.corpRecBoard, h: CorpStyle.REC_BOARD_H },
        { path: RenderConfig.MODELS.corpRecBell, h: CorpStyle.REC_BELL_H },
        // and the kitchen's eleven, for the same reason: render.corp.CorpKitchen reads the
        // generator's tiles and decorations, and the demo model carries neither. The vending
        // machine is the tower's one EMISSIVE glb, a program of its own
        { path: RenderConfig.MODELS.corpKitchenTable, h: CorpStyle.KITCHEN_TABLE_H },
        { path: RenderConfig.MODELS.corpKitchenChair, h: CorpStyle.KITCHEN_CHAIR_H },
        { path: RenderConfig.MODELS.corpKitchenCounter, h: CorpStyle.COUNTER_H },
        { path: RenderConfig.MODELS.corpKitchenSink, h: CorpStyle.SINK_H },
        { path: RenderConfig.MODELS.corpKitchenCab, h: CorpStyle.CAB_H },
        { path: RenderConfig.MODELS.corpKitchenFridge, h: CorpStyle.FRIDGE_H },
        { path: RenderConfig.MODELS.corpKitchenVending, h: CorpStyle.VENDING_H },
        { path: RenderConfig.MODELS.corpKitchenMicrowave, h: CorpStyle.MICROWAVE[0] },
        { path: RenderConfig.MODELS.corpKitchenCoffee, h: CorpStyle.COFFEE[0] },
        { path: RenderConfig.MODELS.corpKitchenKettle, h: CorpStyle.KETTLE[0] },
        { path: RenderConfig.MODELS.corpKitchenToaster, h: CorpStyle.TOASTER[0] },
      ];
      // AND THE ARCHIVE'S TWO, appended off CorpFurniture's own table rather than typed out again
      // so a third family is one line in one place. CorpModel.demo carries two rank cells on each
      // of two rows for this, because the family is dealt off the ROW
      for (u in CorpFurniture.ARCH)
        paths.push({
          path: u.path,
          h: u.h,
        });
      // AND THE FOUR CLUTTER PROPS, one entry per path for the reason the ten above have one: a
      // path warmed nowhere compiles its program on the first area entry instead. Appended off
      // CorpStyle's own tables rather than typed out again, so promoting a seventh pack cell is
      // one line in one place
      for (i in 0...CorpStyle.CLUTTER_PROPS)
        paths.push({
          path: CorpStyle.CLUTTER_PROP_PATH[i],
          h: CorpStyle.CLUTTER_PROP_H[i],
        });
      return new js.lib.Promise(function(res, _)
        {
          var place = [{ x: 0.0, z: 0.0, yaw: 0.0 }];
          // AND THE TOWER'S OBJECT PROPS (the gun cabinet, shut and open): all three variants each,
          // through CorpArea.patchObj so the key is the one the floor asks for
          var objs = [for (m in render.world.ObjModels.MODELS)
            if (m.path.indexOf('models/corp/') == 0) m];
          var C = RenderConfig.OBJMARK;
          var left = paths.length + objs.length;
          for (m in objs)
            render.Models.get(m.path, function(_)
              {
                IndoorMask.attach(CorpStyle.INDOOR, model.w, model.h,
                  function(col, row) return render.facility.FacilityModel.isInterior(model, col, row));
                CorpArea.patchObj(m,
                  render.Models.instanced(sc, m.path, place, m.h, SOLID).mesh,
                  render.Models.instanced(sc, m.path, place, m.h, GHOST).mesh,
                  render.Models.instanced(sc, m.path, place, m.h, HULL(C.color, C.hullW)).mesh);
                IndoorMask.detach();
                left--;
                if (left == 0)
                  res(null);
              });
          for (i in 0...paths.length)
            {
              var pr = paths[i];
              render.Models.get(pr.path, function(_)
                {
                  IndoorMask.attach(CorpStyle.INDOOR, model.w, model.h,
                    function(col, row) return render.facility.FacilityModel.isInterior(model, col, row));
                  ContactMask.attach(FacilityStyle.CONTACT, model.w, model.h,
                    masonry.solid, masonry.holes);
                  render.world.VisionMask.patchMesh(
                    render.Models.instanced(sc, pr.path, place, pr.h, SOLID).mesh);
                  IndoorMask.detach();
                  ContactMask.detach();
                  left--;
                  if (left == 0)
                    res(null);
                });
            }
        }).then(function(_) return Warmup.compile(renderer, camera, sc));
    }
}
