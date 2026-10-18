package render;

import three.Three;

// a loaded glb prop, recentered so its footprint is centered in X/Z with its base at local y=0,
// wrapped in a pivot Group so placement (scale/position/yaw) is free to set on the pivot
typedef ModelTemplate = {
  var pivot:Object3D; // clone this per placement
  var height:Float;   // native world height, for target-height scaling
};

// where one copy of an instanced prop stands. a named typedef rather than an inline structure because
// `y` is optional and Haxe arrays are INVARIANT: an Array<{x,z,yaw}> literal will not pass as an
// Array<{x,z,yaw,?y}>, so every producer has to be annotated with this same type
typedef PropPlace = {
  x:Float,     // world x
  z:Float,     // world z
  yaw:Float,   // turn about the vertical, radians
  ?y:Float,    // signed offset off the floor; absent = 0, which is where normalize() puts the base
  ?scale:Float, // multiplier on the batch's target height; absent = 1. a batch is ONE glb drawn many
                // times, so without this a stand of trees is one tree repeated
  ?pitch:Float, // turn about the prop's own x axis before its yaw, radians; absent = 0. it turns about
                // the base's centre, so a prop laid on its back is lifted and recentred by the caller
};

// handle for a bulk-instanced prop: the mesh plus every placement's precomputed world matrix and
// centre, so a per-frame cull() can pack only the visible instances into the draw. three frustum-
// culls per OBJECT, so one InstancedMesh draws ALL instances whenever any is on screen
typedef InstancedProp = {
  var mesh:InstancedMesh;      // null until the glb finishes loading
  var matrices:Array<Matrix4>; // full per-placement transforms (all instances)
  var centres:Array<Vector3>;  // per-placement world position, for the frustum test
  @:optional var spheres:Array<Sphere>; // per-placement world bounding sphere, built by cullExact's first call
};

// the material a batch draws with. one InstancedMesh = one material, so a level that wants two looks
// over the same prop builds TWO batches over the same placements and lets a per-frame cull mask pick
// which one draws each placement. every variant but SOLID CLONES the material first: it comes from
// the shared model cache, so editing it in place would change every other batch over the same path —
// including the solid twin it is meant to swap with
enum ModelVariant
{
  SOLID;
  DEAD;                          // broken street lamp: emissive killed, lens/hood texels darkened
  GHOST;                         // see-through twin, for a prop the player is standing on
  HULL(color:Int, width:Float);  // flat backface shell on normal-offset geometry: the tactical outline
}

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
              o.material = toLambert(o.material);
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
              // and anisotropic filtering on every map the glb carries — see MODEL_ANISO for why a
              // prop is the ONE thing in the frame that was not getting it. safe to set here without
              // needsUpdate: these textures are minutes old and have never been uploaded, so the
              // value is read on their first upload rather than forcing a second one
              for (t in [ o.material.map, o.material.normalMap, o.material.roughnessMap,
                o.material.metalnessMap, o.material.emissiveMap, o.material.aoMap ])
                if (t != null)
                  {
                    t.anisotropy = RenderConfig.MODEL_ANISO;
                    // and where it came from, for render.PolyProbe's caption. a glb's maps are
                    // embedded, so nothing else in the renderer knows their provenance
                    t.name = path;
                  }
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
          // hand every waiter an EMPTY template instead of dropping them. instanced() finds no mesh
          // and draws nothing, place() adds an empty group — but a caller that SEQUENCES on the
          // callback still advances. dropping them stalled View's boot warm chain on its Promise,
          // which left the renderer bound to the warm render target and never disposed the composer
          // same pivot-wraps-root shape normalize() builds, just with nothing in it: instanced()
          // reads pivot.children[0] unconditionally and would throw on a bare Group
          var pivot = new Group();
          pivot.add(new Group());
          var t:ModelTemplate = { pivot: pivot, height: 0.0 };
          cache.set(path, t);
          for (f in waiting.get(path))
            f(t);
          waiting.remove(path);
        });
    }

