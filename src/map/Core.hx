// shared region map state and low-level helpers

package map;

import game.*;
import js.Browser;
import js.html.CanvasElement;
import js.html.CanvasRenderingContext2D;
import js.lib.Float32Array;
import js.lib.Uint8ClampedArray;
import _AreaType;
import map.SeededRandom;
import map.Types.BlockRect;
import map.Types.BuildingFootprint;
import map.Types.DensityField;
import map.Types.ParcelRect;
import map.Types.RoadMasks;
import map.Types.RoadPlanGrid;
import map.Types.RoadSegment;

typedef LanczosKernelTable = {
  var starts: Array<Int>;
  var taps: Array<Array<Float>>;
}

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
  var MAP_DEBUG_VIEW_MODE = 0; // active region-map debug view
  var ROAD_PROFILE_VERBOSE = false; // collect and print per-label road profiling detail and counters
  var ENABLE_REGION_CITY_CONTENT = true; // enable the road/building generation pipeline
  var ENABLE_REGION_CITY_BACKGROUNDS = true; // draw the legacy density-based city ground as an overlay under roads and buildings
  var REGION_CITY_BACKGROUND_ALPHA = 0.1; // opacity of the legacy density-based city ground over the terrain bands
  var MAP_LANCZOS_UPSCALE = 2; // temporary upscale/downscale factor for final postprocess
  var MAP_LANCZOS_ROUNDS = 0; // number of final postprocess rounds
  var MAP_LANCZOS_RADIUS = 3; // lanczos filter radius

  var TERRAIN_PERLIN_SCALE = 10.0; // coarse scale of the terrain perlin field in tile space
  var TERRAIN_PERLIN_OCTAVES = 3; // number of octaves used by the terrain perlin field
  var TERRAIN_PERLIN_LACUNARITY = 2.0; // frequency multiplier between terrain perlin octaves
  var TERRAIN_PERLIN_GAIN = 0.5; // amplitude multiplier between terrain perlin octaves
  var TERRAIN_PERLIN_CONTRAST = 4.0; // linear contrast multiplier applied to the raw terrain field before banding
  var TERRAIN_PERLIN_BLUR_RADIUS = 0.02; // tile-space radius used to softly blur terrain-band borders

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
  var COLOR_LOW = 0x5a5b60; // low-density urban ground tone
  var COLOR_MEDIUM = 0x6a6b71; // medium-density urban ground tone
  var COLOR_HIGH = 0x7b7c84; // high-density urban ground tone
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
  var COLOR_PLAZA = 0x6f6b61; // plaza fill tone
  var COLOR_PLAZA_EDGE = 0x8b8679; // plaza highlight tone
  var COLOR_YARD = 0x58694c; // yard fill tone
  var BUILDING_LOT_BACKGROUND_ALPHA = 0.25; // opacity of the broader lot background under building footprints
  var BUILDING_FOOTPRINT_BACKGROUND_ALPHA = 0.5; // opacity of the tight background ring under building footprints

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
  var overallDensity: Float;
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
      mapSeed = Std.random(0x7FFFFFFF);
      rng = new SeededRandom(mapSeed);
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

// apply repeated lanczos3 downscale-upscale resampling to the final visible image
  function applyFinalImagePostProcess()
    {
      if (MAP_LANCZOS_ROUNDS <= 0 ||
          MAP_LANCZOS_UPSCALE <= 1 ||
          MAP_LANCZOS_RADIUS <= 0)
        return;

      var workCanvas = canvas;
      for (i in 0...MAP_LANCZOS_ROUNDS)
        {
          var targetWidth = workCanvas.width;
          var targetHeight = workCanvas.height;
          var downscaleWidth = Std.int(Math.max(1, Math.round(targetWidth / MAP_LANCZOS_UPSCALE)));
          var downscaleHeight = Std.int(Math.max(1, Math.round(targetHeight / MAP_LANCZOS_UPSCALE)));

// shrink the final image first to introduce the broad blur
          workCanvas = resampleCanvasLanczos3(workCanvas, downscaleWidth, downscaleHeight);

// restore the original size with the same filter
          workCanvas = resampleCanvasLanczos3(workCanvas, targetWidth, targetHeight);
        }

      canvas = workCanvas;
      ctx = canvas.getContext2d({});
    }

// resize one canvas with a separable lanczos3 filter
  function resampleCanvasLanczos3(srcCanvas: CanvasElement, dstWidth: Int,
      dstHeight: Int): CanvasElement
    {
      var srcWidth = srcCanvas.width;
      var srcHeight = srcCanvas.height;
      var srcCtx = srcCanvas.getContext2d({});
      var srcImage = srcCtx.getImageData(0, 0, srcWidth, srcHeight);
      var xKernel = buildLanczosKernelTable(srcWidth, dstWidth, MAP_LANCZOS_RADIUS);
      var yKernel = buildLanczosKernelTable(srcHeight, dstHeight, MAP_LANCZOS_RADIUS);
      var tmp = resampleLanczos3Horizontal(srcImage.data, srcWidth, srcHeight, xKernel);
      var dstCanvas = Browser.document.createCanvasElement();

      dstCanvas.width = dstWidth;
      dstCanvas.height = dstHeight;
      var dstCtx = dstCanvas.getContext2d({});
      var dstImage = dstCtx.createImageData(dstWidth, dstHeight);
      resampleLanczos3Vertical(tmp, dstWidth, srcHeight, yKernel, dstImage.data);
      dstCtx.putImageData(dstImage, 0, 0);
      return dstCanvas;
    }

