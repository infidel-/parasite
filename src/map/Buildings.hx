// block, parcel, and building helpers kept with the map renderer

package map;

import const.WorldConst;
import map.Types.BlockComponent;
import map.Types.BlockRect;
import map.Types.BuildingFootprint;
import map.Types.BuildingRect;
import map.Types.BuildingShapeType;
import map.Types.BuildingStyle;
import map.Types.GridPoint;
import map.Types.IntRect;
import map.Types.ParcelRect;
import map.Types.RoadMasks;

class Buildings extends LegacyRoads
{
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
      return buildBlocksFromMasks(roadMasks);
    }

// derive rectangular blocks from the road occupancy mask
  function buildBlocksFromMasks(masks: RoadMasks): Array<BlockRect>
    {
      var result = [];
      var blocked = makeBoolGrid(planWidth, planHeight);

      for (yy in 0...planHeight)
        for (xx in 0...planWidth)
          {
            var px = xx * PLAN_CELL_SIZE + Std.int(PLAN_CELL_SIZE / 2);
            var py = yy * PLAN_CELL_SIZE + Std.int(PLAN_CELL_SIZE / 2);
            var areaType = areaTypes[
              clampInt(Std.int(xx / PLAN_CELLS_PER_TILE), 0, fullCellWidth - 1)
            ][
              clampInt(Std.int(yy / PLAN_CELLS_PER_TILE), 0, fullCellHeight - 1)
            ];
            blocked[xx][yy] =
              masks.occupancy[xx][yy] > 0.0 ||
              !isBuildableAreaType(areaType) ||
              !isBuildableGroundCell(xx, yy, px, py);
          }

      var components = collectBuildableComponents(blocked);
      for (component in components)
        extractBlocksFromComponent(component, result);

      return result;
    }

// collect connected buildable components from the mask
  function collectBuildableComponents(blocked: Array<Array<Bool>>): Array<BlockComponent>
    {
      var components = [];
      var visited = makeBoolGrid(planWidth, planHeight);

      for (yy in 0...planHeight)
        for (xx in 0...planWidth)
          {
            if (blocked[xx][yy] || visited[xx][yy])
              continue;

            var queue = [ { x: xx, y: yy } ];
            var cells = [];
            var minX = xx;
            var minY = yy;
            var maxX = xx;
            var maxY = yy;
            visited[xx][yy] = true;

            while (queue.length > 0)
              {
                var pt = queue.pop();
                cells.push(pt);
                if (pt.x < minX) minX = pt.x;
                if (pt.y < minY) minY = pt.y;
                if (pt.x > maxX) maxX = pt.x;
                if (pt.y > maxY) maxY = pt.y;

                for (dir in 0...4)
                  {
                    var nx = pt.x;
                    var ny = pt.y;
                    switch (dir)
                      {
                        case 0: nx--;
                        case 1: nx++;
                        case 2: ny--;
                        case 3: ny++;
                      }

                    if (nx < 0 || ny < 0 || nx >= planWidth || ny >= planHeight)
                      continue;
                    if (blocked[nx][ny] || visited[nx][ny])
                      continue;
                    visited[nx][ny] = true;
                    queue.push({ x: nx, y: ny });
                  }
              }

            components.push({
              cells: cells,
              minX: minX,
              minY: minY,
              maxX: maxX,
              maxY: maxY,
            });
          }

      return components;
    }

// return whether buildings may appear in this area type
  function isBuildableAreaType(areaType: _AreaType): Bool
    {
      var info = WorldConst.getAreaInfo(areaType);
      return info != null &&
        info.isInhabited;
    }

