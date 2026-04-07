// density, area-type, and ground painting helpers

package map;

import _AreaType;
import js.lib.Float32Array;
import map.Core.DarkForestPatchLobe;
import map.Types.DensityField;

class Ground extends Core
{
#if mydebug
// trace one forest profiling phase
  function traceForestProfilePhase(label: String, elapsedMS: Float)
    {
      trace('MAP PROFILE FOREST ' + label + ': ' + Std.int(elapsedMS) + ' ms');
    }

// trace one forest profiling summary line
  function traceForestProfileSummary(label: String)
    {
      trace('MAP PROFILE FOREST ' + label);
    }
#else
// ignore one forest profiling phase outside debug builds
  inline function traceForestProfilePhase(label: String, elapsedMS: Float)
    {
    }

// ignore one forest profiling summary line outside debug builds
  inline function traceForestProfileSummary(label: String)
    {
    }
#end

// build the halo-expanded density field
  function buildDensityField(): DensityField
    {
      var cells = game.region.getCells();
      var values = makeFloatGrid(fullCellWidth, fullCellHeight);

      for (yy in 0...fullCellHeight)
        for (xx in 0...fullCellWidth)
          {
            var srcX = clampInt(xx - HALO_CELLS, 0, regionWidth - 1);
            var srcY = clampInt(yy - HALO_CELLS, 0, regionHeight - 1);
            values[xx][yy] = getAreaDensityValue(cells[srcX][srcY].typeID);
          }

      for (i in 0...0)
        values = blurDensityValues(values);

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
              var srcX = clampInt(xx - HALO_CELLS, 0, regionWidth - 1);
              var srcY = clampInt(yy - HALO_CELLS, 0, regionHeight - 1);
              col.push(cells[srcX][srcY].typeID);
            }
          values.push(col);
        }

      return values;
    }

// paint the continuous density-based ground field
  function paintGround()
    {
      var imageData = ctx.createImageData(fullPixelWidth, fullPixelHeight);
      var data = imageData.data;
      var index = 0;

      for (py in 0...fullPixelHeight)
        for (px in 0...fullPixelWidth)
          {
            var color = (ENABLE_REGION_CITY_CONTENT
              ? getColorForDensity(samplePaintDensityAtPixel(px, py))
              : getGroundColorAtPixel(px, py, COLOR_GROUND));
            data[index++] = (color >> 16) & 0xFF;
            data[index++] = (color >> 8) & 0xFF;
            data[index++] = color & 0xFF;
            data[index++] = 0xFF;
          }

      ctx.putImageData(imageData, 0, 0);
    }

// paint forest canopy patches across wilderness ground tiles
  function paintForests()
    {
#if mydebug
      var totalStartTS = haxe.Timer.stamp() * 1000.0;
#end
      var imageData = ctx.getImageData(0, 0, fullPixelWidth, fullPixelHeight);
#if mydebug
      var phaseStartTS = haxe.Timer.stamp() * 1000.0;
      traceForestProfilePhase('paintForests.getImageData', phaseStartTS - totalStartTS);
      var sampleStartTS = phaseStartTS;
      var groundSupports = new Float32Array(fullPixelWidth * fullPixelHeight);
      var forestFields = new Float32Array(fullPixelWidth * fullPixelHeight);
      var patchStrengths = new Float32Array(fullPixelWidth * fullPixelHeight);
      var patchFields = new Float32Array(fullPixelWidth * fullPixelHeight);
      var patchPixelCount = 0;
      var patchIndex = 0;
      var sampleIndex = 0;

// sample the forest support and field across the visible pixel grid
      for (py in 0...fullPixelHeight)
        for (px in 0...fullPixelWidth)
          {
            var x = (px + 0.5) / CLEAN_TILE_SIZE;
            var y = (py + 0.5) / CLEAN_TILE_SIZE;
            var groundSupport = getGroundAreaSupportAtCoord(x, y);
            groundSupports[sampleIndex] = groundSupport;
            forestFields[sampleIndex] = getForestFieldAtCoord(x, y);
            sampleIndex++;
          }

      var nowTS = haxe.Timer.stamp() * 1000.0;
      traceForestProfilePhase('paintForests.samplePatchStrength.forestBase', nowTS - phaseStartTS);
      phaseStartTS = nowTS;
      sampleIndex = 0;

// sample the raw dark-forest patch field across the visible pixel grid
      for (py in 0...fullPixelHeight)
        for (px in 0...fullPixelWidth)
          {
            patchFields[sampleIndex] = getDarkForestPatchFieldAtCoord(
              (px + 0.5) / CLEAN_TILE_SIZE,
              (py + 0.5) / CLEAN_TILE_SIZE);
            sampleIndex++;
          }

      nowTS = haxe.Timer.stamp() * 1000.0;
      traceForestProfilePhase('paintForests.samplePatchStrength.patchField', nowTS - phaseStartTS);
      phaseStartTS = nowTS;
      sampleIndex = 0;

// combine the precomputed forest and patch fields into the final patch mask
      for (py in 0...fullPixelHeight)
        for (px in 0...fullPixelWidth)
          {
            var x = (px + 0.5) / CLEAN_TILE_SIZE;
            var y = (py + 0.5) / CLEAN_TILE_SIZE;
            var groundSupport = groundSupports[sampleIndex];
            var forestField = forestFields[sampleIndex];
            var forestStrength = getForestStrengthAtCoordWithGroundSupportAndField(x, y, groundSupport, forestField);
            var patch = getDarkForestPatchThresholdStrength(patchFields[sampleIndex]);
            var patchStrength = patch <= 0.0
              ? 0.0
              : patch * getDarkForestPatchSupportStrength(forestStrength, forestField, groundSupport);
            patchStrengths[patchIndex++] = patchStrength;
            if (patchStrength > 0.0)
              patchPixelCount++;
            sampleIndex++;
          }

      nowTS = haxe.Timer.stamp() * 1000.0;
      traceForestProfilePhase('paintForests.samplePatchStrength.patchSupport', nowTS - phaseStartTS);
      traceForestProfilePhase('paintForests.samplePatchStrength', nowTS - sampleStartTS);
      phaseStartTS = nowTS;
#end
      var data = imageData.data;
      var index = 0;

// paint the main forest masses directly from the continuous noise field
      for (py in 0...fullPixelHeight)
        for (px in 0...fullPixelWidth)
          {
            var forestPaintStrength = 0.0;
            var darkWoodsStrength = 0.0;
            var darkForestPatchStrength = 0.0;
#if mydebug
            darkForestPatchStrength = patchStrengths[Std.int(index / 4)];
#else
            var x = (px + 0.5) / CLEAN_TILE_SIZE;
            var y = (py + 0.5) / CLEAN_TILE_SIZE;
            var groundSupport = getGroundAreaSupportAtCoord(x, y);
            var forestField = getForestFieldAtCoord(x, y);
            var forestStrength = getForestStrengthAtCoordWithGroundSupportAndField(x, y, groundSupport, forestField);
            var patch = getDarkForestPatchThresholdStrength(getDarkForestPatchFieldAtCoord(x, y));
            darkForestPatchStrength = patch <= 0.0
              ? 0.0
              : patch * getDarkForestPatchSupportStrength(forestStrength, forestField, groundSupport);
#end

            if (forestPaintStrength > 0.0 ||
                darkWoodsStrength > 0.0 ||
                darkForestPatchStrength > 0.0)
              {
                var forestColor = getForestColorAtPixel(px, py);
                if (forestPaintStrength > 0.0)
                  {
                    var alpha = Math.pow(forestPaintStrength, 1.45) * 0.44;
                    data[index] = Std.int(data[index] + (getColorChannel(forestColor, 16) - data[index]) * alpha);
                    data[index + 1] = Std.int(data[index + 1] +
                      (getColorChannel(forestColor, 8) - data[index + 1]) * alpha);
                    data[index + 2] = Std.int(data[index + 2] +
                      (getColorChannel(forestColor, 0) - data[index + 2]) * alpha);
                  }

                if (darkWoodsStrength > 0.0)
                  {
                    var woodsColor = getDarkWoodsColorAtPixel(px, py);
                    var woodsAlpha = Math.pow(darkWoodsStrength, 1.55) * 0.38;
                    data[index] = Std.int(data[index] + (getColorChannel(woodsColor, 16) - data[index]) * woodsAlpha);
                    data[index + 1] = Std.int(data[index + 1] +
                      (getColorChannel(woodsColor, 8) - data[index + 1]) * woodsAlpha);
                    data[index + 2] = Std.int(data[index + 2] +
                      (getColorChannel(woodsColor, 0) - data[index + 2]) * woodsAlpha);
                  }

                if (darkForestPatchStrength > 0.0)
                  {
                    var patchColor = getDarkForestPatchColorAtPixel(px, py);
                    var patchAlpha = Math.pow(darkForestPatchStrength, 0.8) * DARK_FOREST_PATCH_ALPHA;
                    data[index] = Std.int(data[index] + (getColorChannel(patchColor, 16) - data[index]) * patchAlpha);
                    data[index + 1] = Std.int(data[index + 1] +
                      (getColorChannel(patchColor, 8) - data[index + 1]) * patchAlpha);
                    data[index + 2] = Std.int(data[index + 2] +
                      (getColorChannel(patchColor, 0) - data[index + 2]) * patchAlpha);
                  }
              }
            index += 4;
          }

#if mydebug
      nowTS = haxe.Timer.stamp() * 1000.0;
      traceForestProfilePhase('paintForests.applyPatchOverlay', nowTS - phaseStartTS);
      phaseStartTS = nowTS;
#end
      ctx.putImageData(imageData, 0, 0);
#if mydebug
      nowTS = haxe.Timer.stamp() * 1000.0;
      traceForestProfilePhase('paintForests.putImageData', nowTS - phaseStartTS);
      traceForestProfileSummary('paintForests.summary patchPixels=' + patchPixelCount +
        ' totalPixels=' + (fullPixelWidth * fullPixelHeight));
      traceForestProfilePhase('paintForests.total', nowTS - totalStartTS);
#end
    }

