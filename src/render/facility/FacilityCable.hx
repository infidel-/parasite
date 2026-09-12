package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.ContactMask;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// one thing bolted to a wall, as `sockets` and `fittings` derive it off the grid
typedef Mount = {
  // the FLOOR cell it hangs beside — not the wall cell, which is this plus `dir`
  col:Int,
  row:Int,
  // which of that cell's four sides the masonry is on, in render.facility.FacilityGeom.face's
  // numbering (0 = -z, 1 = +z, 2 = -x, 3 = +x)
  dir:Int,
  // which cell of facility/electrical-pack it draws
  cell:Int,
  // a CORRIDOR fitting rather than a room SOCKET: a different band of the sheet, a different size and
  // a different height. one bool and not two lists because everything downstream — the quad, the
  // floor unit, the cable that leaves it — is the same code with two constants
  fit:Bool,
  // and the MACHINE cell feeding it, or -1: a socket with one gets a cable dropped onto that unit,
  // and a socket without is one of the bare ones
  mcol:Int,
  mrow:Int,
  mkind:Int,
  // whether a cable is already plugged into it. ONE CABLE PER MOUNT, and it is a fact about the ART
  // and not a density rule: the sheet's socket cells draw ONE outlet, so a second lead arriving at
  // the same plate is a lead plugged into nothing. Claimed in order — the machine drops first, then
  // the links (which need BOTH ends free), then the floor leads
  used:Bool,
};

// one floor unit and where it stands
typedef Unit = {
  col:Int,
  row:Int,
};

// what build() hands back for __facility(). five numbers and not one, because every one of these
// fails INDEPENDENTLY and a merged mesh has no instance count to read them off — the lesson of the
// first cable build, which shipped 52 panels and 0 runs behind a single counter
typedef ElecCounts = {
  // every socket and fitting AS PLACED, and not a count of them: a list is what turned four
  // independent bugs in the first cable build into four readable numbers, and a cell index in it is
  // the only way to check from outside that a room really did pick ONE socket
  mounts:Array<Mount>,
  runs:Int,
  units:Int,
  scatter:Int,
};

// the compound's ELECTRICAL SERVICE: wall sockets in the rooms, junction boxes and breaker gear on
// the corridor walls, the floor units a trailing cable leads to, the loose kit lying about beside
// them — and the cable itself, sagging off the machinery and snaking over the floors.
//
// TWO MESHES AND TWO DRAW CALLS FOR ALL OF IT. Everything with a picture on it comes off ONE pack64
// (FacilityStyle.ELEC_TEX), which is why four families that look nothing alike cost one call between
// them; the cable is the second because it is the one thing that tiles rather than being cut out.
// The pack mesh is FacilityClutter's material exactly — an opaque alphaTest draws DoubleSide in one
// pass and still writes depth — so it costs no new program either.
//
// THE PACK IS DRAWN IN TWO PROJECTIONS, which no other sheet in the tree is: its first four rows are
// front elevation and go on walls, its last four are top-down and lie flat on floors. That is the
// whole trick — a wall socket and a cable drum cannot share a view, but they can share a texture.
//
// A SOCKET IS THE SAME IN EVERY ROOM OF ONE ROOM. The sheet's socket band is 16 cells wide and the
// choice is rolled off the ROOM's own id rather than off the cell, so a lab is fitted throughout with
// one pattern and the lab next door with another — which is what an electrician does and what a
// per-cell roll destroys.
//
// A CABLE IS A STRIPE, so it is a TEXTURE on a ribbon and not geometry with a cross-section. The
// ribbon lies IN ONE PLANE — the wall's for a run bolted to masonry, the floor's for one lying on the
// ground — and is never billboarded, the rule the object-effect guard draws between a thing glued to
// the world and a free camera-facing one.
//
// AND THE MATHS IS A PARABOLA AND NOT A SPLINE, which is the one thing worth saying about this file.
// render.PathLine and render.particles.SlimeTrail both build exactly this ribbon and both are the
// wrong shape to borrow from, because both rebuild every frame from a PATH of many cells. A cable has
// TWO ANCHORS. So the centreline is a straight chord with an offset term on it, tapered 4t(1 - t) so
// it is zero at both ends and the run stays glued to what it is bolted to, and the wander that stops
// two runs being parallel curves is one sine rolled ONCE off FacilityModel.mix and baked. Nothing
// here ticks.
//
// RENDER-ONLY, FacilityClutter's contract: no objects.Decoration, no atlas frame, no cell taken,
// nothing persisted, and every placement rolled off the saved grid so an area comes back identical on
// every rebuild.
class FacilityCable
{
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

  // the outward normal of the face a mount hangs on, by the FACE direction (dir ^ 1) rather than by
  // the hand the masonry is on: the quad looks BACK at the cell, so these are the four ways round
  static var NX = [0.0, 0.0, -1.0, 1.0];
  static var NZ = [-1.0, 1.0, 0.0, 0.0];
  // straight up, for a ribbon lying on a floor
  static var UP = [0.0, 1.0, 0.0];

  // the socket cells actually dealt, built once off FacilityStyle.SOCK_SKIP. derived rather than
  // written out so the skip list stays the one place the finding lives — see its comment for why a
  // socket that draws its own cable cannot be used by a family that draws one too
  static var PICK:Array<Int> = [
    for (i in 0...FacilityStyle.ELEC_BAND)
      if (FacilityStyle.SOCK_SKIP.indexOf(FacilityStyle.ELEC_SOCKET + i) < 0) i
  ];

  // and the standing cells actually dealt, the same derivation off FacilityStyle.UNIT_SKIP — two of
  // the sixteen stand on legs a lead would end in the air between
  static var STAND:Array<Int> = [
    for (i in 0...FacilityStyle.ELEC_BAND)
      if (FacilityStyle.UNIT_SKIP.indexOf(FacilityStyle.ELEC_UNIT + i) < 0) i
  ];

