// shared region map state and low-level helpers

package map;

import game.*;
import js.Browser;
import js.html.CanvasElement;
import js.html.CanvasRenderingContext2D;
import _AreaType;
import map.SeededRandom;
import map.Types.BlockRect;
import map.Types.BuildingFootprint;
import map.Types.DensityField;
import map.Types.ParcelRect;
import map.Types.RoadMasks;
import map.Types.RoadSegment;

class Core
{
  var HALO_CELLS = 2;
  var CLEAN_TILE_SIZE = Const.TILE_SIZE_CLEAN;
  var PLAN_CELL_SIZE = 8;
  var PLAN_CELLS_PER_TILE = 8;
  var ROAD2_GRID_STEP = 2;
  var ROAD2_MIN_SPAWN_GAP = 16;
  var ROAD_BRANCH_MIN_TURN_STEPS = 16;
  var ROAD_HIT_CONTINUE_STEPS = 8;
  var ROAD2_MIN_CITY_DENSITY = 0.12;
  var ROAD2_TILE_COVERAGE_DISTANCE = 8;
  var MIN_CITY_TILE_ROAD_COVERAGE = 0.20;
  var MAX_CITY_COVERAGE_TURN_DISTANCE = 6;

  var COLOR_GROUND = 0x3d4a38;
  var COLOR_LOW = 0x5a5b60;
  var COLOR_MEDIUM = 0x6a6b71;
  var COLOR_HIGH = 0x7b7c84;

  var COLOR_ROAD1 = 0x171716;
  var COLOR_ROAD2 = 0xd07a23;
  var COLOR_ROAD3 = 0x3aa354;
  var COLOR_ROAD4 = 0xa33232;
  var COLOR_ROAD5 = 0x3f6fd6;

  var COLOR_BUILDING_LOW = 0x585349;
  var COLOR_BUILDING_MEDIUM = 0x49453d;
  var COLOR_BUILDING_HIGH = 0x343333;
  var COLOR_BUILDING_SHADOW = 0x1a1a1a;
  var COLOR_PLAZA = 0x6f6b61;
  var COLOR_PLAZA_EDGE = 0x8b8679;
  var COLOR_YARD = 0x58694c;

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
  var rng: SeededRandom;
  var densityField: DensityField;
  var areaTypes: Array<Array<_AreaType>>;
  var overallDensity: Float;
  var roads: Array<RoadSegment>;
  var roadMasks: RoadMasks;
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
      var seed = Std.random(0x7FFFFFFF);
      rng = new SeededRandom(seed);
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
