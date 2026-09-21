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
      // THE CEILING IS ITS OWN MESH, and the reason is the render order `add` documents. Nothing
      // in the sprite pool writes depth, so a surface fixture drawn AFTER the actors paints
      // through anyone standing in front of it — which is why the floor pools are below them. A recessed CEILING PANEL is the opposite case: it hangs at 5.75 over
      // everyone's head and nearer the camera than they are, so an actor walking under one was
      // being painted over the light. render.LightCone's additive volume already sits above the
      // actors for exactly this, and Sprites' own header names it
      var bc = MeshBufTools.make();
      var out:CorpLampSet = {
        posts: [],
        rooms: 0,
        panels: 0,
        pools: 0,
      };
      lattice(m, b, bc, out);
      corridors(m, b, bc, out);
      add(scene, b, Sprites.ORD_FIXTURE);
      add(scene, bc, Sprites.ORD_ACTOR + 1);
      return out;
    }

// a fixture lattice over every room rect, and the panel and floor pool each one draws.
//
// the rect is INCLUSIVE of x2/y2 (see _Room), so a room's far edge is that cell's far boundary and
// not its centre. the (i + 0.5) / n spacing is the compound's: it spreads a fixed count along the
// run instead of taking them off its head, so a room under ROOM_SPACING falls to one point on its
// own centre rather than one point against its wall
  static function lattice(m:Facility, b:MeshBuf, bc:MeshBuf, out:CorpLampSet):Void
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
                flat(bc, c.x - pw, c.x + pw, c.z - pd, c.z + pd,
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
  static function corridors(m:Facility, b:MeshBuf, bc:MeshBuf, out:CorpLampSet):Void
    {
      var seen = [];
      carLamp(m, b, bc, out, seen);
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
            flat(bc, c.x - (alongX ? pw : pd), c.x + (alongX ? pw : pd),
              c.z - (alongX ? pd : pw), c.z + (alongX ? pd : pw),
              CorpStyle.CEIL_Y - CorpStyle.PANEL_DROP, CorpStyle.C_PANEL);
            out.panels++;
            flat(b, c.x - CELL / 2, c.x + CELL / 2, c.z - CELL / 2, c.z + CELL / 2,
              CorpStyle.GLOW_Y, CorpStyle.C_POOL);
            out.pools++;
          }
    }

// the lift car's own fixture, ON ITS CENTRE, dealt before the greedy walk and pushed into `seen`
// so that walk cannot deal a second one beside it.
//
// `corridors` is row-major greedy against a spacing test, which is right for an L-shaped corridor
// and wrong for a 3 x 3 room: it took the car's LOWEST-ROW, LOWEST-COL cell and `near` then
// blocked the other eight, so the one light in the lift hung a whole cell — 4 world units —
// diagonally off the middle of a car the player stands in the middle of. The car is the one piece
// of circulation whose shape is known, so it is the one piece worth naming
  static function carLamp(m:Facility, b:MeshBuf, bc:MeshBuf, out:CorpLampSet,
      seen:Array<{ col:Int, row:Int }>):Void
    {
      var c0 = m.w;
      var c1 = -1;
      var r0 = m.h;
      var r1 = -1;
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.surf[row][col] != Surf.LIFT ||
                !FacilityModel.inside(m, col, row))
              continue;
            if (col < c0) c0 = col;
            if (col > c1) c1 = col;
            if (row < r0) r0 = row;
            if (row > r1) r1 = row;
          }
      if (c1 < 0)
        return;
      var col = Std.int((c0 + c1) / 2);
      var row = Std.int((r0 + r1) / 2);
      seen.push({
        col: col,
        row: row,
      });
      var c = CityConfig.cellToWorld(col, row);
      out.posts.push(post(c.x, c.z, col, row, CorpStyle.CORR_MUL));
      var pw = CorpStyle.PANEL_W / 2;
      var pd = CorpStyle.PANEL_H / 2;
      flat(bc, c.x - pw, c.x + pw, c.z - pd, c.z + pd,
        CorpStyle.CEIL_Y - CorpStyle.PANEL_DROP, CorpStyle.C_PANEL);
      out.panels++;
      // and the pool over the WHOLE car rather than one cell of it, the same rule the room
      // lattice follows: one pool per space, never one per fixture
      var lo = CityConfig.cellToWorld(c0, r0);
      var hi = CityConfig.cellToWorld(c1, r1);
      flat(b, lo.x - CELL / 2, hi.x + CELL / 2, lo.z - CELL / 2, hi.z + CELL / 2,
        CorpStyle.GLOW_Y, CorpStyle.C_POOL);
      out.pools++;
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
  static function add(scene:Scene, b:MeshBuf, order:Float):Void
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
      mesh.name = 'corp lamps ' + (order > render.particles.Sprites.ORD_FIXTURE ?
        'ceiling' : 'floor');
      mesh.renderOrder = order;
      scene.add(mesh);
    }
}
