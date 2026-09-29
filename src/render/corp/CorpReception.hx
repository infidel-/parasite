package render.corp;

import citygen.CityConfig;
import render.Models;
import render.facility.FacilityDetail;
import render.facility.FacilityGeom;
import render.facility.FacilityGeom.Rect;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.MeshBuf;

// one reception counter: a straight run of counter cells in the wall line, and the hand the
// corridor is on
typedef ReceptionRun = {
  // the run's first cell (lowest col/row) and how many cells it covers
  var col:Int;
  var row:Int;
  var len:Int;
  // whether the run goes along x (a counter in a top or bottom wall)
  var alongX:Bool;
  // the hand the CORRIDOR is on, in FacilityGeom.DC / DR's numbering; the room is `out ^ 1`
  var out:Int;
};

// one desk-clutter decal on a counter, for render.corp.CorpClutter to emit into its desk sheet
typedef ReceptionDecal = {
  // its centre in world, and the top it lies on
  var x:Float;
  var z:Float;
  var y:Float;
  // its turn, and its cell of corp/desk-clutter
  var yaw:Float;
  var idx:Int;
};

// what every counter on the plate carries, one list per glb and one of decals
typedef ReceptionDress = {
  var phones:Array<Models.PropPlace>;
  var boards:Array<Models.PropPlace>;
  var bells:Array<Models.PropPlace>;
  // corp/desk-plant, which render.corp.CorpClutter already batches for the desks
  var plants:Array<Models.PropPlace>;
  var decals:Array<ReceptionDecal>;
};

// THE RECEPTION COUNTER, off the generator's own cells.
//
// gen.corp.CorpRooms.counter lays Const.TILE_CORP_RECEPTION_COUNTER over the reception's whole wall
// onto the corridor, corner post to corner post. CorpModel reads that id as FLOOR with a fitting on
// it (Wall.OPEN, Surf.RECEPTION, CorpFurniture.FIT_COUNTER) and NOT as a wall, which is what makes
// the opening an opening: each corner post sees open floor beside it and ends the partition with a
// full-height face of its own, the vision mask sees over the counter with no predicate touched, and
// the floor runs through under it. A wall value would have had the posts carry on into it and emit
// no end at all — a hole in the masonry up to the ceiling.
//
// A PURE FUNCTION OF THE MODEL, like every pass on this plate: CorpFurniture emits the body,
// CorpProps seats the receptionist, and neither depends on the other having run
class CorpReception
{
  static inline var CELL = CityConfig.CELL;

// is this a counter cell
  public static inline function cell(m:Facility, col:Int, row:Int):Bool
    {
      return FacilityModel.inside(m, col, row) &&
        m.fit[row][col] == CorpFurniture.FIT_COUNTER;
    }

// every counter run on the plate. the corridor's hand is the one that is NOT inside a room rect,
// which a counter's two long sides always split between them; with no room on either (the warm's
// demo model) it takes -z or -x, which only has to emit something
  public static function runs(m:Facility):Array<ReceptionRun>
    {
      var out = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!cell(m, col, row) ||
                cell(m, col - 1, row) ||
                cell(m, col, row - 1))
              continue;
            var alongX = cell(m, col + 1, row);
            var len = 1;
            while (cell(m, col + (alongX ? len : 0), row + (alongX ? 0 : len)))
              len++;
            // a run of one could go either way; it goes along x unless a wall carries on down z
            if (len == 1 &&
                FacilityModel.isWall(m, col, row - 1))
              alongX = false;
            var side = (alongX ? 0 : 2);
            var r = side;
            if (inRoom(m, col + FacilityGeom.DC[side], row + FacilityGeom.DR[side]))
              r = side + 1;
            out.push({
              col: col,
              row: row,
              len: len,
              alongX: alongX,
              out: r,
            });
          }
      return out;
    }

// is this cell inside one of the model's room rects
  static function inRoom(m:Facility, col:Int, row:Int):Bool
    {
      for (r in m.rooms)
        if (col >= r.x1 &&
            col <= r.x2 &&
            row >= r.y1 &&
            row <= r.y2)
          return true;
      return false;
    }

// emit every counter's body into render.corp.CorpFurniture's buffers, keyed by texture like the rest
// of the fittings, so the marble costs a draw call per sheet and nothing per counter
  public static function build(m:Facility):Int
    {
      var rs = runs(m);
      for (r in rs)
        {
          body(m, r);
          logo(m, r);
        }
      return rs.length;
    }

