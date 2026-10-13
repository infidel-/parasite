package render.lab;

import three.Three;
import render.Warmup;
import render.facility.FacilityDetail;
import render.facility.FacilityGeom;
import render.facility.FacilityStyle;
import render.world.ContactMask;

// the underground lab's warm scene: a mirror of LabArea.build's pass list over LabModel.demo, under
// LabScene's own rig so every program key carries the lab's light counts. It rots the moment that
// pass list grows without this one growing with it — the warning every *Warm carries. Run once per
// session, from render.View.warmKind on the first lab entry
class LabWarm
{
// build the throwaway plate and compile it
  public static function build(renderer:WebGLRenderer, camera:PerspectiveCamera, lampPool:Int):Dynamic
    {
      var model = LabModel.demo();
      // the contact field goes on before the builders, as in LabArea.build: a floor material reads
      // it at creation time
      var masonry = FacilityDetail.masonry(model);
      ContactMask.attach(FacilityStyle.CONTACT, model.w, model.h, masonry.solid, masonry.holes);
      var sc = LabScene.build(renderer, lampPool).scene;
      FacilityGeom.build(sc, model);
      LabGeom.build(sc, model);
      FacilityDetail.corners(sc, model);
      // and the collector those corners feed, which draining is what CLEARS
      FacilityDetail.halos(sc, model);
      LabDoors.build(sc, model, null);
      // the actor layer under the lab's moonless light set (Warmup.actorLayer)
      var fx = new Group();
      sc.add(fx);
      Warmup.actorLayer(fx, camera);
      ContactMask.detach();
      return Warmup.compile(renderer, camera, sc);
    }
}
