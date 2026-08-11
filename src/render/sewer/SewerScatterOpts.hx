package render.sewer;

// one image in a scatter, with the world footprint it is drawn at
typedef SewerDecalType = {
  // baked decal image; alpha is hand-cut (textures.json class "sprite")
  tex:String,
  // footprint width in world units, before jitter and rotation
  w:Float,
  // footprint depth in world units, before jitter and rotation
  d:Float,
  // material opacity. 1 for anything SOLID — blending an iron valve to fix its value just makes a
  // see-through valve. only genuinely translucent art (standing water, a stain) belongs below 1;
  // art that is merely too dark is fixed by the `lift` in textures.json, which brightens the source
  alpha:Float,
  // organic (a puddle, a moss patch, a rubble pile) vs manufactured (a pipe, a valve, a grate).
  // organics take a free rotation and independent per-axis scale jitter, because no two are alike.
  // manufactured parts are NEVER turned and jitter uniformly: they come out of a mould, and a drain
  // grate sitting at 23 degrees reads as a mistake rather than as variety
  organic:Bool,
};

// options for render.sewer.SewerGround.scatter. replaces the positional signature
// (scene, m, types, pct, y, margin, solid), which was five bare values at the call site — two of
// them numbers in the same range and one a naked bool, i.e. silently mis-orderable
typedef SewerScatterOpts = {
  // one entry per image. each merges into its own mesh, so this is also the pass's draw-call count
  types:Array<SewerDecalType>,
  // % of eligible CELLS that get a decal (the block gate below converts it to a per-block rate)
  pct:Int,
  // height above the surface the quads lie on
  y:Float,
  // keep a decal this far inside its cell's edges
  margin:Float,
  // walk SOLID cells (the ledge plateau) instead of floor cells. also selects the hash multipliers,
  // and gates the floor-only halved rate in generator rooms
  solid:Bool,
  // let an ORGANIC decal spill over its cell edges where the whole 3x3 around it is the same
  // surface. false on the ledge, where most cells are a one-cell-wide wall with a drop either side
  cross:Bool,
};
