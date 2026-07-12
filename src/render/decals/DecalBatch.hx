package render.decals;

import three.Three;
import render.particles.Sprites;

// one instanced draw call per decal texture instead of one pooled quad per decal. flat ground
// decals (plain blood splats + street debris) share geometry + material within a texture group and
// ride a single InstancedMesh; the per-decal radius-fade opacity travels on an `instanceAlpha`
// vertex attribute injected into the lit MeshStandard material via onBeforeCompile, so the batch
// keeps the exact wet-sheen look while collapsing hundreds of draw calls to a handful. emissive
// blood (acid/slime/black), wall holes, star glints, actors + badges stay on the per-quad path.
// a frame is begin() -> many add() -> end(); driven by the Decals pass each frame
typedef DecalGroup =
{
  var mesh:InstancedMesh;             // the batched draw call for this texture group
  var geo:Dynamic;                    // own unit-quad geometry (holds this group's instanceAlpha attr)
  var alpha:js.lib.Float32Array;      // per-instance opacity, re-uploaded each frame
  var alphaAttr:InstancedBufferAttribute; // instanced attribute wrapping `alpha`
  var mat:Dynamic;                    // shared lit material (map + wet-sheen params)
  var cap:Int;                        // allocated instance capacity
  var count:Int;                      // instances filled this frame
};

class DecalBatch
{
  var group:Object3D;                                   // scene group the instanced meshes attach to
  var groups:Map<String, DecalGroup> = new Map();       // key: texUuid + rough + metal
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

// queue one flat ground decal into its texture's instanced group. sx/sy are the full world quad
// size on each ground axis (SIZE * scale, times the content fraction for debris); alpha is the
// radius-fade opacity; rough/metal pick the wet-blood vs matte-debris material
  public function add(tex:Texture, x:Float, y:Float, z:Float, sx:Float, sy:Float, yaw:Float,
      alpha:Float, rough:Float, metal:Float):Void
    {
      var key = tex.uuid + ':' + rough + ':' + metal;
      var g = groups.get(key);
      if (g == null)
        g = make(tex, rough, metal, key);
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
        }
    }

// build a fresh instanced group for a texture: unit-quad geometry carrying the instanceAlpha
// attribute, a lit material patched to fold that attribute into the fragment alpha, and the mesh
  function make(tex:Texture, rough:Float, metal:Float, key:String):DecalGroup
    {
      var alpha = new js.lib.Float32Array(CAP);
      var attr = new InstancedBufferAttribute(alpha, 1);
      untyped attr.setUsage(THREE.DynamicDrawUsage);
      var geo:Dynamic = new PlaneGeometry(1, 1);
      geo.setAttribute('instanceAlpha', attr);
      var mat:Dynamic = new MeshStandardMaterial({
        map: tex,
        transparent: true,
        depthWrite: false,
        side: untyped THREE.DoubleSide,
        roughness: rough,
        metalness: metal,
      });
      // inject the per-instance opacity: carry instanceAlpha to the fragment stage and multiply it
      // into the final alpha, so each decal keeps its own radius fade within the shared draw call
      mat.onBeforeCompile = function(shader:Dynamic)
        {
          shader.vertexShader = 'attribute float instanceAlpha;\nvarying float vDecalAlpha;\n' +
            StringTools.replace(shader.vertexShader, 'void main() {',
              'void main() {\n  vDecalAlpha = instanceAlpha;');
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
      var g:DecalGroup =
      {
        mesh: mesh,
        geo: geo,
        alpha: alpha,
        alphaAttr: attr,
        mat: mat,
        cap: CAP,
        count: 0,
      };
      groups.set(key, g);
      group.add(mesh);
      return g;
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
      var geo:Dynamic = new PlaneGeometry(1, 1);
      geo.setAttribute('instanceAlpha', attr);
      var mesh = new InstancedMesh(geo, g.mat, newCap);
      untyped mesh.frustumCulled = false;
      untyped mesh.renderOrder = Sprites.ORD_DECAL;
      group.add(mesh);
      g.mesh = mesh;
      g.geo = geo;
      g.alpha = alpha;
      g.alphaAttr = attr;
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
    }
}
