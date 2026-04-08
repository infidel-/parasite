// building footprint generation helpers

package map.buildings;

import map.Buildings;
import map.Types.BuildingFootprint;
import map.Types.BuildingRect;
import map.Types.BuildingShapeType;
import map.Types.BuildingStyle;
import map.Types.ParcelRect;

@:access(map.Core)
@:access(map.Ground)
@:access(map.Raster)
@:access(map.RoadPlan)
@:access(map.Buildings)
class BuildingsFootprintGenerator
{
  var plan: Buildings;

  public function new(plan: Buildings)
    {
      this.plan = plan;
    }

// generate building footprints from parcels
  public function generateBuildings(parcelList: Array<ParcelRect>): Array<BuildingFootprint>
    {
      var result = [];

      for (parcel in parcelList)
        {
          if (parcel.isOpen)
            continue;

          var building = generateBuildingForParcel(parcel);
          if (building != null)
            result.push(building);
        }

      return result;
    }

// generate one building footprint for a parcel
  function generateBuildingForParcel(parcel: ParcelRect): BuildingFootprint
    {
      var sizingDensity = plan.getBuildingDistrictDensity(parcel.districtType);
      var style = plan.getBuildingStyle(parcel);
      if (plan.rng.nextFloat() > style.buildChance)
        return null;

      var margin = style.margin;
      var innerX = parcel.x + margin;
      var innerY = parcel.y + margin;
      var innerWidth = parcel.width - margin * 2;
      var innerHeight = parcel.height - margin * 2;
      if (innerWidth < plan.PLAN_CELL_SIZE ||
          innerHeight < plan.PLAN_CELL_SIZE)
        return null;

      var shape = pickBuildingShape();
      var footprint = generateBuildingFootprintForShape(shape, innerX, innerY,
        innerWidth, innerHeight, sizingDensity, style);
      if (!plan.footprintHasMinimumRectSize(footprint))
        footprint = null;
      if (footprint == null &&
          (shape == H_SHAPE ||
          shape == T_SHAPE))
        {
          footprint = generateBuildingFootprintForShape(L_SHAPE, innerX, innerY,
            innerWidth, innerHeight, sizingDensity, style);
          if (!plan.footprintHasMinimumRectSize(footprint))
            footprint = null;
        }
      if (footprint == null &&
          shape != RECT)
        {
          footprint = generateBuildingFootprintForShape(RECT, innerX, innerY,
            innerWidth, innerHeight, sizingDensity, style);
          if (!plan.footprintHasMinimumRectSize(footprint))
            footprint = null;
        }
      addRectBuildingRooftopStructure(footprint, sizingDensity);
      if (footprint == null ||
          !plan.footprintHasMinimumRectSize(footprint) ||
          plan.footprintTouchesRoad(footprint))
        return null;

      var bounds = plan.getFootprintBounds(footprint);
      var forecourtAlpha = style.forecourtAlpha;
      if (forecourtAlpha > 0.0 &&
          !plan.hasVisibleForecourt(bounds, innerX, innerY, innerWidth, innerHeight))
        forecourtAlpha = 0.0;

      var color = plan.pickBuildingColor(parcel.density, parcel.districtType,
        innerX, innerY, innerWidth, innerHeight);
      var rooftopRectCount = plan.getRooftopRectCount(footprint);

      return {
        rects: footprint,
        rooftopRectCount: rooftopRectCount,
        color: color,
        rooftopColor: plan.getBuildingRooftopColor(color, parcel.density),
        density: parcel.density,
        lotX: innerX,
        lotY: innerY,
        lotWidth: innerWidth,
        lotHeight: innerHeight,
        forecourtColor: plan.pickBuildingForecourtColor(parcel.density),
        forecourtAlpha: forecourtAlpha,
        roofColor: plan.pickBuildingRoofColor(color, parcel.density, parcel.districtType,
          innerX, innerY, innerWidth, innerHeight),
        roofAlpha: plan.pickBuildingRoofAlpha(parcel.density),
        edgeAlpha: plan.pickBuildingEdgeAlpha(parcel.density),
        shadowOffset: plan.getBuildingShadowOffset(parcel.density),
        shadowAlpha: style.shadowAlpha,
      };
    }

// pick one building footprint archetype
  function pickBuildingShape(): BuildingShapeType
    {
      var roll = plan.rng.nextFloat();
      if (roll < 0.50)
        return RECT;
      if (roll < 0.70)
        return L_SHAPE;
      if (roll < 0.85)
        return H_SHAPE;
      return T_SHAPE;
    }

// generate one footprint from the requested shape archetype
  function generateBuildingFootprintForShape(shape: BuildingShapeType,
      x: Int, y: Int, width: Int, height: Int, density: Float,
      style: BuildingStyle): Array<BuildingRect>
    {
      return switch (shape) {
        case RECT: generateRectBuildingFootprint(x, y, width, height, style);
        case L_SHAPE: generateLBuildingFootprint(x, y, width, height, density, style.centered);
        case H_SHAPE: generateHBuildingFootprint(x, y, width, height, density, style.centered);
        case T_SHAPE: generateTBuildingFootprint(x, y, width, height, density, style.centered);
      };
    }

// generate one rectangular footprint
  function generateRectBuildingFootprint(x: Int, y: Int,
      width: Int, height: Int, style: BuildingStyle): Array<BuildingRect>
    {
      return [ generatePlacedBuildingRect(x, y, width, height,
        style.minRatio, style.maxRatio, style.centered) ];
    }

// generate one L-shaped footprint
  function generateLBuildingFootprint(x: Int, y: Int,
      width: Int, height: Int, density: Float, centered: Bool): Array<BuildingRect>
    {
      var outer = generatePlacedBuildingRect(x, y, width, height,
        plan.getLShapeMinRatio(density), plan.getLShapeMaxRatio(density), centered);
      var cutoutSize = plan.getLShapeCutoutSize(density);
      var verticalWidth = plan.clampInt(Std.int(outer.width * plan.randomRangeFloat(
        plan.getLShapeBarMinRatio(density), plan.getLShapeBarMaxRatio(density))),
        plan.getMinBuildingPixelSize(), outer.width - cutoutSize);
      var horizontalHeight = plan.clampInt(Std.int(outer.height * plan.randomRangeFloat(
        plan.getLShapeBarMinRatio(density), plan.getLShapeBarMaxRatio(density))),
        plan.getMinBuildingPixelSize(), outer.height - cutoutSize);

      if (outer.width - verticalWidth < cutoutSize ||
          outer.height - horizontalHeight < cutoutSize)
        return null;

      var side = plan.rng.next() % 4;
      return switch (side) {
        case 0: [
          { x: outer.x, y: outer.y, width: verticalWidth, height: outer.height },
          { x: outer.x + verticalWidth, y: outer.y,
            width: outer.width - verticalWidth, height: horizontalHeight },
        ];
        case 1: [
          { x: outer.x, y: outer.y, width: verticalWidth, height: outer.height },
          { x: outer.x + verticalWidth, y: outer.y + outer.height - horizontalHeight,
            width: outer.width - verticalWidth, height: horizontalHeight },
        ];
        case 2: [
          { x: outer.x + outer.width - verticalWidth, y: outer.y,
            width: verticalWidth, height: outer.height },
          { x: outer.x, y: outer.y,
            width: outer.width - verticalWidth, height: horizontalHeight },
        ];
        default: [
          { x: outer.x + outer.width - verticalWidth, y: outer.y,
            width: verticalWidth, height: outer.height },
          { x: outer.x, y: outer.y + outer.height - horizontalHeight,
            width: outer.width - verticalWidth, height: horizontalHeight },
        ];
      };
    }

// generate one H-shaped footprint
  function generateHBuildingFootprint(x: Int, y: Int,
      width: Int, height: Int, density: Float, centered: Bool): Array<BuildingRect>
    {
      var outer = generatePlacedBuildingRect(x, y, width, height,
        plan.getHShapeMinRatio(density), plan.getHShapeMaxRatio(density), centered);
      var gapSize = plan.getHShapeGapSize(density);
      var verticalLayout = outer.width >= outer.height;
      if (Math.abs(outer.width - outer.height) < plan.PLAN_CELL_SIZE)
        verticalLayout = plan.rng.nextFloat() < 0.5;

      if (verticalLayout)
        return generateVerticalHFootprint(outer, density, centered, gapSize);
      return generateHorizontalHFootprint(outer, density, centered, gapSize);
    }

// generate one T-shaped footprint
  function generateTBuildingFootprint(x: Int, y: Int,
      width: Int, height: Int, density: Float, centered: Bool): Array<BuildingRect>
    {
      var outer = generatePlacedBuildingRect(x, y, width, height,
        plan.getHShapeMinRatio(density), plan.getHShapeMaxRatio(density), centered);
      var verticalLayout = outer.height >= outer.width;
      if (Math.abs(outer.width - outer.height) < plan.PLAN_CELL_SIZE)
        verticalLayout = plan.rng.nextFloat() < 0.5;

      if (verticalLayout)
        return generateVerticalTFootprint(outer, density, centered);
      return generateHorizontalTFootprint(outer, density, centered);
    }

// generate one placed building rect inside a parcel
  function generatePlacedBuildingRect(x: Int, y: Int,
      width: Int, height: Int, minRatio: Float, maxRatio: Float,
      centered: Bool): BuildingRect
    {
      var bw = Std.int(width * plan.randomRangeFloat(minRatio, maxRatio));
      var bh = Std.int(height * plan.randomRangeFloat(minRatio, maxRatio));
      bw = plan.clampInt(bw, plan.getMinBuildingPixelSize(), width);
      bh = plan.clampInt(bh, plan.getMinBuildingPixelSize(), height);

      var bx = x;
      var by = y;
      if (width > bw)
        {
          if (centered)
            bx += plan.pickCenteredPlacement(width - bw);
          else
            bx += plan.randomRangeInt(0, width - bw);
        }
      if (height > bh)
        {
          if (centered)
            by += plan.pickCenteredPlacement(height - bh);
          else
            by += plan.randomRangeInt(0, height - bh);
        }

      return {
        x: bx,
        y: by,
        width: bw,
        height: bh,
      };
    }

// add one smaller rooftop structure on top of one large rectangular building
  function addRectBuildingRooftopStructure(footprint: Array<BuildingRect>, density: Float)
    {
      if (footprint == null ||
          footprint.length != 1)
        return;

      var baseRect = footprint[0];
      if (baseRect.width <= 40 ||
          baseRect.height <= 40)
        return;

      var hostRect = getRooftopStructureHostRect(baseRect);
      var minRatio = 0.36;
      var maxRatio = 0.54;
      if (density >= 0.66)
        {
          minRatio = 0.44;
          maxRatio = 0.62;
        }
      else if (density >= 0.33)
        {
          minRatio = 0.40;
          maxRatio = 0.58;
        }

      var rooftopRect = generatePlacedBuildingRect(hostRect.x, hostRect.y,
        hostRect.width, hostRect.height, minRatio, maxRatio, true);
      if (rooftopRect.width >= baseRect.width ||
          rooftopRect.height >= baseRect.height)
        return;

      footprint.push(rooftopRect);
    }

// return the host rect used for one rooftop structure
  function getRooftopStructureHostRect(baseRect: BuildingRect): BuildingRect
    {
      var useSplitPlacement = baseRect.width < 100 &&
        baseRect.height < 100 &&
        plan.rng.nextFloat() < 0.5;
      if (!useSplitPlacement)
        return baseRect;

      var splitVertical = baseRect.width > baseRect.height;
      if (baseRect.width == baseRect.height)
        splitVertical = plan.rng.nextFloat() < 0.5;

      if (splitVertical)
        {
          var leftWidth = Std.int(baseRect.width / 2);
          var useRightHalf = plan.rng.nextFloat() < 0.5;
          if (useRightHalf)
            {
              return {
                x: baseRect.x + leftWidth,
                y: baseRect.y,
                width: baseRect.width - leftWidth,
                height: baseRect.height,
              };
            }

          return {
            x: baseRect.x,
            y: baseRect.y,
            width: leftWidth,
            height: baseRect.height,
          };
        }

      var topHeight = Std.int(baseRect.height / 2);
      var useBottomHalf = plan.rng.nextFloat() < 0.5;
      if (useBottomHalf)
        {
          return {
            x: baseRect.x,
            y: baseRect.y + topHeight,
            width: baseRect.width,
            height: baseRect.height - topHeight,
          };
        }

      return {
        x: baseRect.x,
        y: baseRect.y,
        width: baseRect.width,
        height: topHeight,
      };
    }

// generate one vertical H footprint
  function generateVerticalHFootprint(outer: BuildingRect, density: Float,
      centered: Bool, gapSize: Int): Array<BuildingRect>
    {
      var maxBarWidth = Std.int((outer.width - gapSize) / 2);
      var maxCrossHeight = outer.height - gapSize * 2;
      if (maxBarWidth < plan.getMinBuildingPixelSize() ||
          maxCrossHeight < plan.getMinBuildingPixelSize())
        return null;

      var barWidth = plan.clampInt(Std.int(outer.width * plan.randomRangeFloat(
        plan.getHShapeBarMinRatio(density), plan.getHShapeBarMaxRatio(density))),
        plan.getMinBuildingPixelSize(), maxBarWidth);
      if (outer.width - barWidth * 2 < gapSize)
        return null;

      var crossHeight = plan.clampInt(Std.int(outer.height * plan.randomRangeFloat(
        plan.getHShapeBarMinRatio(density), plan.getHShapeBarMaxRatio(density))),
        plan.getMinBuildingPixelSize(), maxCrossHeight);
      var crossY = outer.y + gapSize;
      var crossSpan = outer.height - crossHeight - gapSize * 2;
      if (crossSpan > 0)
        {
          if (centered)
            crossY += plan.pickCenteredPlacement(crossSpan);
          else
            crossY += plan.randomRangeInt(0, crossSpan);
        }

      return [
        { x: outer.x, y: outer.y, width: barWidth, height: outer.height },
        { x: outer.x + outer.width - barWidth, y: outer.y,
          width: barWidth, height: outer.height },
        { x: outer.x + barWidth, y: crossY,
          width: outer.width - barWidth * 2, height: crossHeight },
      ];
    }

// generate one horizontal H footprint
  function generateHorizontalHFootprint(outer: BuildingRect, density: Float,
      centered: Bool, gapSize: Int): Array<BuildingRect>
    {
      var maxBarHeight = Std.int((outer.height - gapSize) / 2);
      var maxCrossWidth = outer.width - gapSize * 2;
      if (maxBarHeight < plan.getMinBuildingPixelSize() ||
          maxCrossWidth < plan.getMinBuildingPixelSize())
        return null;

      var barHeight = plan.clampInt(Std.int(outer.height * plan.randomRangeFloat(
        plan.getHShapeBarMinRatio(density), plan.getHShapeBarMaxRatio(density))),
        plan.getMinBuildingPixelSize(), maxBarHeight);
      if (outer.height - barHeight * 2 < gapSize)
        return null;

      var crossWidth = plan.clampInt(Std.int(outer.width * plan.randomRangeFloat(
        plan.getHShapeBarMinRatio(density), plan.getHShapeBarMaxRatio(density))),
        plan.getMinBuildingPixelSize(), maxCrossWidth);
      var crossX = outer.x + gapSize;
      var crossSpan = outer.width - crossWidth - gapSize * 2;
      if (crossSpan > 0)
        {
          if (centered)
            crossX += plan.pickCenteredPlacement(crossSpan);
          else
            crossX += plan.randomRangeInt(0, crossSpan);
        }

      return [
        { x: outer.x, y: outer.y, width: outer.width, height: barHeight },
        { x: outer.x, y: outer.y + outer.height - barHeight,
          width: outer.width, height: barHeight },
        { x: crossX, y: outer.y + barHeight,
          width: crossWidth, height: outer.height - barHeight * 2 },
      ];
    }

// generate one vertical T footprint
  function generateVerticalTFootprint(outer: BuildingRect, density: Float,
      centered: Bool): Array<BuildingRect>
    {
      var capHeight = plan.clampInt(Std.int(outer.height * plan.randomRangeFloat(
        plan.getHShapeBarMinRatio(density), plan.getHShapeBarMaxRatio(density))),
        plan.getMinBuildingPixelSize(), outer.height);
      var stemWidth = plan.clampInt(Std.int(outer.width * plan.randomRangeFloat(
        plan.getHShapeBarMinRatio(density), plan.getHShapeBarMaxRatio(density))),
        plan.getMinBuildingPixelSize(), outer.width);
      if (outer.height - capHeight < plan.getMinBuildingPixelSize())
        return null;

      var stemX = outer.x;
      var stemSpan = outer.width - stemWidth;
      if (stemSpan > 0)
        {
          if (centered)
            stemX += plan.pickCenteredPlacement(stemSpan);
          else
            stemX += plan.randomRangeInt(0, stemSpan);
        }

      if (plan.rng.nextFloat() < 0.5)
        return [
          { x: outer.x, y: outer.y, width: outer.width, height: capHeight },
          { x: stemX, y: outer.y + capHeight,
            width: stemWidth, height: outer.height - capHeight },
        ];

      return [
        { x: outer.x, y: outer.y + outer.height - capHeight,
          width: outer.width, height: capHeight },
        { x: stemX, y: outer.y,
          width: stemWidth, height: outer.height - capHeight },
      ];
    }

// generate one horizontal T footprint
  function generateHorizontalTFootprint(outer: BuildingRect, density: Float,
      centered: Bool): Array<BuildingRect>
    {
      var capWidth = plan.clampInt(Std.int(outer.width * plan.randomRangeFloat(
        plan.getHShapeBarMinRatio(density), plan.getHShapeBarMaxRatio(density))),
        plan.getMinBuildingPixelSize(), outer.width);
      var stemHeight = plan.clampInt(Std.int(outer.height * plan.randomRangeFloat(
        plan.getHShapeBarMinRatio(density), plan.getHShapeBarMaxRatio(density))),
        plan.getMinBuildingPixelSize(), outer.height);
      if (outer.width - capWidth < plan.getMinBuildingPixelSize())
        return null;

      var stemY = outer.y;
      var stemSpan = outer.height - stemHeight;
      if (stemSpan > 0)
        {
          if (centered)
            stemY += plan.pickCenteredPlacement(stemSpan);
          else
            stemY += plan.randomRangeInt(0, stemSpan);
        }

      if (plan.rng.nextFloat() < 0.5)
        return [
          { x: outer.x, y: outer.y, width: capWidth, height: outer.height },
          { x: outer.x + capWidth, y: stemY,
            width: outer.width - capWidth, height: stemHeight },
        ];

      return [
        { x: outer.x + outer.width - capWidth, y: outer.y,
          width: capWidth, height: outer.height },
        { x: outer.x, y: stemY,
          width: outer.width - capWidth, height: stemHeight },
      ];
    }

}
