package render.facility;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;
import render.Textures;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// how far the clear floor runs one way from a cell, and what ended it
typedef Reach = {
  // clear cells stepped over, not counting the one started from
  cells:Int,
  // and whether FURNITURE is what stopped the walk. the question is deliberately that way round:
  // everything else — masonry, a doorway, glazing, the grid edge — ends the floor, and only a thing
  // STANDING on the floor is the other case
  furn:Bool,
  // and whether a DOORWAY did, which is the one boundary a line is not struck against at all: a door
  // opening onto a lane's SIDE breaks the line for its width, because that gap is how a marked floor
  // says the way in is here. a line run unbroken past a doorway says the opposite
  door:Bool,
};

// everything struck on the compound's floors: the PARKING LOT — its bays against every pavement
// apron and the back-to-back rows that march on into the middle — the main road's lane lines, and
// the markings on the ROOM floors indoors.
//
// ONE merged mesh in the city's own worn traffic paint, which is why the road's few lines share a
// file with the lot's many AND with the rooms': they cost one draw call together. opaque
// and lit like the ground under them (render.world.Ground says why it is not a cutout), floating
// FacilityStyle.PAINT_Y over the surface each line belongs to and NOT over y = 0.
//
// the indoor half takes the same worn paint and a mesh of its own, and the split is the COLOUR and
// nothing else: an aisle is yellow and a parking bay is white, which is not a preference but what
// the marking convention means by each (FacilityStyle.MARK_COLOR). one map, two `color` uniforms,
// so the second mesh is +1 call and +0 programs — `color` is a uniform in Lambert, not a program
// key. see `indoor`.
//
// the lot's geometry is never searched for as a rectangle. a lot cell against a pavement apron IS
// the edge cars park at, so the whole lattice falls out of the tile grid: a RUN is the stretch of
// asphalt holding its pavement on one side, and the run decides both phases — the rhythm along the
// kerb (`runStart`) and the depth marching away from it (`bayLine`)
class FacilityPaint
{
  static inline var CELL = CityConfig.CELL;
  // the four cell-edge directions, in render.facility.FacilityGeom's own numbering. `dir ^ 1` is the
  // opposite of a direction, which is how a bay line marches away from the kerb it hangs off
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];
  // how wide the pavement band beside the main road is, in cells — the generator's own `sidewalkw`.
  // `isEntry` measures against it and nothing else here does
  static inline var SIDEWALK_W = 2;

  // how many SEGMENTS `indoor` struck on the indoor floors — one per cell of one line of an aisle
  // pair, so a marked room contributes roughly twice its long axis and a marked corridor cell
  // contributes two. read by __facility(), which is the only handle on it: this is a merged mesh
  // with no instance count. the shape render.world.ContactMask.count already uses. 0 in a compound
  // with rooms means the gate broke, not that the floors are bare
  public static var marks = 0;

// every painted line in the compound. TWO meshes, split by colour and by nothing else — see the
// header
  public static function build(scene:Scene, m:Facility):Void
    {
      var b = MeshBufTools.make();
      lanes(b, m);
      bays(b, m);
      add(scene, b, FacilityStyle.PAINT_COLOR);
      var mk = MeshBufTools.make();
      indoor(mk, m);
      add(scene, mk, FacilityStyle.MARK_COLOR);
    }

// the main road's lane lines. the compound has exactly one road, and it is a straight band laid
// across the FULL WIDTH at one edge (game.FacilityAreaGenerator lines 66-69). so the band is its row
// extent, it never meets an intersection, and none of render.world.Ground's crossing machinery is
// needed here
  static function lanes(b:MeshBuf, m:Facility):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var lw = RenderConfig.LINE_W;
      var r0 = -1;
      var r1 = -1;
      for (row in 0...m.h)
        if (m.surf[row][0] == Surf.ROAD)
          {
            if (r0 < 0)
              r0 = row;
            r1 = row;
          }
      if (r1 - r0 + 1 != 4)
        return;
      var y = FacilityGround.surfY(Surf.ROAD) + FacilityStyle.PAINT_Y;
      var x0 = -half;
      var x1 = m.w * CELL - half;
      for (k in 0...3)
        {
          var z = (r0 + k + 1) * CELL - half;
          // the middle boundary is the centre of the road and takes the double solid line; the two
          // either side are lane dividers and dash
          if (k != 1)
            {
              var p = x0;
              while (p < x1)
                {
                  mark(b, p, Math.min(p + RenderConfig.DASH_LEN, x1), z - lw / 2, z + lw / 2, y);
                  p += RenderConfig.DASH_LEN + RenderConfig.DASH_GAP;
                }
              continue;
            }
          var g = RenderConfig.DOUBLE_GAP / 2;
          mark(b, x0, x1, z - g - lw / 2, z - g + lw / 2, y);
          mark(b, x0, x1, z + g - lw / 2, z + g + lw / 2, y);
        }
    }