// extract rectangular blocks from one connected component
  function extractBlocksFromComponent(component: BlockComponent, out: Array<BlockRect>)
    {
      var localWidth = component.maxX - component.minX + 1;
      var localHeight = component.maxY - component.minY + 1;
      var available = makeBoolGrid(localWidth, localHeight);

      for (cell in component.cells)
        {
          var lx = cell.x - component.minX;
          var ly = cell.y - component.minY;
          available[lx][ly] = true;
        }

      while (true)
        {
          var start = findFirstAvailableCell(available, localWidth, localHeight);
          if (start == null)
            break;

          var rect = extractLocalBlockRect(start.x, start.y, available,
            localWidth, localHeight);
          if (rect == null)
            {
              available[start.x][start.y] = false;
              continue;
            }

          for (yy in rect.y...rect.y + rect.height)
            for (xx in rect.x...rect.x + rect.width)
              available[xx][yy] = false;

          var pixelX = (component.minX + rect.x) * PLAN_CELL_SIZE;
          var pixelY = (component.minY + rect.y) * PLAN_CELL_SIZE;
          var pixelWidth = rect.width * PLAN_CELL_SIZE;
          var pixelHeight = rect.height * PLAN_CELL_SIZE;
          if (pixelWidth < PLAN_CELL_SIZE ||
              pixelHeight < PLAN_CELL_SIZE)
            continue;

          var density = sampleAverageDensity(pixelX, pixelY, pixelWidth, pixelHeight);
          if (density < 0.02)
            continue;

          out.push({
            x: pixelX,
            y: pixelY,
            width: pixelWidth,
            height: pixelHeight,
            density: density,
          });
        }
    }

// find the first available local grid cell
  function findFirstAvailableCell(available: Array<Array<Bool>>,
      width: Int, height: Int): GridPoint
    {
      for (yy in 0...height)
        for (xx in 0...width)
          if (available[xx][yy])
            return { x: xx, y: yy };
      return null;
    }

// extract the best rectangle from a local availability mask
  function extractLocalBlockRect(startX: Int, startY: Int,
      available: Array<Array<Bool>>, width: Int, height: Int): IntRect
    {
      var bestWidth = 0;
      var bestHeight = 0;
      var bestArea = 0;
      var currentWidth = 0;

      while (startX + currentWidth < width &&
          available[startX + currentWidth][startY])
        currentWidth++;

      if (currentWidth == 0)
        return null;

      var yy = startY;
      while (yy < height && currentWidth > 0)
        {
          var rowWidth = 0;
          while (startX + rowWidth < width &&
              available[startX + rowWidth][yy])
            rowWidth++;

          currentWidth = Std.int(Math.min(currentWidth, rowWidth));
          if (currentWidth == 0)
            break;

          var rectHeight = yy - startY + 1;
          var area = currentWidth * rectHeight;
          if (area > bestArea)
            {
              bestArea = area;
              bestWidth = currentWidth;
              bestHeight = rectHeight;
            }
          yy++;
        }

      return {
        x: startX,
        y: startY,
        width: bestWidth,
        height: bestHeight,
      };
    }

// subdivide blocks into orthogonal parcels
  function buildParcels(blockList: Array<BlockRect>): Array<ParcelRect>
    {
      var result = [];

      for (block in blockList)
        {
          var setback = getBlockSetback(block.density);
          var innerX = block.x + setback;
          var innerY = block.y + setback;
          var innerWidth = block.width - setback * 2;
          var innerHeight = block.height - setback * 2;
          if (innerWidth < PLAN_CELL_SIZE ||
              innerHeight < PLAN_CELL_SIZE)
            continue;

          subdivideParcel(makeParcelRect(innerX, innerY, innerWidth, innerHeight), result, 0);
        }

      return result;
    }

// recursively split a parcel candidate into parcel rectangles
  function subdivideParcel(parcel: ParcelRect, out: Array<ParcelRect>, depth: Int)
    {
      var targetWidth = getTargetParcelWidth(parcel.density);
      var targetHeight = getTargetParcelHeight(parcel.density);
      var splitThreshold = getParcelSplitThreshold(parcel.density);
      var canSplitX = parcel.width > targetWidth * splitThreshold;
      var canSplitY = parcel.height > targetHeight * splitThreshold;
      var maxDepth = getParcelMaxDepth(parcel.density);

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
          var minSplit = Std.int(parcel.width * getParcelSplitMinRatio(parcel.density));
          var maxSplit = Std.int(parcel.width * getParcelSplitMaxRatio(parcel.density));
          if (maxSplit - minSplit < PLAN_CELL_SIZE)
            {
              out.push(finalizeParcel(parcel));
              return;
            }

          var split = parcel.x + randomRangeInt(minSplit, maxSplit);
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

      var minSplit = Std.int(parcel.height * getParcelSplitMinRatio(parcel.density));
      var maxSplit = Std.int(parcel.height * getParcelSplitMaxRatio(parcel.density));
      if (maxSplit - minSplit < PLAN_CELL_SIZE)
        {
          out.push(finalizeParcel(parcel));
          return;
        }

      var split = parcel.y + randomRangeInt(minSplit, maxSplit);
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
        density: sampleAverageDensity(x, y, width, height),
        isOpen: false,
      };
    }

