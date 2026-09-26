package render.corp;

import citygen.CityConfig;
import render.Models;
import render.facility.ClutterSlot;
import render.facility.FacilityDetail;
import render.facility.FacilityGeom.Rect;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;

// one exec desk: the bbox of a connected run of worktop cells on Surf.EXEC, and the hand its owner
// sits on
typedef ExecDesk = {
  var col0:Int;
  var row0:Int;
  var col1:Int;
  var row1:Int;
  // the hand the owner's chair is on, in CorpExec.DC / DR's numbering
  var dir:Int;
  // the cell gen.corp dealt the computer onto, or null for a desk with none
  var work:{ col:Int, row:Int };
};

// what render.corp.CorpProps batches for the exec office, one list per glb
typedef ExecPlaces = {
  var desk:Array<Models.PropPlace>;
  var desk3:Array<Models.PropPlace>;
  var desk2:Array<Models.PropPlace>;
  var chairs:Array<Models.PropPlace>;
  var armchairs:Array<Models.PropPlace>;
  var sofas:Array<Models.PropPlace>;
  var tables:Array<Models.PropPlace>;
  var mons:Array<Models.PropPlace>;
  var keys:Array<Models.PropPlace>;
};

// THE EXEC OFFICE'S FURNITURE, off the generator's own cells.
//
// gen.corp.CorpRooms.exec lays the desk as worktop tiles and deals every seat and the lounge as
// decorations on the four atlas cells rows 23-39 had left empty (Const.CORP_EXEC_CHAIR, _ARMCHAIR,
// _SOFA, _TABLE_LOW). This reads both back and stands a glb on each, every one of them yawed off a
// NEIGHBOUR rather than stored: the desk faces away from its owner's chair, a visitor faces the
// desk, the sofa and the lounge armchairs face the low table between them.
//
// A PURE FUNCTION OF THE GRID AND THE AREA'S OBJECTS, like every pass on this plate, so
// render.corp.CorpClutter can ask where the exec monitors stand without having run after
// render.corp.CorpProps. With no area (the warm's demo model, which carries no decorations) it
// places nothing, and the desk cells draw no worktop either — CorpWarm warms the glbs by path
class CorpExec
{
  static inline var CELL = CityConfig.CELL;

  public static var DC = [0, 0, -1, 1];
  public static var DR = [-1, 1, 0, 0];

// is this a cell of an exec desk — a worktop the exec office stands a glb on instead of emitting
  public static inline function deskCell(m:Facility, col:Int, row:Int):Bool
    {
      return FacilityModel.inside(m, col, row) &&
        m.table[row][col] &&
        m.surf[row][col] == Surf.EXEC;
    }

// every exec desk on the plate: the connected runs of exec worktop, each with its owner's hand
  public static function desks(m:Facility, area:game.AreaGame):Array<ExecDesk>
    {
      var out = [];
      if (area == null)
        return out;
      var owners = cellSet(m, CorpDeco.cells(area, CorpDeco.K_EXEC_CHAIR));
      var work = CorpDeco.cells(area, CorpDeco.K_WORK);
      var seen = [for (_ in 0...m.h) [for (_ in 0...m.w) false]];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (seen[row][col] ||
                !deskCell(m, col, row))
              continue;
            // the run, flooded 4-connected, as its bbox
            var d:ExecDesk = {
              col0: col,
              row0: row,
              col1: col,
              row1: row,
              dir: 1,
              work: null,
            };
            var stack = [{ col: col, row: row }];
            seen[row][col] = true;
            while (stack.length > 0)
              {
                var c = stack.pop();
                if (c.col < d.col0)
                  d.col0 = c.col;
                if (c.col > d.col1)
                  d.col1 = c.col;
                if (c.row < d.row0)
                  d.row0 = c.row;
                if (c.row > d.row1)
                  d.row1 = c.row;
                for (k in 0...4)
                  {
                    var nc = c.col + DC[k], nr = c.row + DR[k];
                    if (!deskCell(m, nc, nr) ||
                        seen[nr][nc])
                      continue;
                    seen[nr][nc] = true;
                    stack.push({ col: nc, row: nr });
                  }
              }
            // the owner is the exec chair touching the run; a desk with none (an old save) faces
            // the room's +z, which is what a desk with no chair behind it cannot get wrong
            for (r in d.row0...d.row1 + 1)
              for (c in d.col0...d.col1 + 1)
                for (k in 0...4)
                  if (owners.exists(key(m, c + DC[k], r + DR[k])))
                    d.dir = k;
            for (w in work)
              if (w.col >= d.col0 &&
                  w.col <= d.col1 &&
                  w.row >= d.row0 &&
                  w.row <= d.row1)
                d.work = w;
            out.push(d);
          }
      return out;
    }

