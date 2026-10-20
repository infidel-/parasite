package render.cave;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.cave.CaveProps.CaveGlow;
import render.sewer.SewerModel;
import render.sewer.SewerModel.Sewer;
import render.world.VisionMask;
import gen.cave.CaveField;

// one welded, indexed mesh under construction
private typedef CaveBuf = {
  pos:Array<Float>,   // xyz per vertex
  uv:Array<Float>,    // uv per vertex
  col:Array<Float>,   // rgb per vertex (the tint and the baked contact shading)
  idx:Array<Int>,     // triangle indices
  keys:Map<Int, Int>, // lattice / edge key -> vertex index, so neighbouring field cells share their verts
}

// one point of a field cell's marching-squares walk: a lattice corner or an iso crossing on an edge
private typedef CavePt = {
  key:Int,    // corner or edge key (see cornerKey / edgeKey), what welds it to the next cell's copy
  u:Float,    // position in cells
  v:Float,
  d:Float,    // field less ISO: > 0 floor side, < 0 rock, 0 on a crossing
  cross:Bool, // an iso crossing rather than a corner
  exit:Bool,  // a crossing where the walk leaves the floor (an iso segment starts here)
}

// static SHELL of the mountain cave, from the habitat's floor grid: NO 90 degree walls. the floor
// grid is blurred into a field (gen.cave.CaveField), roughened with smooth noise, and cut at its ISO
// by marching squares on a lattice of CaveField.SAMPLES points per cell — so the outline rounds every
// corner, runs diagonally across every step of the grid, wanders, and (the invariant everything else
// rests on) only ever eats into ROCK cells: the field on any walkable cell stays above ISO, so a cell
// the player can stand on is never drawn under rock.
// three welded meshes, one draw call each: the floor, the wall strip stood up along every outline
// loop, and the rock tops that meet the wall's lip exactly. nothing fades, so everything merges, as
// in the tunnels
class CaveGeom
{
  static inline var CELL = CityConfig.CELL;
  // each glow colour in linear light, once (glow() runs per vertex)
  static var linear = new Map<Int, Color>();

// build every cave surface into the scene
  public static function build(scene:Scene, m:Sewer):Void
    {
      var s = CaveField.SAMPLES;
      var lw = m.w * s + 1; // lattice points across
      var lh = m.h * s + 1;
      var half = (CityConfig.GRID * CELL) / 2;
      var isFloor = function(col:Int, row:Int) return SewerModel.isFloor(m, col, row);

      // the field at every lattice point, less ISO. never exactly 0: a corner on the line would put a
      // crossing on top of it and a zero-area triangle beside it
      var d = new haxe.ds.Vector<Float>(lw * lh);
      for (j in 0...lh)
        for (i in 0...lw)
          {
            var v = CaveField.field(isFloor, i / s, j / s) - CaveField.ISO;
            d[j * lw + i] = (Math.abs(v) < 1e-6 ? -1e-6 : v);
          }

      var floor = newBuf();
      var top = newBuf();
      // the iso segments, exit crossing key -> entry crossing key (floor on the right), and every
      // crossing's position for the loop walk
      var next = new Map<Int, Int>();
      var at = new Map<Int, CavePt>();

      for (j in 0...lh - 1)
        for (i in 0...lw - 1)
          {
            // the four corners clockwise from above (+x, then +z), and the edge each one starts
            var ci = [ i, i + 1, i + 1, i ];
            var cj = [ j, j, j + 1, j + 1 ];
            var walk:Array<CavePt> = [];
            var crossings = 0;
            for (k in 0...4)
              {
                var k2 = (k + 1) % 4;
                var dk = d[cj[k] * lw + ci[k]];
                var dn = d[cj[k2] * lw + ci[k2]];
                walk.push({
                  key: cornerKey(ci[k], cj[k], lw),
                  u: ci[k] / s,
                  v: cj[k] / s,
                  d: dk,
                  cross: false,
                  exit: false,
                });
                if ((dk > 0) == (dn > 0))
                  continue;
                var t = dk / (dk - dn);
                walk.push({
                  key: edgeKey(ci[k], cj[k], ci[k2], cj[k2], lw),
                  u: (ci[k] + t * (ci[k2] - ci[k])) / s,
                  v: (cj[k] + t * (cj[k2] - cj[k])) / s,
                  d: 0.0,
                  cross: true,
                  exit: (dk > 0),
                });
                crossings++;
              }

            // all floor or all rock: one quad
            if (crossings == 0)
              {
                if (walk[0].d > 0)
                  polygon(floor, walk, half, true);
                else polygon(top, walk, half, false);
                continue;
              }

            for (p in walk)
              if (p.cross)
                at.set(p.key, p);
            if (crossings == 2)
              {
                // one iso segment: the floor polygon walks the floor corners and both crossings, the
                // rock polygon the rest, and the segment runs exit -> entry with the floor on its right
                polygon(floor, [for (p in walk) if (p.cross || p.d > 0) p], half, true);
                polygon(top, [for (p in walk) if (p.cross || p.d <= 0) p], half, false);
                var ex = null;
                var en = null;
                for (p in walk)
                  if (p.cross)
                    {
                      if (p.exit)
                        ex = p;
                      else en = p;
                    }
                next.set(ex.key, en.key);
                continue;
              }

            // a saddle: floor on two opposite corners. the cell centre decides which side connects
            saddle(floor, top, next, walk, half,
              CaveField.field(isFloor, (i + 0.5) / s, (j + 0.5) / s) > CaveField.ISO);
          }

      var walls = newBuf();
      for (loop in loops(next, at))
        wall(walls, loop, half);

      var glows = CaveProps.glows(m);
      add(scene, floor, CaveStyle.FLOOR, false, glows);
      add(scene, top, CaveStyle.ROCKTOP, false, glows);
      add(scene, walls, CaveStyle.WALL, true, glows);
      CavePatches.build(scene, m, glows);
      decals(scene, m);
      CaveBeams.build(scene, m);
    }

// push one vertex's colour: its value `c`, lit by every glowing piece in reach (asked for: "we lack any
// interesting lighting"). the pooled spotlights (render.cave.CaveScene) give the near light, its
// direction and its shadows, but only while the player is near and the pool is on; this is the wide,
// soft spill, baked: a falloff over GLOW_R, keyed on the face's normal (wrapped, so a face turned away
// still takes a little), in the light's own colour. no draw call, no program, every light setting
  public static function glow(glows:Array<CaveGlow>, x:Float, y:Float, z:Float, nx:Float, ny:Float,
      nz:Float, c:Float, col:Array<Float>):Void
    {
      var r = 1.0;
      var g = 1.0;
      var b = 1.0;
      for (s in glows)
        {
          var lx = s.x - x;
          var ly = s.top * CaveStyle.GLOW_Y - y;
          var lz = s.z - z;
          var d = Math.sqrt(lx * lx + ly * ly + lz * lz);
          if (d >= CaveStyle.GLOW_R)
            continue;
          var ndl = (d > 0 ? (nx * lx + ny * ly + nz * lz) / d : 1.0);
          var wrap = Math.max(0, (ndl + CaveStyle.GLOW_WRAP) / (1 + CaveStyle.GLOW_WRAP));
          var fall = (1 - d / CaveStyle.GLOW_R) * (1 - d / CaveStyle.GLOW_R);
          var k = s.light.glow * fall * wrap;
          var lc = linear.get(s.light.color);
          if (lc == null)
            {
              lc = new Color(s.light.color);
              linear.set(s.light.color, lc);
            }
          r += lc.r * k;
          g += lc.g * k;
          b += lc.b * k;
        }
      col.push(c * r);
      col.push(c * g);
      col.push(c * b);
    }

// the floor decals, here rather than in CaveArea so the warm (render.cave.CaveWarm, which runs this
// builder) compiles their program too: grime, crust and fungus over the whole floor, moss only near
// the mouths. the sewer floor's scatter, which reads nothing but the floor/room grid
  static function decals(scene:Scene, m:Sewer):Void
    {
      render.sewer.SewerGround.scatter(scene, m, {
        types: [
          {
            tex: CaveStyle.FLOOR_GUANO,
            w: 2.4,
            d: 2.2,
            alpha: 0.85,
            organic: true,
          },
          {
            tex: CaveStyle.FLOOR_CRUST,
            w: 2.0,
            d: 1.8,
            alpha: 1.0,
            organic: true,
          },
          {
            tex: CaveStyle.FLOOR_FUNGUS,
            w: 1.8,
            d: 1.8,
            alpha: 1.0,
            organic: true,
          },
        ],
        pct: CaveStyle.DECAL_PCT,
        y: CaveStyle.DECAL_Y,
        margin: 0.2,
        solid: false,
        cross: true,
      });
      render.sewer.SewerGround.scatter(scene, m, {
        types: [
          {
            tex: CaveStyle.FLOOR_MOSS,
            w: 2.2,
            d: 2.0,
            alpha: 1.0,
            organic: true,
          },
        ],
        pct: CaveStyle.MOSS_PCT,
        y: CaveStyle.DECAL_Y,
        margin: 0.2,
        solid: false,
        cross: true,
        near: function(col, row)
          {
            for (l in m.lamps)
              if (Math.abs(l.col - col) <= CaveStyle.MOSS_REACH &&
                  Math.abs(l.row - row) <= CaveStyle.MOSS_REACH)
                return true;
            return false;
          },
      });
    }

// height of the rock top at (u, v) in cells, given the field less ISO there (<= 0): WALL_H, less a
// smooth sag, less the rounded lip near the outline. downward only — WALL_H is the camera clearance
  public static function topY(u:Float, v:Float, fd:Float):Float
    {
      var sag = (CaveField.noise(u / 2.1, v / 2.1, 1) * 0.5 + 0.5) * CaveStyle.SAG;
      var lip = 1 - CaveField.smooth(0, CaveStyle.RIM_W, -fd);
      return CaveStyle.WALL_H - sag - CaveStyle.RIM * lip;
    }

// the floor's baked value at (u, v) in cells, given the field less ISO there: the shared tint, darkened
// along the walls. public for render.cave.CavePatches, whose overlays take the same value or glow at
// the wall foot
  public static function floorShade(u:Float, v:Float, fd:Float):Float
    {
      return tint(u, v) *
        (CaveStyle.SHADOW + (1 - CaveStyle.SHADOW) * CaveField.smooth(0, CaveStyle.SHADOW_W, fd));
    }

// the value tint every surface shares: smooth noise either side of 1, keyed off world position so
// the floor, the wall foot and the rock lip agree where they meet
  static inline function tint(u:Float, v:Float):Float
    return 1.0 + CaveField.noise(u * 0.8, v * 0.8, 2) * CaveStyle.TINT_AMP;

// a saddle cell: floor corners 0 and 2 (or 1 and 3), rock on the other two. with the centre on the
// floor side the floor is one hexagon and each rock corner a triangle cut off by its own segment; with
// it on the rock side the other way round
  static function saddle(floor:CaveBuf, top:CaveBuf, next:Map<Int, Int>, walk:Array<CavePt>,
      half:Float, centreFloor:Bool)
    {
      var n = walk.length;
      if (centreFloor)
        polygon(floor, walk.filter(function(p) return p.cross || p.d > 0), half, true);
      else polygon(top, walk.filter(function(p) return p.cross || p.d <= 0), half, false);
      for (k in 0...n)
        {
          var p = walk[k];
          if (p.cross)
            continue;
          var before = walk[(k + n - 1) % n];
          var after = walk[(k + 1) % n];
          // a rock corner cut off the floor hexagon, or a floor corner cut off the rock one
          if (centreFloor &&
              p.d <= 0)
            {
              polygon(top, [ before, p, after ], half, false);
              next.set(before.key, after.key);
            }
          else if (!centreFloor &&
              p.d > 0)
            {
              polygon(floor, [ before, p, after ], half, true);
              next.set(after.key, before.key);
            }
        }
    }

// one convex polygon of a field cell, clockwise from above, fanned into the buffer: the floor flat at
// 0 and darkened along the walls by its field, the rock top at topY
  static function polygon(b:CaveBuf, pts:Array<CavePt>, half:Float, isFloor:Bool)
    {
      var ids = [];
      for (p in pts)
        {
          var id = b.keys.get(p.key);
          if (id == null)
            {
              var x = p.u * CELL - half;
              var z = p.v * CELL - half;
              var y = 0.0;
              var c = (isFloor ? floorShade(p.u, p.v, p.d) : tint(p.u, p.v));
              if (!isFloor)
                y = topY(p.u, p.v, p.d);
              var t = (isFloor ? CaveStyle.FLOOR_TILE : CaveStyle.TOP_TILE);
              id = vertex(b, x, y, z, x / t, z / t, c);
              b.keys.set(p.key, id);
            }
          ids.push(id);
        }
      // clockwise from above, so the fan is wound back to face +y
      for (k in 1...ids.length - 1)
        {
          b.idx.push(ids[0]);
          b.idx.push(ids[k + 1]);
          b.idx.push(ids[k]);
        }
    }

// walk the iso segments into closed loops of crossings, each with the floor on its right
  static function loops(next:Map<Int, Int>, at:Map<Int, CavePt>):Array<Array<CavePt>>
    {
      var done = new Map<Int, Bool>();
      var list = [];
      // keys sorted, so a level's loops and their arc-length seams come out the same every build
      var starts = [for (k in next.keys()) k];
      starts.sort(function(a, b) return a - b);
      for (k0 in starts)
        {
          if (done.exists(k0))
            continue;
          var loop = [];
          var k = k0;
          while (k != null &&
              !done.exists(k))
            {
              done.set(k, true);
              loop.push(at.get(k));
              k = next.get(k);
            }
          if (loop.length >= 3)
            list.push(loop);
        }
      return list;
    }

// stand the wall up along one outline loop: WALL_ROWS rows from the floor to the rock top's lip,
// the middle rows bulging back into the rock (and a little out) by smooth noise, the foot and the lip
// exactly on the outline so the floor and the top meet it. u runs along the loop's arc length, so
// the strata never stretch; one seam where the loop closes
  static function wall(b:CaveBuf, loop:Array<CavePt>, half:Float)
    {
      var n = loop.length;
      var rows = CaveStyle.WALL_ROWS;
      var bulge = CaveStyle.WALL_BULGE;
      var r = rows.length;
      var arc = 0.0;
      var base = Std.int(b.pos.length / 3);
      for (i in 0...n + 1)
        {
          var p = loop[i % n];
          var prev = loop[(i + n - 1) % n];
          var nxt = loop[(i + 1) % n];
          if (i > 0)
            arc += Math.sqrt((p.u - prev.u) * (p.u - prev.u) + (p.v - prev.v) * (p.v - prev.v)) * CELL;
          // the floor-side normal: right of the direction of travel, seen from above
          var tx = nxt.u - prev.u;
          var tz = nxt.v - prev.v;
          var tl = Math.sqrt(tx * tx + tz * tz);
          var nx = (tl > 0 ? -tz / tl : 0.0);
          var nz = (tl > 0 ? tx / tl : 0.0);
          var x = p.u * CELL - half;
          var z = p.v * CELL - half;
          var lipY = topY(p.u, p.v, 0);
          var c = tint(p.u, p.v);
          // the closing column stands where the first one does, so it bulges by the first one's noise
          // (its u carries on to the full arc length, which is the seam)
          var at = (i == n ? 0.0 : arc);
          for (k in 0...r)
            {
              var y = lipY * rows[k];
              var w = CaveField.noise(at / 3.0, k * 0.9, 3);
              var off = (w > 0 ? w * CaveStyle.BULGE : w * CaveStyle.BULGE_OUT) * bulge[k];
              var shade = (k == 0 ? CaveStyle.TINT_FOOT : k == 1 ? CaveStyle.TINT_LOW : 1.0);
              vertex(b, x - nx * off, y, z - nz * off,
                arc / CaveStyle.WALL_TILE, y / CaveStyle.WALL_TILE, c * shade);
            }
        }
      // quads between neighbouring columns, wound to face the floor (right of travel)
      for (i in 0...n)
        for (k in 0...r - 1)
          {
            var a0 = base + i * r + k;
            var b0 = base + (i + 1) * r + k;
            b.idx.push(a0);
            b.idx.push(b0);
            b.idx.push(b0 + 1);
            b.idx.push(a0);
            b.idx.push(b0 + 1);
            b.idx.push(a0 + 1);
          }
    }

// append one vertex, return its index
  static function vertex(b:CaveBuf, x:Float, y:Float, z:Float, u:Float, v:Float, c:Float):Int
    {
      var id = Std.int(b.pos.length / 3);
      b.pos.push(x);
      b.pos.push(y);
      b.pos.push(z);
      b.uv.push(u);
      b.uv.push(v);
      b.col.push(c);
      b.col.push(c);
      b.col.push(c);
      return id;
    }

// a lattice corner's weld key
  static inline function cornerKey(i:Int, j:Int, lw:Int):Int
    return (j * lw + i) * 3;

// an edge's weld key, whichever way round it was walked: horizontal edges off their west end,
// vertical off their north end
  static inline function edgeKey(i1:Int, j1:Int, i2:Int, j2:Int, lw:Int):Int
    {
      var i = (i1 < i2 ? i1 : i2);
      var j = (j1 < j2 ? j1 : j2);
      return (j * lw + i) * 3 + (j1 == j2 ? 1 : 2);
    }

