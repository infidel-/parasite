package render;

import three.Three;
import citygen.CityConfig;
import citygen.CityConfig.cellToWorld;
import game.AreaGame;
import render.world.WorldCtx;

// emissive marks over the cells around the player: one small cross at every shared corner of a
// walkable cell, and a dashed perimeter plus a diagonal hatch over every cell that is NOT passable
// (thin ground quads — WebGL lines are always 1px and can't bloom), HDR-tinted so the bloom pass
// gives them a soft glow without covering the visuals.
//
// the blocked pass exists because the corner marks CANNOT express one: a corner is marked when ANY
// of the four cells touching it is walkable, so an obstacle with open ground around it has all four
// of its own corners marked by its neighbours and draws exactly like grass. measured in a forest
// area, 66 of 83 blocked cells in the window cost the lattice not one mark, and all 83 together
// cost it 11 of 1054 — which is why a boulder, a conifer and a thicket all sat under an unbroken
// grid. only a blob of 2x2 or more drops an interior corner, and one missing cross reads as nothing
class TacticalGrid
{
  static inline var Y = 0.06;
  static inline var WIDTH = 0.015; // cross/dash line half-width (cells)
  static inline var ARM = 0.12;    // cross arm half-length (cells)
  static inline var RADIUS = 16;   // grid extent around the center cell (cells, square)
  static inline var ALPHA = 0.6;   // darkness knob: how much of the ground the marks let through
  // blocked-cell hatch: world-space diagonal line family, so the stripes run CONTINUOUSLY across a
  // multi-cell obstacle instead of restarting inside each cell. thinner than the perimeter dashes so
  // the fill reads as fill and not as a second lattice on top of the corner marks
  static inline var HATCH = 1.0;    // world units between diagonal stripes (CELL / 4 = 7 per cell)
  static inline var HATCH_W = 0.010; // hatch line half-width (cells)
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

// drop the built geometry so the next show rebuilds it in place. the grid is otherwise only rebuilt
// when the player's cell moves, and walkability is not static: an object that blocks its cell
// (a grown organ, a burning barrel) can appear or vanish under a standing player. that used to be
// invisible — a blocked cell drew like open ground either way — and the blocked pass is exactly what
// makes it show, as an outline around nothing or nothing around an obstacle
  public function invalidate():Void
    {
      ccol = -1;
      crow = -1;
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
              {
                blocked(pos, idx, col, row);
                continue;
              }
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
          addSeg(pos, idx, x - arm, z, y, x + arm, z, y, WIDTH);
          addSeg(pos, idx, x, z - arm, y, x, z + arm, y, WIDTH);
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

// one non-passable cell: a dashed line along each edge it shares with a walkable neighbour, plus the
// diagonal hatch inside it. PERIMETER only, like the dashed rectangle render.Occlusion draws around a
// faded building's footprint — dashing every edge would fill the inside of a thicket with a lattice.
// it borrows that rectangle's dash/gap outright, which at 0.6 + 0.4 is exactly four dashes per edge
  function blocked(pos:Array<Float>, idx:Array<Int>, col:Int, row:Int):Void
    {
      // a CITY building is the one blocked cell this skips. its footprint is unpaved (render.world
      // .Ground paves road/alley/walkway only), so the dashes would hang in midair under a solid
      // wall that hides them — and the moment the block DOES fade, which in tactical is the whole
      // selected block, render.Occlusion already draws that identical rectangle a hair above them.
      // what is left over is what actually surprises a player: barrels, objects, blocking decoration
      if (area.getCellType(col, row) == Const.TILE_BUILDING)
        return;
      var half = CityConfig.CELL / 2;
      var c = cellToWorld(col, row);
      var x0 = c.x - half, x1 = c.x + half;
      var z0 = c.z - half, z1 = c.z + half;
      var y = WorldCtx.floorY(col, row) + Y;
      // the four shared edges. the dash rests on the HIGHER of the two cells it divides, the same
      // rule the corner marks take: it lies exactly on the seam, where a city curb steps and
      // WorldCtx.floorYAt would have to pick a side of it by rounding
      if (area.isWalkable(col - 1, row))
        dashes(pos, idx, x0, z0, x0, z1, edgeY(y, col - 1, row));
      if (area.isWalkable(col + 1, row))
        dashes(pos, idx, x1, z0, x1, z1, edgeY(y, col + 1, row));
      if (area.isWalkable(col, row - 1))
        dashes(pos, idx, x0, z0, x1, z0, edgeY(y, col, row - 1));
      if (area.isWalkable(col, row + 1))
        dashes(pos, idx, x0, z1, x1, z1, edgeY(y, col, row + 1));
      // the hatch: every line of the world-space family x + z = k * HATCH that crosses this cell,
      // clipped to it. world-space and not cell-local on purpose — a stripe continues into the next
      // blocked cell instead of stopping at the shared edge, so a thicket hatches as one shape
      var s = Math.ceil((x0 + z0) / HATCH) * HATCH;
      var smax = x1 + z1;
      while (s < smax)
        {
          // the line z = s - x meets the cell over x in [s - z1, s - z0], clipped to the cell's span.
          // under 0.001 of span is a corner graze, where the family's end touches the cell at a point
          var xa = Math.max(x0, s - z1);
          var xb = Math.min(x1, s - z0);
          // sampled per endpoint rather than flat: the stripe lies INSIDE the cell, so out in the
          // wilderness the two ends stand on genuinely different ground and the quad follows the
          // slope between them. in the city floorYAt routes back to this cell's own step
          if (xb - xa >= 0.001)
            addSeg(pos, idx,
              xa, s - xa, WorldCtx.floorYAt(xa, s - xa) + Y,
              xb, s - xb, WorldCtx.floorYAt(xb, s - xb) + Y,
              HATCH_W);
          s += HATCH;
        }
    }

// height of a dash on the seam between the cell it outlines (already lifted, `y`) and its neighbour
  inline function edgeY(y:Float, ncol:Int, nrow:Int):Float
    {
      var ny = WorldCtx.floorY(ncol, nrow) + Y;
      return ny > y ? ny : y;
    }

// walk one cell edge, emitting a dash every dash+gap over its full length
  function dashes(pos:Array<Float>, idx:Array<Int>, x0:Float, z0:Float, x1:Float, z1:Float,
      y:Float):Void
    {
      var dash = RenderConfig.OCCLUSION.outlineDash;
      var gap = RenderConfig.OCCLUSION.outlineGap;
      var dx = x1 - x0, dz = z1 - z0;
      var len = Math.sqrt(dx * dx + dz * dz);
      var ux = dx / len, uz = dz / len;
      var t = 0.0;
      while (t < len)
        {
          var e = t + dash > len ? len : t + dash;
          addSeg(pos, idx, x0 + ux * t, z0 + uz * t, y, x0 + ux * e, z0 + uz * e, y, WIDTH);
          t += dash + gap;
        }
    }

// append one thin ground quad for a segment, widened by `w` (in cells) across its own normal. the
// endpoints carry their own height, so a quad laid over rolling ground follows the slope
  function addSeg(pos:Array<Float>, idx:Array<Int>, x0:Float, z0:Float, y0:Float,
      x1:Float, z1:Float, y1:Float, w:Float):Void
    {
      var base = Std.int(pos.length / 3);
      var dx = x1 - x0, dz = z1 - z0;
      var len = Math.sqrt(dx * dx + dz * dz);
      var hw = CityConfig.CELL * w / len;
      var nx = dz * hw, nz = -dx * hw;
      pushV(pos, x0 + nx, y0, z0 + nz);
      pushV(pos, x1 + nx, y1, z1 + nz);
      pushV(pos, x1 - nx, y1, z1 - nz);
      pushV(pos, x0 - nx, y0, z0 - nz);
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