// the parking lot. one pass over the asphalt, striking the lines of whichever run each cell belongs
// to — the first pavement it finds, so a cell in a corner is claimed once and the two runs meeting
// there do not both stripe it
  static function bays(b:MeshBuf, m:Facility):Void
    {
      var dom = dominant(m);
      // and the one bay that is spoken for: the gate's guard booth stands on it, and a spot marked
      // out under a building is the same mistake `nearBuild` exists to stop (render.facility
      // .FacilityEntry, which reads the entry hole this pass already knows how to find)
      var gate = FacilityEntry.find(m);
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.surf[row][col] != Surf.LOT ||
                isEntry(m, col, row) ||
                (gate != null &&
                 col == gate.boothCol &&
                 row == gate.mouthRow))
              continue;
            for (dir in 0...4)
              {
                if (!isSurf(m, col + DC[dir], row + DR[dir], Surf.WALKWAY))
                  continue;
                // the run's rhythm, struck on the cell's OWN west (or north) edge and counted from
                // the CORNER the run starts at, not from the world grid — a run that begins on an
                // odd cell would otherwise open with a half-width spot. the lot test is what keeps
                // the first divider off the kerb it starts at: where a second pavement meets this
                // one the divider would lie ALONG that kerb, parallel to the pavement instead of
                // across it, and that bay is bounded by the kerb already
                var s = runStart(m, col, row, dir);
                if (((dir < 2 ? col : row) - s) % FacilityStyle.BAY_SPACING == 0 &&
                    isSurf(m, col + (dir < 2 ? -1 : 0), row + (dir < 2 ? 0 : -1), Surf.LOT))
                  bayLine(b, m, col, row, dir, dir == dom);
                // and one closing the run where the KERB ENDS. the next cell along is still lot but
                // has no pavement to park against, so nothing else strikes that edge and the last
                // bay bleeds into the open lot — which is exactly the inside corner of an L-shaped
                // pavement, where the two runs meet. only where the closing edge lands ON the
                // rhythm, though: struck anywhere else it fences off a half-width spot
                var tc = col + (dir < 2 ? 1 : 0);
                var tr = row + (dir < 2 ? 0 : 1);
                if (((dir < 2 ? tc : tr) - s) % FacilityStyle.BAY_SPACING == 0 &&
                    isSurf(m, tc, tr, Surf.LOT) &&
                    !isSurf(m, tc + DC[dir], tr + DR[dir], Surf.WALKWAY))
                  bayLine(b, m, tc, tr, dir, dir == dom);
                break;
              }
          }
    }

