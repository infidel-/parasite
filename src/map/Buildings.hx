// block, parcel, and building helpers kept with the map renderer

package map;

import map.Types.BlockComponent;
import map.Types.BlockRect;
import map.Types.BuildingFootprint;
import map.Types.BuildingRect;
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
            blocked[xx][yy] =
              masks.occupancy[xx][yy] > 0.0 ||
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

            if (cells.length < 8)
              continue;

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
          if (pixelWidth < CLEAN_TILE_SIZE ||
              pixelHeight < CLEAN_TILE_SIZE)
            continue;

          var density = sampleAverageDensity(pixelX, pixelY, pixelWidth, pixelHeight);
          if (density < 0.16)
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

      if (bestArea < 4)
        return null;

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
          if (innerWidth < CLEAN_TILE_SIZE ||
              innerHeight < CLEAN_TILE_SIZE)
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
          if (maxSplit - minSplit < CLEAN_TILE_SIZE / 2)
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
      if (maxSplit - minSplit < CLEAN_TILE_SIZE / 2)
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
        openChance = 0.10;
      else if (parcel.density < 0.66)
        openChance = 0.03;
      else openChance = 0.01;

      var centrality = getParcelCentrality(parcel);
      var area = parcel.width * parcel.height;
      if (parcel.density > 0.66 &&
          parcel.width > CLEAN_TILE_SIZE * 2 &&
          parcel.height > CLEAN_TILE_SIZE * 2)
        {
          openChance += 0.01 + centrality * 0.03;
          if (area >= CLEAN_TILE_SIZE * CLEAN_TILE_SIZE * 6)
            openChance += 0.02;
        }

      if (isSkinnyParcel(parcel))
        openChance += (parcel.density > 0.66 ? 0.10 : 0.28);
      if (parcel.width < CLEAN_TILE_SIZE ||
          parcel.height < CLEAN_TILE_SIZE)
        openChance += 0.25;
      if (parcel.density < 0.33 &&
          parcel.width > CLEAN_TILE_SIZE * 3 &&
          parcel.height > CLEAN_TILE_SIZE * 3)
        openChance += 0.02;
      if (parcel.density < 0.33 &&
          centrality < 0.34 &&
          area >= CLEAN_TILE_SIZE * CLEAN_TILE_SIZE * 4)
        openChance += 0.02;

      openChance = clampFloat(openChance, 0.0, 0.92);

      parcel.isOpen = rng.nextFloat() < openChance;
      return parcel;
    }