// THE COMPANY'S NAME ON THE WALL THE COUNTER FACES, as one 0..1 pane: what a visitor reads over the
// receptionist's head. Hung on the wall straight across the room from the counter's middle, or the
// nearest cell of that wall that is masonry — glazing and a doorway carry nothing
  static function logo(m:Facility, r:ReceptionRun):Void
    {
      var w = logoCell(m, r);
      if (w == null)
        return;
      var f = FacilityGeom.plane(FacilityGeom.slab(m, w.col, w.row), r.out,
        CorpStyle.REC_LOGO_PROUD);
      var c = CityConfig.cellToWorld(w.col, w.row);
      var half = CorpStyle.REC_LOGO_W / 2;
      var alongX = (r.out < 2);
      FacilityGeom.pane(CorpFurniture.buf(CorpStyle.RECEPTION_LOGO),
        (alongX ? c.x - half : f.x0), (alongX ? c.x + half : f.x1),
        (alongX ? f.z0 : c.z - half), (alongX ? f.z1 : c.z + half),
        r.out, CorpStyle.REC_LOGO_Y0,
        CorpStyle.REC_LOGO_Y0 + CorpStyle.REC_LOGO_W / CorpStyle.RECEPTION_LOGO_ASPECT);
    }

// the masonry cell the logo hangs on: straight across the room from the counter's middle to the
// wall line, then along it to the nearest SOLID cell, or null where there is none
  static function logoCell(m:Facility, r:ReceptionRun):{ col:Int, row:Int }
    {
      var k = Std.int(r.len / 2);
      var col = r.col + (r.alongX ? k : 0);
      var row = r.row + (r.alongX ? 0 : k);
      var dc = FacilityGeom.DC[r.out ^ 1];
      var dr = FacilityGeom.DR[r.out ^ 1];
      do
        {
          col += dc;
          row += dr;
        }
      // THE WALL LINE AND NOT A WALL: a doorway is a hole in the line, and a walk that asked for
      // masonry went straight out through the reception's own staff door and hung the logo on the
      // far wall of the room next door
      while (FacilityModel.inside(m, col, row) &&
        !FacilityGeom.carries(m, col, row));
      for (i in 0...3)
        for (s in [1, -1])
          {
            var c = col + (r.alongX ? s * i : 0);
            var w = row + (r.alongX ? 0 : s * i);
            if (FacilityModel.isSolidWall(m, c, w))
              return {
                col: c,
                row: w,
              };
          }
      return null;
    }

// the room cells along each logo's wall that the tower's framed art keeps off, as (col, row) with
// the hand the wall is on — render.corp.CorpSigns asks before it hangs a panel there
  public static function logoClear(m:Facility):Array<{ col:Int, row:Int, dir:Int }>
    {
      var out = [];
      for (r in runs(m))
        {
          var w = logoCell(m, r);
          if (w == null)
            continue;
          var dir = r.out ^ 1;
          for (i in -CorpStyle.REC_LOGO_CLEAR...CorpStyle.REC_LOGO_CLEAR + 1)
            out.push({
              col: w.col - FacilityGeom.DC[dir] + (r.alongX ? i : 0),
              row: w.row - FacilityGeom.DR[dir] + (r.alongX ? 0 : i),
              dir: dir,
            });
        }
      return out;
    }

