package render.facility;

import three.Three;
import citygen.CityConfig;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;

// the safety placards on a lab ROOM's walls, one per run of masonry.
//
// this is the surface the whole interior phase was aimed at. measured on a pinned pose, a room wall
// is 10.25% of the frame and a room floor 12.05%, and of the two the wall carried NOTHING but the
// damp band: the exit signage is Surf.LINO-gated so it is corridors only, the notice board is one per
// front entrance, and the fire points and panels are corridor fittings too. Every family in the
// compound was hung in the circulation and none of them ever reached a room.
//
// A TEXTURE AND NOT A PROP, which is the silhouette-vs-surface guard read the way the notice board
// reads it: a sign plate's outline is a rectangle and there is no silhouette in it to pay triangles
// for, while everything that says "hazard placard" rather than "grey square" is a PICTOGRAM on its
// face. So it is one quad and one atlas cell, and the family costs one draw call per SHEET however
// many stand.
//
// ONE PER RUN AND NEVER PER CELL. a run here is a stretch of room floor hugging unbroken solid
// masonry — a placard every cell turns a wall into a strip of stickers. The doorway is what ends a
// run at all: a door cell is not isSolidWall, so a wall with an opening in it is two runs and takes
// two signs, which is where a real pair is.
//
// AND THE SIGN NAMES WHAT IS UNDER IT. The first build rolled the pictogram off a cell hash and hung
// a biohazard triangle over a bookcase; this one walks the run, finds the loudest thing standing
// against that wall and puts the sign over THAT cell. It works because the content is wall-hugging
// by construction: game.FacilityAreaGenerator.makeWindows stamps every bench and every fitting on
// the interior cell directly against the wall line, and that wall alternates window run and plain
// masonry, so about half of what a room holds sits under exactly the masonry a placard needs.
// Measured on the shipped seed: all 30 runs find something, spread six ways — where the middle cell
// alone gave eye protection 13 times and 11 runs with nothing to say at all.
//
// DERIVED AND NOT PERSISTED, the contract the whole facility render layer runs on. Everything the
// pick reads (Facility.deco, table, drain, surf) comes off the saved grid and the decoration objects
// already in every save. A room ROLE written at generation time would be null on every compound
// already saved, and the facility generator types no rooms at all — game.FacilityAreaGenerator
// .generateRoomContents makes every one of them a chemistry lab
//
// AND IT NEEDS NO CLAIMED-CELL LIST, which is the one thing separating it from every other family
// that stands against a wall. FacilityStyle.PLACARD_Y hangs it clear of the tallest thing that can
// share the cell (FacilityStyle.DECO_CABINET_H 3.43), so the collision question the fire points had
// to answer against FacilityTables.runs simply does not arise up here
class FacilityPlacard
{
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

  // the eight pictograms, as one index across the PAIR of 2x2 sheets: the sheet is
  // index / FacilityStyle.PLACARD_CELLS and the cell in it index % PLACARD_CELLS. Sheet A holds the
  // three the first drop got right plus the prohibition that replaced its no-entry plate — a no-entry
  // sign is a DOOR sign, it had nothing that could ever trigger it, and it was 11 of the 30
  static inline var SIGN_BIO = 0;        // A, top left
  static inline var SIGN_LASER = 1;      // A, top right
  static inline var SIGN_NO_FOOD = 2;    // A, bottom left
  static inline var SIGN_EYE = 3;        // A, bottom right
  static inline var SIGN_RAD = 4;        // B, top left
  static inline var SIGN_ELEC = 5;       // B, top right
  static inline var SIGN_CORROSIVE = 6;  // B, bottom left
  static inline var SIGN_GLOVES = 7;     // B, bottom right

  // how loudly each sign wants its run, lower first. THE SIGNAGE RULE AND NOT A TASTE CALL: a hazard
  // triangle is placed AT its hazard, so a drum two cells along the wall outbids a bench directly
  // under the sign, while a mandatory blue disc is a ROOM rule and is honest anywhere — which is what
  // makes it the right answer for the storage majority no hazard pictogram can name
  static var PRIO = [0, 1, 3, 3, 0, 1, 0, 2];

