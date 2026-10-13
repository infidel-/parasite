// the underground lab's plate: where the rooms, the corridor and the doorways go
//
// the level is cut into bedrock. A lobby at the west end, the lift in its north-west corner; a
// corridor two cells high east from it to the vat chamber at the other end; and the three service
// rooms on that corridor, two on one side and one on the other, each with its own doorway onto it.
// Rooms open onto the corridor and never into each other, the base's lesson.
//
// THE 2D LAB'S SHAPE, GROWN. It was four rooms (lobby, vat chamber, one service room each side, on
// spurs); this is five, every service kind on every level, and the rooms sit straight on the
// corridor wall. The vat chamber, its doorway and its four pads are where the mission has always
// looked for them, so objects.mission.CloneVat's mission reads this level unchanged.
//
// A DRAW THAT DOES NOT FIT IS DRAWN AGAIN, not repaired (docs/area-gen.md, Rules), up to TRIES.

package gen.lab;

import gen.GenTree;
import gen.blocks.LabBlocks;

class LabPlan
{
  // layouts drawn before giving up. A level this size fits on the first draw almost always
  static inline var TRIES = 30;
  // bedrock kept round the level: the wall ring's own cell and one more
  static inline var MARGIN = 2;
  // the lobby, the vat chamber and a service room, in cells of floor
  static inline var ENTRY_W_MIN = 8;
  static inline var ENTRY_W_MAX = 10;
  static inline var ENTRY_H_MIN = 7;
  static inline var ENTRY_H_MAX = 9;
  static inline var VAT_W_MIN = 13;
  static inline var VAT_W_MAX = 15;
  static inline var VAT_H_MIN = 15;
  static inline var VAT_H_MAX = 17;
  static inline var ROOM_W_MIN = 9;
  static inline var ROOM_W_MAX = 12;
  static inline var ROOM_H_MIN = 6;
  static inline var ROOM_H_MAX = 8;

// lay the plate and push what it carved: the lift, the corridor, the five doorways and the rooms
  public static function lay(state: _LabState, node: _GenNode)
    {
      var spec = null;
      while (spec == null &&
          state.tries < TRIES)
        {
          state.tries++;
          spec = draw(state.area);
        }
      if (spec == null)
        {
          trace('LabPlan.lay(): no layout fits ' + state.area.width + 'x' + state.area.height);
          return;
        }

      // the floors, then the corridor, then a wall on every bedrock cell touching any of them
      var cells = state.area.getCells();
      for (r in spec.rooms)
        fillRect(cells, r.x1, r.y1, r.x2, r.y2, LabBlocks.floorOf(r.role));
      fillRect(cells, spec.cx1, spec.cy, spec.cx2, spec.cy + 1, Const.TILE_LAB_CORRIDOR);
      walls(state.area);

      state.rooms = spec.rooms;
      state.corridorY = spec.cy;
      state.cx1 = spec.cx1;
      state.cx2 = spec.cx2;
      var entry = spec.rooms[0];
      var vat = spec.rooms[1];
      state.vatRoomID = vat.id;
      state.vatDoor = {
        x: vat.x1 - 1,
        y: spec.cy,
      };

      // the tree: lift and corridor and doorways first, so a room's deal already sees its doorway
      var lift = GenTree.add(node, LabBlocks.LIFT, entry.x1, entry.y1, entry.x1 + 1, entry.y1 + 1);
      lift.roomID = entry.id;
      GenTree.add(node, LabBlocks.CORRIDOR, spec.cx1, spec.cy, spec.cx2, spec.cy + 1);
      for (d in spec.doors)
        {
          var n = GenTree.add(node, LabBlocks.DOOR, d.x, d.y, d.x + (d.vertical ? 0 : 1),
            d.y + (d.vertical ? 1 : 0));
          n.roomID = d.roomID;
          n.tags = [ (d.vertical ? 'v' : 'h') ];
          state.doors.push({
            x: d.x,
            y: d.y,
            dir: 0,
            roomID1: d.roomID,
            roomID2: 0,
            skip: false,
          });
        }
      for (r in spec.rooms)
        {
          var n = GenTree.add(node, LabBlocks.kindOf(r.role), r.x1, r.y1, r.x2, r.y2);
          n.roomID = r.id;
        }
    }

// one layout, or null when this draw does not fit the grid
  static function draw(area: GenCtx): _LabSpec
    {
      var w = area.width;
      var h = area.height;
      var cy = Std.int(h / 2) - 1 + area.random(5) - 2;

      // the lobby at the west end and the vat chamber at the east, each across the corridor's two
      // rows with wall above and below its doorway
      var ew = roll(area, ENTRY_W_MIN, ENTRY_W_MAX);
      var eh = roll(area, ENTRY_H_MIN, ENTRY_H_MAX);
      var ex1 = MARGIN + area.random(2);
      var ey1 = cy - Std.int(eh / 2) + area.random(3) - 1;
      var vw = roll(area, VAT_W_MIN, VAT_W_MAX);
      var vh = roll(area, VAT_H_MIN, VAT_H_MAX);
      var vx2 = w - 1 - MARGIN - area.random(2);
      var vy1 = cy - Std.int(vh / 2) + area.random(3) - 1;
      var entry = room(1, LabBlocks.ROLE_ENTRANCE, ex1, ey1, ew, eh);
      var vat = room(2, LabBlocks.ROLE_VAT, vx2 - vw + 1, vy1, vw, vh);
      if (!across(entry, cy) ||
          !across(vat, cy) ||
          !inside(area, entry) ||
          !inside(area, vat))
        return null;

      // the corridor runs between their doorway walls
      var cx1 = entry.x2 + 2;
      var cx2 = vat.x1 - 2;
      var len = cx2 - cx1 + 1;

      // the service rooms: the first role alone on one side, the other two side by side on the other
      var roles = LabBlocks.SERVICE.copy();
      for (i in 0...roles.length - 1)
        {
          var j = i + area.random(roles.length - i);
          var t = roles[i];
          roles[i] = roles[j];
          roles[j] = t;
        }
      var soloTop = area.chance(50);
      var w1 = roll(area, ROOM_W_MIN, ROOM_W_MAX);
      var w2max = Std.int(Math.min(ROOM_W_MAX, len - 1 - w1));
      if (w2max < ROOM_W_MIN)
        return null;
      var w2 = roll(area, ROOM_W_MIN, w2max);
      var wSolo = roll(area, ROOM_W_MIN, Std.int(Math.min(ROOM_W_MAX, len)));
      var pairX = cx1 + area.random(len - (w1 + 1 + w2) + 1);
      var soloX = cx1 + area.random(len - wSolo + 1);
      var rooms = [ entry, vat ];
      var spots = [
        { role: roles[0], x: soloX, w: wSolo, top: soloTop },
        { role: roles[1], x: pairX, w: w1, top: !soloTop },
        { role: roles[2], x: pairX + w1 + 1, w: w2, top: !soloTop },
      ];
      for (s in spots)
        {
          var rh = roll(area, ROOM_H_MIN, ROOM_H_MAX);
          // a room above stands on the corridor's top wall, one below hangs off its bottom wall
          var r = room(rooms.length + 1, s.role, s.x, (s.top ? cy - 1 - rh : cy + 3), s.w, rh);
          if (!inside(area, r))
            return null;
          rooms.push(r);
        }

      // the doorways: the lobby's and the chamber's in their corridor-end walls, upright, and each
      // service room's in the corridor wall, clear of its corners
      var doors = [
        door(entry.id, entry.x2 + 1, cy, true),
        door(vat.id, vat.x1 - 1, cy, true),
      ];
      for (i in 2...rooms.length)
        {
          var r = rooms[i];
          doors.push(door(r.id, r.x1 + 1 + area.random(r.w - 3), (r.y2 < cy ? cy - 1 : cy + 2),
            false));
        }
      return {
        rooms: rooms,
        doors: doors,
        cy: cy,
        cx1: cx1,
        cx2: cx2,
      };
    }

// every bedrock cell touching floor on any of its eight sides becomes wall
  static function walls(area: GenCtx)
    {
      var cells = area.getCells();
      var open = [for (x in 0...area.width) [for (y in 0...area.height)
        cells[x][y] != Const.TILE_LAB_ROCK]];
      for (x in 1...area.width - 1)
        for (y in 1...area.height - 1)
          {
            if (open[x][y])
              continue;
            for (i in 0...Const.dirx.length)
              if (open[x + Const.dirx[i]][y + Const.diry[i]])
                {
                  cells[x][y] = Const.TILE_LAB_WALL;
                  break;
                }
          }
    }

// does this room take both corridor rows with wall above and below them, so its doorway is two
// cells of a straight wall?
  static inline function across(r: _Room, cy: Int): Bool
    {
      return r.y1 < cy &&
        r.y2 > cy + 1;
    }

// is this room inside the bedrock margin?
  static inline function inside(area: GenCtx, r: _Room): Bool
    {
      return r.x1 >= MARGIN &&
        r.y1 >= MARGIN &&
        r.x2 <= area.width - 1 - MARGIN &&
        r.y2 <= area.height - 1 - MARGIN;
    }