// finalize a parcel with plaza/open-space chance
  function finalizeParcel(parcel: ParcelRect): ParcelRect
    {
      var openChance = 0.0;
      if (parcel.density < 0.33)
        openChance = 0.006;
      else if (parcel.density < 0.66)
        openChance = 0.003;
      else openChance = 0.010;

      var centrality = getParcelCentrality(parcel);
      var area = parcel.width * parcel.height;
      if (parcel.density > 0.66 &&
          parcel.width > CLEAN_TILE_SIZE * 2 &&
          parcel.height > CLEAN_TILE_SIZE * 2)
        {
          openChance += 0.006 + centrality * 0.018;
          if (area >= CLEAN_TILE_SIZE * CLEAN_TILE_SIZE * 10)
            openChance += 0.010;
        }

      if (isSkinnyParcel(parcel))
        openChance += (parcel.density > 0.66 ? 0.03 : 0.06);
      if (parcel.width < PLAN_CELL_SIZE * 2 ||
          parcel.height < PLAN_CELL_SIZE * 2)
        openChance += 0.04;
      if (parcel.density < 0.33 &&
          parcel.width > CLEAN_TILE_SIZE * 3 &&
          parcel.height > CLEAN_TILE_SIZE * 3)
        openChance += 0.01;
      if (parcel.density < 0.33 &&
          centrality < 0.34 &&
          area >= CLEAN_TILE_SIZE * CLEAN_TILE_SIZE * 4)
        openChance += 0.01;

      openChance = clampFloat(openChance, 0.0, 0.92);

      parcel.isOpen = rng.nextFloat() < openChance;
      return parcel;
    }

// return the building style for one parcel
  function getBuildingStyle(parcel: ParcelRect): BuildingStyle
    {
      if (parcel.density < 0.33)
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

      if (parcel.density < 0.66)
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

// paint open parcels as yards or plazas
  function paintOpenParcels(parcelList: Array<ParcelRect>)
    {
      for (parcel in parcelList)
        {
          if (!parcel.isOpen)
            continue;

          var inset = PLAN_CELL_SIZE;
          if (parcel.density < 0.33)
            inset = PLAN_CELL_SIZE + 2;
          else if (parcel.density > 0.66)
            inset = PLAN_CELL_SIZE;

          var x = parcel.x + inset;
          var y = parcel.y + inset;
          var width = parcel.width - inset * 2;
          var height = parcel.height - inset * 2;
          if (width < PLAN_CELL_SIZE ||
              height < PLAN_CELL_SIZE)
            continue;

          if (parcel.density > 0.66)
            paintPlaza(x, y, width, height, parcel);
          else
            paintYard(x, y, width, height, parcel);
        }
    }

// generate one building footprint for a parcel
  function generateBuildingForParcel(parcel: ParcelRect): BuildingFootprint
    {
      var style = getBuildingStyle(parcel);
      if (rng.nextFloat() > style.buildChance)
        return null;

      var margin = style.margin;
      var innerX = parcel.x + margin;
      var innerY = parcel.y + margin;
      var innerWidth = parcel.width - margin * 2;
      var innerHeight = parcel.height - margin * 2;
      if (innerWidth < PLAN_CELL_SIZE ||
          innerHeight < PLAN_CELL_SIZE)
        return null;

      var shape = pickBuildingShape();
      var footprint = generateBuildingFootprintForShape(shape, innerX, innerY,
        innerWidth, innerHeight, parcel.density, style);
      if (footprint == null &&
          (shape == H_SHAPE ||
          shape == T_SHAPE))
        footprint = generateBuildingFootprintForShape(L_SHAPE, innerX, innerY,
          innerWidth, innerHeight, parcel.density, style);
      if (footprint == null &&
          shape != RECT)
        footprint = generateBuildingFootprintForShape(RECT, innerX, innerY,
          innerWidth, innerHeight, parcel.density, style);
      if (footprint == null ||
          footprintTouchesRoad(footprint))
        return null;

      var bounds = getFootprintBounds(footprint);
      var forecourtAlpha = style.forecourtAlpha;
      if (forecourtAlpha > 0.0 &&
          !hasVisibleForecourt(bounds, innerX, innerY, innerWidth, innerHeight))
        forecourtAlpha = 0.0;

      var color = pickBuildingColor(parcel.density);

      return {
        rects: footprint,
        color: color,
        density: parcel.density,
        lotX: innerX,
        lotY: innerY,
        lotWidth: innerWidth,
        lotHeight: innerHeight,
        forecourtColor: pickBuildingForecourtColor(parcel.density),
        forecourtAlpha: forecourtAlpha,
        roofColor: pickBuildingRoofColor(color, parcel.density),
        roofAlpha: pickBuildingRoofAlpha(parcel.density),
        edgeAlpha: pickBuildingEdgeAlpha(parcel.density),
        shadowOffset: getBuildingShadowOffset(parcel.density),
        shadowAlpha: style.shadowAlpha,
      };
    }

// pick one building footprint archetype
  function pickBuildingShape(): BuildingShapeType
    {
      var roll = rng.nextFloat();
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
        getLShapeMinRatio(density), getLShapeMaxRatio(density), centered);
      var cutoutSize = getLShapeCutoutSize(density);
      var verticalWidth = clampInt(Std.int(outer.width * randomRangeFloat(
        getLShapeBarMinRatio(density), getLShapeBarMaxRatio(density))),
        getMinBuildingPixelSize(), outer.width - cutoutSize);
      var horizontalHeight = clampInt(Std.int(outer.height * randomRangeFloat(
        getLShapeBarMinRatio(density), getLShapeBarMaxRatio(density))),
        getMinBuildingPixelSize(), outer.height - cutoutSize);

      if (outer.width - verticalWidth < cutoutSize ||
          outer.height - horizontalHeight < cutoutSize)
        return null;

      var side = rng.next() % 4;
      return switch (side) {
        case 0: [
          { x: outer.x, y: outer.y, width: verticalWidth, height: outer.height },
          { x: outer.x, y: outer.y, width: outer.width, height: horizontalHeight },
        ];
        case 1: [
          { x: outer.x, y: outer.y, width: verticalWidth, height: outer.height },
          { x: outer.x, y: outer.y + outer.height - horizontalHeight,
            width: outer.width, height: horizontalHeight },
        ];
        case 2: [
          { x: outer.x + outer.width - verticalWidth, y: outer.y,
            width: verticalWidth, height: outer.height },
          { x: outer.x, y: outer.y, width: outer.width, height: horizontalHeight },
        ];
        default: [
          { x: outer.x + outer.width - verticalWidth, y: outer.y,
            width: verticalWidth, height: outer.height },
          { x: outer.x, y: outer.y + outer.height - horizontalHeight,
            width: outer.width, height: horizontalHeight },
        ];
      };
    }

