// the compound's hangar
//
// one open shed: a wall ring, a run of fake bay doors along the face away from the road, one real
// side door, and a concrete floor. Moved out of game.FacilityAreaGenerator whole; the signature is
// still (state, x, y, w, h) rather than a tree filler, which is what Phase 4 changes.

package gen.blocks;

import gen.facility._FacilityState;
import gen.facility.FacilityTemp.*;

class HangarBlock
{
  // cells of open lot left between the hangar and the nearest building's pavement apron. the hangar
  // is the one structure with no apron of its own, and its wall is a blank storey-and-a-half face:
  // at the game's camera pitch that face SILHOUETTES the cell in front of it, so a gap of two read
  // as one on screen and the yard between the lab and the hangar looked like a slot.
  //
  // public because FacilityGen.build reads it to place the hangar, not just to draw it
  public static inline var HANGAR_GAP = 3;

// generate a hangar of a given size at given coordinates
  public static function generateHangar(state: _FacilityState,
      bx: Int, by: Int, bw: Int, bh: Int)
    {
      var area = state.area;
      var cells = area.getCells();
      // draw outer walls
      for (y in by - 2...by + bh + 2)
        for (x in bx - 2...bx + bw + 2)
          {
            if (x < 0 || y < 0 || x >= area.width || y >= area.height)
              continue;
            if (x > bx && x < bx + bw - 1 && y > by && y < by + bh - 1)
              {
                cells[x][y] = TEMP_CONCRETE;
                continue;
              }
            if (x < bx || x >= bx + bw || y < by || y >= by + bh)
              continue;
            if (x == bx || x == bx + bw - 1 || y == by || y == by + bh - 1)
              cells[x][y] = TEMP_BUILDING_WALL;
          }

      // draw fake doors
      var len = 0;
      var y = (state.mainRoadNorth ? (by + bh - 1) : by);
      for (x in bx + 1...bx + bw - 1)
        {
          if (len < 0)
            {
              len++;
              continue;
            }
          cells[x][y] = TEMP_HANGAR_DOOR;
          len++;
          if (len == 3)
            len = -1;
        }

      // draw side door
      cells[bx][by + Std.int(bh / 2)] = TEMP_HANGAR_SIDE_DOOR;

      // the hangar is ONE open space, so it is one room. it has no inner walls and therefore never
      // went through makeDoors, which is why it used to contribute nothing to generatorInfo at all —
      // and a room-less structure gets no ceiling light and no room reveal
      state.allRooms.push({
        id: state.nextRoomID,
        x1: bx + 1,
        y1: by + 1,
        x2: bx + bw - 2,
        y2: by + bh - 2,
        w: bw - 2,
        h: bh - 2,
      });
      state.nextRoomID++;
    }
}