  static inline function roll(area: GenCtx, lo: Int, hi: Int): Int
    {
      return lo + area.random(hi - lo + 1);
    }

  static function room(id: Int, role: String, x1: Int, y1: Int, w: Int, h: Int): _Room
    {
      return {
        id: id,
        x1: x1,
        y1: y1,
        x2: x1 + w - 1,
        y2: y1 + h - 1,
        w: w,
        h: h,
        role: role,
      };
    }

  static function door(roomID: Int, x: Int, y: Int, vertical: Bool): _LabDoorSpec
    {
      return {
        roomID: roomID,
        x: x,
        y: y,
        vertical: vertical,
      };
    }

  static function fillRect(cells: Array<Array<Int>>, x1: Int, y1: Int, x2: Int, y2: Int, t: Int)
    {
      for (x in x1...x2 + 1)
        for (y in y1...y2 + 1)
          cells[x][y] = t;
    }
}

// one drawn layout, before it is laid
private typedef _LabSpec = {
  // the lobby, the vat chamber, then the three service rooms
  var rooms: Array<_Room>;
  var doors: Array<_LabDoorSpec>;
  // the corridor's top row and its first and last column
  var cy: Int;
  var cx1: Int;
  var cx2: Int;
}

// one two-cell doorway: its first cell (the upper or the left) and which way the pair runs
private typedef _LabDoorSpec = {
  // the room it opens, onto the corridor
  var roomID: Int;
  var x: Int;
  var y: Int;
  // two cells down (true) or across (false)
  var vertical: Bool;
}
