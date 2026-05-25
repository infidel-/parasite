// shared region map state and low-level helpers

package map;

import game.*;
import js.Browser;
import js.html.CanvasElement;
import js.html.CanvasRenderingContext2D;
import js.lib.Float32Array;
import js.lib.Uint8Array;
import _AreaType;
import map.SeededRandom;
import map.Types.BlockRect;
import map.Types.BuildingFootprint;
import map.Types.DensityField;
import map.Types.ParcelRect;
import map.Types.RoadMasks;
import map.Types.RoadPlanGrid;
import map.Types.RoadSegment;

class Core
{
  var HALO_CELLS = 2; // halo tile count around the visible region
  var CLEAN_TILE_SIZE = Const.TILE_SIZE_CLEAN; // source pixel size of one region tile
  var PLAN_CELL_SIZE = 8; // raster road cell size in pixels
  var PLAN_CELLS_PER_TILE = 8; // number of road plan cells inside one region tile
  var MAP_DEBUG_VIEW_NORMAL = 0; // draw the normal cached region map
  var MAP_DEBUG_VIEW_GROUND = 1; // draw only the ground layer
  var MAP_DEBUG_VIEW_TERRAIN_RAW = 2; // draw the raw terrain field
  var MAP_DEBUG_VIEW_TERRAIN_BANDS = 3; // draw the classified terrain bands without city overlays
  var MAP_DEBUG_DUMP_PNGS = false; // dump debug view images during generation in electron
  var MAP_DEBUG_DUMP_BUILDING_RECTS = false; // dump building rectangles during generation in electron
  var MAP_DEBUG_VIEW_MODE = 0; // active region-map debug view
  var ROAD_PROFILE = false; // emit MAP PROFILE trace lines via profile()
  var ROAD_PROFILE_VERBOSE = false; // collect and print per-label road profiling detail and counters
  var ENABLE_REGION_CITY_CONTENT = true; // enable the road/building generation pipeline
  var ENABLE_REGION_CITY_BACKGROUNDS = true; // draw the legacy density-based city ground as an overlay under roads and buildings
  var REGION_CITY_BACKGROUND_ALPHA = 0.15; // opacity of the legacy density-based city ground over the terrain bands
  var REGION_CITY_BACKGROUND_EDGE_FADE_PIXELS = 6; // pixel width used to fade city background perimeters

  var TERRAIN_PERLIN_SCALE = 10.0; // coarse scale of the terrain perlin field in tile space
  var TERRAIN_PERLIN_OCTAVES = 3; // number of octaves used by the terrain perlin field
  var TERRAIN_PERLIN_LACUNARITY = 2.0; // frequency multiplier between terrain perlin octaves
  var TERRAIN_PERLIN_GAIN = 0.5; // amplitude multiplier between terrain perlin octaves
  var TERRAIN_PERLIN_CONTRAST = 4.0; // linear contrast multiplier applied to the raw terrain field before banding
  var TERRAIN_CACHE_STEP_PIXELS = 4; // pixel spacing used by the cached terrain field sampler
  var TERRAIN_EDGE_ANTIALIAS_WIDTH = 0.005; // terrain-value half-width used to antialias terrain-band borders

  var TERRAIN_FOREST_THRESHOLD = -0.5; // terrain field value below which tiles render as forest
  var TERRAIN_MOUNTAIN_THRESHOLD = 0.5; // terrain field value above which tiles render as mountains
  var ROAD2_GRID_STEP = 2; // plan-grid step used by road2 growth
  var ROAD2_MIN_SPAWN_GAP = 16; // minimum gap between road2 spawns
  var ROAD_BRANCH_MIN_TURN_STEPS = 16; // minimum branch length before turning
  var ROAD_HIT_CONTINUE_STEPS = 8; // steps allowed when a branch hits an occupied cell
  var ROAD2_MIN_CITY_DENSITY = 0.12; // minimum density for spawning road2 coverage
  var ENABLE_ROAD3_COVERAGE_PASS = true; // enable the supplemental road3 coverage sweep
  var ROAD3_T_SPLIT_STEPS = 32; // road3 distance between T split opportunities
  var ROAD3_GROUND_STOP_CHANCE_STEP = 0.10; // chance increment for stopping road3 in ground tiles
  var DOWNTOWN_ROAD4_COVERAGE_CHANCE = 0.40; // downtown chance to add road4 coverage
  var DOWNTOWN_ROAD5_COVERAGE_CHANCE = 0.0; // downtown chance to add road5 coverage
  var THIN_CROSSING_INTERVAL = 4; // step interval for thin crossing attempts
  var THIN_CROSSING_RIGHT_CHANCE = 0.40; // chance for a thin crossing on the right side
  var THIN_CROSSING_LEFT_CHANCE = 0.40; // chance for a thin crossing on the left side
  var ROAD2_TILE_COVERAGE_DISTANCE = 8; // road2 coverage radius measured in tiles
  var MIN_CITY_TILE_ROAD_COVERAGE = 0.20; // minimum road coverage target for city tiles
  var MAX_CITY_COVERAGE_TURN_DISTANCE = 6; // maximum turn distance when seeking city coverage