// every glb the exec office stands, into `out`, with the contact under each
  public static function place(m:Facility, area:game.AreaGame, out:ExecPlaces):Void
    {
      if (area == null)
        return;
      var ds = desks(m, area);
      for (d in ds)
        desk(m, d, out);
      // the owners' chairs, pulled in to the desk they face
      for (c in CorpDeco.cells(area, CorpDeco.K_EXEC_CHAIR))
        {
          var k = toward(m, c.col, c.row, function(col, row) return deskCell(m, col, row));
          if (k < 0)
            continue;
          seat(m, c.col, c.row, k, CorpStyle.EXEC_CHAIR_IN, CorpStyle.EXEC_CHAIR_W,
            CorpStyle.EXEC_CHAIR_H, out.chairs);
        }
      // the armchairs: a lounge's faces its low table, a visitor's faces the desk
      var lows = cellSet(m, CorpDeco.cells(area, CorpDeco.K_TABLE_LOW));
      for (c in CorpDeco.cells(area, CorpDeco.K_ARMCHAIR))
        {
          var k = toward(m, c.col, c.row, function(col, row) return lows.exists(key(m, col, row)));
          if (k < 0)
            k = toward(m, c.col, c.row, function(col, row) return deskCell(m, col, row));
          if (k < 0)
            continue;
          seat(m, c.col, c.row, k, CorpStyle.ARMCHAIR_IN, CorpStyle.ARMCHAIR_W,
            CorpStyle.ARMCHAIR_H, out.armchairs);
        }
      pairs(m, area, CorpDeco.K_SOFA, lows, out.sofas, true);
      pairs(m, area, CorpDeco.K_TABLE_LOW, lows, out.tables, false);
    }

// the workstation boxes on every exec desk cell that carries one, keyed by cell, for
// render.corp.CorpClutter to scatter round — the same oracle role CorpProps.claims plays for the
// open plan
  public static function claims(m:Facility, area:game.AreaGame):Map<Int, Array<ClutterSlot>>
    {
      var out = new Map<Int, Array<ClutterSlot>>();
      for (d in desks(m, area))
        {
          if (d.work == null)
            continue;
          var ws = workAt(d);
          var alongX = (d.dir < 2);
          out.set(key(m, d.work.col, d.work.row), [
            {
              x: ws.mx,
              z: ws.mz,
              hw: (alongX ? CorpStyle.MON_W : CorpStyle.MON_D) / 2,
              hd: (alongX ? CorpStyle.MON_D : CorpStyle.MON_W) / 2,
            },
            {
              x: ws.kx,
              z: ws.kz,
              hw: (alongX ? CorpStyle.KEY_W : CorpStyle.KEY_D) / 2,
              hd: (alongX ? CorpStyle.KEY_D : CorpStyle.KEY_W) / 2,
            },
          ]);
        }
      return out;
    }

