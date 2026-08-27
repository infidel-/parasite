package render.wild;

import game.Game;
import map.Terrain;

// one terrain band's worth of wilderness look. everything in WildStyle that CHANGES with the band
// lives here instead; everything that does not stays there as a constant
typedef WildBandStyle = {
  // the base ground texture (render.wild.WildGround), tiled at WildStyle.GROUND_TILE like every other
  ground:String,
  // relief scale at the band EDGE and at its extreme — WildHeight's master amplitude, interpolated
  // between the two by how deep into the band the area sits. 1.0 is the field as tuned: 3.80 world
  // units peak to trough, slope p50 0.110 / max 0.164, per-cell step p50 0.272. max BELOW min is
  // legal and the plains row uses it — see there
  reliefMin:Float,
  reliefMax:Float,
  // grass tufts per open cell, and their world height (render.wild.WildGrass)
  tufts:Int,
  tuftH:Float,
  // seed chances for the two ground-patch layers (render.wild.WildPatches). bare earth reads as
  // scree up in the rocks and as nothing under a canopy; dry dead grass is the other way round
  earthChance:Float,
  deadChance:Float,
  // odds an open cell also gets a loose stone (render.wild.WildProps.small)
  smallRocks:Float,
  // PROPS index per Const.TILE_TREE1 + i, so the variant the 2D generator already rolled into the
  // saved grid still picks the model — the band only changes WHICH four models those four IDs mean
  trees:Array<Int>,
  // PROPS indices for a TILE_BUSH and a TILE_ROCK cell, picked by the cell's own hash. REPETITION IS
  // THE WEIGHT: an index listed twice in a four-entry array comes up half the time, which is one
  // mechanism for all three lists instead of a chance constant per pair
  bushes:Array<Int>,
  rocks:Array<Int>,
};

// the wilderness look, per terrain band.
//
// map.Terrain paints three bands over the region map and until now they only named areas: a mountain
// area and a forest area generated the same tile mix and rendered the same landform, so the map
// promised a landscape the area did not deliver. the band now picks the ground, the relief, the grass,
// the patches and which model each tile ID means — and game.AreaGenerator picks the tile DENSITY off
// the same band, which is the half that cannot be done here (a render layer that dropped a tree would
// leave a blocked cell looking empty).
//
// this is global static state reset per build, exactly like render.wild.WildHeight's phase offsets and
// for the same reason: there is one wilderness area on screen at a time, and WildArea.build sets both
// before anything reads them
class WildBand
{
  static var FOREST:WildBandStyle = {
    ground: 'textures/wild/ground-forest.png',
    reliefMin: 0.60,
    reliefMax: 1.00,
    tufts: 2,
    tuftH: 1.0,
    earthChance: 0.004,
    deadChance: 0.030,
    smallRocks: 0.05,
    // leafy: the bare broadleaf is demoted to the fourth slot and the dead snag drops out entirely,
    // so a wood reads as a wood rather than as a stand of skeletons
    trees: [WildStyle.TREE_CONIFER, WildStyle.TREE_BROADLEAF_FULL, WildStyle.TREE_BROADLEAF_FULL,
      WildStyle.TREE_BROADLEAF],
    bushes: [WildStyle.BUSH_LOW, WildStyle.BUSH_LOW, WildStyle.BUSH_BRAMBLE],
    rocks: [WildStyle.ROCK_BOULDER, WildStyle.LOG_FALLEN, WildStyle.LOG_FALLEN, WildStyle.ROCK_CLUSTER],
  };

  static var PLAINS:WildBandStyle = {
    ground: 'textures/wild/ground.png',
    // REVERSED on purpose, and the only row where max < min: plains depth peaks where the perlin
    // field is FLATTEST (map.Terrain.depthAt), so its deep end is the gentlest ground and its edge —
    // where the forest or the mountains start — is the roughest
    reliefMin: 0.60,
    reliefMax: 0.30,
    tufts: 3,
    tuftH: 1.3,
    earthChance: 0.008,
    deadChance: 0.013,
    smallRocks: 0.08,
    // the ONE-TO-ONE mapping the four tile IDs went in with, and the reason the other two rows are
    // written as full arrays rather than as edits to this one
    trees: [WildStyle.TREE_CONIFER, WildStyle.TREE_BROADLEAF, WildStyle.TREE_BROADLEAF_FULL,
      WildStyle.TREE_DEAD],
    bushes: [WildStyle.BUSH_LOW, WildStyle.BUSH_BRAMBLE],
    rocks: [WildStyle.ROCK_BOULDER, WildStyle.ROCK_BOULDER, WildStyle.ROCK_CLUSTER],
  };

  static var MOUNTAIN:WildBandStyle = {
    ground: 'textures/wild/ground-rock.png',
    reliefMin: 1.00,
    reliefMax: 1.80,
    tufts: 1,
    tuftH: 0.8,
    earthChance: 0.030,
    deadChance: 0.004,
    smallRocks: 0.16,
    // conifers and snags: what survives on a rock face, and nothing in leaf
    trees: [WildStyle.TREE_CONIFER, WildStyle.TREE_CONIFER, WildStyle.TREE_DEAD,
      WildStyle.TREE_BROADLEAF],
    bushes: [WildStyle.BUSH_BRAMBLE, WildStyle.BUSH_LOW],
    rocks: [WildStyle.ROCK_CLUSTER, WildStyle.ROCK_OUTCROP, WildStyle.ROCK_OUTCROP,
      WildStyle.ROCK_BOULDER],
  };

  // the active row, and the relief amplitude computed off it. plains is the safe default: anything
  // sampling the height field outside a wilderness build (WorldCtx.ground is cleared by World and
  // SewerArea, but the statics are not) reads the gentlest landform rather than a mountainside
  public static var cur:WildBandStyle = PLAINS;
  public static var reliefAmp = PLAINS.reliefMax;

// point the wilderness look at the area's terrain band. called from render.View.showWild and NOT from
// WildArea.build, which is where the rest of the per-area setup lives: the Wild model is built as the
// ARGUMENT to WildArea's constructor, so it reads the tile-to-model tables before build() runs and a
// band set there would be one area late.
//
// the band comes off the region's persisted mapSeed and the area's own map cell, exactly as area
// naming reads it (game.RegionGame.assignAreaNames), so the ground agrees with what the map paints
  public static function use(game:Game):Void
    {
      var seed = game.region.mapSeed;
      cur = switch (Terrain.bandAtArea(seed, game.area.x, game.area.y))
        {
          case TERRAIN_FOREST: FOREST;
          case TERRAIN_MOUNTAIN: MOUNTAIN;
          case TERRAIN_PLAINS: PLAINS;
        };
      var depth = Terrain.depthAt(seed, game.area.x, game.area.y);
      reliefAmp = cur.reliefMin + (cur.reliefMax - cur.reliefMin) * depth;
    }

// the PROPS index a cell's tile means in this band, given the cell's own hash. `list` is one of the
// weighted arrays above
  public static inline function pick(list:Array<Int>, hash:Int):Int
    {
      return list[hash % list.length];
    }
}