  static function newBuf():CaveBuf
    {
      return {
        pos: [],
        uv: [],
        col: [],
        idx: [],
        keys: new Map(),
      };
    }

// turn one buffer into a single lit mesh: Lambert with the vertex tint and the baked glow over it,
// FrontSide (every face is wound toward the camera side it is seen from), vision-masked
  static function add(scene:Scene, b:CaveBuf, tex:String, casts:Bool, glows:Array<CaveGlow>):Void
    {
      if (b.idx.length == 0)
        return;
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(b.pos, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(b.uv, 2));
      geo.setIndex(b.idx);
      geo.computeVertexNormals();
      // the glow wants the welded normals, so the colour goes on after them
      var nor:Array<Float> = untyped geo.getAttribute('normal').array;
      var col = [];
      for (i in 0...Std.int(b.pos.length / 3))
        glow(glows, b.pos[i * 3], b.pos[i * 3 + 1], b.pos[i * 3 + 2], nor[i * 3], nor[i * 3 + 1],
          nor[i * 3 + 2], b.col[i * 3], col);
      geo.setAttribute('color', new Float32BufferAttribute(col, 3));
      var mesh = new Mesh(geo, VisionMask.patch(new MeshLambertMaterial({
        map: Textures.loadTexture(tex, 'wall', 1),
        side: THREE.FrontSide,
        vertexColors: true,
      })));
      mesh.receiveShadow = true;
      mesh.castShadow = casts;
      scene.add(mesh);
    }
}
