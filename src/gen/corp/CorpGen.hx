// corp tower floor generation, the Game-free half
//
// build() is the real entry point and the one tools/genrun.mjs calls. It must never reach for a
// game.Game: everything it writes goes into a gen.GenCtx, and objects are recorded as SPAWN INTENTS
// that gen.GenSpawner turns into real AreaObjects on the live path only. game.CorpAreaGenerator is
// the thin adapter that does that last step. See docs/area-gen.md.
//
// THE TREE IS SHALLOWER THAN THE COMPOUND'S and deliberately so. A facility is open ground cut into
// plots; a corp area is one floor plate of a tower, so there is nothing to split at the area level
// and the root has exactly one child. What the quota deals is the ROOMS the corridor carve
// produced — see gen.blocks.CorpBlocks.

package gen.corp;

import Const;
import game.AreaGenerator.*;
import gen.GenCtx;
import gen.GenTree;
import gen.blocks.CorpBlocks;
import gen.blocks.ElevatorBlock;
import gen.blocks.OfficeBlock;
import gen.corp.CorpTemp.*;

import haxe.Timer;

class CorpGen
{
// generate a whole floor into a context.
//
// SEED -> ROOT -> PLATE -> WALK -> FINALIZE. The plate's own fill carves the corridors and the
// rooms and pushes the lift and every room as children, so the walk meets them one level down with
// the whole plate already on the grid — which is what lets a room template ask what is next to it
  public static function build(ctx: GenCtx): _CorpState
    {
      var state: _CorpState = {
        area: ctx,
        px1: 0,
        py1: 0,
        px2: 0,
        py2: 0,
        frontDir: DIR_DOWN,
        rooms: [],
        doors: [],
        nextRoomID: BLDG_ROOM_ID_START,
      }
      // everything outside the tower. it is the alley the 2D view has always drawn there, and it
      // is what render.corp reads as the VOID the floor plate stands over — twenty storeys of
      // nothing between this floor and the street
      var cells = ctx.getCells();
      drawBlock(cells, 0, 0, ctx.width, ctx.height, ALLEY);

      var t1 = Timer.stamp();
      var pw = Std.int(ctx.width * PLATE_FRAC);
      var ph = Std.int(ctx.height * PLATE_FRAC);
      var px = Std.int(ctx.width * PLATE_ORIGIN_FRAC);
      var py = Std.int(ctx.height * PLATE_ORIGIN_FRAC);
      state.px1 = px;
      state.py1 = py;
      state.px2 = px + pw - 1;
      state.py2 = py + ph - 1;
      GenTree.add(ctx.root, CorpBlocks.PLATE, state.px1, state.py1, state.px2, state.py2);
      GenTree.build(ctx.root, function(n) fill(state, n));

      finalizeTiles(state);
      // and last, once every wall, door and piece of furniture is on the grid in its final form,
      // make sure every room can be walked into from the lift
      CorpConnect.connectRooms(state);
      // and the per-CELL pass, after every room has a door: a room can be reached and still have
      // a corner of its own floor walled off by its own furniture
      CorpConnect.openPockets(state);
      // and the decorations those two passes orphaned — a chair left pulled up to a desk that came
      // away is the reported shape, and nothing before this point can see it
      CorpConnect.dropOrphanChairs(state);
      trace(Std.int((Timer.stamp() - t1) * 1000) + 'ms');
      return state;
    }

// build one node of the tree. a kind with no case here is a leaf that writes nothing, which is
// what every zone kind is but the kitchen's
  static function fill(state: _CorpState, node: _GenNode)
    {
      if (OfficeBlock.isRoom(node.kind))
        {
          OfficeBlock.fill(state, node);
          return;
        }
      switch (node.kind)
        {
          case CorpBlocks.PLATE:
            CorpBuilding.generate(state, node);

          case CorpBlocks.ELEVATOR:
            ElevatorBlock.fill(state, node);

          case CorpBlocks.ZONE_PREP,
            CorpBlocks.ZONE_VENDING,
            CorpBlocks.ZONE_DINING:
            CorpKitchen.fill(state, node);

          default:
        }
    }

// replace all temp tiles with final ones, and record the objects the marks stand for
  static function finalizeTiles(state: _CorpState)
    {
      var area = state.area;
      var cells = area.getCells();
      for (y in 0...area.height)
        for (x in 0...area.width)
          {
            var tileID = cells[x][y];
            if (tileID == BLDG_ELEVATOR_DOOR)
              area.addDoor(x, y, Const.FRAME_DOOR_ELEVATOR, Const.FRAME_DOOR_ELEVATOR_OPEN);
            else if (tileID == BLDG_INNER_DOOR)
              area.addDoor(x, y, Const.FRAME_DOOR_CORP, Const.FRAME_DOOR_CORP_OPEN);
            else if (tileID == BLDG_VENT)
              area.add('vent', x, y);

            // a room template has already written its FINAL ids — a themed floor, a table tile, a
            // fixture cell. those sit at or above the chem-lab band and are left alone
            if (tileID >= Const.OFFSET_CHEM_LAB)
              continue;
            // and a room ID mark that no template painted over is bare floor
            if (tileID >= BLDG_ROOM_ID_START)
              {
                cells[x][y] = Const.TILE_FLOOR_CARPET;
                continue;
              }
            cells[x][y] = finalTiles[tileID];
          }
    }
}