  // every cell the compound strikes a KEEP-CLEAR hatch on, filled once per build. see `hatched`
  static var zones:Map<Int, Bool>;

// the whole service, as two merged meshes
// `extra` is a ribbon buffer somebody else filled — render.facility.FacilityWork's desk leads — and
// it is merged with this family's own so the whole compound's cable, wall to worktop, stays ONE draw
// call. a borrowed buffer and not a second mesh, for the reason the pack sheet itself exists
  public static function build(scene:Scene, m:Facility, extra:MeshBuf):ElecCounts
    {
      var pack = MeshBufTools.make();
      var cab = extra;
      hatch(m);
      var socks = sockets(m);
      var fits = fittings(m);
      var all = socks.concat(fits);
      for (p in all)
        mount(pack, m, p);
      var runs = drops(cab, pack, m, socks) + links(cab, pack, m, socks);
      var us = units(pack, cab, m, all);
      var scat = scatter(pack, m, us);
      add(scene, pack);
      FacilityGeom.add(scene, cab, FacilityStyle.CABLE_TEX, true, false);
      return {
        mounts: all,
        // every ribbon in the compound: the machine drops, the socket-to-socket runs along the
        // skirting, and the lead out to each floor unit
        runs: runs + us.length,
        units: us.length,
        scatter: scat,
      };
    }

// every cell the compound strikes a KEEP-CLEAR hatch on, as a set.
//
// THE HATCH IS THE FLOOR TELLING YOU NOT TO PUT ANYTHING THERE, and this family was putting a cable
// drum in the middle of one — a fire point's zone, which is the single mark in the compound that means
// exactly that. So it is not a clearance this file invents: it is re-derived off the same two pure
// functions render.facility.FacilityPaint strikes them from (`m.doors` filtered by FacilityGlow
// .outward, and FacilityPoint.places), which is why neither builder has to run before the other.
//
// PER CELL IS THE WHOLE OF IT: a zone reaches ZONE_D 3.0 off the SLAB FACE, and the face is already a
// unit inside the wall cell, so the hatch covers 2 units of the fitting's own 4-unit cell and never
// leaves it
  static function hatch(m:Facility):Void
    {
      zones = new Map();
      for (d in m.doors)
        {
          if (FacilityGlow.outward(m, d) == 0)
            continue;
          for (s in [-1, 1])
            zones.set(cell(m, d.col + (d.alongX ? 0 : s), d.row + (d.alongX ? s : 0)), true);
        }
      for (p in FacilityPoint.places(m))
        zones.set(cell(m, p.col, p.row), true);
    }

// one cell's slot in that set
  static inline function cell(m:Facility, col:Int, row:Int):Int
    {
      return row * m.w + col;
    }

// may this family put anything ON this cell at all: free floor that carries no keep-clear hatch
  static inline function open(m:Facility, col:Int, row:Int):Bool
    {
      return FacilityPaint.freeFloor(m, col, row) &&
        !zones.exists(cell(m, col, row));
    }

// and may a lead merely PASS along it on its way out to a unit — `open` widened by exactly one thing,
// the bench.
//
// STANDING ON A CELL AND CROSSING IT ARE DIFFERENT QUESTIONS, which `run` asked as one and got the
// wrong answer to. A unit stood on a bench cell would be a cabinet standing in a worktop, so the
// STANDING test keeps every clause of `open`; a lead passing one runs in the strip between the wall
// and the bench, because a bench stands on its own CELL a clear unit off the slab face and the ribbon
// is laid on the wall's own hand of it. `joins` has always let a run past a bench for exactly this
// reason and said so — this is that argument applied to the family next door, and it opens up the
// rooms this compound is mostly made of.
//
// THE HATCH IS STILL A HATCH: a keep-clear mark means nothing goes over it, cable included, so the
// zone test is asked of a passing cell too
  static inline function passes(m:Facility, col:Int, row:Int):Bool
    {
      return open(m, col, row) ||
        (FacilityModel.isTable(m, col, row) &&
         !zones.exists(cell(m, col, row)));
    }

// every socket the rooms carry: which cell, which wall of it, and which machine if any feeds it.
//
// THE PREDICATE IS THE PLACARDS' OWN — FacilityPlacard.hangs: room floor (Surf.TILE, which is what
// keeps this family off every corridor family's wall with no check against any of them) looking at
// plain masonry whose wall line carries on past the cell both ways.
//
// AND THE CELL MUST BE BARE, which at this height is a different argument from the panel band's. A
// socket spans 0.25 to 0.95 and anything standing against that wall stands THROUGH it, whatever its
// own height — so unlike the cable runs, where the test is a height against the run's lowest point,
// here a fitting on the cell is simply a reject
  static function sockets(m:Facility):Array<Mount>
    {
      var out:Array<Mount> = [];
      // THE MACHINES ARE DEALT FIRST, and that ordering is the whole of the wired case. The greedy
      // pass below takes the first eligible cell in every SOCK_SPACING neighbourhood, which is
      // essentially never the one cell that happens to have a machine beside it — built the other way
      // round the compound came back with 52 mounts and NOT ONE of them fed.
      //
      // AND A FED SOCKET TAKES NO SPACING AND REACHES TWO CELLS, which is the correction this pass
      // needed: every rack in the compound is supposed to be plugged in, and with SOCK_SPACING on
      // the machine pass most of them were not. A rack standing in a run of fittings has BOTH its
      // neighbours taken, so the old hands — the cell either side and nothing further — simply
      // failed; and two racks inside four cells of each other wired only the first, because the
      // second fell inside the first's neighbourhood. Neither rejection is about the wall's rhythm,
      // which is the only thing SOCK_SPACING was fitted for (3 hung 52 plates and read as
      // wallpaper): A SOCKET BESIDE THE MACHINE IT FEEDS IS JUSTIFIED BY THE MACHINE. So the walk
      // goes out to two cells on each hand and the only thinning left is "not the cell some other
      // mount already took", i.e. `spaced` at 1. The bare pass below still sees these in `out` and
      // still keeps its full spacing off them, so the wall does not fill up behind this.
      //
      // THE ELECTRICAL KINDS AND NOT THE FURNITURE: the two machines and the two racks. A bookcase
      // has no cable to run and a drum is not plugged into anything, and all four of these carry a
      // drawn gland on their own lid art already (art/textures.json facility/deco-machine-top,
      // facility/deco-rack-top)
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var kind = m.deco[row][col] - 1;
            if (!feeds(kind))
              continue;
            var q = FacilityDeco.rectOf(m, col, row, kind);
            if (!q.hasWall)
              continue;
            // BESIDE it and never under it: a socket under a machine is behind the machine
            var sc = (q.dir < 2 ? 1 : 0);
            var sr = (q.dir < 2 ? 0 : 1);
            // the near hands first, so a lead stays as short as the wall allows
            for (s in [-1, 1, -2, 2])
              {
                var c = col + sc * s;
                var r = row + sr * s;
                if (!bare(m, c, r, q.dir) ||
                    !walled(m, col, row, q.dir, sc * s, sr * s) ||
                    !spaced(out, c, r, 1))
                  continue;
                out.push(sock(m, c, r, q.dir, col, row, kind));
                break;
              }
          }
      // and then the bare ones, over whatever wall face is left
      for (row in 0...m.h)
        for (col in 0...m.w)
          for (dir in 0...4)
            {
              if (!bare(m, col, row, dir) ||
                  !spaced(out, col, row, FacilityStyle.SOCK_SPACING))
                continue;
              out.push(sock(m, col, row, dir, -1, -1, -1));
            }
      return out;
    }

