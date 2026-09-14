// facility area generation, the Game-free half
//
// build() is the real entry point and the one tools/genrun.mjs calls. It must never reach for a
// game.Game: everything it writes goes into a gen.GenCtx, and objects are recorded as SPAWN INTENTS
// that gen.GenSpawner turns into real AreaObjects on the live path only. game.FacilityAreaGenerator
// is the thin adapter that does that last step. See docs/area-gen.md.

package gen.facility;

import Const;
import game.AreaGenerator.*;
import gen.GenCtx;
import gen.blocks.HangarBlock;
import gen.blocks.ParkBlock;
import gen.facility.FacilityTemp.*;

import haxe.Timer;

class FacilityGen
{
// generate a whole compound into a context.
//
// still the hand-written arithmetic it always was — main building at 0.5 x 0.5, side building at
// 0.4, hangar at 0.2 — with one coin flip mirroring it north/south. gen.blocks.FacilityBlocks.plan
// already describes the same compound as a quota over a subdivided rect, and Phase 4 is where this
// function stops doing the arithmetic and starts walking that tree instead
  public static function build(ctx: GenCtx): _FacilityState
    {
      var area = ctx;
      var state: _FacilityState = {
        area: ctx,
        mainRoadNorth: ctx.chance(50),
        rooms: null,
        doors: null,
        allRooms: [],
        allDoors: [],
        nextRoomID: TEMP_BUILDING_ROOM_ID_START,
      }
      // fill with blank
      var cells = area.getCells();
      drawBlock(cells, 0, 0, area.width, area.height, TEMP_ALLEY);

      // main road
      var rw = 4;
      var ry = (state.mainRoadNorth ? 0 : area.height - rw);
      drawBlock(cells, 0, ry, area.width, rw, TEMP_ROAD);

      // sidewalk near main road
      var sidewalkw = 2;
      var sidewalky = (state.mainRoadNorth ? ry + rw : ry - sidewalkw);
      drawBlock(cells, 0, sidewalky, area.width, sidewalkw, TEMP_WALKWAY);

      // main building
      var t1 = Timer.stamp();
      var mainw = Std.int(area.width * 0.5),
        mainh = Std.int(area.height * 0.5);
      var mainx = Std.int(mainw / 2),
        mainy = (state.mainRoadNorth ? rw + 2 : area.height - mainh - 2 - rw);
      FacilityBuilding.generateBuilding(state, mainx, mainy, mainw, mainh);

      // hole in sidewalk for entry to parking lot. game.AreaGame.gate() re-derives the checkpoint
      // from exactly this 4x2 hole on every load, so its shape is not cosmetic
      var hx = mainx + mainw + 10, hy = sidewalky;
      drawBlock(cells, hx, hy, 4, 2, TEMP_ALLEY);
      // sewer hatches
      var cnt = 0;
      var sewersDist = 10 + area.random(10);
      for (x in 0...hx)
        {
          cnt++;
          if (cnt < sewersDist)
            continue;
          area.add('sewerHatch', x, sidewalky + (state.mainRoadNorth ? 0 : 1));
          cnt = 0;
        }

      // grass
      var gx = 2, gy = mainy, gw = mainx - 4, gh = mainh;
      drawBlock(cells, gx, gy, gw, gh, TEMP_GRASS);
      drawBlock(cells, 0, gy, 2, gh, TEMP_WALKWAY);
      ParkBlock.generatePark(state, gx, gy, gw, gh);

      // side building
      var sidex = 2,
        sidey = (state.mainRoadNorth ? mainy + mainh + 2 : 2),
        sidew = Std.int(area.width * 0.4),
        sideh = (state.mainRoadNorth ? area.height - sidey - 2 : mainy - 4);
      FacilityBuilding.generateBuilding(state, sidex, sidey, sidew, sideh);

      // hangar. it is pushed off the main building's apron by HANGAR_GAP and SHORTENED by the same,
      // so the far end stays where it was — the yard it faces is the compound's own, and moving that
      // end would take the gap out of the lot on the other side instead
      var hangarx = sidex + sidew + 16,
        hangary = (state.mainRoadNorth ? mainy + mainh + 2 + HangarBlock.HANGAR_GAP : 4),
        hangarw = Std.int(area.width * 0.2),
        hangarh = (state.mainRoadNorth ?
          area.height - sidey - 4 - HangarBlock.HANGAR_GAP :
          mainy - 6 - HangarBlock.HANGAR_GAP);
      HangarBlock.generateHangar(state, hangarx, hangary, hangarw, hangarh);

      // convert temp tiles to ingame ones
      finalizeTiles(state);
      // and last, once every wall, door and piece of furniture is on the grid in its final form,
      // make sure every room can actually be walked into
      FacilityConnect.connectRooms(state);
      trace(Std.int((Timer.stamp() - t1) * 1000) + 'ms');
      return state;
    }

// replace all temp tiles into final ones
  static function finalizeTiles(state: _FacilityState)
    {
      var area = state.area;
      var cells = area.getCells();
      for (y in 0...area.height)
        for (x in 0...area.width)
          {
            var tileID = cells[x][y];
            // spawn doors
            if (tileID == TEMP_BUILDING_FRONT_DOOR)
              {
                area.addDoor(x, y, Const.FRAME_DOOR_DOUBLE,
                  Const.FRAME_DOOR_DOUBLE_OPEN);
              }
            else if (tileID == TEMP_BUILDING_SIDE_DOOR)
              {
                area.addDoor(x, y, Const.FRAME_DOOR_GLASS,
                  Const.FRAME_DOOR_GLASS_OPEN);
              }
            else if (tileID == TEMP_BUILDING_INNER_DOOR)
              {
                // a door into a PRIVATE room takes the solid leaf that blocks sight. read off the
                // floor on the far side of the opening and off nothing else, the same way the whole
                // theme travels: generateRoomContents has already painted those tiles final by here
                var priv = opensOnPrivateRoom(cells, x, y);
                area.addDoor(x, y,
                  (priv ? Const.FRAME_DOOR_PRIVATE : Const.FRAME_DOOR_CABINET),
                  (priv ? Const.FRAME_DOOR_PRIVATE_OPEN : Const.FRAME_DOOR_CABINET_OPEN));
              }
            else if (tileID == TEMP_HANGAR_SIDE_DOOR)
              {
                area.addDoor(x, y, Const.FRAME_DOOR_METAL,
                  Const.FRAME_DOOR_METAL_OPEN);
              }
            // spawn vent object
            else if (tileID == TEMP_BUILDING_VENT)
              {
                area.add('vent', x, y);
              }
            // pick which tree this one is. WHICH cells are planted was decided by ParkBlock, so
            // all that is left here is the image — the bushes and the benches take one tile each
            // and go through finalTiles like everything else.
            //
            // TWO of the four, and they are +0 and +2: the other two are dead wood and a maintained
            // institutional park has none. +3 is the dead snag outright, and +1 draws
            // wild/tree-broadleaf, a BARE broadleaf with thick limbs and no foliage, which reads as
            // a dead tree whatever the wilderness files it under. random(2) * 2 deals the two
            // that are in leaf. render.facility.FacilityGround folds the other two on the render
            // side as well, which is what covers areas generated before this line
            else if (tileID == TEMP_GRASS_TREE)
              {
                cells[x][y] = Const.TILE_TREE1 + area.random(2) * 2;
                continue;
              }

            // a room template has already written its FINAL ids — a themed floor, a drain, an
            // unwalkable furniture cell. those sit at or above the chem-lab band and are left alone
            if (tileID >= Const.OFFSET_CHEM_LAB)
              continue;
            else tileID = finalTiles[tileID];

            cells[x][y] = tileID;
          }
    }
}
