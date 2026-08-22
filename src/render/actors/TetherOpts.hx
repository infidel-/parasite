package render.actors;

import render.actors.Ribbon.RibbonPass;
import render.world.ObjModels.PropTether;

// one pass of one tether's ribbon, for render.actors.PropFX.tetherRibbon. it exists for the reason
// render.actors.BoltOpts does, and shares all but one field with it — which is why both now extend
// RibbonPass rather than each restating the same fourteen.
//
// a cord spans two cells and bows over the gap, so there is no local frame it could sensibly be
// authored in; RibbonPass carries that note along with the fields it applies to
typedef TetherOpts = {
  > RibbonPass,
  tether:PropTether, // the row this cord is authored by: segs, lift, jag, width, taper and glow are
                     // read off it, so the two passes cannot disagree about the shape
};