// one whole bay line, marching away from the kerb: the row of bays against the pavement, then an
// aisle, then the back-to-back rows that fill the middle. (col, row) is the cell whose leading edge
// the line is struck on — the run's own for its rhythm, the next one along for the line that closes
// it. `deep` is off for every kerb but the compound's busiest, whose rows are the only ones that
// march
  static function bayLine(b:MeshBuf, m:Facility, col:Int, row:Int, dir:Int, deep:Bool):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      // inward is away from the pavement, so the line marches on the OPPOSITE direction's step
      var dc = DC[dir ^ 1];
      var dr = DR[dir ^ 1];
      // the line's own coordinate across the run, and the kerb edge it measures its depth from
      var e = (dir < 2 ? col : row) * CELL - half;
      var k = ((dir < 2 ? row : col) + (dir == 1 || dir == 3 ? 1 : 0)) * CELL - half;
      var step = (dir == 1 || dir == 3 ? -CELL : CELL);
      // a line that OPENS a bay carries the row divider too; the one that CLOSES a run has no bay
      // after it. the run's own cells have the pavement beside them, the closing cell is past the end
      var lead = isSurf(m, col + DC[dir], row + DR[dir], Surf.WALKWAY);
      var o = 0;
      var len = FacilityStyle.BAY_CELLS;
      while (FacilityModel.inside(m, col + dc * o, row + dr * o))
        {
          // a blocked band is SKIPPED and not stopped at — a building standing in the middle of the
          // lot must not take the asphalt behind it out of the lattice too
          if (open(m, col + dc * o, row + dr * o, dir, len, o > 0))
            {
              divider(b, dir >= 2, e, k + step * o, k + step * (o + len));
              // a marching band is TWO rows of bays laid back to back, so it takes the line down its
              // middle that tells one row from the other. one bay's worth per divider, which is what
              // makes the segments meet into a line the length of the row
              if (lead && len > FacilityStyle.BAY_CELLS)
                divider(b, dir < 2, k + step * (o + FacilityStyle.BAY_CELLS),
                  e, e + FacilityStyle.BAY_SPACING * CELL);
            }
          if (!deep)
            return;
          o += len + FacilityStyle.AISLE_CELLS;
          len = FacilityStyle.BAY_CELLS * 2;
        }
    }

// one bay divider: a stripe of paint at `e` on the axis ACROSS the run, spanning a0..a1 along it,
// floating over the lot's own surface and not over y = 0
  static function divider(b:MeshBuf, alongX:Bool, e:Float, a0:Float, a1:Float):Void
    {
      var lw = RenderConfig.LINE_W;
      var y = FacilityGround.surfY(Surf.LOT) + FacilityStyle.PAINT_Y;
      if (alongX)
        mark(b, Math.min(a0, a1), Math.max(a0, a1), e - lw / 2, e + lw / 2, y);
      else
        mark(b, e - lw / 2, e + lw / 2, Math.min(a0, a1), Math.max(a0, a1), y);
    }

// is the lot open for this stretch of a bay line — `len` cells of asphalt from here inward? an
// INNER stretch has to clear every other pavement's row of bays AND the aisle behind it: laid any
// closer, the marching rows meet a row struck at right angles nose to nose, with nothing between
// them for a car to turn in. the row against the kerb does not clear anything: that row IS one of
// those, and in a corner it shares its cells with the other one by design
  static function open(m:Facility, col:Int, row:Int, dir:Int, len:Int, inner:Bool):Bool
    {
      var dc = DC[dir ^ 1];
      var dr = DR[dir ^ 1];
      var keep = FacilityStyle.BAY_CELLS + FacilityStyle.AISLE_CELLS;
      for (i in 0...len)
        {
          var c = col + dc * i;
          var r = row + dr * i;
          if (!isSurf(m, c, r, Surf.LOT))
            return false;
          // and the whole BAY the divider opens has to keep off a structure, not just the divider's
          // own cells — the line down the middle of a marching band runs the bay's full width, so a
          // strip checked one cell wide would let that one reach a wall the divider stopped short of
          for (j in 0...FacilityStyle.BAY_SPACING)
            if (nearBuild(m, c + (dir < 2 ? j : 0), r + (dir < 2 ? 0 : j)))
              return false;
          if (!inner)
            continue;
          for (d in 0...4)
            {
              if (d == dir)
                continue;
              for (j in 1...keep + 1)
                if (isSurf(m, c + DC[d] * j, r + DR[d] * j, Surf.WALKWAY))
                  return false;
            }
        }
      return true;
    }

// is this cell within FacilityStyle.BUILD_GAP of a structure — a wall, a shutter or an indoor floor?
// the four outdoor surfaces are the only ones a car ever stands on, so anything else is a building
  static function nearBuild(m:Facility, col:Int, row:Int):Bool
    {
      var g = FacilityStyle.BUILD_GAP;
      for (r in row - g...row + g + 1)
        for (c in col - g...col + g + 1)
          {
            if (!FacilityModel.inside(m, c, r))
              continue;
            var s = m.surf[r][c];
            if (s != Surf.ROAD &&
                s != Surf.WALKWAY &&
                s != Surf.LOT &&
                s != Surf.GRASS)
              return true;
          }
      return false;
    }