// is the masonry UNBROKEN from a machine's own cell to a socket `dc, dr` cells along its wall — the
// test that keeps a drop off a doorway.
//
// A DROP IS A RIBBON AND NOT A RUN: `drops` joins the machine's lid straight to its socket's plate, so
// unlike `joins` and `run` it never walks the cells in between and never asked anything of them. That
// was survivable while the walk reached ONE cell each way, because a socket in front of a doorway is
// already rejected — `FacilityPlacard.hangs` wants the wall line to carry on past its own cell. At two
// cells it is not: the socket lands on good masonry on the FAR side of a door and the cable is drawn
// across the open threshold, which is what came back from the game.
//
// so the span is tested here, where the socket is CHOSEN, rather than in `drops`: a machine whose only
// legal plate is over a doorway is a machine with no plate, and the walk simply moves on to its next
// hand. `isSolidWall` and not `hangs` for `joins`' own reason — a cable passing a cell has nothing to
// hang past and only needs masonry to run along. A BENCH DOES NOT BREAK IT and is not asked about:
// the ribbon is in the wall's plane, a bench stands a clear unit off the slab face, and the strip
// behind one is exactly where a lead belongs
  static function walled(m:Facility, col:Int, row:Int, dir:Int, dc:Int, dr:Int):Bool
    {
      var n = (dc != 0 ? (dc > 0 ? dc : -dc) : (dr > 0 ? dr : -dr));
      var sc = (dc != 0 ? (dc > 0 ? 1 : -1) : 0);
      var sr = (dr != 0 ? (dr > 0 ? 1 : -1) : 0);
      for (i in 1...n + 1)
        if (!FacilityModel.isSolidWall(m, col + sc * i + DC[dir], row + sr * i + DR[dir]))
          return false;
      return true;
    }

// one socket, with the sheet cell its ROOM picked. see the header: the roll is on the room and not
// on the cell, so a room is fitted throughout with one pattern
  static inline function sock(m:Facility, col:Int, row:Int, dir:Int, mcol:Int, mrow:Int,
      mkind:Int):Mount
    {
      return {
        col: col,
        row: row,
        dir: dir,
        cell: FacilityStyle.ELEC_SOCKET +
          PICK[FacilityModel.mix(roomKey(m, col, row) * 1597334677) % PICK.length],
        fit: false,
        mcol: mcol,
        mrow: mrow,
        mkind: mkind,
        used: false,
      };
    }

// which room a cell belongs to, as a stable key. the generator's own room id where its rects reach
// the cell, and the STRUCTURE index otherwise — a compound cell that is in no room rect is in some
// building, and two sockets in one building beat two sockets rolled apart.
//
// `m.rooms` comes straight off generatorInfo and FacilityModel.demo() leaves it empty, which is why
// the fallback is not a nicety: the warm scene has no rooms at all
  static function roomKey(m:Facility, col:Int, row:Int):Int
    {
      for (r in m.rooms)
        if (col >= r.x1 &&
            col <= r.x2 &&
            row >= r.y1 &&
            row <= r.y2)
          return r.id;
      return 1000 + m.owner[row][col];
    }

// every fitting the corridors carry — a junction box, a breaker board, an isolator.
//
// THREE FAMILIES ALREADY OWN THIS WALL and all three are excluded by reading their own placement
// rather than by inventing a clearance. FacilityTables.hugs is the casework's predicate and carries
// the dead-end and inside-corner exclusion that keeps the litter bins' cells free; FacilityTables.runs
// is the casework itself; FacilityPoint.places is the fire points and the distribution boards, whose
// quads span 0.1 to 4.1 and would be drawn straight through. All three are pure functions of the
// saved grid, so none of them has to run before this one — FacilityPoint's own discipline, one level
// on.
//
// AND ALL THREE ARE EXCLUDED PER FACE, not per neighbourhood. That distinction is worth the line: a
// first cut ran the fire points through this pass's own FIT_SPACING thinning and the whole compound
// came back with THREE fittings, because 11 fire points at a reach of 6 cells leave almost no
// corridor wall standing. An exclusion says "not here"; a spacing says "not near anything of MINE",
// and only the second one is about rhythm
  static function fittings(m:Facility):Array<Mount>
    {
      var taken = new Map<Int, Bool>();
      for (r in FacilityTables.runs(m))
        {
          var sc = (r.dir < 2 ? 1 : 0);
          var sr = (r.dir < 2 ? 0 : 1);
          for (i in 0...r.len)
            taken.set(key(m, r.col + sc * i, r.row + sr * i, r.dir), true);
        }
      // the fire points claim their own FACE and nothing more, which is the correction this pass
      // needed: run through the same FIT_SPACING thinning as the fittings themselves they left THREE
      // in the whole compound, because 11 of them at a reach of 6 cells sterilise most of the
      // corridor wall. They are 2.0 wide — a quarter of a cell either side of their own centre — so a
      // fitting one cell along is not touching one, and the only thing that really cannot be shared
      // is the face
      for (p in FacilityPoint.places(m))
        taken.set(key(m, p.col, p.row, p.dir), true);
      var out:Array<Mount> = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          for (dir in 0...4)
            {
              if (!FacilityTables.hugs(m, col, row, dir) ||
                  taken.exists(key(m, col, row, dir)) ||
                  !FacilityPoint.runsOn(m, col, row, dir) ||
                  !spaced(out, col, row, FacilityStyle.FIT_SPACING))
                continue;
              out.push({
                col: col,
                row: row,
                dir: dir,
                cell: FacilityStyle.ELEC_FITTING +
                  FacilityModel.mix((col * 1103515245) ^ (row * 668265263)) %
                    FacilityStyle.ELEC_BAND,
                fit: true,
                mcol: -1,
                mrow: -1,
                mkind: -1,
                used: false,
              });
            }
      return out;
    }

// may a cable LEAVE this mount at all — asked of every end of every run, and it is the corridor half
// that needs asking. A room socket is an outlet by construction; a corridor fitting is whatever cell
// of the band it drew, and ten of the sixteen are sealed enclosures with nothing to plug into. See
// FacilityStyle.FIT_FEED, which is an allowlist because the blocklist it replaced only caught the two
// cells that were absurd and left a lead growing out of a breaker board
  static inline function sources(p:Mount):Bool
    {
      return !p.fit || FacilityStyle.FIT_FEED.indexOf(p.cell) >= 0;
    }

// does a fitting of this kind have a cable to run — the two machines and the two racks
  static inline function feeds(kind:Int):Bool
    {
      return kind == _FittingKind.FIT_MACHINE ||
        kind == _FittingKind.FIT_MACHINE_LOW ||
        kind == _FittingKind.FIT_RACK ||
        kind == _FittingKind.FIT_RACK_LOW;
    }

// may a socket hang on the `dir` wall of this room cell at all: the placards' own predicate, plus a
// cell with nothing standing AGAINST that wall.
//
// A BENCH IS NOT SUCH A THING, and excluding one was this predicate reading its own comment too
// broadly. The argument for the exclusion is real and is about the FITTINGS: a plate spans 0.25 to
// 0.95 and a cabinet, a rack or a machine is bolted TO the wall, so it stands through the plate
// whatever its own height. A bench does not touch the wall at all — it stands on its own cell a clear
// unit off the slab face, which is the very fact `joins` has always used to let a run past one. So
// the strip behind a bench is masonry with nothing on it, which is where a socket goes in a real
// laboratory and where the lead to one is out of the way.
//
// MEASURED, and it is the difference between a wired compound and a half-wired one: of 28 machines
// and racks standing against a wall here, 15 could take a plate with bench cells excluded and 23 with
// them allowed. The eight are machines at the end of a bench run, whose only free neighbour is the
// bench — and before `walled` they were being wired ACROSS A DOORWAY instead.
//
// `true` widens the surface gate to a researcher's OFFICE: the room the compound's other electrical
// kit stays out of for no reason at all — an office has sockets and a skirting run like every other
// room, and the desks and the workstations on them are what they feed
  static inline function bare(m:Facility, col:Int, row:Int, dir:Int):Bool
    {
      return FacilityModel.inside(m, col, row) &&
        FacilityPlacard.hangs(m, col, row, dir, true) &&
        m.deco[row][col] == 0;
    }

