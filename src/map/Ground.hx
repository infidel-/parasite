// density, area-type, and ground painting helpers

package map;

import _AreaType;
import map.Types.DensityField;

class Ground extends Core
{
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
            var color = getColorForDensity(samplePaintDensityAtPixel(px, py));
            if (getAreaTypeAtPixel(px, py) == AREA_GROUND)
              color = getGroundColorAtPixel(px, py, color);
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
      var imageData = ctx.getImageData(0, 0, fullPixelWidth, fullPixelHeight);
      var data = imageData.data;
      var index = 0;

// paint the main forest masses directly from the continuous noise field
      for (py in 0...fullPixelHeight)
        for (px in 0...fullPixelWidth)
          {
            var forestStrength = getForestStrengthAtPixel(px, py);
            var darkWoodsStrength = getDarkWoodsStrengthAtPixel(px, py, forestStrength);
            var darkForestPatchStrength = getDarkForestPatchStrengthAtPixel(px, py, forestStrength);
            var forestPaintStrength = forestStrength;

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

      ctx.putImageData(imageData, 0, 0);
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
            var shade = Std.int(Math.pow(strength, 0.5) * 255.0);
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
      return areaTypes[clampInt(cellX, 0, fullCellWidth - 1)][clampInt(cellY, 0, fullCellHeight - 1)] == AREA_GROUND ? 1.0 : 0.0;
    }

// return smoothed wilderness support at one map-space coordinate
  function getGroundAreaSupportAtCoord(x: Float, y: Float): Float
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
      var support = top + (bottom - top) * ty;
      return support * support * (3.0 - 2.0 * support);
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
      if (groundSupport <= 0.0)
        return 0.0;

      return getForestStrengthFromBaseAndEdge(
        getForestBaseStrength(getForestFieldAtPixel(px, py)) * groundSupport,
        getForestEdgeFactorAtPixel(px, py));
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
      var groundSupport = getGroundAreaSupportAtCoord(x, y);
      if (groundSupport <= 0.0)
        return 0.0;

      var forestBias = clampFloat((Math.max(forestStrength, getForestFieldAtCoord(x, y)) - 0.28) / 0.40, 0.0, 1.0);
      forestBias = forestBias * forestBias * (3.0 - 2.0 * forestBias);
      var support = groundSupport * (0.55 + forestBias * 0.45);
      return 0.55 + support * 0.45;
    }

// return the softened dark-forest patch response from one raw field sample
  function getDarkForestPatchThresholdStrength(field: Float): Float
    {
      var start = DARK_FOREST_PATCH_THRESHOLD - DARK_FOREST_PATCH_SOFTNESS;
      var end = DARK_FOREST_PATCH_THRESHOLD + DARK_FOREST_PATCH_SOFTNESS;
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
      return getForestEdgeFactorFromNeighborhood(groundNeighborhoodField[cellX][cellY]);
    }

// return the softened forest edge factor from one pixel
  function getForestEdgeFactorAtPixel(px: Int, py: Int): Float
    {
      return getForestEdgeFactorFromNeighborhood(sampleGroundNeighborhoodAtPixel(px, py));
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
      var groundSupport = getGroundAreaSupportAtCoord(x, y);
      if (groundSupport <= 0.0)
        return 0.0;

// bend the coarse field so grove edges meander instead of following straight contour lines
      var warpedX = x + (sampleSeededForestValueNoise(
        x / DARK_FOREST_PATCH_WARP_SCALE, y / DARK_FOREST_PATCH_WARP_SCALE, 971) - 0.5) * DARK_FOREST_PATCH_WARP;
      var warpedY = y + (sampleSeededForestValueNoise(
        (x + 41.0) / DARK_FOREST_PATCH_WARP_SCALE, (y - 23.0) / DARK_FOREST_PATCH_WARP_SCALE, 977) - 0.5) * DARK_FOREST_PATCH_WARP;

// build a few broad grove masses from seeded low-frequency fields
      var broad = sampleSeededForestValueNoise(warpedX / DARK_FOREST_PATCH_SCALE,
        warpedY / DARK_FOREST_PATCH_SCALE, 911);
      var lobe = sampleSeededForestValueNoise((warpedX + 37.0) / (DARK_FOREST_PATCH_SCALE * 0.62),
        (warpedY - 19.0) / (DARK_FOREST_PATCH_SCALE * 0.62), 919);
      var carve = sampleSeededForestValueNoise((warpedX - 53.0) / (DARK_FOREST_PATCH_SCALE * 0.88),
        (warpedY + 29.0) / (DARK_FOREST_PATCH_SCALE * 0.88), 929);
      var field = broad * (0.66 + lobe * 0.34);
      field -= clampFloat((carve - 0.64) / 0.36, 0.0, 1.0) * 0.16;

// add a little finer seeded breakup so edges do not read as one soft cloud
      var detail = sampleSeededForestValueNoise(warpedX / DARK_FOREST_PATCH_DETAIL_SCALE,
        warpedY / DARK_FOREST_PATCH_DETAIL_SCALE, 937);
      field = field * (1.0 - DARK_FOREST_PATCH_DETAIL_BLEND) + detail * DARK_FOREST_PATCH_DETAIL_BLEND;
      return clampFloat(field * (0.35 + groundSupport * 0.65), 0.0, 1.0);
    }

// return forest value noise salted with the current map seed
  function sampleSeededForestValueNoise(x: Float, y: Float, salt: Int): Float
    {
      return sampleForestValueNoise(x, y, salt + mapSeed);
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
            if (areaTypes[xx][yy] == AREA_GROUND)
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

// sample the cached wilderness-neighborhood field at one pixel
  function sampleGroundNeighborhoodAtPixel(px: Int, py: Int): Float
    {
      var x = clampFloat((px + 0.5) / CLEAN_TILE_SIZE, 0.0, fullCellWidth - 1.001);
      var y = clampFloat((py + 0.5) / CLEAN_TILE_SIZE, 0.0, fullCellHeight - 1.001);
      var x0 = Std.int(Math.floor(x));
      var y0 = Std.int(Math.floor(y));
      var x1 = clampInt(x0 + 1, 0, fullCellWidth - 1);
      var y1 = clampInt(y0 + 1, 0, fullCellHeight - 1);
      var tx = x - x0;
      var ty = y - y0;
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
