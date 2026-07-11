package render;

import three.Three;
import citygen.CityConfig;
import citygen.CityConfig.cellToWorld;
import game.AreaGame;
import render.world.WorldCtx;

// emissive corner marks over walkable city cells around the player: one small cross at every
// shared cell corner (thin ground quads — WebGL lines are always 1px and can't bloom),
// HDR-tinted so the bloom pass gives them a soft glow without covering the visuals
class TacticalGrid
{
  static inline var Y = 0.06;
  static inline var WIDTH = 0.015; // cross line half-width (cells)
  static inline var ARM = 0.12;    // cross arm half-length (cells)
  static inline var RADIUS = 16;   // grid extent around the center cell (cells, square)
  static inline var ALPHA = 0.6;   // darkness knob: how much of the ground the marks let through
  // HDR color multiplier: must clear BLOOM_THRESHOLD (0.9) in bloom's luminance metric (blue
  // weighs only 0.11) after the alpha mix, with headroom — subpixel segments get diluted by
  // the AA/downsample average and cut out of the glow otherwise
  static inline var GLOW = 5.0;

  var scene:Scene;
  var area:AreaGame;
  var mesh:Mesh;
  var ccol = -1;                   // built center cell (rebuild when it moves)
  var crow = -1;

// remember the area; the geometry is built lazily on the first show (most areas never toggle tactical)
  public function new(scene:Scene, area:AreaGame)
    {
      this.scene = scene;
      this.area = area;
    }

// show the grid around a center cell, rebuilding the geometry when the center moved
  public function show(col:Int, row:Int):Void
    {
      if (mesh == null ||
          col != ccol ||
          row != crow)
        build(col, row);
      mesh.visible = true;
    }

// hide the grid (geometry kept for the next show at the same spot)
  public function hide():Void
    {
      if (mesh != null)
        mesh.visible = false;
    }

// (re)build the grid from the area's authoritative walkability map, RADIUS cells around center
  function build(col:Int, row:Int):Void
    {
      ccol = col;
      crow = row;
      var pos:Array<Float> = [];
      var idx:Array<Int> = [];
      var half = CityConfig.CELL / 2;
      var r0 = crow - RADIUS < 0 ? 0 : crow - RADIUS;
      var r1 = crow + RADIUS + 1 > area.height ? area.height : crow + RADIUS + 1;
      var c0 = ccol - RADIUS < 0 ? 0 : ccol - RADIUS;
      var c1 = ccol + RADIUS + 1 > area.width ? area.width : ccol + RADIUS + 1;
      // mark every corner of every walkable cell once (shared corners dedupe through the map),
      // keeping the highest adjacent floor so a mark on a curb edge isn't buried
      var marks:Map<Int,Float> = new Map();
      var stride = area.width + 1;
      for (row in r0...r1)
        for (col in c0...c1)
          {
            if (!area.isWalkable(col, row))
              continue;
            var y = WorldCtx.floorY(col, row) + Y;
            for (dr in 0...2)
              for (dc in 0...2)
                {
                  var key = (col + dc) + (row + dr) * stride;
                  var cur = marks.get(key);
                  if (cur == null ||
                      y > cur)
                    marks.set(key, y);
                }
          }
      // one small cross per marked corner
      var arm = CityConfig.CELL * ARM;
      for (key in marks.keys())
        {
          var vc = key % stride;
          var vr = Std.int(key / stride);
          var c = cellToWorld(vc, vr);
          var x = c.x - half;
          var z = c.z - half;
          var y = marks.get(key);
          addEdge(pos, idx, x - arm, y, z, x + arm, z);
          addEdge(pos, idx, x, y, z - arm, x, z + arm);
        }
      var geometry = new BufferGeometry();
      geometry.setAttribute('position', new Float32BufferAttribute(pos, 3));
      geometry.setIndex(idx);
      if (mesh == null)
        {
          // normal alpha blend (not additive): additive can only brighten, so alpha reads as
          // dead — this way ALPHA genuinely darkens the marks while GLOW keeps them blooming
          var material = new MeshBasicMaterial({
            color: new Color(0xb46bff).multiplyScalar(GLOW),
            transparent: true,
            opacity: ALPHA,
            depthWrite: false,
            toneMapped: false,
          });
          mesh = new Mesh(geometry, material);
          mesh.renderOrder = 1;
          scene.add(mesh);
          return;
        }
      untyped mesh.geometry.dispose();
      untyped mesh.geometry = geometry;
    }

// append one thin axis-aligned ground quad for a grid edge (two triangles)
  function addEdge(pos:Array<Float>, idx:Array<Int>, x0:Float, y:Float, z0:Float,
      x1:Float, z1:Float):Void
    {
      var base = Std.int(pos.length / 3);
      var w = CityConfig.CELL * WIDTH;
      if (z0 == z1)
        {
          // x-run: widen across z
          pushV(pos, x0, y, z0 - w);
          pushV(pos, x1, y, z0 - w);
          pushV(pos, x1, y, z0 + w);
          pushV(pos, x0, y, z0 + w);
        }
      else
        {
          // z-run: widen across x
          pushV(pos, x0 - w, y, z0);
          pushV(pos, x0 + w, y, z0);
          pushV(pos, x0 + w, y, z1);
          pushV(pos, x0 - w, y, z1);
        }
      // wind counter-clockwise seen from above (+y normal) — the overhead camera culls backfaces
      idx.push(base);
      idx.push(base + 2);
      idx.push(base + 1);
      idx.push(base);
      idx.push(base + 3);
      idx.push(base + 2);
    }

// append one vertex to the position buffer
  inline function pushV(pos:Array<Float>, x:Float, y:Float, z:Float):Void
    {
      pos.push(x);
      pos.push(y);
      pos.push(z);
    }
}
