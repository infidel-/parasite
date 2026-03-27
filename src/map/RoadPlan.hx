// active ROAD1/ROAD2 plan-grid generator and connector logic

package map;

import map.RoadType;
import map.Types.GridPoint;
import map.Types.Road2Attachment;
import map.Types.Road2Component;
import map.Types.Road2Connector;
import map.Types.RoadBranchStart;
import map.Types.RoadPlanGrid;
import map.Types.RoadSegment;
import map.Types.RoadWalker;

class RoadPlan extends Raster
{
  function generateRoadGraph(): Array<RoadSegment>
    {
      var grid = makeRoadPlanGrid();
      var primaryHorizontal = rng.nextFloat() < 0.5;
      var primaryLine = pickCenteredRoad1Line(primaryHorizontal);
      var primaryWalker = makePrimaryRoad1Walker(primaryHorizontal, primaryLine);
      var sideWalker = makeSideRoad1Walker(primaryHorizontal, primaryLine);

      walkRoad1(grid, cloneRoadWalker(primaryWalker));
      walkRoad1(grid, cloneRoadWalker(sideWalker));
      spawnRoad2AlongRoad1(grid, cloneRoadWalker(primaryWalker));
      spawnRoad2AlongRoad1(grid, cloneRoadWalker(sideWalker));
      ensureRoad2Connectivity(grid);
      ensureCityRoad2Coverage(grid);
      ensureRoad2Connectivity(grid);

      return compressRoadPlanGrid(grid);
    }

// allocate the working road occupancy grid
  function makeRoadPlanGrid(): RoadPlanGrid
    {
      var horizontal = makeIntGrid(planWidth, planHeight);
      var vertical = makeIntGrid(planWidth, planHeight);
      var cornerOrder = makeIntGrid(planWidth, planHeight);
      var cornerMask = makeIntGrid(planWidth, planHeight);
      var road1Cells = makeBoolGrid(planWidth, planHeight);
      var road2Cells = makeBoolGrid(planWidth, planHeight);
      var road2IDs = makeIntGrid(planWidth, planHeight);

      for (xx in 0...planWidth)
        for (yy in 0...planHeight)
          {
            horizontal[xx][yy] = -1;
            vertical[xx][yy] = -1;
            cornerOrder[xx][yy] = -1;
            cornerMask[xx][yy] = 0;
            road1Cells[xx][yy] = false;
            road2Cells[xx][yy] = false;
            road2IDs[xx][yy] = -1;
          }

      return {
        width: planWidth,
        height: planHeight,
        horizontal: horizontal,
        vertical: vertical,
        cornerOrder: cornerOrder,
        cornerMask: cornerMask,
        road1Cells: road1Cells,
        road2Cells: road2Cells,
        road2IDs: road2IDs,
      };
    }

// return a centered ROAD1 line with deterministic jitter
  function pickCenteredRoad1Line(horizontal: Bool): Int
    {
      var limit = (horizontal ? planHeight : planWidth);
      var jitter = clampInt(Std.int(limit / 10), 4, PLAN_CELLS_PER_TILE * 2);
      return clampInt(Std.int(limit / 2) + randomRangeInt(-jitter, jitter),
        1, limit - 2);
    }

// return a centered ROAD1 branch coordinate with jitter
  function pickCenteredRoad1Branch(horizontal: Bool): Int
    {
      var limit = (horizontal ? planWidth : planHeight);
      var jitter = clampInt(Std.int(limit / 12), 3, PLAN_CELLS_PER_TILE * 2);
      return clampInt(Std.int(limit / 2) + randomRangeInt(-jitter, jitter),
        1, limit - 2);
    }

// build the primary ROAD1 walker configuration
  function makePrimaryRoad1Walker(primaryHorizontal: Bool, primaryLine: Int): RoadWalker
    {
      if (primaryHorizontal)
        {
          return {
            x: 0,
            y: primaryLine,
            dx: 1,
            dy: 0,
            originX: 0,
            originY: primaryLine,
            horizontalSign: 1,
            verticalSign: 0,
            stepsSinceTurn: 0,
            stopLockSteps: 0,
            road2ID: -1,
            type: ROAD1,
          };
        }

      return {
        x: primaryLine,
        y: 0,
        dx: 0,
        dy: 1,
        originX: primaryLine,
        originY: 0,
        horizontalSign: 0,
        verticalSign: 1,
        stepsSinceTurn: 0,
        stopLockSteps: 0,
        road2ID: -1,
        type: ROAD1,
      };
    }

// build the side ROAD1 walker configuration
  function makeSideRoad1Walker(primaryHorizontal: Bool, primaryLine: Int): RoadWalker
    {
      if (primaryHorizontal)
        {
          var branchX = pickCenteredRoad1Branch(true);
          var branchDy = (rng.nextFloat() < 0.5 ? -1 : 1);
          return {
            x: branchX,
            y: primaryLine,
            dx: 0,
            dy: branchDy,
            originX: branchX,
            originY: primaryLine,
            horizontalSign: 0,
            verticalSign: branchDy,
            stepsSinceTurn: 0,
            stopLockSteps: 0,
            road2ID: -1,
            type: ROAD1,
          };
        }

      var branchY = pickCenteredRoad1Branch(false);
      var branchDx = (rng.nextFloat() < 0.5 ? -1 : 1);
      return {
        x: primaryLine,
        y: branchY,
        dx: branchDx,
        dy: 0,
        originX: primaryLine,
        originY: branchY,
        horizontalSign: branchDx,
        verticalSign: 0,
        stepsSinceTurn: 0,
        stopLockSteps: 0,
        road2ID: -1,
        type: ROAD1,
      };
    }

// clone one walker config before consuming it
  function cloneRoadWalker(walker: RoadWalker): RoadWalker
    {
      return {
        x: walker.x,
        y: walker.y,
        dx: walker.dx,
        dy: walker.dy,
        originX: walker.originX,
        originY: walker.originY,
        horizontalSign: walker.horizontalSign,
        verticalSign: walker.verticalSign,
        stepsSinceTurn: walker.stepsSinceTurn,
        stopLockSteps: walker.stopLockSteps,
        road2ID: walker.road2ID,
        type: walker.type,
      };
    }

// walk one straight ROAD1 trunk without spawning branches
  function walkRoad1(grid: RoadPlanGrid, walker: RoadWalker)
    {
      while (isInPlanBounds(walker.x, walker.y))
        {
          addRoadPlanAxis(grid, walker.x, walker.y, walker.dx, walker.dy, walker.type);
          walker.x += walker.dx;
          walker.y += walker.dy;
        }
    }

// spawn ROAD2 branches along one already-built ROAD1 trunk
  function spawnRoad2AlongRoad1(grid: RoadPlanGrid, walker: RoadWalker)
    {
      var stepIndex = 0;

      while (isInPlanBounds(walker.x, walker.y))
        {
          if (stepIndex > 0 &&
              stepIndex % ROAD2_MIN_SPAWN_GAP == 0)
            trySpawnRoad2Branches(grid, walker);
          walker.x += walker.dx;
          walker.y += walker.dy;
          stepIndex++;
        }
    }

// connect detached orange components back to the road network
  function ensureRoad2Connectivity(grid: RoadPlanGrid)
    {
      var tries = 0;

      while (tries < 64)
        {
          var components = buildRoad2Components(grid);
          var pending: Road2Component = null;

          for (component in components)
            if (!component.touchesRoad1)
              {
                pending = component;
                break;
              }

          if (pending == null)
            return;

          var connector = findRoad2ComponentConnector(grid, pending);
          if (connector == null)
            return;
          if (!connectRoad2Connector(grid, connector.start, connector.target, true))
            return;
          tries++;
        }
    }

// add a second orange coverage pass over city tiles
  function ensureCityRoad2Coverage(grid: RoadPlanGrid)
    {
      var road2Attachments = collectRoad2Attachments(grid);
      var road1Attachments = collectRoad1Attachments(grid);

      for (cellY in 0...fullCellHeight)
        for (cellX in 0...fullCellWidth)
          {
            if (!isCityAreaType(areaTypes[cellX][cellY]))
              continue;

            if (hasRoad2InRegionTile(grid, cellX, cellY))
              continue;

            var start = findTileRoad2Start(grid, cellX, cellY);
            if (start == null)
              continue;

            var target = findNearestRoad2Attachment(road2Attachments, start.x, start.y);
            var connected = false;
            if (target != null)
              connected = connectRoad2Connector(grid, {
                x: start.x,
                y: start.y,
                road2ID: target.road2ID,
                road1StepX: -1,
                road1StepY: -1,
                road1DX: 0,
                road1DY: 0,
              }, target, false);

            if (!connected)
              {
                var road1Target = findNearestRoad1Attachment(road1Attachments, start.x, start.y);
                if (road1Target != null)
                  connected = connectRoad2Connector(grid, {
                    x: start.x,
                    y: start.y,
                    road2ID: nextRoad2ID++,
                    road1StepX: -1,
                    road1StepY: -1,
                    road1DX: 0,
                    road1DY: 0,
                  }, road1Target, false);
              }

            if (connected)
              {
                road2Attachments = collectRoad2Attachments(grid);
                road1Attachments = collectRoad1Attachments(grid);
              }
          }
    }

// collect connected orange components from the plan grid
  function buildRoad2Components(grid: RoadPlanGrid): Array<Road2Component>
    {
      var visited = makeBoolGrid(planWidth, planHeight);
      var result = [];

      for (xx in 0...planWidth)
        for (yy in 0...planHeight)
          {
            if (visited[xx][yy] ||
                !grid.road2Cells[xx][yy])
              continue;

            var queue = [{
              x: xx,
              y: yy,
            }];
            var cells = [];
            var index = 0;
            var touchesRoad1 = false;

            visited[xx][yy] = true;

            while (index < queue.length)
              {
                var point = queue[index++];
                cells.push(point);
                if (hasAdjacentRoad1Cell(grid, point.x, point.y))
                  touchesRoad1 = true;

                for (dir in 0...4)
                  {
                    var nx = point.x + getCardinalDX(dir);
                    var ny = point.y + getCardinalDY(dir);
                    if (!isInPlanBounds(nx, ny) ||
                        visited[nx][ny] ||
                        !grid.road2Cells[nx][ny])
                      continue;
                    visited[nx][ny] = true;
                    queue.push({
                      x: nx,
                      y: ny,
                    });
                  }
              }

            result.push({
              cells: cells,
              touchesRoad1: touchesRoad1,
            });
          }

      return result;
    }

// find the closest empty connector cell from one orange component to ROAD1
  function findRoad2ComponentConnector(grid: RoadPlanGrid, component: Road2Component): Road2Connector
    {
      var road1Attachments = collectRoad1Attachments(grid);
      var best: Road2Connector = null;
      var bestDist = 0x3FFFFFFF;

      if (road1Attachments.length == 0)
        return null;

      for (cell in component.cells)
        {
          var road2ID = grid.road2IDs[cell.x][cell.y];
          for (dir in 0...4)
            {
              var startX = cell.x + getCardinalDX(dir);
              var startY = cell.y + getCardinalDY(dir);
              if (!isInPlanBounds(startX, startY) ||
                  isPlanCellOccupied(grid, startX, startY))
                continue;

              var target = findNearestRoad1Attachment(road1Attachments, startX, startY);
              if (target == null)
                continue;

              var dist = Std.int(Math.abs(startX - target.x) + Math.abs(startY - target.y));
              if (dist < bestDist)
                {
                  bestDist = dist;
                  best = {
                    start: {
                      x: startX,
                      y: startY,
                      road2ID: road2ID,
                      road1StepX: -1,
                      road1StepY: -1,
                      road1DX: 0,
                      road1DY: 0,
                    },
                    target: target,
                  };
                }
            }
        }

      return best;
    }

// connect one orange start to one target attachment point
  function connectRoad2Connector(grid: RoadPlanGrid, start: Road2Attachment,
      target: Road2Attachment, allowTargetRoad1: Bool): Bool
    {
      return tryConnectRoad2Connector(grid, start, target, true, allowTargetRoad1) ||
        tryConnectRoad2Connector(grid, start, target, false, allowTargetRoad1);
    }

// try one orthogonal connector routing order for orange coverage
  function tryConnectRoad2Connector(grid: RoadPlanGrid, start: Road2Attachment,
      target: Road2Attachment, horizontalFirst: Bool, allowTargetRoad1: Bool): Bool
    {
      var path = buildRoad2ConnectorPath(start.x, start.y, target.x, target.y, horizontalFirst);
      if (path.length == 0)
        return false;

      for (i in 0...path.length)
        {
          var point = path[i];
          var ignoreX = (i > 0 ? path[i - 1].x : -1);
          var ignoreY = (i > 0 ? path[i - 1].y : -1);
          var isTarget = i == path.length - 1;
          if (!canStampRoad2ConnectorCell(grid, point.x, point.y, start.road2ID,
              ignoreX, ignoreY, isTarget, target, allowTargetRoad1))
            return false;
        }

      for (point in path)
        addRoad2PlanStamp(grid, point.x, point.y, start.road2ID);
      if (target.road1StepX >= 0)
        addRoad2Road1Bridge(grid, target.road1StepX, target.road1StepY,
          target.x, target.y, target.road1DX, target.road1DY, start.road2ID);
      return true;
    }

// build one orthogonal connector path between two plan cells
  function buildRoad2ConnectorPath(startX: Int, startY: Int, endX: Int, endY: Int,
      horizontalFirst: Bool): Array<GridPoint>
    {
      var start = snapRoad2Anchor(startX, startY);
      var target = snapRoad2Anchor(endX, endY);
      var out = [];
      var x = start.x;
      var y = start.y;

      out.push({
        x: x,
        y: y,
      });

      if (horizontalFirst)
        {
          while (x != target.x)
            {
              x += (target.x > x ? ROAD2_GRID_STEP : -ROAD2_GRID_STEP);
              out.push({
                x: x,
                y: y,
              });
            }
          while (y != target.y)
            {
              y += (target.y > y ? ROAD2_GRID_STEP : -ROAD2_GRID_STEP);
              out.push({
                x: x,
                y: y,
              });
            }
          return out;
        }

      while (y != target.y)
        {
          y += (target.y > y ? ROAD2_GRID_STEP : -ROAD2_GRID_STEP);
          out.push({
            x: x,
            y: y,
          });
        }
      while (x != target.x)
        {
          x += (target.x > x ? ROAD2_GRID_STEP : -ROAD2_GRID_STEP);
          out.push({
            x: x,
            y: y,
          });
        }
      return out;
    }

// return whether one connector cell can be stamped safely
  function canStampRoad2ConnectorCell(grid: RoadPlanGrid, planX: Int, planY: Int,
      road2ID: Int, ignoreStampX: Int = -1, ignoreStampY: Int = -1,
      isTarget: Bool = false, target: Road2Attachment = null, allowRoad1Touch: Bool = false): Bool
    {
      if (!isInPlanBounds(planX, planY))
        return false;
      if (isTarget &&
          target != null &&
          planX == target.x &&
          planY == target.y)
        return target.road1StepX < 0 ||
          canBuildRoad2Road1Bridge(grid, target.road1StepX, target.road1StepY,
            planX, planY, target.road1DX, target.road1DY, road2ID);
      if (!isCityAreaType(getAreaTypeAtPlanCell(planX, planY)) &&
          !(allowRoad1Touch && isRoad1AttachmentCell(grid, planX, planY)) &&
          !isRoad2AttachmentCell(grid, planX, planY))
        return false;
      if (doesRoad2FootprintHitAnyRoad(grid, planX, planY, ignoreStampX, ignoreStampY))
        return false;
      return !hasRoad2ClearanceConflict(grid, planX, planY, road2ID);
    }

// return whether one ROAD1 to ROAD2 bridge strip is clear to stamp
  function canBuildRoad2Road1Bridge(grid: RoadPlanGrid, baseX: Int, baseY: Int,
      planX: Int, planY: Int, dx: Int, dy: Int, road2ID: Int = -1): Bool
    {
      var startX = planX;
      var endX = planX - 1;
      var startY = planY;
      var endY = planY - 1;

      if (dx < 0)
        {
          startX = planX + 2;
          endX = baseX - 2;
          startY = planY;
          endY = planY + 1;
        }
      else if (dx > 0)
        {
          startX = baseX + 2;
          endX = planX - 1;
          startY = planY;
          endY = planY + 1;
        }
      else if (dy < 0)
        {
          startX = planX;
          endX = planX + 1;
          startY = planY + 2;
          endY = baseY - 2;
        }
      else if (dy > 0)
        {
          startX = planX;
          endX = planX + 1;
          startY = baseY + 2;
          endY = planY - 1;
        }

      if (startX > endX ||
          startY > endY)
        return true;

      for (yy in startY...endY + 1)
        for (xx in startX...endX + 1)
          {
            if (!isInPlanBounds(xx, yy) ||
                grid.road1Cells[xx][yy])
              return false;

            var existingRoad2ID = getRoad2IDAt(grid, xx, yy);
            if (existingRoad2ID >= 0 &&
                existingRoad2ID != road2ID)
              return false;
            if (existingRoad2ID < 0 &&
                (grid.horizontal[xx][yy] >= 0 ||
                grid.vertical[xx][yy] >= 0 ||
                grid.cornerOrder[xx][yy] >= 0))
              return false;
          }

      return true;
    }

// stamp one ROAD1 to ROAD2 bridge strip so the start touches the trunk
  function addRoad2Road1Bridge(grid: RoadPlanGrid, baseX: Int, baseY: Int,
      planX: Int, planY: Int, dx: Int, dy: Int, road2ID: Int)
    {
      var startX = planX;
      var endX = planX - 1;
      var startY = planY;
      var endY = planY - 1;

      if (dx < 0)
        {
          startX = planX + 2;
          endX = baseX - 2;
          startY = planY;
          endY = planY + 1;
        }
      else if (dx > 0)
        {
          startX = baseX + 2;
          endX = planX - 1;
          startY = planY;
          endY = planY + 1;
        }
      else if (dy < 0)
        {
          startX = planX;
          endX = planX + 1;
          startY = planY + 2;
          endY = baseY - 2;
        }
      else if (dy > 0)
        {
          startX = planX;
          endX = planX + 1;
          startY = baseY + 2;
          endY = planY - 1;
        }

      if (startX > endX ||
          startY > endY)
        return;

      for (yy in startY...endY + 1)
        for (xx in startX...endX + 1)
          {
            grid.road2Cells[xx][yy] = true;
            grid.road2IDs[xx][yy] = road2ID;
          }
    }

// collect all occupied orange plan cells
  function collectRoad2Cells(grid: RoadPlanGrid): Array<GridPoint>
    {
      var result = [];

      for (xx in 0...planWidth)
        for (yy in 0...planHeight)
          if (grid.road2Cells[xx][yy])
            result.push({
              x: xx,
              y: yy,
            });

      return result;
    }

// collect all empty cells that can attach to orange roads
  function collectRoad2Attachments(grid: RoadPlanGrid): Array<Road2Attachment>
    {
      var result = [];

      for (xx in 0...planWidth)
        {
          if ((xx & 1) != 0)
            continue;
          for (yy in 0...planHeight)
          {
            if ((yy & 1) != 0)
              continue;
            var road2ID = getAdjacentRoad2AttachmentID(grid, xx, yy);
            if (isPlanCellOccupied(grid, xx, yy) ||
                road2ID < 0)
              continue;
            result.push({
              x: xx,
              y: yy,
              road2ID: road2ID,
              road1StepX: -1,
              road1StepY: -1,
              road1DX: 0,
              road1DY: 0,
            });
          }
        }

      return result;
    }

// collect all lane-aligned empty cells that can attach to ROAD1
  function collectRoad1Attachments(grid: RoadPlanGrid): Array<Road2Attachment>
    {
      var result = [];
      var used = makeBoolGrid(planWidth, planHeight);
      var road1Order = getRoadTypeOrder(ROAD1);

      for (xx in 0...planWidth)
        for (yy in 0...planHeight)
          {
            if (grid.horizontal[xx][yy] == road1Order)
              {
                addRoad1AttachmentCandidate(result, used, grid, xx, yy, 0, -1);
                addRoad1AttachmentCandidate(result, used, grid, xx, yy, 0, 1);
              }
            if (grid.vertical[xx][yy] == road1Order)
              {
                addRoad1AttachmentCandidate(result, used, grid, xx, yy, -1, 0);
                addRoad1AttachmentCandidate(result, used, grid, xx, yy, 1, 0);
              }
          }

      return result;
    }

// add one canonical ROAD1 to ROAD2 anchor candidate
  function addRoad1AttachmentCandidate(out: Array<Road2Attachment>, used: Array<Array<Bool>>,
      grid: RoadPlanGrid, baseX: Int, baseY: Int, dx: Int, dy: Int)
    {
      var anchor = getRoad2AnchorFromRoad1Step(baseX, baseY, dx, dy);
      if (anchor == null ||
          used[anchor.x][anchor.y] ||
          !canUseRoad2Anchor(grid, baseX, baseY, anchor.x, anchor.y, dx, dy))
        return;

      used[anchor.x][anchor.y] = true;
      out.push({
        x: anchor.x,
        y: anchor.y,
        road2ID: -1,
        road1StepX: baseX,
        road1StepY: baseY,
        road1DX: dx,
        road1DY: dy,
      });
    }

// return the canonical orange anchor for one ROAD1 step and branch side
  function getRoad2AnchorFromRoad1Step(baseX: Int, baseY: Int, dx: Int, dy: Int): GridPoint
    {
      var planX = floorEven(baseX);
      var planY = floorEven(baseY);

      if (dx < 0)
        planX = floorEven(baseX - 3);
      else if (dx > 0)
        planX = ceilEven(baseX + 2);

      if (dy < 0)
        planY = floorEven(baseY - 3);
      else if (dy > 0)
        planY = ceilEven(baseY + 2);

      if (!isInPlanBounds(planX, planY) ||
          !isInPlanBounds(planX + 1, planY + 1))
        return null;

      return {
        x: planX,
        y: planY,
      };
    }

// return whether one canonical orange anchor is usable as a connector target
  function canUseRoad2Anchor(grid: RoadPlanGrid, baseX: Int, baseY: Int,
      planX: Int, planY: Int, dx: Int, dy: Int): Bool
    {
      return !isPlanCellOccupied(grid, planX, planY) &&
        !doesRoad2FootprintHitAnyRoad(grid, planX, planY) &&
        !hasRoad2ClearanceConflict(grid, planX, planY, -1) &&
        canBuildRoad2Road1Bridge(grid, baseX, baseY, planX, planY, dx, dy) &&
        canRoad2AdvanceFromStart(grid, planX, planY, dx, dy, -1);
    }

// find the nearest orange attachment to one plan cell
  function findNearestRoad2Attachment(list: Array<Road2Attachment>, planX: Int, planY: Int): Road2Attachment
    {
      var best: Road2Attachment = null;
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

// find the nearest ROAD1 attachment to one plan cell
  function findNearestRoad1Attachment(list: Array<Road2Attachment>, planX: Int, planY: Int): Road2Attachment
    {
      var best: Road2Attachment = null;
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

// find the nearest orange road distance to one plan cell
  function findNearestRoad2Distance(list: Array<GridPoint>, planX: Int, planY: Int): Int
    {
      var best = 0x3FFFFFFF;

      for (point in list)
        {
          var dist = Std.int(Math.abs(point.x - planX) + Math.abs(point.y - planY));
          if (dist < best)
            best = dist;
        }

      return best;
    }

// find a reasonable empty orange start inside one city tile
  function findTileRoad2Start(grid: RoadPlanGrid, cellX: Int, cellY: Int): GridPoint
    {
      var tileStartX = cellX * PLAN_CELLS_PER_TILE;
      var tileStartY = cellY * PLAN_CELLS_PER_TILE;
      var centerX = tileStartX + Std.int(PLAN_CELLS_PER_TILE / 2) - 1;
      var centerY = tileStartY + Std.int(PLAN_CELLS_PER_TILE / 2) - 1;
      var best: GridPoint = null;
      var bestDist = 0x3FFFFFFF;

      for (yy in tileStartY...tileStartY + PLAN_CELLS_PER_TILE)
        {
          if ((yy & 1) != 0)
            continue;
          for (xx in tileStartX...tileStartX + PLAN_CELLS_PER_TILE)
          {
            if ((xx & 1) != 0)
              continue;
            if (isPlanCellOccupied(grid, xx, yy) ||
                doesRoad2FootprintHitAnyRoad(grid, xx, yy) ||
                hasRoad2ClearanceConflict(grid, xx, yy, -1))
              continue;

            var dist = Std.int(Math.abs(xx - centerX) + Math.abs(yy - centerY));
            if (dist < bestDist)
              {
                bestDist = dist;
                best = {
                  x: xx,
                  y: yy,
                };
              }
          }
        }

      return best;
    }

// return whether one visible region tile already contains orange road cells
  function hasRoad2InRegionTile(grid: RoadPlanGrid, cellX: Int, cellY: Int): Bool
    {
      var startX = cellX * PLAN_CELLS_PER_TILE;
      var startY = cellY * PLAN_CELLS_PER_TILE;

      for (yy in startY...startY + PLAN_CELLS_PER_TILE)
        for (xx in startX...startX + PLAN_CELLS_PER_TILE)
          if (grid.road2Cells[xx][yy])
            return true;

      return false;
    }

// return whether one empty cell touches ROAD1
  function isRoad1AttachmentCell(grid: RoadPlanGrid, planX: Int, planY: Int): Bool
    {
      var road1Order = getRoadTypeOrder(ROAD1);

      for (yy in clampInt(planY - 3, 0, planHeight - 1)...clampInt(planY + 4, 0, planHeight))
        for (xx in clampInt(planX - 3, 0, planWidth - 1)...clampInt(planX + 4, 0, planWidth))
          {
            if (grid.horizontal[xx][yy] == road1Order)
              {
                var up = getRoad2AnchorFromRoad1Step(xx, yy, 0, -1);
                var down = getRoad2AnchorFromRoad1Step(xx, yy, 0, 1);
                if ((up != null && up.x == planX && up.y == planY) ||
                    (down != null && down.x == planX && down.y == planY))
                  return true;
              }
            if (grid.vertical[xx][yy] == road1Order)
              {
                var left = getRoad2AnchorFromRoad1Step(xx, yy, -1, 0);
                var right = getRoad2AnchorFromRoad1Step(xx, yy, 1, 0);
                if ((left != null && left.x == planX && left.y == planY) ||
                    (right != null && right.x == planX && right.y == planY))
                  return true;
              }
          }
      return false;
    }

// return whether one empty cell touches ROAD2 on a clean outer edge
  function isRoad2AttachmentCell(grid: RoadPlanGrid, planX: Int, planY: Int): Bool
    {
      return getAdjacentRoad2AttachmentID(grid, planX, planY) >= 0;
    }

// return whether one plan cell is adjacent to a ROAD1 footprint
  function hasAdjacentRoad1Cell(grid: RoadPlanGrid, planX: Int, planY: Int): Bool
    {
      for (dir in 0...4)
        {
          var nx = planX + getCardinalDX(dir);
          var ny = planY + getCardinalDY(dir);
          if (isInPlanBounds(nx, ny) &&
              grid.road1Cells[nx][ny])
            return true;
        }
      return false;
    }

// return the lane-aligned adjacent orange corridor ID for one empty cell
  function getAdjacentRoad2AttachmentID(grid: RoadPlanGrid, planX: Int, planY: Int): Int
    {
      if (!isRoad2AnchorAligned(planX, planY))
        return -1;

      var left = getRoad2AnchorID(grid, planX - ROAD2_GRID_STEP, planY);
      var right = getRoad2AnchorID(grid, planX + ROAD2_GRID_STEP, planY);
      var up = getRoad2AnchorID(grid, planX, planY - ROAD2_GRID_STEP);
      var down = getRoad2AnchorID(grid, planX, planY + ROAD2_GRID_STEP);

      var horizontalCount = (left >= 0 ? 1 : 0) + (right >= 0 ? 1 : 0);
      var verticalCount = (up >= 0 ? 1 : 0) + (down >= 0 ? 1 : 0);

      if (horizontalCount > 0 &&
          verticalCount > 0)
        return -1;
      if (horizontalCount > 1 ||
          verticalCount > 1)
        return -1;
      if (left >= 0)
        return left;
      if (right >= 0)
        return right;
      if (up >= 0)
        return up;
      if (down >= 0)
        return down;
      return -1;
    }

// return one orange corridor ID at one canonical 2x2 anchor or -1 if absent
  function getRoad2AnchorID(grid: RoadPlanGrid, planX: Int, planY: Int): Int
    {
      if (!isRoad2AnchorAligned(planX, planY) ||
          !isInPlanBounds(planX, planY) ||
          !isInPlanBounds(planX + 1, planY + 1))
        return -1;

      var road2ID = grid.road2IDs[planX][planY];
      if (road2ID < 0)
        return -1;
      if (grid.road2IDs[planX + 1][planY] != road2ID ||
          grid.road2IDs[planX][planY + 1] != road2ID ||
          grid.road2IDs[planX + 1][planY + 1] != road2ID)
        return -1;
      return road2ID;
    }

// return one orange corridor ID at a plan cell or -1 if absent
  function getRoad2IDAt(grid: RoadPlanGrid, planX: Int, planY: Int): Int
    {
      if (!isInPlanBounds(planX, planY))
        return -1;
      return grid.road2IDs[planX][planY];
    }

// return whether one orange anchor is aligned to the 2x2 lattice
  function isRoad2AnchorAligned(planX: Int, planY: Int): Bool
    {
      return (planX & 1) == 0 &&
        (planY & 1) == 0;
    }

// snap one orange anchor onto the 2x2 lattice
  function snapRoad2Anchor(planX: Int, planY: Int): GridPoint
    {
      return {
        x: clampInt(planX & ~1, 0, planWidth - 2),
        y: clampInt(planY & ~1, 0, planHeight - 2),
      };
    }

// return the nearest even plan coordinate at or below one value
  function floorEven(value: Int): Int
    {
      return value & ~1;
    }

// return the nearest even plan coordinate at or above one value
  function ceilEven(value: Int): Int
    {
      return ((value & 1) == 0 ? value : value + 1);
    }

// return the x delta for one cardinal direction index
  function getCardinalDX(index: Int): Int
    {
      return switch (index) {
        case 0: -1;
        case 1: 1;
        default: 0;
      };
    }

// return the y delta for one cardinal direction index
  function getCardinalDY(index: Int): Int
    {
      return switch (index) {
        case 2: -1;
        case 3: 1;
        default: 0;
      };
    }

// try spawning ROAD2 branches on both sides of one ROAD1 step
  function trySpawnRoad2Branches(grid: RoadPlanGrid, walker: RoadWalker): Bool
    {
      var starts: Array<RoadBranchStart> = [];

      if (walker.dx != 0)
        {
          addRoad2BranchStart(starts, grid, walker, 0, -1);
          addRoad2BranchStart(starts, grid, walker, 0, 1);
        }
      else
        {
          addRoad2BranchStart(starts, grid, walker, -1, 0);
          addRoad2BranchStart(starts, grid, walker, 1, 0);
        }

      if (starts.length == 0)
        return false;

      var maxChance = 0.0;
      for (entry in starts)
        maxChance = Math.max(maxChance, entry.chance);
      if (rng.nextFloat() >= maxChance)
        return false;

      if (starts.length >= 2 &&
          rng.nextFloat() < 0.70)
        {
          for (entry in starts)
            spawnRoad2Branch(grid, entry.start, entry.dx, entry.dy,
              entry.road1StartX, entry.road1StartY, entry.road1StepX, entry.road1StepY);
          return true;
        }

      var chosen = starts[0];
      if (starts.length > 1)
        {
          var totalChance = 0.0;
          for (entry in starts)
            totalChance += entry.chance;
          var pick = rng.nextFloat() * totalChance;
          for (entry in starts)
            {
              pick -= entry.chance;
              if (pick <= 0.0)
                {
                  chosen = entry;
                  break;
                }
            }
        }

      spawnRoad2Branch(grid, chosen.start, chosen.dx, chosen.dy,
        chosen.road1StartX, chosen.road1StartY, chosen.road1StepX, chosen.road1StepY);
      return true;
    }

// collect one valid ROAD2 branch start from a ROAD1 step
  function addRoad2BranchStart(starts: Array<RoadBranchStart>,
      grid: RoadPlanGrid, walker: RoadWalker,
      branchDx: Int, branchDy: Int)
    {
      var start = findBranchStartCell(grid, walker.x, walker.y, branchDx, branchDy, ROAD2,
        walker.originX, walker.originY);
      if (start == null)
        return;
      if (!isCityAreaType(getAreaTypeAtPlanCell(start.x, start.y)))
        return;
      starts.push({
        start: start,
        dx: branchDx,
        dy: branchDy,
        chance: getRoad2BranchChance(start.x, start.y),
        road1StartX: walker.originX,
        road1StartY: walker.originY,
        road1StepX: walker.x,
        road1StepY: walker.y,
      });
    }

// spawn one ROAD2 branch from a prepared branch start
  function spawnRoad2Branch(grid: RoadPlanGrid, start: GridPoint,
      branchDx: Int, branchDy: Int, road1StartX: Int, road1StartY: Int,
      road1StepX: Int, road1StepY: Int)
    {
      start = snapRoad2Anchor(start.x, start.y);
      if (!canUseRoad2Start(grid, start.x, start.y, branchDx, branchDy, road1StartX, road1StartY) ||
          !canBuildRoad2Road1Bridge(grid, road1StepX, road1StepY, start.x, start.y, branchDx, branchDy))
        return;

      var road2ID = nextRoad2ID++;
      addRoad2Road1Bridge(grid, road1StepX, road1StepY, start.x, start.y, branchDx, branchDy, road2ID);
      walkBranchRoad(grid, {
        x: start.x,
        y: start.y,
        dx: branchDx,
        dy: branchDy,
        originX: start.x,
        originY: start.y,
        horizontalSign: (branchDx != 0 ? branchDx : 0),
        verticalSign: (branchDy != 0 ? branchDy : 0),
        stepsSinceTurn: 0,
        stopLockSteps: 0,
        road2ID: road2ID,
        type: ROAD2,
      });
    }

// find the first free branch start cell to one side of a ROAD1 step
  function findBranchStartCell(grid: RoadPlanGrid, baseX: Int, baseY: Int,
      dx: Int, dy: Int, type: RoadType,
      road1StartX: Int = -1, road1StartY: Int = -1): GridPoint
    {
      var planX = 0;
      var planY = 0;
      if (type == ROAD2)
        {
          var anchor = getRoad2AnchorFromRoad1Step(baseX, baseY, dx, dy);
          if (anchor == null)
            return null;
          planX = anchor.x;
          planY = anchor.y;
        }
      else
        {
          var clearance = getRoadBranchRootClearance(type);
          planX = baseX + dx * clearance;
          planY = baseY + dy * clearance;
        }

      while (isInPlanBounds(planX, planY))
        {
          if (canUseRoad2Start(grid, planX, planY, dx, dy, road1StartX, road1StartY) &&
              (type != ROAD2 ||
              canBuildRoad2Road1Bridge(grid, baseX, baseY, planX, planY, dx, dy)))
            {
              return {
                x: planX,
                y: planY,
              };
            }
          if (type == ROAD2)
            {
              planX += dx * ROAD2_GRID_STEP;
              planY += dy * ROAD2_GRID_STEP;
            }
          else
            {
              planX += dx;
              planY += dy;
            }
        }

      return null;
    }

// return whether one ROAD2 branch start is still legal on the current grid
  function canUseRoad2Start(grid: RoadPlanGrid, planX: Int, planY: Int,
      dx: Int, dy: Int, road1StartX: Int, road1StartY: Int, road2ID: Int = -1): Bool
    {
      return isRoad2AnchorAligned(planX, planY) &&
        !isPlanCellOccupied(grid, planX, planY) &&
        !doesRoad2FootprintHitAnyRoad(grid, planX, planY) &&
        !isNearRoad1StartTile(planX, planY, road1StartX, road1StartY) &&
        !hasRoad2ClearanceConflict(grid, planX, planY, road2ID) &&
        canRoad2AdvanceFromStart(grid, planX, planY, dx, dy, road2ID);
    }

// return whether one plan cell falls in the same or adjacent region tile to a ROAD1 origin
  function isNearRoad1StartTile(planX: Int, planY: Int, startX: Int, startY: Int): Bool
    {
      if (startX < 0 ||
          startY < 0)
        return false;

      var tileX = Std.int(planX / PLAN_CELLS_PER_TILE);
      var tileY = Std.int(planY / PLAN_CELLS_PER_TILE);
      var startTileX = Std.int(startX / PLAN_CELLS_PER_TILE);
      var startTileY = Std.int(startY / PLAN_CELLS_PER_TILE);

      return Math.abs(tileX - startTileX) <= 1 &&
        Math.abs(tileY - startTileY) <= 1;
    }

// return whether a ROAD2 start can legally take its first forward step
  function canRoad2AdvanceFromStart(grid: RoadPlanGrid, planX: Int, planY: Int,
      dx: Int, dy: Int, road2ID: Int = -1): Bool
    {
      var nextX = planX + dx * ROAD2_GRID_STEP;
      var nextY = planY + dy * ROAD2_GRID_STEP;
      return isInPlanBounds(nextX, nextY) &&
        !doesRoad2FootprintHitAnyRoad(grid, nextX, nextY) &&
        !hasRoad2ClearanceConflict(grid, nextX, nextY, road2ID);
    }

// return the minimum branch-root offset in plan cells for one road tier
  function getRoadBranchRootClearance(type: RoadType): Int
    {
      if (type == ROAD2)
        return 2;

      var style = getRoadStyle(type);
      var radius = style.coreWidth / 2.0 + style.shoulderWidth + style.featherWidth;
      return clampInt(Std.int(Math.ceil(radius / PLAN_CELL_SIZE)) + 1, 2, 5);
    }

// return the ROAD2 branch chance for one adjacent plan cell
  function getRoad2BranchChance(planX: Int, planY: Int): Float
    {
      return switch (getAreaTypeAtPlanCell(planX, planY)) {
        case AREA_CITY_LOW, AREA_CITY_MEDIUM, AREA_CITY_HIGH: 0.70;
        default: 0.0;
      };
    }

// walk one ROAD2 or ROAD3 branch with turns, stops, and downgrades
  function walkBranchRoad(grid: RoadPlanGrid, walker: RoadWalker)
    {
      if (walker.type == ROAD2)
        {
          var snapped = snapRoad2Anchor(walker.x, walker.y);
          walker.x = snapped.x;
          walker.y = snapped.y;
          addRoad2PlanStamp(grid, walker.x, walker.y, walker.road2ID);
        }
      else
        addRoadPlanAxis(grid, walker.x, walker.y, walker.dx, walker.dy, walker.type);
      while (true)
        {
          var nextX = walker.x + (walker.type == ROAD2 ? walker.dx * ROAD2_GRID_STEP : walker.dx);
          var nextY = walker.y + (walker.type == ROAD2 ? walker.dy * ROAD2_GRID_STEP : walker.dy);
          if (!isInPlanBounds(nextX, nextY))
            return;
          if ((walker.type == ROAD2 &&
              (doesRoad2FootprintHitAnyRoad(grid, nextX, nextY, walker.x, walker.y) ||
              hasRoad2ClearanceConflict(grid, nextX, nextY, walker.road2ID))) ||
              (walker.type != ROAD2 &&
              isPlanCellOccupied(grid, nextX, nextY)))
            return;

          var nextArea = getAreaTypeAtPlanCell(nextX, nextY);
          var oldDx = walker.dx;
          var oldDy = walker.dy;
          var drawType = walker.type;
          var turned = false;

          walker.x = nextX;
          walker.y = nextY;
          walker.stepsSinceTurn++;

          if (walker.type == ROAD2 &&
              nextArea == AREA_CITY_LOW &&
              canRoadWalkerTurn(walker) &&
              rng.nextFloat() < 0.12 &&
              trySpawnRoadTurnBranch(grid, walker, ROAD3))
            {
              drawType = ROAD2;
            }
          else if (walker.type == ROAD2 &&
              shouldTurnRoadWalker(walker))
            trySpawnRoadTurnBranch(grid, walker, ROAD2);
          else if (shouldTurnRoadWalker(walker))
            turned = tryTurnRoadWalker(grid, walker);

          if (drawType == ROAD2)
            addRoad2PlanStamp(grid, walker.x, walker.y, walker.road2ID);
          else if (turned)
            addRoadPlanCorner(grid, walker.x, walker.y, oldDx, oldDy, walker.dx, walker.dy,
              drawType);
          else
            addRoadPlanAxis(grid, walker.x, walker.y, oldDx, oldDy, drawType);

          if (walker.stopLockSteps > 0)
            {
              walker.stopLockSteps--;
              continue;
            }
          if (walker.type == ROAD2 &&
              isRoad2GroundAtPlanCell(nextX, nextY))
            return;
          if (!isCityAreaType(nextArea))
            return;
        }
    }

// try spawning a branch off one ROAD2 step instead of turning the parent
  function trySpawnRoadTurnBranch(grid: RoadPlanGrid, walker: RoadWalker,
      branchType: RoadType): Bool
    {
      var leftDx = walker.dy;
      var leftDy = -walker.dx;
      var rightDx = -walker.dy;
      var rightDy = walker.dx;
      var tryLeftFirst = rng.nextFloat() < 0.5;

      if (tryLeftFirst)
        {
          if (trySpawnRoadTurnBranchDirection(grid, walker, leftDx, leftDy, branchType))
            return true;
          if (trySpawnRoadTurnBranchDirection(grid, walker, rightDx, rightDy, branchType))
            return true;
          return false;
        }

      if (trySpawnRoadTurnBranchDirection(grid, walker, rightDx, rightDy, branchType))
        return true;
      if (trySpawnRoadTurnBranchDirection(grid, walker, leftDx, leftDy, branchType))
        return true;
      return false;
    }

// try spawning one orthogonal branch direction from a ROAD2 step
  function trySpawnRoadTurnBranchDirection(grid: RoadPlanGrid, walker: RoadWalker,
      dx: Int, dy: Int, branchType: RoadType): Bool
    {
      if (!canUseRoadWalkerDirection(walker, dx, dy))
        return false;

      var startX = walker.x + dx * ROAD2_GRID_STEP;
      var startY = walker.y + dy * ROAD2_GRID_STEP;
      if (!isInPlanBounds(startX, startY))
        return false;

      if (branchType == ROAD2)
        {
          var snapped = snapRoad2Anchor(startX, startY);
          startX = snapped.x;
          startY = snapped.y;
          if (!canUseRoad2Start(grid, startX, startY, dx, dy, -1, -1, walker.road2ID))
            return false;

          walkBranchRoad(grid, {
            x: startX,
            y: startY,
            dx: dx,
            dy: dy,
            originX: startX,
            originY: startY,
            horizontalSign: (dx != 0 ? dx : 0),
            verticalSign: (dy != 0 ? dy : 0),
            stepsSinceTurn: 0,
            stopLockSteps: 0,
            road2ID: walker.road2ID,
            type: ROAD2,
          });
          return true;
        }

      if (!canUseBranchRoadStart(grid, startX, startY, dx, dy))
        return false;

      walkBranchRoad(grid, {
        x: startX,
        y: startY,
        dx: dx,
        dy: dy,
        originX: startX,
        originY: startY,
        horizontalSign: (dx != 0 ? dx : 0),
        verticalSign: (dy != 0 ? dy : 0),
        stepsSinceTurn: 0,
        stopLockSteps: 0,
        road2ID: -1,
        type: branchType,
      });
      return true;
    }

// return whether one non-ROAD2 branch can start and move one step
  function canUseBranchRoadStart(grid: RoadPlanGrid, planX: Int, planY: Int,
      dx: Int, dy: Int): Bool
    {
      var nextX = planX + dx;
      var nextY = planY + dy;
      return !isPlanCellOccupied(grid, planX, planY) &&
        isInPlanBounds(nextX, nextY) &&
        !isPlanCellOccupied(grid, nextX, nextY);
    }

// return whether one branch walker should try a spontaneous turn
  function shouldTurnRoadWalker(walker: RoadWalker): Bool
    {
      if (!canRoadWalkerTurn(walker))
        return false;

      return switch (walker.type) {
        case ROAD2: rng.nextFloat() < 0.30;
        case ROAD3: rng.nextFloat() < 0.06;
        default: false;
      };
    }

// return whether one branch walker is allowed to turn yet
  function canRoadWalkerTurn(walker: RoadWalker): Bool
    {
      return walker.stepsSinceTurn >= ROAD_BRANCH_MIN_TURN_STEPS &&
        walker.stepsSinceTurn % PLAN_CELLS_PER_TILE == 0;
    }

// try turning one branch walker and mark the corner cell on the new axis
  function tryTurnRoadWalker(grid: RoadPlanGrid, walker: RoadWalker): Bool
    {
      var leftDx = walker.dy;
      var leftDy = -walker.dx;
      var rightDx = -walker.dy;
      var rightDy = walker.dx;
      var tryLeftFirst = rng.nextFloat() < 0.5;

      if (tryLeftFirst)
        {
          if (canTurnRoadWalker(grid, walker, leftDx, leftDy))
            {
              walker.dx = leftDx;
              walker.dy = leftDy;
              commitRoadWalkerDirection(walker, leftDx, leftDy);
              walker.stepsSinceTurn = 0;
              return true;
            }
          if (canTurnRoadWalker(grid, walker, rightDx, rightDy))
            {
              walker.dx = rightDx;
              walker.dy = rightDy;
              commitRoadWalkerDirection(walker, rightDx, rightDy);
              walker.stepsSinceTurn = 0;
              return true;
            }
          return false;
        }

      if (canTurnRoadWalker(grid, walker, rightDx, rightDy))
        {
          walker.dx = rightDx;
          walker.dy = rightDy;
          commitRoadWalkerDirection(walker, rightDx, rightDy);
          walker.stepsSinceTurn = 0;
          return true;
        }
      if (canTurnRoadWalker(grid, walker, leftDx, leftDy))
        {
          walker.dx = leftDx;
          walker.dy = leftDy;
          commitRoadWalkerDirection(walker, leftDx, leftDy);
          walker.stepsSinceTurn = 0;
          return true;
        }
      return false;
    }

// return whether one walker can turn into the next plan cell
  function canTurnRoadWalker(grid: RoadPlanGrid, walker: RoadWalker, dx: Int, dy: Int): Bool
    {
      if (!canUseRoadWalkerDirection(walker, dx, dy))
        return false;

      var nextX = walker.x + (walker.type == ROAD2 ? dx * ROAD2_GRID_STEP : dx);
      var nextY = walker.y + (walker.type == ROAD2 ? dy * ROAD2_GRID_STEP : dy);
      if (!isInPlanBounds(nextX, nextY))
        return false;

      if (walker.type != ROAD2)
        return true;

      return !doesRoad2FootprintHitAnyRoad(grid, nextX, nextY, walker.x, walker.y) &&
        !hasRoad2ClearanceConflict(grid, nextX, nextY, walker.road2ID);
    }

// commit one walker direction so it cannot loop back later
  function commitRoadWalkerDirection(walker: RoadWalker, dx: Int, dy: Int)
    {
      if (dx != 0)
        walker.horizontalSign = dx;
      if (dy != 0)
        walker.verticalSign = dy;
    }

// return whether one candidate direction would loop back on a committed axis
  function canUseRoadWalkerDirection(walker: RoadWalker, dx: Int, dy: Int): Bool
    {
      if (dx != 0 &&
          walker.horizontalSign != 0 &&
          walker.horizontalSign != dx)
        return false;
      if (dy != 0 &&
          walker.verticalSign != 0 &&
          walker.verticalSign != dy)
        return false;
      return true;
    }

// return whether one plan-grid coordinate is inside bounds
  function isInPlanBounds(planX: Int, planY: Int): Bool
    {
      return planX >= 0 &&
        planY >= 0 &&
        planX < planWidth &&
        planY < planHeight;
    }

// return whether a branch step entered a different region tile
  function isEnteringRegionTile(fromX: Int, fromY: Int, toX: Int, toY: Int): Bool
    {
      var fromCellX = Std.int(fromX / PLAN_CELLS_PER_TILE);
      var fromCellY = Std.int(fromY / PLAN_CELLS_PER_TILE);
      var toCellX = Std.int(toX / PLAN_CELLS_PER_TILE);
      var toCellY = Std.int(toY / PLAN_CELLS_PER_TILE);
      return fromCellX != toCellX || fromCellY != toCellY;
    }

// return the raw area type at one plan-grid cell
  function getAreaTypeAtPlanCell(planX: Int, planY: Int): _AreaType
    {
      var cellX = clampInt(Std.int(planX / PLAN_CELLS_PER_TILE), 0, fullCellWidth - 1);
      var cellY = clampInt(Std.int(planY / PLAN_CELLS_PER_TILE), 0, fullCellHeight - 1);
      return areaTypes[cellX][cellY];
    }

// return whether one plan cell already has any road axis
  function isPlanCellOccupied(grid: RoadPlanGrid, planX: Int, planY: Int): Bool
    {
      return grid.horizontal[planX][planY] >= 0 ||
        grid.vertical[planX][planY] >= 0 ||
        grid.cornerOrder[planX][planY] >= 0 ||
        grid.road1Cells[planX][planY] ||
        grid.road2Cells[planX][planY];
    }

// return whether one plan cell already has a road on the requested axis
  function hasRoadPlanAxis(grid: RoadPlanGrid, planX: Int, planY: Int,
      dx: Int, dy: Int): Bool
    {
      if (dx != 0)
        {
          return grid.horizontal[planX][planY] >= 0 ||
            (grid.cornerMask[planX][planY] &
              (getRoadDirectionMask(-1, 0) | getRoadDirectionMask(1, 0))) != 0;
        }
      return grid.vertical[planX][planY] >= 0 ||
        (grid.cornerMask[planX][planY] &
          (getRoadDirectionMask(0, -1) | getRoadDirectionMask(0, 1))) != 0;
    }

// return whether the rendered 2x2 orange footprint would hit any road cell
  function doesRoad2FootprintHitAnyRoad(grid: RoadPlanGrid, planX: Int, planY: Int,
      ignoreStampX: Int = -1, ignoreStampY: Int = -1): Bool
    {
      for (yy in planY...Std.int(Math.min(planY + 2, planHeight)))
        for (xx in planX...Std.int(Math.min(planX + 2, planWidth)))
          if (!isInsideRoad2Stamp(xx, yy, ignoreStampX, ignoreStampY) &&
              isPlanCellOccupied(grid, xx, yy))
            return true;
      return false;
    }

// return whether one orange footprint is too close to another orange corridor
  function hasRoad2ClearanceConflict(grid: RoadPlanGrid, planX: Int, planY: Int,
      road2ID: Int): Bool
    {
      var minX = clampInt(planX - PLAN_CELLS_PER_TILE, 0, planWidth - 1);
      var maxX = clampInt(planX + 1 + PLAN_CELLS_PER_TILE, 0, planWidth - 1);
      var minY = clampInt(planY - PLAN_CELLS_PER_TILE, 0, planHeight - 1);
      var maxY = clampInt(planY + 1 + PLAN_CELLS_PER_TILE, 0, planHeight - 1);

      for (yy in minY...maxY + 1)
        for (xx in minX...maxX + 1)
          if (grid.road2IDs[xx][yy] >= 0 &&
              grid.road2IDs[xx][yy] != road2ID)
            return true;
      return false;
    }

// return whether one plan cell belongs to a specific ROAD2 2x2 stamp anchor
  function isInsideRoad2Stamp(planX: Int, planY: Int, stampX: Int, stampY: Int): Bool
    {
      return stampX >= 0 &&
        stampY >= 0 &&
        planX >= stampX &&
        planX < stampX + 2 &&
        planY >= stampY &&
        planY < stampY + 2;
    }

// return whether a ROAD2 step is entering visible ground instead of city mass
  function isRoad2GroundAtPlanCell(planX: Int, planY: Int): Bool
    {
      var px = planX * PLAN_CELL_SIZE + Std.int(PLAN_CELL_SIZE / 2);
      var py = planY * PLAN_CELL_SIZE + Std.int(PLAN_CELL_SIZE / 2);
      return sampleDensityAtPixel(px, py) < ROAD2_MIN_CITY_DENSITY;
    }

// return whether one plan cell carries the requested road tier on any stored shape
  function hasRoadTypeAtPlanCell(grid: RoadPlanGrid, planX: Int, planY: Int,
      type: RoadType): Bool
    {
      var order = getRoadTypeOrder(type);
      if (type == ROAD1)
        return grid.road1Cells[planX][planY];
      if (type == ROAD2)
        return grid.road2Cells[planX][planY];
      return grid.horizontal[planX][planY] == order ||
        grid.vertical[planX][planY] == order ||
        grid.cornerOrder[planX][planY] == order;
    }

// mark one ROAD2 anchor as a real 2x2 occupied footprint
  function addRoad2PlanStamp(grid: RoadPlanGrid, planX: Int, planY: Int, road2ID: Int)
    {
      for (yy in planY...Std.int(Math.min(planY + 2, planHeight)))
        for (xx in planX...Std.int(Math.min(planX + 2, planWidth)))
          {
            grid.road2Cells[xx][yy] = true;
            grid.road2IDs[xx][yy] = road2ID;
          }
    }

// mark one ROAD1 centerline step as a 3-cell-wide occupied band
  function addRoad1PlanStamp(grid: RoadPlanGrid, planX: Int, planY: Int, dx: Int, dy: Int)
    {
      if (dx != 0)
        {
          for (yy in clampInt(planY - 1, 0, planHeight - 1)...clampInt(planY + 2, 0, planHeight))
            grid.road1Cells[planX][yy] = true;
          return;
        }

      for (xx in clampInt(planX - 1, 0, planWidth - 1)...clampInt(planX + 2, 0, planWidth))
        grid.road1Cells[xx][planY] = true;
    }

// mark one road axis cell while keeping the stronger road tier when overlapping
  function addRoadPlanAxis(grid: RoadPlanGrid, planX: Int, planY: Int,
      dx: Int, dy: Int, type: RoadType)
    {
      var order = getRoadTypeOrder(type);
      var axis = (dx != 0 ? grid.horizontal : grid.vertical);
      var current = axis[planX][planY];

      if (current < 0 ||
          order < current)
        axis[planX][planY] = order;
      if (type == ROAD1)
        addRoad1PlanStamp(grid, planX, planY, dx, dy);
    }

// mark one explicit corner cell between incoming and outgoing directions
  function addRoadPlanCorner(grid: RoadPlanGrid, planX: Int, planY: Int,
      inDx: Int, inDy: Int, outDx: Int, outDy: Int, type: RoadType)
    {
      var order = getRoadTypeOrder(type);
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

// return the bitmask for one orthogonal road direction
  function getRoadDirectionMask(dx: Int, dy: Int): Int
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
  function compressRoadPlanGrid(grid: RoadPlanGrid): Array<RoadSegment>
    {
      var result = [];

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
                x1: start * PLAN_CELL_SIZE,
                y1: yy * PLAN_CELL_SIZE + Std.int(PLAN_CELL_SIZE / 2),
                x2: (xx + 1) * PLAN_CELL_SIZE,
                y2: yy * PLAN_CELL_SIZE + Std.int(PLAN_CELL_SIZE / 2),
                type: getRoadTypeByOrder(order),
              });
              xx++;
            }
        }

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
                x1: xx * PLAN_CELL_SIZE + Std.int(PLAN_CELL_SIZE / 2),
                y1: start * PLAN_CELL_SIZE,
                x2: xx * PLAN_CELL_SIZE + Std.int(PLAN_CELL_SIZE / 2),
                y2: (yy + 1) * PLAN_CELL_SIZE,
                type: getRoadTypeByOrder(order),
              });
              yy++;
            }
        }

      for (yy in 0...grid.height)
        for (xx in 0...grid.width)
          {
            var order = grid.cornerOrder[xx][yy];
            if (order < 0)
              continue;
            addCornerRoadSegments(result, xx, yy, grid.cornerMask[xx][yy], getRoadTypeByOrder(order));
          }

      for (yy in 0...grid.height)
        for (xx in 0...grid.width)
          {
            if (!grid.road2Cells[xx][yy])
              continue;
            addRoad2CellSegment(result, xx, yy);
          }

      return result;
    }

// add one tiny ROAD2 center segment for a stamped occupied cell
  function addRoad2CellSegment(out: Array<RoadSegment>, xx: Int, yy: Int)
    {
      var centerX = xx * PLAN_CELL_SIZE + Std.int(PLAN_CELL_SIZE / 2);
      var centerY = yy * PLAN_CELL_SIZE + Std.int(PLAN_CELL_SIZE / 2);

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
      var cellX = xx * PLAN_CELL_SIZE;
      var cellY = yy * PLAN_CELL_SIZE;
      var centerX = cellX + Std.int(PLAN_CELL_SIZE / 2);
      var centerY = cellY + Std.int(PLAN_CELL_SIZE / 2);

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
          x2: cellX + PLAN_CELL_SIZE,
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
          y2: cellY + PLAN_CELL_SIZE,
          type: type,
        });
    }

}
