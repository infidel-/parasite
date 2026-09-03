package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// the exit signage: the first visible light FITTING indoors, and it survives what the ceiling panel
// did not — the roof deck fades out the moment the player steps inside, so anything hung from it
// lights nothing, where a sign bolted to a wall is still on the wall.
//
// it cannot ride render.facility.FacilityGlow, which is where every other additive glow in the
// compound lives for one draw call. that mesh shares ONE alphaMap (Textures.makeRectGlowGradient)
// and 0..1 uv across every quad in it, so it can draw a soft rect and nothing else — a legible
// pictogram needs its own image, which means its own material and its own call.
//
// so it is the LIT WINDOW PANE's material instead (FacilityGeom.addPane): the art is its own
// emissiveMap, and one Lambert mesh draws the dark housing and the glowing face together because
// the brightness difference is already painted into the bytes. no second quad behind it and no
// second pass — see FacilityStyle.EXIT_EMISSIVE for the one knob.
//
// THE PLACEMENT IS THE REGULATION AND NOT A TASTE CALL, and the first build got it backwards. Exit
// signage marks the MEANS OF EGRESS, not doorways: a sign goes over a door that IS an exit, and
// along a corridor as a DIRECTIONAL sign wherever that exit is not in view. A room door opening
// onto a corridor is not an exit and gets nothing — NFPA 101 and BS 5499 go further and want a door
// that could be mistaken for one marked NOT AN EXIT, so signing every lab door is the one thing the
// rule pushes against. Built that way it also put an ARROW over an office, which reads as "the exit
// is through this room". Both kinds come out of this file and out of one atlas:
//
//   - TERMINAL, over the inside face of a door that leads outdoors. no arrow.
//   - DIRECTIONAL, on the corridor wall a traveller WALKS INTO, arrow pointing the way to turn
//
// the route is a breadth-first flood from the exit doors over corridor lino, so a directional sign
// points at the exit that is actually NEAREST through the building and not at the one that happens
// to be closest as the crow flies. it costs one grid walk at area build and nothing per frame
class FacilityExit
{
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

// every sign in the compound, merged into one mesh. returns how many went in, for __facility()
  public static function build(scene:Scene, m:Facility):Int
    {
      var b = MeshBufTools.make();
      var dist = [for (_ in 0...m.h) [for (_ in 0...m.w) -1]];
      var n = terminals(b, m, dist);
      n += directionals(b, m, route(m, dist));
      add(scene, b);
      return n;
    }

// the terminal signs, and the seeds of the route flood in the same pass — a door that earns a sign
// is exactly a door the flood starts at, so asking twice could only let the two disagree.
//
// the sign goes on the face that looks at the CIRCULATION, which for an exterior door is its inside
// face by construction: the other side is the lot. the hangar's shutter has tarmac out and concrete
// in, so it seeds nothing and signs nothing, with no case of its own
  static function terminals(b:MeshBuf, m:Facility, dist:Array<Array<Int>>):Int
    {
      var n = 0;
      for (d in m.doors)
        {
          if (FacilityGlow.outward(m, d) == 0)
            continue;
          for (s in [-1, 1])
            {
              var col = d.col + (d.alongX ? 0 : s);
              var row = d.row + (d.alongX ? s : 0);
              if (!corridor(m, col, row))
                continue;
              quad(b, m, d.col, d.row, (d.alongX ? (s < 0 ? 0 : 1) : (s < 0 ? 2 : 3)),
                FacilityStyle.EXIT_V_TERM, false);
              dist[d.row][d.col] = 0;
              n++;
            }
        }
      return n;
    }

// how far every corridor cell is from the nearest exit door, in cells, or -1 for one no exit
// reaches. a plain breadth-first flood seeded at every exit at once, which is what makes the answer
// NEAREST rather than per-door: the first wave to arrive owns the cell.
//
// it stays inside the circulation because the surface does the work — a room is tile and the hangar
// is concrete, so the flood cannot leak through a room door, and the lot outside an exit is walkway,
// so it cannot leak out of the building either. a structure with no exterior door comes back all
// -1 and takes no directional signs, which is the right answer and not a gap
  static function route(m:Facility, dist:Array<Array<Int>>):Array<Array<Int>>
    {
      var q = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          if (dist[row][col] == 0)
            q.push(row * m.w + col);
      var qi = 0;
      while (qi < q.length)
        {
          var cur = q[qi++];
          var col = cur % m.w;
          var row = Std.int(cur / m.w);
          for (dir in 0...4)
            {
              var nc = col + DC[dir];
              var nr = row + DR[dir];
              if (!corridor(m, nc, nr) ||
                  dist[nr][nc] >= 0)
                continue;
              dist[nr][nc] = dist[row][col] + 1;
              q.push(nr * m.w + nc);
            }
        }
      return dist;
    }

// the directional signs, one on every wall a traveller heading for an exit WALKS INTO.
//
// that is the whole rule, and it is what makes an arrow possible at all: a sign flat on the wall
// beside you is edge-on to you, so the only place a flat sign can carry a direction is the wall you
// are walking at — a corridor end, the far side of a T. Which is also where a real one is. A pass
// that put them along the corridor's own SIDE wall every N cells shipped for one build and read as
// a green ribbon, unreadable from the corridor it was signing.
//
// where a run of cells all want the SAME sign, only the last one takes it: the cell you actually
// turn at, not the four before it
  static function directionals(b:MeshBuf, m:Facility, dist:Array<Array<Int>>):Int
    {
      var n = 0;
      for (row in 0...m.h)
        for (col in 0...m.w)
          for (a in 0...4)
            {
              var step = faces(m, dist, col, row, a);
              if (step < 0 ||
                  faces(m, dist, col + DC[step], row + DR[step], a) == step)
                continue;
              quad(b, m, col + DC[a], row + DR[a], a ^ 1, FacilityStyle.EXIT_V_DIR,
                uDir(a ^ 1) != step);
              n++;
            }
      return n;
    }

// does someone heading for the exit walk INTO the wall on side `a` of this cell, and if so which way
// do they have to turn? -1 for no, else the turn as a DC/DR index.
//
// three things have to hold. there is masonry on that side; the way out of here is PERPENDICULAR to
// it, or there is no turn to draw; and the corridor actually RUNS into the wall for EXIT_APPROACH
// cells behind, which is the one that separates a wall you walk at from a wall you walk past. That
// last test is not a refinement — a corridor here is 2 cells wide and the flood reaches one lane a
// step before the other, so every cell of a straight run reads as "the lane beside me is further
// from the exit, therefore people come from there", and without it the compound took 127 signs
  static function faces(m:Facility, dist:Array<Array<Int>>, col:Int, row:Int, a:Int):Int
    {
      if (!corridor(m, col, row) ||
          dist[row][col] < 1 ||
          FacilityModel.isDoor(m, col, row) ||
          !FacilityModel.isSolidWall(m, col + DC[a], row + DR[a]) ||
          signed(m, col + DC[a], row + DR[a], a))
        return -1;
      var step = toward(m, dist, col, row);
      if (step < 0 ||
          (a < 2) == (step < 2))
        return -1;
      for (i in 1...FacilityStyle.EXIT_APPROACH + 1)
        if (!corridor(m, col + DC[a ^ 1] * i, row + DR[a ^ 1] * i))
          return -1;
      return step;
    }

// does this wall cell already have a TERMINAL sign one cell along it, in which case an arrow on it
// is nonsense? the generator cuts an entrance as two leaves flanking a MULLION, so the mullion is a
// wall cell with an exit door on either side of it — and the arrow it took had to pick one of two
// doors 4 units away that both already carry a sign of their own. only the wall LINE is looked
// along, which is the axis `a` is not on
  static function signed(m:Facility, col:Int, row:Int, a:Int):Bool
    {
      for (k in 0...2)
        {
          var d = (a < 2 ? 2 + k : k);
          if (isExit(m, col + DC[d], row + DR[d]))
            return true;
        }
      return false;
    }

// is this cell a doorway that leads outdoors, i.e. one that takes a terminal sign. linear over the
// door list, which is ~20 openings
  static function isExit(m:Facility, col:Int, row:Int):Bool
    {
      for (d in m.doors)
        if (d.col == col &&
            d.row == row &&
            FacilityGlow.outward(m, d) != 0)
          return true;
      return false;
    }

// which way this cell steps to get to the exit: the neighbour one closer than it is, or -1 for a
// cell no exit reaches
  static function toward(m:Facility, dist:Array<Array<Int>>, col:Int, row:Int):Int
    {
      var d = dist[row][col];
      for (dir in 0...4)
        if (corridor(m, col + DC[dir], row + DR[dir]) &&
            dist[row + DR[dir]][col + DC[dir]] < d)
          return dir;
      return -1;
    }

// which world direction one unit of u runs in, on a face looking `dir`. read straight off
// FacilityGeom.ends, whose first pair IS the u=0 end of the quad it winds — so a sign whose arrow
// must point the other way mirrors u, and the running man flips with it exactly as a real mirrored
// drop does
  static inline function uDir(dir:Int):Int
    {
      return switch (dir)
        {
          case 0: 2;
          case 1: 3;
          case 2: 1;
          default: 0;
        };
    }

// is this cell a piece of the circulation: indoor floor laid in corridor lino, which the generator
// deals to the corridors and to every door cell. a room is tile and the hangar is concrete, so this
// is also the room test and the hangar test
  static inline function corridor(m:Facility, col:Int, row:Int):Bool
    {
      return FacilityModel.inside(m, col, row) &&
        !FacilityModel.isWall(m, col, row) &&
        m.surf[row][col] == Surf.LINO;
    }

// one sign on the face of cell (col,row) that looks at `dir`, MOUNT_PROUD clear of the masonry and
// centred on that cell. `v0` picks the atlas cell and `mirror` flips it along the wall.
//
// the plane is the SLAB's face and never the cell boundary. on a wall cell that is the masonry's own
// side; on a DOOR cell slab() returns exactly the lintel box — the cell's wall-line neighbours
// carry, so the two perpendicular sides come back inset by PARAPET_INSET — which is the same 2-unit
// reveal the jambs are built on
  static function quad(b:MeshBuf, m:Facility, col:Int, row:Int, dir:Int, v0:Float,
      mirror:Bool):Void
    {
      var s = FacilityGeom.slab(m, col, row);
      var e = FacilityStyle.MOUNT_PROUD;
      var h = FacilityStyle.EXIT_W / 2;
      var c = CityConfig.cellToWorld(col, row);
      var y0 = FacilityStyle.EXIT_Y - FacilityStyle.EXIT_H / 2;
      var y1 = FacilityStyle.EXIT_Y + FacilityStyle.EXIT_H / 2;
      if (dir < 2)
        {
          var z = (dir == 0 ? s.z0 - e : s.z1 + e);
          pane(b, c.x - h, c.x + h, z, z, dir, y0, y1, v0, mirror);
          return;
        }
      var x = (dir == 2 ? s.x0 - e : s.x1 + e);
      pane(b, x, x, c.z - h, c.z + h, dir, y0, y1, v0, mirror);
    }

// FacilityGeom.pane with the uv opened up: v picks one of the atlas's two cells and u may run
// backwards. everything else about the winding is that function's, through its own `ends`
  static function pane(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, dir:Int, y0:Float,
      y1:Float, v0:Float, mirror:Bool):Void
    {
      var e = FacilityGeom.ends(x0, x1, z0, z1, dir);
      var u0 = (mirror ? 1.0 : 0.0);
      var u1 = (mirror ? 0.0 : 1.0);
      var v1 = v0 + 0.5;
      MeshBufTools.quad(b,
        [e[0], y0, e[1]], [e[2], y0, e[3]], [e[2], y1, e[3]], [e[0], y1, e[1]],
        [u0, v0, u1, v0, u1, v1, u0, v1]);
    }

// merge the buffer into one lit mesh. the material is the window pane's minus its alpha: the art is
// opaque, so there is no alphaTest to set, no `transparent` to order against anything and no sorted
// pass to pay for.
//
// it neither casts nor receives. casting is meaningless — the moon is outside and the roof is over
// it — and receiving would put a wall's own shadow across a thing that is supposed to be a light
  static function add(scene:Scene, b:MeshBuf):Void
    {
      if (b.idx.length == 0)
        return;
      var tex = Textures.loadTexture(FacilityStyle.EXIT_TEX, 'wall', 1);
      var mat = VisionMask.patch(new MeshLambertMaterial({
        map: tex,
        emissiveMap: tex,
        emissive: new Color(0xffffff),
        emissiveIntensity: FacilityStyle.EXIT_EMISSIVE,
        side: THREE.FrontSide,
      }));
      var mesh = new Mesh(FacilityGeom.geom(b), mat);
      mesh.receiveShadow = false;
      mesh.castShadow = false;
      scene.add(mesh);
    }
}