  var COLOR_GROUND = 0x5a6b34; // base wilderness green
  var COLOR_LOW = 0x3a3b40; // low-density urban ground tone
  var COLOR_MEDIUM = 0x4a4b41; // medium-density urban ground tone
  var COLOR_HIGH = 0x6b6c64; // high-density urban ground tone
  var COLOR_FOREST_MID = 0x194508; // mid forest canopy tone
  var COLOR_MOUNTAIN = 0x6f7066; // mountain terrain tone used by the three-band terrain renderer

  var COLOR_ROAD1 = 0x171716; // primary road palette anchor
  var COLOR_ROAD2 = 0xd07a23; // secondary road palette anchor
  var COLOR_ROAD3 = 0x3aa354; // tertiary road palette anchor
  var COLOR_ROAD4 = 0xa33232; // quaternary road palette anchor
  var COLOR_ROAD5 = 0x3f6fd6; // minor road palette anchor

  var COLOR_BUILDING_LOW = 0x585349; // low-density building base tone
  var COLOR_BUILDING_MEDIUM = 0x49453d; // medium-density building base tone
  var COLOR_BUILDING_HIGH = 0x343333; // high-density building base tone
  var COLOR_BUILDING_SHADOW = 0x1a1a1a; // shared building shadow tone
  var COLOR_PLAZA = 0x3f3b31; // plaza fill tone
  var COLOR_PLAZA_EDGE = 0x5b5649; // plaza highlight tone
  var COLOR_YARD = 0x38492c; // yard fill tone
  var BUILDING_LOT_BACKGROUND_ALPHA = 0.25; // opacity of the broader lot background under building footprints
  var BUILDING_FOOTPRINT_BACKGROUND_ALPHA = 0.4; // opacity of the tight background ring under building footprints

  var game: Game;
  var canvas: CanvasElement;
  var ctx: CanvasRenderingContext2D;
  var regionWidth: Int;
  var regionHeight: Int;
  var fullCellWidth: Int;
  var fullCellHeight: Int;
  var fullPixelWidth: Int;
  var fullPixelHeight: Int;
  var planWidth: Int;
  var planHeight: Int;
  var mapSeed: Int;
  var rng: SeededRandom;
  var densityField: DensityField;
  var areaTypes: Array<Array<_AreaType>>;
  var terrainFieldCache: Float32Array;
  var terrainFieldCacheWidth: Int;
  var terrainFieldCacheHeight: Int;
  var cityBackgroundMask: Uint8Array;
  var cityBackgroundPixelCount: Int;
  var roads: Array<RoadSegment>;
  var roadMasks: RoadMasks;
  var roadPlanGrid: RoadPlanGrid;
  var blocks: Array<BlockRect>;
  var parcels: Array<ParcelRect>;
  var buildings: Array<BuildingFootprint>;
  var nextRoad2ID: Int;

  public function new(g: Game)
    {
      game = g;
    }

// initialize region and canvas dimensions
  function initRegionMetrics()
    {
      var region = game.region;
      regionWidth = region.width;
      regionHeight = region.height;
      fullCellWidth = regionWidth + HALO_CELLS * 2;
      fullCellHeight = regionHeight + HALO_CELLS * 2;
      fullPixelWidth = fullCellWidth * CLEAN_TILE_SIZE;
      fullPixelHeight = fullCellHeight * CLEAN_TILE_SIZE;
      planWidth = Std.int(fullPixelWidth / PLAN_CELL_SIZE);
      planHeight = Std.int(fullPixelHeight / PLAN_CELL_SIZE);
      roads = [];
      roadPlanGrid = null;
      blocks = [];
      parcels = [];
      buildings = [];
      nextRoad2ID = 0;
    }

// initialize the working canvas
  function initCanvas()
    {
      canvas = Browser.document.createCanvasElement();
      canvas.width = fullPixelWidth;
      canvas.height = fullPixelHeight;
      ctx = canvas.getContext2d({});
    }

// initialize deterministic random state
  function initRandom()
    {
      mapSeed = game.region.mapSeed;
      rng = new SeededRandom(mapSeed);
      terrainFieldCache = null;
      terrainFieldCacheWidth = 0;
      terrainFieldCacheHeight = 0;
      cityBackgroundMask = null;
      cityBackgroundPixelCount = 0;
    }