// which of the four kerb directions the compound parks against most. only that one's lines march
// into the middle, so the open asphalt is filled by ONE lattice instead of by two crossing ones
  static function dominant(m:Facility):Int
    {
      var n = [0, 0, 0, 0];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.surf[row][col] != Surf.LOT)
              continue;
            for (dir in 0...4)
              if (isSurf(m, col + DC[dir], row + DR[dir], Surf.WALKWAY))
                n[dir]++;
          }
      var best = 0;
      for (dir in 1...4)
        if (n[dir] > n[best])
          best = dir;
      return best;
    }

// the aisle marking on the compound's INDOOR floors, and the only paint in this file that is not on
// asphalt. `facility/floor-tile` is one flat tiling grid over a whole room and the corridor's own
// lino is flatter still, so the contrast has to be PLACED — the argument the lobby notice board and
// the damp band are both built on, taken to the surfaces those two skipped.
//
// AN AISLE IS MARKED AT ITS EDGES, NEVER DOWN ITS MIDDLE, and the first build of this got it
// backwards. A centre line is ROAD logic: a lane divider only means anything where two streams pass
// in opposite directions, and indoors nothing divides. What a building marks is a strip that has to
// stay clear — a zone — so it takes a PAIR of lines, and it is drawn in the colour the marking
// convention assigns to circulation (FacilityStyle.MARK_COLOR).
//
// THE PAIR'S OFFSET IS DERIVED FROM THE CLEAR FLOOR AND NOT SET. `reach` walks out from the middle
// until something stops it and says WHAT stopped it, because the three answers take different
// clearances — see MARK_WALL_CLEAR. Rooms take the MINIMUM reach over the whole run so the pair comes
// out straight; a per-cell edge would wobble in and out at every bench end.
//
// AND MARKING IS FOR TRAFFIC, which is what decides where the derived pair is struck AT ALL. Not
// every room has an aisle: the gap between two bench runs is a WORK aisle and takes no paint, and a
// big open lab whose benches are against its walls has a route across it but not one bounded by
// them. Both are guards on the LANE and not on the room — MARK_LANE_MIN and MARK_ROOM_MAX.
//
// A DOORWAY IS THE ONE BOUNDARY NOTHING IS STRUCK AGAINST. A lane ending at a door runs to the
// threshold; a door opening onto a lane's SIDE breaks its line for the door's width; and a lane
// running into a JUNCTION carries on past its own cell to meet the through lane's line. The three
// together are what make the markings one connected network instead of a set of unrelated strokes,
// which is the whole point of marking a floor.
//
// ROOMS AND CORRIDORS ARE TWO PASSES BECAUSE THEY ARE TWO SHAPES. A room is a rect in `m.rooms` with
// a long axis and a middle. A corridor is in no list anywhere — it is an L, a T and a ring as often
// as it is a length — so it is read per CELL, off the two runs through it, exactly as
// render.facility.FacilityLamps reads one.
//
// NEITHER NEEDS A CLAIMED-CELL LIST, which is what the corridor pass would otherwise have to
// negotiate with the casework, the dead-end bins and the directional signs. MARK_WALL_CLEAR is why:
// everything those three stand is against masonry, and a line set 1.7 in from a wall face clears
// CASE_D 1.4 outright. A clearance is cheaper than a coupling.
//
// AND NO STALE-generatorInfo GUARD, where FacilityLamps.lit needs one. The room pass walks
// `m.rooms`, which comes straight off generatorInfo, but strikes only on a cell that answers
// `freeFloor` off the SAVED GRID — so a rect that no longer describes the building lays nothing, one
// cell at a time
  static function indoor(b:MeshBuf, m:Facility):Void
    {
      marks = 0;
      var y = FacilityGround.surfY(Surf.TILE) + FacilityStyle.PAINT_Y;
      for (r in m.rooms)
        roomAisle(b, m, r, y);
      corridorAisle(b, m, y);
    }