// and is it far enough from every mount already dealt. FacilityPoint.places' own thinning, measured
// between CELLS rather than along one wall for its reason: a room corner has masonry on two hands and
// a mount on each would be two plates meeting at right angles
  static function spaced(out:Array<Mount>, col:Int, row:Int, d:Int):Bool
    {
      for (p in out)
        if (Std.int(Math.abs(p.col - col)) < d &&
            Std.int(Math.abs(p.row - row)) < d)
          return false;
      return true;
    }

// one cell's slot in a claimed-cell set, PER DIRECTION — FacilityTables.key's own layout
  static inline function key(m:Facility, col:Int, row:Int, dir:Int):Int
    {
      return ((dir * m.h + row) * m.w) + col;
    }

// one mount, MOUNT_PROUD clear of the wall face and centred on its cell.
//
// the plane is the SLAB's face and never the cell boundary, the trap FacilityPoint.quad,
// FacilityExit.quad and FacilityTables.unit all record: a straight run insets its room face a whole
// unit into the wall cell. and the span along the wall is clamped to that slab for the same reason —
// a quad centred on the cell at a run's end would hang past the end of the masonry it is bolted to.
//
// NO HALO: `stand` grows a shadow up from the FLOOR for a large cuboid resting against a wall, and
// these are flat plates. The placards and the fire points hang the same way and take none either
  static function mount(b:MeshBuf, m:Facility, p:Mount):Void
    {
      var s = FacilityGeom.slab(m, p.col + DC[p.dir], p.row + DR[p.dir]);
      var e = FacilityStyle.MOUNT_PROUD;
      var w = (p.fit ? FacilityStyle.FIT_W : FacilityStyle.SOCK_W);
      var h = w / 2;
      var c = CityConfig.cellToWorld(p.col, p.row);
      var y = (p.fit ? FacilityStyle.FIT_Y : FacilityStyle.SOCK_Y);
      // the face looks BACK at the cell the mount hangs beside, so it is the opposite of the side the
      // masonry is on
      var dir = p.dir ^ 1;
      if (dir < 2)
        {
          var z = (dir == 0 ? s.z0 - e : s.z1 + e);
          pane(b, Math.max(c.x - h, s.x0), Math.min(c.x + h, s.x1), z, z, dir, y - h, y + h, p.cell);
          return;
        }
      var x = (dir == 2 ? s.x0 - e : s.x1 + e);
      pane(b, x, x, Math.max(c.z - h, s.z0), Math.min(c.z + h, s.z1), dir, y - h, y + h, p.cell);
    }

// FacilityGeom.pane with the pack's cell opened up. v is flipped, the trap FacilitySink.emit records:
// three flips y, so the source's TOP row is the HIGH v
  static function pane(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, dir:Int, y0:Float,
      y1:Float, idx:Int):Void
    {
      var e = FacilityGeom.ends(x0, x1, z0, z1, dir);
      var t = FacilityStyle.ELEC_COLS;
      var cc = idx % t, cr = Std.int(idx / t);
      var u0 = cc / t, u1 = (cc + 1) / t;
      var v0 = 1 - (cr + 1) / t, v1 = 1 - cr / t;
      MeshBufTools.quad(b,
        [e[0], y0, e[1]], [e[2], y0, e[3]], [e[2], y1, e[3]], [e[0], y1, e[1]],
        [u0, v0, u1, v0, u1, v1, u0, v1]);
    }

// the drop from each fed machine's lid down to its own socket.
//
// IT LEAVES THE LID AT THE BACK, in the wall plane itself, which is both where a gland is and what
// keeps the whole ribbon in ONE plane — a cable leaving the middle of the lid would have a depth
// component. CABLE_LID_D moves it ALONG the wall off the unit's centre so the drop is a diagonal with
// something to sag against rather than the straight vertical a centred gland would give
  static function drops(b:MeshBuf, pack:MeshBuf, m:Facility, list:Array<Mount>):Int
    {
      var n = 0;
      for (p in list)
        {
          if (p.mkind < 0)
            continue;
          var q = FacilityDeco.rectOf(m, p.mcol, p.mrow, p.mkind);
          var sl = FacilityGeom.slab(m, p.col + DC[p.dir], p.row + DR[p.dir]);
          // AT A THIRD OF ITS HEIGHT AND NOT ON ITS LID. The lid was the first anchor and the game
          // reported what it looks like: these fittings are SPRITES and a sprite does not fill its
          // quad's top corners, so a cable leaving at q.h leaves from a point outside the drawn
          // object and hangs in the air beside it. Down the body it is inside the art of all four
          var y = FacilityGround.surfY(Surf.TILE) + q.h * FacilityStyle.CABLE_LID_H;
          var dir = p.dir ^ 1;
          var e = FacilityStyle.MOUNT_PROUD + FacilityStyle.CABLE_EPS;
          // toward the socket, which is the hand the machine's cell is NOT on
          var s = (p.dir < 2 ? (p.col > p.mcol ? 1 : -1) : (p.row > p.mrow ? 1 : -1));
          var d = FacilityStyle.CABLE_LID_D;
          var a = (dir < 2 ?
            [q.x0 + (q.x1 - q.x0) * (s > 0 ? 1 - d : d), y, (dir == 0 ? sl.z0 - e : sl.z1 + e)] :
            [(dir == 2 ? sl.x0 - e : sl.x1 + e), y, q.z0 + (q.z1 - q.z0) * (s > 0 ? 1 - d : d)]);
          var c = anchor(m, p, -s);
          strip(b, {
            a: a,
            c: c,
            n: [NX[dir], 0.0, NZ[dir]],
            side: [0.0, -1.0, 0.0],
            bow: droop(a, c),
            wave: FacilityStyle.CABLE_WAVE,
            seed: FacilityModel.mix((p.mcol * 971658137) ^ (p.mrow * 1266489917)),
          });
          plug(pack, m, p, -s);
          p.used = true;
          n++;
        }
      return n;
    }

