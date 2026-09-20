package render.corp;

import three.Three;
import _Room;
import citygen.CityConfig;
import render.Textures;
import render.particles.LampPost;
import render.particles.Sprites;
import render.facility.FacilityGeom;
import render.facility.FacilityModel;
import render.facility.FacilityModel.DoorCell;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// what the rig placed, for __corp()
typedef CorpLampSet = {
  var posts:Array<LampPost>;   // every fixture, straight into the shared 12-slot spotlight pool
  var rooms:Int;               // how many of them are a room lattice point
  var panels:Int;              // recessed panel quads in the glow mesh
  var pools:Int;               // and floor pools under them
  var calls:Int;               // lit lift-call plates
};

// the corp tower's light SOURCES and everything additive they put on a surface — one file, because
// a fixture and the panel drawn where it hangs are the same decision and two files would drift.
//
// THIS IS THE PHASE THE PLATE WAS WAITING FOR. render.corp.CorpArea has handed
// render.particles.LampLights an EMPTY post list since phase 2, so an entire floor of offices was
// lit by render.world.IndoorMask's flat ambient and nothing else — every screenshot of phases 2
// through 6 is of an unlit building. The fixtures below are the first real light in it.
//
// TWO FAMILIES, FOUND TWO DIFFERENT WAYS, which is the compound's own split and holds here for the
// same reason: a ROOM is a rect in area.generatorInfo and takes a lattice over it, while
// CIRCULATION is in no list at all — it is whatever carpet is left over — and has to be scanned off
// the grid.
//
// NOTHING FLICKERS and nothing moves, so the per-frame cost of this whole file is one
// LampLights.update call and no cone repack.
class CorpLamps
{
  static inline var CELL = CityConfig.CELL;

  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

// the whole rig: the fixtures, and the one additive mesh everything they throw is merged into
  public static function build(scene:Scene, m:Facility):CorpLampSet
    {
      var b = MeshBufTools.make();
      var out:CorpLampSet = {
        posts: [],
        rooms: 0,
        panels: 0,
        pools: 0,
        calls: 0,
      };
      lattice(m, b, out);
      corridors(m, b, out);
      calls(m, b, out);
      add(scene, b);
      return out;
    }

// a fixture lattice over every room rect, and the panel and floor pool each one draws.
//
// the rect is INCLUSIVE of x2/y2 (see _Room), so a room's far edge is that cell's far boundary and
// not its centre. the (i + 0.5) / n spacing is the compound's: it spreads a fixed count along the
// run instead of taking them off its head, so a room under ROOM_SPACING falls to one point on its
// own centre rather than one point against its wall
  static function lattice(m:Facility, b:MeshBuf, out:CorpLampSet):Void
    {
      for (r in m.rooms)
        {
          var nx = Math.ceil(r.w / CorpStyle.ROOM_SPACING);
          var ny = Math.ceil(r.h / CorpStyle.ROOM_SPACING);
          for (i in 0...nx)
            for (j in 0...ny)
              {
                var col = r.x1 + Std.int((i + 0.5) * r.w / nx);
                var row = r.y1 + Std.int((j + 0.5) * r.h / ny);
                // a lattice point can land on a cubicle spine or a server rack, which the rect
                // does not know about. nudged off it rather than dropped — a room is entitled to
                // its fitting and a partition is 1.4 m tall
                var q = free(m, r, col, row);
                if (q == null)
                  continue;
                var c = CityConfig.cellToWorld(q.col, q.row);
                out.posts.push(post(c.x, c.z, q.col, q.row, CorpStyle.CEIL_MUL));
                out.rooms++;
                // the fitting itself, its long axis along the room's
                var pw = (r.w >= r.h ? CorpStyle.PANEL_W : CorpStyle.PANEL_H) / 2;
                var pd = (r.w >= r.h ? CorpStyle.PANEL_H : CorpStyle.PANEL_W) / 2;
                flat(b, c.x - pw, c.x + pw, c.z - pd, c.z + pd,
                  CorpStyle.CEIL_Y - CorpStyle.PANEL_DROP, CorpStyle.C_PANEL);
                out.panels++;
              }
          // and ONE pool over the room's whole rect rather than one per lattice point: two pools
          // overlapping in an additive mesh is twice the brightness down the strip they share, and
          // a room is lit evenly by a ceiling grid whatever its count
          if (out.panels == 0)
            continue;
          var lo = CityConfig.cellToWorld(r.x1, r.y1);
          var hi = CityConfig.cellToWorld(r.x2, r.y2);
          var e = CorpStyle.POOL_INSET;
          flat(b, lo.x - CELL / 2 + e, hi.x + CELL / 2 - e,
            lo.z - CELL / 2 + e, hi.z + CELL / 2 - e, CorpStyle.GLOW_Y, CorpStyle.C_POOL);
          out.pools++;
        }
    }

// a fixture down the circulation, which no room rect can reach.
//
// row-major greedy against a spacing test, and it looks for no RUNS first: a corridor on a floor
// plate is an L, a T and a ring as often as it is a straight length, so the thing a run-finder
// would deal in does not exist. Taking the first cell far enough from everything already placed
// covers any of those shapes and reads only the saved grid
  static function corridors(m:Facility, b:MeshBuf, out:CorpLampSet):Void
    {
      var seen = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            // the circulation surface AND the lift lobby, and never a doorway: a door cell carries
            // the corridor's own finish whichever way it faces (FacilityGeom paints its reveal in
            // it), and is a piece of circulation rather than somewhere to hang a fitting
            var s = m.surf[row][col];
            if (!FacilityModel.inside(m, col, row) ||
                (s != Surf.CARPET && s != Surf.LIFT) ||
                !FacilityModel.isInterior(m, col, row) ||
                FacilityModel.isDoor(m, col, row) ||
                near(seen, col, row))
              continue;
            seen.push({
              col: col,
              row: row,
            });
            var c = CityConfig.cellToWorld(col, row);
            out.posts.push(post(c.x, c.z, col, row, CorpStyle.CORR_MUL));
            var pw = CorpStyle.PANEL_W / 2;
            var pd = CorpStyle.PANEL_H / 2;
            // the panel lies along the passage, which is whichever of its two runs is LONGER —
            // the shorter one is the cross-section
            var alongX = run(m, col, row, true) >= run(m, col, row, false);
            flat(b, c.x - (alongX ? pw : pd), c.x + (alongX ? pw : pd),
              c.z - (alongX ? pd : pw), c.z + (alongX ? pd : pw),
              CorpStyle.CEIL_Y - CorpStyle.PANEL_DROP, CorpStyle.C_PANEL);
            out.panels++;
            flat(b, c.x - CELL / 2, c.x + CELL / 2, c.z - CELL / 2, c.z + CELL / 2,
              CorpStyle.GLOW_Y, CorpStyle.C_POOL);
            out.pools++;
          }
    }