// the pair bounding one room's aisle, down its long axis.
//
// the offset is taken as the MINIMUM clear reach over every cell of the run whose middle is free, so
// the line is guaranteed inside every one of those cells' clear extent and comes out dead straight.
// a cell whose middle is NOT free — an island bench sitting on the centre line — breaks the run
// rather than collapsing it, which is the same per-cell emission the segments already run on
  static function roomAisle(b:MeshBuf, m:Facility, r:_Room, y:Float):Void
    {
      var alongX = (r.w >= r.h);
      var len = (alongX ? r.w : r.h);
      if (len < FacilityStyle.MARK_AISLE_MIN)
        return;
      var base = (alongX ? r.x1 : r.y1);
      var mid = (alongX ? Std.int((r.y1 + r.y2) / 2) : Std.int((r.x1 + r.x2) / 2));
      var off = [0.0, 0.0];
      for (i in 0...2)
        {
          var s = i * 2 - 1;
          var least = -1;
          var furn = false;
          for (k in 0...len)
            {
              var col = (alongX ? base + k : mid);
              var row = (alongX ? mid : base + k);
              if (!freeFloor(m, col, row))
                continue;
              var e = reach(m, col, row, (alongX ? 0 : s), (alongX ? s : 0));
              if (least >= 0 &&
                  e.cells >= least)
                continue;
              least = e.cells;
              furn = e.furn;
            }
          if (least < 0)
            return;
          // out to the far boundary of the last clear cell, then back off whatever stopped there
          off[i] = CELL / 2 + least * CELL -
            (furn ? FacilityStyle.MARK_FURN_CLEAR : FacilityStyle.MARK_WALL_CLEAR);
        }
      // both sides are derived before either is struck, because both guards are on the LANE and not
      // on a line. NARROW: a room whose clear floor is one cell wide leaves 4 units and loses 2.4 of
      // them to two furniture clearances, and 1.6 between the pair reads as one thick line — a work
      // aisle between two bench runs is not a traffic lane and takes no marking at all. WIDE: a big
      // open lab has its benches against the walls, so the derived pair lands ON those walls and
      // outlines the room instead of marking a route across it; over the cap both edges come in
      // equally, which keeps the lane centred where the clear floor put it
      var w = off[0] + off[1];
      if (w < FacilityStyle.MARK_LANE_MIN)
        return;
      if (w > FacilityStyle.MARK_ROOM_MAX)
        for (i in 0...2)
          off[i] -= (w - FacilityStyle.MARK_ROOM_MAX) / 2;
      for (i in 0...2)
        line(b, m, alongX, base, len, mid, i * 2 - 1, off[i], y);
    }

// one of a room pair, walked cell by cell along the run at a fixed offset from the middle cell's
// centre. `s` is which side of the middle it bounds and `off` how far out
  static function line(b:MeshBuf, m:Facility, alongX:Bool, base:Int, len:Int, mid:Int, s:Int,
      off:Float, y:Float):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var a0 = base * CELL - half;
      var a1 = (base + len) * CELL - half;
      // the inset is taken where MASONRY ends the run and NOT where a DOORWAY does: an aisle marks a
      // route and a route goes through the door, so a line stopped a unit short of the one opening
      // it leads to reads as a line that leads nowhere. a doorway also carries no masonry at floor
      // level (FacilityDetail.masonry skips it), so there is no crease here to keep off either
      if (!FacilityModel.isDoor(m, (alongX ? base - 1 : mid), (alongX ? mid : base - 1)))
        a0 += FacilityStyle.MARK_AISLE_INSET;
      if (!FacilityModel.isDoor(m, (alongX ? base + len : mid), (alongX ? mid : base + len)))
        a1 -= FacilityStyle.MARK_AISLE_INSET;
      var lw = RenderConfig.LINE_W;
      var e = (mid + 0.5) * CELL - half + s * off;
      for (k in 0...len)
        {
          var col = (alongX ? base + k : mid);
          var row = (alongX ? mid : base + k);
          if (!freeFloor(m, col, row))
            continue;
          // and the line breaks where a DOOR opens onto the side it bounds — the gap is the opening,
          // and it is the figure that ties the room's lane to the corridor's. walked from the middle
          // outward on this line's own side, so a bench standing between the lane and the door means
          // the door does not open onto the lane and the line runs on
          if (reach(m, col, row, (alongX ? 0 : s), (alongX ? s : 0)).door)
            continue;
          var s0 = Math.max(a0, (base + k) * CELL - half);
          var s1 = Math.min(a1, (base + k + 1) * CELL - half);
          if (s1 <= s0)
            continue;
          if (alongX)
            mark(b, s0, s1, e - lw / 2, e + lw / 2, y);
          else
            mark(b, e - lw / 2, e + lw / 2, s0, s1, y);
          marks++;
        }
    }