// one counter: the tall body with its ledge on the corridor side, and the worktop on the room side.
// Where its ends meet masonry — the corner posts, every time on a generated floor — it runs to
// that masonry's own face and shows no end of its own
  static function body(m:Facility, r:ReceptionRun):Void
    {
      var v = span(m, r);
      var d = r.out;
      var back = d ^ 1;
      // the two hands along the run, and whether each is open (no masonry to butt)
      var e0 = (r.alongX ? 2 : 0);
      var open0 = !endWall(m, r, false);
      var open1 = !endWall(m, r, true);
      var bodyTop = CorpStyle.REC_LEDGE_H - CorpStyle.REC_LEDGE_T;
      var workTop = CorpStyle.DESK_H;
      var workBot = workTop - CorpStyle.REC_WORK_T;
      var t = CorpStyle.REC_TILE;
      var front = CorpFurniture.buf(CorpStyle.RECEPTION_FRONT);
      var top = CorpFurniture.buf(CorpStyle.RECEPTION_TOP);
      var oak = CorpFurniture.buf(CorpStyle.COUNTER_FRONT);

      // the BODY, floor to the ledge's underside
      var b = rect(r, v, CorpStyle.REC_BACK_U, CorpStyle.REC_FRONT_U);
      FacilityGeom.face(front, b.x0, b.x1, b.z0, b.z1, d, 0.0, bodyTop, t);
      // its room face in two strips, under the worktop and over it
      FacilityGeom.face(oak, b.x0, b.x1, b.z0, b.z1, back, 0.0, workBot, t);
      FacilityGeom.face(oak, b.x0, b.x1, b.z0, b.z1, back, workTop, bodyTop, t);
      ends(front, b, e0, open0, open1, 0.0, bodyTop, t);

      // the LEDGE: its top, the overhang's underside, and its edges
      var l = rect(r, v, CorpStyle.REC_BACK_U, CorpStyle.REC_FRONT_U + CorpStyle.REC_LEDGE_OVER);
      var over = rect(r, v, CorpStyle.REC_FRONT_U, CorpStyle.REC_FRONT_U + CorpStyle.REC_LEDGE_OVER);
      FacilityGeom.cap(top, l.x0, l.x1, l.z0, l.z1, CorpStyle.REC_LEDGE_H, t);
      FacilityGeom.capDown(top, over.x0, over.x1, over.z0, over.z1, bodyTop, t);
      FacilityGeom.face(front, l.x0, l.x1, l.z0, l.z1, d, bodyTop, CorpStyle.REC_LEDGE_H, t);
      FacilityGeom.face(front, l.x0, l.x1, l.z0, l.z1, back, bodyTop, CorpStyle.REC_LEDGE_H, t);
      ends(front, l, e0, open0, open1, bodyTop, CorpStyle.REC_LEDGE_H, t);

      // the WORKTOP, a slab off the body's room face with nothing under it but the knee space
      var w = rect(r, v, CorpStyle.REC_WORK_U, CorpStyle.REC_BACK_U);
      FacilityGeom.cap(top, w.x0, w.x1, w.z0, w.z1, workTop, t);
      FacilityGeom.capDown(top, w.x0, w.x1, w.z0, w.z1, workBot, t);
      FacilityGeom.face(front, w.x0, w.x1, w.z0, w.z1, back, workBot, workTop, t);
      ends(front, w, e0, open0, open1, workBot, workTop, t);

      // and its contact: the body and the worktop's shadow on the floor, and a halo up each post
      FacilityDetail.ground(m, {
        col: r.col,
        row: r.row,
        len: r.len,
        alongX: r.alongX,
        rect: rect(r, v, CorpStyle.REC_WORK_U, CorpStyle.REC_FRONT_U),
        h: CorpStyle.REC_LEDGE_H,
      });
    }

// the end faces of one box, on whichever of its two run ends is open
  static function ends(b:MeshBuf, r:Rect, e0:Int, open0:Bool, open1:Bool, y0:Float, y1:Float,
      t:Float):Void
    {
      if (open0)
        FacilityGeom.face(b, r.x0, r.x1, r.z0, r.z1, e0, y0, y1, t);
      if (open1)
        FacilityGeom.face(b, r.x0, r.x1, r.z0, r.z1, e0 + 1, y0, y1, t);
    }

// is there masonry past this end of the run
  static function endWall(m:Facility, r:ReceptionRun, far:Bool):Bool
    {
      var c = endCell(r, far);
      return FacilityModel.isWall(m, c.col, c.row);
    }

// the cell just past one end of the run
  static function endCell(r:ReceptionRun, far:Bool):{ col:Int, row:Int }
    {
      var k = (far ? r.len : -1);
      return {
        col: r.col + (r.alongX ? k : 0),
        row: r.row + (r.alongX ? 0 : k),
      };
    }

// the run's extent along its own axis, in world: cell boundary to cell boundary, and on into the
// cell past each end as far as that cell's masonry FACE where there is masonry. A corner post is
// thinner than the cell it stands in (FacilityGeom.slab), so stopping at the boundary left a gap
// of (CELL - thick) / 2 between the counter and the post it is set into
  static function span(m:Facility, r:ReceptionRun):{ v0:Float, v1:Float }
    {
      var a = CityConfig.cellToWorld(r.col, r.row);
      var lo = (r.alongX ? a.x : a.z) - CELL / 2;
      var hi = lo + r.len * CELL;
      var c0 = endCell(r, false);
      var c1 = endCell(r, true);
      if (endWall(m, r, false))
        lo -= CELL / 2 - FacilityGeom.thick(m, c0.col, c0.row) / 2;
      if (endWall(m, r, true))
        hi += CELL / 2 - FacilityGeom.thick(m, c1.col, c1.row) / 2;
      return {
        v0: lo,
        v1: hi,
      };
    }