  // which sign a piece of room furniture earns, indexed by _FittingKind and IN ITS ORDER — a kind
  // added to that enum without a row here falls off the end of this table and `classOf` reads the
  // cell as bare. see Const.FACILITY_DECO for what each one actually draws as
  static var KIND_SIGN = [
    SIGN_GLOVES,     // FIT_SHELVING: open metal shelving of boxes
    SIGN_GLOVES,     // FIT_BOOKCASE: a case of books and bottles
    SIGN_ELEC,       // FIT_RACK: a server rack, and the one fitting carrying its own lights
    SIGN_ELEC,       // FIT_RACK_LOW: the same cabinet one tile tall
    SIGN_GLOVES,     // FIT_CABINET: fridge, freezer, storage and safety cases, one silhouette
    SIGN_LASER,      // FIT_MACHINE: hopper, analyser, CNC enclosure, press, lathe
    SIGN_LASER,      // FIT_MACHINE_LOW: the same casing knee-high
    SIGN_CORROSIVE,  // FIT_DRUM_STEEL: grey drum, yellow hazard triangle
    SIGN_BIO,        // FIT_DRUM_BIO: yellow drum, biohazard trefoil
    SIGN_RAD,        // FIT_DRUM_RAD: red drum, radiation trefoil
    SIGN_GLOVES,     // FIT_BIN: a lidded waste bin
  ];

// every placard in the compound, merged into one mesh PER SHEET. returns how many went in, for
// __facility()
  public static function build(scene:Scene, m:Facility):Int
    {
      var b = [MeshBufTools.make(), MeshBufTools.make()];
      var n = 0;
      var seen = new Map<Int, Bool>();
      for (dir in 0...4)
        {
          // a run follows the WALL, so it advances along x for a wall in z and along z for one in x —
          // FacilityTables.runs' own walk, which this cannot call: that one is LINO-gated and rolls
          // the casework's CASE_PCT, and a room is exactly what it refuses
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
                if (len < FacilityStyle.PLACARD_RUN_MIN)
                  continue;
                var p = pick(m, col, row, dir, len);
                quad(b[Std.int(p.sign / FacilityStyle.PLACARD_CELLS)], m,
                  col + sc * p.at, row + sr * p.at, dir, p.sign);
                n++;
              }
        }
      FacilityGeom.add(scene, b[0], FacilityStyle.PLACARD_TEX, true, false);
      FacilityGeom.add(scene, b[1], FacilityStyle.PLACARD_TEX2, true, false);
      return n;
    }

// can a placard hang on the `dir` wall of this cell: ROOM floor looking at plain masonry whose wall
// line carries on past it both ways.
//
// Surf.TILE and not isIndoor is the whole gate, and it is the one FacilityKit already runs on: lino
// is the corridor, where the signage and the fittings live, and concrete is the hangar. that split is
// also what keeps this family off every corridor family's wall with no check against any of them.
//
// the carries-both-ways half is FacilityKit.wall's rule and is here for FacilityPoint's reason:
// FacilityGeom.slab insets a face by a unit wherever the wall line STOPS at that cell, so on the last
// cell of a run the masonry shows 3 units of a 4-unit cell and a PLACARD_W quad centred on the cell
// would hang past the end of the wall it is bolted to.
//
// PUBLIC because render.facility.FacilityCable's panels want the same three facts and a third copy of
// this test is a third place to get the carries-both-ways half wrong. It is a pure function of the
// saved grid, so either family may run first — FacilityPoint.places' own discipline
// `office` widens the surface gate to a researcher's office as well, and ONLY the electrical family
// passes it: an office is a room with sockets and skirting runs in it like any other, but the eight
// plates on the two sheets here are laboratory hazard signage — a biohazard trefoil over a desk is
// the exact failure the Surf.TILE gate exists to prevent
  public static function hangs(m:Facility, col:Int, row:Int, dir:Int, ?office:Bool):Bool
    {
      if (!FacilityModel.inside(m, col, row))
        return false;
      var s = m.surf[row][col];
      if (s != Surf.TILE &&
          !(office == true && s == Surf.OFFICE))
        return false;
      if (!FacilityModel.isSolidWall(m, col + DC[dir], row + DR[dir]))
        return false;
      var c = col + DC[dir];
      var r = row + DR[dir];
      var sc = (dir < 2 ? 1 : 0);
      var sr = (dir < 2 ? 0 : 1);
      return FacilityGeom.carries(m, c - sc, r - sr) &&
        FacilityGeom.carries(m, c + sc, r + sr);
    }

