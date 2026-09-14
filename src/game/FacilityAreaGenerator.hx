// facility area generation, the live-game side
//
// THE ADAPTER AND NOTHING ELSE. All of generation moved to gen.facility — see docs/area-gen.md —
// because the generator must not touch a game.Game if tools/genrun.mjs is to run it headless. What
// is left here is the two things that genuinely need the live area:
//
//   * generate(), which wraps the area's grid in a gen.GenCtx, runs the generator, and turns the
//     spawn intents it recorded into real AreaObjects;
//   * repairRooms(), which re-derives rooms and doors from a SAVED grid and so takes an AreaGame.
//
// the class name and package are unchanged on purpose: game.AreaGenerator dispatches through it and
// game.AreaGame calls repairRooms on every facility entry.

package game;

import const.WorldConst;
import Const;
import game.AreaGame;
import game.AreaGenerator;
import game.AreaGenerator.*;
import gen.GenCtx;
import gen.GenSpawner;
import gen.Rng;
import gen.facility.FacilityGen;
import gen.facility.FacilityTemp;

class FacilityAreaGenerator
{
  var game: Game;

  public function new(g: Game)
    {
      game = g;
    }

// entry-point for facility generation.
//
// `info` is unused and has been since this file was written; it stays in the signature because
// game.AreaGenerator.generate dispatches every area type through the same one
  public function generate(area: AreaGame, info: AreaInfo)
    {
      var ctx = new GenCtx(area.width, area.height, Rng.seed(), area.getCells());
      // every roll below comes off that seed, so this line is the whole repro: `make gen
      // seeds=1 args="--seed <n> --size <w>x<h> --print"` lays the same compound again with no game
      // running. the SIZE is part of it — game.AreaGame.initPost rolls each axis before we get here
      trace('facility ' + area.width + 'x' + area.height + ' seed ' + ctx.seed);
      var state = FacilityGen.build(ctx);
      area.generatorInfo = {
        rooms: state.allRooms,
        doors: state.allDoors,
      };
      GenSpawner.drain(game, area, ctx);
    }

// does this tile belong to a ROOM rather than to a corridor? lino is the corridor floor AND the
// floor under every door, which is exactly what separates one room from the next
  static function isRoomFloor(t: Int): Bool
    {
      if (t == Const.TILE_FLOOR_LINO)
        return false;
      if (t == Const.TILE_FLOOR_TILE ||
          t == Const.TILE_FLOOR_TILE_UNWALKABLE ||
          t == Const.TILE_FLOOR_TILE_CANNOTSEE ||
          t == Const.TILE_FLOOR_CONCRETE ||
          t == Const.TILE_FLOOR_CONCRETE_UNWALKABLE)
        return true;
      if (t >= Const.TILE_FLOOR_TILE_GRATE1 &&
          t <= Const.TILE_FLOOR_TILE_GRATE3)
        return true;
      // every table tile stands on room floor
      return (t >= Const.OFFSET_ROW8);
    }

// room id at a cell, or -1
  static inline function roomAt(mark: Array<Array<Int>>, x: Int, y: Int): Int
    {
      if (x < 0 ||
          y < 0 ||
          x >= mark.length ||
          y >= mark[0].length)
        return -1;
      return mark[x][y];
    }

// re-derive rooms and doors from the saved tile grid, for an area generated before this file
// recorded every structure's.
//
// generate() used to null state.rooms/doors after the main building and makeDoors reassigned rather
// than appended, so a saved facility describes its SIDE building only and the hangar contributes
// nothing. that record is persisted, and the cell grid is persisted verbatim and never regenerated,
// so a fixed generator alone would leave every already-visited facility partial forever. rooms are
// read by the 3D ceiling-light pass, by AreaView's room reveal and by three cult missions, so the
// repair is worth more than the renderer.
//
// it does NOT touch a single tile and it keeps missionHints: the rects are recovered from the grid
// the generator already wrote, which is the same trick render.sewer.SewerModel and
// render.wild.WildModel use to avoid persisting anything at all
  public static function repairRooms(area: AreaGame)
    {
      var cells = area.getCells();
      var mark = [for (x in 0...area.width) [for (y in 0...area.height) -1]];
      var rooms: Array<_Room> = [];
      for (y in 0...area.height)
        for (x in 0...area.width)
          {
            if (!isRoomFloor(cells[x][y]) ||
                mark[x][y] >= 0)
              continue;
            var id = FacilityTemp.TEMP_BUILDING_ROOM_ID_START + rooms.length;
            var room: _Room = {
              id: id,
              x1: x,
              y1: y,
              x2: x,
              y2: y,
              w: 1,
              h: 1,
            };
            var stack = [ { x: x, y: y } ];
            mark[x][y] = id;
            while (stack.length > 0)
              {
                var c = stack.pop();
                if (c.x < room.x1)
                  room.x1 = c.x;
                if (c.x > room.x2)
                  room.x2 = c.x;
                if (c.y < room.y1)
                  room.y1 = c.y;
                if (c.y > room.y2)
                  room.y2 = c.y;
                for (i in 0...Const.dir4x.length)
                  {
                    var nx = c.x + Const.dir4x[i];
                    var ny = c.y + Const.dir4y[i];
                    if (roomAt(mark, nx, ny) != -1 ||
                        !isRoomFloor(cells[nx][ny]))
                      continue;
                    mark[nx][ny] = id;
                    stack.push({ x: nx, y: ny });
                  }
              }
            room.w = room.x2 - room.x1 + 1;
            room.h = room.y2 - room.y1 + 1;
            rooms.push(room);
          }
      // a complete record already describes at least as many rooms as the grid holds. comparing
      // COUNTS rather than coverage is what makes this cheap and safe to run on every entry: a
      // record written by the fixed generator can only ever match or exceed the derivation, and the
      // partial ones it exists for are short by a whole building
      if (area.generatorInfo != null &&
          area.generatorInfo.rooms != null &&
          area.generatorInfo.rooms.length >= rooms.length)
        return;

      // doors link the rooms either side of them. a front or side door has a room on one side only
      // and the outdoors on the other, which is roomID2 0 — the same value the generator writes for
      // a door opening onto a corridor
      var doors: Array<_Door> = [];
      for (o in area.getObjects())
        {
          if (o.type != 'door')
            continue;
          var a = roomAt(mark, o.x - 1, o.y);
          var b = roomAt(mark, o.x + 1, o.y);
          var dir = DIR_RIGHT;
          if (a < 0 &&
              b < 0)
            {
              a = roomAt(mark, o.x, o.y - 1);
              b = roomAt(mark, o.x, o.y + 1);
              dir = DIR_DOWN;
            }
          if (a < 0 &&
              b < 0)
            continue;
          doors.push({
            x: o.x,
            y: o.y,
            dir: dir,
            roomID1: (a >= 0 ? a : b),
            roomID2: (a >= 0 && b >= 0 ? b : 0),
            skip: false,
          });
        }
      trace('repaired facility generatorInfo: ' + rooms.length + ' rooms, ' +
        doors.length + ' doors');
      area.generatorInfo = {
        rooms: rooms,
        doors: doors,
        missionHints: (area.generatorInfo != null ? area.generatorInfo.missionHints : null),
      };
    }
}
