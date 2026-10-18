package render.corp;

import three.Three;

// the corp floor's per-TEXTURE meshes, collapsed into one mesh per MATERIAL.
//
// every emitter here (FacilityGeom.add / addFloor for the shell and the fittings, CorpStreet.add for
// the city below, CorpFacade for the tower's flank) merges its quads into one mesh per texture, so a
// floor plate drew ~10-13 wall meshes, 4-6 floors and 24 street meshes that differ in nothing but
// their map. One texture cannot hold them: the surfaces TILE, and an atlas cell cannot wrap (see
// 3d-render.md's open lead on walls). A DataArrayTexture can, since each layer is its own 0..1 space,
// so each bucket of identical materials becomes ONE mesh carrying a per-vertex `layer` and ONE
// texture array, sampled where three would have sampled `map`.
//
// a map of any other size than SIZE keeps its own mesh (signs2 is 1024, the whiteboard 512x384), and
// so does anything transparent, alpha-tested, emissive or alpha-mapped: those are different programs
class CorpMerge
{
  static inline var SIZE = 512; // every layer's edge, in texels

// merge every bucket of two or more identical-material meshes under `root`. returns how many merged
// meshes were made, or -1 while a candidate's map is still loading (the bucket cannot be decided
// before its sizes are known; call again next frame). `warm` skips the size test and fills nothing,
// for render.corp.CorpWarm, which only needs the merged programs compiled
  public static function merge(root:Object3D, warm:Bool):Int
    {
      var buckets = new Map<String, Array<Mesh>>();
      var keys = [];
      var pending = false;
      root.updateMatrixWorld();
      root.traverse(function(o)
        {
          var m:Dynamic = o;
          if (!fits(m))
            return;
          var img:Dynamic = m.material.map.image;
          if (!warm &&
              img == null)
            {
              pending = true;
              return;
            }
          if (!warm &&
              (img.width != SIZE ||
              img.height != SIZE))
            return;
          var key = bucketOf(m);
          if (!buckets.exists(key))
            {
              buckets.set(key, []);
              keys.push(key);
            }
          buckets.get(key).push(m);
        });
      if (pending)
        return -1;
      var made = 0;
      for (key in keys)
        {
          var list = buckets.get(key);
          if (list.length < 2)
            continue;
          build(list, warm);
          made++;
        }
      return made;
    }

// can this mesh join a bucket at all: an opaque, front-faced, plainly mapped lambert at its parent's
// origin, over the attribute set every emitter writes, that its owner has not held back with
// `userData.noMerge` (a mesh something else still hides or fades on its own)
  static function fits(m:Dynamic):Bool
    {
      if (m.isMesh != true ||
          m.isInstancedMesh == true ||
          m.visible != true ||
          m.userData.noMerge == true ||
          Std.isOfType(m.material, Array))
        return false;
      var mat:Dynamic = m.material;
      if (mat.isMeshLambertMaterial != true ||
          mat.map == null ||
          mat.transparent ||
          mat.alphaTest != 0 ||
          mat.alphaMap != null ||
          mat.emissiveMap != null ||
          mat.side != THREE.FrontSide)
        return false;
      var map:Dynamic = mat.map;
      if (map.repeat.x != 1 ||
          map.repeat.y != 1 ||
          map.offset.x != 0 ||
          map.offset.y != 0 ||
          map.rotation != 0)
        return false;
      if (m.position.x != 0 ||
          m.position.y != 0 ||
          m.position.z != 0 ||
          m.rotation.x != 0 ||
          m.rotation.y != 0 ||
          m.rotation.z != 0 ||
          m.scale.x != 1 ||
          m.scale.y != 1 ||
          m.scale.z != 1)
        return false;
      var geo:Dynamic = m.geometry;
      if (geo.index == null)
        return false;
      for (name in Reflect.fields(geo.attributes))
        if (name != 'position' &&
            name != 'normal' &&
            name != 'uv' &&
            name != 'color')
          return false;
      return true;
    }

// what makes two meshes the same draw but for the map: the program (the patch chain's cache key), the
// per-object flags and the parent. a parent at IDENTITY (the scene, a render.Chunks group) merges as
// one; any other (the street group, 114 units down) keeps its own buckets, so its transform still moves
// and hides the lot
  static function bucketOf(m:Dynamic):String
    {
      var mat:Dynamic = m.material;
      var p:Dynamic = m.parent;
      return (identity(p) ? 'root' : p.uuid) + '|' +
        mat.customProgramCacheKey() + '|' +
        (m.geometry.attributes.color != null) + '|' +
        m.castShadow + '|' +
        m.receiveShadow + '|' +
        mat.vertexColors + '|' +
        mat.color.getHex() + '|' +
        m.renderOrder;
    }

// is this parent's world transform the identity, so its children's vertices are already world space?
  static function identity(p:Object3D):Bool
    {
      var e = p.matrixWorld.elements;
      for (i in 0...16)
        if (e[i] != (i % 5 == 0 ? 1 : 0))
          return false;
      return true;
    }

// one bucket into one mesh: a layer per distinct map, the geometries concatenated with that layer
// written per vertex, the first member's material re-used with the array patched in, the rest freed
  static function build(list:Array<Mesh>, warm:Bool):Void
    {
      var first:Dynamic = list[0];
      var images:Array<Dynamic> = [];
      var maps:Array<Dynamic> = [];
      var layerOf = new Map<String, Int>();
      var geos = [];
      for (o in list)
        {
          var m:Dynamic = o;
          var name:String = m.material.map.name;
          if (!layerOf.exists(name))
            {
              layerOf.set(name, images.length);
              images.push(m.material.map.image);
              maps.push(m.material.map);
            }
          var g:Dynamic = m.geometry;
          var n:Int = g.attributes.position.count;
          var layer = layerOf.get(name);
          // built first: a comprehension in the call's args makes Haxe hoist `g.setAttribute` off its
          // Dynamic receiver, and three's method then runs with no `this`
          var arr:Array<Float> = [for (i in 0...n) layer];
          g.setAttribute('layer', new Float32BufferAttribute(arr, 1));
          geos.push(g);
        }
      var tex = layers(images, warm);
      tex.anisotropy = first.material.map.anisotropy;
      var mat:Dynamic = first.material;
      patch(mat, tex);
      var mesh = new Mesh(THREE.mergeGeometries(geos, false), mat);
      mesh.name = 'corp merged ' + list.length + ' ' + first.name;
      mesh.castShadow = first.castShadow;
      mesh.receiveShadow = first.receiveShadow;
      mesh.renderOrder = first.renderOrder;
      // the source map of each layer, for render.PolyProbe: the material's own `map` is the first
      // member's, so without this every face of the merge reports and paints that one texture
      mesh.userData.layerMaps = maps;
      // an identity parent may be a Chunks group, which culls as a 64-unit block: the merged mesh
      // spans the plate, so it goes to the top of the chain instead
      var parent:Object3D = first.parent;
      if (identity(parent))
        while (parent.parent != null)
          parent = parent.parent;
      parent.add(mesh);
      for (o in list)
        {
          var m:Dynamic = o;
          m.removeFromParent();
          m.geometry.dispose();
          if (m.material != mat)
            {
              m.material.map.dispose();
              m.material.dispose();
            }
        }
    }

// the texture array: each image drawn bottom row first (no flipY on a 3D upload), read back off a
// CPU-backed canvas, and the CPU copy dropped once the GPU has it
  static function layers(images:Array<Dynamic>, warm:Bool):DataArrayTexture
    {
      // the warm compiles the program and draws nothing, which a 1x1 single layer does as well as
      // the full array: allocating and mipping a blank SIZE array per bucket cost the warm ~1.3 s
      var edge = warm ? 1 : SIZE;
      var depth = warm ? 1 : images.length;
      var data = new js.lib.Uint8Array(edge * edge * 4 * depth);
      if (!warm)
        {
          var cv:Dynamic = js.Browser.document.createElement('canvas');
          cv.width = SIZE;
          cv.height = SIZE;
          var cx:Dynamic = cv.getContext('2d', { willReadFrequently: true });
          cx.setTransform(1, 0, 0, -1, 0, SIZE);
          for (i in 0...images.length)
            {
              cx.drawImage(images[i], 0, 0, SIZE, SIZE);
              data.set(cx.getImageData(0, 0, SIZE, SIZE).data, i * SIZE * SIZE * 4);
            }
        }
      var tex = new DataArrayTexture(data, edge, edge, depth);
      tex.colorSpace = THREE.SRGBColorSpace;
      tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
      tex.magFilter = THREE.LinearFilter;
      tex.minFilter = THREE.LinearMipmapLinearFilter;
      tex.generateMipmaps = true;
      tex.needsUpdate = true;
      tex.onUpdate = function()
        {
          tex.image.data = null;
        };
      return tex;
    }

// sample the array where three samples `map`. the map itself stays bound so USE_MAP and vMapUv (and
// every mask patch keyed on them) are untouched; only the diffuse read moves. chained OUTSIDE the
// existing hooks, none of which touch <uv_vertex> or <map_fragment> on these materials
  static function patch(mat:Dynamic, tex:DataArrayTexture):Void
    {
      var prev:Dynamic = mat.onBeforeCompile;
      var key:String = mat.customProgramCacheKey();
      var uni = { value: tex };
      mat.onBeforeCompile = function(shader:Dynamic, renderer:Dynamic)
        {
          prev(shader, renderer);
          shader.uniforms.uLayers = uni;
          shader.vertexShader = 'attribute float layer;\nflat varying float vLayer;\n' +
            StringTools.replace(shader.vertexShader, '#include <uv_vertex>',
              '#include <uv_vertex>\n  vLayer = layer;');
          shader.fragmentShader = 'uniform highp sampler2DArray uLayers;\nflat varying float vLayer;\n' +
            StringTools.replace(shader.fragmentShader, '#include <map_fragment>',
              '#ifdef USE_MAP\n  diffuseColor *= texture( uLayers, vec3( vMapUv, vLayer ) );\n#endif');
        };
      mat.customProgramCacheKey = function()
        {
          return key + '|layers';
        };
      mat.needsUpdate = true;
    }
}