// swap a glb's PBR material for the flat MeshLambert every other surface in the game already draws
// with. the night art has no specular in it, and a prop was the last thing in the frame still shading
// through the full PBR path — which costs far more than its triangles do: a TRELLIS prop is ~5k tris
// over a 40-pixel silhouette, so its triangles are SUB-PIXEL and the fragment shader runs once per
// 2x2 quad however small they get, which is why prop cost tracks TRIANGLES and barely moves with
// resolution. measured on the integrated Radeon with the whole park in frame (3.6M tris, 1080p):
// 31.4ms -> 20.3ms GPU, and the culled follow view 8.9 -> 6.6. metalness/roughness go with the path,
// which on a TRELLIS bake is a FIX and not a loss — it lands at metallic 1 with an MR map and reads
// as chrome against flat art. the one family that really does want specular says so IN THE GLB:
// models.json's `roughness` dial bakes a roughnessFactor below 1 (the habitat props, 0.30-0.45), and
// those keep MeshStandard
  static function toLambert(m:Dynamic):Dynamic
    {
      var rough:Null<Float> = m.roughness;
      if (rough == null ||
          rough < 1)
        return m;
      return new MeshLambertMaterial({
        name: m.name,
        map: m.map,
        color: m.color,
        // the baked per-vertex AO (tools/models.mjs `bakeAO`, manifest key `ao`), which arrives as
        // COLOR_0 and is multiplied into the base colour by three's own shader. CARRIED EXPLICITLY
        // because this builds a NEW material rather than editing the loaded one — GLTFLoader sets the
        // flag on the material it made, and dropping it here would throw the bake away silently, with
        // the attribute still in the glb and nothing to show for it
        vertexColors: m.vertexColors,
        normalMap: m.normalMap,
        aoMap: m.aoMap,
        emissive: m.emissive,
        emissiveMap: m.emissiveMap,
        emissiveIntensity: m.emissiveIntensity,
        alphaTest: m.alphaTest,
        transparent: m.transparent,
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

// find the first mesh (has geometry) in a subtree — the source for instancing, and for
// render.military.MilitaryDoors, which patches the material every SOLID batch of a path shares
  public static function firstMesh(root:Object3D):Object3D
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

// the tactical outline's shell: every vertex pushed out along its own normal by `w`, so a BackSide
// draw of it pokes out past the real mesh and what stays visible is a band hugging the silhouette.
// `w` is in the model's LOCAL units — the caller divides by the instance scale to get a world-constant
// band. baked once per model+width and cached: the geometry is shared by every instance of the batch
  static var hullGeos:Map<String, BufferGeometry> = new Map();
  static function hullGeo(path:String, src:BufferGeometry, w:Float):BufferGeometry
    {
      var key = path + '@' + w;
      if (hullGeos.exists(key))
        return hullGeos.get(key);
      var geo = src.clone();
      var pos:Dynamic = geo.attributes.position;
      var nor:Dynamic = geo.attributes.normal;
      for (i in 0...(pos.count : Int))
        pos.setXYZ(i,
          pos.getX(i) + nor.getX(i) * w,
          pos.getY(i) + nor.getY(i) * w,
          pos.getZ(i) + nor.getZ(i) * w);
      pos.needsUpdate = true;
      geo.computeBoundingSphere();
      hullGeos.set(key, geo);
      return geo;
    }

// place MANY copies of a prop as ONE InstancedMesh (shared geometry+material, one draw call) — for
// props placed in bulk (street lamps, exit ladders). each placement: world (x,z) + yaw, scaled so
// height == targetH, base on the ground. reuses the prop's single mesh; the template recenter is
// folded into each instance matrix analytically (assumes the mesh sits at the template root — true
// for our baked glbs). `variant` picks the material, see ModelVariant
  public static function instanced(scene:Object3D, path:String, placements:Array<PropPlace>, targetH:Float, variant:ModelVariant):InstancedProp
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
          var geo:Dynamic = mesh.geometry;
          var mat:Dynamic = mesh.material;
          var real = true; // enters the shadow passes; false for the outline hull, which is pure UI
          switch (variant)
            {
              case SOLID:
              // dead street lamps: same post geometry, but its glowing bulb must not glow — and above
              // all must not feed bloom, which is what still lit a broken lamp's head. killing the
              // emissive alone is NOT enough: the base-colour map paints the lens and hood pale cream,
              // so the head still read bright — hence the masked map below
              case DEAD:
                mat = mesh.material.clone();
                if (mat.map != null && mesh.material.emissiveMap != null)
                  mat.map = deadMap(path, mat.map, mesh.material.emissiveMap);
                mat.emissive = new Color(0x000000);
                mat.emissiveMap = null;
                mat.emissiveIntensity = 0;
                mat.needsUpdate = true;
              case GHOST:
                mat = mesh.material.clone();
                mat.transparent = true;
                // opacity is owned by the per-frame ease (render.world.ObjModels.cull) and starts
                // SOLID on purpose: the glb can land mid-frame, before the first cull trims this
                // batch, and that one frame draws every ghost over its solid twin — at 1.0 that is
                // pixel-identical, so nothing shows
                mat.opacity = 1.0;
                // the load-bearing flag, not the alpha: the actor billboard is depth-TESTED, so a
                // prop that still writes depth rejects it however faint the prop is drawn
                mat.depthWrite = false;
                mat.needsUpdate = true;
              case HULL(color, width):
                // the band is a WORLD width and the shell is scaled by s at every instance, so the
                // vertex offset baked into the geometry has to be divided by it
                geo = hullGeo(path, mesh.geometry, width / s);
                real = false;
                mat = new MeshBasicMaterial({
                  color: color,
                  side: THREE.BackSide,
                  depthWrite: true,
                  fog: false, // a marker, not world geometry — it must stay legible into the fog
                });
            }
          var inst = new InstancedMesh(geo, mat, placements.length);
          inst.name = 'prop ' + path;
          // bulk props (lamp posts, ladders) cast AND receive real shadows — the post throws an angled
          // moon shadow, shows up in nearby lamp-spotlight casters, and self-shadows (crossarm/head
          // shadow the pole under the angled moon). own-light self-shadow is negligible (bulb straight
          // overhead). the GHOST twin keeps casting too: three's shadow pass renders its own depth
          // material and ignores transparency, so the batch handover never pops a shadow on or off
          inst.castShadow = real;
          inst.receiveShadow = real;
          // cull() does exact per-instance frustum culling every frame; three's coarse whole-mesh
          // cull tests a cached boundingSphere built from the reduced count and drops the whole mesh
          // at extreme camera (e.g. full zoom-out) — turn it off so only our cull() decides visibility
          untyped inst.frustumCulled = false;
          var q = new Quaternion(), scl = new Vector3(s, s, s);
          var up = new Vector3(0, 1, 0);
          var side = new Vector3(1, 0, 0), qx = new Quaternion(), off = new Vector3();
          for (i in 0...placements.length)
            {
              var pl = placements[i];
              var cos = Math.cos(pl.yaw), sin = Math.sin(pl.yaw);
              // per-placement scale rides ON TOP of the batch's height scale, so the recenter offset
              // (which is in the same local units) has to be scaled by it too or a jittered prop
              // drifts off its own footprint
              var ps = (pl.scale != null ? pl.scale : 1.0);
              scl.set(s * ps, s * ps, s * ps);
              // world = T(x,y,z) · Ry(yaw) · S(s) · T(recenter) → compose with the recenter rotated in.
              // normalize() puts the base at 0, so `y` (absent on most placements) is a signed offset
              // off the floor: negative buries a prop that should read as grown out of it
              var pos = new Vector3(pl.x + (rx * cos + rz * sin) * ps,
                ry * ps + (pl.y != null ? pl.y : 0.0),
                pl.z + (-rx * sin + rz * cos) * ps);
              q.setFromAxisAngle(up, pl.yaw);
              // a pitched prop: world = T · Ry(yaw) · Rx(pitch) · S · T(recenter), the recenter turned
              // by both
              if (pl.pitch != null)
                {
                  q.multiply(qx.setFromAxisAngle(side, pl.pitch));
                  off.set(rx * ps, ry * ps, rz * ps).applyQuaternion(q);
                  pos.set(pl.x + off.x, off.y + (pl.y != null ? pl.y : 0.0), pl.z + off.z);
                }
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
// back this frame — a lamp mid-outage swaps between the lit and the dead batch that way, for free.
// `all` skips the frustum test and packs every masked instance: a frame on which a FROZEN shadow map
// renders has to see every caster, or that map keeps the hole until its next render
  static var _frustum = new Frustum();
  static var _projScreen = new Matrix4();
  static var _sph = new Sphere();
  public static function cull(prop:InstancedProp, camera:PerspectiveCamera, radius:Float, ?mask:Array<Bool>, ?all:Bool):Void
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
          if (all != true &&
              !_frustum.intersectsSphere(_sph))
            continue;
          prop.mesh.setMatrixAt(k, prop.matrices[i]);
          k++;
        }
      prop.mesh.count = k;
      // an empty batch leaves the render list: at count 0 three still binds its program, uniforms and
      // VAO and skips only the draw, ~20-25 us a batch, and 32-57 of them sat empty every facility frame
      prop.mesh.visible = k > 0;
      untyped prop.mesh.instanceMatrix.needsUpdate = true;
    }

// exact per-instance cull for a static casting batch: each placement's own world bounding sphere
// (+ margin) against the frustum, visible instances packed first and the hidden ones after them, so
// the buffer always holds ALL of them. the main pass draws the visible count; every SHADOW pass draws
// the full set (spheres() hooks it), because a frozen spot or moon map rendered off the camera's
// subset keeps that hole until it next refreshes. an empty batch leaves the render list unless
// `keep` says a shadow map renders this frame. placements must not move after build: the spheres
// are baked once, so a posed batch (the doors) stays on cull()
  public static function cullExact(prop:InstancedProp, camera:PerspectiveCamera, margin:Float, keep:Bool):Void
    {
      var mesh = prop.mesh;
      if (mesh == null)
        return;
      if (prop.spheres == null)
        spheres(prop, margin);
      camera.updateMatrixWorld();
      _projScreen.multiplyMatrices(camera.projectionMatrix, camera.matrixWorldInverse);
      _frustum.setFromProjectionMatrix(_projScreen);
      var k = 0;
      var j = prop.matrices.length;
      for (i in 0...prop.matrices.length)
        {
          if (_frustum.intersectsSphere(prop.spheres[i]))
            {
              mesh.setMatrixAt(k, prop.matrices[i]);
              k++;
            }
          else
            {
              j--;
              mesh.setMatrixAt(j, prop.matrices[i]);
            }
        }
      mesh.count = k;
      mesh.visible = k > 0 || keep;
      untyped mesh.instanceMatrix.needsUpdate = true;
    }

// builds every placement's world bounding sphere for cullExact, and hooks the batch's shadow draws to
// the full instance count, handing the visible count back to the main pass after each one
  static function spheres(prop:InstancedProp, margin:Float):Void
    {
      var mesh = prop.mesh;
      if (mesh.geometry.boundingSphere == null)
        mesh.geometry.computeBoundingSphere();
      var bs:Sphere = mesh.geometry.boundingSphere;
      prop.spheres = [];
      for (m in prop.matrices)
        {
          var s = new Sphere();
          s.center.copy(bs.center).applyMatrix4(m);
          s.radius = bs.radius * m.getMaxScaleOnAxis() + margin;
          prop.spheres.push(s);
        }
      var n = prop.matrices.length;
      var shown = 0;
      mesh.onBeforeShadow = function()
        {
          shown = mesh.count;
          mesh.count = n;
        };
      mesh.onAfterShadow = function()
        {
          mesh.count = shown;
        };
    }
}
