// terrain band classification for naming (reproduces the map renderer's perlin field)

package map;

// terrain band an area sits on
enum _TerrainBand
{
  TERRAIN_FOREST;
  TERRAIN_PLAINS;
  TERRAIN_MOUNTAIN;
}

class Terrain
{
  // perlin params - keep in sync with map/Core.hx:41-50
  // ponytail: literals duplicated from the renderer (instance-scoped there); naming runs
  // with no renderer instance, so dup beats threading a Ground instance through gen/load
  static inline var SCALE = 10.0;
  static inline var OCTAVES = 3;
  static inline var LACUNARITY = 2.0;
  static inline var GAIN = 0.5;
  static inline var CONTRAST = 4.0;
  static inline var FOREST_THRESHOLD = -0.5;
  static inline var MOUNTAIN_THRESHOLD = 0.5;

// terrain band at an area's center tile, matching the rendered map for this seed.
//
// the HALO OFFSET is the load-bearing part, and it is why this used to disagree with the map on
// ~40% of tiles. map.Core rasterizes the WHOLE canvas, halo included, and samples the perlin field
// at full-canvas tile coordinates ((px + 0.5) / CLEAN_TILE_SIZE over full pixels, see
// buildTerrainFieldCache), while a region tile index is recovered by subtracting HALO_CELLS
// (map/Ground.hx). So region tile (x,y) is painted from the field at (x + HALO, y + HALO), and
// sampling here at (x, y) named an area from a band two tiles away — "Bald Mountain" on green, and
// visible mountains left as the generic "Uninhabited area". Measured over 4 seeds x 3600 tiles:
// 58.5-62.1% agreement before, 0 mismatches in 14400 after. The constants above never drifted; the
// FRAME did, because it was not in the list they were being kept in sync against
  public static function bandAtArea(seed: Int, x: Int, y: Int): _TerrainBand
    {
      var t = sample(seed, x, y);
      if (t < FOREST_THRESHOLD)
        return TERRAIN_FOREST;
      if (t > MOUNTAIN_THRESHOLD)
        return TERRAIN_MOUNTAIN;
      return TERRAIN_PLAINS;
    }

// how far into its OWN band an area sits: 0 at the band edge, 1 at the extreme. forest and mountain
// run outward from their thresholds to the clamped +/-1; plains runs the other way, because it is the
// band with no character of its own and its "extreme" is the flat middle of the field. the wilderness
// scales relief and prop density by this, so a deep forest is denser than one a tile from the plains
// and the two do not snap at the threshold
  public static function depthAt(seed: Int, x: Int, y: Int): Float
    {
      var t = sample(seed, x, y);
      if (t < FOREST_THRESHOLD)
        return (FOREST_THRESHOLD - t) / (1.0 + FOREST_THRESHOLD);
      if (t > MOUNTAIN_THRESHOLD)
        return (t - MOUNTAIN_THRESHOLD) / (1.0 - MOUNTAIN_THRESHOLD);
      return 1.0 - Math.abs(t) / MOUNTAIN_THRESHOLD;
    }

// the raw contrast-scaled field at an area's center tile, in the renderer's own coordinate frame.
// the clamp mirrors Core.sampleTerrainFieldRawAtCoord: it cannot change a band (both thresholds are
// well inside +/-1), but it makes the two paths provably identical instead of incidentally so.
// exposed because the wilderness generator wants the VALUE, not just the band — how far into the
// mountain band a tile sits is what scales its terrain relief
  public static function sample(seed: Int, x: Int, y: Int): Float
    {
      var t = TerrainNoise.sampleFractal(seed,
        (x + Core.HALO_CELLS + 0.5) / SCALE,
        (y + Core.HALO_CELLS + 0.5) / SCALE,
        OCTAVES, LACUNARITY, GAIN) * CONTRAST;
      return t < -1.0 ? -1.0 : (t > 1.0 ? 1.0 : t);
    }
}
