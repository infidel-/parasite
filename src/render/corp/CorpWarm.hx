package render.corp;

import three.Three;
import render.Warmup;
import render.facility.FacilityDetail;
import render.facility.FacilityDoors;
import render.facility.FacilityGeom;
import render.facility.FacilityScene;
import render.facility.FacilityStyle;
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
      IndoorMask.attach(FacilityStyle.INDOOR, model.w, model.h,
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
      FacilityDetail.corners(sc, model);
      // and the collector those corners feed, which is NOT optional: FacilityDetail.halos is what
      // CLEARS it, so skipping it here carries these demo quads into the first real tower
      FacilityDetail.halos(sc, model);
      // the door leaves, an INSTANCED mask-patched lambert — USE_INSTANCING is a program define, so
      // the merged shell above does not cover it. no area behind the demo model, so the leaf is shut
      FacilityDoors.build(sc, model, null);
      IndoorMask.detach();
      ContactMask.detach();
      return Warmup.compile(renderer, camera, sc);
    }
}
