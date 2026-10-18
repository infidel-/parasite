package render.corp;

import three.Three;
import citygen.CityConfig;
import render.facility.FacilityGeom;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;

// the four things hanging on a corp tower's walls: a fire-exit sign, a wayfinding directory, a room
// plate and a framed print.
//
// A TEXTURE AND NOT A PROP, the silhouette-vs-surface guard read the way render.facility
// .FacilityPlacard reads it: a sign's outline is a rectangle and there is nothing in that outline
// to pay triangles for, while everything that says "fire exit" rather than "grey square" is a
// PICTOGRAM on its face. So the whole family is one quad each off one atlas and costs ONE draw
// call however many hang.
//
// ONE PER RUN AND NEVER PER CELL, and the doorway is what ends a run: a door cell is not
// isSolidWall, so a wall with an opening in it is two runs and takes two signs — which is where a
// real pair is. A sign every cell turns a wall into a strip of stickers.
//
// FOUR ASPECTS ON ONE SHEET, which is the one place this differs from the compound's placards and
// the reason it has an ASPECT table at all. The compound's eight plates are all square, so
// PLACARD_W == PLACARD_H and a quad needs no arithmetic. A landscape exit sign, a portrait
// directory, a square plate and a landscape print are not, and drawing any of them on a square quad
// is the stretch docs/3d-geometry.md's aspect lock exists to forbid. So the LONGEST edge is
// CorpStyle.SIGN_MAX and the other comes off the art's own measured ratio.
// one atlas this family draws from. cols x rows of cells in reading order, `cells` of which the
// family actually uses — see CorpSigns.SHEETS
typedef CorpSheet = {
  var tex: String;    // the atlas
  var cols: Int;      // cells across it
  var cells: Int;     // and how many cells it carries, so `rows` is cells / cols
}

class CorpSigns
{
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

  // THREE ATLASES, and a slot is a GLOBAL index across all of them: 0-3 on corp/signs, 4-7 on
  // corp/posters and 8-23 on corp/signs2. So a slot alone still says which sheet it is on and
  // which cell of it, and the arithmetic lives in exactly two places — `sheetOf` and `pane`.
  //
  // IT USED TO BE THE LITERALS `slot < 4` AND `q = i & 3` with four 0.5s, which is a 2x2 pack
  // written out by hand and cannot hold a 4x4. The uv shape below is the one the repo already
  // uses at render.facility.FacilityClutter.emit, and render.facility.FacilityPlacard is the
  // precedent for two sheets serving one family. A fourth sheet is now one row here
  static final SHEETS:Array<CorpSheet> = [
    {
      tex: CorpStyle.SIGN_TEX,
      cols: 2,
      cells: 4,
    },
    {
      tex: CorpStyle.POSTER_TEX,
      cols: 2,
      cells: 4,
    },
    {
      tex: CorpStyle.SIGN2_TEX,
      cols: 4,
      cells: 16,
    },
  ];

  // the cells, in each sheet's own reading order: 0 top-left, then across, then down
  static inline var SIGN_EXIT = 0;       // green running man, circulation only
  static inline var SIGN_DIRECTORY = 1;  // smoked-glass floor listing, circulation only
  static inline var SIGN_PLATE = 2;      // brushed room plate, every other room
  static inline var SIGN_ART = 3;        // framed print, the rooms that would have one
  static inline var POSTER_EYE = 4;      // propaganda, portrait: an eye in a ring
  static inline var POSTER_MARCH = 5;    // propaganda, landscape: the one out of step
  static inline var POSTER_CHART = 6;    // a falling performance chart, the boardroom's
  static inline var POSTER_SCREEN = 7;   // a pulled-down projector screen, one per boardroom
  // and corp/signs2's sixteen: the paperwork a records floor is actually papered with, the
  // compound's fire and evacuation plates, and the markers a floor is navigated by
  static inline var PLATE_NUMBER = 8;    // brushed room-number plate, one big numeral
  static inline var PLATE_NAME = 9;      // lacquer room-name plate with a brass edge
  static inline var PLATE_BRAILLE = 10;  // anodised door plate over a braille strip
  static inline var NOTICE_MEMO = 11;    // a memo pinned to a slim board
  static inline var NOTICE_ROSTER = 12;  // a shift roster, ruled and part-filled
  static inline var NOTICE_WARN = 13;    // the yellow CAUTION notice
  static inline var CERT_FRAMED = 14;    // a framed certificate with a foil seal
  static inline var CERT_PLAQUE = 15;    // a compliance certificate over a brass plaque
  static inline var FIRE_EXT = 16;       // extinguisher plate, red, with its arrow
  static inline var FIRE_HOSE = 17;      // hose reel plate, red
  static inline var FIRE_ALARM = 18;     // alarm call point, red, portrait
  static inline var EVAC_PLAN = 19;      // the framed evacuation diagram
  static inline var EVAC_POINT = 20;     // assembly point, green
  static inline var DEPT_BLOCK = 21;     // a department letter block
  static inline var DEPT_ARROW = 22;     // a department name and a long arrow
  static inline var DEPT_BAND = 23;      // a floor marker over an amber band

