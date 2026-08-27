// density, area-type, and ground painting helpers

package map;

import _AreaType;
import js.lib.Float32Array;
import js.lib.Uint8Array;
import map.TerrainNoise;
import map.Types.DensityField;

class Ground extends Core
{
// trace one perlin profiling phase
  function tracePerlinProfilePhase(label: String, elapsedMS: Float)
    {
      if (!Const.isDebug)
        return;
      profile('PERLIN', label + ': ' + Std.int(elapsedMS) + ' ms');
    }

// trace one perlin profiling summary line
  function tracePerlinProfileSummary(label: String)
    {
      if (!Const.isDebug)
        return;
      profile('PERLIN', label);
    }

// build the halo-expanded density field
  function buildDensityField(): DensityField
    {
      var cells = game.region.getCells();
      var values = makeFloatGrid(fullCellWidth, fullCellHeight);

      for (yy in 0...fullCellHeight)
        for (xx in 0...fullCellWidth)
          {
            var srcX = clampInt(xx - Core.HALO_CELLS, 0, regionWidth - 1);
            var srcY = clampInt(yy - Core.HALO_CELLS, 0, regionHeight - 1);
            values[xx][yy] = getAreaDensityValue(cells[srcX][srcY].typeID);
          }

      return {
        width: fullCellWidth,
        height: fullCellHeight,
        values: values,
      };
    }

// build the halo-expanded area-type field
  function buildAreaTypeField(): Array<Array<_AreaType>>
    {
      var cells = game.region.getCells();
      var values = [];

      for (xx in 0...fullCellWidth)
        {
          var col = [];
          for (yy in 0...fullCellHeight)
            {
              var srcX = clampInt(xx - Core.HALO_CELLS, 0, regionWidth - 1);
              var srcY = clampInt(yy - Core.HALO_CELLS, 0, regionHeight - 1);
              col.push(cells[srcX][srcY].typeID);
            }
          values.push(col);
        }

      return values;
    }

// build cached terrain and city background data used by ground painting
  function ensureGroundRenderCaches()
    {
      if (terrainFieldCache == null)
        buildTerrainFieldCache();
      if (cityBackgroundMask == null)
        buildCityBackgroundMask();
    }

// build the reduced-resolution cached terrain field
  function buildTerrainFieldCache()
    {
      var step = TERRAIN_CACHE_STEP_PIXELS < 1 ? 1 : TERRAIN_CACHE_STEP_PIXELS;
      terrainFieldCacheWidth = Std.int(Math.ceil((fullPixelWidth - 1) / step)) + 1;
      terrainFieldCacheHeight = Std.int(Math.ceil((fullPixelHeight - 1) / step)) + 1;
      terrainFieldCache = new Float32Array(terrainFieldCacheWidth * terrainFieldCacheHeight);
      var index = 0;

      for (yy in 0...terrainFieldCacheHeight)
        {
          var py = Math.min(yy * step, fullPixelHeight - 1);
          var y = (py + 0.5) / CLEAN_TILE_SIZE;
          for (xx in 0...terrainFieldCacheWidth)
            {
              var px = Math.min(xx * step, fullPixelWidth - 1);
              var x = (px + 0.5) / CLEAN_TILE_SIZE;
              terrainFieldCache[index++] = sampleTerrainFieldRawAtCoord(x, y);
            }
        }
    }

// build the pixel alpha mask used for city background overlays
  function buildCityBackgroundMask()
    {
      cityBackgroundMask = new Uint8Array(fullPixelWidth * fullPixelHeight);
      cityBackgroundPixelCount = 0;
      if (!ENABLE_REGION_CITY_CONTENT ||
          !ENABLE_REGION_CITY_BACKGROUNDS)
        return;

      for (cellY in 0...fullCellHeight)
        for (cellX in 0...fullCellWidth)
          {
            if (!isCityAreaType(areaTypes[cellX][cellY]))
              continue;

            var startX = cellX * CLEAN_TILE_SIZE;
            var startY = cellY * CLEAN_TILE_SIZE;
            var fadeLeft = !isCityBackgroundAreaTypeAtCell(cellX - 1, cellY);
            var fadeRight = !isCityBackgroundAreaTypeAtCell(cellX + 1, cellY);
            var fadeTop = !isCityBackgroundAreaTypeAtCell(cellX, cellY - 1);
            var fadeBottom = !isCityBackgroundAreaTypeAtCell(cellX, cellY + 1);
            for (localY in 0...CLEAN_TILE_SIZE)
              {
                var rowIndex = (startY + localY) * fullPixelWidth + startX;
                for (localX in 0...CLEAN_TILE_SIZE)
                  cityBackgroundMask[rowIndex + localX] = getCityBackgroundMaskAlpha(localX, localY,
                    fadeLeft, fadeRight, fadeTop, fadeBottom);
              }
            cityBackgroundPixelCount += CLEAN_TILE_SIZE * CLEAN_TILE_SIZE;
          }
    }

// return whether one full-grid cell should receive a city background overlay
  function isCityBackgroundAreaTypeAtCell(cellX: Int, cellY: Int): Bool
    {
      if (cellX < 0 ||
          cellX >= fullCellWidth ||
          cellY < 0 ||
          cellY >= fullCellHeight)
        return false;
      return isCityAreaType(areaTypes[cellX][cellY]);
    }

// return the city background alpha mask value for one local tile pixel
  function getCityBackgroundMaskAlpha(localX: Int, localY: Int, fadeLeft: Bool,
      fadeRight: Bool, fadeTop: Bool, fadeBottom: Bool): Int
    {
      var fadePixels = REGION_CITY_BACKGROUND_EDGE_FADE_PIXELS;
      if (fadePixels <= 0)
        return 255;

      var coverage = 1.0;
      if (fadeLeft)
        coverage = Math.min(coverage,
          getCityBackgroundEdgeFactor((localX + 0.5) / fadePixels));
      if (fadeRight)
        coverage = Math.min(coverage,
          getCityBackgroundEdgeFactor((CLEAN_TILE_SIZE - localX - 0.5) / fadePixels));
      if (fadeTop)
        coverage = Math.min(coverage,
          getCityBackgroundEdgeFactor((localY + 0.5) / fadePixels));
      if (fadeBottom)
        coverage = Math.min(coverage,
          getCityBackgroundEdgeFactor((CLEAN_TILE_SIZE - localY - 0.5) / fadePixels));
      return Std.int(clampFloat(coverage, 0.0, 1.0) * 255.0);
    }

// return one smooth coverage factor for city background perimeter fade
  function getCityBackgroundEdgeFactor(v: Float): Float
    {
      var t = clampFloat(v, 0.0, 1.0);
      return t * t * (3.0 - 2.0 * t);
    }

// paint the mixed city-background and perlin terrain ground field
  function paintGround()
    {
      if (Const.isDebug)
        {
          var totalStartTS = haxe.Timer.stamp() * 1000.0;
          var imageData = ctx.createImageData(fullPixelWidth, fullPixelHeight);
          var data = imageData.data;
          var phaseStartTS = haxe.Timer.stamp() * 1000.0;
          tracePerlinProfilePhase('paintGround.createImageData', phaseStartTS - totalStartTS);
          ensureGroundRenderCaches();
          var terrainRawValues = new Float32Array(fullPixelWidth * fullPixelHeight);
          var sampleIndex = 0;
          var minTerrain = 1.0;
          var maxTerrain = -1.0;
          var cityMask = cityBackgroundMask;
          var cityPixelCount = cityBackgroundPixelCount;

          // sample the raw terrain field once per pixel
          for (py in 0...fullPixelHeight)
            for (px in 0...fullPixelWidth)
              {
                var terrain = sampleTerrainFieldAtPixel(px, py);
                terrainRawValues[sampleIndex++] = terrain;
                if (terrain < minTerrain)
                  minTerrain = terrain;
                if (terrain > maxTerrain)
                  maxTerrain = terrain;
              }

          var nowTS = haxe.Timer.stamp() * 1000.0;
          tracePerlinProfilePhase('paintGround.sampleTerrainBase', nowTS - phaseStartTS);
          phaseStartTS = nowTS;
          sampleIndex = 0;
          var forestPixelCount = 0;
          var groundPixelCount = 0;
          var mountainPixelCount = 0;
          var index = 0;
          sampleIndex = 0;

          // classify terrain pixels and blend city background overlays where needed
          for (py in 0...fullPixelHeight)
            for (px in 0...fullPixelWidth)
              {
                var terrain = terrainRawValues[sampleIndex];
                var terrainColor = getTerrainBandColorForValue(terrain);
                var color = terrainColor;
                if (cityMask[sampleIndex] != 0)
                  color = lerpColor(terrainColor, getColorForDensity(samplePaintDensityAtPixel(px, py)),
                    getCityBackgroundPaintAlpha(cityMask[sampleIndex]));
                if (terrain < TERRAIN_FOREST_THRESHOLD)
                  forestPixelCount++;
                else if (terrain > TERRAIN_MOUNTAIN_THRESHOLD)
                  mountainPixelCount++;
                else
                  groundPixelCount++;
                sampleIndex++;
                data[index++] = (color >> 16) & 0xFF;
                data[index++] = (color >> 8) & 0xFF;
                data[index++] = color & 0xFF;
                data[index++] = 0xFF;
              }

          nowTS = haxe.Timer.stamp() * 1000.0;
          tracePerlinProfilePhase('paintGround.applyTerrainBands', nowTS - phaseStartTS);
          phaseStartTS = nowTS;
          ctx.putImageData(imageData, 0, 0);
          nowTS = haxe.Timer.stamp() * 1000.0;
          tracePerlinProfilePhase('paintGround.putImageData', nowTS - phaseStartTS);
          tracePerlinProfileSummary('paintGround.summary min=' + minTerrain +
            ' max=' + maxTerrain +
            ' cityPixels=' + cityPixelCount +
            ' forestPixels=' + forestPixelCount +
            ' groundPixels=' + groundPixelCount +
            ' mountainPixels=' + mountainPixelCount +
            ' totalPixels=' + (fullPixelWidth * fullPixelHeight));
          tracePerlinProfilePhase('paintGround.total', nowTS - totalStartTS);
          return;
        }
      ensureGroundRenderCaches();
      var imageData = ctx.createImageData(fullPixelWidth, fullPixelHeight);
      var data = imageData.data;
      var index = 0;
      var pixelIndex = 0;
      var cityMask = cityBackgroundMask;

      for (py in 0...fullPixelHeight)
        for (px in 0...fullPixelWidth)
          {
            var terrain = sampleTerrainFieldAtPixel(px, py);
            var terrainColor = getTerrainBandColorForValue(terrain);
            var color = terrainColor;
            if (cityMask[pixelIndex] != 0)
              color = lerpColor(terrainColor, getColorForDensity(samplePaintDensityAtPixel(px, py)),
                getCityBackgroundPaintAlpha(cityMask[pixelIndex]));
            data[index++] = (color >> 16) & 0xFF;
            data[index++] = (color >> 8) & 0xFF;
            data[index++] = color & 0xFF;
            data[index++] = 0xFF;
            pixelIndex++;
          }

      ctx.putImageData(imageData, 0, 0);
    }

// return the paint alpha for one city background mask value
  function getCityBackgroundPaintAlpha(maskAlpha: Int): Float
    {
      return REGION_CITY_BACKGROUND_ALPHA * (maskAlpha / 255.0);
    }

// return the terrain band color with threshold antialiasing
  function getTerrainBandColorForValue(terrain: Float): Int
    {
      if (terrain < TERRAIN_FOREST_THRESHOLD - TERRAIN_EDGE_ANTIALIAS_WIDTH)
        return COLOR_FOREST_MID;

      if (terrain < TERRAIN_FOREST_THRESHOLD + TERRAIN_EDGE_ANTIALIAS_WIDTH)
        return lerpColor(COLOR_FOREST_MID, COLOR_GROUND,
          getTerrainEdgeAntialiasFactor(terrain, TERRAIN_FOREST_THRESHOLD));

      if (terrain > TERRAIN_MOUNTAIN_THRESHOLD + TERRAIN_EDGE_ANTIALIAS_WIDTH)
        return COLOR_MOUNTAIN;

      if (terrain > TERRAIN_MOUNTAIN_THRESHOLD - TERRAIN_EDGE_ANTIALIAS_WIDTH)
        return lerpColor(COLOR_GROUND, COLOR_MOUNTAIN,
          getTerrainEdgeAntialiasFactor(terrain, TERRAIN_MOUNTAIN_THRESHOLD));

      return COLOR_GROUND;
    }

// return one smooth antialias blend factor around a terrain threshold
  function getTerrainEdgeAntialiasFactor(terrain: Float, threshold: Float): Float
    {
      var t = clampFloat((terrain - threshold + TERRAIN_EDGE_ANTIALIAS_WIDTH) /
        (TERRAIN_EDGE_ANTIALIAS_WIDTH * 2.0), 0.0, 1.0);
      return t * t * (3.0 - 2.0 * t);
    }

// return the terrain band color for one pixel from the new perlin terrain field
  function getTerrainBandColorAtPixel(px: Int, py: Int): Int
    {
      return getTerrainBandColorForValue(sampleTerrainFieldAtPixel(px, py));
    }

// sample the uncached terrain field at one map-space coordinate
  function sampleTerrainFieldRawAtCoord(x: Float, y: Float): Float
    {
      var terrain = TerrainNoise.sampleFractal(
        mapSeed,
        x / TERRAIN_PERLIN_SCALE,
        y / TERRAIN_PERLIN_SCALE,
        TERRAIN_PERLIN_OCTAVES,
        TERRAIN_PERLIN_LACUNARITY,
        TERRAIN_PERLIN_GAIN);
      return clampFloat(terrain * TERRAIN_PERLIN_CONTRAST, -1.0, 1.0);
    }

// sample the cached terrain field at one map-space coordinate
  function sampleTerrainFieldCacheAtCoord(x: Float, y: Float): Float
    {
      var step = TERRAIN_CACHE_STEP_PIXELS < 1 ? 1 : TERRAIN_CACHE_STEP_PIXELS;
      var pixelX = clampFloat(x * CLEAN_TILE_SIZE - 0.5, 0.0, fullPixelWidth - 1.0);
      var pixelY = clampFloat(y * CLEAN_TILE_SIZE - 0.5, 0.0, fullPixelHeight - 1.0);
      var fx = pixelX / step;
      var fy = pixelY / step;
      var x0 = Std.int(Math.floor(fx));
      var y0 = Std.int(Math.floor(fy));
      var x1 = clampInt(x0 + 1, 0, terrainFieldCacheWidth - 1);
      var y1 = clampInt(y0 + 1, 0, terrainFieldCacheHeight - 1);
      var tx = fx - x0;
      var ty = fy - y0;
      var v00 = terrainFieldCache[y0 * terrainFieldCacheWidth + x0];
      var v10 = terrainFieldCache[y0 * terrainFieldCacheWidth + x1];
      var v01 = terrainFieldCache[y1 * terrainFieldCacheWidth + x0];
      var v11 = terrainFieldCache[y1 * terrainFieldCacheWidth + x1];
      var top = v00 + (v10 - v00) * tx;
      var bottom = v01 + (v11 - v01) * tx;
      return top + (bottom - top) * ty;
    }

// sample the cached terrain field at one pixel center
  function sampleTerrainFieldAtPixel(px: Int, py: Int): Float
    {
      return sampleTerrainFieldCacheAtCoord(
        (px + 0.5) / CLEAN_TILE_SIZE,
        (py + 0.5) / CLEAN_TILE_SIZE);
    }

// return the cached raw terrain field at one map-space coordinate
  function getTerrainFieldAtCoord(x: Float, y: Float): Float
    {
      ensureGroundRenderCaches();
      return sampleTerrainFieldCacheAtCoord(x, y);
    }

// paint one debug visualization of the current terrain layers
  function paintDebugViewIfRequested(): Bool
    {
      if (MAP_DEBUG_VIEW_MODE == MAP_DEBUG_VIEW_NORMAL)
        return false;

      if (MAP_DEBUG_VIEW_MODE == MAP_DEBUG_VIEW_GROUND)
        {
          paintGround();
          return true;
        }

      if (MAP_DEBUG_VIEW_MODE == MAP_DEBUG_VIEW_TERRAIN_RAW)
        {
          paintTerrainFieldDebug();
          return true;
        }

      if (MAP_DEBUG_VIEW_MODE == MAP_DEBUG_VIEW_TERRAIN_BANDS)
        {
          paintTerrainBandsDebug();
          return true;
        }

      return false;
    }

// paint the raw terrain field as a grayscale debug image
  function paintTerrainFieldDebug()
    {
      ensureGroundRenderCaches();
      var imageData = ctx.createImageData(fullPixelWidth, fullPixelHeight);
      var data = imageData.data;
      var index = 0;

      for (py in 0...fullPixelHeight)
        for (px in 0...fullPixelWidth)
          {
            var terrain = getTerrainFieldAtCoord(
              (px + 0.5) / CLEAN_TILE_SIZE,
              (py + 0.5) / CLEAN_TILE_SIZE);
            var shade = Std.int(clampFloat((terrain + 1.0) * 0.5, 0.0, 1.0) * 255.0);
            data[index++] = shade;
            data[index++] = shade;
            data[index++] = shade;
            data[index++] = 0xFF;
          }

      ctx.putImageData(imageData, 0, 0);
    }

// paint the classified terrain bands without city overlays
  function paintTerrainBandsDebug()
    {
      ensureGroundRenderCaches();
      var imageData = ctx.createImageData(fullPixelWidth, fullPixelHeight);
      var data = imageData.data;
      var index = 0;

      for (py in 0...fullPixelHeight)
        for (px in 0...fullPixelWidth)
          {
            var color = getTerrainBandColorAtPixel(px, py);
            data[index++] = (color >> 16) & 0xFF;
            data[index++] = (color >> 8) & 0xFF;
            data[index++] = color & 0xFF;
            data[index++] = 0xFF;
          }

      ctx.putImageData(imageData, 0, 0);
    }

// return the area type at one painted pixel
  function getAreaTypeAtPixel(px: Int, py: Int): _AreaType
    {
      var x = clampInt(Std.int(Math.floor((px + 0.5) / CLEAN_TILE_SIZE)), 0, fullCellWidth - 1);
      var y = clampInt(Std.int(Math.floor((py + 0.5) / CLEAN_TILE_SIZE)), 0, fullCellHeight - 1);
      return areaTypes[x][y];
    }

// sample the ground paint density with soft blending only near tile edges
  function samplePaintDensityAtPixel(px: Int, py: Int): Float
    {
      var xBlend = getGroundPaintAxisBlend(px, densityField.width);
      var yBlend = getGroundPaintAxisBlend(py, densityField.height);
      var v00 = densityField.values[xBlend.a][yBlend.a];
      var v10 = densityField.values[xBlend.b][yBlend.a];
      var v01 = densityField.values[xBlend.a][yBlend.b];
      var v11 = densityField.values[xBlend.b][yBlend.b];
      var top = v00 + (v10 - v00) * xBlend.t;
      var bottom = v01 + (v11 - v01) * xBlend.t;
      return top + (bottom - top) * yBlend.t;
    }

// return the edge-band width used for softened ground paint transitions
  function getGroundPaintEdgeBlend(): Float
    {
      return 0.85;
    }

// return the two density cells and blend factor for one paint axis
  function getGroundPaintAxisBlend(pixel: Int, cellCount: Int): { a: Int, b: Int, t: Float }
    {
      var coord = (pixel + 0.5) / CLEAN_TILE_SIZE;
      var cell = clampInt(Std.int(Math.floor(coord)), 0, cellCount - 1);
      var local = coord - cell;
      var bandHalf = getGroundPaintEdgeBlend();

      if (local < bandHalf &&
          cell > 0)
        {
          return {
            a: cell - 1,
            b: cell,
            t: getGroundPaintEdgeFactor((local + bandHalf) / (bandHalf * 2.0)),
          };
        }

      if (local > 1.0 - bandHalf &&
          cell < cellCount - 1)
        {
          return {
            a: cell,
            b: cell + 1,
            t: getGroundPaintEdgeFactor((local - (1.0 - bandHalf)) / (bandHalf * 2.0)),
          };
        }

      return {
        a: cell,
        b: cell,
        t: 0.0,
      };
    }

// return one smooth blend factor inside the ground paint edge band
  function getGroundPaintEdgeFactor(v: Float): Float
    {
      var t = clampFloat(v, 0.0, 1.0);
      return t * t * (3.0 - 2.0 * t);
    }

