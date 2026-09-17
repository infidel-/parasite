package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.facility.FacilityModel.Wall;
import render.world.ContactMask;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;
import render.world.WorldCtx.WallMount;

// what one structure's roof fades. ONLY the roof: the walls used to fade with it, and a wall face
// was picked for that by its NORMAL, which cannot answer the question it was being asked. see the
// header of render.facility.FacilityArea.ease
typedef Shell = {
  roof:Array<Mesh>,
  // the shared uniform this structure's window panes dim on, 0 lit from the lot .. 1 seen from
  // inside — one object handed to both run lengths' materials, so FacilityArea writes ONE float per
  // structure per frame and touches no material property at all. the panes are not in `roof` and
  // must not be: a roof fades to nothing and glass only changes what it is
  glaze:Dynamic,
  // what the parapet ring emitted on this structure, for __facility().roof. a hangar's are both 0
  // by construction — its roofline is a later job and `parapet` is not called on one at all
  paraCells:Int,
  paraQuads:Int,
};

// an axis-aligned footprint in world units, used for both a wall cell's slab and its roof band
typedef Rect = {
  x0:Float,
  x1:Float,
  z0:Float,
  z1:Float,
};

// one floor strip a slab leaves uncovered inside its own cell, plus the cell whose surface it
// continues. half-thickness walls do not fill their cell, so the remainder is floor — and it is the
// NEIGHBOUR's floor, because the strip is the last unit of the room (or of the car park) and not a
// surface of its own
typedef Strip = {
  x0:Float,
  x1:Float,
  z0:Float,
  z1:Float,
  col:Int,
  row:Int,
};

// one corner square inside a wall cell's bounding slab that its RUNS do not fill. a Strip with the
// two directions the wall line carries into, because the same square is three things at once: the
// diagonal room's floor, its ceiling, and two standing faces of masonry looking back at it
typedef Notch = {
  > Strip,
  dx:Int,   // 2 = west, 3 = east: the horizontal run's direction, and the way one face looks
  dz:Int,   // 0 = north, 1 = south: the vertical run's, and the way the other looks
};

// the static shell of every facility structure: indoor floors, walls, window openings and the roof,
// built from the saved cell grid. one merged mesh per (structure, surface) — a structure is the unit
// because the roof fade is per building, so a mesh may never span two of them.
//
// nothing here is a citygen Building, so render.Occlusion never runs on a facility: the shell fades
// on the player being INSIDE it rather than on blocking a sightline, which is a different question
// with a different answer (see FacilityArea.reveal)
class FacilityGeom
{
  static inline var CELL = CityConfig.CELL;

  // how many floor buffers `structure` allocates: one slot per Surf value, so a surface indexes its
  // own buffer and most of them come back empty and emit no mesh at all
  static inline var FLOOR_SURFS = 11;

  // cell offsets of the neighbour each wall face looks at. 0 = north (-z), 1 = south (+z),
  // 2 = west (-x), 3 = east (+x) — the same order render.sewer.SewerGeom winds, and the order
  // `ends` winds a face against. PUBLIC so a second pass over the same faces cannot get its own copy
  // slightly wrong: render.world.Geom numbers its four directions differently, and a decal emitted
  // on dir 2 when the emitter meant dir 3 lands inside the masonry with nothing to see
  public static var DC = [0, 0, -1, 1];
  public static var DR = [-1, 1, 0, 0];

// how tall a window run of this many cells stands, world units. NOTHING is ever stretched, so the
// height is the run's width over the ASPECT OF THE ART IT DRAWS — and there is one art per run
// length, so the two lengths are two different numbers rather than one aspect and a fraction.
//
// they come out very nearly the same height (2-cell 4.08, 3-cell 4.14) where before the shorter one
// was 2.76, a third of a storey lower than its neighbour on the same facade. that is the correct
// answer and not a coincidence: a pane is a pane, so a shorter opening is fewer of them and not
// smaller ones. read by BOTH passes over m.windows — the one that records the hole for the wall
// emitter to leave, and the one that fills it — which is why it is a function and not a line in either
  public static inline function paneTall(len:Int):Float
    return len * CELL /
      (len == 2 ? FacilityStyle.WINDOW_ASPECT_2 : FacilityStyle.WINDOW_ASPECT);

// build every structure's shell, and hand back what fades
  public static function build(scene:Scene, m:Facility):Array<Shell>
    {
      // the vertical band a window opening occupies on its own run's cells, so the wall emitter can
      // leave a hole rather than paint over the pane. keyed per cell because a face is emitted per
      // cell while a pane is emitted per RUN
      var sill = [for (_ in 0...m.h) [for (_ in 0...m.w) -1.0]];
      var head = [for (_ in 0...m.h) [for (_ in 0...m.w) -1.0]];
      var doorAt = [for (_ in 0...m.h) [for (_ in 0...m.w) -1]];
      for (i in 0...m.doors.length)
        doorAt[m.doors[i].row][m.doors[i].col] = i;
      for (w in m.windows)
        {
          // a LIGHT WELL is not sized off its art the way a ribbon is: it is one cell, one image maps
          // 0..1 across it, and where it sits in the wall is the whole design (see WINDOW_HIGH_SILL)
          var tall = (w.high ? FacilityStyle.WINDOW_HIGH_H : paneTall(w.len));
          var lo = (w.high ? FacilityStyle.WINDOW_HIGH_SILL :
            (FacilityStyle.WALL_H - tall) / 2);
          if (lo < 0)
            lo = 0;
          var hi = lo + tall;
          if (hi > FacilityStyle.WALL_H)
            hi = FacilityStyle.WALL_H;
          for (i in 0...w.len)
            {
              var c = w.col + (w.alongX ? i : 0);
              var r = w.row + (w.alongX ? 0 : i);
              sill[r][c] = lo;
              head[r][c] = hi;
            }
        }

      var g:FacilityShellOpts = {
        sill: sill,
        head: head,
        doorAt: doorAt,
        hood: MeshBufTools.make(),
      };
      var out = [];
      for (si in 0...m.structures.length)
        out.push(structure(scene, m, si, g));
      // and the bulkhead hoods, merged across every structure at once — see the field's own comment.
      // it does NOT cast, which is the one place it departs from the cladding it used to ride: a
      // shadow-map draw is a real draw call, and MEASURED in a pinned frame at the hangar's side
      // door, hiding the mesh took `calls` 68 -> 66 with castShadow on and 68 -> 67 with it off,
      // for two screenshots that cannot be told apart. nothing here is between a caster and a
      // surface — the compound's only spotlights that cast hang BELOW the hood's own top and aim
      // straight down. the buffer is empty in a compound with no exterior door and `add` emits no
      // mesh then
      add(scene, g.hood, FacilityStyle.DOOR_LAMP_TEX, true, false);
      return out;
    }

// does the wall LINE carry on through this cell?
//
// a wall does, and so does a DOOR cell. that second half is not a nicety: a doorway is a hole IN
// the line, not the end of it, and reading it as an end pulls both flanking slabs back by the
// inset and opens a 4-unit opening out to 6
  public static inline function carries(m:Facility, col:Int, row:Int):Bool
    {
      return FacilityModel.isWall(m, col, row) || FacilityModel.isDoor(m, col, row);
    }

// how thick a cell's masonry is: HALF a cell for solid wall and a QUARTER for glazing
  public static inline function thick(m:Facility, col:Int, row:Int):Float
    {
      return FacilityModel.inside(m, col, row) && m.wall[row][col] == Wall.WINDOW ?
        FacilityStyle.GLASS_T : FacilityStyle.WALL_T;
    }

// how far from a wall cell's CENTRE this compound draws that cell's face, or -1 where the cell is
// not masonry at all. render.world.WorldCtx.wallFace's own contract, and the whole of what a decal
// standing on a wall needs from the facility: a splat or a bullet hole is placed from the cell the
// drop or the shot DIED in, and a cell turns solid at its BOUNDARY — two units out — while `thick`
// says the slab reaches half that. Reported from the game as blood hanging in the air off an inner
// wall, and it was 1.12 units of it
  public static function wallFace(m:Facility, col:Int, row:Int, dir:Int):Float
    {
      if (FacilityModel.isWall(m, col, row))
        return thick(m, col, row) / 2;
      // AND THE WASHROOM DIVIDER, which is the one FITTING in the compound that is a wall rather
      // than a thing standing against one — and the one that is not square in its cell: it spans the
      // whole of it along its own run and stands PART_T 0.6 across, so a splat on its flank hung
      // 1.82 units off it, worse than the masonry. Its box is the one FacilityDeco already derives
      // for the emitter, so the two cannot disagree
      var kind = (FacilityModel.inside(m, col, row) ? m.deco[row][col] - 1 : -1);
      if (kind != _FittingKind.FIT_PARTITION)
        return -1.0;
      var r = FacilityDeco.rectOf(m, col, row, kind);
      var c = CityConfig.cellToWorld(col, row);
      return switch (dir)
        {
          case 0: r.z1 - c.z;
          case 1: c.z - r.z0;
          case 2: r.x1 - c.x;
          default: c.x - r.x0;
        }
    }

// where an object standing on a wall cell hangs: one pose per face the wall line does NOT carry
// into, which for a straight run is its two sides. null for every other cell, so the actor layer
// pays one grid lookup per object and allocates nothing in the common case.
//
// this exists because the generator writes a VENT as a TILE_BUILDING cell and stands an objects.Vent
// on it. Drawn like any other object the grille lay FLAT on the floor inside two units of masonry,
// where nothing but its through-wall mark could ever be seen — reported from the game as a dotted
// mark on the ground that ought to be on the wall
  public static function wallMounts(m:Facility, col:Int, row:Int):Array<WallMount>
    {
      if (!FacilityModel.isWall(m, col, row))
        return null;
      var c = CityConfig.cellToWorld(col, row);
      var out = thick(m, col, row) / 2 + FacilityStyle.MOUNT_PROUD;
      var mounts = [];
      for (dir in 0...4)
        {
          if (carries(m, col + DC[dir], row + DR[dir]))
            continue;
          // the face's outward normal IS (DC,DR) read as (x,z), so its yaw is that vector's angle —
          // no dir-to-rotation table, and none of render.world.Geom's opposite dir numbering to cross
          mounts.push({
            x: c.x + DC[dir] * out,
            y: FacilityStyle.MOUNT_Y,
            z: c.z + DR[dir] * out,
            rotY: Math.atan2(DC[dir], DR[dir]),
            scale: FacilityStyle.MOUNT_SCALE,
          });
        }
      return mounts;
    }

// the BOUNDING BOX of a wall cell's masonry, in world units — reaching the cell boundary only on the
// sides where the wall line carries on, and inset by half the leftover elsewhere. two things fall
// out of that one rule and neither needs a case of its own:
//   - a straight run comes out 2 units thick, so a doorway is a 2-unit reveal and not a 4-unit tunnel
//   - a window slab sits strictly INSIDE its neighbour's cross-section, so the neighbour's own butt
//     cap is the jamb reveal and the hole that used to be there closes for free
// also correct for a DOOR cell, which is not a wall: its wall-line neighbours carry, so it comes
// back as exactly the lintel planes.
//
// it is the BOX and not the masonry. where the line turns or branches, the runs through the cell
// form an L, a T or a cross and the box is strictly bigger than their union — see notches()
  public static function slab(m:Facility, col:Int, row:Int):Rect
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var e = (CELL - thick(m, col, row)) / 2;
      var x0 = col * CELL - half;
      var z0 = row * CELL - half;
      return {
        x0: x0 + (carries(m, col - 1, row) ? 0.0 : e),
        x1: x0 + CELL - (carries(m, col + 1, row) ? 0.0 : e),
        z0: z0 + (carries(m, col, row - 1) ? 0.0 : e),
        z1: z0 + CELL - (carries(m, col, row + 1) ? 0.0 : e),
      };
    }