// build one separable lanczos3 kernel table for one axis
  function buildLanczosKernelTable(srcSize: Int, dstSize: Int, radius: Int): LanczosKernelTable
    {
      var starts = [];
      var taps = [];
      var scale = dstSize / srcSize;
      var support = (scale < 1.0 ? radius / scale : radius);

      for (dst in 0...dstSize)
        {
          var center = (dst + 0.5) / scale - 0.5;
          var start = Std.int(Math.ceil(center - support));
          var stop = Std.int(Math.floor(center + support));
          var weights = [];
          var total = 0.0;

          for (src in start...stop + 1)
            {
              var weight = getLanczosWeight(center - src, scale, radius);
              weights.push(weight);
              total += weight;
            }

          if (total <= 0.0)
            {
              start = clampInt(Std.int(Math.round(center)), 0, srcSize - 1);
              weights = [1.0];
              total = 1.0;
            }

          for (i in 0...weights.length)
            weights[i] = weights[i] / total;

          starts.push(start);
          taps.push(weights);
        }

      return {
        starts: starts,
        taps: taps,
      };
    }

// resample one image horizontally with one lanczos3 kernel table
  function resampleLanczos3Horizontal(src: Uint8ClampedArray, srcWidth: Int, srcHeight: Int,
      kernel: LanczosKernelTable): Float32Array
    {
      var dstWidth = kernel.starts.length;
      var dst = new Float32Array(dstWidth * srcHeight * 4);

      for (yy in 0...srcHeight)
        for (xx in 0...dstWidth)
          {
            var start = kernel.starts[xx];
            var weights = kernel.taps[xx];
            var dstIndex = (yy * dstWidth + xx) * 4;
            var r = 0.0;
            var g = 0.0;
            var b = 0.0;
            var a = 0.0;

            for (i in 0...weights.length)
              {
                var srcX = clampInt(start + i, 0, srcWidth - 1);
                var srcIndex = (yy * srcWidth + srcX) * 4;
                var weight = weights[i];

                r += src[srcIndex] * weight;
                g += src[srcIndex + 1] * weight;
                b += src[srcIndex + 2] * weight;
                a += src[srcIndex + 3] * weight;
              }

            dst[dstIndex] = r;
            dst[dstIndex + 1] = g;
            dst[dstIndex + 2] = b;
            dst[dstIndex + 3] = a;
          }

      return dst;
    }

// resample one image vertically with one lanczos3 kernel table
  function resampleLanczos3Vertical(src: Float32Array, srcWidth: Int, srcHeight: Int,
      kernel: LanczosKernelTable, dst: Uint8ClampedArray)
    {
      var dstHeight = kernel.starts.length;

      for (yy in 0...dstHeight)
        {
          var start = kernel.starts[yy];
          var weights = kernel.taps[yy];

          for (xx in 0...srcWidth)
            {
              var dstIndex = (yy * srcWidth + xx) * 4;
              var r = 0.0;
              var g = 0.0;
              var b = 0.0;
              var a = 0.0;

              for (i in 0...weights.length)
                {
                  var srcY = clampInt(start + i, 0, srcHeight - 1);
                  var srcIndex = (srcY * srcWidth + xx) * 4;
                  var weight = weights[i];

                  r += src[srcIndex] * weight;
                  g += src[srcIndex + 1] * weight;
                  b += src[srcIndex + 2] * weight;
                  a += src[srcIndex + 3] * weight;
                }

              dst[dstIndex] = clampInt(Std.int(Math.round(r)), 0, 255);
              dst[dstIndex + 1] = clampInt(Std.int(Math.round(g)), 0, 255);
              dst[dstIndex + 2] = clampInt(Std.int(Math.round(b)), 0, 255);
              dst[dstIndex + 3] = clampInt(Std.int(Math.round(a)), 0, 255);
            }
        }
    }

// return one lanczos sample weight with anti-alias widening on downscale
  function getLanczosWeight(distance: Float, scale: Float, radius: Int): Float
    {
      var x = Math.abs(distance);
      if (scale < 1.0)
        x *= scale;

      if (x >= radius)
        return 0.0;
      if (x < 0.000001)
        return 1.0;

      return getSincSample(Math.PI * x) * getSincSample(Math.PI * x / radius);
    }

// return one normalized sinc sample
  function getSincSample(x: Float): Float
    {
      if (Math.abs(x) < 0.000001)
        return 1.0;
      return Math.sin(x) / x;
    }

// return whether a candidate line is far enough from others
  function isFarFromLines(line: Int, list: Array<Int>, spacing: Int): Bool
    {
      for (other in list)
        if (Math.abs(other - line) < spacing)
          return false;
      return true;
    }

// return a center-biased connector coordinate
  function pickConnectorCoordinate(min: Int, max: Int, index: Int, count: Int): Int
    {
      if (max <= min)
        return min;
      var ratio = (index + 1) / (count + 1);
      var jitter = (rng.nextFloat() - 0.5) * 0.22;
      var span = max - min;
      return clampInt(min + Std.int(span * clampFloat(ratio + jitter, 0.15, 0.85)),
        min, max);
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

}