// paint one debug visualization of the current wilderness layers
  function paintDebugViewIfRequested(): Bool
    {
      if (MAP_DEBUG_VIEW_MODE == MAP_DEBUG_VIEW_NORMAL)
        return false;

      if (MAP_DEBUG_VIEW_MODE == MAP_DEBUG_VIEW_GROUND)
        {
          paintGround();
          return true;
        }

      if (MAP_DEBUG_VIEW_MODE == MAP_DEBUG_VIEW_FOREST_RAW)
        {
          paintForestFieldDebug();
          return true;
        }

      if (MAP_DEBUG_VIEW_MODE == MAP_DEBUG_VIEW_FOREST_MASK)
        {
          paintForestMaskDebug();
          return true;
        }

      if (MAP_DEBUG_VIEW_MODE == MAP_DEBUG_VIEW_WOODS_RAW)
        {
          paintDarkWoodsFieldDebug();
          return true;
        }

      if (MAP_DEBUG_VIEW_MODE == MAP_DEBUG_VIEW_WOODS_THRESHOLD)
        {
          paintDarkWoodsThresholdDebug();
          return true;
        }

      if (MAP_DEBUG_VIEW_MODE == MAP_DEBUG_VIEW_WOODS_SUPPORT)
        {
          paintDarkWoodsSupportDebug();
          return true;
        }

      if (MAP_DEBUG_VIEW_MODE == MAP_DEBUG_VIEW_DARK_FOREST_PATCH_RAW)
        {
          paintDarkForestPatchFieldDebug();
          return true;
        }

      if (MAP_DEBUG_VIEW_MODE == MAP_DEBUG_VIEW_DARK_FOREST_PATCH_THRESHOLD)
        {
          paintDarkForestPatchThresholdDebug();
          return true;
        }

      if (MAP_DEBUG_VIEW_MODE == MAP_DEBUG_VIEW_DARK_FOREST_PATCH_MASK)
        {
          paintDarkForestPatchMaskDebug();
          return true;
        }

      if (MAP_DEBUG_VIEW_MODE == MAP_DEBUG_VIEW_WOODS_MASK)
        {
          paintDarkWoodsMaskDebug();
          return true;
        }

      if (MAP_DEBUG_VIEW_MODE == MAP_DEBUG_VIEW_FOREST_EDGE)
        {
          paintForestEdgeDebug();
          return true;
        }

      return false;
    }

// paint the forest-strength mask as a grayscale debug image
  function paintForestFieldDebug()
    {
      var imageData = ctx.createImageData(fullPixelWidth, fullPixelHeight);
      var data = imageData.data;
      var index = 0;

      for (py in 0...fullPixelHeight)
        for (px in 0...fullPixelWidth)
          {
            var shade = Std.int(clampFloat(getForestFieldAtPixel(px, py), 0.0, 1.0) * 255.0);
            data[index++] = shade;
            data[index++] = shade;
            data[index++] = shade;
            data[index++] = 0xFF;
          }

      ctx.putImageData(imageData, 0, 0);
    }

// paint the forest edge attenuation field as a grayscale debug image
  function paintForestEdgeDebug()
    {
      var imageData = ctx.createImageData(fullPixelWidth, fullPixelHeight);
      var data = imageData.data;
      var index = 0;

      for (py in 0...fullPixelHeight)
        for (px in 0...fullPixelWidth)
          {
            var shade = Std.int(clampFloat(getForestEdgeFactorAtPixel(px, py), 0.0, 1.0) * 255.0);
            data[index++] = shade;
            data[index++] = shade;
            data[index++] = shade;
            data[index++] = 0xFF;
          }

      ctx.putImageData(imageData, 0, 0);
    }

// paint the forest-strength mask as a grayscale debug image
  function paintForestMaskDebug()
    {
      var imageData = ctx.createImageData(fullPixelWidth, fullPixelHeight);
      var data = imageData.data;
      var index = 0;

      for (py in 0...fullPixelHeight)
        for (px in 0...fullPixelWidth)
          {
            var forestStrength = getForestStrengthAtPixel(px, py);
            var shade = Std.int(clampFloat(forestStrength, 0.0, 1.0) * 255.0);
            data[index++] = shade;
            data[index++] = shade;
            data[index++] = shade;
            data[index++] = 0xFF;
          }

      ctx.putImageData(imageData, 0, 0);
    }

// paint the dark-woods raw field as a grayscale debug image
  function paintDarkWoodsFieldDebug()
    {
      var imageData = ctx.createImageData(fullPixelWidth, fullPixelHeight);
      var data = imageData.data;
      var index = 0;

      for (py in 0...fullPixelHeight)
        for (px in 0...fullPixelWidth)
          {
            var shade = Std.int(clampFloat(getDarkWoodsFieldAtPixel(px, py), 0.0, 1.0) * 255.0);
            data[index++] = shade;
            data[index++] = shade;
            data[index++] = shade;
            data[index++] = 0xFF;
          }

      ctx.putImageData(imageData, 0, 0);
    }