// return the building style for one parcel
  function getBuildingStyle(parcel: ParcelRect): BuildingStyle
    {
      if (parcel.density < 0.33)
        {
          var lowRoll = rng.nextFloat();
          var lowExtra = 0;
          if (lowRoll < 0.10) lowExtra = 1;
          else if (lowRoll < 0.11) lowExtra = 2;
          return {
            buildChance: 0.96,
            margin: 4 + rng.next() % 4,
            minRatio: 0.10,
            maxRatio: 0.24,
            extraRectCount: lowExtra,
            shadowAlpha: 0.16,
            forecourtAlpha: 0.0,
            centered: false,
          };
        }

      if (parcel.density < 0.66)
        {
          var medRoll = rng.nextFloat();
          var medExtra = 0;
          if (medRoll < 0.64) medExtra = 1;
          else if (medRoll < 0.86) medExtra = 2;
          return {
            buildChance: 0.995,
            margin: 2 + rng.next() % 3,
            minRatio: 0.22,
            maxRatio: 0.46,
            extraRectCount: medExtra,
            shadowAlpha: 0.24,
            forecourtAlpha: 0.0,
            centered: false,
          };
        }

      var plaza = parcel.width > CLEAN_TILE_SIZE * 2 &&
        parcel.height > CLEAN_TILE_SIZE * 2 &&
        rng.nextFloat() < getHighDensityPlazaChance(parcel);
      return {
        buildChance: 0.995,
        margin: (plaza ? 8 + rng.next() % 3 : 1),
        minRatio: (plaza ? 0.18 : 0.28),
        maxRatio: (plaza ? 0.34 : 0.52),
        extraRectCount: (plaza ? 0 : (rng.nextFloat() < 0.04 ? 1 : 0)),
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

          var inset = 8;
          if (parcel.density < 0.33)
            inset = 10;
          else if (parcel.density > 0.66)
            inset = 8;

          var x = parcel.x + inset;
          var y = parcel.y + inset;
          var width = parcel.width - inset * 2;
          var height = parcel.height - inset * 2;
          if (width < CLEAN_TILE_SIZE / 3 ||
              height < CLEAN_TILE_SIZE / 3)
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
      if (innerWidth < CLEAN_TILE_SIZE / 4 ||
          innerHeight < CLEAN_TILE_SIZE / 4)
        return null;

      var footprint = [];
      var mainRect = generatePrimaryBuildingRect(innerX, innerY,
        innerWidth, innerHeight, style);
      footprint.push(mainRect);

      var extraRects = style.extraRectCount;
      for (i in 0...extraRects)
        {
          var wing = generateWingRect(mainRect, innerX, innerY,
            innerWidth, innerHeight);
          if (wing != null &&
              wingAddsUsefulArea(mainRect, wing, footprint))
            footprint.push(wing);
        }

      if (footprintTouchesRoad(footprint) ||
          footprintArea(footprint) < mainRect.width * mainRect.height * 0.95)
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

// generate the main building mass in a parcel
  function generatePrimaryBuildingRect(x: Int, y: Int,
      width: Int, height: Int, style: BuildingStyle): BuildingRect
    {
      var bw = Std.int(width * randomRangeFloat(style.minRatio, style.maxRatio));
      var bh = Std.int(height * randomRangeFloat(style.minRatio, style.maxRatio));
      bw = clampInt(bw, Std.int(CLEAN_TILE_SIZE / 5), width);
      bh = clampInt(bh, Std.int(CLEAN_TILE_SIZE / 5), height);

      var bx = x;
      var by = y;
      if (width > bw)
        {
          if (style.centered)
            bx += pickCenteredPlacement(width - bw);
          else
            bx += randomRangeInt(0, width - bw);
        }
      if (height > bh)
        {
          if (style.centered)
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

// generate an attached wing rectangle
  function generateWingRect(mainRect: BuildingRect,
      parcelX: Int, parcelY: Int, parcelWidth: Int, parcelHeight: Int): BuildingRect
    {
      if (mainRect.width < CLEAN_TILE_SIZE / 2 ||
          mainRect.height < CLEAN_TILE_SIZE / 2)
        return null;

      var wingWidth = clampInt(Std.int(mainRect.width * randomRangeFloat(0.30, 0.55)),
        Std.int(CLEAN_TILE_SIZE / 5), mainRect.width);
      var wingHeight = clampInt(Std.int(mainRect.height * randomRangeFloat(0.25, 0.45)),
        Std.int(CLEAN_TILE_SIZE / 5), mainRect.height);
      var side = rng.next() % 4;
      var wx = mainRect.x;
      var wy = mainRect.y;

      switch (side)
        {
          case 0:
            wx = mainRect.x + randomRangeInt(0,
              Std.int(Math.max(mainRect.width - wingWidth, 0)));
            wy = mainRect.y - wingHeight + Std.int(CLEAN_TILE_SIZE / 5);
          case 1:
            wx = mainRect.x + randomRangeInt(0,
              Std.int(Math.max(mainRect.width - wingWidth, 0)));
            wy = mainRect.y + mainRect.height - Std.int(CLEAN_TILE_SIZE / 5);
          case 2:
            wx = mainRect.x - wingWidth + Std.int(CLEAN_TILE_SIZE / 5);
            wy = mainRect.y + randomRangeInt(0,
              Std.int(Math.max(mainRect.height - wingHeight, 0)));
          case 3:
            wx = mainRect.x + mainRect.width - Std.int(CLEAN_TILE_SIZE / 5);
            wy = mainRect.y + randomRangeInt(0,
              Std.int(Math.max(mainRect.height - wingHeight, 0)));
        }

      if (wy < parcelY)
        wy = parcelY;
      if (wy + wingHeight > parcelY + parcelHeight)
        wy = parcelY + parcelHeight - wingHeight;
      if (wx < parcelX)
        wx = parcelX;
      if (wx + wingWidth > parcelX + parcelWidth)
        wx = parcelX + parcelWidth - wingWidth;

      if (wingWidth < CLEAN_TILE_SIZE / 5 ||
          wingHeight < CLEAN_TILE_SIZE / 5)
        return null;

      return {
        x: wx,
        y: wy,
        width: wingWidth,
        height: wingHeight,
      };
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
          ctx.fillRect(rect.x - 2, rect.y - 2, rect.width + 4, rect.height + 4);
        }

      ctx.fillStyle = '#' + StringTools.hex(shadowColor, 6);
      ctx.globalAlpha = building.shadowAlpha;
      for (rect in building.rects)
        {
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
          var edgeWidth = getBuildingEdgeWidth(rect, building.density);
          ctx.fillRect(rect.x, rect.y, rect.width, edgeWidth);
          ctx.fillRect(rect.x, rect.y, edgeWidth, rect.height);
        }

      ctx.fillStyle = '#' + StringTools.hex(shadeColor, 6);
      ctx.globalAlpha = 0.11 + building.edgeAlpha * 0.55;
      for (rect in building.rects)
        {
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
        return 14;
      if (density < 0.66)
        return 8;
      return 4;
    }

// return the target parcel width for a density band
  function getTargetParcelWidth(density: Float): Int
    {
      if (density < 0.33)
        return Std.int(CLEAN_TILE_SIZE * 2.5);
      if (density < 0.66)
        return Std.int(CLEAN_TILE_SIZE * 1.6);
      return Std.int(CLEAN_TILE_SIZE * 0.95);
    }

// return the target parcel height for a density band
  function getTargetParcelHeight(density: Float): Int
    {
      if (density < 0.33)
        return Std.int(CLEAN_TILE_SIZE * 2.5);
      if (density < 0.66)
        return Std.int(CLEAN_TILE_SIZE * 1.6);
      return Std.int(CLEAN_TILE_SIZE * 0.95);
    }

// return the recursion depth limit for parcel subdivision
  function getParcelMaxDepth(density: Float): Int
    {
      if (density < 0.33)
        return 3;
      if (density < 0.66)
        return 5;
      return 6;
    }

// return the parcel split threshold multiplier
  function getParcelSplitThreshold(density: Float): Float
    {
      if (density < 0.33)
        return 1.45;
      if (density < 0.66)
        return 1.18;
      return 1.04;
    }

// return the minimum split ratio for a parcel
  function getParcelSplitMinRatio(density: Float): Float
    {
      if (density < 0.33)
        return 0.30;
      if (density < 0.66)
        return 0.34;
      return 0.38;
    }

// return the maximum split ratio for a parcel
  function getParcelSplitMaxRatio(density: Float): Float
    {
      if (density < 0.33)
        return 0.70;
      if (density < 0.66)
        return 0.66;
      return 0.62;
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
          var maxX = clampInt(Std.int(Math.ceil(checkX2 / PLAN_CELL_SIZE)), 0, planWidth - 1);
          var minY = clampInt(Std.int(Math.floor(checkY1 / PLAN_CELL_SIZE)), 0, planHeight - 1);
          var maxY = clampInt(Std.int(Math.ceil(checkY2 / PLAN_CELL_SIZE)), 0, planHeight - 1);

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

// return whether a wing adds enough distinct area to keep
  function wingAddsUsefulArea(mainRect: BuildingRect, wing: BuildingRect,
      existing: Array<BuildingRect>): Bool
    {
      if (wing == null)
        return false;

      var overlapMain = getRectOverlapArea(mainRect, wing);
      var wingArea = wing.width * wing.height;
      var newArea = wingArea - overlapMain;
      if (newArea < wingArea * 0.35)
        return false;

      var extendsPastMain =
        wing.x < mainRect.x ||
        wing.y < mainRect.y ||
        wing.x + wing.width > mainRect.x + mainRect.width ||
        wing.y + wing.height > mainRect.y + mainRect.height;
      if (!extendsPastMain)
        return false;

      for (rect in existing)
        {
          if (rect == mainRect)
            continue;
          var overlap = getRectOverlapArea(rect, wing);
          if (overlap > wingArea * 0.55)
            return false;
        }

      return true;
    }

// return the total approximate footprint union area
  function footprintArea(rects: Array<BuildingRect>): Float
    {
      if (rects.length == 0)
        return 0.0;

      var area = 0.0;
      for (i in 0...rects.length)
        {
          var rect = rects[i];
          area += rect.width * rect.height;
          for (j in 0...i)
            area -= getRectOverlapArea(rect, rects[j]);
        }
      return area;
    }

// return overlap area between two axis-aligned rectangles
  function getRectOverlapArea(a: BuildingRect, b: BuildingRect): Float
    {
      var x1 = Math.max(a.x, b.x);
      var y1 = Math.max(a.y, b.y);
      var x2 = Math.min(a.x + a.width, b.x + b.width);
      var y2 = Math.min(a.y + a.height, b.y + b.height);
      if (x2 <= x1 || y2 <= y1)
        return 0.0;
      return (x2 - x1) * (y2 - y1);
    }

}