// a box's footprint in world: `v` along the run, and u0..u1 across it off the wall line, u positive
// toward the corridor
  static function rect(r:ReceptionRun, v:{ v0:Float, v1:Float }, u0:Float, u1:Float):Rect
    {
      var a = CityConfig.cellToWorld(r.col, r.row);
      var s = (r.alongX ? FacilityGeom.DR[r.out] : FacilityGeom.DC[r.out]);
      var c = (r.alongX ? a.z : a.x);
      var p0 = c + s * u0;
      var p1 = c + s * u1;
      var lo = (p0 < p1 ? p0 : p1);
      var hi = (p0 < p1 ? p1 : p0);
      return {
        x0: (r.alongX ? v.v0 : lo),
        x1: (r.alongX ? v.v1 : hi),
        z0: (r.alongX ? lo : v.v0),
        z1: (r.alongX ? hi : v.v1),
      };
    }

// WHAT EACH COUNTER CARRIES, laid out and not rolled: a front desk is arranged. On the visitor's
// LEDGE, the WELCOME board a cell in from the end nearer the lift (the side a visitor walks up
// from), a desk plant at the other end, the bell beside the middle, and the visitor book with its pen, the
// business cards and a lanyard badge lying on it. On the receptionist's WORKTOP, the phone beside
// the workstation, the sticky notes on the other side of it, and a second plant at the lift end on a
// counter long enough to have room for one. Every glb stands in a round contact on the top it stands on
  public static function dress(m:Facility):ReceptionDress
    {
      var out:ReceptionDress = {
        phones: [],
        boards: [],
        bells: [],
        plants: [],
        decals: [],
      };
      var lift = liftCell(m);
      for (r in runs(m))
        {
          var mid = Std.int(r.len / 2);
          // which end is the lift's, and the step along the run toward it
          var e0 = at(r, 0, 0.0);
          var e1 = at(r, r.len - 1, 0.0);
          var toward = (lift == null ||
            dist(e0, lift) <= dist(e1, lift) ? -1 : 1);
          var endA = (toward < 0 ? 0 : r.len - 1);
          var endB = r.len - 1 - endA;
          var ux = FacilityGeom.DC[r.out];
          var uz = FacilityGeom.DR[r.out];
          var toCorridor = Math.atan2(ux, uz);
          var toRoom = Math.atan2(-ux, -uz);
          var hash = FacilityModel.mix((r.col * 374761393) ^ (r.row * 40503));
          var ledge = CorpStyle.REC_LEDGE_H;
          var lu = CorpStyle.REC_LEDGE_MID_U;
          var wu = CorpStyle.REC_WORK_BACK_U;
          var ledgeRect = rect(r, span(m, r), CorpStyle.REC_BACK_U,
            CorpStyle.REC_FRONT_U + CorpStyle.REC_LEDGE_OVER);
          var workRect = rect(r, span(m, r), CorpStyle.REC_WORK_U, CorpStyle.REC_BACK_U);

          // the ledge. The board stands a cell IN from the lift end: the counter's end cell is
          // often against the tower's outer wall, whose rim hid it from the camera
          var boardAt = (r.len > 2 ? endA - toward : endA);
          stand(out.boards, at(r, boardAt, lu), ledge, toCorridor,
            CorpStyle.REC_BOARD_R * CorpStyle.REC_BOARD_H, ledgeRect);
          if (r.len > 1)
            stand(out.plants, at(r, endB, lu), ledge, hash * 0.001,
              plantR(), ledgeRect);
          stand(out.bells, at(r, mid + toward * 0.4, lu + 0.1), ledge, toCorridor,
            CorpStyle.REC_BELL_R * CorpStyle.REC_BELL_H, ledgeRect);
          var book = at(r, mid - toward * 0.45, lu);
          decal(out, book, ledge, toCorridor, CorpStyle.REC_DECALS[0]);
          decal(out, at(r, mid - toward * 0.1, lu + 0.2), ledge, toCorridor + 0.5,
            CorpStyle.REC_DECALS[1]);
          decal(out, at(r, endA, lu), ledge, toCorridor + 0.2, CorpStyle.REC_DECALS[2]);
          if (r.len > 3)
            decal(out, at(r, endB + toward * 1.0, lu), ledge, (hash >>> 8) % 628 * 0.01,
              CorpStyle.REC_DECALS[3]);

          // the worktop
          var side = (mid + toward >= 0 && mid + toward < r.len ? toward : -toward);
          stand(out.phones, at(r, mid + side * 0.85, wu), CorpStyle.DESK_H, toRoom,
            CorpStyle.REC_PHONE_R * CorpStyle.REC_PHONE_H, workRect);
          decal(out, at(r, mid - side * 0.8, wu - 0.35), CorpStyle.DESK_H, toRoom + 0.3,
            CorpStyle.REC_DECALS[4]);
          // and the second plant at the OTHER end from the first, where it does not stack with it
          if (r.len > 4)
            stand(out.plants, at(r, endA, wu), CorpStyle.DESK_H, hash * 0.002, plantR(),
              workRect);
        }
      return out;
    }