// paint the thresholded dark-woods field as a grayscale debug image
  function paintDarkWoodsThresholdDebug()
    {
      var imageData = ctx.createImageData(fullPixelWidth, fullPixelHeight);
      var data = imageData.data;
      var index = 0;

      for (py in 0...fullPixelHeight)
        for (px in 0...fullPixelWidth)
          {
            var shade = Std.int(clampFloat(getDarkWoodsThresholdStrength(getDarkWoodsFieldAtPixel(px, py)), 0.0, 1.0) * 255.0);
            data[index++] = shade;
            data[index++] = shade;
            data[index++] = shade;
            data[index++] = 0xFF;
          }

      ctx.putImageData(imageData, 0, 0);
    }

// paint the forest support used by dark woods as a grayscale debug image
  function paintDarkWoodsSupportDebug()
    {
      var imageData = ctx.createImageData(fullPixelWidth, fullPixelHeight);
      var data = imageData.data;
      var index = 0;

      for (py in 0...fullPixelHeight)
        for (px in 0...fullPixelWidth)
          {
            var forestStrength = getForestStrengthAtPixel(px, py);
            var forestSupport = getDarkWoodsForestSupportAtPixel(px, py, forestStrength);
            var shade = Std.int(clampFloat(getDarkWoodsSupportStrength(forestSupport), 0.0, 1.0) * 255.0);
            data[index++] = shade;
            data[index++] = shade;
            data[index++] = shade;
            data[index++] = 0xFF;
          }

      ctx.putImageData(imageData, 0, 0);
    }

// paint the raw dark-forest patch field as a grayscale debug image
  function paintDarkForestPatchFieldDebug()
    {
      var imageData = ctx.createImageData(fullPixelWidth, fullPixelHeight);
      var data = imageData.data;
      var index = 0;

      for (py in 0...fullPixelHeight)
        for (px in 0...fullPixelWidth)
          {
            var shade = Std.int(clampFloat(getDarkForestPatchFieldAtPixel(px, py), 0.0, 1.0) * 255.0);
            data[index++] = shade;
            data[index++] = shade;
            data[index++] = shade;
            data[index++] = 0xFF;
          }

      ctx.putImageData(imageData, 0, 0);
    }

// paint the thresholded dark-forest patch field as a grayscale debug image
  function paintDarkForestPatchThresholdDebug()
    {
      var imageData = ctx.createImageData(fullPixelWidth, fullPixelHeight);
      var data = imageData.data;
      var index = 0;

      for (py in 0...fullPixelHeight)
        for (px in 0...fullPixelWidth)
          {
            var shade = Std.int(clampFloat(getDarkForestPatchThresholdStrength(
              getDarkForestPatchFieldAtPixel(px, py)), 0.0, 1.0) * 255.0);
            data[index++] = shade;
            data[index++] = shade;
            data[index++] = shade;
            data[index++] = 0xFF;
          }

      ctx.putImageData(imageData, 0, 0);
    }

// paint the final dark-forest patch mask as a grayscale debug image
  function paintDarkForestPatchMaskDebug()
    {
      var imageData = ctx.createImageData(fullPixelWidth, fullPixelHeight);
      var data = imageData.data;
      var index = 0;

      for (py in 0...fullPixelHeight)
        for (px in 0...fullPixelWidth)
          {
            var forestStrength = getForestStrengthAtPixel(px, py);
            var strength = clampFloat(getDarkForestPatchStrengthAtPixel(px, py, forestStrength), 0.0, 1.0);
            var shade = Std.int(strength * 255.0);
            data[index++] = shade;
            data[index++] = shade;
            data[index++] = shade;
            data[index++] = 0xFF;
          }

      ctx.putImageData(imageData, 0, 0);
    }

