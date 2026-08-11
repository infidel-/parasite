package render;

import three.Three;
import citygen.CityConfig;

// spatial chunking for a built area's STATIC geometry. a world builder adds thousands of flat
// children to the scene and three walks + frustum-tests every one of them each frame to find the
// few hundred it draws; bucketing them under chunk groups lets projectObject early-out on a whole
// block at once (an invisible parent is O(1)). the groups sit at identity, so every child keeps its
// local position and world matrix — pixel-identical output, only the traversal changes.
// extracted from render.View so every render.Area3D kind shares one implementation
class Chunks
{
  public static inline var CELLS = 16; // chunk edge, in grid cells (16 * CELL 4 = 64 world units)

  var list:Array<{ g:Group, sphere:Sphere }> = [];
  var frustum = new Frustum();
  var mat = new Matrix4();

  public function new()
    {
    }

// a mesh's local bounding radius — used to spot area-spanning geometry that must NOT be chunked
  static function objRadius(d:Dynamic):Float
    {
      var g:Dynamic = d.geometry;
      if (g == null)
        return 1e9;
      var r:Float;
      if (d.isInstancedMesh == true)
        {
          d.computeBoundingSphere(); // instance-aware: a per-building window mesh is small, the city-wide lamp prop is not
          r = d.boundingSphere != null ? d.boundingSphere.radius : 1e9;
        }
      else
        {
          if (g.boundingSphere == null)
            g.computeBoundingSphere();
          r = g.boundingSphere != null ? g.boundingSphere.radius : 1e9;
        }
      var s:Dynamic = d.scale;
      return r * Math.max(s.x, Math.max(s.y, s.z));
    }

// bucket the static geometry into spatial chunk groups. `pre` is the snapshot of what the scene
// already held before the world builder ran (lights, lamp props) — those keep their scene parent.
// world matrices are baked once here and the subtree then opts out of the per-frame matrix walk
  public function build(scene:Scene, pre:Array<Object3D>):Void
    {
      var CH = CityConfig.CELL * CELLS;
      var skip = new Map<String,Bool>();
      for (o in pre)
        skip.set(untyped o.uuid, true);
      var groups = new Map<String, Group>();
      for (o in scene.children.copy())
        {
          var d:Dynamic = o;
          if (skip.exists(d.uuid) ||
              (d.isMesh != true && d.isInstancedMesh != true))
            continue;
          // area-spanning meshes (ground, roads) keep their scene parent: bucketed by their single
          // origin they would pop out entirely the moment that one chunk culls
          if (objRadius(d) > CH)
            continue;
          var key = Math.floor(o.position.x / CH) + ':' + Math.floor(o.position.z / CH);
          var g = groups.get(key);
          if (g == null)
            {
              g = new Group();
              groups.set(key, g);
              scene.add(g);
            }
          g.add(o); // reparent — group is at identity, so the child's world transform is unchanged
        }
      scene.updateMatrixWorld(true); // bake every world matrix once, before the subtrees freeze
      list = [];
      for (g in groups)
        {
          var b = new Box3().setFromObject(g);
          var size = b.getSize(new Vector3());
          var sph = new Sphere();
          sph.center = b.getCenter(new Vector3());
          sph.radius = Math.sqrt(size.x * size.x + size.y * size.y + size.z * size.z) / 2;
          untyped g.matrixWorldAutoUpdate = false; // static: skip this subtree in updateMatrixWorld forever
          list.push({ g: g, sphere: sph });
        }
      trace('[chunks] ' + list.length + ' groups (' + CELLS + ' cells each)');
    }

// per frame: frustum-test each CHUNK instead of each mesh. `shadowReach` keeps a chunk inside a
// shadow box visible even when offscreen, else its geometry would stop casting shadows into view
// (0 for an area with no area-wide shadow caster, e.g. a sewer)
  public function cull(camera:PerspectiveCamera, p:Vector3, shadowReach:Float):Void
    {
      if (list.length == 0)
        return;
      mat.multiplyMatrices(camera.projectionMatrix, camera.matrixWorldInverse);
      frustum.setFromProjectionMatrix(mat);
      for (c in list)
        {
          var dx = c.sphere.center.x - p.x;
          var dz = c.sphere.center.z - p.z;
          var reach = shadowReach + c.sphere.radius;
          c.g.visible = (dx * dx + dz * dz) <= reach * reach || frustum.intersectsSphere(c.sphere);
        }
    }
}
