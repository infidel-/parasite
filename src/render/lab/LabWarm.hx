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
// build the throwaway plate, wait for its glbs and compile it
  public static function build(renderer:WebGLRenderer, camera:PerspectiveCamera, lampPool:Int):Dynamic
    {
      var model = LabModel.demo();
      // the contact field goes on before the builders, as in LabArea.build: a floor material reads
      // it at creation time
      var masonry = FacilityDetail.masonry(model);
      ContactMask.attach(FacilityStyle.CONTACT, model.w, model.h, masonry.solid, masonry.holes);
      var bundle = LabScene.build(renderer, lampPool);
      var sc = bundle.scene;
      FacilityGeom.build(sc, model);
      LabGeom.build(sc, model);
      FacilityDetail.corners(sc, model);
      // and the collector those corners feed, which draining is what CLEARS
      FacilityDetail.halos(sc, model);
      LabDoors.build(sc, model, null);
      // the vats, the lift and the furniture, one of each part: every glb is its own material and so
      // its own program, and the glass and the medium are transparent, which is a key of its own on top
      var paths = LabVats.warm(sc).concat(LabLift.warm(sc)).concat(LabInterior.warm(sc))
        .concat(LabSpin.warm(sc));
      LabDecals.warm(sc);
      LabWall.warm(sc);
      LabFlames.warm(sc);
      // the borrowed electrical over the demo's rooms, which its walls give sockets to hang on
      render.facility.FacilityCable.build(sc, model, render.world.MeshBuf.MeshBufTools.make());
      // the actor layer under the lab's moonless light set (Warmup.actorLayer)
      var fx = new Group();
      sc.add(fx);
      Warmup.actorLayer(fx, camera);
      ContactMask.detach();
      // a batch has no mesh until its glb lands, so the compile waits on every one of them
      return new js.lib.Promise(function(res, _)
        {
          var left = paths.length;
          for (p in paths)
            render.Models.get(p, function(_)
              {
                left--;
                if (left == 0)
                  res(null);
              });
        }).then(function(_)
          {
            // the moving lights' shadow pass (LabSpin): the lab's furniture casts near them, and
            // only a REAL shadow render compiles the depth programs (Warmup.compile's note). Every
            // batch casts here, one caster slot is aimed down over the plate and dirtied, so the
            // compile's one render draws its map
            sc.traverse(function(o:Object3D)
              {
                if (untyped o.isInstancedMesh)
                  o.castShadow = true;
              });
            var l:SpotLight = cast bundle.lampLights.debugList()[0];
            l.position.set(0, 10, 0);
            l.target.position.set(0, 0, 1);
            untyped l.shadow.needsUpdate = true;
            return Warmup.compile(renderer, camera, sc);
          });
    }
}