// the pair bounding every corridor, read per CELL off the two runs through it: the SHORTER is the
// passage's cross-section and the longer is the direction it travels. that is FacilityLamps' own
// reading of a corridor cell, and it is what lets this pass need no run list — a corridor is in no
// list anywhere and its shape is not a rect.
//
// EACH EDGE IS EMITTED BY THE CELL THAT TOUCHES IT, which is the whole of how this pass tells a
// passage from a BRANCH without a run list. `reach` walks clear floor and cannot tell them apart, so
// the first build asked for the cross-section as a whole and rejected the cell when it came back too
// wide — and at a T that rejects BOTH lines, though the branch only opens off one of them. So the
// through lane broke on its far side too, over cols 14..16 and 19..21 and over the union 24..27 of
// two branches that are not even opposite each other.
//
// asking per EDGE answers all of it. `cells == 0` on one side means this cell is against that
// boundary, so the edge is struck there and nowhere else: a two-wide corridor has each of its two
// cells strike one line, a three-wide leaves its middle cell striking neither, and the far side of a
// branch mouth — where `cells` runs off down the branch — strikes nothing while the near side
// carries straight past. It also makes the old stray stub impossible by construction: an edge can
// only ever land on the boundary of the cell that emitted it, never four cells away, so
// MARK_LANE_MAX is gone with the bug it was guarding
  static function corridorAisle(b:MeshBuf, m:Facility, y:Float):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!freeFloor(m, col, row) ||
                m.surf[row][col] != Surf.LINO)
              continue;
            var xLo = reach(m, col, row, -1, 0);
            var xHi = reach(m, col, row, 1, 0);
            var zLo = reach(m, col, row, 0, -1);
            var zHi = reach(m, col, row, 0, 1);
            var alongX = (xLo.cells + xHi.cells >= zLo.cells + zHi.cells);
            var lo = (alongX ? zLo : xLo);
            var hi = (alongX ? zHi : xHi);
            // the lane the two edges would bound, measured the same from every cell of the section
            // so the guard answers the same everywhere in it
            var c = ((alongX ? row : col) + 0.5) * CELL - half;
            var e0 = c - CELL / 2 - lo.cells * CELL +
              (lo.furn ? FacilityStyle.MARK_FURN_CLEAR : FacilityStyle.MARK_WALL_CLEAR);
            var e1 = c + CELL / 2 + hi.cells * CELL -
              (hi.furn ? FacilityStyle.MARK_FURN_CLEAR : FacilityStyle.MARK_WALL_CLEAR);
            if (e1 - e0 < FacilityStyle.MARK_LANE_MIN)
              continue;
            if (lo.cells == 0 &&
                !lo.door)
              edge(b, m, col, row, alongX, -1, e0, y);
            if (hi.cells == 0 &&
                !hi.door)
              edge(b, m, col, row, alongX, 1, e1, y);
          }
    }

// one cell's worth of one corridor line, struck at `e` on the cross axis. `s` says which side of the
// cell it bounds, and that is what decides where its own boundary runs — which is the question both
// ends of it are trimmed by
  static function edge(b:MeshBuf, m:Facility, col:Int, row:Int, alongX:Bool, s:Int, e:Float,
      y:Float):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var lw = RenderConfig.LINE_W;
      var t = (alongX ? col : row);
      // the step along the way the passage travels, and the cell this line is struck against
      var dc = (alongX ? 1 : 0);
      var dr = (alongX ? 0 : 1);
      var bc = col + (alongX ? 0 : s);
      var br = row + (alongX ? s : 0);
      var t0 = t * CELL - half + trim(m, alongX, col - dc, row - dr, bc - dc, br - dr);
      var t1 = (t + 1) * CELL - half - trim(m, alongX, col + dc, row + dr, bc + dc, br + dr);
      if (t1 <= t0)
        return;
      if (alongX)
        mark(b, t0, t1, e - lw / 2, e + lw / 2, y);
      else
        mark(b, e - lw / 2, e + lw / 2, t0, t1, y);
      marks++;
    }

