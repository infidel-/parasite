// building paint helpers

package map.buildings;

import map.Buildings;
import map.Types.BuildingFootprint;
import map.Types.ParcelRect;

@:access(map.Core)
@:access(map.Ground)
@:access(map.Raster)
@:access(map.RoadPlan)
@:access(map.LegacyRoads)
@:access(map.Buildings)
class BuildingsPainter
{
  var plan: Buildings;

  public function new(plan: Buildings)
    {
      this.plan = plan;
    }

// paint open parcels as yards or plazas
  public function paintOpenParcels(parcelList: Array<ParcelRect>)
    {
      for (parcel in parcelList)
        {
          if (!parcel.isOpen)
            continue;

          var sizingDensity = plan.getBuildingDistrictDensity(parcel.districtType);
          var inset = plan.PLAN_CELL_SIZE;
          if (sizingDensity < 0.33)
            inset = plan.PLAN_CELL_SIZE + 2;
          else if (sizingDensity > 0.66)
            inset = plan.PLAN_CELL_SIZE;

          var x = parcel.x + inset;
          var y = parcel.y + inset;
          var width = parcel.width - inset * 2;
          var height = parcel.height - inset * 2;
          if (width < plan.PLAN_CELL_SIZE ||
              height < plan.PLAN_CELL_SIZE)
            continue;

          if (sizingDensity > 0.66)
            paintPlaza(x, y, width, height, parcel);
          else
            paintYard(x, y, width, height, parcel);
        }
    }

// paint all building footprints
  public function paintBuildings()
    {
      for (building in plan.buildings)
        paintBuilding(building);
    }

// paint one building footprint with a soft edge and shadow
  function paintBuilding(building: BuildingFootprint)
    {
      var rooftopRectCount = plan.getBuildingRooftopRectCount(building);
      var baseRectCount = plan.getBuildingBaseRectCount(building);
      var rooftopColor = plan.getBuildingPaintRooftopColor(building);
      var shadowColor = plan.adjustColor(plan.COLOR_BUILDING_SHADOW,
        0.96 + building.density * 0.08);
      var highlightColor = plan.adjustColor(building.roofColor, 1.07);
      var shadeColor = plan.adjustColor(building.color, 0.76);
      var rooftopRoofColor = plan.adjustColor(building.roofColor, 1.04);
      var rooftopHighlightColor = plan.adjustColor(building.roofColor, 1.10);
      var rooftopShadeColor = plan.adjustColor(rooftopColor, 0.80);

      paintBuildingLotBackground(building);
      paintBuildingFootprintBackground(building, baseRectCount);

      if (building.forecourtAlpha > 0.0)
        paintBuildingForecourt(building);

      plan.ctx.fillStyle = '#' + StringTools.hex(building.color, 6);
      plan.ctx.globalAlpha = building.edgeAlpha;
      for (i in 0...baseRectCount)
        {
          var rect = building.rects[i];
          if (plan.isSmallBuildingRect(rect))
            continue;
          plan.ctx.fillRect(rect.x - 2, rect.y - 2, rect.width + 4, rect.height + 4);
        }
      if (rooftopRectCount > 0)
        {
          plan.ctx.fillStyle = '#' + StringTools.hex(rooftopColor, 6);
          for (i in baseRectCount...building.rects.length)
            {
              var rect = building.rects[i];
              if (plan.isSmallBuildingRect(rect))
                continue;
              plan.ctx.fillRect(rect.x - 2, rect.y - 2, rect.width + 4, rect.height + 4);
            }
        }

      plan.ctx.fillStyle = '#' + StringTools.hex(shadowColor, 6);
      plan.ctx.globalAlpha = building.shadowAlpha;
      for (i in 0...baseRectCount)
        {
          var rect = building.rects[i];
          if (plan.isSmallBuildingRect(rect))
            continue;
          plan.ctx.fillRect(rect.x + building.shadowOffset, rect.y + building.shadowOffset,
            rect.width, rect.height);
        }
      if (rooftopRectCount > 0)
        {
          for (i in baseRectCount...building.rects.length)
            {
              var rect = building.rects[i];
              if (plan.isSmallBuildingRect(rect))
                continue;
              plan.ctx.fillRect(rect.x + building.shadowOffset, rect.y + building.shadowOffset,
                rect.width, rect.height);
            }
        }

      plan.ctx.fillStyle = '#' + StringTools.hex(building.color, 6);
      plan.ctx.globalAlpha = 1.0;
      for (i in 0...baseRectCount)
        {
          var rect = building.rects[i];
          plan.ctx.fillRect(rect.x, rect.y, rect.width, rect.height);
        }
      if (rooftopRectCount > 0)
        {
          plan.ctx.fillStyle = '#' + StringTools.hex(rooftopColor, 6);
          for (i in baseRectCount...building.rects.length)
            {
              var rect = building.rects[i];
              plan.ctx.fillRect(rect.x, rect.y, rect.width, rect.height);
            }
        }

      plan.ctx.fillStyle = '#' + StringTools.hex(building.roofColor, 6);
      plan.ctx.globalAlpha = building.roofAlpha;
      for (i in 0...baseRectCount)
        {
          var rect = building.rects[i];
          if (plan.isSmallBuildingRect(rect))
            continue;
          var roofInset = plan.getBuildingRoofInset(rect, building.density);
          var roofWidth = rect.width - roofInset * 2;
          var roofHeight = rect.height - roofInset * 2;
          if (roofWidth < plan.CLEAN_TILE_SIZE / 5 ||
              roofHeight < plan.CLEAN_TILE_SIZE / 5)
            continue;

          plan.ctx.fillRect(rect.x + roofInset, rect.y + roofInset, roofWidth, roofHeight);
        }
      if (rooftopRectCount > 0)
        {
          plan.ctx.fillStyle = '#' + StringTools.hex(rooftopRoofColor, 6);
          for (i in baseRectCount...building.rects.length)
            {
              var rect = building.rects[i];
              if (plan.isSmallBuildingRect(rect))
                continue;
              var roofInset = plan.getBuildingRoofInset(rect, building.density);
              var roofWidth = rect.width - roofInset * 2;
              var roofHeight = rect.height - roofInset * 2;
              if (roofWidth < plan.CLEAN_TILE_SIZE / 5 ||
                  roofHeight < plan.CLEAN_TILE_SIZE / 5)
                continue;

              plan.ctx.fillRect(rect.x + roofInset, rect.y + roofInset, roofWidth, roofHeight);
            }
        }

      plan.ctx.fillStyle = '#' + StringTools.hex(highlightColor, 6);
      plan.ctx.globalAlpha = 0.08 + building.edgeAlpha * 0.45;
      for (i in 0...baseRectCount)
        {
          var rect = building.rects[i];
          if (plan.isSmallBuildingRect(rect))
            continue;
          var edgeWidth = plan.getBuildingEdgeWidth(rect, building.density);
          plan.ctx.fillRect(rect.x, rect.y, rect.width, edgeWidth);
          plan.ctx.fillRect(rect.x, rect.y, edgeWidth, rect.height);
        }
      if (rooftopRectCount > 0)
        {
          plan.ctx.fillStyle = '#' + StringTools.hex(rooftopHighlightColor, 6);
          for (i in baseRectCount...building.rects.length)
            {
              var rect = building.rects[i];
              if (plan.isSmallBuildingRect(rect))
                continue;
              var edgeWidth = plan.getBuildingEdgeWidth(rect, building.density);
              plan.ctx.fillRect(rect.x, rect.y, rect.width, edgeWidth);
              plan.ctx.fillRect(rect.x, rect.y, edgeWidth, rect.height);
            }
        }

      plan.ctx.fillStyle = '#' + StringTools.hex(shadeColor, 6);
      plan.ctx.globalAlpha = 0.11 + building.edgeAlpha * 0.55;
      for (i in 0...baseRectCount)
        {
          var rect = building.rects[i];
          if (plan.isSmallBuildingRect(rect))
            continue;
          var edgeWidth = plan.getBuildingEdgeWidth(rect, building.density);
          plan.ctx.fillRect(rect.x, rect.y + rect.height - edgeWidth, rect.width, edgeWidth);
          plan.ctx.fillRect(rect.x + rect.width - edgeWidth, rect.y, edgeWidth, rect.height);
        }
      if (rooftopRectCount > 0)
        {
          plan.ctx.fillStyle = '#' + StringTools.hex(rooftopShadeColor, 6);
          for (i in baseRectCount...building.rects.length)
            {
              var rect = building.rects[i];
              if (plan.isSmallBuildingRect(rect))
                continue;
              var edgeWidth = plan.getBuildingEdgeWidth(rect, building.density);
              plan.ctx.fillRect(rect.x, rect.y + rect.height - edgeWidth, rect.width, edgeWidth);
              plan.ctx.fillRect(rect.x + rect.width - edgeWidth, rect.y, edgeWidth,
                rect.height);
            }
        }

      plan.ctx.globalAlpha = 1.0;
    }

// paint one broader lot background under a building footprint
  function paintBuildingLotBackground(building: BuildingFootprint)
    {
      plan.ctx.globalAlpha = plan.BUILDING_LOT_BACKGROUND_ALPHA;
      plan.ctx.fillStyle = '#' + StringTools.hex(building.forecourtColor, 6);
      plan.ctx.fillRect(building.lotX, building.lotY, building.lotWidth, building.lotHeight);
    }

// paint one opaque background tightly around the base footprint
  function paintBuildingFootprintBackground(building: BuildingFootprint, baseRectCount: Int)
    {
      plan.ctx.globalAlpha = plan.BUILDING_FOOTPRINT_BACKGROUND_ALPHA;
      plan.ctx.fillStyle = '#' + StringTools.hex(building.forecourtColor, 6);
      for (i in 0...baseRectCount)
        {
          var rect = building.rects[i];
          var padding = plan.getBuildingEdgeWidth(rect, building.density) + 2;
          plan.ctx.fillRect(rect.x - padding, rect.y - padding,
            rect.width + padding * 2, rect.height + padding * 2);
        }
    }

// paint a paved forecourt around a centered tower footprint
  function paintBuildingForecourt(building: BuildingFootprint)
    {
      var inset = 3;
      var x = building.lotX + inset;
      var y = building.lotY + inset;
      var width = building.lotWidth - inset * 2;
      var height = building.lotHeight - inset * 2;
      if (width < plan.CLEAN_TILE_SIZE / 2 ||
          height < plan.CLEAN_TILE_SIZE / 2)
        return;

      plan.ctx.globalAlpha = building.forecourtAlpha;
      plan.ctx.fillStyle = '#' + StringTools.hex(building.forecourtColor, 6);
      plan.ctx.fillRect(x, y, width, height);

      plan.ctx.globalAlpha = building.forecourtAlpha * 0.48;
      plan.ctx.fillStyle = '#' + StringTools.hex(
        plan.adjustColor(building.forecourtColor, 1.08), 6);
      plan.ctx.fillRect(x + Std.int(width / 2) - 2, y + 4, 4, height - 8);
      plan.ctx.fillRect(x + 4, y + Std.int(height / 2) - 2, width - 8, 4);
      plan.ctx.globalAlpha = 1.0;
    }

// paint one high-density open parcel as a plaza
  function paintPlaza(x: Int, y: Int, width: Int, height: Int, parcel: ParcelRect)
    {
      plan.ctx.globalAlpha = 0.46;
      plan.ctx.fillStyle = '#' + StringTools.hex(plan.adjustColor(plan.COLOR_PLAZA,
        0.92 + plan.hashFloat(parcel.x, parcel.y, 211) * 0.14), 6);
      plan.ctx.fillRect(x, y, width, height);

      plan.ctx.globalAlpha = 0.28;
      plan.ctx.fillStyle = '#' + StringTools.hex(plan.COLOR_PLAZA_EDGE, 6);
      plan.ctx.fillRect(x + Std.int(width / 2) - 2, y + 4, 4, height - 8);
      plan.ctx.fillRect(x + 4, y + Std.int(height / 2) - 2, width - 8, 4);
      if (width > plan.CLEAN_TILE_SIZE * 2 &&
          height > plan.CLEAN_TILE_SIZE * 2)
        {
          plan.ctx.globalAlpha = 0.12;
          plan.ctx.fillRect(x + Std.int(width / 4) - 1, y + 6, 2, height - 12);
          plan.ctx.fillRect(x + Std.int(width * 3 / 4) - 1, y + 6, 2, height - 12);
          plan.ctx.fillRect(x + 6, y + Std.int(height / 4) - 1, width - 12, 2);
          plan.ctx.fillRect(x + 6, y + Std.int(height * 3 / 4) - 1, width - 12, 2);
        }
      plan.ctx.globalAlpha = 1.0;
    }

// paint one lower-density open parcel as a yard
  function paintYard(x: Int, y: Int, width: Int, height: Int, parcel: ParcelRect)
    {
      plan.ctx.globalAlpha = 0.24;
      plan.ctx.fillStyle = '#' + StringTools.hex(plan.adjustColor(plan.COLOR_YARD,
        0.92 + plan.hashFloat(parcel.x, parcel.y, 223) * 0.18), 6);
      plan.ctx.fillRect(x, y, width, height);
      plan.ctx.globalAlpha = 0.10;
      plan.ctx.fillStyle = '#' + StringTools.hex(plan.adjustColor(plan.COLOR_YARD, 1.10), 6);
      plan.ctx.fillRect(x + 4, y + 4, width - 8, height - 8);
      plan.ctx.globalAlpha = 1.0;
    }

}
