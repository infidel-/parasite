package render.decals;

import three.Three;
import render.particles.AtlasRect;
import render.particles.Sprites;

// one instanced draw call per decal MATERIAL instead of one pooled quad per decal. flat ground
// decals (plain blood splats + street debris) all sample the shared sprite atlas, so they share
// geometry + material and ride a single InstancedMesh; the per-decal radius-fade opacity and the
// per-decal atlas UV rect travel on `instanceAlpha` / `instanceUV` vertex attributes injected into
// the lit MeshStandard material via onBeforeCompile, so the batch keeps the exact wet-sheen look
// while collapsing hundreds of draw calls to a handful. emissive blood (acid/slime/black), wall
// holes, star glints, actors + badges stay on the per-quad path.
// grouping on the atlas texture (not a per-cell crop) is the whole point: keying on a cropped cell
// gave one group per sprite — measured 55 live groups = 55 calls for 122 decals
// a frame is begin() -> many add() -> end(); driven by the Decals pass each frame
typedef DecalGroup =
{
  var mesh:InstancedMesh;             // the batched draw call for this material group
  var geo:Dynamic;                    // own unit-quad geometry (holds this group's per-instance attrs)
  var alpha:js.lib.Float32Array;      // per-instance opacity, re-uploaded each frame
  var alphaAttr:InstancedBufferAttribute; // instanced attribute wrapping `alpha`
  var uv:js.lib.Float32Array;         // per-instance atlas UV rect (u, v, w, h), re-uploaded each frame
  var uvAttr:InstancedBufferAttribute; // instanced attribute wrapping `uv`
  var mat:Dynamic;                    // shared lit material (atlas map + wet-sheen params)
  var cap:Int;                        // allocated instance capacity
  var count:Int;                      // instances filled this frame
};

class DecalBatch
{
  var group:Object3D;                                   // scene group the instanced meshes attach to
  var groups:Map<String, DecalGroup> = new Map();       // key: atlasUuid + rough + metal
  // the group materials in creation order, so a caller that has to reach them every frame does not
  // walk the map. MATERIALS and not meshes on purpose: grow() swaps a group's mesh and keeps its
  // material, so a mesh list would go stale where this cannot
  var mats:Array<Dynamic> = [];
  // scratch reused per add() so a frame allocates nothing
  var _q = new Quaternion();
  var _e = new Euler();
  var _v = new Vector3();
  var _s = new Vector3();
  var _m = new Matrix4();
  // per texture group is a single splat type at one size band, well under this; grow() is a guard
  static inline var CAP = 128;

