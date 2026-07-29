package render;

import three.Three;

typedef PolyInfo = { name:String, tex:String, res:Int };

// polygon class registry for the in-browser texture-UV editor. Every tunable face
// material is tagged with a class string; its texture is registered here so editing
// a class shifts that texture's UV offset on EVERY polygon of that kind at once.
// baseOff remembers each texture's original offset so class edits are ADDITIONAL
class Poly {
  public static final tex:Map<String, Array<Texture>> = new Map();
  public static final info:Map<String, PolyInfo> = new Map();
  // base offset per texture, keyed by uuid (so class edits stack on the original)
  static final baseOff:Map<String, { u:Float, v:Float }> = new Map();

  public static function tag(mat:Dynamic, cls:String, name:String, texPath:String, res:Int = 512):Dynamic {
    if (mat == null || mat.map == null) return mat;
    mat.userData.cls = cls;
    if (!tex.exists(cls)) tex.set(cls, []);
    tex.get(cls).push(mat.map);
    if (!info.exists(cls)) info.set(cls, { name: name, tex: texPath, res: res });
    baseOff.set(mat.map.uuid, { u: mat.map.offset.x, v: mat.map.offset.y });
    return mat;
  }

  public static function applyClassOffset(cls:String, u:Float, v:Float):Void {
    var arr = tex.get(cls);
    if (arr == null) return;
    for (t in arr) {
      var bo = baseOff.get(t.uuid);
      var bu = bo != null ? bo.u : 0.0;
      var bv = bo != null ? bo.v : 0.0;
      t.offset.set(bu + u, bv + v);
    }
  }

  static var checked = false;

// collapse a multi-material box into one draw call PER DISTINCT source image, by baking each
// face's texture matrix into the geometry UVs (identity-transform materials then sample
// pixel-identically) and reordering the index so same-image faces form one contiguous group.
// a single-image box (coping) -> 1 call; a clean+worn box (brick parapet) -> 2; walls+roof -> 3.
// returns one Material (single image) or a deduped Material[] (multi); falls back to the
// original array untouched if any face lacks a map. one class tag per bucket keeps the live UV
// editor able to shift a texture globally (per-face offsets are baked and no longer editable)
  public static function flattenBox(geo:Dynamic, mats:Array<Dynamic>,
      cls:String, name:String, texPath:String):Dynamic
    {
      if (!checked)
        {
          checked = true;
          if (!flattenDemo())
            js.Browser.console.warn('[poly] flatten uv self-check FAILED');
        }
      // every face needs a mapped texture to bake; without one, leave the box as-is
      for (m in mats)
        if (m.map == null)
          return mats;
      var groups:Array<Dynamic> = geo.groups;
      // bake each group's texture transform into its face UVs. box faces own distinct
      // vertices, so a per-vertex seen[] stops the shared quad edge being transformed twice
      var uv:Dynamic = geo.attributes.uv;
      var index:Dynamic = geo.index;
      var seen:Array<Bool> = [];
      for (g in groups)
        {
          var mtx = uvMatrix(mats[g.materialIndex].map);
          var end = g.start + g.count;
          for (k in g.start...end)
            {
              var vi:Int = index.getX(k);
              if (seen[vi])
                continue;
              seen[vi] = true;
              var u:Float = uv.getX(vi);
              var v:Float = uv.getY(vi);
              uv.setXY(vi, mtx.a * u + mtx.b * v + mtx.e, mtx.c * u + mtx.d * v + mtx.f);
            }
        }
      uv.needsUpdate = true;
      // bucket faces by source image: one draw call (index group) per distinct image
      var srcs:Array<Dynamic> = [];
      var repMap:Array<Dynamic> = [];   // a representative map per bucket, to clone the material from
      var faceBucket:Array<Int> = [];   // per group (face) -> bucket index
      for (g in groups)
        {
          var s:Dynamic = mats[g.materialIndex].map.source;
          var bi = -1;
          for (i in 0...srcs.length)
            if (srcs[i] == s)
              {
                bi = i;
                break;
              }
          if (bi < 0)
            {
              bi = srcs.length;
              srcs.push(s);
              repMap.push(mats[g.materialIndex].map);
            }
          faceBucket.push(bi);
        }
      // one identity-transform material per bucket over its shared image; RepeatWrapping since
      // the baked UVs run past [0,1] where a face tiled (its source's own wrap was already Repeat)
      var out:Array<Dynamic> = [];
      for (i in 0...srcs.length)
        {
          var base:Dynamic = repMap[i].clone();
          base.center.set(0, 0);
          base.repeat.set(1, 1);
          base.rotation = 0;
          base.offset.set(0, 0);
          base.wrapS = untyped THREE.RepeatWrapping;
          base.wrapT = untyped THREE.RepeatWrapping;
          base.needsUpdate = true;
          out.push(tag(new MeshLambertMaterial({ map: base }),
            cls, name, texPath));
        }
      // single image: drop the groups so the whole box draws in one call
      if (srcs.length == 1)
        {
          geo.clearGroups();
          return out[0];
        }
      // multiple images: reorder the index so each bucket's faces are contiguous, then emit
      // one group per bucket (draw calls == distinct image count, down from six)
      var old:Array<Int> = [for (k in 0...index.count) index.getX(k)];
      var newIdx:Array<Int> = [];
      geo.clearGroups();
      for (bi in 0...srcs.length)
        {
          var start = newIdx.length;
          for (gi in 0...groups.length)
            {
              if (faceBucket[gi] != bi)
                continue;
              var g = groups[gi];
              for (k in g.start...(g.start + g.count))
                newIdx.push(old[k]);
            }
          geo.addGroup(start, newIdx.length - start, bi);
        }
      geo.setIndex(newIdx);
      return out;
    }

// replicate three's Texture.updateMatrix (setUvTransform) as plain coefficients so a face's
// texture transform can be baked into geometry UVs: u' = a*u + b*v + e, v' = c*u + d*v + f
  static function uvMatrix(tex:Dynamic):{ a:Float, b:Float, c:Float, d:Float, e:Float, f:Float }
    {
      var co = Math.cos(tex.rotation);
      var si = Math.sin(tex.rotation);
      var sx:Float = tex.repeat.x, sy:Float = tex.repeat.y;
      var cx:Float = tex.center.x, cy:Float = tex.center.y;
      var tx:Float = tex.offset.x, ty:Float = tex.offset.y;
      return {
        a: sx * co,
        b: sx * si,
        e: -sx * (co * cx + si * cy) + cx + tx,
        c: -sy * si,
        d: sy * co,
        f: -sy * (-si * cx + co * cy) + cy + ty,
      };
    }

// self-check: the baked coefficients match three's own Texture matrix for a sample transform
  static function flattenDemo():Bool
    {
      var t:Dynamic = new Texture();
      t.center.set(0.3, 0.7);
      t.repeat.set(2, -1.5);
      t.rotation = 0.5;
      t.offset.set(0.1, 0.2);
      t.updateMatrix();
      var m = uvMatrix(t);
      var el:Array<Float> = t.matrix.elements; // column-major: [a,c,_, b,d,_, e,f,_]
      inline function close(x:Float, y:Float):Bool
        return Math.abs(x - y) < 1e-6;
      return close(m.a, el[0]) &&
        close(m.c, el[1]) &&
        close(m.b, el[3]) &&
        close(m.d, el[4]) &&
        close(m.e, el[6]) &&
        close(m.f, el[7]);
    }
}