// and the runs between two sockets on one wall line, draped down the wall between them.
//
// IN THE WALL PLANE AND NOT THE FLOOR'S, which the sockets moving down the wall nearly took away.
// A run between two fittings at head height sags under gravity; between two sockets half a unit off
// the ground the old 0.45 droop is underground at mid-span. The first answer was to lay the run flat
// on the floor instead, and it was wrong for a reason the floor leads are not: both its ends are
// plugged into something half a unit UP, so a horizontal ribbon between them floats. It stays in the
// wall plane and `droop` gives it whatever headroom its anchors leave — a cable draped along a
// skirting, which is what it is.
//
// EVERY ELIGIBLE PAIR IS JOINED, and the bare sockets come out of the geometry rather than out of a
// roll. A skip roll was built here first, on the argument that a compound where every socket is wired
// to both its neighbours reads as a diagram — and then measured: of 30 candidate pairs only 4 were
// eligible at all. The compound supplies far more emptiness than any roll could
  static function links(b:MeshBuf, pack:MeshBuf, m:Facility, list:Array<Mount>):Int
    {
      var n = 0;
      for (p in list)
        for (q in list)
          {
            // one direction only, so a pair is not run twice — and ONE CABLE PER MOUNT, so a link
            // needs BOTH of its ends still free AND both of them able to source a lead at all
            if (q.dir != p.dir ||
                p.used ||
                q.used ||
                !sources(p) ||
                !sources(q) ||
                !before(p, q) ||
                !joins(m, p, q))
              continue;
            var pa = anchor(m, p, 1);
            var qa = anchor(m, q, -1);
            strip(b, {
              a: pa,
              c: qa,
              n: [NX[p.dir ^ 1], 0.0, NZ[p.dir ^ 1]],
              side: [0.0, -1.0, 0.0],
              bow: droop(pa, qa),
              wave: FacilityStyle.CABLE_WAVE,
              seed: FacilityModel.mix((p.col * 374761393) ^ (p.row * 668265263) ^
                (q.col * 1103515245) ^ (q.row * 12345)),
            });
            plug(pack, m, p, 1);
            plug(pack, m, q, -1);
            p.used = true;
            q.used = true;
            n++;
          }
      return n;
    }

// where a socket sits along its own wall, in cells — the axis the wall does NOT lie on
  static inline function along(p:Mount):Int
    {
      return (p.dir < 2 ? p.col : p.row);
    }

// and the axis it does, which is what makes two sockets neighbours rather than strangers
  static inline function line(p:Mount):Int
    {
      return (p.dir < 2 ? p.row : p.col);
    }

// a stable order over a pair, so `links` walks each one once
  static inline function before(p:Mount, q:Mount):Bool
    {
      return line(p) == line(q) && along(p) < along(q);
    }

// may a run join these two: same wall line, close enough, and nothing standing between them.
//
// A FITTING BETWEEN THEM IS A REJECT AND A BENCH IS NOT, which is the one judgement in this test and
// the one thing the move to the floor did NOT change. The old panel band could take a fitting's
// height against the run's lowest point and let the low half of the family pass under; a run on the
// FLOOR passes under nothing, so any fitting on the cell is in the way. A bench still is not: it
// stands on its own CELL, a clear unit of floor off the slab face (FacilityGeom.slab's own inset),
// and CABLE_SNAKE 0.55 of bow does not reach it. Rejecting bench cells is what took the first build to
// 34 same-line pairs and ZERO links — these rooms are mostly bench.
//
// the wall test is isSolidWall and NOT `hangs`, and the two are not the same test twice: `hangs` asks
// whether the wall line CARRIES ON PAST the cell both ways, which a fixed-width plate needs because it
// would otherwise hang past the masonry it is bolted to. A cable passing THROUGH a cell has nothing to
// hang past and only needs masonry to run along
  static function joins(m:Facility, p:Mount, q:Mount):Bool
    {
      var d = along(q) - along(p);
      if (d > FacilityStyle.CABLE_RUN_MAX)
        return false;
      var sc = (p.dir < 2 ? 1 : 0);
      var sr = (p.dir < 2 ? 0 : 1);
      for (i in 1...d)
        {
          var c = p.col + sc * i;
          var r = p.row + sr * i;
          if (!FacilityModel.isSolidWall(m, c + DC[p.dir], r + DR[p.dir]) ||
              m.deco[r][c] != 0)
            return false;
        }
      return true;
    }

// the plug on the end of a run, over the point it leaves a SOCKET from.
//
// NOT THROUGH `pane`, which is the one reason this is fifteen lines instead of one: the art has to
// TURN so its gland collar follows the cable, and `pane` takes an axis-aligned rect and an upright v.
// So the quad is built from a world basis instead — pick the art's own UP and the rest falls out of
// `R = U cross n`, which reproduces `FacilityGeom.ends`' handedness on every face without a table
// (face 0's right really is -x) and keeps the front face looking into the room by construction.
//
// the gland points DOWN for a lead heading out into the room (`s` 0) and ALONG THE WALL for one
// running to a neighbour or up to a machine, which is the same hand `anchor` slid the cable to.
//
// SOCKETS ONLY: a lead leaving a corridor junction box leaves through a gland, and those cells draw
// their own
  static function plug(b:MeshBuf, m:Facility, p:Mount, s:Int):Void
    {
      if (p.fit)
        return;
      var f = p.dir ^ 1;
      var n = [NX[f], 0.0, NZ[f]];
      // the axis `anchor` slides along, which is the wall's own in-plane horizontal
      var sv = (p.dir < 2 ? [1.0, 0.0, 0.0] : [0.0, 0.0, 1.0]);
      var u = (s == 0 ? [0.0, 1.0, 0.0] : [-s * sv[0], 0.0, -s * sv[2]]);
      var r = [u[1] * n[2] - u[2] * n[1], u[2] * n[0] - u[0] * n[2], u[0] * n[1] - u[1] * n[0]];
      // ON THE PLATE'S CENTRE AND NOT ON THE CABLE'S EXIT POINT, which is `anchor`'s hand 0 rather
      // than `s`. The two are different points by construction: `anchor` slides SOCK_W * SOCK_LEAD
      // along the wall so the ribbon's CUT END is hidden well inside the plate's art, and hanging the
      // plug there put its centre 0.35 off a plate whose half-width is 0.7 — so the plug covered the
      // plate's far HALF and the rest of it hung on bare wall, reported as the two overlapping only
      // partially. A plug goes on its socket; the lead still leaves from `anchor`, which stays inside
      // this quad (0.35 against the plug's own half-width of PLUG_W / 2), so the cable comes out from
      // under the plug's body and not out of thin air. The basis above still keys off `s`, so the
      // gland collar goes on turning to follow the lead
      var c = anchor(m, p, 0);
      // proud of the ribbon it covers, which is itself proud of the plate — three parallel surfaces,
      // and the standing note says separate them with a gap and never with a polygonOffset
      var e = FacilityStyle.CABLE_EPS;
      var h = FacilityStyle.PLUG_W / 2;
      var t = FacilityStyle.ELEC_COLS;
      var cc = FacilityStyle.ELEC_PLUG % t, cr = Std.int(FacilityStyle.ELEC_PLUG / t);
      var u0 = cc / t, u1 = (cc + 1) / t;
      var v0 = 1 - (cr + 1) / t, v1 = 1 - cr / t;
      inline function at(a:Float, b2:Float)
        return [c[0] + n[0] * e + r[0] * a + u[0] * b2,
                c[1] + n[1] * e + r[1] * a + u[1] * b2,
                c[2] + n[2] * e + r[2] * a + u[2] * b2];
      MeshBufTools.quad(b, at(-h, -h), at(h, -h), at(h, h), at(-h, h),
        [u0, v0, u1, v0, u1, v1, u0, v1]);
    }

