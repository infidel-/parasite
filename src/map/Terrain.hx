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

// terrain band at an area's center tile, matching the rendered map for this seed
  public static function bandAtArea(seed: Int, x: Int, y: Int): _TerrainBand
    {
      var t = TerrainNoise.sampleFractal(seed,
        (x + 0.5) / SCALE,
        (y + 0.5) / SCALE,
        OCTAVES, LACUNARITY, GAIN) * CONTRAST;
      if (t < FOREST_THRESHOLD)
        return TERRAIN_FOREST;
      if (t > MOUNTAIN_THRESHOLD)
        return TERRAIN_MOUNTAIN;
      return TERRAIN_PLAINS;
    }
}