// the low tables' tops as world rects, for render.corp.CorpClutter to lay a thing or two on
  public static function lowTops(m:Facility, area:game.AreaGame):Array<{ x:Float, z:Float,
      hw:Float, hd:Float, col:Int, row:Int }>
    {
      var out = [];
      if (area == null)
        return out;
      var lows = cellSet(m, CorpDeco.cells(area, CorpDeco.K_TABLE_LOW));
      var places = [];
      pairs(m, area, CorpDeco.K_TABLE_LOW, lows, places, false);
      for (p in places)
        {
          var alongX = (Math.abs(Math.sin(p.yaw)) < 0.5);
          var c = CityConfig.worldToCell(p.x, p.z);
          out.push({
            x: p.x,
            z: p.z,
            hw: (alongX ? CorpStyle.TABLE_LOW_W : CorpStyle.TABLE_LOW_D) / 2,
            hd: (alongX ? CorpStyle.TABLE_LOW_D : CorpStyle.TABLE_LOW_W) / 2,
            col: c.col,
            row: c.row,
          });
        }
      return out;
    }

// one desk's glb, its workstation and its contact
  static function desk(m:Facility, d:ExecDesk, out:ExecPlaces):Void
    {
      var w = d.col1 - d.col0 + 1, h = d.row1 - d.row0 + 1;
      var long = (w > h ? w : h);
      var short = (w > h ? h : w);
      // a glb per EXACT footprint and nothing for any other: the 3x2 block is laid 3 across x and
      // 2 down z by its tiles, and a desk the pocket repair ate into is not stretched over its stub
      var list = (w == 3 && h == 2 ? out.desk :
        (short == 1 && long == 3 ? out.desk3 : (short == 1 && long == 2 ? out.desk2 : null)));
      if (list == null)
        return;
      var c = CityConfig.cellToWorld((d.col0 + d.col1) / 2, (d.row0 + d.row1) / 2);
      // the model's FRONT is its +z at yaw 0 and its owner side -z, so it faces AWAY from the owner
      list.push({
        x: c.x,
        z: c.z,
        yaw: Math.atan2(-DC[d.dir], -DR[d.dir]),
      });
      FacilityDetail.ground(m, {
        col: d.col0,
        row: d.row0,
        len: (w >= h ? w : h),
        alongX: (w >= h),
        rect: {
          x0: c.x - w * CELL / 2 + CorpStyle.FIT_INSET,
          x1: c.x + w * CELL / 2 - CorpStyle.FIT_INSET,
          z0: c.z - h * CELL / 2 + CorpStyle.FIT_INSET,
          z1: c.z + h * CELL / 2 - CorpStyle.FIT_INSET,
        },
        h: CorpStyle.EXEC_DESK_H,
      });
      if (d.work == null)
        return;
      // the screen faces its owner, standing back across the desk from the chair
      var ws = workAt(d);
      var yaw = Math.atan2(DC[d.dir], DR[d.dir]);
      out.mons.push({
        x: ws.mx,
        z: ws.mz,
        yaw: yaw,
        y: CorpStyle.DESK_H,
      });
      out.keys.push({
        x: ws.kx,
        z: ws.kz,
        yaw: yaw,
        y: CorpStyle.DESK_H,
      });
    }

// where a desk's monitor and keyboard stand: on the computer's own cell, the screen set back from
// the owner by CorpStyle.EXEC_MON_BACK and the keyboard between it and him
  static function workAt(d:ExecDesk):{ mx:Float, mz:Float, kx:Float, kz:Float }
    {
      var c = CityConfig.cellToWorld(d.work.col, d.work.row);
      var ox = DC[d.dir], oz = DR[d.dir];
      return {
        mx: c.x - ox * CorpStyle.EXEC_MON_BACK,
        mz: c.z - oz * CorpStyle.EXEC_MON_BACK,
        kx: c.x - ox * (CorpStyle.EXEC_MON_BACK - CorpStyle.KEY_FWD),
        kz: c.z - oz * (CorpStyle.EXEC_MON_BACK - CorpStyle.KEY_FWD),
      };
    }