// the desk plant's footprint radius at the height CorpClutter draws it
  static inline function plantR():Float
    {
      return CorpStyle.CLUTTER_PROP_R[CorpStyle.CLUTTER_PLANT] *
        CorpStyle.CLUTTER_PROP_H[CorpStyle.CLUTTER_PLANT];
    }

// one glb onto its list, standing on a top `y` up, with a round contact under it clipped to `top`
  static function stand(list:Array<Models.PropPlace>, p:{ x:Float, z:Float }, y:Float,
      yaw:Float, rad:Float, top:Rect):Void
    {
      list.push({
        x: p.x,
        z: p.z,
        yaw: yaw,
        y: y,
      });
      FacilityDetail.deck({
        cx: p.x,
        cz: p.z,
        hw: rad,
        hd: rad,
        yaw: yaw,
        y: y,
        plate: top,
      });
    }

// one decal onto the list, lying on a top `y` up
  static function decal(out:ReceptionDress, p:{ x:Float, z:Float }, y:Float, yaw:Float,
      idx:Int):Void
    {
      out.decals.push({
        x: p.x,
        z: p.z,
        y: y + CorpStyle.CLUTTER_Y,
        yaw: yaw,
        idx: idx,
      });
    }

// a point on a counter: `k` cells along the run from its first (fractions allowed) and `u` across it
  static function at(r:ReceptionRun, k:Float, u:Float):{ x:Float, z:Float }
    {
      var a = CityConfig.cellToWorld(r.col, r.row);
      var ux = FacilityGeom.DC[r.out];
      var uz = FacilityGeom.DR[r.out];
      return {
        x: a.x + (r.alongX ? k * CELL : 0.0) + ux * u,
        z: a.z + (r.alongX ? 0.0 : k * CELL) + uz * u,
      };
    }

// the lift's own floor, as its first cell in world, or null on a plate with none
  static function liftCell(m:Facility):{ x:Float, z:Float }
    {
      for (row in 0...m.h)
        for (col in 0...m.w)
          if (m.surf[row][col] == Surf.LIFT)
            return CityConfig.cellToWorld(col, row);
      return null;
    }

// taxicab distance between two world points
  static inline function dist(a:{ x:Float, z:Float }, b:{ x:Float, z:Float }):Float
    {
      return Math.abs(a.x - b.x) + Math.abs(a.z - b.z);
    }

// the receptionist: a task chair in the room behind the middle of each counter, facing it, and the
// workstation on the worktop in front of it — into render.corp.CorpProps' own batches
  public static function place(m:Facility, chairs:Array<Models.PropPlace>,
      mons:Array<Models.PropPlace>, keys:Array<Models.PropPlace>):Void
    {
      for (r in runs(m))
        {
          var k = Std.int(r.len / 2);
          var c = CityConfig.cellToWorld(r.col + (r.alongX ? k : 0), r.row + (r.alongX ? 0 : k));
          var ux = FacilityGeom.DC[r.out];
          var uz = FacilityGeom.DR[r.out];
          // the chair faces the corridor, i.e. the counter; the screen looks back at the chair
          chairs.push({
            x: c.x - ux * CorpStyle.CHAIR_OUT,
            z: c.z - uz * CorpStyle.CHAIR_OUT,
            yaw: Math.atan2(ux, uz),
          });
          var mu = CorpStyle.REC_BACK_U - CorpStyle.REC_MON_IN;
          var ku = CorpStyle.REC_BACK_U - CorpStyle.REC_KEY_IN;
          mons.push({
            x: c.x + ux * mu,
            z: c.z + uz * mu,
            yaw: Math.atan2(-ux, -uz),
            y: CorpStyle.DESK_H,
          });
          keys.push({
            x: c.x + ux * ku,
            z: c.z + uz * ku,
            yaw: Math.atan2(-ux, -uz),
            y: CorpStyle.DESK_H,
          });
        }
    }
}