// generate one H-shaped footprint
  function generateHBuildingFootprint(x: Int, y: Int,
      width: Int, height: Int, density: Float, centered: Bool): Array<BuildingRect>
    {
      var outer = generatePlacedBuildingRect(x, y, width, height,
        getHShapeMinRatio(density), getHShapeMaxRatio(density), centered);
      var gapSize = getHShapeGapSize(density);
      var verticalLayout = outer.width >= outer.height;
      if (Math.abs(outer.width - outer.height) < PLAN_CELL_SIZE)
        verticalLayout = rng.nextFloat() < 0.5;

      if (verticalLayout)
        return generateVerticalHFootprint(outer, density, centered, gapSize);
      return generateHorizontalHFootprint(outer, density, centered, gapSize);
    }

// generate one T-shaped footprint
  function generateTBuildingFootprint(x: Int, y: Int,
      width: Int, height: Int, density: Float, centered: Bool): Array<BuildingRect>
    {
      var outer = generatePlacedBuildingRect(x, y, width, height,
        getHShapeMinRatio(density), getHShapeMaxRatio(density), centered);
      var verticalLayout = outer.height >= outer.width;
      if (Math.abs(outer.width - outer.height) < PLAN_CELL_SIZE)
        verticalLayout = rng.nextFloat() < 0.5;

      if (verticalLayout)
        return generateVerticalTFootprint(outer, density, centered);
      return generateHorizontalTFootprint(outer, density, centered);
    }

