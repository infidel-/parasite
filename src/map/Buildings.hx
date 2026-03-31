// building pipeline facade and shared tuning helpers

package map;

import _AreaType;
import const.WorldConst;
import map.buildings.BuildingsBlockBuilder;
import map.buildings.BuildingsFootprintGenerator;
import map.buildings.BuildingsPainter;
import map.buildings.BuildingsParcelBuilder;
import map.Types.BlockRect;
import map.Types.BuildingDistrictType;
import map.Types.BuildingFootprint;
import map.Types.BuildingRect;
import map.Types.BuildingStyle;
import map.Types.IntRect;
import map.Types.ParcelRect;
import map.Types.RoadMasks;

class Buildings extends LegacyRoads
{
  var blockBuilder: BuildingsBlockBuilder;
  var parcelBuilder: BuildingsParcelBuilder;
  var footprintGenerator: BuildingsFootprintGenerator;
  var painter: BuildingsPainter;

// initialize the helper classes used by the building pipeline
  function initBuildingHelpers()
    {
      if (blockBuilder != null)
        return;

      blockBuilder = new BuildingsBlockBuilder(this);
      parcelBuilder = new BuildingsParcelBuilder(this);
      footprintGenerator = new BuildingsFootprintGenerator(this);
      painter = new BuildingsPainter(this);
    }

// return how central a parcel is within the generated region
  function getParcelCentrality(parcel: ParcelRect): Float
    {
      var cx = (parcel.x + parcel.width / 2.0) / fullPixelWidth;
      var cy = (parcel.y + parcel.height / 2.0) / fullPixelHeight;
      var dx = Math.abs(cx - 0.5) * 2.0;
      var dy = Math.abs(cy - 0.5) * 2.0;
      return 1.0 - clampFloat((dx + dy) * 0.5, 0.0, 1.0);
    }

// return the plaza chance for a high-density parcel
  function getHighDensityPlazaChance(parcel: ParcelRect): Float
    {
      var sizeScore = clampFloat(
        (Math.min(parcel.width, parcel.height) - CLEAN_TILE_SIZE * 2) /
        (CLEAN_TILE_SIZE * 3), 0.0, 1.0);
      var plazaChance = 0.04 +
        getParcelCentrality(parcel) * 0.08 +
        sizeScore * 0.08;
      if (isSkinnyParcel(parcel))
        plazaChance -= 0.06;
      return clampFloat(plazaChance, 0.02, 0.18);
    }

// derive rectangular blocks from the final road masks
  function buildBlocks(): Array<BlockRect>
    {
      initBuildingHelpers();
      return blockBuilder.buildBlocks();
    }

// derive rectangular blocks from the road occupancy mask
  function buildBlocksFromMasks(masks: RoadMasks): Array<BlockRect>
    {
      initBuildingHelpers();
      return blockBuilder.buildBlocksFromMasks(masks);
    }

// return whether buildings may appear in this area type
  function isBuildableAreaType(areaType: _AreaType): Bool
    {
      var info = WorldConst.getAreaInfo(areaType);
      return info != null &&
        info.isInhabited;
    }

// return one unblurred building district band for one area type
  function getBuildingDistrictTypeForAreaType(areaType: _AreaType): BuildingDistrictType
    {
      return switch (areaType) {
        case AREA_CITY_LOW: LOW;
        case AREA_CITY_MEDIUM: MEDIUM;
        case AREA_CITY_HIGH, AREA_CORP: DOWNTOWN;
        default: OTHER;
      };
    }

// return one priority rank for one building district band
  function getBuildingDistrictRank(districtType: BuildingDistrictType): Int
    {
      return switch (districtType) {
        case OTHER: 0;
        case LOW: 1;
        case MEDIUM: 2;
        case DOWNTOWN: 3;
      };
    }

// return one sizing density for one building district band
  function getBuildingDistrictDensity(districtType: BuildingDistrictType): Float
    {
      return switch (districtType) {
        case OTHER, LOW: 0.24;
        case MEDIUM: 0.58;
        case DOWNTOWN: 1.0;
      };
    }

// return the highest unblurred building district touching one rect
  function getBuildingDistrictTypeForRect(x: Int, y: Int,
      width: Int, height: Int): BuildingDistrictType
    {
      var minCellX = clampInt(Std.int(x / CLEAN_TILE_SIZE), 0, fullCellWidth - 1);
      var maxCellX = clampInt(Std.int((x + width - 1) / CLEAN_TILE_SIZE), 0, fullCellWidth - 1);
      var minCellY = clampInt(Std.int(y / CLEAN_TILE_SIZE), 0, fullCellHeight - 1);
      var maxCellY = clampInt(Std.int((y + height - 1) / CLEAN_TILE_SIZE), 0, fullCellHeight - 1);
      var bestType = OTHER;
      var bestRank = 0;

      for (cellY in minCellY...maxCellY + 1)
        for (cellX in minCellX...maxCellX + 1)
          {
            var districtType = getBuildingDistrictTypeForAreaType(areaTypes[cellX][cellY]);
            var rank = getBuildingDistrictRank(districtType);
            if (rank <= bestRank)
              continue;
            bestType = districtType;
            bestRank = rank;
          }

      return bestType;
    }

// subdivide blocks into orthogonal parcels
  function buildParcels(blockList: Array<BlockRect>): Array<ParcelRect>
    {
      initBuildingHelpers();
      return parcelBuilder.buildParcels(blockList);
    }

// return the building style for one parcel
  function getBuildingStyle(parcel: ParcelRect): BuildingStyle
    {
      var sizingDensity = getBuildingDistrictDensity(parcel.districtType);
      if (sizingDensity < 0.33)
        {
          return {
            buildChance: 1.0,
            margin: 0,
            minRatio: 0.32,
            maxRatio: 0.62,
            shadowAlpha: 0.16,
            forecourtAlpha: 0.0,
            centered: false,
          };
        }

      if (sizingDensity < 0.66)
        {
          return {
            buildChance: 1.0,
            margin: 0,
            minRatio: 0.42,
            maxRatio: 0.82,
            shadowAlpha: 0.24,
            forecourtAlpha: 0.0,
            centered: false,
          };
        }

      var plaza = parcel.width > CLEAN_TILE_SIZE * 2 &&
        parcel.height > CLEAN_TILE_SIZE * 2 &&
        rng.nextFloat() < getHighDensityPlazaChance(parcel);
      return {
        buildChance: 0.99,
        margin: (plaza ? PLAN_CELL_SIZE : 1),
        minRatio: (plaza ? 0.20 : 0.66),
        maxRatio: (plaza ? 0.38 : 0.97),
        shadowAlpha: 0.32,
        forecourtAlpha: (plaza ? 0.34 + rng.nextFloat() * 0.10 : 0.0),
        centered: true,
      };
    }

// generate building footprints from parcels
  function generateBuildings(parcelList: Array<ParcelRect>): Array<BuildingFootprint>
    {
      initBuildingHelpers();
      return footprintGenerator.generateBuildings(parcelList);
    }

// paint open parcels as yards or plazas
  function paintOpenParcels(parcelList: Array<ParcelRect>)
    {
      initBuildingHelpers();
      painter.paintOpenParcels(parcelList);
    }

// paint all building footprints
  function paintBuildings()
    {
      initBuildingHelpers();
      painter.paintBuildings();
    }

// return the block setback for a density band
  function getBlockSetback(density: Float): Int
    {
      if (density < 0.33)
        return 0;
      if (density < 0.66)
        return 0;
      return 1;
    }

// return the target parcel width for a density band
  function getTargetParcelWidth(density: Float): Int
    {
      if (density < 0.33)
        return Std.int(CLEAN_TILE_SIZE * 0.68);
      if (density < 0.66)
        return Std.int(CLEAN_TILE_SIZE * 0.54);
      return Std.int(CLEAN_TILE_SIZE * 1.85);
    }

// return the target parcel height for a density band
  function getTargetParcelHeight(density: Float): Int
    {
      if (density < 0.33)
        return Std.int(CLEAN_TILE_SIZE * 0.68);
      if (density < 0.66)
        return Std.int(CLEAN_TILE_SIZE * 0.54);
      return Std.int(CLEAN_TILE_SIZE * 1.85);
    }

// return the recursion depth limit for parcel subdivision
  function getParcelMaxDepth(density: Float): Int
    {
      if (density < 0.33)
        return 7;
      if (density < 0.66)
        return 8;
      return 5;
    }

// return the parcel split threshold multiplier
  function getParcelSplitThreshold(density: Float): Float
    {
      if (density < 0.33)
        return 1.0;
      if (density < 0.66)
        return 0.96;
      return 1.10;
    }

// return the minimum split ratio for a parcel
  function getParcelSplitMinRatio(density: Float): Float
    {
      if (density < 0.33)
        return 0.18;
      if (density < 0.66)
        return 0.22;
      return 0.36;
    }

// return the maximum split ratio for a parcel
  function getParcelSplitMaxRatio(density: Float): Float
    {
      if (density < 0.33)
        return 0.82;
      if (density < 0.66)
        return 0.78;
      return 0.64;
    }

// return whether a parcel is too skinny to read as a normal lot
  function isSkinnyParcel(parcel: ParcelRect): Bool
    {
      var shortSide = Math.min(parcel.width, parcel.height);
      var longSide = Math.max(parcel.width, parcel.height);
      if (shortSide <= 0)
        return true;
      return longSide / shortSide > 2.6;
    }

// return a placement offset biased toward the center
  function pickCenteredPlacement(span: Int): Int
    {
      if (span <= 0)
        return 0;
      var center = span / 2.0;
      var jitter = (rng.nextFloat() - 0.5) * span * 0.35;
      return clampInt(Std.int(center + jitter), 0, span);
    }

// return the building palette for a density band
  function pickBuildingColor(density: Float): Int
    {
      var base = COLOR_BUILDING_LOW;
      if (density >= 0.66)
        base = COLOR_BUILDING_HIGH;
      else if (density >= 0.33)
        base = COLOR_BUILDING_MEDIUM;

      var factor = 0.96 + rng.nextFloat() * 0.10;
      if (density >= 0.66)
        factor = 0.84 + rng.nextFloat() * 0.10;
      else if (density >= 0.33)
        factor = 0.91 + rng.nextFloat() * 0.10;
      return adjustColor(base, factor);
    }

// return a forecourt tone for centered tower parcels
  function pickBuildingForecourtColor(density: Float): Int
    {
      return adjustColor(COLOR_PLAZA, 0.92 + density * 0.08 + rng.nextFloat() * 0.04);
    }

// return a roof tone for the current building density
  function pickBuildingRoofColor(color: Int, density: Float): Int
    {
      var accent = 0xbab3a5;
      if (density >= 0.66)
        accent = 0xc5bdae;
      else if (density >= 0.33)
        accent = 0xb8b09f;

      return lerpColor(color, accent, 0.18 + density * 0.10 + rng.nextFloat() * 0.05);
    }

// return the roof overlay alpha for a density band
  function pickBuildingRoofAlpha(density: Float): Float
    {
      if (density >= 0.66)
        return 0.30 + rng.nextFloat() * 0.06;
      if (density >= 0.33)
        return 0.22 + rng.nextFloat() * 0.05;
      return 0.16 + rng.nextFloat() * 0.04;
    }

// return the soft edge alpha for a density band
  function pickBuildingEdgeAlpha(density: Float): Float
    {
      if (density >= 0.66)
        return 0.22 + rng.nextFloat() * 0.06;
      if (density >= 0.33)
        return 0.14 + rng.nextFloat() * 0.05;
      return 0.09 + rng.nextFloat() * 0.03;
    }

// return the shadow offset for a density band
  function getBuildingShadowOffset(density: Float): Int
    {
      if (density >= 0.66)
        return 6;
      if (density >= 0.33)
        return 4;
      return 2;
    }

// return the minimum footprint ratio for one L shape
  function getLShapeMinRatio(density: Float): Float
    {
      if (density < 0.33)
        return 0.38;
      if (density < 0.66)
        return 0.60;
      return 0.82;
    }

// return the maximum footprint ratio for one L shape
  function getLShapeMaxRatio(density: Float): Float
    {
      if (density < 0.33)
        return 0.58;
      if (density < 0.66)
        return 0.82;
      return 0.98;
    }

// return the minimum bar ratio for one L shape
  function getLShapeBarMinRatio(density: Float): Float
    {
      if (density < 0.33)
        return 0.24;
      if (density < 0.66)
        return 0.30;
      return 0.36;
    }

// return the maximum bar ratio for one L shape
  function getLShapeBarMaxRatio(density: Float): Float
    {
      if (density < 0.33)
        return 0.36;
      if (density < 0.66)
        return 0.42;
      return 0.52;
    }

// return the required cutout size for one L shape
  function getLShapeCutoutSize(density: Float): Int
    {
      if (density < 0.33)
        return Std.int(PLAN_CELL_SIZE / 2);
      if (density < 0.66)
        return Std.int(PLAN_CELL_SIZE * 0.75);
      return PLAN_CELL_SIZE;
    }

// return the minimum footprint ratio for one H shape
  function getHShapeMinRatio(density: Float): Float
    {
      if (density < 0.33)
        return 0.46;
      if (density < 0.66)
        return 0.68;
      return 0.86;
    }

// return the maximum footprint ratio for one H shape
  function getHShapeMaxRatio(density: Float): Float
    {
      if (density < 0.33)
        return 0.66;
      if (density < 0.66)
        return 0.88;
      return 0.98;
    }

// return the minimum bar ratio for one H shape
  function getHShapeBarMinRatio(density: Float): Float
    {
      if (density < 0.33)
        return 0.20;
      if (density < 0.66)
        return 0.26;
      return 0.32;
    }

// return the maximum bar ratio for one H shape
  function getHShapeBarMaxRatio(density: Float): Float
    {
      if (density < 0.33)
        return 0.28;
      if (density < 0.66)
        return 0.36;
      return 0.44;
    }

// return the required inner gap size for one H shape
  function getHShapeGapSize(density: Float): Int
    {
      if (density < 0.33)
        return Std.int(PLAN_CELL_SIZE / 2);
      if (density < 0.66)
        return PLAN_CELL_SIZE;
      return PLAN_CELL_SIZE + Std.int(PLAN_CELL_SIZE / 2);
    }

// return the minimum pixel size for one building rect side
  function getMinBuildingPixelSize(): Int
    {
      return 4;
    }

// return the number of rooftop rects stored at the end of one footprint
  function getRooftopRectCount(rects: Array<BuildingRect>): Int
    {
      return rects != null &&
        rects.length > 1 ? 1 : 0;
    }

// return the number of rooftop rects stored on one building
  function getBuildingRooftopRectCount(building: BuildingFootprint): Int
    {
      return building.rooftopRectCount != null ? building.rooftopRectCount : 0;
    }

// return the number of base rects before rooftop add-ons
  function getBuildingBaseRectCount(building: BuildingFootprint): Int
    {
      return building.rects.length - getBuildingRooftopRectCount(building);
    }

// return the lighter rooftop mass color for one building
  function getBuildingRooftopColor(baseColor: Int, density: Float): Int
    {
      return adjustColor(baseColor, density >= 0.66 ? 1.18 : 1.14);
    }

// return the rooftop paint color for one building
  function getBuildingPaintRooftopColor(building: BuildingFootprint): Int
    {
      return building.rooftopColor != null ? building.rooftopColor : building.color;
    }

// return whether every rect in one footprint meets the minimum side size
  function footprintHasMinimumRectSize(rects: Array<BuildingRect>): Bool
    {
      if (rects == null)
        return false;

      var minSize = getMinBuildingPixelSize();
      for (rect in rects)
        if (rect.width < minSize ||
            rect.height < minSize)
          return false;
      return true;
    }

// return whether one building rect is small enough to skip shading passes
  function isSmallBuildingRect(rect: BuildingRect): Bool
    {
      return Math.min(rect.width, rect.height) <= PLAN_CELL_SIZE;
    }

// return the roof inset for one building rect
  function getBuildingRoofInset(rect: BuildingRect, density: Float): Int
    {
      var inset = 4;
      if (density >= 0.66)
        inset = 3;
      else if (density < 0.33)
        inset = 5;

      var maxInset = Std.int(Math.min(rect.width, rect.height) / 4);
      return clampInt(inset, 2, Std.int(Math.max(maxInset, 2)));
    }

// return the edge highlight width for one building rect
  function getBuildingEdgeWidth(rect: BuildingRect, density: Float): Int
    {
      var width = density >= 0.66 ? 2 : 1;
      if (Math.min(rect.width, rect.height) >= CLEAN_TILE_SIZE)
        width++;
      return clampInt(width, 1, Std.int(Math.max(Math.min(rect.width, rect.height) / 6, 1)));
    }

// return whether a building footprint overlaps roads
  function footprintTouchesRoad(rects: Array<BuildingRect>): Bool
    {
      for (rect in rects)
        {
          var inset = Std.int(Math.min(Math.min(rect.width, rect.height) / 6, PLAN_CELL_SIZE));
          var checkX1 = rect.x + inset;
          var checkY1 = rect.y + inset;
          var checkX2 = rect.x + rect.width - inset;
          var checkY2 = rect.y + rect.height - inset;
          if (checkX2 <= checkX1 ||
              checkY2 <= checkY1)
            {
              checkX1 = rect.x;
              checkY1 = rect.y;
              checkX2 = rect.x + rect.width;
              checkY2 = rect.y + rect.height;
            }

          var minX = clampInt(Std.int(Math.floor(checkX1 / PLAN_CELL_SIZE)), 0, planWidth - 1);
          var maxX = clampInt(Std.int(Math.ceil(checkX2 / PLAN_CELL_SIZE)) - 1, 0, planWidth - 1);
          var minY = clampInt(Std.int(Math.floor(checkY1 / PLAN_CELL_SIZE)), 0, planHeight - 1);
          var maxY = clampInt(Std.int(Math.ceil(checkY2 / PLAN_CELL_SIZE)) - 1, 0, planHeight - 1);

          for (yy in minY...maxY + 1)
            for (xx in minX...maxX + 1)
              if (roadMasks.core[xx][yy] > 0.0)
                return true;
        }
      return false;
    }

// return the bounding box of a building footprint
  function getFootprintBounds(rects: Array<BuildingRect>): IntRect
    {
      var minX = rects[0].x;
      var minY = rects[0].y;
      var maxX = rects[0].x + rects[0].width;
      var maxY = rects[0].y + rects[0].height;

      for (i in 1...rects.length)
        {
          var rect = rects[i];
          if (rect.x < minX)
            minX = rect.x;
          if (rect.y < minY)
            minY = rect.y;
          if (rect.x + rect.width > maxX)
            maxX = rect.x + rect.width;
          if (rect.y + rect.height > maxY)
            maxY = rect.y + rect.height;
        }

      return {
        x: minX,
        y: minY,
        width: maxX - minX,
        height: maxY - minY,
      };
    }

// return whether a footprint leaves enough room to show a forecourt
  function hasVisibleForecourt(bounds: IntRect,
      lotX: Int, lotY: Int, lotWidth: Int, lotHeight: Int): Bool
    {
      var left = bounds.x - lotX;
      var top = bounds.y - lotY;
      var right = lotX + lotWidth - (bounds.x + bounds.width);
      var bottom = lotY + lotHeight - (bounds.y + bounds.height);
      var minClear = left;
      if (top < minClear)
        minClear = top;
      if (right < minClear)
        minClear = right;
      if (bottom < minClear)
        minClear = bottom;
      return minClear >= CLEAN_TILE_SIZE / 5;
    }

}