// which cell of a run takes the sign, and which sign it is. ONE walk answers both, because the two
// questions are the same question: the cell is picked BECAUSE of what stands on it.
//
// every cell is asked twice — what stands on the cell the plate would hang over, and then what stands
// one step further into the room behind it. the second is not a nicety: a bench run against the wall
// with a drum in the next row along is the commonest shape in these rooms, and the drum is the thing
// worth naming
  static function pick(m:Facility, col:Int, row:Int, dir:Int, len:Int):{ at:Int, sign:Int }
    {
      var sc = (dir < 2 ? 1 : 0);
      var sr = (dir < 2 ? 0 : 1);
      var mid = len >> 1;
      var at = mid;
      var sign = -1;
      var best = 1000;
      for (i in 0...len)
        {
          var d = (i > mid ? i - mid : mid - i);
          // BOTH probes are scored and the second is not a fallback for the first. asking behind only
          // when the cell itself is bare loses the drum every time, because the cell itself is a
          // BENCH: 6 of the 30 runs on the shipped seed are a bench against the wall with something
          // louder standing in the row behind it, and the bench was answering for all of them
          for (back in 0...2)
            {
              var s = classOf(m, col + sc * i - DC[dir] * back, row + sr * i - DR[dir] * back);
              if (s < 0)
                continue;
              // how loud the sign is, then whether the thing stands ON the cell or one step behind
              // it, then how far the cell is off the run's middle — one comparable number, and a run
              // is never long enough for the last term to reach into the second
              var score = PRIO[s] * 100 + back * 50 + d;
              if (score >= best)
                continue;
              best = score;
              at = i;
              sign = s;
            }
        }
      // a run with nothing standing along it at all still takes a plate, and a room rule is the sign
      // that is honest with nothing under it. measured 0 runs on the shipped seed, but a bare
      // compound is a compound this has never seen
      if (sign < 0)
        sign = bench(col + sc * mid, row + sr * mid);
      return {
        at: at,
        sign: sign,
      };
    }

// the sign one room cell earns, or -1 for a cell with nothing on it. a fitting first, then the
// chemistry the generator lays in every lab (an actual drain object, or the grate TILE that says
// where one could be), then the bench
  static function classOf(m:Facility, col:Int, row:Int):Int
    {
      if (!FacilityModel.inside(m, col, row))
        return -1;
      var k = m.deco[row][col] - 1;
      if (k >= 0 && k < KIND_SIGN.length)
        return KIND_SIGN[k];
      if (m.drain[row][col] ||
          m.surf[row][col] == Surf.GRATE)
        return SIGN_BIO;
      if (m.table[row][col])
        return bench(col, row);
      return -1;
    }

// which of the two room-rule discs a bench takes. rolled off the cell so a long wall of worktop does
// not carry the same plate three times — FacilityTables.runs' own three-term mix, since the bare
// (col * A) ^ (row * B) collapses to an arithmetic sequence on row 0 and column 0
  static inline function bench(col:Int, row:Int):Int
    {
      return (FacilityModel.mix((col * 374761393) ^ (row * 668265263) ^ 83492791) % 2 == 0
        ? SIGN_EYE : SIGN_NO_FOOD);
    }

// one cell's slot in a claimed-cell set, PER DIRECTION — FacilityTables.key's own layout, and claimed
// per direction for its reason: a cell in a corner of a room has masonry on two hands and each is its
// own run
  static inline function key(m:Facility, col:Int, row:Int, dir:Int):Int
    {
      return ((dir * m.h + row) * m.w) + col;
    }

// one placard on the masonry beside cell (col,row), MOUNT_PROUD clear of the wall face and centred on
// the cell. the plane is the SLAB's face and never the cell boundary, the same trap FacilityExit.quad,
// FacilityPoint.quad and FacilityTables.unit all take.
//
// no clamp to the slab along the wall, where the fire points need one: `hangs` has already rejected
// every cell the wall line stops at, so the masonry here always spans the full cell
  static function quad(b:MeshBuf, m:Facility, col:Int, row:Int, dir:Int, sign:Int):Void
    {
      var s = FacilityGeom.slab(m, col + DC[dir], row + DR[dir]);
      var e = FacilityStyle.MOUNT_PROUD;
      var h = FacilityStyle.PLACARD_W / 2;
      var c = CityConfig.cellToWorld(col, row);
      var y0 = FacilityStyle.PLACARD_Y - FacilityStyle.PLACARD_H / 2;
      var y1 = FacilityStyle.PLACARD_Y + FacilityStyle.PLACARD_H / 2;
      var i = sign % FacilityStyle.PLACARD_CELLS;
      // the face looks BACK at the cell the placard stands on, so it is the opposite of the side the
      // masonry is on
      var d = dir ^ 1;
      if (d < 2)
        {
          var z = (d == 0 ? s.z0 - e : s.z1 + e);
          pane(b, c.x - h, c.x + h, z, z, d, y0, y1, i);
          return;
        }
      var x = (d == 2 ? s.x0 - e : s.x1 + e);
      pane(b, x, x, c.z - h, c.z + h, d, y0, y1, i);
    }