  function cropVisibleRegion()
    {
      var cropCanvas = Browser.document.createCanvasElement();
      var cropCtx = cropCanvas.getContext2d({});
      var haloOffset = HALO_CELLS * CLEAN_TILE_SIZE;

      cropCanvas.width = regionWidth * CLEAN_TILE_SIZE;
      cropCanvas.height = regionHeight * CLEAN_TILE_SIZE;
      cropCtx.drawImage(canvas,
        haloOffset, haloOffset,
        cropCanvas.width, cropCanvas.height,
        0, 0,
        cropCanvas.width, cropCanvas.height);

      canvas = cropCanvas;
      ctx = cropCtx;
    }

  function hashFloat(x: Int, y: Int, salt: Int): Float
    {
      var n = x * 374761393 + y * 668265263 + salt * 1442695041;
      n = (n ^ (n >> 13)) * 1274126177;
      n = n ^ (n >> 16);
      return (n & 0x7FFFFFFF) / 2147483647.0;
    }

// return a color interpolated between two rgb ints
  function lerpColor(c1: Int, c2: Int, t: Float): Int
    {
      var tt = clampFloat(t, 0.0, 1.0);
      var r1 = (c1 >> 16) & 0xFF;
      var g1 = (c1 >> 8) & 0xFF;
      var b1 = c1 & 0xFF;
      var r2 = (c2 >> 16) & 0xFF;
      var g2 = (c2 >> 8) & 0xFF;
      var b2 = c2 & 0xFF;

      var r = Std.int(r1 + (r2 - r1) * tt);
      var g = Std.int(g1 + (g2 - g1) * tt);
      var b = Std.int(b1 + (b2 - b1) * tt);
      return (r << 16) | (g << 8) | b;
    }

// return a brightness-adjusted rgb int
  function adjustColor(color: Int, factor: Float): Int
    {
      var r = clampInt(Std.int(((color >> 16) & 0xFF) * factor), 0, 255);
      var g = clampInt(Std.int(((color >> 8) & 0xFF) * factor), 0, 255);
      var b = clampInt(Std.int((color & 0xFF) * factor), 0, 255);
      return (r << 16) | (g << 8) | b;
    }

// return deterministic 0..1 noise from a few integer inputs
  function getStableNoise(a: Int, b: Int, c: Int, d: Int, salt: Int): Float
    {
      var hash = salt;
      hash = hash ^ (a * 73856093);
      hash = hash ^ (b * 19349663);
      hash = hash ^ (c * 83492791);
      hash = hash ^ (d * 265443576);
      hash = (hash ^ (hash >> 13)) * 1274126177;
      hash = hash ^ (hash >> 16);
      return (hash & 0x7FFFFFFF) / 0x7FFFFFFF;
    }

// allocate a float grid
  function makeFloatGrid(width: Int, height: Int): Array<Array<Float>>
    {
      var grid = [];
      for (xx in 0...width)
        {
          var col = [];
          for (yy in 0...height)
            col.push(0.0);
          grid.push(col);
        }
      return grid;
    }

// allocate an int grid
  function makeIntGrid(width: Int, height: Int): Array<Array<Int>>
    {
      var grid = [];
      for (xx in 0...width)
        {
          var col = [];
          for (yy in 0...height)
            col.push(0);
          grid.push(col);
        }
      return grid;
    }

// allocate a bool grid
  function makeBoolGrid(width: Int, height: Int): Array<Array<Bool>>
    {
      var grid = [];
      for (xx in 0...width)
        {
          var col = [];
          for (yy in 0...height)
            col.push(false);
          grid.push(col);
        }
      return grid;
    }

// return an inclusive random integer
  function randomRangeInt(min: Int, max: Int): Int
    {
      if (max <= min)
        return min;
      return min + rng.next() % (max - min + 1);
    }

// return a random float in range
  function randomRangeFloat(min: Float, max: Float): Float
    {
      if (max <= min)
        return min;
      return min + (max - min) * rng.nextFloat();
    }

// clamp an int to bounds
  function clampInt(v: Int, min: Int, max: Int): Int
    {
      if (v < min)
        return min;
      if (v > max)
        return max;
      return v;
    }

// clamp a float to bounds
  function clampFloat(v: Float, min: Float, max: Float): Float
    {
      if (v < min)
        return min;
      if (v > max)
        return max;
      return v;
    }

// sort ints in ascending order
  function sortInt(a: Int, b: Int): Int
    {
      return a - b;
    }

// trace one MAP PROFILE line gated by ROAD_PROFILE (debug only)
  function profile(prefix: String, msg: String)
    {
      if (!Const.isDebug || !ROAD_PROFILE)
        return;
      trace('MAP PROFILE ' + prefix + ' ' + msg);
    }

}