// the corner squares a cell's slab box holds that its masonry does not: one per PAIR of adjacent
// directions the wall line carries into.
//
// a wall cell is the union of the RUNS through it and never their bounding box. a corner is an L of
// two 2-thick runs and the box is a 3x3 pier — the extra 1x1 sits in the angle between them, poking
// into the room past both wall lines, which is the full-cell wall this phase exists to have removed.
// a T leaves two of these and a crossing four, so it is not a corner case in either sense.
//
// the square belongs to the DIAGONAL cell: it is the last unit of that room's corner, and it takes
// that room's floor, its fading ceiling and its paint, exactly as strips() hands a run's leftover to
// the neighbour beside it
  public static function notches(m:Facility, col:Int, row:Int):Array<Notch>
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var e = (CELL - thick(m, col, row)) / 2;
      var x0 = col * CELL - half;
      var z0 = row * CELL - half;
      var out = [];
      for (dz in 0...2)
        for (k in 0...2)
          {
            var dx = 2 + k;
            if (!carries(m, col + DC[dz], row + DR[dz]) ||
                !carries(m, col + DC[dx], row + DR[dx]))
              continue;
            var nx = (dx == 2 ? x0 : x0 + CELL - e);
            var nz = (dz == 0 ? z0 : z0 + CELL - e);
            out.push({
              x0: nx,
              x1: nx + e,
              z0: nz,
              z1: nz + e,
              dx: dx,
              dz: dz,
              col: col + DC[dx],
              row: row + DR[dz],
            });
          }
      return out;
    }

// the floor strips a cell's slab leaves uncovered — the cell rect minus the slab rect, decomposed
// so nothing overlaps: north and south span the full cell width and own the corners, west and east
// take what is left. a side whose wall line carries on is degenerate and never appears
  public static function strips(m:Facility, col:Int, row:Int):Array<Strip>
    {
      return stripsOf(m, col, row, slab(m, col, row));
    }

// and the same decomposition the FLOOR takes, which differs at exactly one kind of cell: a DOORWAY.
//
// a door cell's slab is its LINTEL — masonry above head height with nothing under it — so the floor
// there is not the door cell's own surface but the two spaces the opening joins, meeting at the wall
// line. an exterior door had 2 units of corridor lino laid out past the building line; it takes
// pavement now, off the same neighbour rule every other strip uses. collapsing the slab to the wall
// line and re-running the same decomposition IS the two halves, so there is no second rule
  public static function floorStrips(m:Facility, col:Int, row:Int):Array<Strip>
    {
      if (!FacilityModel.isDoor(m, col, row))
        return strips(m, col, row);
      var half = (CityConfig.GRID * CELL) / 2;
      var s = slab(m, col, row);
      var c = (carries(m, col - 1, row) ? row : col) * CELL - half + CELL / 2;
      return stripsOf(m, col, row, carries(m, col - 1, row) ?
        {
          x0: s.x0,
          x1: s.x1,
          z0: c,
          z1: c,
        } :
        {
          x0: c,
          x1: c,
          z0: s.z0,
          z1: s.z1,
        });
    }

// the cell rect minus `s`, in up to four rects plus the corner squares
  static function stripsOf(m:Facility, col:Int, row:Int, s:Rect):Array<Strip>
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var x0 = col * CELL - half, x1 = x0 + CELL;
      var z0 = row * CELL - half, z1 = z0 + CELL;
      var out = [];
      function add(ax0:Float, ax1:Float, az0:Float, az1:Float, nc:Int, nr:Int):Void
        {
          if (ax1 - ax0 < 0.01 ||
              az1 - az0 < 0.01 ||
              !FacilityModel.inside(m, nc, nr) ||
              m.surf[nr][nc] == Surf.NONE)
            return;
          out.push({
            x0: ax0,
            x1: ax1,
            z0: az0,
            z1: az1,
            col: nc,
            row: nr,
          });
        }
      add(x0, x1, z0, s.z0, col, row - 1);
      add(x0, x1, s.z1, z1, col, row + 1);
      add(x0, s.x0, s.z0, s.z1, col - 1, row);
      add(s.x1, x1, s.z0, s.z1, col + 1, row);
      // and the corner squares INSIDE the box, where the wall line turns or branches
      for (n in notches(m, col, row))
        add(n.x0, n.x1, n.z0, n.z1, n.col, n.row);
      return out;
    }

// the cell a butt cap looks into.
//
// it is DIAGONAL from the cap's own cell: one step along the wall line into the neighbour it butts
// against, then one step off the line toward the side the excess sits on. reading the neighbour
// itself instead gets a window jamb right and a corner pier wrong, because a corner's shoulder looks
// past the run it meets and into the room behind it
  static inline function diagCol(col:Int, dir:Int, side:Int):Int
    {
      return col + DC[dir] + (dir < 2 ? side : 0);
    }

  static inline function diagRow(row:Int, dir:Int, side:Int):Int
    {
      return row + DR[dir] + (dir < 2 ? 0 : side);
    }

