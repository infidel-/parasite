// decorative objects, non-interactive

package objects;

import game.Game;

class Decoration extends AreaObject
{
  public function new(g: Game, vaid: Int, vx: Int, vy: Int, row: Int, col: Int)
    {
      super(g, vaid, vx, vy);
      init();
      imageRow = row;
      imageCol = col;
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      imageCol = Const.FRAME_SEWER_HATCH;
      type = 'decoration';
      name = 'decoration';
      isStatic = true;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

  public override function known(): Bool
    { return true; }

// a washroom's DIVIDER is masonry as far as sight is concerned, and nothing else here is.
//
// it is a full-height slab (render.facility.FacilityStyle.PART_H is WALL_H - 1.0) standing on the
// room's own centre line, and the two halves it makes could see straight through each other: a
// partition cell finalises to a plain unwalkable floor id and every one of those is TILE_SEETHROUGH,
// so game.AreaGame.recalcTile had nothing to read. Answered HERE and not in the tile table because
// that id is stamped for EVERY fitting — a rack, a cabinet, a machine — and those are furniture you
// see over
  public override function canSeeThrough(): Bool
    { return (Const.fittingOf(imageRow, imageCol) != _FittingKind.FIT_PARTITION); }

  public override function visible(): Bool
    { return false; }

// stand upright in the 3D view instead of lying flat like ground clutter.
//
// every icon these draw with is painted in ELEVATION and not from above - the chem-lab set is
// fridges, fume cabinets, flasks, microscopes, drums, server racks and robot arms, all seen from the
// side (Const.CHEM_LABS_DECO_FLOOR_HIGH / _TABLE / _FLOOR_LOW, rows 8-14 of entities64). laid flat
// they read as decals of furniture printed on the floor.
//
// THE HANDFUL THAT DO LIE DOWN ARE NOW NAMED, and this comment used to say they were not worth it:
// the gloves and the calculator ARE drawn looking down at a thing on a bench, and stood upright they
// read as a pair of gloves balanced on one cuff. What made it not worth doing was the shape — a
// per-ROW table cannot say it, since those cells sit among eleven upright flasks each. Per FRAME it
// is three entries: Const.FACILITY_FLAT_DECO, applied in the 3D view alone by
// render.facility.FacilityDeco.spriteFlat, so this default stands and nothing here has to know.
// objects.DecorationExt keeps the default on purpose: that one carries a random angle and scale and
// IS floor litter
  public override function isGroundDecal(): Bool
    { return false; }
}
