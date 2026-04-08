// building parcel subdivision helpers

package map.buildings;

import map.Buildings;
import map.Types.BlockRect;
import map.Types.ParcelRect;

@:access(map.Core)
@:access(map.Ground)
@:access(map.Raster)
@:access(map.RoadPlan)
@:access(map.Buildings)
class BuildingsParcelBuilder
{
  var plan: Buildings;

  public function new(plan: Buildings)
    {
      this.plan = plan;
    }

// subdivide blocks into orthogonal parcels
  public function buildParcels(blockList: Array<BlockRect>): Array<ParcelRect>
    {
      var result = [];

      for (block in blockList)
        {
          var setback = plan.getBlockSetback(plan.getBuildingDistrictDensity(block.districtType));
          var innerX = block.x + setback;
          var innerY = block.y + setback;
          var innerWidth = block.width - setback * 2;
          var innerHeight = block.height - setback * 2;
          if (innerWidth < plan.PLAN_CELL_SIZE ||
              innerHeight < plan.PLAN_CELL_SIZE)
            continue;

          subdivideParcel(makeParcelRect(innerX, innerY, innerWidth, innerHeight), result, 0);
        }

      return result;
    }

// recursively split a parcel candidate into parcel rectangles
  function subdivideParcel(parcel: ParcelRect, out: Array<ParcelRect>, depth: Int)
    {
      var sizingDensity = plan.getBuildingDistrictDensity(parcel.districtType);
      var targetWidth = plan.getTargetParcelWidth(sizingDensity);
      var targetHeight = plan.getTargetParcelHeight(sizingDensity);
      var splitThreshold = plan.getParcelSplitThreshold(sizingDensity);
      var canSplitX = parcel.width > targetWidth * splitThreshold;
      var canSplitY = parcel.height > targetHeight * splitThreshold;
      var maxDepth = plan.getParcelMaxDepth(sizingDensity);

      if (depth >= maxDepth ||
          (!canSplitX && !canSplitY))
        {
          out.push(finalizeParcel(parcel));
          return;
        }

      var splitVertical = parcel.width >= parcel.height;
      if (splitVertical && !canSplitX)
        splitVertical = false;
      else if (!splitVertical && !canSplitY)
        splitVertical = true;

      if (splitVertical)
        {
          var minSplit = Std.int(parcel.width * plan.getParcelSplitMinRatio(sizingDensity));
          var maxSplit = Std.int(parcel.width * plan.getParcelSplitMaxRatio(sizingDensity));
          if (maxSplit - minSplit < plan.PLAN_CELL_SIZE)
            {
              out.push(finalizeParcel(parcel));
              return;
            }

          var split = parcel.x + plan.randomRangeInt(minSplit, maxSplit);
          subdivideParcel(makeParcelRect(
            parcel.x,
            parcel.y,
            split - parcel.x,
            parcel.height), out, depth + 1);
          subdivideParcel(makeParcelRect(
            split,
            parcel.y,
            parcel.x + parcel.width - split,
            parcel.height), out, depth + 1);
          return;
        }

      var minSplit = Std.int(parcel.height * plan.getParcelSplitMinRatio(sizingDensity));
      var maxSplit = Std.int(parcel.height * plan.getParcelSplitMaxRatio(sizingDensity));
      if (maxSplit - minSplit < plan.PLAN_CELL_SIZE)
        {
          out.push(finalizeParcel(parcel));
          return;
        }

      var split = parcel.y + plan.randomRangeInt(minSplit, maxSplit);
      subdivideParcel(makeParcelRect(
        parcel.x,
        parcel.y,
        parcel.width,
        split - parcel.y), out, depth + 1);
      subdivideParcel(makeParcelRect(
        parcel.x,
        split,
        parcel.width,
        parcel.y + parcel.height - split), out, depth + 1);
    }

// create one parcel rect with local sampled density
  function makeParcelRect(x: Int, y: Int, width: Int, height: Int): ParcelRect
    {
      return {
        x: x,
        y: y,
        width: width,
        height: height,
        density: plan.sampleAverageDensity(x, y, width, height),
        districtType: plan.getBuildingDistrictTypeForRect(x, y, width, height),
        isOpen: false,
      };
    }

// finalize a parcel with plaza/open-space chance
  function finalizeParcel(parcel: ParcelRect): ParcelRect
    {
      var sizingDensity = plan.getBuildingDistrictDensity(parcel.districtType);
      var openChance = 0.0;
      if (sizingDensity < 0.33)
        openChance = 0.006;
      else if (sizingDensity < 0.66)
        openChance = 0.003;
      else openChance = 0.010;

      var centrality = plan.getParcelCentrality(parcel);
      var area = parcel.width * parcel.height;
      if (sizingDensity > 0.66 &&
          parcel.width > plan.CLEAN_TILE_SIZE * 2 &&
          parcel.height > plan.CLEAN_TILE_SIZE * 2)
        {
          openChance += 0.006 + centrality * 0.018;
          if (area >= plan.CLEAN_TILE_SIZE * plan.CLEAN_TILE_SIZE * 10)
            openChance += 0.010;
        }

      if (plan.isSkinnyParcel(parcel))
        openChance += (sizingDensity > 0.66 ? 0.03 : 0.06);
      if (parcel.width < plan.PLAN_CELL_SIZE * 2 ||
          parcel.height < plan.PLAN_CELL_SIZE * 2)
        openChance += 0.04;
      if (sizingDensity < 0.33 &&
          parcel.width > plan.CLEAN_TILE_SIZE * 3 &&
          parcel.height > plan.CLEAN_TILE_SIZE * 3)
        openChance += 0.01;
      if (sizingDensity < 0.33 &&
          centrality < 0.34 &&
          area >= plan.CLEAN_TILE_SIZE * plan.CLEAN_TILE_SIZE * 4)
        openChance += 0.01;

      openChance = plan.clampFloat(openChance, 0.0, 0.92);

      parcel.isOpen = plan.rng.nextFloat() < openChance;
      return parcel;
    }

}