// one structure: its floors, its walls, its window panes, its door lintels and its roof
  static function structure(scene:Scene, m:Facility, si:Int, g:FacilityShellOpts):Shell
    {
      var st = m.structures[si];
      var half = (CityConfig.GRID * CELL) / 2;
      // does this structure's interior get a FLAT ceiling at ROOF_Y? a lab building does; a hangar's
      // is the barrel vault render.facility.FacilityRoof.vault arches over it, and the flat deck
      // under one would be dead geometry in a transparent buffer — hidden from outside by the vault
      // and faded off with it from inside, paying overdraw in the sorted pass for neither. the RIM
      // is unaffected: it caps the wall head, and the vault springs from the outer plane above it
      var flatDeck = !st.hangar;
      // floors, one buffer per surface. a hangar rolls no lab tile and a lab building no concrete,
      // so most of these come back empty and emit no mesh at all
      //
      // INDEXED BY Surf and not five named locals: the list grew with the room templates, and every
      // call site passing the whole set positionally is the arg list this file does not want
      var floors = [for (_ in 0...FLOOR_SURFS) MeshBufTools.make()];
      // walls. NOT split by facing any more — see the Shell header. the two INTERIOR buffers are
      // split by the SPACE a face looks into instead: a corridor is painted board and a lab room is
      // tiled, and they are 218 faces against 538 in a generated area, so the corridor is a real
      // third of what the player sees indoors rather than a detail
      var wOut = MeshBufTools.make();
      var wRoom = MeshBufTools.make();
      var wCorr = MeshBufTools.make();
      // and one more pair for the two ROOM TEMPLATES: an office is painted and a washroom is glazed
      // tile floor to ceiling, and neither is the laboratory's finish
      var wOffice = MeshBufTools.make();
      var wWash = MeshBufTools.make();
      // the hangar's roll-up shutter strips. their own buffer because they take their own texture:
      // painted in plain cladding they were a door you could not see
      var shut = MeshBufTools.make();
      // the roof, split by whether it is over floor (fades) or over the wall ring (never does). the
      // rim is what keeps the building's outline on screen once you are inside it
      var roof = MeshBufTools.make();
      var rim = MeshBufTools.make();
      // and the parapet's coping cap, which is the ONE piece of it that needs a buffer of its own:
      // the cladding merges into wOut for free, but a coping in the wall's own art is invisible and
      // the whole point of it is the line it draws along the roofline (see FacilityStyle.COPING)
      var cope = MeshBufTools.make();
      // window panes, and the aluminium capping that tops a run and closes its reveal. TWO pane
      // buffers, one per run length, because each length draws its OWN art (see `addPane`)
      var panes = MeshBufTools.make();
      var panes2 = MeshBufTools.make();
      var panesHigh = MeshBufTools.make();
      var head = MeshBufTools.make();
      // which wall buffer a face looking into (c,r) belongs in. the hangar wears its cladding on
      // both sides, so it never reaches the interior pair; a corridor is Surf.LINO, the surface the
      // generator floors every corridor and every door cell with, so the split needs no
      // generatorInfo and works on a saved grid
      function look(c:Int, r:Int):MeshBuf
        {
          if (st.hangar || !FacilityModel.isIndoor(m, c, r))
            return wOut;
          return switch (m.surf[r][c])
            {
              case Surf.LINO: wCorr;
              case Surf.OFFICE: wOffice;
              case Surf.WASH: wWash;
              case _: wRoom;
            }
        }

      for (row in st.oy1...st.oy2 + 1)
        for (col in st.ox1...st.ox2 + 1)
          {
            if (!FacilityModel.inside(m, col, row) ||
                m.owner[row][col] != si)
              continue;
            var x0 = col * CELL - half, x1 = x0 + CELL;
            var z0 = row * CELL - half, z1 = z0 + CELL;
            var di = g.doorAt[row][col];
            // a wall and a doorway both fill only PART of their cell, and what the slab leaves is
            // the neighbour's cell reaching into this one: it takes the neighbour's floor, and the
            // neighbour's ceiling with it. the ceiling has to be the FADING roof and not the rim, or
            // the ledge rimRect's header measures comes straight back in a second place. the outdoor
            // half of the same strips is emitted by render.facility.FacilityGround, which is where
            // the ground buffers live
            if (carries(m, col, row))
              {
                // the CEILING follows the masonry and the FLOOR does not, and they part company at a
                // doorway: the lintel's own top is the rim, so the fading roof takes only what the
                // slab leaves, while under it there is no masonry at all and the floor runs right
                // through (see floorStrips). identical at every other cell
                for (sp in strips(m, col, row))
                  if (flatDeck &&
                      FacilityModel.isIndoor(m, sp.col, sp.row))
                    cap(roof, sp.x0, sp.x1, sp.z0, sp.z1, FacilityStyle.ROOF_Y,
                      FacilityStyle.ROOF_TILE);
                for (sp in floorStrips(m, col, row))
                  if (FacilityModel.isIndoor(m, sp.col, sp.row))
                    cap(floorBuf(m, sp.col, sp.row, floors),
                      sp.x0, sp.x1, sp.z0, sp.z1, 0.0, FacilityStyle.FLOOR_TILE_SZ);
                // a corner square is floor and ceiling like any other strip — the loop above has
                // just laid both — and the two runs it sits in the angle of stand at its edges. one
                // face each, looking the way that run's line carries, into the room the square is a
                // corner of
                for (n in notches(m, col, row))
                  {
                    var b = look(n.col, n.row);
                    butt(b, false, n.dx == 3 ? n.x0 : n.x1, n.z0, n.z1, n.dx);
                    butt(b, true, n.dz == 1 ? n.z0 : n.z1, n.x0, n.x1, n.dz);
                  }
              }
            if (FacilityModel.isWall(m, col, row))
              {
                var s = slab(m, col, row);
                var e = (CELL - thick(m, col, row)) / 2;
                var glazed = (m.wall[row][col] == Wall.WINDOW);
                var shutter = (m.wall[row][col] == Wall.SHUTTER);
                capTop(rim, head, m, col, row, glazed);
                // and over glazing a SECOND band, the deck's own art in the FADING buffer, directly
                // over the capping the line above just sank. the capping is right only once the roof
                // has gone: from outside the coping covers just 0.22 of the 1.0-wide band and the
                // rest reads as a strip of aluminium lying in the bitumen, at ~110 glazed cells an
                // area. one quad each, merged into a mesh that already exists, so no draw call — and
                // FacilityArea.apply drops the deck to visible false at full reveal, so nothing
                // z-fights and nothing has to be told about the swap
                if (glazed)
                  capTop(roof, head, m, col, row, false);
                for (dir in 0...4)
                  {
                    var nc = col + DC[dir];
                    var nr = row + DR[dir];
                    if (carries(m, nc, nr))
                      {
                        // the line carries on, so the two runs meet in the cell boundary plane and
                        // the only thing that can be exposed there is a difference in THICKNESS:
                        // glazing sits strictly inside the solid wall that bounds its run, and the
                        // wall's excess either side is the SHOULDER on each face of it.
                        //
                        // AND THE SHOULDERS ARE NOT THE JAMB, which this note used to call them and
                        // which cost a hole in every window run: they are the two strips OUTSIDE the
                        // glazing band, and the jamb is the band itself over the opening's height.
                        // `jamb`, from the window pass, is what closes that.
                        //
                        // the slabs' own extents used to be compared instead, and that answered a
                        // different question: at a corner the box reaches the boundary on the side
                        // the OTHER run leaves through, so the difference read as an exposed end and
                        // capped a shoulder that notches() has now taken away
                        var en = (CELL - thick(m, nc, nr)) / 2;
                        if (en < e + 0.005)
                          continue;
                        var flat = (dir < 2);
                        var pl = flat ? (dir == 0 ? s.z0 : s.z1) : (dir == 2 ? s.x0 : s.x1);
                        var p0 = (flat ? col : row) * CELL - half;
                        butt(look(diagCol(col, dir, -1), diagRow(row, dir, -1)),
                          flat, pl, p0 + e, p0 + en, dir);
                        butt(look(diagCol(col, dir, 1), diagRow(row, dir, 1)),
                          flat, pl, p0 + CELL - en, p0 + CELL - e, dir);
                        continue;
                      }
                    // the shutter is chosen off THIS cell rather than off the neighbour, unlike
                    // `look` beside it: a roll-up door reads as a door from both sides
                    var b = shutter ? shut : look(nc, nr);
                    var t = shutter ? FacilityStyle.SHUTTER_TILE : FacilityStyle.WALL_TILE;
                    if (g.sill[row][col] < 0)
                      {
                        face(b, s.x0, s.x1, s.z0, s.z1, dir,
                          FacilityStyle.WALL_BASE, FacilityStyle.WALL_H, t);
                        continue;
                      }
                    // a window run: leave the opening and carry the wall above and below it
                    face(b, s.x0, s.x1, s.z0, s.z1, dir,
                      FacilityStyle.WALL_BASE, g.sill[row][col], t);
                    face(b, s.x0, s.x1, s.z0, s.z1, dir, g.head[row][col], FacilityStyle.WALL_H, t);
                  }
                continue;
              }
            // a door cell carries FLOOR and no wall — the generator finalises one to plain corridor
            // lino — so without this the building has a hole in it at every doorway. the head closes
            // BOTH faces of the reveal, and the reveal is now WALL_T deep rather than a whole cell
            if (di >= 0)
              {
                var s = slab(m, col, row);
                // above DOOR_H the opening is masonry like any other wall, so its roof belongs to
                // the RIM. left in the fading roof with the rest of the cell — which is where it was
                // — all 30 doorways took their piece of the wall-top ring away with the ceiling, and
                // the building read as a ring with a notch cut out of it at every door. the full
                // cell was wrong in the other direction too: at the 7 exterior doors it hung 28
                // square units of roof, and the same again of corridor lino, out over the pavement
                capTop(rim, head, m, col, row, false);
                // the reveal — soffit and both jambs — is painted as CORRIDOR whichever way the
                // opening faces. it used to take whichever of the two flanking spaces the loop below
                // happened to read first, so an interior door was painted in the room's tile half
                // the time and an exterior one in the outside cladding. a doorway is a piece of the
                // circulation and not of either space it joins, which is the same reason the
                // generator floors every door cell in corridor lino
                var soffit = (st.hangar ? wOut : wCorr);
                for (k in 0...2)
                  {
                    var dir = (m.doors[di].alongX ? k : 2 + k);
                    face(look(col + DC[dir], row + DR[dir]), s.x0, s.x1, s.z0, s.z1, dir,
                      FacilityStyle.DOOR_H, FacilityStyle.WALL_H, FacilityStyle.WALL_TILE);
                  }
                // and the head from UNDERNEATH. the two faces above sit on the slab's own planes
                // while the leaves hang between them, so without this the reveal over a door is open
                // to the sky. verified before adding, by putting the free cam on the floor and
                // looking up: a black void over every doorway. the game camera pitches DOWN 51
                // degrees and never sees it, which is exactly why it would have shipped
                capDown(soffit, s.x0, s.x1, s.z0, s.z1, FacilityStyle.DOOR_H, FacilityStyle.WALL_TILE);
                // and the two JAMBS, the opening's side reveals, floor to lintel.
                //
                // NOTHING else emits these. the flanking wall cell sees `carries` on this cell and
                // takes the butt-cap branch, where the two cross-sections are identical — which is
                // true of the MASONRY and false of the hole underneath it, so the reveal came out
                // as two open slots you could see straight through. each jamb sits in a cell
                // boundary plane looking INTO the cell, i.e. wound the opposite way from a wall
                // face at the same place, which is what makes it `face` with one axis collapsed
                jamb(soffit, m.doors[di].alongX, s, FacilityStyle.WALL_BASE, FacilityStyle.DOOR_H,
                  FacilityStyle.WALL_TILE);
                // and the threshold under them, for the surface the doorway opens onto being lower
                // than the floor it leads to — see `threshold`
                threshold(soffit, m.doors[di].alongX, s);
                // and the bulkhead lamp's hood, over an EXTERIOR doorway only. it rode wOut for a
                // build — the exterior cladding's own buffer, for no draw call at all, the way the
                // parapet ring and the gable crescents do — and a fitting painted in the wall's own
                // art is not a fitting, it is a lump of wall. it takes its own now, in the ONE
                // buffer `build` merges for the whole compound
                doorLamp(g.hood, m, m.doors[di]);
                continue;
              }
            if (flatDeck)
              cap(roof, x0, x1, z0, z1, FacilityStyle.ROOF_Y, FacilityStyle.ROOF_TILE);
            cap(floorBuf(m, col, row, floors),
              x0, x1, z0, z1, 0.0, FacilityStyle.FLOOR_TILE_SZ);
          }

      // one pane per RUN and not per cell, so the art's three panes span the whole opening exactly
      // once. both faces get one: a window read only from outside would vanish the moment the roof
      // faded and the player was standing next to it
      for (w in m.windows)
        {
          if (w.structure != si)
            continue;
          var wide = w.len * CELL;
          var tall = (w.high ? FacilityStyle.WINDOW_HIGH_H : paneTall(w.len));
          var lo = (w.high ? FacilityStyle.WINDOW_HIGH_SILL :
            (FacilityStyle.WALL_H - tall) / 2);
          if (lo < 0)
            lo = 0;
          // the run's own footprint: full length along its axis and the GLAZING slab's one unit
          // across it. the first cell's slab already reaches the cell boundary on the run axis
          // (its neighbour there is the wall that bounds the run), so the length is just `wide`
          var s = slab(m, w.col, w.row);
          var x0 = s.x0;
          var z0 = s.z0;
          var x1 = w.alongX ? x0 + wide : s.x1;
          var z1 = w.alongX ? s.z1 : z0 + wide;
          // the exterior face is the one AWAY from the interior, and the interior face its opposite
          var outDir = w.alongX ? (w.inDir > 0 ? 0 : 1) : (w.inDir > 0 ? 2 : 3);
          var inFace = w.alongX ? (w.inDir > 0 ? 1 : 0) : (w.inDir > 0 ? 3 : 2);
          // the run goes in the buffer for its OWN length, because that is what picks the art it
          // draws — see `addPane` and FacilityStyle.WINDOW_LIT_2.
          //
          // and the pane is drawn a hair BIGGER than the opening it fills (WINDOW_OVERLAP), grown
          // along the RUN's own axis and in height, so alphaTest eating the art's outermost texel row
          // cannot open a slit. the head and sill caps below keep the opening's true size, so only
          // the glass grows and the extra is buried in the masonry.
          //
          // ACROSS the run it SHRINKS instead, by WINDOW_INSET, and that is the glass being set into
          // its opening rather than glazed onto the face of it. The masonry above and below is
          // emitted on THIS cell's slab, i.e. the glazing plane, so a pane flush with that plane is
          // coplanar with the spandrel it meets — z-fighting at best and, as reported from the game,
          // a window that reads as painted ON the wall instead of in it. Narrowing the rect pulls
          // BOTH faces off the plane at once, each toward the slab's centre, so each ends up inside
          // its own side and the head and sill caps below — which keep the opening's TRUE size —
          // stand proud of the glass as the reveal
          var pb = (w.high ? panesHigh : (w.len == 2 ? panes2 : panes));
          var gr = wide * FacilityStyle.WINDOW_OVERLAP / 2;
          var gy = tall * FacilityStyle.WINDOW_OVERLAP / 2;
          var ge = FacilityStyle.WINDOW_INSET;
          var px0 = w.alongX ? x0 - gr : x0 + ge;
          var px1 = w.alongX ? x1 + gr : x1 - ge;
          var pz0 = w.alongX ? z0 + ge : z0 - gr;
          var pz1 = w.alongX ? z1 - ge : z1 + gr;
          pane(pb, px0, px1, pz0, pz1, outDir, lo - gy, lo + tall + gy);
          pane(pb, px0, px1, pz0, pz1, inFace, lo - gy, lo + tall + gy);
          // THE REVEAL IS FOUR QUADS AND IT USED TO BE TWO. A hole cut in a wall has a soffit, a
          // sill and two jambs, and the note that used to stand here claimed the flanking wall cells
          // closed the jambs "by being thicker than it". They do not, and the arithmetic says so:
          // `butt` caps the boundary plane only where the thick cell's cross-section stands PROUD of
          // the thin one, i.e. the two 0.5 shoulder strips at (WALL_T - GLASS_T) / 2 either side of
          // the glazing band. The band BETWEEN them is the glazing's own 1.0, and over the opening's
          // height there is no masonry in it at all — so it was open, and a grazing view along the
          // facade looked straight through the wall into the lit room. Reported from the game as a
          // vertical hole at each end of every window run, and MEASURED on the run at col 20 row 3:
          // the reveal volume held exactly four triangles of `window-head` (the soffit at y 5.04 and
          // the sill at 0.96) plus the two panes, and nothing whatever in either end plane.
          //
          // `jamb` was already here and already correct — it was gated to LIGHT WELLS, on the same
          // wrong belief. A ribbon needs it for exactly the same reason a well does.
          capDown(head, x0, x1, z0, z1, lo + tall, FacilityStyle.HEAD_TILE);
          if (lo >= 0.05)
            cap(head, x0, x1, z0, z1, lo, FacilityStyle.HEAD_TILE);
          // both ends unconditionally, and the two things that makes safe are invariants and not
          // luck: FacilityModel.findWindows runs a run to the END of its contiguous window strip, so
          // two runs can never abut and the cell past each end is never glazing — and it is solid
          // masonry rather than a doorway, measured over all 42 runs of a compound, whose 84 end
          // cells came back Const.TILE_BUILDING with no object on any of them
          jamb(head, w.alongX, { x0: x0, x1: x1, z0: z0, z1: z1 }, lo, lo + tall,
            FacilityStyle.HEAD_TILE);
        }

      // the parapet ring, once the wall ring it stands on is complete — and the hangar's opposite
      // number, which is the pair of gable crescents its barrel vault springs off. a parapet and a
      // gable are the same object here: the exterior cladding carrying on ABOVE the wall head, in
      // this same buffer, in this same course, staying put when the lid over the player's head
      // fades. only the shape differs, a band round a box against a segment under an arch
      var wallTex = st.hangar ? FacilityStyle.WALL_HANGAR : FacilityStyle.WALL_EXTERIOR;
      if (st.hangar)
        FacilityRoof.crescents(m, si, wOut);
      var shell:Shell = {
        roof: [],
        glaze: { value: 0.0 },
        paraCells: st.hangar ? 0 : ringCells(m, si),
        paraQuads: st.hangar ? 0 : parapet(m, si, wOut, cope),
      };
      addFloor(scene, floors[Surf.TILE], FacilityStyle.FLOOR_TILE);
      addFloor(scene, floors[Surf.LINO], FacilityStyle.FLOOR_LINO);
      addFloor(scene, floors[Surf.CONCRETE], FacilityStyle.FLOOR_CONCRETE);
      addFloor(scene, floors[Surf.OFFICE], FacilityStyle.FLOOR_OFFICE);
      addFloor(scene, floors[Surf.WASH], FacilityStyle.FLOOR_WASH);
      add(scene, wOut, wallTex, true, true);
      add(scene, wRoom, FacilityStyle.WALL_ROOM, true, false);
      add(scene, wCorr, FacilityStyle.WALL_CORRIDOR, true, false);
      add(scene, wOffice, FacilityStyle.WALL_OFFICE, true, false);
      add(scene, wWash, FacilityStyle.WALL_WASH, true, false);
      add(scene, shut, FacilityStyle.DOOR_SHUTTER, true, true);
      add(scene, head, FacilityStyle.WINDOW_HEAD, true, false);
      // the coping does not cast: the cladding under it is in wOut, which does, and at the moon
      // box's 0.088 units per shadow texel a 0.25-tall band overhanging 0.12 adds at most three
      // texels to a silhouette that is already thrown
      add(scene, cope, FacilityStyle.COPING, true, false);
      addPane(scene, panes, FacilityStyle.WINDOW_LIT, shell);
      addPane(scene, panes2, FacilityStyle.WINDOW_LIT_2, shell);
      addPane(scene, panesHigh, FacilityStyle.WINDOW_HIGH_TEX, shell);
      // the roof takes NO vision mask. it is the one surface whose visibility is decided by where the
      // player STANDS rather than by what they can see: masked, a roof over cells the sweep never
      // reached would sink to the fog colour and the building would read as a hole in its own lot
      // from every angle outside it
      addDeck(scene, rim, FacilityStyle.ROOF, false, shell);
      addDeck(scene, roof, FacilityStyle.ROOF, true, shell);
      return shell;
    }

