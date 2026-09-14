// the compound's street frontage
//
// the carriageway, the pavement beside it, the sewer hatches down that pavement, and the MOUTH
// through it that the parking lot is entered by.
//
// IT IS NOT PART OF THE SPLIT. Which edge the road lies on is decided outside the tree and
// FacilityBlocks.plan reserves its band before it cuts anything, the same way
// game.AreaGenerator.placeHighway runs before the wilderness is laid. This node is attached to the
// root ahead of the quota's blocks so the pavement is down before anything aprons onto it.

package gen.blocks;

import game.AreaGenerator.*;
import gen.GenTree;
import gen.facility._FacilityState;
import gen.facility.FacilityTemp.*;

class RoadBlock
{
  // how wide the mouth through the pavement is. game.AreaGame.gate() re-derives the checkpoint from
  // exactly this hole on every load — the bounding box of every open-lot cell within the pavement's
  // own depth of the road — so its shape is not cosmetic, and there must be exactly ONE of it. That
  // is why the pavement band runs the FULL width of the area and only this breaks it
  public static inline var ENTRY_W = 4;
  // one sewer hatch every this many pavement cells, plus a roll on top
  static inline var SEWER_MIN = 10;
  static inline var SEWER_SPREAD = 10;

// the node covering the carriageway and its pavement, off whichever edge the compound faces
  public static function node(state: _FacilityState): _GenNode
    {
      var band = FacilityBlocks.ROAD_W + FacilityBlocks.SIDEWALK_W;
      var y1 = (state.mainRoadNorth ? 0 : state.area.height - band);
      return GenTree.root(FacilityBlocks.ROAD, 0, y1, state.area.width - 1, y1 + band - 1);
    }

// lay the band: carriageway against the edge, pavement inside it, hatches down the pavement row that
// touches the carriageway.
//
// the hatches run the WHOLE pavement and step over the mouth. The arithmetic version stopped at the
// mouth and never resumed, which cost nothing when the mouth was hardcoded at three quarters of the
// width — but the mouth is wherever the parking plot landed now, and a plot on the left took the
// mean from 3.95 hatches per compound to 1.85, with compounds getting none at all. A hatch is a way
// into the sewers, so that is a gameplay regression and not a layout one
  public static function fill(state: _FacilityState, node: _GenNode)
    {
      var area = state.area;
      var cells = area.getCells();
      var ry = (state.mainRoadNorth ? node.y1 : node.y2 - FacilityBlocks.ROAD_W + 1);
      var sy = (state.mainRoadNorth ? node.y1 + FacilityBlocks.ROAD_W : node.y1);
      drawBlock(cells, 0, ry, area.width, FacilityBlocks.ROAD_W, TEMP_ROAD);
      drawBlock(cells, 0, sy, area.width, FacilityBlocks.SIDEWALK_W, TEMP_WALKWAY);

      // the mouth is punched by the ENTRYWAY node one level down, so it is not on the grid yet — but
      // the parking plot it is centred on was dealt at plan time, so where it WILL be is already
      // known. a compound whose quota went unsatisfied has no parking plot and so no mouth at all
      var parking = GenTree.find(area.root, FacilityBlocks.PARKING);
      var entry = (parking != null ? entryRect(state, parking) : null);
      var cnt = 0;
      var dist = SEWER_MIN + area.random(SEWER_SPREAD);
      for (x in 0...area.width)
        {
          cnt++;
          if (cnt < dist)
            continue;
          if (entry != null &&
              x >= entry.x1 &&
              x <= entry.x2)
            continue;
          area.add('sewerHatch', x,
            sy + (state.mainRoadNorth ? 0 : FacilityBlocks.SIDEWALK_W - 1));
          cnt = 0;
        }
    }

// the mouth through the pavement, centred on the parking plot: a plain ENTRY_W x SIDEWALK_W hole of
// open lot, which is all gate() looks for. Returned UNATTACHED — FacilityGen hangs it off the
// parking node so it is filled a level later, after every plot has aprons onto the pavement band and
// can no longer pave over it
  public static function entryRect(state: _FacilityState, parking: _GenNode): _GenNode
    {
      var sy = (state.mainRoadNorth ? FacilityBlocks.ROAD_W :
        state.area.height - FacilityBlocks.ROAD_W - FacilityBlocks.SIDEWALK_W);
      var x1 = parking.x1 + Std.int((GenTree.width(parking) - ENTRY_W) / 2);
      return GenTree.root(FacilityBlocks.ENTRYWAY, x1, sy, x1 + ENTRY_W - 1,
        sy + FacilityBlocks.SIDEWALK_W - 1);
    }
}
