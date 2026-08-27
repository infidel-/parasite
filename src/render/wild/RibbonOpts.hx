package render.wild;

// everything one alpha-cut ribbon of the highway needs: the art it draws with, where it sits in the
// ground stack, how wide it is, and how its outer edge is carved.
//
// replaces the signature `WildRoad.edgeMask(m, areaID)` + `WildRoad.surface(scene, mat, m)` grew into
// once the verge became a second ribbon of the same shape — halfW, band, reach, rMin, rMax, step,
// along, across, salt and tile would have been ten positional numbers of which eight are bare floats.
//
// the two ribbons differ in KIND and not only in size, which is why this is one typedef rather than a
// scale factor: asphalt is a manufactured edge that may only crumble (R_MAX 0.4, an 8-16 pixel nick),
// while the verge's outer edge is dirt meeting vegetation and is allowed to be genuinely chewed
// (R_MAX 1.1). the same number is right on one and wrong on the other
typedef RibbonOpts = {
  tex:String,      // the art, a WildStyle path
  tile:Float,      // world units per texture repeat, both axes. NOT a multiple of CELL — see WildStyle.GROUND_TILE
  y:Float,         // lift off the graded ground, above whatever layer this covers
  order:Float,     // renderOrder within the transparent queue. must be UNIQUE per ground layer, or
                   // three falls back to a back-to-front distance sort and near-coplanar layers flicker
  halfW:Float,     // NOMINAL half-width in world units: the straight line the stamps are centred on
  reach:Float,     // mesh half-reach in CELLS, from the centreline. must exceed halfW/CELL by enough to
                   // hold the furthest texel a stamp can paint, or the blob is cut off by a straight
                   // mesh edge — the exact artifact the mask exists to remove
  rMin:Float,      // smallest stamp radius, world units. sets the mask resolution: a stamp needs ~2
                   // texels of radius or alphaTest turns it into a speckle
  rMax:Float,      // largest stamp radius, world units — the SIZE OF ONE DEFORMITY, and the only
                   // number here anyone will notice. judge it in screen pixels (~39 px per world unit
                   // at the wilderness camera), not in the abstract
  step:Float,      // world units between stamps down one edge. must stay UNDER 2 * rMin or consecutive
                   // stamps leave gaps, and a gap is the nominal straight line showing through
  along:Int,       // mask canvas texels down the corridor
  across:Int,      // mask canvas texels across it
  salt:Int,        // hash salt, so two ribbons over the same area carve differently
  cls:String,      // render.Poly.tag class
  label:String,    // render.Poly.tag human label
};