// paint the dark-woods-strength mask as a grayscale debug image
  function paintDarkWoodsMaskDebug()
    {
      var imageData = ctx.createImageData(fullPixelWidth, fullPixelHeight);
      var data = imageData.data;
      var index = 0;

      for (py in 0...fullPixelHeight)
        for (px in 0...fullPixelWidth)
          {
            var forestStrength = getForestStrengthAtPixel(px, py);
            var woodsStrength = getDarkWoodsStrengthAtPixel(px, py, forestStrength);
            var shade = Std.int(clampFloat(woodsStrength, 0.0, 1.0) * 255.0);
            data[index++] = shade;
            data[index++] = shade;
            data[index++] = shade;
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

// return whether one map cell is wilderness ground as a numeric value
  function getGroundAreaValue(cellX: Int, cellY: Int): Float
    {
      if (!ENABLE_REGION_CITY_CONTENT)
        return 1.0;
      return areaTypes[clampInt(cellX, 0, fullCellWidth - 1)][clampInt(cellY, 0, fullCellHeight - 1)] == AREA_GROUND ? 1.0 : 0.0;
    }

// return smoothed wilderness support at one map-space coordinate
  function getGroundAreaSupportAtCoord(x: Float, y: Float): Float
    {
      if (!ENABLE_REGION_CITY_CONTENT)
        return 1.0;
      return sampleGroundAreaSupportFieldAtCoord(x, y);
    }

// return raw bilinearly blended wilderness occupancy at one map-space coordinate
  function getGroundAreaBlendAtCoord(x: Float, y: Float): Float
    {
      var fx = clampFloat(x, 0.0, fullCellWidth - 1.001);
      var fy = clampFloat(y, 0.0, fullCellHeight - 1.001);
      var x0 = Std.int(Math.floor(fx));
      var y0 = Std.int(Math.floor(fy));
      var x1 = clampInt(x0 + 1, 0, fullCellWidth - 1);
      var y1 = clampInt(y0 + 1, 0, fullCellHeight - 1);
      var tx = fx - x0;
      var ty = fy - y0;
      var v00 = getGroundAreaValue(x0, y0);
      var v10 = getGroundAreaValue(x1, y0);
      var v01 = getGroundAreaValue(x0, y1);
      var v11 = getGroundAreaValue(x1, y1);
      var top = v00 + (v10 - v00) * tx;
      var bottom = v01 + (v11 - v01) * tx;
      return top + (bottom - top) * ty;
    }

// return the wilderness base color at one pixel with broad local variation
  function getGroundColorAtPixel(px: Int, py: Int, baseColor: Int): Int
    {
      var x = (px + 0.5) / CLEAN_TILE_SIZE;
      var y = (py + 0.5) / CLEAN_TILE_SIZE;
      var broad = sampleForestValueNoise(x / 14.0, y / 14.0, 811);
      var detail = sampleForestValueNoise(x / 2.6, y / 2.6, 823);
      var warmth = sampleForestValueNoise(x / 4.2, y / 4.2, 839);
      var tone = broad * 0.22 + detail * 0.78;
      var varied = lerpColor(COLOR_GROUND_DARK, COLOR_GROUND_LIGHT, tone);
      var warmBlend = clampFloat((warmth - 0.60) / 0.24, 0.0, 1.0) * 0.24;
      varied = lerpColor(varied, COLOR_GROUND_WARM, warmBlend);
      return lerpColor(baseColor, varied, 0.12 + detail * 0.10);
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

// return how strongly one ground tile should read as forest
  function getForestStrengthAtCell(cellX: Int, cellY: Int): Float
    {
      var groundSupport = getForestGroundSupportAtCell(cellX, cellY);
      if (groundSupport <= 0.0)
        return 0.0;

      return getForestStrengthFromBaseAndEdge(
        getForestBaseStrength(getForestFieldAtCell(cellX, cellY)) * groundSupport,
        getForestEdgeFactorAtCell(cellX, cellY));
    }

// return how strongly one pixel should read as forest
  function getForestStrengthAtPixel(px: Int, py: Int): Float
    {
      var groundSupport = getForestGroundSupportAtPixel(px, py);
      return getForestStrengthAtCoordWithGroundSupport(
        (px + 0.5) / CLEAN_TILE_SIZE,
        (py + 0.5) / CLEAN_TILE_SIZE,
        groundSupport);
    }

// return the canopy color for one forested pixel
  function getForestColorAtPixel(px: Int, py: Int): Int
    {
      var x = (px + 0.5) / CLEAN_TILE_SIZE;
      var y = (py + 0.5) / CLEAN_TILE_SIZE;
      var broad = sampleForestValueNoise(x / 4.6, y / 4.6, 743);
      var detail = sampleForestValueNoise(x / 2.0, y / 2.0, 751);
      var accent = sampleForestValueNoise(x / 1.0, y / 1.0, 761);
      var warmth = sampleForestValueNoise(x / 3.2, y / 3.2, 773);
      var canopy = lerpColor(COLOR_FOREST_DARK, COLOR_FOREST_MID, broad * 0.72 + detail * 0.28);
      canopy = lerpColor(canopy, COLOR_FOREST_LIGHT,
        clampFloat((detail - 0.18) / 0.82, 0.0, 1.0) * 0.66 + accent * 0.18);
      return lerpColor(canopy, COLOR_FOREST_WARM,
        clampFloat((warmth - 0.60) / 0.26, 0.0, 1.0) * 0.34);
    }

// return how strongly one forested cell should read as dark woods
  function getDarkWoodsStrengthAtCell(cellX: Int, cellY: Int, forestStrength: Float): Float
    {
      var forestSupport = getDarkWoodsForestSupportAtCell(cellX, cellY, forestStrength);
      if (forestSupport <= 0.0)
        return 0.0;

      var woods = getDarkWoodsThresholdStrength(getDarkWoodsFieldAtCell(cellX, cellY));
      return woods * getDarkWoodsSupportStrength(forestSupport);
    }

// return how strongly one forested pixel should read as dark woods
  function getDarkWoodsStrengthAtPixel(px: Int, py: Int, forestStrength: Float): Float
    {
      var forestSupport = getDarkWoodsForestSupportAtPixel(px, py, forestStrength);
      if (forestSupport <= 0.0)
        return 0.0;

      var woods = getDarkWoodsThresholdStrength(getDarkWoodsFieldAtPixel(px, py));
      return woods * getDarkWoodsSupportStrength(forestSupport);
    }

// return the canopy color for one dark-woods pixel
  function getDarkWoodsColorAtPixel(px: Int, py: Int): Int
    {
      var x = (px + 0.5) / CLEAN_TILE_SIZE;
      var y = (py + 0.5) / CLEAN_TILE_SIZE;
      var broad = sampleForestValueNoise(x / 3.8, y / 3.8, 839);
      var detail = sampleForestValueNoise(x / 1.6, y / 1.6, 853);
      return lerpColor(COLOR_WOODS_DARK, COLOR_WOODS_LIGHT, broad * 0.74 + detail * 0.26);
    }

// return the overlay color for one distinct dark-forest patch pixel
  function getDarkForestPatchColorAtPixel(px: Int, py: Int): Int
    {
      var x = (px + 0.5) / CLEAN_TILE_SIZE;
      var y = (py + 0.5) / CLEAN_TILE_SIZE;
      var broad = sampleForestValueNoise(x / 5.8, y / 5.8, 881);
      var detail = sampleForestValueNoise(x / 2.6, y / 2.6, 887);
      return lerpColor(COLOR_DARK_FOREST_PATCH_DARK, COLOR_DARK_FOREST_PATCH_LIGHT,
        broad * 0.30 + detail * 0.18);
    }

// return the blended raw forest field at one cell
  function getForestFieldAtCell(cellX: Int, cellY: Int): Float
    {
      return getForestFieldAtCoord(cellX, cellY);
    }

// return the blended raw forest field at one pixel
  function getForestFieldAtPixel(px: Int, py: Int): Float
    {
      return getForestFieldAtCoord((px + 0.5) / CLEAN_TILE_SIZE, (py + 0.5) / CLEAN_TILE_SIZE);
    }

// return the blended raw forest field at one coordinate
  function getForestFieldAtCoord(x: Float, y: Float): Float
    {
      var broad = sampleForestValueNoise(x / FOREST_NOISE_SCALE, y / FOREST_NOISE_SCALE, 701);
      var detail = sampleForestValueNoise(x / FOREST_DETAIL_SCALE, y / FOREST_DETAIL_SCALE, 727);
      return broad * (1.0 - FOREST_DETAIL_BLEND) + detail * FOREST_DETAIL_BLEND;
    }

// return the thresholded forest strength before edge suppression
  function getForestBaseStrength(field: Float): Float
    {
      var start = FOREST_PATCH_THRESHOLD - FOREST_PATCH_SOFTNESS;
      var end = FOREST_PATCH_THRESHOLD + FOREST_PATCH_SOFTNESS;
      var t = clampFloat((field - start) / Math.max(end - start, 0.0001), 0.0, 1.0);
      return t * t * (3.0 - 2.0 * t);
    }

// compute one adaptive dark-forest threshold that preserves at least the target visible-map coverage
  function computeDarkForestPatchThresholdValue(): Float
    {
      var values = [];
      var targetCoverage = getDarkForestPatchCoverageTarget();
      var subcellScale = DARK_FOREST_PATCH_GRID_SUBCELLS;
      var visibleGridWidth = regionWidth * subcellScale;
      var visibleGridHeight = regionHeight * subcellScale;
      var minGridX = HALO_CELLS * subcellScale;
      var minGridY = HALO_CELLS * subcellScale;

      for (gridY in minGridY...minGridY + visibleGridHeight)
        for (gridX in minGridX...minGridX + visibleGridWidth)
          {
            var x = (gridX + 0.5) / subcellScale;
            var y = (gridY + 0.5) / subcellScale;
            var groundSupport = getGroundAreaSupportAtCoord(x, y);
            if (groundSupport <= 0.0)
              continue;

            var forestField = getForestFieldAtCoord(x, y);
            var forestStrength = getForestStrengthAtCoordWithGroundSupportAndField(x, y, groundSupport, forestField);
            var support = getDarkForestPatchSupportStrength(forestStrength, forestField, groundSupport);
            if (support <= 0.0)
              continue;

            var field = getDarkForestPatchFieldAtCoord(x, y);
            if (field <= 0.0)
              continue;
            values.push(field);
          }

      if (values.length <= 0)
        return DARK_FOREST_PATCH_THRESHOLD;

      var targetCount = Std.int(Math.ceil(visibleGridWidth * visibleGridHeight * targetCoverage));
      targetCount = clampInt(targetCount, 0, values.length);
      if (targetCount <= 0)
        return DARK_FOREST_PATCH_THRESHOLD;

      values.sort(function(a: Float, b: Float)
        {
          return a < b ? -1 : (a > b ? 1 : 0);
        });

      return values[values.length - targetCount];
    }

// return the seeded visible-map dark-forest coverage target for this generation
  function getDarkForestPatchCoverageTarget(): Float
    {
      return MIN_DARK_FOREST_MAP_COVERAGE +
        getStableNoise(mapSeed, regionWidth, regionHeight, fullCellWidth, 1087) *
        (MAX_DARK_FOREST_MAP_COVERAGE - MIN_DARK_FOREST_MAP_COVERAGE);
    }

// return forest strength after edge attenuation without fully erasing edge pixels
  function getForestStrengthFromBaseAndEdge(baseStrength: Float, edgeFactor: Float): Float
    {
      if (baseStrength <= 0.0)
        return 0.0;
      return baseStrength * (FOREST_EDGE_MIN_KEEP + (1.0 - FOREST_EDGE_MIN_KEEP) * edgeFactor);
    }

// return the smoothed ground support used by cell-level forest placement
  function getForestGroundSupportAtCell(cellX: Int, cellY: Int): Float
    {
      return getGroundAreaSupportAtCoord(cellX + 0.5, cellY + 0.5);
    }

// return the smoothed ground support used by pixel-level forest placement
  function getForestGroundSupportAtPixel(px: Int, py: Int): Float
    {
      return getGroundAreaSupportAtCoord((px + 0.5) / CLEAN_TILE_SIZE, (py + 0.5) / CLEAN_TILE_SIZE);
    }

// return how strongly one map-space coordinate should read as forest
  function getForestStrengthAtCoord(x: Float, y: Float): Float
    {
      var groundSupport = getGroundAreaSupportAtCoord(x, y);
      return getForestStrengthAtCoordWithGroundSupportAndField(x, y, groundSupport, getForestFieldAtCoord(x, y));
    }

// return how strongly one map-space coordinate should read as forest with precomputed support
  function getForestStrengthAtCoordWithGroundSupport(x: Float, y: Float, groundSupport: Float): Float
    {
      return getForestStrengthAtCoordWithGroundSupportAndField(x, y, groundSupport, getForestFieldAtCoord(x, y));
    }

// return how strongly one map-space coordinate should read as forest with precomputed support and field
  function getForestStrengthAtCoordWithGroundSupportAndField(x: Float, y: Float, groundSupport: Float,
      forestField: Float): Float
    {
      if (groundSupport <= 0.0)
        return 0.0;

      return getForestStrengthFromBaseAndEdge(
        getForestBaseStrength(forestField) * groundSupport,
        getForestEdgeFactorAtCoord(x, y));
    }

// return the strength of the canopy texture overlay for one forest tile
  function getForestTextureStrength(forestStrength: Float): Float
    {
      var t = clampFloat((forestStrength - FOREST_TEXTURE_THRESHOLD) / Math.max(FOREST_TEXTURE_FADE, 0.0001), 0.0, 1.0);
      return t * t * (3.0 - 2.0 * t);
    }

// return the final dark-forest patch strength at one pixel
  function getDarkForestPatchStrengthAtPixel(px: Int, py: Int, forestStrength: Float): Float
    {
      var patch = getDarkForestPatchThresholdStrength(getDarkForestPatchFieldAtPixel(px, py));
      if (patch <= 0.0)
        return 0.0;
      return patch * getDarkForestPatchSupportAtPixel(px, py, forestStrength);
    }

// return the support mask used to keep dark-forest patches inside plausible forest
  function getDarkForestPatchSupportAtPixel(px: Int, py: Int, forestStrength: Float): Float
    {
      var x = (px + 0.5) / CLEAN_TILE_SIZE;
      var y = (py + 0.5) / CLEAN_TILE_SIZE;
      return getDarkForestPatchSupportAtCoord(x, y, forestStrength);
    }

// return the support mask used to keep dark-forest patches inside plausible forest at one coordinate
  function getDarkForestPatchSupportAtCoord(x: Float, y: Float, forestStrength: Float): Float
    {
      var groundSupport = getGroundAreaSupportAtCoord(x, y);
      return getDarkForestPatchSupportAtCoordWithGroundSupport(x, y, forestStrength, groundSupport);
    }

// return the support mask used to keep dark-forest patches inside plausible forest with precomputed support
  function getDarkForestPatchSupportAtCoordWithGroundSupport(x: Float, y: Float, forestStrength: Float,
      groundSupport: Float): Float
    {
      if (groundSupport <= 0.0)
        return 0.0;
      return getDarkForestPatchSupportStrength(forestStrength, getForestFieldAtCoord(x, y), groundSupport);
    }

// return the support mask used to keep dark-forest patches inside plausible forest from precomputed values
  function getDarkForestPatchSupportStrength(forestStrength: Float, forestField: Float, groundSupport: Float): Float
    {
      var forestBias = clampFloat((Math.max(forestStrength, forestField) - 0.28) / 0.40, 0.0, 1.0);
      forestBias = forestBias * forestBias * (3.0 - 2.0 * forestBias);
      var support = groundSupport * (0.70 + forestBias * 0.30);
      return 0.55 + support * 0.45;
    }

// return the softened dark-forest patch response from one raw field sample
  function getDarkForestPatchThresholdStrength(field: Float): Float
    {
      if (field <= 0.0)
        return 0.0;

      var start = Math.max(0.0, darkForestPatchThresholdValue - DARK_FOREST_PATCH_SOFTNESS);
      var end = Math.max(start + 0.0001, darkForestPatchThresholdValue + DARK_FOREST_PATCH_SOFTNESS);
      var t = clampFloat((field - start) / Math.max(end - start, 0.0001), 0.0, 1.0);
      return t * t * (3.0 - 2.0 * t);
    }

// return the forest-domain signal used to place dark-forest patches
  function getDarkForestPatchForestDomainAtCoord(x: Float, y: Float): Float
    {
      var groundSupport = getGroundAreaSupportAtCoord(x, y);
      if (groundSupport <= 0.0)
        return 0.0;

      var forestBase = getForestBaseStrength(getForestFieldAtCoord(x, y)) * groundSupport;
      var t = clampFloat((forestBase - 0.08) / 0.44, 0.0, 1.0);
      return t * t * (3.0 - 2.0 * t);
    }

// return the softened dark-woods threshold response from one raw field sample
  function getDarkWoodsThresholdStrength(field: Float): Float
    {
      var start = WOODS_PATCH_THRESHOLD - WOODS_PATCH_SOFTNESS;
      var end = WOODS_PATCH_THRESHOLD + WOODS_PATCH_SOFTNESS;
      var t = clampFloat((field - start) / Math.max(end - start, 0.0001), 0.0, 1.0);
      return t * t * (3.0 - 2.0 * t);
    }

// return the forest-support ramp used by the dark-woods mask
  function getDarkWoodsSupportStrength(forestSupport: Float): Float
    {
      return clampFloat((forestSupport - WOODS_MIN_FOREST_STRENGTH) /
        Math.max(1.0 - WOODS_MIN_FOREST_STRENGTH, 0.0001), 0.0, 1.0);
    }

// return the softened forest edge factor from one cell
  function getForestEdgeFactorAtCell(cellX: Int, cellY: Int): Float
    {
      if (!ENABLE_REGION_CITY_CONTENT)
        return 1.0;
      return getForestEdgeFactorFromNeighborhood(groundNeighborhoodField[cellX][cellY]);
    }

// return the softened forest edge factor from one pixel
  function getForestEdgeFactorAtPixel(px: Int, py: Int): Float
    {
      if (!ENABLE_REGION_CITY_CONTENT)
        return 1.0;
      return getForestEdgeFactorFromNeighborhood(sampleGroundNeighborhoodAtPixel(px, py));
    }

// return the softened forest edge factor from one map-space coordinate
  function getForestEdgeFactorAtCoord(x: Float, y: Float): Float
    {
      if (!ENABLE_REGION_CITY_CONTENT)
        return 1.0;
      return getForestEdgeFactorFromNeighborhood(sampleGroundNeighborhoodAtCoord(x, y));
    }

// return one softened forest edge factor from a neighborhood ratio
  function getForestEdgeFactorFromNeighborhood(neighborhood: Float): Float
    {
      var t = clampFloat((neighborhood - FOREST_EDGE_START) / Math.max(FOREST_EDGE_FADE, 0.0001), 0.0, 1.0);
      return Math.pow(t, 0.70);
    }

// return the blended raw dark-woods field at one cell
  function getDarkWoodsFieldAtCell(cellX: Int, cellY: Int): Float
    {
      return getDarkWoodsFieldAtCoord(cellX, cellY);
    }

// return the blended raw dark-woods field at one pixel
  function getDarkWoodsFieldAtPixel(px: Int, py: Int): Float
    {
      return getDarkWoodsFieldAtCoord((px + 0.5) / CLEAN_TILE_SIZE, (py + 0.5) / CLEAN_TILE_SIZE);
    }

// return the blended raw dark-woods field at one coordinate
  function getDarkWoodsFieldAtCoord(x: Float, y: Float): Float
    {
      var broad = sampleForestValueNoise(x / WOODS_NOISE_SCALE, y / WOODS_NOISE_SCALE, 821);
      var detail = sampleForestValueNoise(x / WOODS_DETAIL_SCALE, y / WOODS_DETAIL_SCALE, 829);
      return broad * 0.72 + detail * 0.28;
    }

// return the blended raw dark-forest patch field at one pixel
  function getDarkForestPatchFieldAtPixel(px: Int, py: Int): Float
    {
      return getDarkForestPatchFieldAtCoord((px + 0.5) / CLEAN_TILE_SIZE, (py + 0.5) / CLEAN_TILE_SIZE);
    }

// return the blended raw dark-forest patch field at one coordinate
  function getDarkForestPatchFieldAtCoord(x: Float, y: Float): Float
    {
      return sampleDarkForestPatchFieldAtCoord(x, y);
    }

// return forest value noise salted with the current map seed
  function sampleSeededForestValueNoise(x: Float, y: Float, salt: Int): Float
    {
      return sampleForestValueNoise(x, y, salt + mapSeed);
    }

// sample the continuous dark-forest field directly from the seeded grove lobes
  function sampleDarkForestPatchFieldAtCoord(x: Float, y: Float): Float
    {
      var best = 0.0;
      var binX = clampInt(Std.int(Math.floor(clampFloat(x, 0.0, fullCellWidth - 1.001) / DARK_FOREST_PATCH_BIN_SIZE)),
        0, darkForestPatchLobeBinWidth - 1);
      var binY = clampInt(Std.int(Math.floor(clampFloat(y, 0.0, fullCellHeight - 1.001) / DARK_FOREST_PATCH_BIN_SIZE)),
        0, darkForestPatchLobeBinHeight - 1);
      var lobeIndices = darkForestPatchLobeBins[binY * darkForestPatchLobeBinWidth + binX];

      for (lobeIndex in lobeIndices)
        {
          var lobe = darkForestPatchLobes[lobeIndex];
          if (x < lobe.minX ||
              x > lobe.maxX ||
              y < lobe.minY ||
              y > lobe.maxY)
            continue;

          var dx = x - lobe.centerX;
          var dy = y - lobe.centerY;
          var localX = (dx * lobe.shapeCos + dy * lobe.shapeSin) / Math.max(lobe.radiusX, 0.0001);
          var localY = (-dx * lobe.shapeSin + dy * lobe.shapeCos) / Math.max(lobe.radiusY, 0.0001);
          var distance = Math.sqrt(localX * localX + localY * localY);
          if (distance > 1.25)
            continue;

// add light seeded edge breakup without quantizing the grove shape to a grid
          var edgeNoise = sampleSeededForestValueNoise(
            (x + lobe.groveIndex * 13 + lobe.lobeIndex * 7) / DARK_FOREST_PATCH_DETAIL_SCALE,
            (y - lobe.groveIndex * 11 + lobe.lobeIndex * 5) / DARK_FOREST_PATCH_DETAIL_SCALE,
            1021 + lobe.lobeIndex * 17);
          var edgeScale = 1.0 + (edgeNoise - 0.5) * DARK_FOREST_PATCH_DETAIL_BLEND * 1.8;
          var strength = clampFloat(1.0 - distance / Math.max(edgeScale, 0.0001), 0.0, 1.0);
          if (strength <= 0.0)
            continue;

          strength = strength * strength * (3.0 - 2.0 * strength);
          if (strength > best)
            {
              best = strength;
              if (best >= 0.999)
                return 1.0;
            }
        }

      return best;
    }

// sample the continuous visual ground-support field with short support-style smoothing
  function sampleGroundAreaSupportFieldAtCoord(x: Float, y: Float): Float
    {
      var warpX = (sampleSeededForestValueNoise(
        x / GROUND_BORDER_WARP_SCALE,
        y / GROUND_BORDER_WARP_SCALE,
        541) - 0.5) * GROUND_BORDER_WARP_STRENGTH;
      var warpY = (sampleSeededForestValueNoise(
        (x + 37.0) / GROUND_BORDER_WARP_SCALE,
        (y - 19.0) / GROUND_BORDER_WARP_SCALE,
        547) - 0.5) * GROUND_BORDER_WARP_STRENGTH;
      var base = getGroundAreaBlendAtCoord(x + warpX, y + warpY);
      if (base <= 0.0)
        return 0.0;
      if (base >= 1.0)
        return 1.0;

// shape a short continuous edge band around the seeded border threshold
      var broadNoise = sampleSeededForestValueNoise(
        x / GROUND_BORDER_BREAKUP_SCALE,
        y / GROUND_BORDER_BREAKUP_SCALE,
        571);
      var detailNoise = sampleSeededForestValueNoise(
        x / (GROUND_BORDER_BREAKUP_SCALE * 0.55),
        y / (GROUND_BORDER_BREAKUP_SCALE * 0.55),
        577);
      var edgeNoise = broadNoise * 0.72 + detailNoise * 0.28;
      var threshold = 0.5 + (edgeNoise - 0.5) * GROUND_BORDER_BREAKUP_STRENGTH;
      var edgeBand = GROUND_BORDER_SOFTNESS * (8.0 / Math.max(GROUND_AREA_GRID_SUBCELLS, 1));
      var t = clampFloat((base - (threshold - edgeBand)) / Math.max(edgeBand * 2.0, 0.0001), 0.0, 1.0);
      return t * t * (3.0 - 2.0 * t);
    }

// return the forest support used to gate woods on one cell
  function getDarkWoodsForestSupportAtCell(cellX: Int, cellY: Int, forestStrength: Float): Float
    {
      return Math.max(forestStrength, getForestFieldAtCell(cellX, cellY));
    }

// return the forest support used to gate woods on one pixel
  function getDarkWoodsForestSupportAtPixel(px: Int, py: Int, forestStrength: Float): Float
    {
      return Math.max(forestStrength, getForestFieldAtPixel(px, py));
    }

// return one smooth value-noise forest sample at fractional tile coordinates
  function sampleForestValueNoise(x: Float, y: Float, salt: Int): Float
    {
      var x0 = Std.int(Math.floor(x));
      var y0 = Std.int(Math.floor(y));
      var x1 = x0 + 1;
      var y1 = y0 + 1;
      var tx = getForestNoiseFade(x - x0);
      var ty = getForestNoiseFade(y - y0);
      var v00 = hashFloat(x0, y0, salt);
      var v10 = hashFloat(x1, y0, salt);
      var v01 = hashFloat(x0, y1, salt);
      var v11 = hashFloat(x1, y1, salt);
      var top = v00 + (v10 - v00) * tx;
      var bottom = v01 + (v11 - v01) * tx;
      return top + (bottom - top) * ty;
    }

// return one eased interpolation factor for forest value noise
  function getForestNoiseFade(t: Float): Float
    {
      var tt = clampFloat(t, 0.0, 1.0);
      return tt * tt * (3.0 - 2.0 * tt);
    }

// return the fraction of nearby tiles that are wilderness ground
  function getGroundNeighborhoodRatio(cellX: Int, cellY: Int, radius: Int): Float
    {
      if (!ENABLE_REGION_CITY_CONTENT)
        return 1.0;
      var groundCount = 0;
      var total = 0;

      for (yy in cellY - radius...cellY + radius + 1)
        for (xx in cellX - radius...cellX + radius + 1)
          {
            if (xx < 0 ||
                yy < 0 ||
                xx >= fullCellWidth ||
                yy >= fullCellHeight)
              continue;
            total++;
            if (getGroundAreaValue(xx, yy) > 0.5)
              groundCount++;
          }

      if (total <= 0)
        return 0.0;
      return groundCount / total;
    }

// build one cached wilderness-neighborhood field for forest edge sampling
  function buildGroundNeighborhoodField(radius: Int): Array<Array<Float>>
    {
      var field = [];

      for (cellX in 0...fullCellWidth)
        {
          var col = [];
          for (cellY in 0...fullCellHeight)
            col.push(getGroundNeighborhoodRatio(cellX, cellY, radius));
          field.push(col);
        }

      return field;
    }

// build one seeded set of continuous dark-forest grove lobes
  function buildDarkForestPatchLobes(): Array<DarkForestPatchLobe>
    {
      var lobes = [];
      var lobeSpan = DARK_FOREST_PATCH_MAX_LOBES - DARK_FOREST_PATCH_MIN_LOBES + 1;

      for (groveIndex in 0...DARK_FOREST_PATCH_COUNT)
        {
          var centerX = 0.0;
          var centerY = 0.0;
          var bestScore = -1.0;

// choose one grove center from a few seeded candidates so patches land in plausible forest territory
          for (centerAttempt in 0...4)
            {
              var candidateX = getStableNoise(mapSeed, groveIndex, centerAttempt, 911, fullCellWidth) *
                Math.max(fullCellWidth - 1.0, 0.0);
              var candidateY = getStableNoise(mapSeed, groveIndex, centerAttempt, 919, fullCellHeight) *
                Math.max(fullCellHeight - 1.0, 0.0);
              var candidateScore = getDarkForestPatchForestDomainAtCoord(candidateX, candidateY);
              if (candidateScore <= bestScore)
                continue;
              centerX = candidateX;
              centerY = candidateY;
              bestScore = candidateScore;
            }

          var baseRadius = DARK_FOREST_PATCH_MIN_RADIUS +
            getStableNoise(mapSeed, groveIndex, fullCellWidth + fullCellHeight, 1, 929) *
            (DARK_FOREST_PATCH_MAX_RADIUS - DARK_FOREST_PATCH_MIN_RADIUS);
          var lobeCount = DARK_FOREST_PATCH_MIN_LOBES +
            clampInt(Std.int(getStableNoise(mapSeed, groveIndex, 2, fullCellWidth, 937) * lobeSpan),
              0, lobeSpan - 1);

// store a few continuous lobes for analytic grove sampling
          for (lobeIndex in 0...lobeCount)
            {
              var lobeAngle = getStableNoise(mapSeed, groveIndex, lobeIndex, 947, 953) * Math.PI * 2.0;
              var lobeOffset = (lobeIndex == 0
                ? 0.0
                : getStableNoise(mapSeed, groveIndex, lobeIndex, 967, 971) * DARK_FOREST_PATCH_LOBE_SPREAD);
              var lobeCenterX = clampFloat(centerX + Math.cos(lobeAngle) * lobeOffset, 0.0, fullCellWidth - 1.0);
              var lobeCenterY = clampFloat(centerY + Math.sin(lobeAngle) * lobeOffset, 0.0, fullCellHeight - 1.0);
              var lobeRadius = baseRadius * (0.58 +
                getStableNoise(mapSeed, groveIndex, lobeIndex, 977, 983) * 0.52);
              var lobeAspect = 0.72 +
                getStableNoise(mapSeed, groveIndex, lobeIndex, 989, 997) * 0.56;
              var radiusX = lobeRadius * lobeAspect;
              var radiusY = lobeRadius / lobeAspect;
              var shapeAngle = getStableNoise(mapSeed, groveIndex, lobeIndex, 1009, 1013) * Math.PI * 2.0;
              var shapeCos = Math.cos(shapeAngle);
              var shapeSin = Math.sin(shapeAngle);
              var maxRadius = Math.max(radiusX, radiusY);
              var boundRadius = maxRadius * (1.25 + DARK_FOREST_PATCH_DETAIL_BLEND * 0.9);

              lobes.push({
                groveIndex: groveIndex,
                lobeIndex: lobeIndex,
                centerX: lobeCenterX,
                centerY: lobeCenterY,
                radiusX: radiusX,
                radiusY: radiusY,
                shapeCos: shapeCos,
                shapeSin: shapeSin,
                minX: Math.max(lobeCenterX - boundRadius, 0.0),
                minY: Math.max(lobeCenterY - boundRadius, 0.0),
                maxX: Math.min(lobeCenterX + boundRadius, fullCellWidth - 1.0),
                maxY: Math.min(lobeCenterY + boundRadius, fullCellHeight - 1.0),
              });
            }
        }

      return lobes;
    }

// build coarse lobe bins for faster dark-forest field sampling
  function buildDarkForestPatchLobeBins(): Array<Array<Int>>
    {
      darkForestPatchLobeBinWidth = Std.int(Math.ceil(fullCellWidth / DARK_FOREST_PATCH_BIN_SIZE));
      darkForestPatchLobeBinHeight = Std.int(Math.ceil(fullCellHeight / DARK_FOREST_PATCH_BIN_SIZE));
      var bins = [];

      for (i in 0...darkForestPatchLobeBinWidth * darkForestPatchLobeBinHeight)
        bins.push([]);

      for (lobeIndex in 0...darkForestPatchLobes.length)
        {
          var lobe = darkForestPatchLobes[lobeIndex];
          var minBinX = clampInt(Std.int(Math.floor(lobe.minX / DARK_FOREST_PATCH_BIN_SIZE)), 0,
            darkForestPatchLobeBinWidth - 1);
          var maxBinX = clampInt(Std.int(Math.floor(lobe.maxX / DARK_FOREST_PATCH_BIN_SIZE)), 0,
            darkForestPatchLobeBinWidth - 1);
          var minBinY = clampInt(Std.int(Math.floor(lobe.minY / DARK_FOREST_PATCH_BIN_SIZE)), 0,
            darkForestPatchLobeBinHeight - 1);
          var maxBinY = clampInt(Std.int(Math.floor(lobe.maxY / DARK_FOREST_PATCH_BIN_SIZE)), 0,
            darkForestPatchLobeBinHeight - 1);

// place each lobe into every overlapping coarse bin
          for (binY in minBinY...maxBinY + 1)
            for (binX in minBinX...maxBinX + 1)
              bins[binY * darkForestPatchLobeBinWidth + binX].push(lobeIndex);
        }

      return bins;
    }

// sample the cached wilderness-neighborhood field at one pixel
  function sampleGroundNeighborhoodAtPixel(px: Int, py: Int): Float
    {
      return sampleGroundNeighborhoodAtCoord((px + 0.5) / CLEAN_TILE_SIZE, (py + 0.5) / CLEAN_TILE_SIZE);
    }

// sample the cached wilderness-neighborhood field at one map-space coordinate
  function sampleGroundNeighborhoodAtCoord(x: Float, y: Float): Float
    {
      var xx = clampFloat(x, 0.0, fullCellWidth - 1.001);
      var yy = clampFloat(y, 0.0, fullCellHeight - 1.001);
      var x0 = Std.int(Math.floor(xx));
      var y0 = Std.int(Math.floor(yy));
      var x1 = clampInt(x0 + 1, 0, fullCellWidth - 1);
      var y1 = clampInt(y0 + 1, 0, fullCellHeight - 1);
      var tx = xx - x0;
      var ty = yy - y0;
      var v00 = groundNeighborhoodField[x0][y0];
      var v10 = groundNeighborhoodField[x1][y0];
      var v01 = groundNeighborhoodField[x0][y1];
      var v11 = groundNeighborhoodField[x1][y1];
      var top = v00 + (v10 - v00) * tx;
      var bottom = v01 + (v11 - v01) * tx;
      return top + (bottom - top) * ty;
    }

// paint one wilderness tile as layered canopy blobs
  function paintForestTile(cellX: Int, cellY: Int, forestStrength: Float, textureStrength: Float,
      darkWoodsStrength: Float)
    {
      var tileX = cellX * CLEAN_TILE_SIZE;
      var tileY = cellY * CLEAN_TILE_SIZE;
      var canopyColor = lerpColor(COLOR_FOREST_DARK, COLOR_FOREST_MID,
        hashFloat(cellX, cellY, 727));
      var highlightColor = lerpColor(COLOR_FOREST_LIGHT, COLOR_FOREST_WARM,
        0.45 + hashFloat(cellX, cellY, 733) * 0.30);
      if (darkWoodsStrength > 0.0)
        {
          var woodsCanopyColor = lerpColor(COLOR_WOODS_DARK, COLOR_WOODS_LIGHT,
            hashFloat(cellX, cellY, 857));
          canopyColor = lerpColor(canopyColor, woodsCanopyColor, 0.54 + darkWoodsStrength * 0.32);
          highlightColor = lerpColor(highlightColor, adjustColor(woodsCanopyColor, 1.14),
            0.18 + darkWoodsStrength * 0.22);
        }
      var canopyCount = 1;
      var highlightCount = (textureStrength >= 0.72 ? 1 : 0);

// lay down the darker canopy masses first
      for (i in 0...canopyCount)
        {
          var centerX = tileX + CLEAN_TILE_SIZE * (0.06 +
            getStableNoise(cellX, cellY, i, 743, 0x18af31) * 0.88);
          var centerY = tileY + CLEAN_TILE_SIZE * (0.06 +
            getStableNoise(cellX, cellY, i, 751, 0x27bc42) * 0.88);
          var radiusX = CLEAN_TILE_SIZE * (0.18 + forestStrength * 0.12 +
            getStableNoise(cellX, cellY, i, 757, 0x35cd53) * 0.18);
          var radiusY = radiusX * (0.52 + getStableNoise(cellX, cellY, i, 761, 0x44de64) * 0.42);
          var rotation = (getStableNoise(cellX, cellY, i, 769, 0x53ef75) - 0.5) * 1.3;

          paintForestBlob(centerX, centerY, radiusX, radiusY, rotation, canopyColor,
            textureStrength * (0.018 + forestStrength * 0.032));
        }

// add smaller lighter canopy breaks so patches do not read as flat stains
      for (i in 0...highlightCount)
        {
          var centerX = tileX + CLEAN_TILE_SIZE * (0.14 +
            getStableNoise(cellX, cellY, i, 773, 0x47de61) * 0.72);
          var centerY = tileY + CLEAN_TILE_SIZE * (0.14 +
            getStableNoise(cellX, cellY, i, 779, 0x58ef72) * 0.72);
          var radiusX = CLEAN_TILE_SIZE * (0.12 + forestStrength * 0.10 +
            getStableNoise(cellX, cellY, i, 787, 0x69ab83) * 0.10);
          var radiusY = radiusX * (0.55 + getStableNoise(cellX, cellY, i, 797, 0x71bc95) * 0.35);
          var rotation = (getStableNoise(cellX, cellY, i, 809, 0x82cd17) - 0.5) * 1.3;

          paintForestBlob(centerX, centerY, radiusX, radiusY, rotation, highlightColor,
            textureStrength * (0.014 + forestStrength * 0.022));
        }
    }

// paint one rotated forest canopy ellipse
  function paintForestBlob(centerX: Float, centerY: Float, radiusX: Float, radiusY: Float,
      rotation: Float, color: Int, alpha: Float)
    {
      ctx.save();
      ctx.globalAlpha = alpha;
      ctx.fillStyle = '#' + StringTools.hex(color, 6);
      ctx.translate(centerX, centerY);
      ctx.rotate(rotation);
      ctx.scale(radiusX, radiusY);
      ctx.beginPath();
      ctx.arc(0, 0, 1.0, 0.0, Math.PI * 2.0, false);
      ctx.fill();
      ctx.restore();
    }

// return one rgb channel from an int color
  function getColorChannel(color: Int, shift: Int): Int
    {
      return (color >> shift) & 0xFF;
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

// return whether an area type is one of the visible city bands
  function isCityAreaType(type: _AreaType): Bool
    {
      return switch (type) {
        case AREA_CITY_LOW, AREA_CITY_MEDIUM, AREA_CITY_HIGH: true;
        default: false;
      };
    }

// return a small integer density rank for seeding
  function getAreaDensityRank(type: _AreaType): Int
    {
      return switch (type) {
        case AREA_CITY_LOW: 1;
        case AREA_CITY_MEDIUM: 2;
        case AREA_CITY_HIGH, AREA_CORP: 3;
        default: 0;
      };
    }

// blur one density grid pass
  function blurDensityValues(src: Array<Array<Float>>): Array<Array<Float>>
    {
      var dst = makeFloatGrid(fullCellWidth, fullCellHeight);

      for (yy in 0...fullCellHeight)
        for (xx in 0...fullCellWidth)
          {
            var sum = 0.0;
            var weight = 0.0;
            for (dy in -1...2)
              for (dx in -1...2)
                {
                  var sx = clampInt(xx + dx, 0, fullCellWidth - 1);
                  var sy = clampInt(yy + dy, 0, fullCellHeight - 1);
                  var sampleWeight = (dx == 0 && dy == 0 ? 4 : (dx == 0 || dy == 0 ? 2 : 1));
                  sum += src[sx][sy] * sampleWeight;
                  weight += sampleWeight;
                }
            dst[xx][yy] = sum / weight;
          }

      return dst;
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