// how far one end of a corridor line comes IN from its cell boundary, given the next cell along the
// passage (nc,nr) and the cell this line is struck against beside THAT one (bc,br). four answers,
// because four things can be beyond the end:
//  - the passage carries on with its boundary       -> 0, and the next cell's segment abuts this one
//  - MASONRY ends it                                -> the inset, off the wall crease
//  - a DOORWAY ends it                              -> 0, the lane runs up to the threshold it serves
//  - the BOUNDARY ends and the floor does not       -> NEGATIVE. this is a junction mouth, and the
//    line runs on to meet the through lane's own line, which sits exactly MARK_WALL_CLEAR past the
//    cell boundary — so the two meet at the corner of the mouth instead of leaving the 1.7 units of
//    gap reported from the game
//
// AND THE CORNER IS A BUTT JOINT, NOT A CROSS. Run both lines to the same point and they overlap by
// a quarter of a line width, coplanar at PAINT_Y, which draws as doubled paint at every bend. So one
// of the two runs on to the FAR edge of the line it meets and the other starts at that far edge, a
// half width apart: no overlap, no gap. WHICH of the two extends is arbitrary and has only to be the
// same everywhere, or a compound's bends are made two different ways — the X-running line takes it
  static function trim(m:Facility, alongX:Bool, nc:Int, nr:Int, bc:Int, br:Int):Float
    {
      if (!freeFloor(m, nc, nr))
        return (FacilityModel.isDoor(m, nc, nr) ? 0 : FacilityStyle.MARK_AISLE_INSET);
      if (!freeFloor(m, bc, br))
        return 0;
      return -FacilityStyle.MARK_WALL_CLEAR +
        (alongX ? -RenderConfig.LINE_W / 2 : RenderConfig.LINE_W / 2);
    }

// how many clear floor cells you can step from (col,row) in one direction, and whether FURNITURE is
// what stopped the walk. the two travel together because they decide different clearances: casework
// and corner bins stand against a boundary, and nothing at all stands off the front of a bench.
//
// asking about FURNITURE and not about masonry is the whole of it, and the first build asked
// `isWall`. A doorway is not masonry, so beside every opening the answer flipped and the lane edge
// took the furniture clearance — 0.5 units toward the door, reported from the game. A door, a
// window, a wall and the edge of the grid all END the floor; only a bench or a fitting is a thing
// STANDING on floor that carries on underneath it
  static function reach(m:Facility, col:Int, row:Int, dc:Int, dr:Int):Reach
    {
      var n = 0;
      while (freeFloor(m, col + dc * (n + 1), row + dr * (n + 1)))
        n++;
      var c = col + dc * (n + 1);
      var r = row + dr * (n + 1);
      return {
        cells: n,
        furn: FacilityModel.isTable(m, c, r) ||
          FacilityModel.isFitting(m, c, r),
        door: FacilityModel.isDoor(m, c, r),
      };
    }

// is this an indoor floor cell with nothing standing on it — the only cell a marking is struck on.
//
// GRATE IS IN AND `m.drain` IS THE TEST, which is the model's own rule and the first build broke it:
// the generator lays a grate TILE in every chemistry lab and stands an objects.FloorDrain on it only
// about a third of the time, so *the surface says where a drain COULD be and the object says where
// one is*. FacilityGeom.floorBuf already routes GRATE to the ROOM floor buffer for exactly this
// reason — a drain is a fitting IN the floor, not a floor of its own — so a bare grate cell draws as
// ordinary tile and reads as ordinary tile, and skipping it left a hole in the line with nothing
// visible in it.
//
// the wall and doorway tests are not covered by the surface either: a door cell finalises to
// corridor lino and a wall cell keeps whatever surface it was laid over, so both are asked
// separately — the pair render.facility.FacilityExit.corridor makes for the same reason
  static inline function freeFloor(m:Facility, col:Int, row:Int):Bool
    {
      return FacilityModel.inside(m, col, row) &&
        (m.surf[row][col] == Surf.TILE ||
         m.surf[row][col] == Surf.GRATE ||
         m.surf[row][col] == Surf.LINO) &&
        !m.drain[row][col] &&
        !FacilityModel.isWall(m, col, row) &&
        !FacilityModel.isDoor(m, col, row) &&
        !FacilityModel.isTable(m, col, row) &&
        !FacilityModel.isFitting(m, col, row);
    }