// generate one placed building rect inside a parcel
  function generatePlacedBuildingRect(x: Int, y: Int,
      width: Int, height: Int, minRatio: Float, maxRatio: Float,
      centered: Bool): BuildingRect
    {
      var bw = Std.int(width * randomRangeFloat(minRatio, maxRatio));
      var bh = Std.int(height * randomRangeFloat(minRatio, maxRatio));
      bw = clampInt(bw, getMinBuildingPixelSize(), width);
      bh = clampInt(bh, getMinBuildingPixelSize(), height);

      var bx = x;
      var by = y;
      if (width > bw)
        {
          if (centered)
            bx += pickCenteredPlacement(width - bw);
          else
            bx += randomRangeInt(0, width - bw);
        }
      if (height > bh)
        {
          if (centered)
            by += pickCenteredPlacement(height - bh);
          else
            by += randomRangeInt(0, height - bh);
        }

      return {
        x: bx,
        y: by,
        width: bw,
        height: bh,
      };
    }

// generate one vertical H footprint
  function generateVerticalHFootprint(outer: BuildingRect, density: Float,
      centered: Bool, gapSize: Int): Array<BuildingRect>
    {
      var maxBarWidth = Std.int((outer.width - gapSize) / 2);
      var maxCrossHeight = outer.height - gapSize * 2;
      if (maxBarWidth < getMinBuildingPixelSize() ||
          maxCrossHeight < getMinBuildingPixelSize())
        return null;

      var barWidth = clampInt(Std.int(outer.width * randomRangeFloat(
        getHShapeBarMinRatio(density), getHShapeBarMaxRatio(density))),
        getMinBuildingPixelSize(), maxBarWidth);
      if (outer.width - barWidth * 2 < gapSize)
        return null;

      var crossHeight = clampInt(Std.int(outer.height * randomRangeFloat(
        getHShapeBarMinRatio(density), getHShapeBarMaxRatio(density))),
        getMinBuildingPixelSize(), maxCrossHeight);
      var crossY = outer.y + gapSize;
      var crossSpan = outer.height - crossHeight - gapSize * 2;
      if (crossSpan > 0)
        {
          if (centered)
            crossY += pickCenteredPlacement(crossSpan);
          else
            crossY += randomRangeInt(0, crossSpan);
        }

      return [
        { x: outer.x, y: outer.y, width: barWidth, height: outer.height },
        { x: outer.x + outer.width - barWidth, y: outer.y,
          width: barWidth, height: outer.height },
        { x: outer.x, y: crossY, width: outer.width, height: crossHeight },
      ];
    }

// generate one horizontal H footprint
  function generateHorizontalHFootprint(outer: BuildingRect, density: Float,
      centered: Bool, gapSize: Int): Array<BuildingRect>
    {
      var maxBarHeight = Std.int((outer.height - gapSize) / 2);
      var maxCrossWidth = outer.width - gapSize * 2;
      if (maxBarHeight < getMinBuildingPixelSize() ||
          maxCrossWidth < getMinBuildingPixelSize())
        return null;

      var barHeight = clampInt(Std.int(outer.height * randomRangeFloat(
        getHShapeBarMinRatio(density), getHShapeBarMaxRatio(density))),
        getMinBuildingPixelSize(), maxBarHeight);
      if (outer.height - barHeight * 2 < gapSize)
        return null;

      var crossWidth = clampInt(Std.int(outer.width * randomRangeFloat(
        getHShapeBarMinRatio(density), getHShapeBarMaxRatio(density))),
        getMinBuildingPixelSize(), maxCrossWidth);
      var crossX = outer.x + gapSize;
      var crossSpan = outer.width - crossWidth - gapSize * 2;
      if (crossSpan > 0)
        {
          if (centered)
            crossX += pickCenteredPlacement(crossSpan);
          else
            crossX += randomRangeInt(0, crossSpan);
        }

      return [
        { x: outer.x, y: outer.y, width: outer.width, height: barHeight },
        { x: outer.x, y: outer.y + outer.height - barHeight,
          width: outer.width, height: barHeight },
        { x: crossX, y: outer.y, width: crossWidth, height: outer.height },
      ];
    }

