package render;

import three.Three;

// one merged mesh, its index re-sorted block by block so a contiguous run of it is a contiguous patch
// of the ground
typedef RangeMesh = {
  mesh:Mesh,           // the merged mesh, at identity, so its positions are world space
  starts:Array<Int>,   // per block, in index order: the first index of its triangles
  ends:Array<Int>,     // per block: one past its last index
  boxes:Array<Box3>,   // per block: the world box of its triangles
  box:Box3,            // the whole mesh's world box, tested first
};

// draw-range culling for an area-spanning merged mesh. one mesh per material is the cheapest thing to
// SUBMIT, but three culls it as one sphere that holds the whole area, so it drew from everywhere and a
// draw call that put no pixel on screen was most of what the facility submitted. cutting it back into
// meshes costs the calls the merge saved (measured: per 16-cell chunk, office110T 153 -> 298 calls);
// keeping it whole and narrowing its DRAW RANGE to the blocks in frame keeps one call and drops the
// rest. calls can only go down and the sort order is untouched
class RangeCull
{
  static var _frustum = new Frustum();
  static var _proj = new Matrix4();
  static var _v = new Vector3();

// re-sort `mesh`'s index by the `block`-unit square each triangle's centroid stands in, IN PLACE, and
// record each block's index span and world box. a casting mesh gets its full range back for every
// shadow pass, so a frozen map never keeps the hole of a block the camera was not looking at
  public static function build(mesh:Mesh, block:Float):RangeMesh
    {
      var geo:Dynamic = mesh.geometry;
      var idx:Dynamic = geo.index.array;
      var pos:Dynamic = geo.attributes.position.array;
      // bucket the triangles by block, keyed on the block's grid coordinates
      var tris = new Map<Int, Array<Int>>();
      var keys:Array<Int> = [];
      var t = 0;
      while (t < idx.length)
        {
          var a:Int = (idx[t] : Int) * 3;
          var b:Int = (idx[t + 1] : Int) * 3;
          var c:Int = (idx[t + 2] : Int) * 3;
          var bx = Math.floor((pos[a] + pos[b] + pos[c]) / 3 / block);
          var bz = Math.floor((pos[a + 2] + pos[b + 2] + pos[c + 2]) / 3 / block);
          var key = (bx + 2048) * 4096 + bz + 2048;
          var list = tris.get(key);
          if (list == null)
            {
              list = [];
              tris.set(key, list);
              keys.push(key);
            }
          list.push(t);
          t += 3;
        }
      keys.sort(function(x, y) return x - y);
      // write the blocks back in key order, each one's span and box beside it
      var sorted:Array<Int> = [];
      var out:RangeMesh = {
        mesh: mesh,
        starts: [],
        ends: [],
        boxes: [],
        box: new Box3(),
      };
      for (key in keys)
        {
          var box = new Box3();
          out.starts.push(sorted.length);
          for (t0 in tris.get(key))
            for (k in 0...3)
              {
                var i:Int = idx[t0 + k];
                sorted.push(i);
                _v.set(pos[i * 3], pos[i * 3 + 1], pos[i * 3 + 2]);
                box.expandByPoint(_v);
                out.box.expandByPoint(_v);
              }
          out.ends.push(sorted.length);
          out.boxes.push(box);
        }
      for (i in 0...sorted.length)
        idx[i] = sorted[i];
      geo.index.needsUpdate = true;
      if (mesh.castShadow)
        {
          var n:Int = idx.length;
          var start = 0;
          var count = 0;
          mesh.onBeforeShadow = function()
            {
              start = geo.drawRange.start;
              count = geo.drawRange.count;
              geo.setDrawRange(0, n);
            };
          mesh.onAfterShadow = function()
            {
              geo.setDrawRange(start, count);
            };
        }
      return out;
    }

// per frame: each mesh draws from its first block in frame to its last, and leaves the render list
// when none is. `keep` holds an empty CASTING mesh in the list on a frame a shadow map renders, with
// nothing in the main pass and its full range in the shadow one
  public static function cull(list:Array<RangeMesh>, camera:PerspectiveCamera, keep:Bool):Void
    {
      camera.updateMatrixWorld();
      _proj.multiplyMatrices(camera.projectionMatrix, camera.matrixWorldInverse);
      _frustum.setFromProjectionMatrix(_proj);
      for (r in list)
        {
          var lo = -1;
          var hi = -1;
          if (_frustum.intersectsBox(r.box))
            for (i in 0...r.boxes.length)
              if (_frustum.intersectsBox(r.boxes[i]))
                {
                  if (lo < 0)
                    lo = r.starts[i];
                  hi = r.ends[i];
                }
          var geo:Dynamic = r.mesh.geometry;
          if (lo < 0)
            {
              geo.setDrawRange(0, 0);
              r.mesh.visible = keep &&
                r.mesh.castShadow;
            }
          else
            {
              geo.setDrawRange(lo, hi - lo);
              r.mesh.visible = true;
            }
        }
    }
}
