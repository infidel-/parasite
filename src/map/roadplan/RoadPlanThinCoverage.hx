// road-plan thin-road coverage and connector helpers

package map.roadplan;

import map.RoadPlan;
import map.RoadType;
import map.Types.GridPoint;
import map.Types.IntRect;
import map.Types.RoadPlanGrid;
import map.Types.ThinAttachmentCache;
import map.Types.ThinRoadStart;

@:access(map.Core)
@:access(map.Ground)
@:access(map.Raster)
@:access(map.RoadPlan)
class RoadPlanThinCoverage
{
  var plan: RoadPlan;
  var gridOps: RoadPlanGridOps;
  var branchWalker: RoadPlanBranchWalker;

  public function new(plan: RoadPlan, gridOps: RoadPlanGridOps,
      branchWalker: RoadPlanBranchWalker)
    {
      this.plan = plan;
      this.gridOps = gridOps;
      this.branchWalker = branchWalker;
    }

// build one attachment cache for one thin-road tile attempt
  function makeThinAttachmentCache(searchRect: IntRect): ThinAttachmentCache
    {
      return {
        searchRect: searchRect,
        buckets: [],
      };
    }

// return a stable cache key for one thin-road parent tier set
  function getThinRoadAttachmentCacheKey(parentTypes: Array<RoadType>): Int
    {
      var key = 0;

      for (type in parentTypes)
        key = key | (1 << plan.getRoadTypeOrder(type));
      return key;
    }

// return the local thin-road attachment list for one tier set
  function getThinRoadAttachmentList(grid: RoadPlanGrid, parentTypes: Array<RoadType>,
      searchRect: IntRect, cache: ThinAttachmentCache = null): Array<GridPoint>
    {
      if (cache == null)
        return collectThinRoadAttachments(grid, parentTypes, searchRect);

      var key = getThinRoadAttachmentCacheKey(parentTypes);
      for (bucket in cache.buckets)
        if (bucket.key == key)
          return bucket.points;

      var points = collectThinRoadAttachments(grid, parentTypes, cache.searchRect);
      cache.buckets.push({
        key: key,
        points: points,
      });
      return points;
    }

// add a separate green coverage pass over city tiles after orange is settled
  public function ensureCityRoad3Coverage(grid: RoadPlanGrid)
    {
      var parentTypes: Array<RoadType> = [ROAD2];

      for (cellY in 0...plan.fullCellHeight)
        for (cellX in 0...plan.fullCellWidth)
          {
            if (!plan.isCityAreaType(plan.areaTypes[cellX][cellY]))
              continue;

            if (gridOps.hasRoadTypeInRegionTile(grid, cellX, cellY, ROAD1))
              continue;

            if (gridOps.hasRoadTypeInRegionTile(grid, cellX, cellY, ROAD3))
              continue;

            plan.addMapProfileCount('thin.coverage.ROAD3.attempts');
            if (spawnThinRoadCoverage(grid, cellX, cellY, ROAD3, parentTypes))
              plan.addMapProfileCount('thin.coverage.ROAD3.success');
          }
    }

// remove isolated green components that never touch ROAD1 or ROAD2
  public function pruneOrphanRoad3Components(grid: RoadPlanGrid)
    {
      var visited = plan.makeBoolGrid(plan.planWidth, plan.planHeight);

      for (xx in 0...plan.planWidth)
        for (yy in 0...plan.planHeight)
          {
            if (visited[xx][yy] ||
                !gridOps.hasRoadTypeAtPlanCell(grid, xx, yy, ROAD3))
              continue;

            var queue: Array<GridPoint> = [{
              x: xx,
              y: yy,
            }];
            var cells: Array<GridPoint> = [];
            var index = 0;
            var touchesOtherRoad = false;

            visited[xx][yy] = true;

            while (index < queue.length)
              {
                var point = queue[index++];
                cells.push(point);
                if (doesRoad3CellTouchOtherRoad(grid, point.x, point.y))
                  touchesOtherRoad = true;

                for (dir in 0...4)
                  {
                    var nx = point.x + gridOps.getCardinalDX(dir);
                    var ny = point.y + gridOps.getCardinalDY(dir);
                    if (!gridOps.isInPlanBounds(nx, ny) ||
                        visited[nx][ny] ||
                        !gridOps.hasRoadTypeAtPlanCell(grid, nx, ny, ROAD3) ||
                        !doRoad3CellsConnect(grid, point.x, point.y, nx, ny))
                      continue;
                    visited[nx][ny] = true;
                    queue.push({
                      x: nx,
                      y: ny,
                    });
                  }
              }

            if (touchesOtherRoad)
              {
                plan.addMapProfileCount('thin.pruneOrphanRoad3Components.keptComponents');
                continue;
              }

            plan.addMapProfileCount('thin.pruneOrphanRoad3Components.removedComponents');
            plan.addMapProfileCount('thin.pruneOrphanRoad3Components.removedCells', cells.length);
            for (cell in cells)
              gridOps.clearThinRoadTypeAtPlanCell(grid, cell.x, cell.y, ROAD3);
          }
    }

// add a separate red coverage pass over city tiles after green is settled
  public function ensureCityRoad4Coverage(grid: RoadPlanGrid)
    {
      var parentTypes: Array<RoadType> = [ROAD3, ROAD2];
      var targetTypeGroups: Array<Array<RoadType>> = [[ROAD3], [ROAD2]];

      for (cellY in 0...plan.fullCellHeight)
        for (cellX in 0...plan.fullCellWidth)
          {
            if (!plan.isCityAreaType(plan.areaTypes[cellX][cellY]))
              continue;

            if (gridOps.hasRoadTypeInRegionTile(grid, cellX, cellY, ROAD1))
              continue;

            if (gridOps.hasRoadTypeInRegionTile(grid, cellX, cellY, ROAD4))
              continue;

            plan.addMapProfileCount('thin.coverage.ROAD4.attempts');
            if (spawnBidirectionalThinRoadCoverage(grid, cellX, cellY, ROAD4, parentTypes,
                  targetTypeGroups))
              plan.addMapProfileCount('thin.coverage.ROAD4.success');
          }
    }

// return whether two neighboring ROAD3 cells share one real edge connection
  function doRoad3CellsConnect(grid: RoadPlanGrid, fromX: Int, fromY: Int, toX: Int, toY: Int): Bool
    {
      return gridOps.hasRoadTypeFacingCell(grid, fromX, fromY, toX, toY, ROAD3) &&
        gridOps.hasRoadTypeFacingCell(grid, toX, toY, fromX, fromY, ROAD3);
    }

// return whether one ROAD3 cell touches ROAD1 or ROAD2 across one shared edge
  function doesRoad3CellTouchOtherRoad(grid: RoadPlanGrid, planX: Int, planY: Int): Bool
    {
      for (dir in 0...4)
        {
          var nx = planX + gridOps.getCardinalDX(dir);
          var ny = planY + gridOps.getCardinalDY(dir);
          if (!gridOps.isInPlanBounds(nx, ny) ||
              !gridOps.hasRoadTypeFacingCell(grid, planX, planY, nx, ny, ROAD3))
            continue;
          if (gridOps.hasRoadTypeFacingCell(grid, nx, ny, planX, planY, ROAD1) ||
              gridOps.hasRoadTypeFacingCell(grid, nx, ny, planX, planY, ROAD2))
            return true;
        }
      return false;
    }

// add a separate blue coverage pass over city tiles after red is settled
  public function ensureCityRoad5Coverage(grid: RoadPlanGrid)
    {
      var parentTypes: Array<RoadType> = [ROAD5, ROAD4, ROAD3, ROAD2];
      var targetTypeGroups: Array<Array<RoadType>> = [[ROAD4], [ROAD3], [ROAD2]];

      for (cellY in 0...plan.fullCellHeight)
        for (cellX in 0...plan.fullCellWidth)
          {
            if (!plan.isCityAreaType(plan.areaTypes[cellX][cellY]))
              continue;

            if (gridOps.hasRoadTypeInRegionTile(grid, cellX, cellY, ROAD1))
              continue;

            if (gridOps.hasRoadTypeInRegionTile(grid, cellX, cellY, ROAD5))
              continue;

            plan.addMapProfileCount('thin.coverage.ROAD5.attempts');
            if (spawnBidirectionalThinRoadCoverage(grid, cellX, cellY, ROAD5, parentTypes,
                  targetTypeGroups))
              plan.addMapProfileCount('thin.coverage.ROAD5.success');
          }
    }

// add one one-sided thin-road coverage branch for one city tile
  public function spawnThinRoadCoverage(grid: RoadPlanGrid, cellX: Int, cellY: Int,
      type: RoadType, parentTypes: Array<RoadType>,
      targetTypeGroups: Array<Array<RoadType>> = null): Bool
    {
      var searchRect = getThinRoadSearchRect(cellX, cellY);
      var cache = makeThinAttachmentCache(searchRect);
      var start = findThinRoadCoverageStart(grid, cellX, cellY, parentTypes, targetTypeGroups,
        searchRect, cache);
      if (start == null)
        return false;

      var target = findPreferredThinRoadAttachmentInDirection(grid, parentTypes,
        targetTypeGroups, start.x, start.y, start.dx, start.dy, searchRect, cache);
      if (!gridOps.isThinRoadAttachmentCell(grid, start.x, start.y, parentTypes) &&
          target != null &&
          connectThinRoadToTarget(grid, start, target, type, parentTypes))
        return true;

      branchWalker.walkBranchRoad(grid, branchWalker.makeThinRoadWalker(start.x, start.y,
        start.dx, start.dy, type, (type == ROAD3 ? plan.ROAD3_T_SPLIT_STEPS : -1),
        type == ROAD4 || type == ROAD5));
      return true;
    }

// add one two-sided thin-road coverage branch for one city tile
  public function spawnBidirectionalThinRoadCoverage(grid: RoadPlanGrid, cellX: Int, cellY: Int,
      type: RoadType, parentTypes: Array<RoadType>,
      targetTypeGroups: Array<Array<RoadType>> = null): Bool
    {
      var searchRect = getThinRoadSearchRect(cellX, cellY);
      var cache = makeThinAttachmentCache(searchRect);
      var start = findThinRoadCoverageStart(grid, cellX, cellY, parentTypes, targetTypeGroups,
        searchRect, cache);
      if (start == null)
        return false;

      var addedForward = spawnThinRoadSide(grid, start.x, start.y, start.dx, start.dy,
        type, parentTypes, false, targetTypeGroups, searchRect, cache);
      var addedBackward = spawnThinRoadSide(grid, start.x, start.y, -start.dx, -start.dy,
        type, parentTypes, addedForward, targetTypeGroups, searchRect, cache);
      return addedForward || addedBackward;
    }

// return the local 3x3 region-tile search window for one thin-road spawn tile
  function getThinRoadSearchRect(cellX: Int, cellY: Int): IntRect
    {
      var minCellX = plan.clampInt(cellX - 1, 0, plan.fullCellWidth - 1);
      var maxCellX = plan.clampInt(cellX + 1, 0, plan.fullCellWidth - 1);
      var minCellY = plan.clampInt(cellY - 1, 0, plan.fullCellHeight - 1);
      var maxCellY = plan.clampInt(cellY + 1, 0, plan.fullCellHeight - 1);
      return {
        x: minCellX * plan.PLAN_CELLS_PER_TILE,
        y: minCellY * plan.PLAN_CELLS_PER_TILE,
        width: (maxCellX - minCellX + 1) * plan.PLAN_CELLS_PER_TILE,
        height: (maxCellY - minCellY + 1) * plan.PLAN_CELLS_PER_TILE,
      };
    }

// find a usable thin-road coverage start for one city tile
  function findThinRoadCoverageStart(grid: RoadPlanGrid, cellX: Int, cellY: Int,
      parentTypes: Array<RoadType>,
      targetTypeGroups: Array<Array<RoadType>> = null,
      searchRect: IntRect = null, cache: ThinAttachmentCache = null): ThinRoadStart
    {
      var centerX = cellX * plan.PLAN_CELLS_PER_TILE + Std.int(plan.PLAN_CELLS_PER_TILE / 2);
      var centerY = cellY * plan.PLAN_CELLS_PER_TILE + Std.int(plan.PLAN_CELLS_PER_TILE / 2);
      var horizontalScore = getThinRoadCoverageAxisScore(grid, parentTypes, targetTypeGroups,
        centerX, centerY, 1, searchRect, cache);
      var verticalScore = getThinRoadCoverageAxisScore(grid, parentTypes, targetTypeGroups,
        centerX, centerY, 2, searchRect, cache);
      if (horizontalScore < 0x3FFFFFFF ||
          verticalScore < 0x3FFFFFFF)
        {
          var firstAxisMask = (horizontalScore <= verticalScore ? 1 : 2);
          var secondAxisMask = (firstAxisMask == 1 ? 2 : 1);
          var firstScore = (firstAxisMask == 1 ? horizontalScore : verticalScore);
          var secondScore = (secondAxisMask == 1 ? horizontalScore : verticalScore);
          var axisStart = findThinRoadCoverageStartOnAxis(grid, cellX, cellY, parentTypes,
            targetTypeGroups, firstAxisMask, searchRect, cache);
          if (axisStart != null)
            return axisStart;
          if (secondScore < 0x3FFFFFFF)
            {
              axisStart = findThinRoadCoverageStartOnAxis(grid, cellX, cellY, parentTypes,
                targetTypeGroups, secondAxisMask, searchRect, cache);
              if (axisStart != null)
                return axisStart;
            }
          if (firstScore < 0x3FFFFFFF)
            {
              plan.addMapProfileCount('thin.findThinRoadCoverageStart.null');
              return null;
            }
        }

      var preferredTarget = findPreferredThinRoadAttachment(grid, parentTypes, targetTypeGroups,
        centerX, centerY, searchRect, cache);
      var start = findTileThinRoadStart(grid, cellX, cellY, preferredTarget, parentTypes);
      if (start == null &&
          preferredTarget != null)
        start = findTileThinRoadStart(grid, cellX, cellY, null, parentTypes);
      if (start == null)
        plan.addMapProfileCount('thin.findThinRoadCoverageStart.null');
      return start;
    }

// find a usable thin-road coverage start for one chosen axis
  function findThinRoadCoverageStartOnAxis(grid: RoadPlanGrid, cellX: Int, cellY: Int,
      parentTypes: Array<RoadType>, targetTypeGroups: Array<Array<RoadType>>,
      axisMask: Int, searchRect: IntRect = null,
      cache: ThinAttachmentCache = null): ThinRoadStart
    {
      var centerX = cellX * plan.PLAN_CELLS_PER_TILE + Std.int(plan.PLAN_CELLS_PER_TILE / 2);
      var centerY = cellY * plan.PLAN_CELLS_PER_TILE + Std.int(plan.PLAN_CELLS_PER_TILE / 2);
      var preferredTarget = findPreferredThinRoadAttachmentForAxis(grid, parentTypes,
        targetTypeGroups, centerX, centerY, axisMask, searchRect, cache);
      var start = findTileThinRoadStart(grid, cellX, cellY, preferredTarget, parentTypes,
        axisMask);
      if (start == null &&
          preferredTarget != null)
        start = findTileThinRoadStart(grid, cellX, cellY, null, parentTypes, axisMask);
      return start;
    }

// score one thin-road coverage axis from opposite-side parent targets
  function getThinRoadCoverageAxisScore(grid: RoadPlanGrid, parentTypes: Array<RoadType>,
      targetTypeGroups: Array<Array<RoadType>>, planX: Int, planY: Int, axisMask: Int,
      searchRect: IntRect = null, cache: ThinAttachmentCache = null): Int
    {
      var negativeTarget = findPreferredThinRoadAttachmentInDirection(grid, parentTypes,
        targetTypeGroups, planX, planY, axisMask == 1 ? -1 : 0, axisMask == 2 ? -1 : 0,
        searchRect, cache);
      var positiveTarget = findPreferredThinRoadAttachmentInDirection(grid, parentTypes,
        targetTypeGroups, planX, planY, axisMask == 1 ? 1 : 0, axisMask == 2 ? 1 : 0,
        searchRect, cache);
      if (negativeTarget == null &&
          positiveTarget == null)
        return 0x3FFFFFFF;

      var score = 0;
      if (negativeTarget != null)
        score += Std.int(Math.abs(negativeTarget.x - planX) + Math.abs(negativeTarget.y - planY));
      else
        score += plan.PLAN_CELLS_PER_TILE * 4;
      if (positiveTarget != null)
        score += Std.int(Math.abs(positiveTarget.x - planX) + Math.abs(positiveTarget.y - planY));
      else
        score += plan.PLAN_CELLS_PER_TILE * 4;
      if (negativeTarget != null &&
          positiveTarget != null)
        score -= plan.PLAN_CELLS_PER_TILE;
      return score;
    }

// return the closer parent attachment on one chosen axis
  function findPreferredThinRoadAttachmentForAxis(grid: RoadPlanGrid, parentTypes: Array<RoadType>,
      targetTypeGroups: Array<Array<RoadType>>, planX: Int, planY: Int, axisMask: Int,
      searchRect: IntRect = null, cache: ThinAttachmentCache = null): GridPoint
    {
      var negativeTarget = findPreferredThinRoadAttachmentInDirection(grid, parentTypes,
        targetTypeGroups, planX, planY, axisMask == 1 ? -1 : 0, axisMask == 2 ? -1 : 0,
        searchRect, cache);
      var positiveTarget = findPreferredThinRoadAttachmentInDirection(grid, parentTypes,
        targetTypeGroups, planX, planY, axisMask == 1 ? 1 : 0, axisMask == 2 ? 1 : 0,
        searchRect, cache);
      if (negativeTarget == null)
        return positiveTarget;
      if (positiveTarget == null)
        return negativeTarget;

      var negativeDist = Std.int(Math.abs(negativeTarget.x - planX) + Math.abs(negativeTarget.y - planY));
      var positiveDist = Std.int(Math.abs(positiveTarget.x - planX) + Math.abs(positiveTarget.y - planY));
      return (negativeDist <= positiveDist ? negativeTarget : positiveTarget);
    }

// add one directional thin-road side from a shared start cell
  function spawnThinRoadSide(grid: RoadPlanGrid, startX: Int, startY: Int, dx: Int, dy: Int,
      type: RoadType, parentTypes: Array<RoadType>, allowOccupiedStart: Bool,
      targetTypeGroups: Array<Array<RoadType>> = null, searchRect: IntRect = null,
      cache: ThinAttachmentCache = null): Bool
    {
      if (!branchWalker.canUseBranchRoadStart(grid, startX, startY, dx, dy, allowOccupiedStart))
        return false;

      if (gridOps.hasParentRoadOnSide(grid, startX, startY, dx, dy, parentTypes))
        {
          gridOps.addRoadPlanAxis(grid, startX, startY, dx, dy, type);
          return true;
        }

      var target = findPreferredThinRoadAttachmentInDirection(grid, parentTypes,
        targetTypeGroups, startX, startY, dx, dy, searchRect, cache);
      var start: ThinRoadStart = {
        x: startX,
        y: startY,
        dx: dx,
        dy: dy,
      };
      if (target != null &&
          connectThinRoadToTarget(grid, start, target, type, parentTypes, allowOccupiedStart))
        return true;

      branchWalker.walkBranchRoad(grid, branchWalker.makeThinRoadWalker(startX, startY,
        dx, dy, type, -1, type == ROAD4 || type == ROAD5));
      return true;
    }

// collect all empty cells where one thin road can attach to one parent tier set
  function collectThinRoadAttachments(grid: RoadPlanGrid, parentTypes: Array<RoadType>,
      searchRect: IntRect = null): Array<GridPoint>
    {
#if mydebug
      var startTS = haxe.Timer.stamp() * 1000.0;
#end
      var result = [];
      var minX = (searchRect != null ? searchRect.x : 0);
      var minY = (searchRect != null ? searchRect.y : 0);
      var maxX = (searchRect != null ? searchRect.x + searchRect.width : plan.planWidth);
      var maxY = (searchRect != null ? searchRect.y + searchRect.height : plan.planHeight);
      var usedWidth = maxX - minX;
      var usedHeight = maxY - minY;
      var used = [];

      for (ii in 0...usedWidth * usedHeight)
        used.push(false);

      for (yy in minY...maxY)
        for (xx in minX...maxX)
          {
            if (!gridOps.hasAnyRoadTypeAtPlanCell(grid, xx, yy, parentTypes))
              continue;

            for (dir in 0...4)
              {
                var nx = xx + gridOps.getCardinalDX(dir);
                var ny = yy + gridOps.getCardinalDY(dir);
                var localIndex = (nx - minX) * usedHeight + (ny - minY);
                if (!gridOps.isInPlanBounds(nx, ny) ||
                    (searchRect != null &&
                    (nx < minX ||
                    ny < minY ||
                    nx >= maxX ||
                    ny >= maxY)) ||
                    used[localIndex] ||
                    !gridOps.isThinRoadAttachmentCell(grid, nx, ny, parentTypes))
                  continue;
                used[localIndex] = true;
                result.push({
                  x: nx,
                  y: ny,
                });
              }
          }

#if mydebug
      plan.addMapProfileSample('thin.collectThinRoadAttachments',
        haxe.Timer.stamp() * 1000.0 - startTS);
      plan.addMapProfileCount('thin.collectThinRoadAttachments.resultCount', result.length);
      plan.addMapProfileCount('thin.collectThinRoadAttachments.searchCells',
        (maxX - minX) * (maxY - minY));
#end
      return result;
    }

// find the nearest thin-road parent attachment to one plan cell
  function findNearestThinRoadAttachment(list: Array<GridPoint>, planX: Int, planY: Int): GridPoint
    {
      var best: GridPoint = null;
      var bestDist = 0x3FFFFFFF;

      for (point in list)
        {
          var dist = Std.int(Math.abs(point.x - planX) + Math.abs(point.y - planY));
          if (dist < bestDist)
            {
              bestDist = dist;
              best = point;
            }
        }

      return best;
    }

// find the nearest thin-road parent attachment using tiered target groups when requested
  function findPreferredThinRoadAttachment(grid: RoadPlanGrid, parentTypes: Array<RoadType>,
      targetTypeGroups: Array<Array<RoadType>>, planX: Int, planY: Int,
      searchRect: IntRect = null, cache: ThinAttachmentCache = null): GridPoint
    {
      if (targetTypeGroups != null)
        for (types in targetTypeGroups)
          {
            var target = findNearestThinRoadAttachment(getThinRoadAttachmentList(grid, types,
                searchRect, cache),
              planX, planY);
            if (target != null)
              return target;
          }

      return findNearestThinRoadAttachment(getThinRoadAttachmentList(grid, parentTypes,
          searchRect, cache),
        planX, planY);
    }

// find the nearest thin-road parent attachment on one chosen side
  function findNearestThinRoadAttachmentInDirection(list: Array<GridPoint>,
      planX: Int, planY: Int, dx: Int, dy: Int): GridPoint
    {
      var best: GridPoint = null;
      var bestDist = 0x3FFFFFFF;

      for (point in list)
        {
          var along = (point.x - planX) * dx + (point.y - planY) * dy;
          if (along <= 0)
            continue;

          var dist = Std.int(Math.abs(point.x - planX) + Math.abs(point.y - planY));
          if (dist < bestDist)
            {
              bestDist = dist;
              best = point;
            }
        }

      return best;
    }

// find the nearest thin-road parent attachment on one chosen side using tiered target groups
  function findPreferredThinRoadAttachmentInDirection(grid: RoadPlanGrid,
      parentTypes: Array<RoadType>, targetTypeGroups: Array<Array<RoadType>>,
      planX: Int, planY: Int, dx: Int, dy: Int,
      searchRect: IntRect = null, cache: ThinAttachmentCache = null): GridPoint
    {
      if (targetTypeGroups != null)
        for (types in targetTypeGroups)
          {
            var target = findNearestThinRoadAttachmentInDirection(
              getThinRoadAttachmentList(grid, types, searchRect, cache), planX, planY, dx, dy);
            if (target != null)
              return target;
          }

      return findNearestThinRoadAttachmentInDirection(
        getThinRoadAttachmentList(grid, parentTypes, searchRect, cache), planX, planY, dx, dy);
    }

// find a reasonable thin-road start and initial direction inside one city tile
  function findTileThinRoadStart(grid: RoadPlanGrid, cellX: Int, cellY: Int,
      target: GridPoint, parentTypes: Array<RoadType>, requiredAxisMask: Int = 0): ThinRoadStart
    {
#if mydebug
      var startTS = haxe.Timer.stamp() * 1000.0;
#end
      var tileStartX = cellX * plan.PLAN_CELLS_PER_TILE;
      var tileStartY = cellY * plan.PLAN_CELLS_PER_TILE;
      var tileEndX = tileStartX + plan.PLAN_CELLS_PER_TILE - 1;
      var tileEndY = tileStartY + plan.PLAN_CELLS_PER_TILE - 1;
      var centerX = tileStartX + Std.int(plan.PLAN_CELLS_PER_TILE / 2) - 1;
      var centerY = tileStartY + Std.int(plan.PLAN_CELLS_PER_TILE / 2) - 1;
      var preferredX = plan.clampInt(centerX + plan.randomRangeInt(-2, 2), tileStartX, tileEndX);
      var preferredY = plan.clampInt(centerY + plan.randomRangeInt(-2, 2), tileStartY, tileEndY);
      var targetX = (target != null ? target.x : -1);
      var targetY = (target != null ? target.y : -1);
      var preferredAxisMask = requiredAxisMask;
      if (preferredAxisMask == 0 &&
          target != null)
        preferredAxisMask = getThinRoadPreferredAxisMaskForTarget(grid, target.x, target.y,
          parentTypes);
      var best: ThinRoadStart = null;
      var bestScore = 0x3FFFFFFF;

      for (yy in tileStartY...tileStartY + plan.PLAN_CELLS_PER_TILE)
        for (xx in tileStartX...tileStartX + plan.PLAN_CELLS_PER_TILE)
          {
            if (gridOps.isPlanCellOccupied(grid, xx, yy))
              continue;

            for (dir in 0...4)
              {
                var dx = gridOps.getCardinalDX(dir);
                var dy = gridOps.getCardinalDY(dir);
                var dirAxisMask = gridOps.getRoadAxisMask(dx, dy);
                if (!branchWalker.canUseBranchRoadStart(grid, xx, yy, dx, dy))
                  continue;
                if (preferredAxisMask != 0 &&
                    (preferredAxisMask & dirAxisMask) == 0)
                  continue;
                if (targetX >= 0 &&
                    targetY >= 0 &&
                    xx == targetX &&
                    yy == targetY)
                  continue;

                var parentAway = getThinRoadAwayVector(grid, xx, yy, parentTypes);
                var nextToParent = gridOps.isThinRoadAttachmentCell(grid, xx, yy, parentTypes);
                var awayScore = parentAway.x * dx + parentAway.y * dy;
                if (nextToParent &&
                    (parentAway.x != 0 ||
                    parentAway.y != 0) &&
                    awayScore <= 0)
                  continue;

                var nextX = xx + dx;
                var nextY = yy + dy;
                if (gridOps.hasParallelRoadFlankConflict(grid, xx, yy, dx, dy) ||
                    gridOps.hasParallelRoadFlankConflict(grid, nextX, nextY, dx, dy))
                  continue;
                var score = Std.int(Math.abs(xx - preferredX) + Math.abs(yy - preferredY)) * 4;
                if (targetX >= 0 &&
                    targetY >= 0)
                  score += Std.int(Math.abs(nextX - targetX) + Math.abs(nextY - targetY));
                else
                  score += getThinRoadTileExitDistance(tileStartX, tileStartY,
                    tileEndX, tileEndY, nextX, nextY, dx, dy) * 2;
                if (nextToParent &&
                    awayScore > 0)
                  score -= 6;

                if (score < bestScore)
                  {
                    bestScore = score;
                    best = {
                      x: xx,
                      y: yy,
                      dx: dx,
                      dy: dy,
                    };
                  }
              }
          }

#if mydebug
      plan.addMapProfileSample('thin.findTileThinRoadStart',
        haxe.Timer.stamp() * 1000.0 - startTS);
      if (best != null)
        plan.addMapProfileCount('thin.findTileThinRoadStart.found');
      else
        plan.addMapProfileCount('thin.findTileThinRoadStart.null');
#end
      return best;
    }

// return the net direction pointing away from adjacent parent-road cells
  function getThinRoadAwayVector(grid: RoadPlanGrid, planX: Int, planY: Int,
      parentTypes: Array<RoadType>): GridPoint
    {
      var dx = 0;
      var dy = 0;

      for (dir in 0...4)
        {
          var nx = planX + gridOps.getCardinalDX(dir);
          var ny = planY + gridOps.getCardinalDY(dir);
          if (!gridOps.isInPlanBounds(nx, ny) ||
              !gridOps.hasParentRoadFacingCell(grid, nx, ny, planX, planY, parentTypes))
            continue;
          dx += planX - nx;
          dy += planY - ny;
        }

      return {
        x: dx,
        y: dy,
      };
    }

// return the preferred child axis mask from one chosen parent attachment target
  function getThinRoadPreferredAxisMaskForTarget(grid: RoadPlanGrid, planX: Int, planY: Int,
      parentTypes: Array<RoadType>): Int
    {
      var parentAxisMask = 0;

      for (dir in 0...4)
        {
          var nx = planX + gridOps.getCardinalDX(dir);
          var ny = planY + gridOps.getCardinalDY(dir);
          if (!gridOps.isInPlanBounds(nx, ny))
            continue;
          for (type in parentTypes)
            {
              if (!gridOps.hasRoadTypeFacingCell(grid, nx, ny, planX, planY, type))
                continue;
              parentAxisMask = parentAxisMask |
                gridOps.getRoadTypeAxisMaskAtPlanCell(grid, nx, ny, type);
            }
        }

      return gridOps.getPerpendicularRoadAxisMask(parentAxisMask);
    }

// return the number of steps from one walker step to leave the current tile
  function getThinRoadTileExitDistance(tileStartX: Int, tileStartY: Int,
      tileEndX: Int, tileEndY: Int, nextX: Int, nextY: Int, dx: Int, dy: Int): Int
    {
      if (dx < 0)
        return nextX - tileStartX;
      if (dx > 0)
        return tileEndX - nextX;
      if (dy < 0)
        return nextY - tileStartY;
      return tileEndY - nextY;
    }

// connect one thin-road coverage start to an empty cell beside one parent road
  function connectThinRoadToTarget(grid: RoadPlanGrid, start: ThinRoadStart,
      target: GridPoint, type: RoadType, parentTypes: Array<RoadType>,
      allowOccupiedStart: Bool = false): Bool
    {
#if mydebug
      var startTS = haxe.Timer.stamp() * 1000.0;
#end
      var connected = tryConnectThinRoadToTarget(grid, start, target, type, parentTypes,
          true, allowOccupiedStart) ||
        tryConnectThinRoadToTarget(grid, start, target, type, parentTypes,
          false, allowOccupiedStart);
#if mydebug
      plan.addMapProfileSample('thin.connectThinRoadToTarget.' + Std.string(type),
        haxe.Timer.stamp() * 1000.0 - startTS);
      if (connected)
        plan.addMapProfileCount('thin.connectThinRoadToTarget.' + Std.string(type) + '.success');
      else
        plan.addMapProfileCount('thin.connectThinRoadToTarget.' + Std.string(type) + '.failed');
#end
      return connected;
    }

// try one orthogonal routing order for one thin-road connector
  function tryConnectThinRoadToTarget(grid: RoadPlanGrid, start: ThinRoadStart,
      target: GridPoint, type: RoadType, parentTypes: Array<RoadType>,
      horizontalFirst: Bool, allowOccupiedStart: Bool): Bool
    {
      if ((type == ROAD3 ||
          type == ROAD4 ||
          type == ROAD5) &&
          start.x != target.x &&
          start.y != target.y)
        return false;

      var path = buildThinRoadConnectorPath(start.x, start.y, target.x, target.y, horizontalFirst);
      if (path.length < 2)
        return false;
      if (path[1].x - path[0].x != start.dx ||
          path[1].y - path[0].y != start.dy)
        return false;

      for (i in 0...path.length)
        {
          var point = path[i];
          var axisMask = getThinRoadPathAxisMask(path, i);
          if (gridOps.isPlanCellOccupied(grid, point.x, point.y) &&
              (!allowOccupiedStart ||
              i != 0 ||
              point.x != start.x ||
              point.y != start.y))
            return false;
          if (gridOps.hasParallelRoadFlankConflictForAxisMask(grid, point.x, point.y, axisMask))
            return false;
          if (i < path.length - 1 &&
              gridOps.isThinRoadAttachmentCell(grid, point.x, point.y, parentTypes))
            return false;
        }
      if (!gridOps.isThinRoadAttachmentCell(grid, target.x, target.y, parentTypes))
        return false;

      gridOps.addRoadPlanPath(grid, path, type);
      return true;
    }

// build one orthogonal thin-road connector path between two plan cells
  function buildThinRoadConnectorPath(startX: Int, startY: Int, endX: Int, endY: Int,
      horizontalFirst: Bool): Array<GridPoint>
    {
      var out = [];
      var x = startX;
      var y = startY;

      out.push({
        x: x,
        y: y,
      });

      if (horizontalFirst)
        {
          while (x != endX)
            {
              x += (endX > x ? 1 : -1);
              out.push({
                x: x,
                y: y,
              });
            }
          while (y != endY)
            {
              y += (endY > y ? 1 : -1);
              out.push({
                x: x,
                y: y,
              });
            }
          return out;
        }

      while (y != endY)
        {
          y += (endY > y ? 1 : -1);
          out.push({
            x: x,
            y: y,
          });
        }
      while (x != endX)
        {
          x += (endX > x ? 1 : -1);
          out.push({
            x: x,
            y: y,
          });
        }
      return out;
    }

// return the axis mask one thin-road connector path paints at one path cell
  function getThinRoadPathAxisMask(path: Array<GridPoint>, index: Int): Int
    {
      if (path.length <= 1)
        return 0;
      if (index <= 0)
        return gridOps.getRoadAxisMask(path[1].x - path[0].x, path[1].y - path[0].y);
      if (index >= path.length - 1)
        return gridOps.getRoadAxisMask(path[index].x - path[index - 1].x,
          path[index].y - path[index - 1].y);

      var mask = gridOps.getRoadAxisMask(path[index].x - path[index - 1].x,
        path[index].y - path[index - 1].y);
      return mask | gridOps.getRoadAxisMask(path[index + 1].x - path[index].x,
        path[index + 1].y - path[index].y);
    }
}