// the indoor floor buffer a cell's surface asks for. `Surf.GRATE` is deliberately absent and falls
// to room floor: a drain is a fitting IN the floor and not a floor of its own, so it is the
// objects.FloorDrain standing on the cell that paints it, one centred decal — see the atlas note on
// `facility/floor-grate` in textures.json. Painted as a cell-wide surface here instead, a 2 m square
// of grating read as a vehicle pit, and tiled down it read as four of them
  static function floorBuf(m:Facility, col:Int, row:Int, floors:Array<MeshBuf>):MeshBuf
    {
      return switch (surfUnder(m, col, row))
        {
          case Surf.LINO: floors[Surf.LINO];
          case Surf.CONCRETE: floors[Surf.CONCRETE];
          case Surf.OFFICE: floors[Surf.OFFICE];
          case Surf.WASH: floors[Surf.WASH];
          default: floors[Surf.TILE];
        };
    }

// the surface a cell's floor is drawn in — its own, except that a DRAIN inherits its neighbours'.
//
// `Surf.GRATE` is a final tile id the generator writes under a floor drain, and FacilityRooms
// .paintRoomFloor steps over final ids — so a washroom's drain cell kept the laboratory's own tile
// and rendered as one square of lab floor in the middle of the marble. The drain's art is a centred
// decal of its own (FacilityDeco.drain), so what belongs UNDER it is simply the room's floor
  static function surfUnder(m:Facility, col:Int, row:Int):Int
    {
      var s = m.surf[row][col];
      if (s != Surf.GRATE)
        return s;
      for (d in 0...4)
        {
          var c = col + DC[d], r = row + DR[d];
          if (FacilityModel.inside(m, c, r) &&
              m.surf[r][c] != Surf.GRATE &&
              FacilityModel.isIndoor(m, c, r))
            return m.surf[r][c];
        }
      return Surf.TILE;
    }

