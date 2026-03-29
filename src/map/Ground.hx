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

      for (i in 0...4)
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
            var color = getColorForDensity(sampleDensityAtPixel(px, py));
            data[index++] = (color >> 16) & 0xFF;
            data[index++] = (color >> 8) & 0xFF;
            data[index++] = color & 0xFF;
            data[index++] = 0xFF;
          }

      ctx.putImageData(imageData, 0, 0);
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