  function sampleDensityAtPixel(px: Int, py: Int): Float
    {
      var fx = clampFloat(px / CLEAN_TILE_SIZE, 0.0, densityField.width - 1.001);
      var fy = clampFloat(py / CLEAN_TILE_SIZE, 0.0, densityField.height - 1.001);
      var x0 = Std.int(Math.floor(fx));
      var y0 = Std.int(Math.floor(fy));
      var x1 = clampInt(x0 + 1, 0, densityField.width - 1);
      var y1 = clampInt(y0 + 1, 0, densityField.height - 1);
      var tx = fx - x0;
      var ty = fy - y0;

      var v00 = densityField.values[x0][y0];
      var v10 = densityField.values[x1][y0];
      var v01 = densityField.values[x0][y1];
      var v11 = densityField.values[x1][y1];
      var top = v00 + (v10 - v00) * tx;
      var bottom = v01 + (v11 - v01) * tx;
      return top + (bottom - top) * ty;
    }

// sample the average density over a block rectangle
  function sampleAverageDensity(x: Int, y: Int, width: Int, height: Int): Float
    {
      var sum = 0.0;
      var count = 0;
      var x2 = x + width;
      var y2 = y + height;
      var step = PLAN_CELL_SIZE * 2;

      var py = y + Std.int(PLAN_CELL_SIZE / 2);
      while (py < y2)
        {
          var px = x + Std.int(PLAN_CELL_SIZE / 2);
          while (px < x2)
            {
              sum += sampleDensityAtPixel(px, py);
              count++;
              px += step;
            }
          py += step;
        }

      if (count == 0)
        return sampleDensityAtPixel(x + Std.int(width / 2), y + Std.int(height / 2));
      return sum / count;
    }

// return whether one non-road plan cell should stay buildable
  function isBuildableGroundCell(xx: Int, yy: Int, px: Int, py: Int): Bool
    {
      var density = sampleDensityAtPixel(px, py);
      if (density >= 0.22)
        return true;

      var coarseX = Std.int(px / (PLAN_CELL_SIZE * 3));
      var coarseY = Std.int(py / (PLAN_CELL_SIZE * 3));
      var noise = hashFloat(xx, yy, 331) * 0.55 +
        hashFloat(coarseX, coarseY, 337) * 0.45;
      var openness = clampFloat((0.22 - density) / 0.18, 0.0, 1.0);
      return noise > openness;
    }

// return the density value for an area type
  function getAreaDensityValue(type: _AreaType): Float
    {
      if (!ENABLE_REGION_CITY_CONTENT)
        return 0.01;
      return switch (type) {
        case AREA_CITY_LOW: 0.24;
        case AREA_CITY_MEDIUM: 0.58;
        case AREA_CITY_HIGH, AREA_CORP: 1.0;
        default: 0.01;
      };
    }

// return whether an area type is a city area
  function isCityAreaType(type: _AreaType): Bool
    {
      return switch (type) {
        case AREA_CITY_LOW, AREA_CITY_MEDIUM, AREA_CITY_HIGH, AREA_CORP: true;
        default: false;
      };
    }

// return a density-interpolated ground color
  function getColorForDensity(density: Float): Int
    {
      var t = clampFloat(density, 0.0, 1.0);

      if (t <= 0.33)
        return lerpColor(COLOR_GROUND, COLOR_LOW, t / 0.33);
      if (t <= 0.66)
        return lerpColor(COLOR_LOW, COLOR_MEDIUM, (t - 0.33) / 0.33);
      return lerpColor(COLOR_MEDIUM, COLOR_HIGH, (t - 0.66) / 0.34);
    }

}
