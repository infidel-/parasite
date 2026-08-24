package render.world;

// the per-area-kind tuning of render.world.VisionMask.
//
// this replaces the block of `SewerStyle.MASK_*` statics the mask used to read directly, which is what
// pinned it to one area kind: every constant below was reachable only as a sewer constant, so a second
// caller could not have differed on ONE of them without forking the file. the presets are
// SewerStyle.MASK and WildStyle.MASK, and the long-form rationale for each value stays with the preset
// that measured it rather than moving here — the comments below only say what a field IS.
//
// VisionMask holds the live one in a static, set by attach(), because exactly one area is ever built
typedef VisionMaskOpts = {
  // how far a hidden fragment sinks toward the fog colour. 0 = the 2D view's flat black
  hidden:Float,
  // the same floor for ADDITIVE emissives, which need a harder one than the surface they sit on
  hiddenAdd:Float,
  // mask texels per cell: how finely the visibility polygon is sampled
  px:Int,
  // gaussian sigma the visibility plane is blurred by on its way into the mask, in WORLD units
  blur:Float,
  // how deep into a lit blocker cell the mask fades where it touches one the sweep never reached, in cells
  wallFade:Float,
  // how far the AREA'S OUTER RIM fades out, in cells (the mask's blue channel)
  edgeFade:Float,
  // how far the boundary wanders from where the polygon put it, in WORLD units. blocker cells only
  wobble:Float,
  // how far the smoothed origin must travel, in cells, before the polygon is rebuilt
  step:Float,
  // radius in cells the polygon is built over. the sweep is O(rays * segments), so this is the cost knob
  r:Int,
}
