// default tile wrapper for base tileset image

package tiles;

class Default extends Tileset
{
  public static var STREET_DEBRIS_LAYER_ID = 0;

  public static var TILE_WALKABLE = [
    // row 0. TILE_ROCK (3) is UNWALKABLE, matching the four tree tiles (5-8) beside it: it is written
    // only by game.AreaGenerator.generateWilderness, and render.wild.WildProps stands a boulder or a
    // rock cluster on every one of those cells, so a walkable rock was geometry the player could step
    // through. it stays see-through below, again like the trees. nothing to migrate - walkability is a
    // static table and not persisted, area entry re-tests it live through AreaGame.findEmptyLocation,
    // and movement tests the TARGET cell, so an actor saved standing on a rock can still walk off it.
    //
    // 12 and 13 are Const.TILE_ROCK_LARGE and TILE_TREE_CLUSTER, the wilderness's two MULTI-CELL
    // obstacles, and neither needed an edit here or in TILE_SEETHROUGH below: row 0's spare slots were
    // already 0/0, the TILE_BUILDING / TILE_WALL profile, so naming them was the whole gameplay half.
    // they are the only cells an open area writes that are not see-through
    0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0,
    // row 1 - region
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    // row 2 - roads, indoor
    1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1,

    // row 3+ - city tiles
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,

    // row 7 - floor
    1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1,

    // row 8-11 - table
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    // row 12 - corpo
    0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    // row 13 - corpo
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1,
    // row 14-16 - table
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  ];
  public static var TILE_SEETHROUGH = [
    // row 0
    0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0,
    // row 1 - region
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    // row 2 - roads, indoor
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,

    // row 3+ - region tiles
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,

    // row 7 - floor
    1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1,

    // row 8-11 - table
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    // row 12 - corpo
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    // row 13 - corpo
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    // row 14-16 - table
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  ];

// load default tileset image
  public function new()
    {
      super('img/tileset64.png');
      addFloorDecorationLayer('img/entities64.png', []);
      splatLayerID = floorDecorationLayers.length - 1;
    }

// check if default tile is walkable
  public override function isWalkable(tileID: Int): Bool
    {
      if (tileID < 0 ||
          tileID >= TILE_WALKABLE.length)
        return false;
      return TILE_WALKABLE[tileID] == 1;
    }

// check if default tile can be seen through
  public override function canSeeThrough(tileID: Int): Bool
    {
      if (tileID < 0 ||
          tileID >= TILE_SEETHROUGH.length)
        return false;
      return TILE_SEETHROUGH[tileID] == 1;
    }
}
