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
class CorpSigns
{
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

  // TWO ATLASES, four quadrants each, in reading order: 0 top-left, 1 top-right, 2 bottom-left,
  // 3 bottom-right. Slots 0-3 are `corp/signs` and slots 4-7 are `corp/posters`, so a slot alone
  // says which sheet it is on — see `quad`
  static inline var SIGN_EXIT = 0;       // green running man, circulation only
  static inline var SIGN_DIRECTORY = 1;  // smoked-glass floor listing, circulation only
  static inline var SIGN_PLATE = 2;      // brushed room plate, every other room
  static inline var SIGN_ART = 3;        // framed print, the rooms that would have one
  static inline var POSTER_EYE = 4;      // propaganda, portrait: an eye in a ring
  static inline var POSTER_MARCH = 5;    // propaganda, landscape: the one out of step
  static inline var POSTER_CHART = 6;    // a falling performance chart, the boardroom's
  static inline var POSTER_SCREEN = 7;   // a pulled-down projector screen, one per boardroom

  // each panel's own width:height, MEASURED off the built sheets' crops and not chosen — see the
  // class header and art/textures.json's notes on corp/signs and corp/posters
  static var ASPECT = [1.6553, 0.7038, 1.0400, 1.5034, 0.6987, 1.8139, 1.4000, 1.2632];

// every sign on the plate, merged into one mesh. returns how many hang, for __corp()
  public static function build(scene:Scene, m:Facility):Int
    {
      var b = MeshBufTools.make();
      var bp = MeshBufTools.make();
      var n = 0;
      var seen = new Map<Int, Bool>();
      // one projector screen per boardroom and no more, keyed on the room it hangs in
      var screened = new Map<Int, Bool>();
      for (dir in 0...4)
        {
          // a run follows the WALL, so it advances along x for a wall in z and along z for one in x
          var sc = (dir < 2 ? 1 : 0);
          var sr = (dir < 2 ? 0 : 1);
          for (row in 0...m.h)
            for (col in 0...m.w)
              {
                if (seen.exists(key(m, col, row, dir)) ||
                    !hangs(m, col, row, dir))
                  continue;
                var len = 0;
                while (hangs(m, col + sc * len, row + sr * len, dir))
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
                    var slot = pick(m, cc, rr, len, screened);
                    quad(slot < 4 ? b : bp, m, cc, rr, dir, slot);
                    n++;
                  }
              }
        }
      // AND THE ONE ON THE AISLE. A cubicle panel is a wall too, and the two sheets this pass
      // already owns are the only propaganda in the building — so an outward-looking panel face
      // takes one here, into the SAME buffer, for no draw call at all.
      //
      // IT USED TO BE AN 8% ROLL ON ANY FACE, which hung the company's poster half a metre from
      // one worker's nose as often as on the passage everybody walks down. A face looks either at
      // a desk or at the aisle (CorpFurniture.podFace) and that is the whole split: the desk side
      // is his and render.corp.CorpClutter dresses it, the aisle side is the company's and is
      // this. Neither pass tells the other anything — they both ask the grid
      for (q in CorpFurniture.panels)
        for (side in 0...2)
          {
            if (CorpFurniture.podFace(q, side) ||
                !aisle(m, q, side))
              continue;
            panelPane(bp, q, side);
            n++;
          }
      FacilityGeom.add(scene, b, CorpStyle.SIGN_TEX, true, false);
      FacilityGeom.add(scene, bp, CorpStyle.POSTER_TEX, true, false);
      return n;
    }

// does this face of a panel look at floor somebody can actually walk on?
//
// NOT THE SAME QUESTION AS `podFace`, and the difference is the block that backs onto masonry: a
// face is "not a desk" whether the cell beyond it is the aisle, a room wall or a fitting, and only
// the first is worth a poster. The cell is derived rather than carried — a panel stands on a cell
// BOUNDARY, so the neighbour on either hand is half a cell off its centre along the short axis
  static function aisle(m:Facility, q:CorpFurniture.CorpPanel, side:Int):Bool
    {
      var d = (side == 0 ? -CityConfig.CELL / 2 : CityConfig.CELL / 2);
      var cx = (q.x0 + q.x1) / 2;
      var cz = (q.z0 + q.z1) / 2;
      var c = CityConfig.worldToCell(q.alongX ? cx : cx + d, q.alongX ? cz + d : cz);
      return FacilityModel.inside(m, c.col, c.row) &&
        !FacilityModel.isWall(m, c.col, c.row) &&
        !m.table[c.row][c.col] &&
        m.fit[c.row][c.col] == 0;
    }

// one propaganda poster on one face of a cubicle panel, centred on the run.
//
// the two portrait/landscape slots are dealt off the panel's own seed so the same bay comes back
// with the same poster on every rebuild, and the size comes off the MEASURED aspect table the wall
// panes use — a poster is the same image whichever wall it is on
  static function panelPane(b:MeshBuf, q:CorpFurniture.CorpPanel, side:Int):Void
    {
      var slot = (FacilityModel.mix(q.seed ^ ((side + 1) * 1103515245)) & 1 == 0 ?
        POSTER_EYE : POSTER_MARCH);
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
      if (s == Surf.EXEC)
        return SIGN_ART;
      // and CIRCULATION takes the wayfinding, alternating so a corridor does not read as a row of
      // one thing. The lift lobby counts as circulation here — it is where somebody arriving looks
      if (s == Surf.CARPET ||
          s == Surf.LIFT)
        return [SIGN_EXIT, SIGN_DIRECTORY, POSTER_EYE, POSTER_MARCH][h % 4];
      // every other room: the plate that says which room it is, or the company reminding whoever
      // works in it what is expected
      return [SIGN_PLATE, SIGN_PLATE, POSTER_EYE, POSTER_MARCH][h % 4];
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
// AND NO CLAIMED-CELL LIST, the one thing separating this from every family that STANDS against a
// wall: CorpStyle.SIGN_Y 4.6 hangs it clear of the tallest thing that can share the cell (a server
// rack at RACK_H 4.0), so the collision question simply does not arise up here
  static function hangs(m:Facility, col:Int, row:Int, dir:Int):Bool
    {
      if (!FacilityModel.inside(m, col, row) ||
          !FacilityModel.isInterior(m, col, row) ||
          FacilityModel.isWall(m, col, row) ||
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

// one upright quad wearing one 2x2 quadrant
  static function pane(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, dir:Int, y0:Float,
      y1:Float, i:Int):Void
    {
      var e = FacilityGeom.ends(x0, x1, z0, z1, dir);
      // the quadrant within THIS slot's own sheet — the high bit picked the sheet in `build`
      var q = i & 3;
      var u0 = (q & 1) * 0.5;
      var v0 = (q < 2 ? 0.5 : 0.0);
      var u1 = u0 + 0.5;
      var v1 = v0 + 0.5;
      MeshBufTools.quad(b,
        [e[0], y0, e[1]], [e[2], y0, e[3]], [e[2], y1, e[3]], [e[0], y1, e[1]],
        [u0, v0, u1, v0, u1, v1, u0, v1]);
    }
}