  // each panel's own width:height, MEASURED off the built sheets' crops and not chosen — see the
  // class header and art/textures.json's notes on corp/signs and corp/posters
  static var ASPECT = [1.6553, 0.7038, 1.0400, 1.5034, 0.6987, 1.8139, 1.4000, 1.2632,
    1.0062, 1.6183, 0.7113, 1.4259, 0.7826, 0.9799, 0.8164, 1.3837,
    0.9840, 1.0323, 0.8187, 1.3041, 0.9738, 1.0000, 1.4706, 1.5235];

  // WHAT A CORRIDOR TAKES AND WHAT A ROOM TAKES, dealt off the cell's own hash in `pick`. These
  // are the whole point of a third sheet: the "every other room" arm used to be SIGN_PLATE twice
  // over against the two posters, so half the plates in the building were the same plate.
  //
  // SPLIT BY WHERE THE THING WOULD REALLY HANG and not dealt evenly over all sixteen. A fire
  // plate, an evacuation diagram and a department marker are read ON THE WAY PAST and belong on
  // circulation; a room plate, a roster and a certificate are read by whoever works in the room.
  // Both arms keep the two propaganda posters, which are the company talking and hang anywhere
  static var POOL_HALL = [
    SIGN_EXIT, SIGN_DIRECTORY, POSTER_EYE, POSTER_MARCH,
    FIRE_EXT, FIRE_HOSE, FIRE_ALARM, EVAC_PLAN, EVAC_POINT,
    DEPT_BLOCK, DEPT_ARROW, DEPT_BAND];
  static var POOL_ROOM = [
    SIGN_PLATE, POSTER_EYE, POSTER_MARCH,
    PLATE_NUMBER, PLATE_NAME, PLATE_BRAILLE,
    NOTICE_MEMO, NOTICE_ROSTER, NOTICE_WARN,
    CERT_FRAMED, CERT_PLAQUE];

// every sign on the plate, merged into one mesh. returns how many hang, for __corp()
  public static function build(scene:Scene, m:Facility, ?area:game.AreaGame):Int
    {
      var high = CorpKitchen.high(m, area);
      var bufs = [for (sh in SHEETS) MeshBufTools.make()];
      var n = 0;
      var seen = new Map<Int, Bool>();
      // one projector screen per boardroom and no more, keyed on the room it hangs in
      var screened = new Map<Int, Bool>();
      // and the stretch of wall each reception's logo hangs on, which takes no framed art beside it
      var logos = new Map<Int, Bool>();
      for (c in CorpReception.logoClear(m))
        logos.set(key(m, c.col, c.row, c.dir), true);
      // and the security room's video wall
      for (c in CorpSecurity.videoClear(m))
        logos.set(key(m, c.col, c.row, c.dir), true);
      for (dir in 0...4)
        {
          // a run follows the WALL, so it advances along x for a wall in z and along z for one in x
          var sc = (dir < 2 ? 1 : 0);
          var sr = (dir < 2 ? 0 : 1);
          for (row in 0...m.h)
            for (col in 0...m.w)
              {
                if (seen.exists(key(m, col, row, dir)) ||
                    !hangs(m, col, row, dir, high))
                  continue;
                var len = 0;
                while (hangs(m, col + sc * len, row + sr * len, dir, high))
                  {
                    seen.set(key(m, col + sc * len, row + sr * len, dir), true);
                    len++;
                  }
                if (len < CorpStyle.SIGN_RUN_MIN)
                  continue;
                // ONE PANEL PER CorpStyle.SIGN_SPACING CELLS, spread (i + 0.5) / k the way
                // CorpLamps.lattice spreads a ceiling fixture — a short run still falls to one
                // panel on its own centre, which is where a sign centred on a wall belongs, and a
                // long corridor wall stops carrying exactly one lost in the middle of it.
                //
                // the compound picks its cell by what stands under the plate instead, and that is
                // a hazard-signage rule: a triangle is placed AT its hazard. Nothing in these two
                // sheets names a thing, so none of them has anywhere it would rather be
                var k = Math.ceil(len / CorpStyle.SIGN_SPACING);
                for (i in 0...k)
                  {
                    var at = Std.int((i + 0.5) * len / k);
                    var cc = col + sc * at;
                    var rr = row + sr * at;
                    if (logos.exists(key(m, cc, rr, dir)))
                      continue;
                    var slot = pick(m, cc, rr, len, screened);
                    quad(bufs[sheetOf(slot)], m, cc, rr, dir, slot);
                    n++;
                  }
              }
        }
      // AND THE ONE ON THE AISLE. A cubicle panel is a wall too, and the two sheets this pass
      // already owns are the only propaganda in the building — so an outward-looking panel face
      // takes one here, into the SAME buffer, for no draw call at all.
      //
      // IT USED TO BE AN 8% ROLL ON ANY FACE, which hung the company's poster half a metre from
      // one worker's nose as often as on the passage everybody walks down. WHICH faces are
      // eligible is the grid's answer and not a roll — a face looks at a desk, at the passage or
      // at masonry, and only the passage is the company's — but every eligible face taking one was
      // overboard the other way. CorpFurniture.panelPoster is the grid AND the thinning roll, and
      // it is the one predicate render.corp.CorpClutter asks before scattering on the same face,
      // so the two passes tell each other nothing and still never collide
      for (q in CorpFurniture.panels)
        for (side in 0...2)
          {
            if (!CorpFurniture.panelPoster(q, side))
              continue;
            panelPane(bufs, q, side);
            n++;
          }
      // AND THE ARCHIVE'S RUN ENDS, the side panel a run of cabinets or shelves shows its aisle —
      // the same two propaganda slots, into the same buffer. CorpFurniture.archEndPoster is the
      // split with CorpClutter's pinned paper, so the two never land on one side
      for (e in CorpFurniture.archEnds)
        {
          if (!CorpFurniture.archEndPoster(e))
            continue;
          endPane(bufs, e);
          n++;
        }
      // one mesh per sheet, and `add` drops an empty buffer, so a sheet no room on the plate
      // asked for costs nothing
      for (i in 0...SHEETS.length)
        FacilityGeom.add(scene, bufs[i], SHEETS[i].tex, true, false);
      return n;
    }

// one propaganda poster on one face of a cubicle panel, centred on the run.
//
// the two portrait/landscape slots are dealt off the panel's own seed so the same bay comes back
// with the same poster on every rebuild, and the size comes off the MEASURED aspect table the wall
// panes use — a poster is the same image whichever wall it is on
  static function panelPane(bufs:Array<MeshBuf>, q:CorpFurniture.CorpPanel, side:Int):Void
    {
      var slot = (FacilityModel.mix(q.seed ^ ((side + 1) * 1103515245)) & 1 == 0 ?
        POSTER_EYE : POSTER_MARCH);
      var b = bufs[sheetOf(slot)];
      var a = ASPECT[slot];
      var mx = CorpStyle.PANEL_POSTER_MAX;
      var w = (a >= 1 ? mx : mx * a) / 2;
      var hh = (a >= 1 ? mx / a : mx) / 2;
      var at = (q.alongX ? (q.x0 + q.x1) / 2 : (q.z0 + q.z1) / 2);
      // the band's own centre, dropped if the sheet's half height would ride the trim rail on top
      // of the panel — CorpClutter.face clamps its decals against the same three constants
      var y = CorpStyle.PARTITION_H * (CorpStyle.PANEL_LO + CorpStyle.PANEL_HI) / 2;
      var top = CorpStyle.PARTITION_H - CorpStyle.PARTITION_T - CorpStyle.PANEL_TOP_GAP - hh;
      if (y > top)
        y = top;
      var e = CorpStyle.PANEL_PROUD;
      if (q.alongX)
        {
          var z = (side == 0 ? q.z0 - e : q.z1 + e);
          pane(b, at - w, at + w, z, z, (side == 0 ? 0 : 1), y - hh, y + hh, slot);
          return;
        }
      var x = (side == 0 ? q.x0 - e : q.x1 + e);
      pane(b, x, x, at - w, at + w, (side == 0 ? 2 : 3), y - hh, y + hh, slot);
    }

// one propaganda poster on the side of an archive run's end unit: as big as the panel's poster and
// no wider than the side, centred across it, its top ARCH_END_TOP under the unit's
  static function endPane(bufs:Array<MeshBuf>, e:CorpFurniture.CorpArchEnd):Void
    {
      var slot = (e.seed & 1 == 0 ? POSTER_EYE : POSTER_MARCH);
      var a = ASPECT[slot];
      var mx = CorpStyle.PANEL_POSTER_MAX;
      var w = Math.min((a >= 1 ? mx : mx * a), e.a1 - e.a0 - 2 * CorpStyle.ARCH_END_EDGE);
      var hh = w / a / 2;
      var at = (e.a0 + e.a1) / 2;
      var y1 = Math.min(e.h - CorpStyle.ARCH_END_TOP, CorpStyle.ARCH_END_LO + 2 * hh);
      var p = e.p + (e.dir == 0 || e.dir == 2 ? -1 : 1) * CorpStyle.PANEL_PROUD;
      if (e.alongX)
        pane(bufs[sheetOf(slot)], p, p, at - w / 2, at + w / 2, e.dir, y1 - 2 * hh, y1, slot);
      else
        pane(bufs[sheetOf(slot)], at - w / 2, at + w / 2, p, p, e.dir, y1 - 2 * hh, y1, slot);
    }

// which panel this spot earns, off the surface it hangs in
  static function pick(m:Facility, col:Int, row:Int, len:Int, screened:Map<Int, Bool>):Int
    {
      var s = m.surf[row][col];
      var h = FacilityModel.mix((col * 668265263) ^ (row * 1103515245));
      // THE BOARDROOM IS THE ONE ROOM WITH A JOB, and the job is a wall to project onto: one
      // screen per room on a wall long enough to hang it, and charts on whatever is left. A
      // framed print over a boardroom table said the room was for looking at
      if (s == Surf.MEETING)
        {
          var r = roomAt(m, col, row);
          if (len >= CorpStyle.SCREEN_RUN_MIN &&
              !screened.exists(r))
            {
              screened.set(r, true);
              return POSTER_SCREEN;
            }
          return POSTER_CHART;
        }
      // an EXEC office keeps the print: it is the one room in the tower whose occupant chose what
      // hangs in it
      if (s == Surf.EXEC ||
          s == Surf.RECEPTION)
        return SIGN_ART;
      // and CIRCULATION takes the wayfinding, alternating so a corridor does not read as a row of
      // one thing. The lift lobby counts as circulation here — it is where somebody arriving looks
      if (s == Surf.CARPET ||
          s == Surf.LIFT)
        return POOL_HALL[h % POOL_HALL.length];
      // every other room: what is read by whoever works in it
      return POOL_ROOM[h % POOL_ROOM.length];
    }

// which room rect holds this cell, as its index in m.rooms, or -1. `screened` is keyed on it, so a
// boardroom that spans two wall runs still hangs exactly one screen
  static function roomAt(m:Facility, col:Int, row:Int):Int
    {
      for (i in 0...m.rooms.length)
        {
          var r = m.rooms[i];
          if (col >= r.x1 &&
              col <= r.x2 &&
              row >= r.y1 &&
              row <= r.y2)
            return i;
        }
      return -1;
    }

// can a sign hang on the `dir` wall of this cell: INDOOR floor looking at plain masonry whose wall
// line carries on past it both ways.
//
// the carries-both-ways half is FacilityKit.wall's rule and is here for its reason: FacilityGeom
// .slab insets a face by a unit wherever the wall line STOPS at that cell, so on the last cell of a
// run the masonry shows three units of a four-unit cell and a quad centred on the cell would hang
// past the end of the wall it is bolted to.
//
// CorpStyle.SIGN_Y 4.6 hangs it clear of a server rack (RACK_H 4.0), but a sign 2.1 tall reaches
// down to 3.55, and the staff kitchen stands taller things on walkable floor: `high` is
// render.corp.CorpKitchen.high's cells, the vending machine, the fridge and the wall cabinets
  static function hangs(m:Facility, col:Int, row:Int, dir:Int, high:Map<Int, Bool>):Bool
    {
      if (!FacilityModel.inside(m, col, row) ||
          !FacilityModel.isInterior(m, col, row) ||
          FacilityModel.isWall(m, col, row) ||
          high.exists(CorpKitchen.key(m, col, row)) ||
          m.table[row][col] ||
          m.fit[row][col] != 0)
        return false;
      var c = col + DC[dir];
      var r = row + DR[dir];
      if (!FacilityModel.isSolidWall(m, c, r))
        return false;
      var sc = (dir < 2 ? 1 : 0);
      var sr = (dir < 2 ? 0 : 1);
      return FacilityGeom.carries(m, c - sc, r - sr) &&
        FacilityGeom.carries(m, c + sc, r + sr);
    }

// one cell's slot in a claimed-cell set, PER DIRECTION: a cell in a room corner has masonry on two
// hands and each is its own run
  static inline function key(m:Facility, col:Int, row:Int, dir:Int):Int
    {
      return ((dir * m.h + row) * m.w) + col;
    }

// one sign on the masonry beside (col,row), SIGN_PROUD clear of the wall face and centred on the
// cell. the plane is the SLAB's face and never the cell boundary — a corp wall slab is a unit
// inside its cell, and a quad on the boundary hangs in mid-air
  static function quad(b:MeshBuf, m:Facility, col:Int, row:Int, dir:Int, sign:Int):Void
    {
      var s = FacilityGeom.slab(m, col + DC[dir], row + DR[dir]);
      var a = ASPECT[sign];
      // a projector screen is not a plate and takes its own longest edge
      var mx = (sign == POSTER_SCREEN ? CorpStyle.SCREEN_MAX : CorpStyle.SIGN_MAX);
      var w = (a >= 1 ? mx : mx * a) / 2;
      var hh = (a >= 1 ? mx / a : mx) / 2;
      var c = CityConfig.cellToWorld(col, row);
      var y0 = CorpStyle.SIGN_Y - hh;
      var y1 = CorpStyle.SIGN_Y + hh;
      // the face looks BACK at the cell the sign is read from, so it is the opposite of the side
      // the masonry is on
      var d = dir ^ 1;
      var e = CorpStyle.SIGN_PROUD;
      if (d < 2)
        {
          var z = (d == 0 ? s.z0 - e : s.z1 + e);
          pane(b, c.x - w, c.x + w, z, z, d, y0, y1, sign);
          return;
        }
      var x = (d == 2 ? s.x0 - e : s.x1 + e);
      pane(b, x, x, c.z - w, c.z + w, d, y0, y1, sign);
    }

// which sheet a slot is on, as an index into SHEETS.
//
// the cumulative bases are WALKED and not stored: three sheets, and a base table that has to be
// kept in step with SHEETS by hand is a second place to get it wrong
  static function sheetOf(slot:Int):Int
    {
      var base = 0;
      for (i in 0...SHEETS.length)
        {
          base += SHEETS[i].cells;
          if (slot < base)
            return i;
        }
      return SHEETS.length - 1;
    }

// one upright quad wearing one cell of one sheet
  static function pane(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, dir:Int, y0:Float,
      y1:Float, i:Int):Void
    {
      var e = FacilityGeom.ends(x0, x1, z0, z1, dir);
      // the cell within THIS slot's own sheet, as its column and row in reading order. v is
      // flipped because a uv origin is the BOTTOM-left and reading order starts at the top
      var sheet = sheetOf(i);
      var sh = SHEETS[sheet];
      var q = i;
      for (k in 0...sheet)
        q -= SHEETS[k].cells;
      var cw = 1 / sh.cols;
      // and one cell's height is cols / cells, which is 1 / rows without naming rows
      var ch = sh.cols / sh.cells;
      var u0 = (q % sh.cols) * cw;
      var v0 = 1 - (Std.int(q / sh.cols) + 1) * ch;
      var u1 = u0 + cw;
      var v1 = v0 + ch;
      MeshBufTools.quad(b,
        [e[0], y0, e[1]], [e[2], y0, e[3]], [e[2], y1, e[3]], [e[0], y1, e[1]],
        [u0, v0, u1, v0, u1, v1, u0, v1]);
    }
}