// the lit call plate beside every lift door.
//
// A SECOND COLOUR IN ONE MESH, which is what the per-vertex brightness channel cannot do on its
// own — so the plate's quads carry a brightness scaled by the RATIO between the two colours, and
// one additive material draws both. It is right whatever colour space `new Color` works in, both
// terms being in the same one. The compound does exactly this for its warm bulkhead lamp
  static function calls(m:Facility, b:MeshBuf, out:CorpLampSet):Void
    {
      var warm = ratio();
      for (d in m.doors)
        {
          // a LIFT door and no other: the plate is the thing that says which of the openings off
          // the lobby is the car, which is the one question a lift lobby asks
          if (!lift(m, d))
            continue;
          var c = CityConfig.cellToWorld(d.col, d.row);
          var s = FacilityGeom.slab(m, d.col, d.row);
          var w = CorpStyle.CALL_W / 2;
          var y0 = CorpStyle.CALL_Y - CorpStyle.CALL_H / 2;
          var y1 = CorpStyle.CALL_Y + CorpStyle.CALL_H / 2;
          var e = CorpStyle.SIGN_PROUD;
          // beside the opening, on the LOBBY side of it — `inDir` points at the side the leaves
          // swing into, and the side a call button is pressed from is the one that is not the car
          for (side in [-1, 1])
            {
              if (d.alongX)
                {
                  var z = (d.inDir > 0 ? s.z0 - e : s.z1 + e);
                  quad(b, [c.x + side * CorpStyle.CALL_OFF - w, y0, z],
                    [c.x + side * CorpStyle.CALL_OFF + w, y0, z],
                    [c.x + side * CorpStyle.CALL_OFF + w, y1, z],
                    [c.x + side * CorpStyle.CALL_OFF - w, y1, z],
                    CorpStyle.C_CALL * warm);
                }
              else
                {
                  var x = (d.inDir > 0 ? s.x0 - e : s.x1 + e);
                  quad(b, [x, y0, c.z + side * CorpStyle.CALL_OFF - w],
                    [x, y0, c.z + side * CorpStyle.CALL_OFF + w],
                    [x, y1, c.z + side * CorpStyle.CALL_OFF + w],
                    [x, y1, c.z + side * CorpStyle.CALL_OFF - w],
                    CorpStyle.C_CALL * warm);
                }
              out.calls++;
            }
        }
    }

// is this opening a lift car door — an opening with the lift core on one side of it?
  static function lift(m:Facility, d:DoorCell):Bool
    {
      for (s in [-1, 1])
        {
          var c = d.col + (d.alongX ? 0 : s);
          var r = d.row + (d.alongX ? s : 0);
          if (FacilityModel.inside(m, c, r) &&
              m.surf[r][c] == Surf.LIFT)
            return true;
        }
      return false;
    }