// the top of one wall or door cell's masonry — permanent roof, and over glazing the aluminium
// capping UNDER it, because a window run capped in plain roof read as a strip of bitumen and gravel
// lying on the glass, and one capped in aluminium read as a strip of window head lying in the roof.
//
// emitted as the UNION OF THE RUNS and not as the slab box: the run along x across the middle band,
// and the run along z's two arms, each degenerate and self-skipping where that line does not carry.
// the box would hang a permanent 1x1 patch of rim over the room in every corner's angle, which is
// the notch — the FADING roof's, laid by the strips loop in structure().
//
// the band no longer overhangs on an OUTDOOR side either. it used to stop at WALL_T's inset rather
// than the cell's own, which was a no-op on solid wall and left half a unit of roof out over the
// glass at every window run: the straight roof line it bought was not worth the bitumen sitting on
// the outside of the pane, and the run now notches in with the glazing.
//
// a GLAZED band sinks HEAD_DROP out of the deck plane, because it is not the only thing there: the
// caller lays the same band again in the FADING deck buffer, so the capping is what the player sees
// once the roof has gone and plain roof is what they see while it is up. `deck` is a parameter and
// not the rim for exactly that second call — it takes the fading buffer with glazed false
  static function capTop(deck:MeshBuf, capping:MeshBuf, m:Facility, col:Int, row:Int,
      glazed:Bool):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var s = slab(m, col, row);
      var e = (CELL - thick(m, col, row)) / 2;
      var xa = col * CELL - half + e, xb = xa + CELL - 2 * e;
      var za = row * CELL - half + e, zb = za + CELL - 2 * e;
      var b = glazed ? capping : deck;
      var t = glazed ? FacilityStyle.HEAD_TILE : FacilityStyle.ROOF_TILE;
      var y = FacilityStyle.ROOF_Y - (glazed ? FacilityStyle.HEAD_DROP : 0.0);
      // with no run along x there is nothing to split around, and the run along z is one rect. worth
      // the branch: without it every cell of every vertical wall in the area emitted its band as
      // three quads that abut, ~900 triangles of roof for no pixel's difference
      if (!carries(m, col - 1, row) &&
          !carries(m, col + 1, row))
        {
          cap(b, xa, xb, s.z0, s.z1, y, t);
          return;
        }
      cap(b, s.x0, s.x1, za, zb, y, t);
      cap(b, xa, xb, s.z0, za, y, t);
      cap(b, xa, xb, zb, s.z1, y, t);
    }

// does this cell stand a length of OUTWARD parapet in `dir`? the wall LINE has to carry through the
// cell and the neighbour it looks at has to be outdoors.
//
// `carries` and not `isWall`, which is the whole difference between a roofline and a roofline with
// holes in it: a DOOR cell is a hole in the wall line, not the end of it, and it never enters the
// `for (dir in 0...4)` loop in structure() at all — its outward face comes from the `di >= 0` branch
// instead. keyed on isWall the parapet opens a 4-unit gap over every one of the area's 7 exterior
// doors. slab() on a door cell returns the lintel planes, already inset by exactly PARAPET_INSET,
// so the band runs dead straight over the opening with no case of its own
  static inline function outward(m:Facility, col:Int, row:Int, dir:Int):Bool
    {
      return carries(m, col, row) &&
        !carries(m, col + DC[dir], row + DR[dir]) &&
        !FacilityModel.isIndoor(m, col + DC[dir], row + DR[dir]);
    }

// slab() with the SOLID wall's inset FORCED, whatever this cell's own masonry is.
//
// it is a near-copy rather than an optional argument on slab(), because slab is public and its
// contract — the bounding box of a cell's MASONRY — is load-bearing for strips, floorStrips, capTop
// and the window-run loop, and a second inset would make its header a lie.
//
// the forcing is the point: a glazed cell's slab is GLASS_T where its neighbours' are WALL_T, so a
// parapet following the slab would jog half a unit in and out at every window run's two ends. what
// that costs is one soffit quad per glazed band (the ring stands 0.5 proud of the glass, with air
// under it); what it buys is a dead straight roofline and, less obviously, a joint test that never
// has to compare planes — two bands meeting at a cell boundary are always collinear
  static function ringRect(m:Facility, col:Int, row:Int):Rect
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var e = FacilityStyle.PARAPET_INSET;
      var x0 = col * CELL - half;
      var z0 = row * CELL - half;
      return {
        x0: x0 + (carries(m, col - 1, row) ? 0.0 : e),
        x1: x0 + CELL - (carries(m, col + 1, row) ? 0.0 : e),
        z0: z0 + (carries(m, col, row - 1) ? 0.0 : e),
        z1: z0 + CELL - (carries(m, col, row + 1) ? 0.0 : e),
      };
    }

// how the perimeter behaves past one end of a band, where `q` is the run direction leaving it.
// 0 = the line carries on (or the band simply ends), 1 = CONVEX — the perpendicular band on THIS
// cell overlaps it in a T x T square, 2 = CONCAVE — the perimeter steps and the two leave one empty.
//
// the fourth combination cannot happen and needs no branch: if the neighbour along the run is
// outdoors then this cell's own face in `q` looks at it, so `outward` there is true by construction
  static function endCase(m:Facility, col:Int, row:Int, dir:Int, q:Int):Int
    {
      if (carries(m, col + DC[q], row + DR[q]))
        return outward(m, col + DC[q], row + DR[q], dir) ? 0 : 2;
      return outward(m, col, row, q) ? 1 : 0;
    }

// the five parts of a band, which do NOT share a run extent — see grow()
  static inline var P_OUT = 0;    // cladding, outer face
  static inline var P_IN = 1;     // cladding, inner face
  static inline var P_COPE = 2;   // the coping's top
  static inline var P_CO_OUT = 3; // its outer fascia
  static inline var P_CO_IN = 4;  // its inner fascia

// how far one PART of a band grows OUTWARD past the rect it came from at one end — negative
// retracts. five parts and not one number, which is the whole of getting a corner right:
//
// a joint between two perpendicular bands is a MITRE. both OUTER faces run all the way to the
// corner and meet there in a line; both INNER faces stop one thickness short of it, so the T x T
// corner square is enclosed by the two outer faces and solid. retracting the outer face with the
// inner one is what a single growth number does, and it leaves the corner square's own outward face
// unemitted: photographed from the game camera as a slot at every building corner that you can see
// straight through onto the roof deck. the coping's two fascias mitre the same way, one thickness
// wider.
//
// the coping's TOP is the exception and the reason `alongX` is here at all. it is the one part that
// is HORIZONTAL, so two of them meeting cannot simply share a line — they would overlap and
// z-fight. z-bands own every corner square and x-bands yield, which is render.world.roofs.Parapets'
// always-emitted corner post transposed to an axis rule (there is no post here to be one)
  static inline function grow(kase:Int, alongX:Bool, part:Int):Float
    {
      var t = FacilityStyle.PARAPET_T;
      var co = FacilityStyle.COPING_OUT;
      if (kase == 0)
        return 0.0;
      var sgn = (kase == 1 ? -1.0 : 1.0); // convex retracts, concave extends
      return switch (part)
        {
          case P_OUT: 0.0;
          case P_IN: sgn * t;
          case P_CO_OUT: co;
          case P_CO_IN: sgn * (t + co);
          default: alongX ? -(kase == 1 ? t + co : co) : (kase == 1 ? co : t + co);
        };
    }

