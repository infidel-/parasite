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
import gen.GenTree;
import gen.blocks.FacilityBlocks;
import gen.blocks.HangarBlock;
import gen.blocks.ParkBlock;
import gen.blocks.RoadBlock;
import gen.facility.FacilityTemp.*;

import haxe.Timer;

class FacilityGen
{
// generate a whole compound into a context.
//
// SEED -> ROOT -> RESERVE THE ROAD -> SPLIT -> DEAL -> WALK -> FINALIZE -> CONNECT, and the middle
// four are gen.blocks.FacilityBlocks.plan. This used to be hand-written arithmetic on
// area.width/height — main building at 0.5 x 0.5, side building at 0.4, hangar at 0.2, park in the
// strip left over and the car park in whatever the grid was still at — so a compound had exactly one
// layout with a north/south mirror on it. Now the quota says WHAT a compound must contain and the
// split says where it fits, so every seed lays out differently and every seed still has everything.
//
// the walk is BREADTH-FIRST (see gen.GenTree), which is what the ENTRYWAY child rides on: it hangs
// off the parking plot rather than off the road, so the mouth is punched a level AFTER every plot
// has thrown its pavement apron onto the road band and can no longer pave over it
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
      // the ground everything is cut out of. the YARD is this and nothing else — it has no filler,
      // because "open lot" is what the area already is. The parking plot is the same ground with one
      // mark laid over it, see the PARKING arm of `fill`
      var cells = area.getCells();
      drawBlock(cells, 0, 0, area.width, area.height, TEMP_ALLEY);

      var t1 = Timer.stamp();
      var root = area.root;
      root.children.push(RoadBlock.node(state));
      for (b in FacilityBlocks.plan(area.width, area.height, state.mainRoadNorth, area.rng))
        root.children.push(b);
      GenTree.build(root, function(n) fill(state, n));

      // convert temp tiles to ingame ones
      finalizeTiles(state);
      // and last, once every wall, door and piece of furniture is on the grid in its final form,
      // make sure every room can actually be walked into
      FacilityConnect.connectRooms(state);
      trace(Std.int((Timer.stamp() - t1) * 1000) + 'ms');
      return state;
    }

// build one node of the tree.
//
// the filler table for the BLOCK level, and the whole of it. A kind with no case here is a leaf that
// writes nothing, which is exactly right for 'yard' — open lot is what the grid was blanked to, so
// the yard is already finished before the walk reaches it. 'parking' is the same ground and gets a
// case all the same, for the one tile that tells it apart from the yard.
//
// the room kinds under a building fall through here on purpose. They are built and filled inside
// generateBuilding, by gen.blocks.RoomBlock through a walk of their own, because a room's contents
// have to be standing before the building's last pass runs; the area walk meets them again a level
// later and must do nothing when it does
  static function fill(state: _FacilityState, node: _GenNode)
    {
      var cells = state.area.getCells();
      var w = GenTree.width(node);
      var h = GenTree.height(node);
      switch (node.kind)
        {
          case FacilityBlocks.ROAD:
            RoadBlock.fill(state, node);

          case FacilityBlocks.BUILDING:
            // the building fills its plot outright. its own 2-cell pavement apron is written OUTSIDE
            // that rect, into the gap FacilityBlocks.splitProfile leaves between plots, which is why
            // that gap is 2 and not 1 — and why FacilityBlocks.EDGE_MARGIN keeps a plot off the grid
            // edge, where there is no neighbour to borrow the gap from
            FacilityBuilding.generateBuilding(state, node);

          case FacilityBlocks.HANGAR:
            // and the hangar sits one cell inside its plot on every side, because it is the one
            // structure with NO apron: the split's 2-cell gap plus this is HANGAR_GAP, the clearance
            // its blank storey-and-a-half face needs before the yard in front of it reads as a slot.
            //
            // then it is CAPPED at HangarBlock.HANGAR_W x HANGAR_H and CENTRED in what is left. A
            // plot is 16..34 on each axis and the hangar used to take all of it; the cap puts it
            // back at the size the arithmetic era drew it. The slack is not wasted — it stays the
            // open lot the grid was blanked to, so the shed gets free asphalt on every side and its
            // clearance only ever grows past HANGAR_GAP
            var inset = HangarBlock.HANGAR_GAP - FacilityBlocks.splitProfile().gap;
            var aw = w - inset * 2;
            var ah = h - inset * 2;
            var bw = (aw < HangarBlock.HANGAR_W ? aw : HangarBlock.HANGAR_W);
            var bh = (ah < HangarBlock.HANGAR_H ? ah : HangarBlock.HANGAR_H);
            HangarBlock.generateHangar(state, node,
              node.x1 + inset + Std.int((aw - bw) / 2),
              node.y1 + inset + Std.int((ah - bh) / 2), bw, bh);

          case FacilityBlocks.PARK:
            drawBlock(cells, node.x1, node.y1, w, h, TEMP_GRASS);
            ParkBlock.generatePark(state, node.x1, node.y1, w, h);

          case FacilityBlocks.PARKING:
            // the car park writes ONE TILE and nothing else. Its plot is already the open lot the
            // grid was blanked to, so this changes no geometry — it only NAMES it, and the name is
            // what tells the renderer this lot is the one with a gate on it. Without it
            // render.facility.FacilityPaint stripes bays onto every yard that happens to touch
            // pavement and FacilityCars parks in one, because "open lot" was one tile id for the
            // car park, the yard and every 2-cell gap between plots alike.
            //
            // the ENTRYWAY child is pushed after and paints its mouth back to TEMP_ALLEY: the mouth
            // is what game.AreaGame.gate() re-derives the checkpoint from and it looks for alley
            drawBlock(cells, node.x1, node.y1, w, h, TEMP_PARKING);
            node.children.push(RoadBlock.entryRect(state, node));

          case FacilityBlocks.ENTRYWAY:
            drawBlock(cells, node.x1, node.y1, w, h, TEMP_ALLEY);

          default:
        }
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