// one seat on its cell, pulled `pull` toward the hand it faces and turned to face it
  static function seat(m:Facility, col:Int, row:Int, k:Int, pull:Float, w:Float, h:Float,
      list:Array<Models.PropPlace>):Void
    {
      var c = CityConfig.cellToWorld(col, row);
      var x = c.x + DC[k] * pull;
      var z = c.z + DR[k] * pull;
      list.push({
        x: x,
        z: z,
        yaw: Math.atan2(DC[k], DR[k]),
      });
      FacilityDetail.ground(m, {
        col: col,
        row: row,
        len: 1,
        alongX: true,
        rect: {
          x0: x - w / 2,
          x1: x + w / 2,
          z0: z - w / 2,
          z1: z + w / 2,
        },
        h: h,
      });
    }

// the two-cell pieces of a lounge: each pair of one kind's cells as one glb over its middle. The
// sofa faces its table and is pushed back toward the wall behind it; the table runs along the pair
  static function pairs(m:Facility, area:game.AreaGame, kind:Int, lows:Map<Int, Bool>,
      list:Array<Models.PropPlace>, sofa:Bool):Void
    {
      var cells = CorpDeco.cells(area, kind);
      var set = cellSet(m, cells);
      for (c in cells)
        {
          // a pair is taken from its first cell only: the one with its partner on the +x or +z hand
          var alongX = set.exists(key(m, c.col + 1, c.row));
          if (!alongX &&
              !set.exists(key(m, c.col, c.row + 1)))
            continue;
          var w = CityConfig.cellToWorld(c.col + (alongX ? 0.5 : 0.0),
            c.row + (alongX ? 0.0 : 0.5));
          if (!sofa)
            {
              // the model runs along its own x, so a pair down z takes a quarter turn
              list.push({
                x: w.x,
                z: w.z,
                yaw: (alongX ? 0.0 : Math.PI / 2),
              });
              FacilityDetail.ground(m, {
                col: c.col,
                row: c.row,
                len: 2,
                alongX: alongX,
                rect: rectOf(w.x, w.z, alongX, CorpStyle.TABLE_LOW_W, CorpStyle.TABLE_LOW_D),
                h: CorpStyle.TABLE_LOW_H,
              });
              continue;
            }
          // which hand the table is on, off either cell of the pair
          var k = toward(m, c.col, c.row, function(col, row) return lows.exists(key(m, col, row)));
          if (k < 0)
            k = toward(m, c.col + (alongX ? 1 : 0), c.row + (alongX ? 0 : 1),
              function(col, row) return lows.exists(key(m, col, row)));
          if (k < 0)
            continue;
          var x = w.x - DC[k] * CorpStyle.SOFA_BACK;
          var z = w.z - DR[k] * CorpStyle.SOFA_BACK;
          list.push({
            x: x,
            z: z,
            yaw: Math.atan2(DC[k], DR[k]),
          });
          FacilityDetail.ground(m, {
            col: c.col,
            row: c.row,
            len: 2,
            alongX: alongX,
            rect: rectOf(x, z, alongX, CorpStyle.SOFA_W, CorpStyle.SOFA_D),
            h: CorpStyle.SOFA_H,
          });
        }
    }

// a piece's footprint in world axes, `len` along the pair and `deep` across it
  static function rectOf(x:Float, z:Float, alongX:Bool, len:Float, deep:Float):Rect
    {
      var hw = (alongX ? len : deep) / 2;
      var hd = (alongX ? deep : len) / 2;
      return {
        x0: x - hw,
        x1: x + hw,
        z0: z - hd,
        z1: z + hd,
      };
    }

// the first hand of a cell whose neighbour passes `hit`, or -1
  static function toward(m:Facility, col:Int, row:Int, hit:Int->Int->Bool):Int
    {
      for (k in 0...4)
        if (FacilityModel.inside(m, col + DC[k], row + DR[k]) &&
            hit(col + DC[k], row + DR[k]))
          return k;
      return -1;
    }

// a list of cells as a set keyed by `key`
  static function cellSet(m:Facility, cells:Array<{ col:Int, row:Int }>):Map<Int, Bool>
    {
      var out = new Map<Int, Bool>();
      for (c in cells)
        out.set(key(m, c.col, c.row), true);
      return out;
    }

// one cell as a map key
  public static inline function key(m:Facility, col:Int, row:Int):Int
    {
      return row * m.w + col;
    }
}