// how far a WALL run may droop: its own lowest anchor, less the height a run lies at on the floor,
// the ribbon's own half-width and the wander that rides on top of the sag — capped at CABLE_SAG,
// which is the slack a cable actually has.
//
// A CAP AND NOT A CONSTANT, because everything this family hangs off came down the wall. A machine's
// lead now leaves at a third of the unit's height and arrives at a socket half a unit off the floor,
// so a fixed 0.45 of droop takes the mid-span THROUGH the floor: measured at min y 0.0203 on the
// emitted ribbon, under `RenderConfig.PAINT_Y` 0.03 and so inside the aisle markings
  static inline function droop(a:Array<Float>, c:Array<Float>):Float
    {
      return Math.max(0, Math.min(FacilityStyle.CABLE_SAG,
        Math.min(a[1], c[1]) - FacilityStyle.CABLE_FLOOR_Y - FacilityStyle.CABLE_W / 2 -
          FacilityStyle.CABLE_WAVE));
    }

// THE ONE POINT EVERY CABLE IN THIS FILE LEAVES A MOUNT FROM, slid along the wall by the hand `s`
// (0 is dead under it, which is what a lead heading out into the room wants).
//
// ON THE MOUNT'S OWN FACE and not the floor beneath it, which is the second thing the game reported
// about this family: a floor lead that begins at floor level begins a socket's height away from the
// socket it is supposed to be plugged into, so it reads as stopping short of the wall. Starting it
// here and letting the chord fall to the floor costs nothing — `strip` bows about n cross t, and with
// n straight up that stays horizontal however the chord is tilted.
//
// AT THE MOUNT'S CENTRE HEIGHT and not its low edge, which was the first cut and read as a cable
// plugged into the wall UNDER the socket. A plate is opaque where the art is, so a run leaving its
// middle has its cut end hidden by the thing it leaves; and the extra half-unit of height is what
// gives `droop` its full CABLE_SAG back on a short hop.
//
// and WELL INSIDE the drawn art rather than at the quad's edge, for FacilityStyle.SOCK_LEAD's reason
  static function anchor(m:Facility, p:Mount, s:Int):Array<Float>
    {
      var sl = FacilityGeom.slab(m, p.col + DC[p.dir], p.row + DR[p.dir]);
      var c = CityConfig.cellToWorld(p.col, p.row);
      var w = (p.fit ? FacilityStyle.FIT_W : FacilityStyle.SOCK_W);
      var h = w * FacilityStyle.SOCK_LEAD;
      var y = (p.fit ? FacilityStyle.FIT_Y : FacilityStyle.SOCK_Y);
      var dir = p.dir ^ 1;
      var e = FacilityStyle.MOUNT_PROUD + FacilityStyle.CABLE_EPS;
      if (dir < 2)
        return [c.x + s * h, y, (dir == 0 ? sl.z0 - e : sl.z1 + e)];
      return [(dir == 2 ? sl.x0 - e : sl.x1 + e), y, c.z + s * h];
    }

// the floor units, and the cable that leads to each: a drum, a welding set, a distribution board
// standing out in the room with a trailing lead back to the wall.
//
// THE REACH IS THE NEAREST CLEAR ONE and not a rolled distance. The unit walks along its mount's wall
// and takes the first cell from UNIT_REACH_MIN out that it may STAND on, with a lead that may pass
// every cell before it — two different questions, see `passes`. A unit is never stood in a worktop;
// the lead behind one is where a lead goes. A mount whose wall is blocked outright simply gets no
// unit, which is the same "the compound supplies the emptiness" argument the links run on
  static function units(pack:MeshBuf, cab:MeshBuf, m:Facility, list:Array<Mount>):Array<Unit>
    {
      var out:Array<Unit> = [];
      for (p in list)
        {
          // ONE CABLE PER MOUNT, so a socket that already took a machine's lead or a link is done —
          // and only a mount that DRAWS somewhere a cable can leave from may source one
          if (p.used ||
              !sources(p))
            continue;
          // ALONG the wall and never out from it. Straight out was the first cut and it is the one
          // thing this family must not do: in a ROOM it walks the lead across the aisle markings
          // FacilityPaint just struck, and in a CORRIDOR it walks it across the corridor — a cable
          // laid over the route everyone uses, which no compound would leave and which reads as a
          // mistake. Along the wall a lead is where a lead is, and it stays out of every lane by
          // construction rather than by a clearance
          var sc = (p.dir < 2 ? 1 : 0);
          var sr = (p.dir < 2 ? 0 : 1);
          var s = (FacilityModel.mix((p.col * 40503) ^ (p.row * 12345)) % 2 == 0 ? 1 : -1);
          for (turn in 0...2)
            {
              if (run(pack, cab, m, p, sc * s, sr * s, out))
                break;
              s = -s;
            }
        }
      return out;
    }

// one mount's try at standing a unit `s` cells along its own wall. returns whether one went up.
//
// the whole span has to be FREE FLOOR with UNBROKEN MASONRY beside it, which is two tests doing two
// jobs: the floor is what the unit stands on and the lead crosses, and the masonry is what keeps the
// lead ON the wall — a doorway is not solid wall, so a run can never be laid across a threshold
  static function run(pack:MeshBuf, cab:MeshBuf, m:Facility, p:Mount, sc:Int, sr:Int,
      out:Array<Unit>):Bool
    {
      for (d in 1...FacilityStyle.UNIT_REACH_MAX + 1)
        {
          var c = p.col + sc * d;
          var r = p.row + sr * d;
          if (!passes(m, c, r) ||
              !FacilityModel.isSolidWall(m, c + DC[p.dir], r + DR[p.dir]))
            return false;
          if (d < FacilityStyle.UNIT_REACH_MIN ||
              !open(m, c, r) ||
              !clearOf(out, c, r))
            continue;
          var g = FacilityModel.mix((c * 971658137) ^ (r * 1266489917));
          var b = base(m, c, r, p.dir);
          stand(pack, b, FacilityStyle.ELEC_UNIT + STAND[g % STAND.length]);
          // BOTH CONTACTS ARE SIZED TO THE ART AND NOT THE QUAD (FacilityStyle.UNIT_FILL_W/_H), which
          // is the whole of the wall shadow being too large: the sprite fills 0.64 across and 0.77 up
          // of what it was handing over
          var hw = FacilityStyle.UNIT_SZ * FacilityStyle.UNIT_FILL_W / 2;
          FacilityDetail.stand({
            col: c,
            row: r,
            dir: p.dir,
            a0: (p.dir < 2 ? b[0] : b[2]) - hw,
            a1: (p.dir < 2 ? b[0] : b[2]) + hw,
            len: 1,
            y: b[1],
            h: FacilityStyle.UNIT_SZ * FacilityStyle.UNIT_FILL_H,
          });
          // and the FLOOR under it, which it had nothing on at all. a footprint goes to the field
          // every builder that stands something indoors feeds — no quad, no mesh, no draw call — and
          // it is square because a sprite has no depth to read one off: a floor-standing cabinet is
          // about as deep as it is wide
          ContactMask.prop(b[0] - hw, b[0] + hw, b[2] - hw, b[2] + hw);
          // and BEHIND it, not on its face. the quad is vertical and its base point IS its plane, so a
          // lead ending at `b` ended coplanar with the art and drew OVER it — reported as the cable
          // being in front of the object. UNIT_BACK gives the sprite the body depth it does not have,
          // toward the wall, which is where a lead plugs in anyway
          var f = p.dir ^ 1;
          var bk = FacilityStyle.UNIT_SZ * FacilityStyle.UNIT_BACK;
          strip(cab, {
            a: anchor(m, p, 0),
            // ARRIVING ON THE BODY AND NOT AT THE FOOT: half this band stands on legs, castors or a
            // pallet, so a lead ending at the floor ends UNDER the object rather than at it
            c: [b[0] - NX[f] * bk, b[1] + FacilityStyle.UNIT_SZ * FacilityStyle.UNIT_FOOT,
              b[2] - NZ[f] * bk],
            n: UP,
            // out into the room, so the slack in the lead bows away from the wall rather than into it
            side: [NX[f], 0.0, NZ[f]],
            bow: FacilityStyle.CABLE_SNAKE,
            wave: FacilityStyle.CABLE_WAVE,
            seed: g,
          });
          plug(pack, m, p, 0);
          p.used = true;
          out.push({
            col: c,
            row: r,
          });
          return true;
        }
      return false;
    }