// generate one vertical T footprint
  function generateVerticalTFootprint(outer: BuildingRect, density: Float,
      centered: Bool): Array<BuildingRect>
    {
      var capHeight = clampInt(Std.int(outer.height * randomRangeFloat(
        getHShapeBarMinRatio(density), getHShapeBarMaxRatio(density))),
        getMinBuildingPixelSize(), outer.height);
      var stemWidth = clampInt(Std.int(outer.width * randomRangeFloat(
        getHShapeBarMinRatio(density), getHShapeBarMaxRatio(density))),
        getMinBuildingPixelSize(), outer.width);
      if (outer.height - capHeight < getMinBuildingPixelSize())
        return null;

      var stemX = outer.x;
      var stemSpan = outer.width - stemWidth;
      if (stemSpan > 0)
        {
          if (centered)
            stemX += pickCenteredPlacement(stemSpan);
          else
            stemX += randomRangeInt(0, stemSpan);
        }

      if (rng.nextFloat() < 0.5)
        return [
          { x: outer.x, y: outer.y, width: outer.width, height: capHeight },
          { x: stemX, y: outer.y, width: stemWidth, height: outer.height },
        ];

      return [
        { x: outer.x, y: outer.y + outer.height - capHeight,
          width: outer.width, height: capHeight },
        { x: stemX, y: outer.y, width: stemWidth, height: outer.height },
      ];
    }

// generate one horizontal T footprint
  function generateHorizontalTFootprint(outer: BuildingRect, density: Float,
      centered: Bool): Array<BuildingRect>
    {
      var capWidth = clampInt(Std.int(outer.width * randomRangeFloat(
        getHShapeBarMinRatio(density), getHShapeBarMaxRatio(density))),
        getMinBuildingPixelSize(), outer.width);
      var stemHeight = clampInt(Std.int(outer.height * randomRangeFloat(
        getHShapeBarMinRatio(density), getHShapeBarMaxRatio(density))),
        getMinBuildingPixelSize(), outer.height);
      if (outer.width - capWidth < getMinBuildingPixelSize())
        return null;

      var stemY = outer.y;
      var stemSpan = outer.height - stemHeight;
      if (stemSpan > 0)
        {
          if (centered)
            stemY += pickCenteredPlacement(stemSpan);
          else
            stemY += randomRangeInt(0, stemSpan);
        }

      if (rng.nextFloat() < 0.5)
        return [
          { x: outer.x, y: outer.y, width: capWidth, height: outer.height },
          { x: outer.x, y: stemY, width: outer.width, height: stemHeight },
        ];

      return [
        { x: outer.x + outer.width - capWidth, y: outer.y,
          width: capWidth, height: outer.height },
        { x: outer.x, y: stemY, width: outer.width, height: stemHeight },
      ];
    }

// paint all building footprints
  function paintBuildings()
    {
      for (building in buildings)
        paintBuilding(building);
    }

// paint one building footprint with a soft edge and shadow
  function paintBuilding(building: BuildingFootprint)
    {
      var shadowColor = adjustColor(COLOR_BUILDING_SHADOW, 0.96 + building.density * 0.08);
      var highlightColor = adjustColor(building.roofColor, 1.07);
      var shadeColor = adjustColor(building.color, 0.76);

      if (building.forecourtAlpha > 0.0)
        paintBuildingForecourt(building);

      ctx.fillStyle = '#' + StringTools.hex(building.color, 6);
      ctx.globalAlpha = building.edgeAlpha;
      for (rect in building.rects)
        {
          if (isSmallBuildingRect(rect))
            continue;
          ctx.fillRect(rect.x - 2, rect.y - 2, rect.width + 4, rect.height + 4);
        }

      ctx.fillStyle = '#' + StringTools.hex(shadowColor, 6);
      ctx.globalAlpha = building.shadowAlpha;
      for (rect in building.rects)
        {
          if (isSmallBuildingRect(rect))
            continue;
          ctx.fillRect(rect.x + building.shadowOffset, rect.y + building.shadowOffset,
            rect.width, rect.height);
        }

      ctx.fillStyle = '#' + StringTools.hex(building.color, 6);
      ctx.globalAlpha = 1.0;
      for (rect in building.rects)
        {
          ctx.fillRect(rect.x, rect.y, rect.width, rect.height);
        }

      ctx.fillStyle = '#' + StringTools.hex(building.roofColor, 6);
      ctx.globalAlpha = building.roofAlpha;
      for (rect in building.rects)
        {
          if (isSmallBuildingRect(rect))
            continue;
          var roofInset = getBuildingRoofInset(rect, building.density);
          var roofWidth = rect.width - roofInset * 2;
          var roofHeight = rect.height - roofInset * 2;
          if (roofWidth < CLEAN_TILE_SIZE / 5 ||
              roofHeight < CLEAN_TILE_SIZE / 5)
            continue;

          ctx.fillRect(rect.x + roofInset, rect.y + roofInset, roofWidth, roofHeight);
        }

      ctx.fillStyle = '#' + StringTools.hex(highlightColor, 6);
      ctx.globalAlpha = 0.08 + building.edgeAlpha * 0.45;
      for (rect in building.rects)
        {
          if (isSmallBuildingRect(rect))
            continue;
          var edgeWidth = getBuildingEdgeWidth(rect, building.density);
          ctx.fillRect(rect.x, rect.y, rect.width, edgeWidth);
          ctx.fillRect(rect.x, rect.y, edgeWidth, rect.height);
        }

      ctx.fillStyle = '#' + StringTools.hex(shadeColor, 6);
      ctx.globalAlpha = 0.11 + building.edgeAlpha * 0.55;
      for (rect in building.rects)
        {
          if (isSmallBuildingRect(rect))
            continue;
          var edgeWidth = getBuildingEdgeWidth(rect, building.density);
          ctx.fillRect(rect.x, rect.y + rect.height - edgeWidth, rect.width, edgeWidth);
          ctx.fillRect(rect.x + rect.width - edgeWidth, rect.y, edgeWidth, rect.height);
        }

      ctx.globalAlpha = 1.0;
    }