// is this cell part of the parking ENTRY — the mouth cut through the pavement that the cars drive in
// by? it is the gateway, so nothing is struck on it and, as render.facility.FacilityLamps asks the
// same question, nothing stands in it either.
//
// the test is the cell's own distance to the ROAD, not the shape of the run it belongs to. the
// generator punches the entry as a plain 4x2 hole of asphalt through the pavement band beside the
// road (game.FacilityAreaGenerator lines 86-88), so every cell of it — and nothing else in the lot,
// which always has that whole band between it and the road — lies within the band's width of the
// kerb. the run-shaped test this replaces read the entry as "a run that begins off the road", which
// is what the mouth looks like only when it is cut in a pavement running ACROSS the lot: where the
// hole is cut in the road's own sidewalk the run it starts is one cell long and turns the corner,
// and a lamp went up in the middle of the gateway
  public static function isEntry(m:Facility, col:Int, row:Int):Bool
    {
      if (!isSurf(m, col, row, Surf.LOT))
        return false;
      for (dir in 0...4)
        for (i in 1...SIDEWALK_W + 1)
          if (isSurf(m, col + DC[dir] * i, row + DR[dir] * i, Surf.ROAD))
            return true;
      return false;
    }

// the coordinate along the kerb where this cell's bay run BEGINS — walk back while the cells keep
// their pavement on the same side. the rhythm counts from here so that every run opens on a whole
// bay, and the two runs meeting at a corner square it off between them. public because
// render.facility.FacilityLamps reads the same phase to keep a mast out of the paint
  public static function runStart(m:Facility, col:Int, row:Int, dir:Int):Int
    {
      var dc = (dir < 2 ? -1 : 0);
      var dr = (dir < 2 ? 0 : -1);
      while (isSurf(m, col + dc, row + dr, Surf.LOT) &&
             isSurf(m, col + dc + DC[dir], row + dr + DR[dir], Surf.WALKWAY))
        {
          col += dc;
          row += dr;
        }
      return (dir < 2 ? col : row);
    }

// does this cell hold that ground surface? false off the grid
  static inline function isSurf(m:Facility, col:Int, row:Int, s:Surf):Bool
    return FacilityModel.inside(m, col, row) && m.surf[row][col] == s;

// one painted rect, its uv world-aligned on both axes so the wear samples at one scale everywhere
  static inline function mark(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, y:Float):Void
    {
      var t = RenderConfig.PAINT_TILE;
      MeshBufTools.quad(b, [x0, y, z1], [x1, y, z1], [x1, y, z0], [x0, y, z0],
        [x0 / t, z1 / t, x1 / t, z1 / t, x1 / t, z0 / t, x0 / t, z0 / t]);
    }

// merge one paint buffer into a lit mesh, the same pair of shadow flags every outdoor surface takes.
// `tint` multiplies the shared worn-paint map, which is what makes an aisle yellow and a bay white
// off one texture: `color` is a Lambert UNIFORM and not a program key, so the second mesh compiles
// nothing of its own
  static function add(scene:Scene, b:MeshBuf, tint:Int):Void
    {
      if (b.idx.length == 0)
        return;
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(b.pos, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(b.uv, 2));
      geo.setIndex(b.idx);
      geo.computeVertexNormals();
      var mesh = new Mesh(geo, VisionMask.patch(new MeshLambertMaterial({
        map: Textures.loadTexture(FacilityStyle.GROUND_PAINT, 'ground', 1),
        color: tint,
        side: THREE.FrontSide,
      })));
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }
}
