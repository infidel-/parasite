// road-plan grid allocation, queries, stamps, and compression helpers

package map.roadplan;

import _AreaType;
import map.RoadPlan;
import map.RoadType;
import map.Types.GridPoint;
import map.Types.RoadPlanGrid;
import map.Types.RoadSegment;

@:access(map.Core)
@:access(map.Ground)
@:access(map.Raster)
@:access(map.RoadPlan)
class RoadPlanGridOps
{
  var plan: RoadPlan;

  public function new(plan: RoadPlan)
    {
      this.plan = plan;
    }

// allocate the working road occupancy grid
  public function makeRoadPlanGrid(): RoadPlanGrid
    {
      var startTS = haxe.Timer.stamp() * 1000.0;
      var horizontal = plan.makeIntGrid(plan.planWidth, plan.planHeight);
      var vertical = plan.makeIntGrid(plan.planWidth, plan.planHeight);
      var cornerOrder = plan.makeIntGrid(plan.planWidth, plan.planHeight);
      var cornerMask = plan.makeIntGrid(plan.planWidth, plan.planHeight);
      var road1Cells = plan.makeBoolGrid(plan.planWidth, plan.planHeight);
      var road2Cells = plan.makeBoolGrid(plan.planWidth, plan.planHeight);
      var road2IDs = plan.makeIntGrid(plan.planWidth, plan.planHeight);
      var road2AxisMask = plan.makeIntGrid(plan.planWidth, plan.planHeight);
      var initStartTS = haxe.Timer.stamp() * 1000.0;
      plan.addMapProfileSample('grid.makeRoadPlanGrid.alloc', initStartTS - startTS);

      for (xx in 0...plan.planWidth)
        for (yy in 0...plan.planHeight)
          {
            horizontal[xx][yy] = -1;
            vertical[xx][yy] = -1;
            cornerOrder[xx][yy] = -1;
            cornerMask[xx][yy] = 0;
            road1Cells[xx][yy] = false;
            road2Cells[xx][yy] = false;
            road2IDs[xx][yy] = -1;
            road2AxisMask[xx][yy] = 0;
          }

      plan.addMapProfileSample('grid.makeRoadPlanGrid.init',
        haxe.Timer.stamp() * 1000.0 - initStartTS);

      return {
        width: plan.planWidth,
        height: plan.planHeight,
        horizontal: horizontal,
        vertical: vertical,
        cornerOrder: cornerOrder,
        cornerMask: cornerMask,
        road1Cells: road1Cells,
        road2Cells: road2Cells,
        road2IDs: road2IDs,
        road2AxisMask: road2AxisMask,
      };
    }

// return whether one visible region tile already contains one road tier
  public function hasRoadTypeInRegionTile(grid: RoadPlanGrid, cellX: Int, cellY: Int,
      type: RoadType): Bool
    {
      var startX = cellX * plan.PLAN_CELLS_PER_TILE;
      var startY = cellY * plan.PLAN_CELLS_PER_TILE;

      for (yy in startY...startY + plan.PLAN_CELLS_PER_TILE)
        for (xx in startX...startX + plan.PLAN_CELLS_PER_TILE)
          if (hasRoadTypeAtPlanCell(grid, xx, yy, type))
            return true;

      return false;
    }

// return whether one visible region tile already contains orange road cells
  public function hasRoad2InRegionTile(grid: RoadPlanGrid, cellX: Int, cellY: Int): Bool
    {
      return hasRoadTypeInRegionTile(grid, cellX, cellY, ROAD2);
    }

// return whether one empty cell can be used to touch one parent-road tier set
  public function isThinRoadAttachmentCell(grid: RoadPlanGrid, planX: Int, planY: Int,
      parentTypes: Array<RoadType>): Bool
    {
      if (!isInPlanBounds(planX, planY) ||
          isPlanCellOccupied(grid, planX, planY))
        return false;

      for (dir in 0...4)
        {
          var nx = planX + getCardinalDX(dir);
          var ny = planY + getCardinalDY(dir);
          if (isInPlanBounds(nx, ny) &&
              hasParentRoadFacingCell(grid, nx, ny, planX, planY, parentTypes))
            return true;
        }
      return false;
    }

// return whether one plan cell already carries any road in one tier set
  public function hasAnyRoadTypeAtPlanCell(grid: RoadPlanGrid, planX: Int, planY: Int,
      types: Array<RoadType>): Bool
    {
      for (type in types)
        if (hasRoadTypeAtPlanCell(grid, planX, planY, type))
          return true;
      return false;
    }

// return whether one plan cell touches one parent road on one chosen side
  public function hasParentRoadOnSide(grid: RoadPlanGrid, planX: Int, planY: Int,
      dx: Int, dy: Int, parentTypes: Array<RoadType>): Bool
    {
      var nextX = planX + dx;
      var nextY = planY + dy;
      return isInPlanBounds(nextX, nextY) &&
        hasParentRoadFacingCell(grid, nextX, nextY, planX, planY, parentTypes);
    }

// return whether one parent-road cell actually faces one neighboring attachment cell
  public function hasParentRoadFacingCell(grid: RoadPlanGrid, roadX: Int, roadY: Int,
      targetX: Int, targetY: Int, parentTypes: Array<RoadType>): Bool
    {
      for (type in parentTypes)
        if (hasRoadTypeFacingCell(grid, roadX, roadY, targetX, targetY, type))
          return true;
      return false;
    }

// return whether one road cell reaches the shared edge toward one neighboring cell
  public function hasRoadTypeFacingCell(grid: RoadPlanGrid, roadX: Int, roadY: Int,
      targetX: Int, targetY: Int, type: RoadType): Bool
    {
      if (!hasRoadTypeAtPlanCell(grid, roadX, roadY, type))
        return false;
      if (type == ROAD1)
        return true;
      if (type == ROAD2)
        return hasRoad2FacingCell(grid, roadX, roadY, targetX, targetY);
      return hasRoadTypeDirectionAtPlanCell(grid, roadX, roadY,
        targetX - roadX, targetY - roadY, type);
    }

// return whether one ROAD2 cell exposes the shared side toward one attachment cell
  public function hasRoad2FacingCell(grid: RoadPlanGrid, roadX: Int, roadY: Int,
      targetX: Int, targetY: Int): Bool
    {
      var axisMask = grid.road2AxisMask[roadX][roadY];
      var dx = targetX - roadX;
      var dy = targetY - roadY;
      if (dx != 0)
        return (axisMask & 2) != 0;
      if (dy != 0)
        return (axisMask & 1) != 0;
      return false;
    }

// return whether one plan-grid coordinate is inside bounds
  public function isInPlanBounds(planX: Int, planY: Int): Bool
    {
      return planX >= 0 &&
        planY >= 0 &&
        planX < plan.planWidth &&
        planY < plan.planHeight;
    }

// return the raw area type at one plan-grid cell
  public function getAreaTypeAtPlanCell(planX: Int, planY: Int): _AreaType
    {
      var cellX = plan.clampInt(Std.int(planX / plan.PLAN_CELLS_PER_TILE), 0, plan.fullCellWidth - 1);
      var cellY = plan.clampInt(Std.int(planY / plan.PLAN_CELLS_PER_TILE), 0, plan.fullCellHeight - 1);
      return plan.areaTypes[cellX][cellY];
    }

// return whether one plan cell already has any road axis
  public function isPlanCellOccupied(grid: RoadPlanGrid, planX: Int, planY: Int): Bool
    {
      return grid.horizontal[planX][planY] >= 0 ||
        grid.vertical[planX][planY] >= 0 ||
        grid.cornerOrder[planX][planY] >= 0 ||
        grid.road1Cells[planX][planY] ||
        grid.road2Cells[planX][planY];
    }

// return whether one plan cell touches any blocking road in the surrounding cardinal neighbors
  public function hasAdjacentRoadNeighbor(grid: RoadPlanGrid, planX: Int, planY: Int,
      ignoreX: Int = -1, ignoreY: Int = -1): Bool
    {
      for (dir in 0...4)
        {
          var xx = planX + getCardinalDX(dir);
          var yy = planY + getCardinalDY(dir);
          if (!isInPlanBounds(xx, yy) ||
              (xx == ignoreX &&
              yy == ignoreY))
            continue;
          if (grid.road1Cells[xx][yy] ||
              grid.road2Cells[xx][yy] ||
              hasFacingThinRoadNeighbor(grid, xx, yy, planX, planY))
            return true;
        }
      return false;
    }

// return whether one candidate road cell would run parallel one cell away from another road
  public function hasParallelRoadFlankConflict(grid: RoadPlanGrid, planX: Int, planY: Int,
      dx: Int, dy: Int): Bool
    {
      return hasParallelRoadFlankConflictForAxisMask(grid, planX, planY, getRoadAxisMask(dx, dy));
    }

// return whether one candidate road cell would run parallel one cell away on any painted axis
  public function hasParallelRoadFlankConflictForAxisMask(grid: RoadPlanGrid, planX: Int, planY: Int,
      axisMask: Int): Bool
    {
      if ((axisMask & 1) != 0 &&
          (hasParallelRoadAxisAtPlanCell(grid, planX, planY - 1, 1) ||
          hasParallelRoadAxisAtPlanCell(grid, planX, planY + 1, 1)))
        return true;
      if ((axisMask & 2) != 0 &&
          (hasParallelRoadAxisAtPlanCell(grid, planX - 1, planY, 2) ||
          hasParallelRoadAxisAtPlanCell(grid, planX + 1, planY, 2)))
        return true;
      return false;
    }

// return whether one neighboring plan cell carries any road on the requested axis
  public function hasParallelRoadAxisAtPlanCell(grid: RoadPlanGrid, planX: Int, planY: Int,
      axisMask: Int): Bool
    {
      if (!isInPlanBounds(planX, planY))
        return false;
      if (grid.road1Cells[planX][planY])
        return true;
      if ((grid.road2AxisMask[planX][planY] & axisMask) != 0)
        return true;
      return (getAnyThinRoadAxisMaskAtPlanCell(grid, planX, planY) & axisMask) != 0;
    }

// return whether one neighboring thin-road cell reaches the shared edge
  public function hasFacingThinRoadNeighbor(grid: RoadPlanGrid, roadX: Int, roadY: Int,
      targetX: Int, targetY: Int): Bool
    {
      return hasRoadTypeFacingCell(grid, roadX, roadY, targetX, targetY, ROAD3) ||
        hasRoadTypeFacingCell(grid, roadX, roadY, targetX, targetY, ROAD4) ||
        hasRoadTypeFacingCell(grid, roadX, roadY, targetX, targetY, ROAD5);
    }

// return the stored horizontal-or-vertical bits from any thin road at one plan cell
  public function getAnyThinRoadAxisMaskAtPlanCell(grid: RoadPlanGrid, planX: Int, planY: Int): Int
    {
      var mask = 0;
      if (grid.horizontal[planX][planY] >= 0)
        mask = mask | 1;
      if (grid.vertical[planX][planY] >= 0)
        mask = mask | 2;
      if (grid.cornerOrder[planX][planY] >= 0)
        {
          if ((grid.cornerMask[planX][planY] & (1 | 2)) != 0)
            mask = mask | 1;
          if ((grid.cornerMask[planX][planY] & (4 | 8)) != 0)
            mask = mask | 2;
        }
      return mask;
    }

// return the stored axis mask for one road tier at one plan cell
  public function getRoadTypeAxisMaskAtPlanCell(grid: RoadPlanGrid, planX: Int, planY: Int,
      type: RoadType): Int
    {
      if (type == ROAD2)
        return grid.road2AxisMask[planX][planY];

      var order = plan.getRoadTypeOrder(type);
      var mask = 0;
      if (grid.horizontal[planX][planY] == order)
        mask = mask | 1;
      if (grid.vertical[planX][planY] == order)
        mask = mask | 2;
      if (grid.cornerOrder[planX][planY] == order)
        {
          if ((grid.cornerMask[planX][planY] & (1 | 2)) != 0)
            mask = mask | 1;
          if ((grid.cornerMask[planX][planY] & (4 | 8)) != 0)
            mask = mask | 2;
        }
      return mask;
    }

// return whether one stored road tier reaches one edge direction inside one plan cell
  public function hasRoadTypeDirectionAtPlanCell(grid: RoadPlanGrid, planX: Int, planY: Int,
      dx: Int, dy: Int, type: RoadType): Bool
    {
      var order = plan.getRoadTypeOrder(type);
      if (dx != 0 &&
          grid.horizontal[planX][planY] == order)
        return true;
      if (dy != 0 &&
          grid.vertical[planX][planY] == order)
        return true;
      return grid.cornerOrder[planX][planY] == order &&
        (grid.cornerMask[planX][planY] & getRoadDirectionMask(dx, dy)) != 0;
    }

// return the horizontal-or-vertical axis bit for one step direction
  public function getRoadAxisMask(dx: Int, dy: Int): Int
    {
      return (dx != 0 ? 1 : 2);
    }

// return the perpendicular axis mask for one road axis mask
  public function getPerpendicularRoadAxisMask(axisMask: Int): Int
    {
      var result = 0;
      if ((axisMask & 1) != 0)
        result = result | 2;
      if ((axisMask & 2) != 0)
        result = result | 1;
      return result;
    }

// return whether the rendered 2x2 orange footprint would hit any road cell
  public function doesRoad2FootprintHitAnyRoad(grid: RoadPlanGrid, planX: Int, planY: Int,
      ignoreStampX: Int = -1, ignoreStampY: Int = -1): Bool
    {
      for (yy in planY...Std.int(Math.min(planY + 2, plan.planHeight)))
        for (xx in planX...Std.int(Math.min(planX + 2, plan.planWidth)))
          if (!isInsideRoad2Stamp(xx, yy, ignoreStampX, ignoreStampY) &&
              isPlanCellOccupied(grid, xx, yy))
            return true;
      return false;
    }

// return whether one orange footprint is too close to another orange corridor
  public function hasRoad2ClearanceConflict(grid: RoadPlanGrid, planX: Int, planY: Int,
      road2ID: Int): Bool
    {
      var minX = plan.clampInt(planX - plan.PLAN_CELLS_PER_TILE, 0, plan.planWidth - 1);
      var maxX = plan.clampInt(planX + 1 + plan.PLAN_CELLS_PER_TILE, 0, plan.planWidth - 1);
      var minY = plan.clampInt(planY - plan.PLAN_CELLS_PER_TILE, 0, plan.planHeight - 1);
      var maxY = plan.clampInt(planY + 1 + plan.PLAN_CELLS_PER_TILE, 0, plan.planHeight - 1);

      for (yy in minY...maxY + 1)
        for (xx in minX...maxX + 1)
          if (grid.road2IDs[xx][yy] >= 0 &&
              grid.road2IDs[xx][yy] != road2ID)
            return true;
      return false;
    }

// return whether one plan cell belongs to a specific ROAD2 2x2 stamp anchor
  public function isInsideRoad2Stamp(planX: Int, planY: Int, stampX: Int, stampY: Int): Bool
    {
      return stampX >= 0 &&
        stampY >= 0 &&
        planX >= stampX &&
        planX < stampX + 2 &&
        planY >= stampY &&
        planY < stampY + 2;
    }

// return whether one plan cell carries the requested road tier on any stored shape
  public function hasRoadTypeAtPlanCell(grid: RoadPlanGrid, planX: Int, planY: Int,
      type: RoadType): Bool
    {
      var order = plan.getRoadTypeOrder(type);
      if (type == ROAD1)
        return grid.road1Cells[planX][planY];
      if (type == ROAD2)
        return grid.road2Cells[planX][planY];
      return grid.horizontal[planX][planY] == order ||
        grid.vertical[planX][planY] == order ||
        grid.cornerOrder[planX][planY] == order;
    }

// mark one ROAD2 anchor as a real 2x2 occupied footprint
  public function addRoad2PlanStamp(grid: RoadPlanGrid, planX: Int, planY: Int,
      road2ID: Int, axisMask: Int)
    {
      for (yy in planY...Std.int(Math.min(planY + 2, plan.planHeight)))
        for (xx in planX...Std.int(Math.min(planX + 2, plan.planWidth)))
          {
            grid.road2Cells[xx][yy] = true;
            grid.road2IDs[xx][yy] = road2ID;
            grid.road2AxisMask[xx][yy] = grid.road2AxisMask[xx][yy] | axisMask;
          }
    }

// mark one ROAD1 centerline step as an occupied trunk cell
  public function addRoad1PlanStamp(grid: RoadPlanGrid, planX: Int, planY: Int, dx: Int, dy: Int)
    {
      grid.road1Cells[planX][planY] = true;
    }

// mark one road axis cell while keeping the stronger road tier when overlapping
  public function addRoadPlanAxis(grid: RoadPlanGrid, planX: Int, planY: Int,
      dx: Int, dy: Int, type: RoadType)
    {
      var order = plan.getRoadTypeOrder(type);
      var axis = (dx != 0 ? grid.horizontal : grid.vertical);
      var current = axis[planX][planY];

      if (current < 0 ||
          order < current)
        axis[planX][planY] = order;
      if (type == ROAD1)
        addRoad1PlanStamp(grid, planX, planY, dx, dy);
    }

// mark one explicit corner cell between incoming and outgoing directions
  public function addRoadPlanCorner(grid: RoadPlanGrid, planX: Int, planY: Int,
      inDx: Int, inDy: Int, outDx: Int, outDy: Int, type: RoadType)
    {
      var order = plan.getRoadTypeOrder(type);
      var current = grid.cornerOrder[planX][planY];
      var mask = getRoadDirectionMask(-inDx, -inDy) | getRoadDirectionMask(outDx, outDy);

      if (current < 0 ||
          order < current)
        {
          grid.cornerOrder[planX][planY] = order;
          grid.cornerMask[planX][planY] = mask;
          return;
        }
      if (current == order)
        grid.cornerMask[planX][planY] = grid.cornerMask[planX][planY] | mask;
    }

// add one directional half-arm mask on an existing road cell
  public function addRoadPlanDirectionMask(grid: RoadPlanGrid, planX: Int, planY: Int,
      mask: Int, type: RoadType)
    {
      var order = plan.getRoadTypeOrder(type);
      var current = grid.cornerOrder[planX][planY];

      if (current < 0 ||
          order < current)
        {
          grid.cornerOrder[planX][planY] = order;
          grid.cornerMask[planX][planY] = mask;
          return;
        }
      if (current == order)
        grid.cornerMask[planX][planY] = grid.cornerMask[planX][planY] | mask;
    }

// clear one thin-road tier from one plan cell without touching stronger tiers
  public function clearThinRoadTypeAtPlanCell(grid: RoadPlanGrid, planX: Int, planY: Int,
      type: RoadType)
    {
      var order = plan.getRoadTypeOrder(type);

      if (grid.horizontal[planX][planY] == order)
        grid.horizontal[planX][planY] = -1;
      if (grid.vertical[planX][planY] == order)
        grid.vertical[planX][planY] = -1;
      if (grid.cornerOrder[planX][planY] == order)
        {
          grid.cornerOrder[planX][planY] = -1;
          grid.cornerMask[planX][planY] = 0;
        }
    }

// add one orthogonal path to the plan grid using axis and corner cells
  public function addRoadPlanPath(grid: RoadPlanGrid, path: Array<GridPoint>, type: RoadType)
    {
      if (path.length < 2)
        return;

      for (i in 0...path.length)
        {
          if (i == 0)
            {
              addRoadPlanAxis(grid, path[i].x, path[i].y,
                path[i + 1].x - path[i].x,
                path[i + 1].y - path[i].y, type);
              continue;
            }
          if (i == path.length - 1)
            {
              addRoadPlanAxis(grid, path[i].x, path[i].y,
                path[i].x - path[i - 1].x,
                path[i].y - path[i - 1].y, type);
              continue;
            }

          var inDx = path[i].x - path[i - 1].x;
          var inDy = path[i].y - path[i - 1].y;
          var outDx = path[i + 1].x - path[i].x;
          var outDy = path[i + 1].y - path[i].y;
          if (inDx == outDx &&
              inDy == outDy)
            addRoadPlanAxis(grid, path[i].x, path[i].y, outDx, outDy, type);
          else
            addRoadPlanCorner(grid, path[i].x, path[i].y, inDx, inDy, outDx, outDy, type);
        }
    }

// return the bitmask for one orthogonal road direction
  public function getRoadDirectionMask(dx: Int, dy: Int): Int
    {
      if (dx < 0)
        return 1;
      if (dx > 0)
        return 2;
      if (dy < 0)
        return 4;
      return 8;
    }

// compress the plan-grid occupancy back into orthogonal road segments
  public function compressRoadPlanGrid(grid: RoadPlanGrid): Array<RoadSegment>
    {
      var result = [];
      var sectionStartTS = haxe.Timer.stamp() * 1000.0;

      for (yy in 0...grid.height)
        {
          var xx = 0;
          while (xx < grid.width)
            {
              var order = grid.horizontal[xx][yy];
              if (order < 0)
                {
                  xx++;
                  continue;
                }

              var start = xx;
              while (xx + 1 < grid.width &&
                  grid.horizontal[xx + 1][yy] == order)
                xx++;

              result.push({
                x1: start * plan.PLAN_CELL_SIZE,
                y1: yy * plan.PLAN_CELL_SIZE + Std.int(plan.PLAN_CELL_SIZE / 2),
                x2: (xx + 1) * plan.PLAN_CELL_SIZE,
                y2: yy * plan.PLAN_CELL_SIZE + Std.int(plan.PLAN_CELL_SIZE / 2),
                type: plan.getRoadTypeByOrder(order),
              });
              xx++;
            }
        }

      var nowTS = haxe.Timer.stamp() * 1000.0;
      plan.addMapProfileSample('grid.compress.horizontal', nowTS - sectionStartTS);
      sectionStartTS = nowTS;

      for (xx in 0...grid.width)
        {
          var yy = 0;
          while (yy < grid.height)
            {
              var order = grid.vertical[xx][yy];
              if (order < 0)
                {
                  yy++;
                  continue;
                }

              var start = yy;
              while (yy + 1 < grid.height &&
                  grid.vertical[xx][yy + 1] == order)
                yy++;

              result.push({
                x1: xx * plan.PLAN_CELL_SIZE + Std.int(plan.PLAN_CELL_SIZE / 2),
                y1: start * plan.PLAN_CELL_SIZE,
                x2: xx * plan.PLAN_CELL_SIZE + Std.int(plan.PLAN_CELL_SIZE / 2),
                y2: (yy + 1) * plan.PLAN_CELL_SIZE,
                type: plan.getRoadTypeByOrder(order),
              });
              yy++;
            }
        }

      nowTS = haxe.Timer.stamp() * 1000.0;
      plan.addMapProfileSample('grid.compress.vertical', nowTS - sectionStartTS);
      sectionStartTS = nowTS;

      for (yy in 0...grid.height)
        for (xx in 0...grid.width)
          {
            var order = grid.cornerOrder[xx][yy];
            if (order < 0)
              continue;
            addCornerRoadSegments(result, xx, yy, grid.cornerMask[xx][yy], plan.getRoadTypeByOrder(order));
          }

      nowTS = haxe.Timer.stamp() * 1000.0;
      plan.addMapProfileSample('grid.compress.corners', nowTS - sectionStartTS);
      sectionStartTS = nowTS;

      for (yy in 0...grid.height)
        for (xx in 0...grid.width)
          {
            if (!grid.road2Cells[xx][yy])
              continue;
            addRoad2CellSegment(result, xx, yy);
          }

      plan.addMapProfileSample('grid.compress.road2Cells',
        haxe.Timer.stamp() * 1000.0 - sectionStartTS);

      return result;
    }

// add one tiny ROAD2 center segment for a stamped occupied cell
  function addRoad2CellSegment(out: Array<RoadSegment>, xx: Int, yy: Int)
    {
      var centerX = xx * plan.PLAN_CELL_SIZE + Std.int(plan.PLAN_CELL_SIZE / 2);
      var centerY = yy * plan.PLAN_CELL_SIZE + Std.int(plan.PLAN_CELL_SIZE / 2);

      out.push({
        x1: centerX - 1,
        y1: centerY,
        x2: centerX + 1,
        y2: centerY,
        type: ROAD2,
      });
    }

// add the short half-cell arm segments for one corner cell
  function addCornerRoadSegments(out: Array<RoadSegment>, xx: Int, yy: Int,
      mask: Int, type: RoadType)
    {
      var cellX = xx * plan.PLAN_CELL_SIZE;
      var cellY = yy * plan.PLAN_CELL_SIZE;
      var centerX = cellX + Std.int(plan.PLAN_CELL_SIZE / 2);
      var centerY = cellY + Std.int(plan.PLAN_CELL_SIZE / 2);

      if ((mask & 1) != 0)
        out.push({
          x1: cellX,
          y1: centerY,
          x2: centerX,
          y2: centerY,
          type: type,
        });
      if ((mask & 2) != 0)
        out.push({
          x1: centerX,
          y1: centerY,
          x2: cellX + plan.PLAN_CELL_SIZE,
          y2: centerY,
          type: type,
        });
      if ((mask & 4) != 0)
        out.push({
          x1: centerX,
          y1: cellY,
          x2: centerX,
          y2: centerY,
          type: type,
        });
      if ((mask & 8) != 0)
        out.push({
          x1: centerX,
          y1: centerY,
          x2: centerX,
          y2: cellY + plan.PLAN_CELL_SIZE,
          type: type,
        });
    }

// return the x delta for one cardinal direction index
  public function getCardinalDX(index: Int): Int
    {
      return switch (index) {
        case 0: -1;
        case 1: 1;
        default: 0;
      };
    }

// return the y delta for one cardinal direction index
  public function getCardinalDY(index: Int): Int
    {
      return switch (index) {
        case 2: -1;
        case 3: 1;
        default: 0;
      };
    }
}
