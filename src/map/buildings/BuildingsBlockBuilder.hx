// building block extraction helpers

package map.buildings;

import map.Buildings;
import map.Types.BlockComponent;
import map.Types.BlockRect;
import map.Types.GridPoint;
import map.Types.IntRect;
import map.Types.RoadMasks;

@:access(map.Core)
@:access(map.Ground)
@:access(map.Raster)
@:access(map.RoadPlan)
@:access(map.LegacyRoads)
@:access(map.Buildings)
class BuildingsBlockBuilder
{
  var plan: Buildings;

  public function new(plan: Buildings)
    {
      this.plan = plan;
    }

// derive rectangular blocks from the final road masks
  public function buildBlocks(): Array<BlockRect>
    {
      return buildBlocksFromMasks(plan.roadMasks);
    }

// derive rectangular blocks from the road occupancy mask
  public function buildBlocksFromMasks(masks: RoadMasks): Array<BlockRect>
    {
      var result = [];
      var blocked = plan.makeBoolGrid(plan.planWidth, plan.planHeight);

      for (yy in 0...plan.planHeight)
        for (xx in 0...plan.planWidth)
          {
            var px = xx * plan.PLAN_CELL_SIZE + Std.int(plan.PLAN_CELL_SIZE / 2);
            var py = yy * plan.PLAN_CELL_SIZE + Std.int(plan.PLAN_CELL_SIZE / 2);
            var areaType = plan.areaTypes[
              plan.clampInt(Std.int(xx / plan.PLAN_CELLS_PER_TILE), 0, plan.fullCellWidth - 1)
            ][
              plan.clampInt(Std.int(yy / plan.PLAN_CELLS_PER_TILE), 0, plan.fullCellHeight - 1)
            ];
            blocked[xx][yy] =
              masks.occupancy[xx][yy] > 0.0 ||
              !plan.isBuildableAreaType(areaType) ||
              !plan.isBuildableGroundCell(xx, yy, px, py);
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
      var visited = plan.makeBoolGrid(plan.planWidth, plan.planHeight);

      for (yy in 0...plan.planHeight)
        for (xx in 0...plan.planWidth)
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

                    if (nx < 0 || ny < 0 || nx >= plan.planWidth || ny >= plan.planHeight)
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

// extract rectangular blocks from one connected component
  function extractBlocksFromComponent(component: BlockComponent, out: Array<BlockRect>)
    {
      var localWidth = component.maxX - component.minX + 1;
      var localHeight = component.maxY - component.minY + 1;
      var available = plan.makeBoolGrid(localWidth, localHeight);

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

          var pixelX = (component.minX + rect.x) * plan.PLAN_CELL_SIZE;
          var pixelY = (component.minY + rect.y) * plan.PLAN_CELL_SIZE;
          var pixelWidth = rect.width * plan.PLAN_CELL_SIZE;
          var pixelHeight = rect.height * plan.PLAN_CELL_SIZE;
          if (pixelWidth < plan.PLAN_CELL_SIZE ||
              pixelHeight < plan.PLAN_CELL_SIZE)
            continue;

          var density = plan.sampleAverageDensity(pixelX, pixelY, pixelWidth, pixelHeight);
          var districtType = plan.getBuildingDistrictTypeForRect(pixelX, pixelY,
            pixelWidth, pixelHeight);
          if (density < 0.02)
            continue;

          out.push({
            x: pixelX,
            y: pixelY,
            width: pixelWidth,
            height: pixelHeight,
            density: density,
            districtType: districtType,
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

}