// where a unit's base sits in its cell, world: centred along the wall and pushed BACK against it, so
// it is parked rather than stood in the middle of the floor. UNIT_OFF is measured off the slab FACE
// and never off the cell boundary — the trap every wall family here records, a straight run insetting
// its room face a whole unit into the wall cell
  static function base(m:Facility, col:Int, row:Int, dir:Int):Array<Float>
    {
      var s = FacilityGeom.slab(m, col + DC[dir], row + DR[dir]);
      var c = CityConfig.cellToWorld(col, row);
      var y = FacilityGround.surfY(m.surf[row][col]);
      var o = FacilityStyle.UNIT_OFF;
      return switch (dir)
        {
          case 0: [c.x, y, s.z1 + o];
          case 1: [c.x, y, s.z0 - o];
          case 2: [s.x1 + o, y, c.z];
          default: [s.x0 - o, y, c.z];
        }
    }

// one unit STANDING on the floor: a frontal quad, fixed yaw, leaned back by FacilityStyle.UNIT_TILT.
//
// FRONTAL AND NOT CAMERA-FACING, the rule the object-effect guard draws: this is glued to a world
// cell, so it holds its yaw and stays coplanar with the sprites beside it from any camera angle.
// render.particles.Sparks.flameQuad builds the same basis out of a rotation; here the four corners
// are written out, because a merged buffer has no transform.
//
// IT DOES NOT LEAN, which is where it parts company with every other sprite here and the reason is
// geometric rather than stylistic: UNIT_TILT is 0 because a unit is the only one of them parked ON a
// wall, and Sprites.TILT 0.6 puts the top of a 2.6-unit quad 1.47 back into masonry it stands 0.9
// clear of. The basis is kept general so the knob is a knob
//
// the quad is pinned by its BASE, so the lean tips the top back toward the wall and the feet stay on
// the floor — flameQuad's own correction, arrived at from the other side (it shifts a centre, this
// simply never uses one)
  static function stand(b:MeshBuf, p:Array<Float>, idx:Int):Void
    {
      var h = FacilityStyle.UNIT_SZ;
      var hw = h / 2;
      // up, after leaning back by UNIT_TILT: the quad's own +y rotated -UNIT_TILT about x. that knob
      // is 0 and the whole of why is on it — a unit parked against a wall has no room to lean into
      var uy = Math.cos(FacilityStyle.UNIT_TILT) * h;
      var uz = -Math.sin(FacilityStyle.UNIT_TILT) * h;
      // and the base dropped through the floor by the art's own margin, so its FEET meet it
      var y = p[1] - FacilityStyle.UNIT_SINK * uy;
      var z = p[2] - FacilityStyle.UNIT_SINK * uz;
      var t = FacilityStyle.ELEC_COLS;
      var cc = idx % t, cr = Std.int(idx / t);
      var u0 = cc / t, u1 = (cc + 1) / t;
      var v0 = 1 - (cr + 1) / t, v1 = 1 - cr / t;
      MeshBufTools.quad(b,
        [p[0] - hw, y, z],
        [p[0] + hw, y, z],
        [p[0] + hw, y + uy, z + uz],
        [p[0] - hw, y + uy, z + uz],
        [u0, v0, u1, v0, u1, v1, u0, v1]);
    }

// is this cell clear of every unit already stood
  static function clearOf(out:Array<Unit>, col:Int, row:Int):Bool
    {
      for (u in out)
        if (Std.int(Math.abs(u.col - col)) < FacilityStyle.UNIT_SPACING &&
            Std.int(Math.abs(u.row - row)) < FacilityStyle.UNIT_SPACING)
          return false;
      return true;
    }

// the loose kit lying about on the floors — an offcut coil, a taped-down run, a dropped plug. one
// cell in SCAT_ODDS carries one, rolled off the cell so it comes back identical on every rebuild.
//
// ROOMS AND CORRIDORS BOTH, which is the whole point of it: FacilityPaint.freeFloor already answers
// "is there floor here nobody is standing on" over Surf.TILE, Surf.LINO and Surf.GRATE alike, so this
// family needed no surface rule of its own
  static function scatter(b:MeshBuf, m:Facility, taken:Array<Unit>):Int
    {
      var n = 0;
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var g = FacilityModel.mix((col * 374761393) ^ (row * 40503));
            if (g % FacilityStyle.SCAT_ODDS != 0 ||
                !open(m, col, row))
              continue;
            // AND IT HAS TO BE AGAINST SOMETHING. Reported from the game twice, once of the rooms and
            // once of the corridors: kit dropped in the middle of the floor is kit dropped in the
            // walking route. A cell test alone does not answer it either — a corridor is two cells
            // wide, so BOTH its cells touch a wall and a decal centred in one is still dead in the
            // lane. So the cell must hug something AND the decal is slid to that hand's cell edge
            var h = hug(m, col, row);
            var take = (h < 0);
            for (u in taken)
              if (u.col == col && u.row == row)
                take = true;
            if (take)
              continue;
            var sz = FacilityStyle.SCAT_SZ +
              ((g >>> 4) % 1000) / 1000 * FacilityStyle.SCAT_SZ_VAR;
            var c = CityConfig.cellToWorld(col, row);
            var o = CityConfig.CELL / 2 - sz / 2;
            flat(b,
              [c.x + DC[h] * o,
               FacilityGround.surfY(m.surf[row][col]) + FacilityStyle.ELEC_FLOOR_Y,
               c.z + DR[h] * o],
              sz,
              ((g >>> 14) % 1000) / 1000 * 2 * Math.PI,
              FacilityStyle.ELEC_SCATTER + (g >>> 24) % FacilityStyle.ELEC_BAND);
            n++;
          }
      return n;
    }