// one length of parapet: two faces of cladding standing on the roof deck and a four-quad coping over
// them, plus the soffit a band over GLAZING needs because it oversails the thinner slab.
//
// the coping's UNDERSIDE is one of those four, and it was left out of the first build on the rule
// that nothing downward-facing at the roofline is ever seen. That rule is about the DECK, which is
// enclosed; the coping oversails the cladding by COPING_OUT on both sides and its underside is the
// only thing there to see from below the parapet — reported from the game as the cap having no
// bottom. It is emitted as ONE quad on the coping's own footprint rather than as the two 0.12
// overhang strips it is visible along: the middle 0.6 is buried inside the parapet either way, and
// one quad is cheaper than two. Taking the P_COPE extents also hands it the corner mitre for free
//
// `p` is the outer plane and `b0/b1` the run ends of the rect it came from; every part works out
// its own two ends off those and the end cases `k0/k1`. a degenerate rect is how a plane gets
// handed to `face`, the same trick butt() uses
  static function band(wOut:MeshBuf, cope:MeshBuf, dir:Int, p:Float, b0:Float, b1:Float,
      k0:Int, k1:Int, soffit:Bool):Void
    {
      var alongX = (dir < 2);
      var inw = -(alongX ? DR[dir] : DC[dir]);
      var pi = p + inw * FacilityStyle.PARAPET_T;
      var o0 = p - inw * FacilityStyle.COPING_OUT;
      var o1 = pi + inw * FacilityStyle.COPING_OUT;
      var lo = o0 < o1 ? o0 : o1;
      var hi = o0 < o1 ? o1 : o0;
      var y0 = FacilityStyle.ROOF_Y;
      var y1 = y0 + FacilityStyle.PARAPET_H;
      var y2 = y1 + FacilityStyle.COPING_H;
      var wt = FacilityStyle.WALL_TILE;
      var ct = FacilityStyle.COPING_TILE;
      inline function a0(part:Int):Float
        return b0 - grow(k0, alongX, part);
      inline function a1(part:Int):Float
        return b1 + grow(k1, alongX, part);
      if (alongX)
        {
          face(wOut, a0(P_OUT), a1(P_OUT), p, p, dir, y0, y1, wt);
          face(wOut, a0(P_IN), a1(P_IN), pi, pi, dir ^ 1, y0, y1, wt);
          face(cope, a0(P_CO_OUT), a1(P_CO_OUT), o0, o0, dir, y1, y2, ct);
          face(cope, a0(P_CO_IN), a1(P_CO_IN), o1, o1, dir ^ 1, y1, y2, ct);
          cap(cope, a0(P_COPE), a1(P_COPE), lo, hi, y2, ct);
          capDown(cope, a0(P_COPE), a1(P_COPE), lo, hi, y1, ct);
          if (soffit)
            capDown(wOut, a0(P_OUT), a1(P_OUT), p < pi ? p : pi, p < pi ? pi : p, y0, wt);
          return;
        }
      face(wOut, p, p, a0(P_OUT), a1(P_OUT), dir, y0, y1, wt);
      face(wOut, pi, pi, a0(P_IN), a1(P_IN), dir ^ 1, y0, y1, wt);
      face(cope, o0, o0, a0(P_CO_OUT), a1(P_CO_OUT), dir, y1, y2, ct);
      face(cope, o1, o1, a0(P_CO_IN), a1(P_CO_IN), dir ^ 1, y1, y2, ct);
      cap(cope, lo, hi, a0(P_COPE), a1(P_COPE), y2, ct);
      capDown(cope, lo, hi, a0(P_COPE), a1(P_COPE), y1, ct);
      if (soffit)
        capDown(wOut, p < pi ? p : pi, p < pi ? pi : p, a0(P_OUT), a1(P_OUT), y0, wt);
    }

// the parapet ring for one structure: the exterior cladding continuing PARAPET_H above the roof
// deck and a coping band capping it. it is what gives the compound a ROOFLINE — without it the wall
// stops dead at ROOF_Y and a single-storey building reads as a flat lid from a camera pitched 51
// degrees down.
//
// it costs NO draw call. the cladding merges into wOut, which is already the exterior wall's own
// buffer at the same texture and the same world-aligned UVs (so the panel course simply carries up
// past the roofline), already casts and receives, and is already VisionMask-patched at the same XZ
// as the wall under it. the coping merges into `head`, the window capping — measured, and the
// obvious city/coping.png is the wrong answer: it sits within 1% of facility/wall-exterior's own
// linear luminance and produces a coping nobody can see, where window-head is 1.43x the wall, which
// is a capping band rather than a white outline round every building. it is also what a coping IS,
// the same flashing system the window heads already wear
//
// returns the quad count, read straight off the buffers so it cannot drift from what was emitted
  static function parapet(m:Facility, si:Int, wOut:MeshBuf, cope:MeshBuf):Int
    {
      var st = m.structures[si];
      var before = wOut.idx.length + cope.idx.length;
      for (row in st.oy1...st.oy2 + 1)
        for (col in st.ox1...st.ox2 + 1)
          {
            if (!FacilityModel.inside(m, col, row) ||
                m.owner[row][col] != si ||
                !carries(m, col, row))
              continue;
            var r = ringRect(m, col, row);
            var glazed = FacilityModel.isWall(m, col, row) &&
              m.wall[row][col] == Wall.WINDOW;
            for (dir in 0...4)
              {
                if (!outward(m, col, row, dir))
                  continue;
                var alongX = (dir < 2);
                var p = alongX ? (dir == 0 ? r.z0 : r.z1) : (dir == 2 ? r.x0 : r.x1);
                var b0 = alongX ? r.x0 : r.z0;
                var b1 = alongX ? r.x1 : r.z1;
                band(wOut, cope, dir, p, b0, b1,
                  endCase(m, col, row, dir, alongX ? 2 : 0),
                  endCase(m, col, row, dir, alongX ? 3 : 1), glazed);
              }
            // the reentrant corners. a notch's two faces are the only thing that carries the
            // perimeter round the inside of an L, and they are stated here rather than left out
            // because the generator draws rectangular rings TODAY and a flood fill that ever merged
            // two touching footprints would leave a T x T hole in the ring at every turn. the corner
            // is the notch's own inner corner, which is the CONCAVE case at exactly one end of each
            // band while the other end carries on into the neighbouring cell's
            for (n in notches(m, col, row))
              {
                if (FacilityModel.isIndoor(m, n.col, n.row))
                  continue;
                var zc = (n.dz == 1);
                var xc = (n.dx == 3);
                band(wOut, cope, n.dx, xc ? n.x0 : n.x1, n.z0, n.z1,
                  zc ? 2 : 0, zc ? 0 : 2, false);
                band(wOut, cope, n.dz, zc ? n.z0 : n.z1, n.x0, n.x1,
                  xc ? 2 : 0, xc ? 0 : 2, false);
              }
          }
      return Std.int((wOut.idx.length + cope.idx.length - before) / 6);
    }

// how many cells of this structure stand a length of parapet — the ring's own cell count, for
// __facility().roof beside the quad count parapet() returns
  static function ringCells(m:Facility, si:Int):Int
    {
      var st = m.structures[si];
      var n = 0;
      for (row in st.oy1...st.oy2 + 1)
        for (col in st.ox1...st.ox2 + 1)
          {
            if (!FacilityModel.inside(m, col, row) ||
                m.owner[row][col] != si)
              continue;
            for (dir in 0...4)
              if (outward(m, col, row, dir))
                {
                  n++;
                  break;
                }
          }
      return n;
    }

// the two side reveals of an opening, from `y0` to `y1`. both lie in the cell boundary planes the
// wall line runs through, and both look INWARD — the opposite way round from a wall face at the same
// place — so each is emitted for the direction pointing at the other jamb.
//
// THREE CALLERS AND THEY ARE WHY THE HEIGHTS ARE PARAMETERS: a doorway (floor to lintel), a ribbon
// window and a washroom LIGHT WELL (each sill to head).
//
// THE RIBBON WAS THE ONE LEFT OUT, on the belief that "the flanking cells' butt caps close its ends
// for free". They do not: `butt` caps the boundary plane only where the thick cell stands PROUD of
// the thin one, which is the two (WALL_T - GLASS_T) / 2 shoulders either side of the glazing band
// and never the band itself. See the reveal block in `structure` for the measurement. A light well
// reaches the same hole from the other end — it is punched in a cell of FULL WALL THICKNESS (`thick`
// reads Wall.WINDOW and a well is Wall.WINDOW_HIGH), so its neighbours take the equal-thickness
// branch and emit nothing at all.
  static function jamb(b:MeshBuf, alongX:Bool, s:Rect, y0:Float, y1:Float, t:Float):Void
    {
      if (alongX)
        {
          face(b, s.x0, s.x0, s.z0, s.z1, 3, y0, y1, t);
          face(b, s.x1, s.x1, s.z0, s.z1, 2, y0, y1, t);
          return;
        }
      face(b, s.x0, s.x1, s.z0, s.z0, 1, y0, y1, t);
      face(b, s.x0, s.x1, s.z1, s.z1, 0, y0, y1, t);
    }

// the strip of masonry closing a doorway's own threshold, WALL_BASE up to the floor. every OTHER
// cell gets this from its wall face, which now starts at WALL_BASE — but under a lintel there is no
// masonry at all, so the outdoor half of the cell is laid at the neighbouring surface's height by
// floorStrips and the indoor half at 0, and on a dropped surface the two meet with nothing between.
// the hangar's side door opens straight onto the lot and is where it shows.
//
// BOTH planes, wound OUTWARD, and no test of which one faces out: the indoor one is buried under
// that cell's own floor cap, whose top edge is this quad's top edge, and a camera pitched 51 degrees
// down cannot see under a step. the same thing that makes the skirt free everywhere else
// the hood of the bulkhead lamp over an exterior door, as FOUR QUADS in the compound's one hood
// buffer — its own art, so it can no longer ride the cladding (see FacilityShellOpts.hood).
//
// NOT A GLB — see FacilityStyle.DOOR_LAMP_W's header for why, and render.facility.FacilityEntry's
// for the general rule. no BACK face (it is against the masonry) and no UNDERSIDE: this camera
// pitches 51 degrees DOWN, so the soffit of a thing standing off a wall is never in frame, which is
// the same reason FacilityRoof.box has no bottom either.
//
// the position comes from FacilityGlow.lamp and is not recomputed here, because the lens quad and
// the spotlight are hung off that same point and a hood that drifted from its own light is the one
// error none of the three files could see alone
  static function doorLamp(b:MeshBuf, m:Facility, d:FacilityModel.DoorCell):Void
    {
      var l = FacilityGlow.lamp(m, d);
      if (l == null)
        return;
      // the box: half the hood's width along the wall line, and its depth reaching BACK from the
      // shared point to the masonry. that point is the LENS PLANE, i.e. the hood's front face and
      // not its centre, so the box hangs behind it — centred on it, the hood floated 0.3 off the
      // wall with daylight behind it
      var hw = FacilityStyle.DOOR_LAMP_W / 2;
      var hd = FacilityStyle.DOOR_LAMP_D / 2;
      var cx = l.x - l.nx * hd;
      var cz = l.z - l.nz * hd;
      var x0 = cx - (l.nx != 0 ? hd : hw), x1 = cx + (l.nx != 0 ? hd : hw);
      var z0 = cz - (l.nz != 0 ? hd : hw), z1 = cz + (l.nz != 0 ? hd : hw);
      var y0 = FacilityStyle.DOOR_LAMP_Y;
      var y1 = y0 + FacilityStyle.DOOR_LAMP_H;
      for (dir in 0...4)
        if (dir != (l.dir ^ 1))
          face(b, x0, x1, z0, z1, dir, y0, y1, FacilityStyle.DOOR_LAMP_TILE);
      cap(b, x0, x1, z0, z1, y1, FacilityStyle.DOOR_LAMP_TILE);
    }

  static function threshold(b:MeshBuf, alongX:Bool, s:Rect):Void
    {
      if (alongX)
        {
          face(b, s.x0, s.x0, s.z0, s.z1, 2, FacilityStyle.WALL_BASE, 0.0, FacilityStyle.WALL_TILE);
          face(b, s.x1, s.x1, s.z0, s.z1, 3, FacilityStyle.WALL_BASE, 0.0, FacilityStyle.WALL_TILE);
          return;
        }
      face(b, s.x0, s.x1, s.z0, s.z0, 0, FacilityStyle.WALL_BASE, 0.0, FacilityStyle.WALL_TILE);
      face(b, s.x0, s.x1, s.z1, s.z1, 1, FacilityStyle.WALL_BASE, 0.0, FacilityStyle.WALL_TILE);
    }