// paint a paved forecourt around a centered tower footprint
  function paintBuildingForecourt(building: BuildingFootprint)
    {
      var inset = 3;
      var x = building.lotX + inset;
      var y = building.lotY + inset;
      var width = building.lotWidth - inset * 2;
      var height = building.lotHeight - inset * 2;
      if (width < CLEAN_TILE_SIZE / 2 ||
          height < CLEAN_TILE_SIZE / 2)
        return;

      ctx.globalAlpha = building.forecourtAlpha;
      ctx.fillStyle = '#' + StringTools.hex(building.forecourtColor, 6);
      ctx.fillRect(x, y, width, height);

      ctx.globalAlpha = building.forecourtAlpha * 0.48;
      ctx.fillStyle = '#' + StringTools.hex(adjustColor(building.forecourtColor, 1.08), 6);
      ctx.fillRect(x + Std.int(width / 2) - 2, y + 4, 4, height - 8);
      ctx.fillRect(x + 4, y + Std.int(height / 2) - 2, width - 8, 4);
      ctx.globalAlpha = 1.0;
    }

// paint one high-density open parcel as a plaza
  function paintPlaza(x: Int, y: Int, width: Int, height: Int, parcel: ParcelRect)
    {
      ctx.globalAlpha = 0.46;
      ctx.fillStyle = '#' + StringTools.hex(adjustColor(COLOR_PLAZA,
        0.92 + hashFloat(parcel.x, parcel.y, 211) * 0.14), 6);
      ctx.fillRect(x, y, width, height);

      ctx.globalAlpha = 0.28;
      ctx.fillStyle = '#' + StringTools.hex(COLOR_PLAZA_EDGE, 6);
      ctx.fillRect(x + Std.int(width / 2) - 2, y + 4, 4, height - 8);
      ctx.fillRect(x + 4, y + Std.int(height / 2) - 2, width - 8, 4);
      if (width > CLEAN_TILE_SIZE * 2 &&
          height > CLEAN_TILE_SIZE * 2)
        {
          ctx.globalAlpha = 0.12;
          ctx.fillRect(x + Std.int(width / 4) - 1, y + 6, 2, height - 12);
          ctx.fillRect(x + Std.int(width * 3 / 4) - 1, y + 6, 2, height - 12);
          ctx.fillRect(x + 6, y + Std.int(height / 4) - 1, width - 12, 2);
          ctx.fillRect(x + 6, y + Std.int(height * 3 / 4) - 1, width - 12, 2);
        }
      ctx.globalAlpha = 1.0;
    }

// paint one lower-density open parcel as a yard
  function paintYard(x: Int, y: Int, width: Int, height: Int, parcel: ParcelRect)
    {
      ctx.globalAlpha = 0.24;
      ctx.fillStyle = '#' + StringTools.hex(adjustColor(COLOR_YARD,
        0.92 + hashFloat(parcel.x, parcel.y, 223) * 0.18), 6);
      ctx.fillRect(x, y, width, height);
      ctx.globalAlpha = 0.10;
      ctx.fillStyle = '#' + StringTools.hex(adjustColor(COLOR_YARD, 1.10), 6);
      ctx.fillRect(x + 4, y + 4, width - 8, height - 8);
      ctx.globalAlpha = 1.0;
    }

// crop the halo out of the final cached canvas

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

// return a center-biased connector coordinate

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