// which hand of this cell has something to lean against — masonry, a bench or a standing fitting —
// or -1 for a cell out in the open. the FIRST one found and not the nearest: a cell with two is a
// corner, and either hand puts the decal out of the way
  static function hug(m:Facility, col:Int, row:Int):Int
    {
      for (dir in 0...4)
        {
          var c = col + DC[dir];
          var r = row + DR[dir];
          if (!FacilityModel.inside(m, c, r))
            continue;
          if (FacilityModel.isSolidWall(m, c, r) ||
              m.table[r][c] ||
              m.deco[r][c] != 0)
            return dir;
        }
      return -1;
    }

// one flat decal lying on a floor cell, TURNED about its own centre.
//
// it cannot go through FacilityGeom.cap, which takes an axis-aligned rect — and the turn is the
// point. A rank of square-on cut-outs reads as a layout; a free yaw reads as things someone put down.
// FacilityClutter.emit's own corner order and winding, so the face looks UP
  static function flat(b:MeshBuf, c:Array<Float>, sz:Float, yaw:Float, idx:Int):Void
    {
      var hs = sz * 0.5;
      var cs = Math.cos(yaw), sn = Math.sin(yaw);
      var lx = [ -hs, hs, hs, -hs ];
      var lz = [ hs, hs, -hs, -hs ];
      var wx = [], wz = [];
      for (i in 0...4)
        {
          wx.push(c[0] + lx[i] * cs - lz[i] * sn);
          wz.push(c[2] + lx[i] * sn + lz[i] * cs);
        }
      var t = FacilityStyle.ELEC_COLS;
      var cc = idx % t, cr = Std.int(idx / t);
      var u0 = cc / t, u1 = (cc + 1) / t;
      var v0 = 1 - (cr + 1) / t, v1 = 1 - cr / t;
      var y = c[1];
      MeshBufTools.quad(b,
        [wx[0], y, wz[0]], [wx[1], y, wz[1]], [wx[2], y, wz[2]], [wx[3], y, wz[3]],
        [u0, v0, u1, v0, u1, v1, u0, v1]);
    }

// one run: a quad strip from `a` to `c`, both in the plane `o.n` describes, bowing between them.
//
// THE WIDTH AXIS AND THE BOW AXIS ARE THE SAME VECTOR AND MUST NOT BE THE SAME VARIABLE. `w` is the
// in-plane perpendicular of the chord (n cross t), and it is what the ribbon is widened along and
// what winds the quads — negate it and every face of the run turns to look into the masonry (or into
// the floor) and simply never appears. The bow rides the same axis with its own SIGN, taken off
// `o.side` where the caller knows which way it should go and off the seed where it does not.
//
// v runs along the length at CABLE_TILE and u across the ribbon 0..1, which is the mapping the art's
// cross-section shading exists for — that is what makes a flat strip read as round
  public static function strip(b:MeshBuf, o:StripOpts):Void
    {
      var dx = o.c[0] - o.a[0], dy = o.c[1] - o.a[1], dz = o.c[2] - o.a[2];
      var len = Math.sqrt(dx * dx + dy * dy + dz * dz);
      if (len < 0.001)
        return;
      var tx = dx / len, ty = dy / len, tz = dz / len;
      // n cross t, perpendicular to the chord and still in the plane, because n has no component
      // along it
      var wx = o.n[1] * tz - o.n[2] * ty;
      var wy = o.n[2] * tx - o.n[0] * tz;
      var wz = o.n[0] * ty - o.n[1] * tx;
      var wl = Math.sqrt(wx * wx + wy * wy + wz * wz);
      if (wl < 0.001)
        return;
      wx /= wl;
      wy /= wl;
      wz /= wl;
      // the bow's own sign, never w's: flipping w flips the winding. a hint too nearly perpendicular
      // to w to answer — a vertical drop asked which way is down — falls through to the seed
      var d = (o.side != null ? wx * o.side[0] + wy * o.side[1] + wz * o.side[2] : 0.0);
      var sg = (Math.abs(d) > 0.1 ? (d > 0 ? 1.0 : -1.0) : (o.seed % 2 == 0 ? 1.0 : -1.0));
      var ph = ((o.seed % 1000) / 1000) * 2 * Math.PI;
      // the bow is world units, so a run SHORTER than a cell has to have it taken back off or the
      // 2-unit drop off a machine lid swings like a skipping rope
      var amp = Math.min(1.0, len / CityConfig.CELL);
      var hw = FacilityStyle.CABLE_W / 2;
      var n = FacilityStyle.CABLE_STEPS;
      var px = 0.0, py = 0.0, pz = 0.0;
      for (i in 0...n + 1)
        {
          var t = i / n;
          // zero at both ends, so the run stays glued to what it is bolted to
          var taper = 4 * t * (1 - t);
          var off = sg * amp * taper * (o.bow + o.wave * Math.sin(t * 3 * Math.PI + ph));
          var mx = o.a[0] + dx * t + wx * off;
          var my = o.a[1] + dy * t + wy * off;
          var mz = o.a[2] + dz * t + wz * off;
          if (i > 0)
            {
              var v0 = (i - 1) / n * len / FacilityStyle.CABLE_TILE;
              var v1 = t * len / FacilityStyle.CABLE_TILE;
              // (t, w, n) is right-handed, so this order is counter-clockwise seen from the room
              MeshBufTools.quad(b,
                [px - wx * hw, py - wy * hw, pz - wz * hw],
                [mx - wx * hw, my - wy * hw, mz - wz * hw],
                [mx + wx * hw, my + wy * hw, mz + wz * hw],
                [px + wx * hw, py + wy * hw, pz + wz * hw],
                [0, v0, 0, v1, 1, v1, 1, v0]);
            }
          px = mx;
          py = my;
          pz = mz;
        }
    }

// the pack's whole family as one mesh. FacilityClutter.add's material exactly, and for its three
// reasons: an opaque alphaTest draws DoubleSide in ONE pass, it still writes depth so nothing sorts
// against the floor under it, and leaving `transparent` false keeps VisionMask on its darkening
// branch rather than the alpha-scaling one (the trap FacilityGeom.addPane records). Sharing that
// material is also why this family costs no new program
  static function add(scene:Scene, b:MeshBuf):Void
    {
      if (b.idx.length == 0)
        return;
      var mesh = new Mesh(FacilityGeom.geom(b), VisionMask.patch(new MeshLambertMaterial({
        map: Textures.loadTexture(FacilityStyle.ELEC_TEX, 'wall', 1),
        alphaTest: FacilityStyle.ELEC_CUT,
        side: THREE.DoubleSide,
      })));
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }
}
