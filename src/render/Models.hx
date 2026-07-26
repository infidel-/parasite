package render;

import three.Three;

// a loaded glb prop, recentered so its footprint is centered in X/Z with its base at local y=0,
// wrapped in a pivot Group so placement (scale/position/yaw) is free to set on the pivot
typedef ModelTemplate = {
  var pivot:Object3D; // clone this per placement
  var height:Float;   // native world height, for target-height scaling
};

// handle for a bulk-instanced prop: the mesh plus every placement's precomputed world matrix and
// centre, so a per-frame cull() can pack only the visible instances into the draw. three frustum-
// culls per OBJECT, so one InstancedMesh draws ALL instances whenever any is on screen
typedef InstancedProp = {
  var mesh:InstancedMesh;      // null until the glb finishes loading
  var matrices:Array<Matrix4>; // full per-placement transforms (all instances)
  var centres:Array<Vector3>;  // per-placement world position, for the frustum test
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
              // DEBUG: smooth away the decimation shading artifact (see MODEL_SMOOTH_NORMALS). recomputes
              // per-vertex normals from the coarse geometry, dropping the mismatched authored normals
              if (RenderConfig.MODEL_SMOOTH_NORMALS &&
                  o.geometry != null)
                o.geometry.computeVertexNormals();
              // the glbs carry a hi-poly normal map but no tangents, and we decimate hard — the
              // derived tangents perturb shading normals wrongly (lights polys that face away). scale
              // the normal map down (0 = ignore it, flat shading from geometry only)
              if (o.material.normalMap != null)
                o.material.normalScale.set(RenderConfig.MODEL_NORMAL_SCALE, RenderConfig.MODEL_NORMAL_SCALE);
            });
          // instanced() reads each mesh's RAW geometry and ignores its node transform — so a rotation
          // authored on the NODE (not baked into the verts) is silently dropped, laying the prop over.
          // street-lamp2 carries a 90°-about-X node quat that stands its (lying) geometry up; bake every
          // mesh's world matrix into its geometry here so the verts are self-standing (lamp1's node is
          // identity → no-op). must run before normalize() measures the box
          untyped gltf.scene.updateMatrixWorld(true);
          untyped gltf.scene.traverse(function(o:Dynamic)
            {
              if (o.geometry == null)
                return;
              o.geometry.applyMatrix4(o.matrixWorld);
              o.position.set(0, 0, 0);
              o.quaternion.set(0, 0, 0, 1);
              o.scale.set(1, 1, 1);
              o.updateMatrix();
            });
          // per-model yaw so the prop's facing matches the placement convention (SceneSetup yaws each
          // post to face its road, bulb offset along local +X). street-lamp2's arm is authored 90° off
          // lamp1's, so turn it to match — baked into the (now upright) verts before normalize
          var ry = yawFix(path);
          if (ry != 0)
            untyped gltf.scene.traverse(function(o:Dynamic)
              {
                if (o.geometry != null)
                  o.geometry.rotateY(ry);
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

// per-model yaw correction (radians about the vertical Y) so a prop's facing matches the placement
// convention; 0 = as-authored. street-lamp2's arm sits 90° off the residential lamp
  static function yawFix(path:String):Float
    return path == RenderConfig.MODELS.streetLamp2 ? -Math.PI / 2 : 0.0;

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

// find the first mesh (has geometry) in a subtree — the source for instancing
  static function firstMesh(root:Object3D):Object3D
    {
      var found:Object3D = null;
      root.traverse(function(o)
        {
          if (found == null && o.geometry != null)
            found = o;
        });
      return found;
    }

// the DEAD lamp's base-colour map. the glb paints the lens and hood pale cream, so a broken lamp still
// reads bright once its emissive is stripped. that same material's emissive map is EXACTLY the lens
// region in white on black, so use it as a mask and multiply only those texels down:
//   out = base * (1 - mask * (1 - mul))
// three canvas ops, no per-pixel loop: invert the mask, screen it with a flat grey(mul) — screen(1-m,
// mul) == 1 - m*(1-mul) exactly — then multiply the result onto the base. one texture per model path,
// cached and shared by every dead lamp in the area
  static var deadMaps:Map<String, Texture> = new Map();
  static function deadMap(path:String, base:Dynamic, mask:Dynamic):Texture
    {
      if (deadMaps.exists(path))
        return deadMaps.get(path);
      var mul = RenderConfig.LAMP_LIGHT.deadLensMul;
      var w:Int = base.image.width;
      var h:Int = base.image.height;
      // the darkening factor per texel, as an image
      var mc = js.Browser.document.createCanvasElement();
      mc.width = w;
      mc.height = h;
      var mx = mc.getContext2d();
      untyped mx.drawImage(mask.image, 0, 0, w, h);
      mx.globalCompositeOperation = 'difference';
      mx.fillStyle = '#ffffff';
      mx.fillRect(0, 0, w, h);
      mx.globalCompositeOperation = 'screen';
      var g = Std.int(mul * 255);
      mx.fillStyle = 'rgb(' + g + ',' + g + ',' + g + ')';
      mx.fillRect(0, 0, w, h);
      // base, multiplied by it
      var cv = js.Browser.document.createCanvasElement();
      cv.width = w;
      cv.height = h;
      var ctx = cv.getContext2d();
      untyped ctx.drawImage(base.image, 0, 0, w, h);
      ctx.globalCompositeOperation = 'multiply';
      untyped ctx.drawImage(mc, 0, 0);
      var t = new CanvasTexture(cv);
      // the canvas holds the source image UNFLIPPED, so it must inherit the glb texture's flipY
      // (false) — a bare CanvasTexture defaults to true and would stand the post on its head
      t.flipY = base.flipY;
      t.wrapS = base.wrapS;
      t.wrapT = base.wrapT;
      t.colorSpace = base.colorSpace;
      t.needsUpdate = true;
      deadMaps.set(path, t);
      return t;
    }

// place MANY copies of a prop as ONE InstancedMesh (shared geometry+material, one draw call) — for
// props placed in bulk (street lamps). each placement: world (x,z) + yaw, scaled so height == targetH,
// base on the ground. reuses the prop's single mesh; the template recenter is folded into each
// instance matrix analytically (assumes the mesh sits at the template root — true for our baked glbs)
  public static function instanced(scene:Object3D, path:String, placements:Array<{ x:Float, z:Float, yaw:Float }>, targetH:Float, ?dead:Bool = false):InstancedProp
    {
      var prop:InstancedProp = { mesh: null, matrices: [], centres: [] };
      if (placements.length == 0)
        return prop;
      get(path, function(t)
        {
          var root = t.pivot.children[0]; // normalize() wrapped the recentered root in the pivot
          var mesh:Dynamic = firstMesh(root);
          if (mesh == null)
            return;
          var s = t.height > 0 ? targetH / t.height : 1.0;
          // recenter offset baked by normalize() onto root.position — scaled + yaw-rotated per instance
          var rx = root.position.x * s, ry = root.position.y * s, rz = root.position.z * s;
          // dead street lamps: same post geometry, but its glowing bulb must not glow — and above all
          // must not feed bloom, which is what still lit a broken lamp's head. clone first: the glb
          // material comes from the shared model cache, so editing it in place would kill the working
          // lamps' bulbs too. killing the emissive alone is NOT enough: the base-colour map paints the
          // lens and hood pale cream, so the head still read bright — hence the masked map below
          var mat:Dynamic = mesh.material;
          if (dead)
            {
              mat = mesh.material.clone();
              if (mat.map != null && mesh.material.emissiveMap != null)
                mat.map = deadMap(path, mat.map, mesh.material.emissiveMap);
              mat.emissive = new Color(0x000000);
              mat.emissiveMap = null;
              mat.emissiveIntensity = 0;
              mat.needsUpdate = true;
            }
          var inst = new InstancedMesh(mesh.geometry, mat, placements.length);
          // bulk props (lamp posts) cast AND receive real shadows — the post throws an angled moon
          // shadow, shows up in nearby lamp-spotlight casters, and self-shadows (crossarm/head shadow
          // the pole under the angled moon). own-light self-shadow is negligible (bulb straight overhead)
          inst.castShadow = true;
          inst.receiveShadow = true;
          // cull() does exact per-instance frustum culling every frame; three's coarse whole-mesh
          // cull tests a cached boundingSphere built from the reduced count and drops the whole mesh
          // at extreme camera (e.g. full zoom-out) — turn it off so only our cull() decides visibility
          untyped inst.frustumCulled = false;
          var q = new Quaternion(), scl = new Vector3(s, s, s);
          var up = new Vector3(0, 1, 0);
          for (i in 0...placements.length)
            {
              var pl = placements[i];
              var cos = Math.cos(pl.yaw), sin = Math.sin(pl.yaw);
              // world = T(x,0,z) · Ry(yaw) · S(s) · T(recenter) → compose with the recenter rotated in
              var pos = new Vector3(pl.x + rx * cos + rz * sin, ry, pl.z - rx * sin + rz * cos);
              q.setFromAxisAngle(up, pl.yaw);
              var mtx = new Matrix4();
              mtx.compose(pos, q, scl);
              inst.setMatrixAt(i, mtx);
              // keep the transform + centre so cull() can repack the visible subset each frame
              prop.matrices.push(mtx);
              prop.centres.push(pos);
            }
          untyped inst.instanceMatrix.needsUpdate = true;
          scene.add(inst);
          prop.mesh = inst;
        });
      return prop;
    }

// per-frame frustum cull for a bulk-instanced prop: pack only the instances whose centre is within
// the camera frustum (plus a per-instance radius margin) into the front of the buffer and cap count.
// without this a single InstancedMesh draws every instance whenever any one is on screen.
// `mask` (optional, indexed like the placements) additionally drops instances the caller wants held
// back this frame — a lamp mid-outage swaps between the lit and the dead batch that way, for free
  static var _frustum = new Frustum();
  static var _projScreen = new Matrix4();
  static var _sph = new Sphere();
  public static function cull(prop:InstancedProp, camera:PerspectiveCamera, radius:Float, ?mask:Array<Bool>):Void
    {
      if (prop.mesh == null)
        return;
      camera.updateMatrixWorld();
      _projScreen.multiplyMatrices(camera.projectionMatrix, camera.matrixWorldInverse);
      _frustum.setFromProjectionMatrix(_projScreen);
      _sph.radius = radius;
      var k = 0;
      for (i in 0...prop.centres.length)
        {
          if (mask != null && !mask[i])
            continue;
          _sph.center.copy(prop.centres[i]);
          if (!_frustum.intersectsSphere(_sph))
            continue;
          prop.mesh.setMatrixAt(k, prop.matrices[i]);
          k++;
        }
      prop.mesh.count = k;
      untyped prop.mesh.instanceMatrix.needsUpdate = true;
    }
}