// one exposed end of a slab where its neighbour's cross-section falls short of it. the quad lives
// in the cell boundary plane, so it is `face` with both coordinates of one axis collapsed onto it
  static function butt(b:MeshBuf, flat:Bool, plane:Float, a0:Float, a1:Float, dir:Int):Void
    {
      if (flat)
        face(b, a0, a1, plane, plane, dir, FacilityStyle.WALL_BASE, FacilityStyle.WALL_H,
          FacilityStyle.WALL_TILE);
      else
        face(b, plane, plane, a0, a1, dir, FacilityStyle.WALL_BASE, FacilityStyle.WALL_H,
          FacilityStyle.WALL_TILE);
    }

// one horizontal cell quad at height y, world-aligned UVs (never stretched). public because
// render.facility.FacilityTables emits its worktops with it — a bench is the same kind of surface as
// a floor or a roof, and duplicating the winding is how one of them ends up facing the wrong way
  public static function cap(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, y:Float, t:Float):Void
    {
      if (x1 - x0 < 0.01 ||
          z1 - z0 < 0.01)
        return;
      MeshBufTools.quad(b, [x0, y, z1], [x1, y, z1], [x1, y, z0], [x0, y, z0],
        [x0 / t, z1 / t, x1 / t, z1 / t, x1 / t, z0 / t, x0 / t, z0 / t]);
    }

// the same quad wound the other way, so it is seen from BELOW — a door head's soffit. public for
// render.facility.FacilityEntry, whose booth roof is a free-standing slab and so needs its own
  public static function capDown(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, y:Float, t:Float):Void
    {
      if (x1 - x0 < 0.01 ||
          z1 - z0 < 0.01)
        return;
      MeshBufTools.quad(b, [x0, y, z0], [x1, y, z0], [x1, y, z1], [x0, y, z1],
        [x0 / t, z0 / t, x1 / t, z0 / t, x1 / t, z1 / t, x0 / t, z1 / t]);
    }

// the run endpoints of a cell-edge face, wound so the FRONT face looks at the neighbour in `dir`.
// derived rather than hand-cased: for a run direction d the quad's normal is (-dz, 0, dx), so each
// direction fixes which end of the edge is wound first. getting this backwards is invisible until a
// whole axis of faces disappears — the failure render.wild.WildRoad's dashes recorded.
// public alongside `face` for render.facility.FacilityTables, which has to emit its cabinet fronts
// with a different period on each axis and so cannot call `face` — but must not re-derive THIS
  public static inline function ends(x0:Float, x1:Float, z0:Float, z1:Float, dir:Int):Array<Float>
    {
      return switch (dir)
        {
          case 0: [x1, z0, x0, z0];
          case 1: [x0, z1, x1, z1];
          case 2: [x0, z0, x0, z1];
          default: [x1, z1, x1, z0];
        };
    }

// a rect's face in `dir`, collapsed to the plane that face lies on and pushed `eps` out of the
// masonry — the degenerate rect the wall-decal passes wind a quad against.
//
// the four cases are the one thing here that is invisible when they are wrong: a quad emitted
// against dir 2 where the caller meant dir 3 lands INSIDE the wall and simply never appears. two
// passes need it (render.facility.FacilityGrime's damp band, FacilityDetail's corner strips) and a
// third would have copied it, so it lives here with `ends`, which is the other half of the same job
  public static inline function plane(s:Rect, dir:Int, eps:Float):Rect
    {
      return switch (dir)
        {
          case 0: { x0: s.x0, x1: s.x1, z0: s.z0 - eps, z1: s.z0 - eps };
          case 1: { x0: s.x0, x1: s.x1, z0: s.z1 + eps, z1: s.z1 + eps };
          case 2: { x0: s.x0 - eps, x1: s.x0 - eps, z0: s.z0, z1: s.z1 };
          default: { x0: s.x1 + eps, x1: s.x1 + eps, z0: s.z0, z1: s.z1 };
        };
    }

// one vertical wall face spanning y0..y1, UVs world-aligned along the run and up the wall so
// neighbouring faces of one long wall carry a continuous course. `t` is the repeat period, which the
// shutter runs take at their own value so their slat pitch is independent of the wall course.
// public for render.facility.FacilityTables, which emits a bench's sides with it: the `dir` winding
// is the one thing here that is invisible until a whole axis of faces disappears
  public static function face(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float,
      dir:Int, y0:Float, y1:Float, t:Float):Void
    {
      if (y1 - y0 < 0.01)
        return;
      var e = ends(x0, x1, z0, z1, dir);
      var us = (dir < 2 ? e[0] : e[1]) / t;
      var ue = (dir < 2 ? e[2] : e[3]) / t;
      if (Math.abs(ue - us) < 0.0001)
        return;
      MeshBufTools.quad(b, [e[0], y0, e[1]], [e[2], y0, e[3]], [e[2], y1, e[3]], [e[0], y1, e[1]],
        [us, y0 / t, ue, y0 / t, ue, y1 / t, us, y1 / t]);
    }

// one window pane over a whole run: the same face winding, but the texture maps 0..1 across it
// rather than tiling. public for render.facility.FacilityEntry, whose booth is glazed on all four
// sides and so wants the same 0..1 mapping over a face that is not part of any wall run
//
// FLUSH with the wall plane. it used to stand a hundredth of a unit proud of it "so nothing depends
// on polygonOffset" — but the emitter cuts the opening OUT of the wall rather than painting the pane
// over it, so the two are never coplanar-and-overlapping and there was nothing to fight with. All
// the offset bought was a seam of open air along the head and the sill, where the reveal's own caps
// stop at the masonry and the glass no longer did
  public static function pane(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float,
      dir:Int, y0:Float, y1:Float):Void
    {
      var e = ends(x0, x1, z0, z1, dir);
      MeshBufTools.quad(b,
        [e[0], y0, e[1]], [e[2], y0, e[3]], [e[2], y1, e[3]], [e[0], y1, e[1]],
        [0, 0, 1, 0, 1, 1, 0, 1]);
    }

// merge a buffer into one lit mesh. every one of these is OPAQUE now: the walls stopped fading with
// the roof, so nothing here needs `transparent` and nothing here pays for the sorted pass.
// public for render.facility.FacilityEntry, whose booth is a shell like any other — walls in the
// same cladding, a roof in the same felt, and no reason to carry a second copy of this
  public static function add(scene:Scene, b:MeshBuf, tex:String, recv:Bool, casts:Bool):Void
    {
      if (b.idx.length == 0)
        return;
      var mat = VisionMask.patch(new MeshLambertMaterial({
        map: Textures.loadTexture(tex, 'wall', 1),
        side: THREE.FrontSide,
      }));
      var mesh = new Mesh(geom(b), mat);
      mesh.receiveShadow = recv;
      mesh.castShadow = casts;
      scene.add(mesh);
    }

// the same merge as `add`, for a surface the contact shadow lies ON — the three interior floors and
// nothing else. it is a separate entry point rather than a sixth argument to `add` because that is
// the arg count this repo's style guide says to stop appending at, and because the answer is not a
// caller's taste: a WALL cannot take this patch at all. render.world.ContactMask is top-down, so
// every fragment of a 6-unit wall face samples the same xz and the whole column would darken by one
// flat amount. the mask darkens the ground a wall stands on, never the wall
  static function addFloor(scene:Scene, b:MeshBuf, tex:String):Void
    {
      if (b.idx.length == 0)
        return;
      // CONTACT FIRST, VISION SECOND, and the order is load-bearing in both directions. both hooks
      // replace <fog_fragment> with itself plus their code, so whoever patches first lands LAST in
      // main() — and the contact term reads `visMaskRaw`, which VisionMask assigns. Swap these and
      // the shader either fails to compile or reads an unassigned global
      var mat = VisionMask.patch(ContactMask.patch(new MeshLambertMaterial({
        map: Textures.loadTexture(tex, 'wall', 1),
        side: THREE.FrontSide,
      })));
      var mesh = new Mesh(geom(b), mat);
      mesh.receiveShadow = true;
      scene.add(mesh);
    }

