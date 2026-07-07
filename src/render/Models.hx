package render;

import three.Three;

// a loaded glb prop, recentered so its footprint is centered in X/Z with its base at local y=0,
// wrapped in a pivot Group so placement (scale/position/yaw) is free to set on the pivot
typedef ModelTemplate = {
  var pivot:Object3D; // clone this per placement
  var height:Float;   // native world height, for target-height scaling
};

// loads + caches optimized glb props (baked by `make models` into app/models/). one GLTFLoader,
// one cached template per path; clones are cheap. mirrors render.Textures for models
class Models {
  static var loader:GLTFLoader = null;
  static var cache:Map<String, ModelTemplate> = new Map();
  static var waiting:Map<String, Array<ModelTemplate -> Void>> = new Map();

// request a template by app-relative path; cb runs now if cached, else once the load completes
  public static function get(path:String, cb:ModelTemplate -> Void):Void
    {
      if (cache.exists(path))
        {
          cb(cache.get(path));
          return;
        }
      var w = waiting.get(path);
      if (w != null)
        {
          w.push(cb);
          return;
        }
      waiting.set(path, [cb]);
      if (loader == null)
        loader = new GLTFLoader();
      loader.load(path, function(gltf)
        {
          // force single-sided: the glbs ship doubleSided, which lets back faces catch the omni
          // point light (no self-shadow) and lights the lamp's back. FrontSide culls that
          untyped gltf.scene.traverse(function(o:Dynamic)
            {
              if (o.material == null)
                return;
              o.material.side = THREE.FrontSide;
              // the glbs carry a hi-poly normal map but no tangents, and we decimate hard — the
              // derived tangents perturb shading normals wrongly (lights polys that face away). scale
              // the normal map down (0 = ignore it, flat shading from geometry only)
              if (o.material.normalMap != null)
                o.material.normalScale.set(RenderConfig.MODEL_NORMAL_SCALE, RenderConfig.MODEL_NORMAL_SCALE);
            });
          var t = normalize(gltf.scene);
          cache.set(path, t);
          for (f in waiting.get(path))
            f(t);
          waiting.remove(path);
        }, null, function(_)
        {
          js.Browser.console.warn('[models] load failed ' + path);
          waiting.remove(path);
        });
    }

// recenter a loaded root (center X/Z, base at y=0) inside a pivot Group and measure native height
  static function normalize(root:Object3D):ModelTemplate
    {
      var box = new Box3().setFromObject(root);
      var size = box.getSize(new Vector3());
      var center = box.getCenter(new Vector3());
      root.position.set(-center.x, -box.min.y, -center.z);
      var pivot = new Group();
      pivot.add(root);
      return { pivot: pivot, height: size.y };
    }

// clone the template into a scene at world (x,z), scaled so its height == targetH, base on the
// ground (y=0), yawed by `yaw` radians. no-op-until-loaded: nothing appears until the glb arrives
  public static function place(scene:Object3D, path:String, x:Float, z:Float, targetH:Float, yaw:Float = 0.0):Void
    {
      get(path, function(t)
        {
          var m = t.pivot.clone();
          var s = t.height > 0 ? targetH / t.height : 1.0;
          m.scale.set(s, s, s);
          m.position.set(x, 0, z);
          m.rotation.set(0, yaw, 0);
          scene.add(m);
        });
    }
}
