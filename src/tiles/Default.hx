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
    // they are the only cells an open area writes that are not see-through. 14 is
    // Const.TILE_ARCHIVE_HIGH, the corp archive's full-height shelving, on the same profile, and 15
    // is Const.TILE_RACK_HIGH, a corp server rack
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

    // row 7 - floor. 11 and 12 are Const.TILE_PARKING_CAR and TILE_PARKING_CAR_ORIGIN: a parked car
    // is a solid object and the two ids exist to say so. they stay SEE-THROUGH below — a car park
    // the player cannot see across is a change to line of sight nobody asked for
    1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 0, 1, 1, 1,

    // row 8-11 - table
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    // row 12 - corpo
    0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    // row 13 - corpo: the UNWALKABLE TWINS of row 12's floors (a corp floor's twin is +16,
    // gen.corp.CorpTemp.UNWALKABLE_TILE_OFFSET), which is how every dressing gen.corp.CorpRooms
    // lays blocks its cell.
    //
    // INDEX 12 WAS A 1 AND IT IS THE BOARDROOM'S. It is TILE_FLOOR_CARPET_MEETING + 16, and it was
    // left at the value the row inherited when 13 and 14 were patched in for the cubicle and
    // server floors — so 80% of a meeting room's wall furniture (gen.corp.CorpRooms.meeting rolls
    // `bigFloorID` at smallChance 20) stood on floor you walk straight through, and rendered as
    // nothing besides. It is why room-meeting measured BOTH the emptiest kind at 16.1% fill and
    // the only one with a 0.0% furniture-pocket rate
    //
    // AND INDEX 15 WAS A 1 FOR THE SAME REASON, found before it could do the same damage: it is
    // Const.TILE_FLOOR_ARCHIVE + 16, the records room's fitting cell, and left at the inherited
    // value every file cabinet and bookcase in an archive would have been floor you walk straight
    // through — with gen.GenCheck's reachability and pocket oracles both passing, because to them
    // a walkable cell is not a fault
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    // row 14-16 - table
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    // row 17 - corpo floors past row 12 (Const.TILE_FLOOR_RECEPTION, TILE_FLOOR_EXEC_RUG) and the
    // reception counter (TILE_CORP_RECEPTION_COUNTER, unwalkable), the security room's locker and
    // wall rack (TILE_CORP_LOCKER, TILE_CORP_WALL_RACK, walkable: both stand in the wall's margin,
    // clear of their cell), and row 18 their twins
    1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    // row 19 - the military base (Const.TILE_MIL_*): fence, TORN fence (walkable), tower, tent,
    // container x2, vehicle footprint x5, the helipad (walkable) and a jersey barrier
    0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0,
    // row 20 - the base's interior (Const.TILE_MIL_FLOOR_* walkable, the furniture not, the map
    // board walkable: it marks a wall)
    1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0,
  ];
  public static var TILE_SEETHROUGH = [
    // row 0
    0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0,
    // row 1 - region
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    // row 2 - roads, indoor. index 10 is Const.TILE_WINDOW_HIGH and is the one window tile that does
    // NOT pass sight: it is a light well up under the ceiling, not a pane you look out of
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1,

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
    // row 17-18 - corpo floors and their twins
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    // row 19 - the military base: a tent and a container block sight, the chain-link, the tower's
    // legs and a parked vehicle do not
    1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    // row 20 - the base's interior: nothing in a room stands above eye height but a cubicle
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1,
  ];

// load default tileset image
  public function new()
    {
      super('img/tileset64.png');
      addFloorDecorationLayer('img/entities64.png', []);
      splatLayerID = floorDecorationLayers.length - 1;
    }

// map tile id to icon coordinates.
//
// NINE ALIASES, and the reason none of them needed art: a mark that exists so CODE can tell two
// surfaces apart still has to LOOK like the surface it marks. The car park's three are asphalt drawn
// from the alley's own cell — the lot you drive into against the yard you do not, and where a car is
// standing (Const.TILE_PARKING, TILE_PARKING_CAR). The corp office's four are the same idea indoors:
// a cubicle farm is carpet and a server room is concrete to look at, and the id is what tells them
// from the corridor and the lift lobby they share those floors with. The ARCHIVE is a THIRD of them
// and is concrete like the server room it was split off, because what its own id buys is not a look
// but an unwalkable TWIN of its own -- see Const.TILE_FLOOR_ARCHIVE
  public override function getIcon(tileID: Int): _Icon
    {
      if (tileID == Const.TILE_PARKING ||
          tileID == Const.TILE_PARKING_CAR ||
          tileID == Const.TILE_PARKING_CAR_ORIGIN)
        return super.getIcon(Const.TILE_ALLEY);
      // and the corp office's three role-only floors, which are carpet and concrete to look at
      if (tileID == Const.TILE_FLOOR_CUBICLE)
        return super.getIcon(Const.TILE_FLOOR_CARPET);
      if (tileID == Const.TILE_FLOOR_SERVER ||
          tileID == Const.TILE_FLOOR_ARCHIVE)
        return super.getIcon(Const.TILE_FLOOR_CONCRETE);
      if (tileID == Const.TILE_FLOOR_CUBICLE + 16)
        return super.getIcon(Const.TILE_FLOOR_CARPET + 16);
      // the reception is the marble it was laid in before it had an id of its own
      if (tileID == Const.TILE_FLOOR_RECEPTION)
        return super.getIcon(Const.TILE_FLOOR_MARBLE1);
      if (tileID == Const.TILE_FLOOR_RECEPTION + 16)
        return super.getIcon(Const.TILE_FLOOR_MARBLE1 + 16);
      // the counter in the reception's wall is the marble desk it replaced
      if (tileID == Const.TILE_CORP_RECEPTION_COUNTER)
        return super.getIcon(Const.TILE_DARK_TABLE_MARBLE1_1X1);
      // a locker and a wall rack are the server floor's twin they stand on
      if (tileID == Const.TILE_CORP_LOCKER ||
          tileID == Const.TILE_CORP_WALL_RACK)
        return super.getIcon(Const.TILE_FLOOR_CONCRETE);
      // and the exec rug is the boardroom's carpet, the one rug-like floor the tileset has
      if (tileID == Const.TILE_FLOOR_EXEC_RUG)
        return super.getIcon(Const.TILE_FLOOR_CARPET_MEETING);
      if (tileID == Const.TILE_FLOOR_EXEC_RUG + 16)
        return super.getIcon(Const.TILE_FLOOR_CARPET_MEETING + 16);
      if (tileID == Const.TILE_FLOOR_SERVER + 16 ||
          tileID == Const.TILE_FLOOR_ARCHIVE + 16 ||
          tileID == Const.TILE_ARCHIVE_HIGH ||
          tileID == Const.TILE_RACK_HIGH)
        return super.getIcon(Const.TILE_FLOOR_CONCRETE);
      // the military base's row has no art of its own: it is always drawn in 3D
      if (tileID >= Const.OFFSET_ROW19)
        return super.getIcon(Const.TILE_ALLEY);
      return super.getIcon(tileID);
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