// the ROOM SIGNS: one plate on the corridor wall beside a themed room's door.
//
// A SEPARATE PASS AND A SEPARATE SHEET, because it is the opposite of everything above it. The eight
// hazard plates hang INSIDE a laboratory, on the room's own side of the wall, chosen by what stands
// under them. These hang OUTSIDE, on the corridor side, chosen by what the room IS — which is the one
// question the corridor asks and the one the room's own signage never answers.
//
// a washroom gets TWO, one flanking each side of its door, and that is not decoration: it has two
// halves behind one opening (see game.FacilityAreaGenerator.toiletPartition), and a pair of plates
// either side of the door is exactly how a shared entrance to both says so
  public static function rooms(scene:Scene, m:Facility):Int
    {
      var b = MeshBufTools.make();
      var n = 0;
      for (d in m.doors)
        {
          var dc = d.alongX ? 0 : 1;
          var dr = d.alongX ? 1 : 0;
          var s = surfOfRoom(m, d.col + dc * d.inDir, d.row + dr * d.inDir);
          if (s < 0)
            continue;
          // the corridor side of the wall line, and the face on it that looks back down the corridor
          var face = (d.alongX ? (d.inDir > 0 ? 1 : 0) : (d.inDir > 0 ? 3 : 2));
          var sc = (d.alongX ? 1 : 0);
          var sr = (d.alongX ? 0 : 1);
          var wash = (s == Surf.WASH);
          var put = 0;
          for (k in 0...2)
            {
              var side = (k == 0 ? -1 : 1);
              // the masonry the plate is bolted to, and the corridor cell it hangs over
              var wc = d.col + sc * side, wr = d.row + sr * side;
              var cc = wc - dc * d.inDir, cr = wr - dr * d.inDir;
              if (!FacilityModel.isSolidWall(m, wc, wr) ||
                  !FacilityModel.inside(m, cc, cr) ||
                  m.surf[cr][cc] != Surf.LINO)
                continue;
              var cell = (wash ? (put == 0 ? FacilityStyle.SIGN_MEN : FacilityStyle.SIGN_WOMEN) :
                (FacilityModel.mix((d.col * 374761393) ^ (d.row * 40503)) % 2 == 0 ?
                  FacilityStyle.SIGN_OFFICE_A : FacilityStyle.SIGN_OFFICE_B));
              sign(b, m, cc, cr, face, cell);
              put++;
              n++;
              // an office says its name once; a washroom names both its halves
              if (!wash)
                break;
            }
        }
      FacilityGeom.add(scene, b, FacilityStyle.SIGN_TEX, true, false);
      return n;
    }

// the themed surface of the room on the far side of a door, or -1 for anything else. off the FLOOR
// TILE like every other themed test in the compound, so it needs no generatorInfo and works on a
// grid saved before any of it existed
  static function surfOfRoom(m:Facility, col:Int, row:Int):Int
    {
      if (!FacilityModel.inside(m, col, row))
        return -1;
      var s = m.surf[row][col];
      return (s == Surf.OFFICE || s == Surf.WASH ? s : -1);
    }

// one room sign, on the slab face of the masonry at (col,row)'s `dir` hand and MOUNT_PROUD clear of
// it — `quad`'s own geometry at this family's own size
  static function sign(b:MeshBuf, m:Facility, col:Int, row:Int, dir:Int, cell:Int):Void
    {
      var s = FacilityGeom.slab(m, col + DC[dir], row + DR[dir]);
      var e = FacilityStyle.MOUNT_PROUD;
      var h = FacilityStyle.SIGN_W / 2;
      var c = CityConfig.cellToWorld(col, row);
      var y0 = FacilityStyle.SIGN_Y - FacilityStyle.SIGN_H / 2;
      var y1 = FacilityStyle.SIGN_Y + FacilityStyle.SIGN_H / 2;
      var d = dir ^ 1;
      if (d < 2)
        {
          var z = (d == 0 ? s.z0 - e : s.z1 + e);
          pane(b, c.x - h, c.x + h, z, z, d, y0, y1, cell);
          return;
        }
      var x = (d == 2 ? s.x0 - e : s.x1 + e);
      pane(b, x, x, c.z - h, c.z + h, d, y0, y1, cell);
    }

// FacilityGeom.pane with the uv opened up to one cell of a 2x2 sheet. three flips y, so the source's
// TOP row is v 0.5..1: on either sheet cells 0 and 1 are the top pair and 2 and 3 the bottom one.
// derived from the index rather than named constant by constant because the sheet is a regular grid —
// see FacilityStyle.PLACARD_CELLS. everything else about the winding is that function's, through its
// own `ends`
  static function pane(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, dir:Int, y0:Float,
      y1:Float, i:Int):Void
    {
      var e = FacilityGeom.ends(x0, x1, z0, z1, dir);
      var u0 = (i & 1) * 0.5;
      var v0 = (i < 2 ? 0.5 : 0.0);
      var u1 = u0 + 0.5;
      var v1 = v0 + 0.5;
      MeshBufTools.quad(b,
        [e[0], y0, e[1]], [e[2], y0, e[3]], [e[2], y1, e[3]], [e[0], y1, e[1]],
        [u0, v0, u1, v0, u1, v1, u0, v1]);
    }
}