// the warm plate's colour as a MULTIPLIER on the mesh's own, so one additive material draws two
// lights. cached because it is three divisions and is asked once per opening
  static var _warm:Float = -1.0;

  static function ratio():Float
    {
      if (_warm >= 0)
        return _warm;
      var a = new Color(CorpStyle.LAMP_COLOR);
      var w = new Color(CorpStyle.CALL_COLOR);
      // on the LUMINANCE, which is the one scalar a per-vertex grey can carry — a hue really does
      // need its own material and the plate is 0.5 world units across
      _warm = (0.2126 * w.r + 0.7152 * w.g + 0.0722 * w.b) /
        (0.2126 * a.r + 0.7152 * a.g + 0.0722 * a.b);
      return _warm;
    }

// one fixture, aimed straight down. `col`/`row` and not the shifted point: that pair is what
// LampLights sorts the pool on and what IndoorMask.indoorAt reads to keep an indoor lamp out of the
// outdoor fake-shadow list
  static inline function post(x:Float, z:Float, col:Int, row:Int, mul:Float):LampPost
    {
      return {
        x: x,
        z: z,
        y: CorpStyle.CEIL_Y,
        tx: x,
        tz: z,
        color: CorpStyle.LAMP_COLOR,
        col: col,
        row: row,
        phase: 0.0,
        flick: 1.0,
        mul: mul,
      };
    }

// is there already a fitting within CORR_SPACING cells of here?
  static function near(seen:Array<{ col:Int, row:Int }>, col:Int, row:Int):Bool
    {
      for (s in seen)
        if (Math.abs(s.col - col) + Math.abs(s.row - row) < CorpStyle.CORR_SPACING)
          return true;
      return false;
    }

// how far the open floor runs through this cell on one axis, in cells
  static function run(m:Facility, col:Int, row:Int, alongX:Bool):Int
    {
      var dc = (alongX ? 1 : 0);
      var dr = (alongX ? 0 : 1);
      var n = 1;
      var i = 1;
      while (open(m, col - i * dc, row - i * dr))
        {
          n++;
          i++;
        }
      i = 1;
      while (open(m, col + i * dc, row + i * dr))
        {
          n++;
          i++;
        }
      return n;
    }

  static inline function open(m:Facility, col:Int, row:Int):Bool
    {
      return FacilityModel.inside(m, col, row) &&
        !FacilityModel.isWall(m, col, row);
    }

// the nearest cell of the room that a fitting may hang over: the point itself, or one step off it
// if a partition or a rack is standing there
  static function free(m:Facility, r:_Room, col:Int, row:Int):{ col:Int, row:Int }
    {
      for (d in 0...5)
        {
          var c = (d == 0 ? col : col + DC[d - 1]);
          var w = (d == 0 ? row : row + DR[d - 1]);
          if (c < r.x1 ||
              c > r.x2 ||
              w < r.y1 ||
              w > r.y2 ||
              !FacilityModel.inside(m, c, w))
            continue;
          if (!FacilityModel.isWall(m, c, w) &&
              m.fit[w][c] == 0)
            return {
              col: c,
              row: w,
            };
        }
      return null;
    }

// one horizontal quad at height y — a recessed panel over the floor, or the pool under it
  static function flat(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, y:Float, c:Float):Void
    {
      if (x1 - x0 < 0.01 ||
          z1 - z0 < 0.01)
        return;
      quad(b, [x0, y, z1], [x1, y, z1], [x1, y, z0], [x0, y, z0], c);
    }

// one quad with its own 0..1 uv, so the shared gradient fits it whatever its size, and a flat
// per-vertex brightness
  static inline function quad(b:MeshBuf, p0:Array<Float>, p1:Array<Float>, p2:Array<Float>,
      p3:Array<Float>, c:Float):Void
    MeshBufTools.quadC(b, p0, p1, p2, p3, [0, 0, 1, 0, 1, 1, 0, 1], [c, c, c, c]);

// the whole glow layer as ONE additive mesh. render.facility.FacilityGlow.add's material exactly,
// for its reasons: the vision mask is not decoration here (hiddenAdd is 0.0, so a glow the player
// cannot see is cut to a true zero rather than dimmed — without it every lit room shines through
// its own walls), and the render order is below the actors because nothing in the sprite pool
// writes depth, so a glow drawn at their order paints its core through anyone in front of it
  static function add(scene:Scene, b:MeshBuf):Void
    {
      if (b.idx.length == 0)
        return;
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(b.pos, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(b.uv, 2));
      geo.setAttribute('color', new Float32BufferAttribute(b.col, 3));
      geo.setIndex(b.idx);
      var mesh = new Mesh(geo, VisionMask.patch(new MeshBasicMaterial({
        color: new Color(CorpStyle.LAMP_COLOR).multiplyScalar(CorpStyle.GLOW),
        transparent: true,
        alphaMap: Textures.makeRectGlowGradient(0.0),
        vertexColors: true,
        depthWrite: false,
        side: THREE.DoubleSide,
        blending: untyped THREE.AdditiveBlending,
      })));
      mesh.renderOrder = Sprites.ORD_FIXTURE;
      scene.add(mesh);
    }
}
