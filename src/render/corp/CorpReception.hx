package render.corp;

import citygen.CityConfig;
import render.Models;
import render.facility.FacilityDetail;
import render.facility.FacilityGeom;
import render.facility.FacilityGeom.Rect;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
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
        body(m, r);
      return rs.length;
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