  public function new(group:Object3D)
    {
      this.group = group;
    }

// start a frame: reset every group's fill count (leftover instances hidden by the count trim in end)
  public function begin():Void
    {
      for (g in groups)
        g.count = 0;
    }

// queue one flat ground decal into its material's instanced group. atlas is the shared sprite-atlas
// texture and r the cell's UV rect inside it; sx/sy are the full world quad size on each ground axis
// (SIZE * scale, times the content fraction for debris); alpha is the radius-fade opacity;
// rough/metal pick the wet-blood vs matte-debris material
  public function add(atlas:Texture, r:AtlasRect, x:Float, y:Float, z:Float, sx:Float, sy:Float,
      yaw:Float, alpha:Float, rough:Float, metal:Float):Void
    {
      var key = atlas.uuid + ':' + rough + ':' + metal;
      var g = groups.get(key);
      if (g == null)
        g = make(atlas, rough, metal, key);
      if (g.count >= g.cap)
        grow(g);
      // lie flat (−90° about X) + yaw in-plane, scaled to the world quad size, at the ground point
      _e.set(-Math.PI / 2, 0, yaw);
      _q.setFromEuler(_e);
      _v.set(x, y, z);
      _s.set(sx, sy, 1);
      _m.compose(_v, _q, _s);
      g.mesh.setMatrixAt(g.count, _m);
      g.alpha[g.count] = alpha;
      g.uv[g.count * 4] = r.u;
      g.uv[g.count * 4 + 1] = r.v;
      g.uv[g.count * 4 + 2] = r.w;
      g.uv[g.count * 4 + 3] = r.h;
      g.count++;
    }

// upload each group's filled instances + trim the drawn count to hide the empty tail
  public function end():Void
    {
      for (g in groups)
        {
          g.mesh.count = g.count;
          untyped g.mesh.instanceMatrix.needsUpdate = true;
          g.alphaAttr.needsUpdate = true;
          g.uvAttr.needsUpdate = true;
        }
    }

// build a fresh instanced group for a material: unit-quad geometry carrying the instanceAlpha +
// instanceUV attributes, a lit material patched to fold those into the fragment alpha and the atlas
// lookup, and the mesh
  function make(atlas:Texture, rough:Float, metal:Float, key:String):DecalGroup
    {
      var alpha = new js.lib.Float32Array(CAP);
      var attr = new InstancedBufferAttribute(alpha, 1);
      untyped attr.setUsage(THREE.DynamicDrawUsage);
      var uv = new js.lib.Float32Array(CAP * 4);
      var uvAttr = new InstancedBufferAttribute(uv, 4);
      untyped uvAttr.setUsage(THREE.DynamicDrawUsage);
      var geo:Dynamic = new PlaneGeometry(1, 1);
      geo.setAttribute('instanceAlpha', attr);
      geo.setAttribute('instanceUV', uvAttr);
      var mat:Dynamic = new MeshStandardMaterial({
        map: atlas,
        transparent: true,
        depthWrite: false,
        side: untyped THREE.DoubleSide,
        // three draws a transparent DoubleSide material TWICE (back pass then front pass, each
        // flagging needsUpdate). that split only matters for closed geometry where both faces can
        // show at once; a flat decal quad shows one face, so the back pass is a pure duplicate.
        // measured: 513 -> 458 calls citywide
        forceSinglePass: true,
        roughness: rough,
        metalness: metal,
      });
      // inject the per-instance opacity + atlas window: carry instanceAlpha to the fragment stage and
      // multiply it into the final alpha (each decal keeps its own radius fade within the shared draw
      // call), and remap the quad's uv onto this instance's atlas cell. the vMapUv overwrite must
      // land AFTER <uv_vertex>, which is what assigns it from the base uv
      mat.onBeforeCompile = function(shader:Dynamic)
        {
          shader.vertexShader = 'attribute float instanceAlpha;\nattribute vec4 instanceUV;\n' +
            'varying float vDecalAlpha;\n' +
            StringTools.replace(shader.vertexShader, 'void main() {',
              'void main() {\n  vDecalAlpha = instanceAlpha;');
          shader.vertexShader = StringTools.replace(shader.vertexShader, '#include <uv_vertex>',
            '#include <uv_vertex>\n  vMapUv = uv * instanceUV.zw + instanceUV.xy;');
          shader.fragmentShader = 'varying float vDecalAlpha;\n' +
            StringTools.replace(shader.fragmentShader, '#include <opaque_fragment>',
              '#include <opaque_fragment>\n  gl_FragColor.a *= vDecalAlpha;');
        };
      // three keys its program cache by base material params, NOT by onBeforeCompile — without a
      // distinct key our alpha-patched program could collide with an identical plain MeshStandard
      // (dropping the fade). force a unique key so the patched program stays ours
      untyped mat.customProgramCacheKey = function() return 'decalInstanceAlpha';
      var mesh = new InstancedMesh(geo, mat, CAP);
      // our own cull isn't needed (decals are few + the count trims the tail); but three's coarse
      // whole-mesh cull uses a stale boundingSphere as instances shuffle, so disable it
      untyped mesh.frustumCulled = false;
      untyped mesh.renderOrder = Sprites.ORD_DECAL;
      // the road under a batched decal is a shadow receiver, so the decal must be one too — else a
      // blood pool inside a building's moon shadow stays lit over darkened asphalt (the same miss
      // Windows.add and WallDecals already fixed). free: receiveShadow is a uniform, not a define
      mesh.receiveShadow = true;
      var g:DecalGroup =
      {
        mesh: mesh,
        geo: geo,
        alpha: alpha,
        alphaAttr: attr,
        uv: uv,
        uvAttr: uvAttr,
        mat: mat,
        cap: CAP,
        count: 0,
      };
      groups.set(key, g);
      mats.push(mat);
      group.add(mesh);
      return g;
    }

// the batched materials, for a caller that has to patch them. these groups are built LAZILY, on the
// first paint that needs one, so there is no build-time moment to catch them — the sewer vision mask
// (render.sewer.SewerMask) folds itself in from the render loop instead
  public function materials():Array<Dynamic>
    {
      return mats;
    }

// double a group's capacity (guard: a texture group shouldn't exceed CAP in practice). the in-flight
// instances added this frame are dropped for one frame — cosmetic, and effectively never happens
  function grow(g:DecalGroup):Void
    {
      var newCap = g.cap * 2;
      group.remove(g.mesh);
      g.mesh.dispose();
      var alpha = new js.lib.Float32Array(newCap);
      var attr = new InstancedBufferAttribute(alpha, 1);
      untyped attr.setUsage(THREE.DynamicDrawUsage);
      var uv = new js.lib.Float32Array(newCap * 4);
      var uvAttr = new InstancedBufferAttribute(uv, 4);
      untyped uvAttr.setUsage(THREE.DynamicDrawUsage);
      var geo:Dynamic = new PlaneGeometry(1, 1);
      geo.setAttribute('instanceAlpha', attr);
      geo.setAttribute('instanceUV', uvAttr);
      var mesh = new InstancedMesh(geo, g.mat, newCap);
      untyped mesh.frustumCulled = false;
      untyped mesh.renderOrder = Sprites.ORD_DECAL;
      mesh.receiveShadow = true; // carried over from make() — the replacement mesh must still receive
      group.add(mesh);
      g.mesh = mesh;
      g.geo = geo;
      g.alpha = alpha;
      g.alphaAttr = attr;
      g.uv = uv;
      g.uvAttr = uvAttr;
      g.cap = newCap;
      g.count = 0;
    }

// release GPU buffers for every group (called on view teardown)
  public function dispose():Void
    {
      for (g in groups)
        {
          group.remove(g.mesh);
          g.mesh.dispose();
          untyped g.geo.dispose();
          untyped g.mat.dispose();
        }
      groups = new Map();
      mats = [];
    }
}