// the lit window pane, frame and glass in ONE draw.
//
// the alpha does the splitting and it comes out of the texture, not the shader: tools/textures.py's
// `glass_alpha` key takes the bright half of the art down to 128 and leaves the dark frame at 255,
// which the source's own luma histogram separates outright (frame 16-127 at 30.6%, glass 144-207 at
// 58.8%, a 0.2% valley between). so the frame stays solid, the glass is half see-through, and there
// is no second mesh and no second material. alphaTest is only there to kill the transparent margin
// the API's cut leaves, so it never writes depth.
//
// the texture is cropped to its own ALPHA BBOX rather than to a pair of hand-fitted fractions. those
// fractions are only right for the exact drop they were measured on and are centred by construction,
// and the art's bbox need not be: the last one sat 9px high of its image, so the crop shaved the top
// rail off the frame and left an empty strip under the glass for alphaTest to throw away.
//
// `transparent` is set AFTER VisionMask.patch on purpose: the mask reads that flag to choose which
// branch it compiles, and set first it would pick the alpha-scaling branch and fade a hidden window
// OUT instead of sinking it toward the fog (see render.wild.WildRoad)
//
// `tex` is the art for ONE RUN LENGTH, which is why the caller keeps two buffers and calls this
// twice. `pane` maps one unit of u across a whole run, so the number of panes a run shows is a
// property of the IMAGE and not of the geometry: the three-pane art drawn on a 2-cell opening is that
// window at two thirds scale. It costs one extra mesh per structure carrying both lengths — measured
// on a generated compound, the two structures with windows both do, so 2 pane meshes became 4
  static function addPane(scene:Scene, b:MeshBuf, path:String, shell:Shell):Void
    {
      if (b.idx.length == 0)
        return;
      var tex = Textures.loadAlphaCropped(path);
      // held as its own typed local rather than as `patch`'s Dynamic return, because `glaze` below
      // hooks it before the mask does. `patch` folds the mask into this same object and hands it back
      var mat = new MeshLambertMaterial({
        map: tex,
        emissiveMap: tex,
        emissive: new Color(0xffffff),
        emissiveIntensity: FacilityStyle.WINDOW_EMISSIVE,
        alphaTest: 0.02,
        side: THREE.FrontSide,
      });
      // BEFORE the mask, so the mask chains onto this hook rather than the other way round. the two
      // use different anchors (<map_fragment> / <emissivemap_fragment> against <fog_fragment>) and
      // VisionMask carries a chained hook's cache key forward, which is the whole contract here
      glaze(mat, shell.glaze);
      VisionMask.patch(mat);
      mat.transparent = true;
      var mesh = new Mesh(geom(b), mat);
      mesh.receiveShadow = false;
      // the pane CASTS, and it is the only thing that can: the run's opening is cut OUT of the wall
      // (see the sill/head pair in `structure`) and the exterior wall is the shell's one caster, so a
      // non-casting pane left a real hole in the masonry for the moon — one clean parallelogram of
      // moonlight per window run, lying on the floor inside the wall's own shadow. the depth material
      // carries alphaTest so the glass casts solid, and shadowSide flips FrontSide to BackSide, which
      // picks exactly the one of the run's two coplanar faces that looks away from the moon
      mesh.castShadow = true;
      scene.add(mesh);
    }

// the tint every pane's GLASS takes when the player is inside, as one shared uniform — the value is
// a constant and every pane in the game wants the same one
  static var uPaneTint:Dynamic = null;

// fold the "player is inside this building" dimmer into one pane material's own shader. `u` is the
// structure's amount, 0 lit .. 1 seen from inside, and it is the ONLY thing that moves per frame.
//
// IT HAS TO BE A SHADER, and the frames are why. This was `material.color` for a build, which
// multiplies the whole map, and the art's frame members are already sRGB 16-127 — tinted, they
// crushed into the glass and an opening read as one flat black rectangle. Reported from the game as
// exactly that. The only thing that separates frame from glass is the ALPHA the art already carries
// (tools/textures.py's `glass_alpha`: bright half to 128, frame left at 255, which the source's own
// luma histogram splits outright), and nothing but a fragment can read it. See
// FacilityStyle.WINDOW_TINT_IN.
//
// the two anchors are chosen and not interchangeable: <map_fragment> is where `diffuseColor` has
// just taken the map and so is the only point the alpha means the art's alpha, and it runs BEFORE
// <alphatest_fragment>, which this must not disturb — only `.rgb` is touched. <emissivemap_fragment>
// is where `totalEmissiveRadiance` exists at all
  static function glaze(mat:MeshLambertMaterial, u:Dynamic):Void
    {
      // three's shader hooks are an untyped API — `onBeforeCompile` and `customProgramCacheKey` are
      // on no extern and cannot be, being a compiler callback and a cache-key method. Same boundary
      // render.world.VisionMask.patch crosses, in the same way
      var d:Dynamic = mat;
      if (uPaneTint == null)
        uPaneTint = { value: new Color(FacilityStyle.WINDOW_TINT_IN) };
      d.onBeforeCompile = function(shader:Dynamic, renderer:Dynamic)
        {
          shader.uniforms.paneGlaze = u;
          shader.uniforms.paneTint = uPaneTint;
          // the mask is DILATED before it is thresholded — see FacilityStyle.WINDOW_TINT_GROW. min
          // of a plus-shaped tap, which is a morphological grow: a fragment counts as glass if
          // anything within GROW texels of it is. Four taps and not eight because the members this
          // has to reach under are a mullion and a rail, both axis-aligned; a corner nick two texels
          // across is not visible. `textureSize` rather than a uniform: the art is cropped to its own
          // alpha bbox at LOAD, so its size is not known when this material is built.
          //
          // smoothstep and not step on the result: the ramp is what keeps the grown edge from
          // drawing a hard line of its own one texel further out
          shader.fragmentShader = 'uniform float paneGlaze;\n' +
            'uniform vec3 paneTint;\n' +
            StringTools.replace(shader.fragmentShader, '#include <map_fragment>',
              '#include <map_fragment>\n' +
              // `float( .. )` around the constant on purpose: Haxe prints 2.0 as "2", and a bare
              // integer literal divided by a vec2 leans on ESSL 3.00's implicit conversion
              '  vec2 paneTx = float( ' + FacilityStyle.WINDOW_TINT_GROW +
                ' ) / vec2( textureSize( map, 0 ) );\n' +
              '  float paneA = diffuseColor.a;\n' +
              '  paneA = min( paneA, texture2D( map, vMapUv + vec2( paneTx.x, 0.0 ) ).a );\n' +
              '  paneA = min( paneA, texture2D( map, vMapUv - vec2( paneTx.x, 0.0 ) ).a );\n' +
              '  paneA = min( paneA, texture2D( map, vMapUv + vec2( 0.0, paneTx.y ) ).a );\n' +
              '  paneA = min( paneA, texture2D( map, vMapUv - vec2( 0.0, paneTx.y ) ).a );\n' +
              '  float paneGlass = smoothstep( 0.90, 0.70, paneA );\n' +
              '  diffuseColor.rgb *= mix( vec3( 1.0 ), paneTint, paneGlaze * paneGlass );');
          // the glow goes with the WHOLE pane, frame included — it is what carries the glass over
          // BLOOM_THRESHOLD, and the frame never crossed it at any intensity anyway
          shader.fragmentShader = StringTools.replace(shader.fragmentShader,
            '#include <emissivemap_fragment>',
            '#include <emissivemap_fragment>\n' +
            '  totalEmissiveRadiance *= 1.0 - paneGlaze;');
        };
      // an own key, or three hands this program to any other material the mask keys the same way —
      // the trap VisionMask documents. It reads `hasOwnProperty` here and chains what it finds
      d.customProgramCacheKey = function() return 'paneGlaze';
    }

// the roof, and anything STANDING on it that has to fade with it. no vision mask (see the call
// site) and no shadow casting: the moon box follows the player, so a roof casting over its own lot
// would put the whole building in shadow the moment the player walked past it.
//
// `tex` is a parameter because render.facility.FacilityRoof's access hatches come through here too:
// they stand on the fading deck, so a hatch that did not fade with it would be left hanging in the
// air the moment the player stepped inside, and `Shell.roof` is what FacilityArea.apply eases
  public static function addDeck(scene:Scene, b:MeshBuf, tex:String, fades:Bool, shell:Shell):Void
    {
      if (b.idx.length == 0)
        return;
      var mat = new MeshLambertMaterial({
        map: Textures.loadTexture(tex, 'roof', 1),
        side: THREE.FrontSide,
      });
      if (fades)
        {
          mat.transparent = true;
          mat.opacity = 1.0;
        }
      var mesh = new Mesh(geom(b), mat);
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
      if (fades)
        shell.roof.push(mesh);
    }

// one merged buffer as a BufferGeometry.
//
// `col` is an OPT-IN channel (render.world.MeshBuf's own word for it): only the quadC/quadRGB
// emitters fill it, so the attribute is attached when it is filled and every buffer built with plain
// `quad` comes out exactly as it did. DERIVED and not a flag, so the geometry and the material that
// reads it cannot disagree — the caller sets `vertexColors` off the same test
  public static function geom(b:MeshBuf):BufferGeometry
    {
      var g = new BufferGeometry();
      g.setAttribute('position', new Float32BufferAttribute(b.pos, 3));
      g.setAttribute('uv', new Float32BufferAttribute(b.uv, 2));
      if (b.col.length == b.pos.length)
        g.setAttribute('color', new Float32BufferAttribute(b.col, 3));
      g.setIndex(b.idx);
      g.computeVertexNormals();
      return g;
    }
}
