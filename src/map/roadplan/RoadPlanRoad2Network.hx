// road-plan ROAD2 network, anchors, and connector helpers

package map.roadplan;

import _AreaType;
import map.RoadPlan;
import map.Types.GridPoint;
import map.Types.IntRect;
import map.Types.Road2Attachment;
import map.Types.Road2CoverageAttachmentState;
import map.Types.Road2Component;
import map.Types.Road2Connector;
import map.Types.RoadPlanGrid;

@:access(map.Core)
@:access(map.Ground)
@:access(map.Raster)
@:access(map.RoadPlan)
class RoadPlanRoad2Network
{
  var plan: RoadPlan;
  var gridOps: RoadPlanGridOps;

  public function new(plan: RoadPlan, gridOps: RoadPlanGridOps)
    {
      this.plan = plan;
      this.gridOps = gridOps;
    }

// return whether ROAD2 may use this area type
  public function canRoad2UseAreaType(areaType: _AreaType): Bool
    {
      return switch (areaType) {
        case AREA_CITY_LOW, AREA_CITY_MEDIUM: true;
        default: false;
      };
    }

// return whether ROAD2 may use this plan cell
  public function canRoad2UsePlanCell(planX: Int, planY: Int): Bool
    {
      return canRoad2UseAreaType(gridOps.getAreaTypeAtPlanCell(planX, planY));
    }

// connect detached orange components back to the road network
  public function ensureRoad2Connectivity(grid: RoadPlanGrid)
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
  public function ensureCityRoad2Coverage(grid: RoadPlanGrid)
    {
      var road1Candidates = collectRoad1AttachmentCandidates(grid);
      var attachmentState = makeRoad2CoverageAttachmentState(grid);

      for (cellY in 0...plan.fullCellHeight)
        for (cellX in 0...plan.fullCellWidth)
          {
            if (!canRoad2UseAreaType(plan.areaTypes[cellX][cellY]))
              continue;

            if (gridOps.hasRoad2InRegionTile(grid, cellX, cellY))
              continue;

            var start = findTileRoad2Start(grid, cellX, cellY);
            if (start == null)
              continue;

            plan.addMapProfileCount('road2.ensureCityRoad2Coverage.attempts');
            var target = findNearestRoad2Attachment(attachmentState.road2Attachments, start.x, start.y);
            var dirtyRect: IntRect = null;
            if (target != null)
              {
                dirtyRect = connectRoad2ConnectorAndGetDirtyRect(grid, {
                  x: start.x,
                  y: start.y,
                  road2ID: target.road2ID,
                  road1StepX: -1,
                  road1StepY: -1,
                  road1DX: 0,
                  road1DY: 0,
                }, target, false);
                if (dirtyRect != null)
                  plan.addMapProfileCount('road2.ensureCityRoad2Coverage.connectedToRoad2');
              }

            if (dirtyRect == null)
              {
                var road1Target = findNearestRoad1Attachment(attachmentState.road1Attachments,
                  start.x, start.y);
                if (road1Target != null)
                  {
                    if (!isTinyRoad2Road1CoverageConnector(start.x, start.y, road1Target))
                      {
                        dirtyRect = connectRoad2ConnectorAndGetDirtyRect(grid, {
                          x: start.x,
                          y: start.y,
                          road2ID: plan.nextRoad2ID++,
                          road1StepX: -1,
                          road1StepY: -1,
                          road1DX: 0,
                          road1DY: 0,
                        }, road1Target, false);
                        if (dirtyRect != null)
                          plan.addMapProfileCount('road2.ensureCityRoad2Coverage.connectedToRoad1');
                      }
                  }
              }

            if (dirtyRect != null)
              {
                attachmentState = refreshRoad2CoverageAttachmentState(grid, road1Candidates,
                  attachmentState, dirtyRect);
                plan.addMapProfileCount('road2.ensureCityRoad2Coverage.localRefreshes');
              }
            else
              plan.addMapProfileCount('road2.ensureCityRoad2Coverage.failed');
          }
    }

// collect the mutable attachment lists used during ROAD2 coverage
  function makeRoad2CoverageAttachmentState(grid: RoadPlanGrid): Road2CoverageAttachmentState
    {
#if mydebug
      plan.addMapProfileCount('road2.ensureCityRoad2Coverage.collectRoad2Attachments.rebuilds');
#end
      var road2Attachments = collectRoad2Attachments(grid);
#if mydebug
      plan.addMapProfileCount('road2.ensureCityRoad2Coverage.collectRoad1Attachments.rebuilds');
#end
      var road1Attachments = collectRoad1Attachments(grid);
      return {
        road2Attachments: road2Attachments,
        road1Attachments: road1Attachments,
      };
    }

// collect connected orange components from the plan grid
  function buildRoad2Components(grid: RoadPlanGrid): Array<Road2Component>
    {
      var visited = plan.makeBoolGrid(plan.planWidth, plan.planHeight);
      var result = [];

      for (xx in 0...plan.planWidth)
        for (yy in 0...plan.planHeight)
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
                    var nx = point.x + gridOps.getCardinalDX(dir);
                    var ny = point.y + gridOps.getCardinalDY(dir);
                    if (!gridOps.isInPlanBounds(nx, ny) ||
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
              var startX = cell.x + gridOps.getCardinalDX(dir);
              var startY = cell.y + gridOps.getCardinalDY(dir);
              if (!gridOps.isInPlanBounds(startX, startY) ||
                  gridOps.isPlanCellOccupied(grid, startX, startY))
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
  public function connectRoad2Connector(grid: RoadPlanGrid, start: Road2Attachment,
      target: Road2Attachment, allowTargetRoad1: Bool): Bool
    {
      return connectRoad2ConnectorAndGetDirtyRect(grid, start, target, allowTargetRoad1) != null;
    }

// connect one orange start and return the dirty rect when stamping succeeds
  function connectRoad2ConnectorAndGetDirtyRect(grid: RoadPlanGrid, start: Road2Attachment,
      target: Road2Attachment, allowTargetRoad1: Bool): IntRect
    {
#if mydebug
      var startTS = haxe.Timer.stamp() * 1000.0;
#end
      var dirtyRect = tryConnectRoad2Connector(grid, start, target, true, allowTargetRoad1);
      if (dirtyRect == null)
        dirtyRect = tryConnectRoad2Connector(grid, start, target, false, allowTargetRoad1);
#if mydebug
      plan.addMapProfileSample('road2.connectRoad2Connector',
        haxe.Timer.stamp() * 1000.0 - startTS);
      if (dirtyRect != null)
        plan.addMapProfileCount('road2.connectRoad2Connector.success');
      else
        plan.addMapProfileCount('road2.connectRoad2Connector.failed');
#end
      return dirtyRect;
    }

// try one orthogonal connector routing order for orange coverage
  function tryConnectRoad2Connector(grid: RoadPlanGrid, start: Road2Attachment,
      target: Road2Attachment, horizontalFirst: Bool, allowTargetRoad1: Bool): IntRect
    {
      var path = buildRoad2ConnectorPath(start.x, start.y, target.x, target.y, horizontalFirst);
      if (path.length == 0)
        return null;

      for (i in 0...path.length)
        {
          var point = path[i];
          var ignoreX = (i > 0 ? path[i - 1].x : -1);
          var ignoreY = (i > 0 ? path[i - 1].y : -1);
          var isTarget = i == path.length - 1;
          if (!canStampRoad2ConnectorCell(grid, point.x, point.y, start.road2ID,
              ignoreX, ignoreY, isTarget, target, allowTargetRoad1))
            return null;
        }

      var dirtyRect = getRoad2ConnectorDirtyRect(path, target);
      for (point in path)
        gridOps.addRoad2PlanStamp(grid, point.x, point.y, start.road2ID,
          getRoad2PathAxisMask(path, point));
      if (target.road1StepX >= 0)
        addRoad2Road1Bridge(grid, target.road1StepX, target.road1StepY,
          target.x, target.y, target.road1DX, target.road1DY, start.road2ID);
      return dirtyRect;
    }

// return the dirty plan rect touched by one successful orange connector
  function getRoad2ConnectorDirtyRect(path: Array<GridPoint>, target: Road2Attachment): IntRect
    {
      var minX = plan.planWidth - 1;
      var minY = plan.planHeight - 1;
      var maxX = 0;
      var maxY = 0;

      for (point in path)
        {
          minX = Std.int(Math.min(minX, point.x));
          minY = Std.int(Math.min(minY, point.y));
          maxX = Std.int(Math.max(maxX, point.x + 1));
          maxY = Std.int(Math.max(maxY, point.y + 1));
        }

      if (target.road1StepX >= 0)
        {
          var bridgeRect = getRoad2Road1BridgeRect(target.road1StepX, target.road1StepY,
            target.x, target.y, target.road1DX, target.road1DY);
          if (bridgeRect != null)
            {
              minX = Std.int(Math.min(minX, bridgeRect.x));
              minY = Std.int(Math.min(minY, bridgeRect.y));
              maxX = Std.int(Math.max(maxX, bridgeRect.x + bridgeRect.width - 1));
              maxY = Std.int(Math.max(maxY, bridgeRect.y + bridgeRect.height - 1));
            }
        }

      return {
        x: minX,
        y: minY,
        width: maxX - minX + 1,
        height: maxY - minY + 1,
      };
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
              x += (target.x > x ? plan.ROAD2_GRID_STEP : -plan.ROAD2_GRID_STEP);
              out.push({
                x: x,
                y: y,
              });
            }
          while (y != target.y)
            {
              y += (target.y > y ? plan.ROAD2_GRID_STEP : -plan.ROAD2_GRID_STEP);
              out.push({
                x: x,
                y: y,
              });
            }
          return out;
        }

      while (y != target.y)
        {
          y += (target.y > y ? plan.ROAD2_GRID_STEP : -plan.ROAD2_GRID_STEP);
          out.push({
            x: x,
            y: y,
          });
        }
      while (x != target.x)
        {
          x += (target.x > x ? plan.ROAD2_GRID_STEP : -plan.ROAD2_GRID_STEP);
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
      if (!gridOps.isInPlanBounds(planX, planY))
        return false;
      if (!canRoad2UsePlanCell(planX, planY))
        return false;
      if (isTarget &&
          target != null &&
          planX == target.x &&
          planY == target.y)
        return target.road1StepX < 0 ||
          canBuildRoad2Road1Bridge(grid, target.road1StepX, target.road1StepY,
            planX, planY, target.road1DX, target.road1DY, road2ID);
      if (!(allowRoad1Touch && isRoad1AttachmentCell(grid, planX, planY)) &&
          !isRoad2AttachmentCell(grid, planX, planY))
        return false;
      if (gridOps.doesRoad2FootprintHitAnyRoad(grid, planX, planY, ignoreStampX, ignoreStampY))
        return false;
      return !gridOps.hasRoad2ClearanceConflict(grid, planX, planY, road2ID);
    }

// return whether one ROAD1 to ROAD2 bridge strip is clear to stamp
  public function canBuildRoad2Road1Bridge(grid: RoadPlanGrid, baseX: Int, baseY: Int,
      planX: Int, planY: Int, dx: Int, dy: Int, road2ID: Int = -1): Bool
    {
      var bridgeRect = getRoad2Road1BridgeRect(baseX, baseY, planX, planY, dx, dy);
      if (bridgeRect == null)
        return true;

      for (yy in bridgeRect.y...bridgeRect.y + bridgeRect.height)
        for (xx in bridgeRect.x...bridgeRect.x + bridgeRect.width)
          {
            if (!gridOps.isInPlanBounds(xx, yy) ||
                !canRoad2UsePlanCell(xx, yy) ||
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
  public function addRoad2Road1Bridge(grid: RoadPlanGrid, baseX: Int, baseY: Int,
      planX: Int, planY: Int, dx: Int, dy: Int, road2ID: Int)
    {
      var bridgeRect = getRoad2Road1BridgeRect(baseX, baseY, planX, planY, dx, dy);
      if (bridgeRect == null)
        return;

      var axisMask = gridOps.getRoadAxisMask(dx, dy);
      for (yy in bridgeRect.y...bridgeRect.y + bridgeRect.height)
        for (xx in bridgeRect.x...bridgeRect.x + bridgeRect.width)
          {
            grid.road2Cells[xx][yy] = true;
            grid.road2IDs[xx][yy] = road2ID;
            grid.road2AxisMask[xx][yy] = grid.road2AxisMask[xx][yy] | axisMask;
          }
    }

// return the bridge strip bounds between one ROAD1 step and one ROAD2 anchor
  function getRoad2Road1BridgeRect(baseX: Int, baseY: Int, planX: Int, planY: Int,
      dx: Int, dy: Int): IntRect
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
        return null;

      return {
        x: startX,
        y: startY,
        width: endX - startX + 1,
        height: endY - startY + 1,
      };
    }

// return the stored axis mask for one ROAD2 connector stamp cell
  function getRoad2PathAxisMask(path: Array<GridPoint>, point: GridPoint): Int
    {
      if (path.length <= 1)
        return 3;

      for (i in 0...path.length)
        {
          if (path[i].x != point.x ||
              path[i].y != point.y)
            continue;

          if (i == 0)
            return gridOps.getRoadAxisMask(path[i + 1].x - path[i].x,
              path[i + 1].y - path[i].y);
          if (i == path.length - 1)
            return gridOps.getRoadAxisMask(path[i].x - path[i - 1].x,
              path[i].y - path[i - 1].y);

          var mask = gridOps.getRoadAxisMask(path[i].x - path[i - 1].x,
            path[i].y - path[i - 1].y);
          return mask | gridOps.getRoadAxisMask(path[i + 1].x - path[i].x,
            path[i + 1].y - path[i].y);
        }

      return 0;
    }

// collect all empty cells that can attach to orange roads
  public function collectRoad2Attachments(grid: RoadPlanGrid): Array<Road2Attachment>
    {
#if mydebug
      var startTS = haxe.Timer.stamp() * 1000.0;
#end
      var result = [];

      for (xx in 0...plan.planWidth)
        {
          if ((xx & 1) != 0)
            continue;
          for (yy in 0...plan.planHeight)
          {
            if ((yy & 1) != 0)
              continue;
            var road2ID = getAdjacentRoad2AttachmentID(grid, xx, yy);
            if (gridOps.isPlanCellOccupied(grid, xx, yy) ||
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

#if mydebug
      plan.addMapProfileSample('road2.collectRoad2Attachments',
        haxe.Timer.stamp() * 1000.0 - startTS);
      plan.addMapProfileCount('road2.collectRoad2Attachments.resultCount', result.length);
#end
      return result;
    }

// collect all canonical ROAD1 anchor candidates before dynamic filtering
  function collectRoad1AttachmentCandidates(grid: RoadPlanGrid): Array<Road2Attachment>
    {
      var result = [];
      var used = plan.makeBoolGrid(plan.planWidth, plan.planHeight);
      var road1Order = plan.getRoadTypeOrder(ROAD1);

      for (xx in 0...plan.planWidth)
        for (yy in 0...plan.planHeight)
          {
            if (grid.horizontal[xx][yy] == road1Order)
              {
                addRoad1AttachmentCandidate(result, used, grid, xx, yy, 0, -1, false);
                addRoad1AttachmentCandidate(result, used, grid, xx, yy, 0, 1, false);
              }
            if (grid.vertical[xx][yy] == road1Order)
              {
                addRoad1AttachmentCandidate(result, used, grid, xx, yy, -1, 0, false);
                addRoad1AttachmentCandidate(result, used, grid, xx, yy, 1, 0, false);
              }
          }

      return result;
    }

// collect all lane-aligned empty cells that can attach to ROAD1
  public function collectRoad1Attachments(grid: RoadPlanGrid): Array<Road2Attachment>
    {
#if mydebug
      var startTS = haxe.Timer.stamp() * 1000.0;
#end
      var result = [];
      var used = plan.makeBoolGrid(plan.planWidth, plan.planHeight);
      var road1Order = plan.getRoadTypeOrder(ROAD1);

      for (xx in 0...plan.planWidth)
        for (yy in 0...plan.planHeight)
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

#if mydebug
      plan.addMapProfileSample('road2.collectRoad1Attachments',
        haxe.Timer.stamp() * 1000.0 - startTS);
      plan.addMapProfileCount('road2.collectRoad1Attachments.resultCount', result.length);
#end
      return result;
    }

// add one canonical ROAD1 to ROAD2 anchor candidate
  function addRoad1AttachmentCandidate(out: Array<Road2Attachment>, used: Array<Array<Bool>>,
      grid: RoadPlanGrid, baseX: Int, baseY: Int, dx: Int, dy: Int, requireUsable: Bool = true)
    {
      var anchor = getRoad2AnchorFromRoad1Step(baseX, baseY, dx, dy);
      if (anchor == null ||
          used[anchor.x][anchor.y] ||
          (requireUsable &&
          !canUseRoad2Anchor(grid, baseX, baseY, anchor.x, anchor.y, dx, dy)))
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

// refresh the mutable ROAD2 coverage attachment lists near one successful connector
  function refreshRoad2CoverageAttachmentState(grid: RoadPlanGrid,
      road1Candidates: Array<Road2Attachment>, state: Road2CoverageAttachmentState,
      dirtyRect: IntRect): Road2CoverageAttachmentState
    {
#if mydebug
      var startTS = haxe.Timer.stamp() * 1000.0;
#end
      var refreshRect = getRoad2CoverageRefreshRect(dirtyRect);
      var road2Attachments = filterAttachmentsOutsideRect(state.road2Attachments, refreshRect);
      var road1Attachments = filterAttachmentsOutsideRect(state.road1Attachments, refreshRect);

      appendRoad2AttachmentsInRect(road2Attachments, grid, refreshRect);
      appendRoad1AttachmentsInRect(road1Attachments, grid, road1Candidates, refreshRect);
      sortAttachmentsByPlanCell(road2Attachments);
      sortAttachmentsByPlanCell(road1Attachments);
#if mydebug
      plan.addMapProfileSample('road2.refreshCoverageAttachmentState',
        haxe.Timer.stamp() * 1000.0 - startTS);
      plan.addMapProfileCount('road2.refreshCoverageAttachmentState.road2ScanCells',
        refreshRect.width * refreshRect.height);
#end
      return {
        road2Attachments: road2Attachments,
        road1Attachments: road1Attachments,
      };
    }

// return the conservative local refresh window for one ROAD2 coverage mutation
  function getRoad2CoverageRefreshRect(dirtyRect: IntRect): IntRect
    {
      return expandPlanRect(dirtyRect, plan.PLAN_CELLS_PER_TILE + plan.ROAD2_GRID_STEP);
    }

// return one plan-space rect expanded and clamped to bounds
  function expandPlanRect(rect: IntRect, padding: Int): IntRect
    {
      var minX = plan.clampInt(rect.x - padding, 0, plan.planWidth - 1);
      var minY = plan.clampInt(rect.y - padding, 0, plan.planHeight - 1);
      var maxX = plan.clampInt(rect.x + rect.width - 1 + padding, 0, plan.planWidth - 1);
      var maxY = plan.clampInt(rect.y + rect.height - 1 + padding, 0, plan.planHeight - 1);
      return {
        x: minX,
        y: minY,
        width: maxX - minX + 1,
        height: maxY - minY + 1,
      };
    }

// return whether one plan cell falls inside one local refresh rect
  function isPointInRect(planX: Int, planY: Int, rect: IntRect): Bool
    {
      return planX >= rect.x &&
        planY >= rect.y &&
        planX < rect.x + rect.width &&
        planY < rect.y + rect.height;
    }

// keep only the attachments whose anchor lies outside one refresh rect
  function filterAttachmentsOutsideRect(list: Array<Road2Attachment>,
      rect: IntRect): Array<Road2Attachment>
    {
      var out = [];

      for (entry in list)
        if (!isPointInRect(entry.x, entry.y, rect))
          out.push(entry);
      return out;
    }

// append the current ROAD2 attachments inside one refresh rect in canonical order
  function appendRoad2AttachmentsInRect(out: Array<Road2Attachment>,
      grid: RoadPlanGrid, rect: IntRect)
    {
      for (xx in rect.x...rect.x + rect.width)
        {
          if ((xx & 1) != 0)
            continue;
          for (yy in rect.y...rect.y + rect.height)
            {
              if ((yy & 1) != 0)
                continue;
              var road2ID = getAdjacentRoad2AttachmentID(grid, xx, yy);
              if (gridOps.isPlanCellOccupied(grid, xx, yy) ||
                  road2ID < 0)
                continue;
              out.push({
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
    }

// append the currently valid ROAD1 attachments inside one refresh rect in canonical order
  function appendRoad1AttachmentsInRect(out: Array<Road2Attachment>, grid: RoadPlanGrid,
      candidates: Array<Road2Attachment>, rect: IntRect)
    {
      var scanned = 0;

      for (candidate in candidates)
        {
          if (!isPointInRect(candidate.x, candidate.y, rect))
            continue;
          scanned++;
          if (!canUseRoad2Anchor(grid, candidate.road1StepX, candidate.road1StepY,
                candidate.x, candidate.y, candidate.road1DX, candidate.road1DY))
            continue;
          out.push(candidate);
        }

#if mydebug
      plan.addMapProfileCount('road2.refreshCoverageAttachmentState.road1CandidatesScanned',
        scanned);
#end
    }

// sort attachment anchors in the same x-major order as the full collectors
  function sortAttachmentsByPlanCell(list: Array<Road2Attachment>)
    {
      list.sort(sortAttachmentsByPlanCellOrder);
    }

// sort two attachment anchors in canonical plan-grid order
  function sortAttachmentsByPlanCellOrder(a: Road2Attachment, b: Road2Attachment): Int
    {
      if (a.x < b.x)
        return -1;
      if (a.x > b.x)
        return 1;
      if (a.y < b.y)
        return -1;
      if (a.y > b.y)
        return 1;
      return 0;
    }

// return the canonical orange anchor for one ROAD1 step and branch side
  public function getRoad2AnchorFromRoad1Step(baseX: Int, baseY: Int, dx: Int, dy: Int): GridPoint
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

      if (!gridOps.isInPlanBounds(planX, planY) ||
          !gridOps.isInPlanBounds(planX + 1, planY + 1))
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
      return canRoad2UsePlanCell(planX, planY) &&
        !gridOps.isPlanCellOccupied(grid, planX, planY) &&
        !gridOps.doesRoad2FootprintHitAnyRoad(grid, planX, planY) &&
        !gridOps.hasRoad2ClearanceConflict(grid, planX, planY, -1) &&
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

// return whether one city ROAD2 fallback would create only one anchor plus the ROAD1 bridge
  function isTinyRoad2Road1CoverageConnector(startX: Int, startY: Int,
      target: Road2Attachment): Bool
    {
      var start = snapRoad2Anchor(startX, startY);
      var snappedTarget = snapRoad2Anchor(target.x, target.y);
      return start.x == snappedTarget.x &&
        start.y == snappedTarget.y;
    }

// find a reasonable empty orange start inside one city tile
  function findTileRoad2Start(grid: RoadPlanGrid, cellX: Int, cellY: Int): GridPoint
    {
#if mydebug
      var startTS = haxe.Timer.stamp() * 1000.0;
#end
      var tileStartX = cellX * plan.PLAN_CELLS_PER_TILE;
      var tileStartY = cellY * plan.PLAN_CELLS_PER_TILE;
      var centerX = tileStartX + Std.int(plan.PLAN_CELLS_PER_TILE / 2) - 1;
      var centerY = tileStartY + Std.int(plan.PLAN_CELLS_PER_TILE / 2) - 1;
      var best: GridPoint = null;
      var bestDist = 0x3FFFFFFF;

      for (yy in tileStartY...tileStartY + plan.PLAN_CELLS_PER_TILE)
        {
          if ((yy & 1) != 0)
            continue;
          for (xx in tileStartX...tileStartX + plan.PLAN_CELLS_PER_TILE)
          {
            if ((xx & 1) != 0)
              continue;
            if (gridOps.isPlanCellOccupied(grid, xx, yy) ||
                gridOps.doesRoad2FootprintHitAnyRoad(grid, xx, yy) ||
                gridOps.hasRoad2ClearanceConflict(grid, xx, yy, -1))
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

#if mydebug
      plan.addMapProfileSample('road2.findTileRoad2Start',
        haxe.Timer.stamp() * 1000.0 - startTS);
      if (best != null)
        plan.addMapProfileCount('road2.findTileRoad2Start.found');
      else
        plan.addMapProfileCount('road2.findTileRoad2Start.null');
#end
      return best;
    }

// return whether one empty cell touches ROAD1
  public function isRoad1AttachmentCell(grid: RoadPlanGrid, planX: Int, planY: Int): Bool
    {
      var road1Order = plan.getRoadTypeOrder(ROAD1);

      for (yy in plan.clampInt(planY - 3, 0, plan.planHeight - 1)...plan.clampInt(planY + 4, 0, plan.planHeight))
        for (xx in plan.clampInt(planX - 3, 0, plan.planWidth - 1)...plan.clampInt(planX + 4, 0, plan.planWidth))
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
  public function isRoad2AttachmentCell(grid: RoadPlanGrid, planX: Int, planY: Int): Bool
    {
      return getAdjacentRoad2AttachmentID(grid, planX, planY) >= 0;
    }

// return whether one plan cell is adjacent to a ROAD1 footprint
  public function hasAdjacentRoad1Cell(grid: RoadPlanGrid, planX: Int, planY: Int): Bool
    {
      for (dir in 0...4)
        {
          var nx = planX + gridOps.getCardinalDX(dir);
          var ny = planY + gridOps.getCardinalDY(dir);
          if (gridOps.isInPlanBounds(nx, ny) &&
              grid.road1Cells[nx][ny])
            return true;
        }
      return false;
    }

// return the lane-aligned adjacent orange corridor ID for one empty cell
  public function getAdjacentRoad2AttachmentID(grid: RoadPlanGrid, planX: Int, planY: Int): Int
    {
      if (!isRoad2AnchorAligned(planX, planY))
        return -1;

      var left = getRoad2AnchorID(grid, planX - plan.ROAD2_GRID_STEP, planY);
      var right = getRoad2AnchorID(grid, planX + plan.ROAD2_GRID_STEP, planY);
      var up = getRoad2AnchorID(grid, planX, planY - plan.ROAD2_GRID_STEP);
      var down = getRoad2AnchorID(grid, planX, planY + plan.ROAD2_GRID_STEP);

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
  public function getRoad2AnchorID(grid: RoadPlanGrid, planX: Int, planY: Int): Int
    {
      if (!isRoad2AnchorAligned(planX, planY) ||
          !gridOps.isInPlanBounds(planX, planY) ||
          !gridOps.isInPlanBounds(planX + 1, planY + 1))
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
  public function getRoad2IDAt(grid: RoadPlanGrid, planX: Int, planY: Int): Int
    {
      if (!gridOps.isInPlanBounds(planX, planY))
        return -1;
      return grid.road2IDs[planX][planY];
    }

// return whether one orange anchor is aligned to the 2x2 lattice
  public function isRoad2AnchorAligned(planX: Int, planY: Int): Bool
    {
      return (planX & 1) == 0 &&
        (planY & 1) == 0;
    }

// snap one orange anchor onto the 2x2 lattice
  public function snapRoad2Anchor(planX: Int, planY: Int): GridPoint
    {
      return {
        x: plan.clampInt(planX & ~1, 0, plan.planWidth - 2),
        y: plan.clampInt(planY & ~1, 0, plan.planHeight - 2),
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

// return whether one ROAD2 branch start is still legal on the current grid
  public function canUseRoad2Start(grid: RoadPlanGrid, planX: Int, planY: Int,
      dx: Int, dy: Int, road1StartX: Int, road1StartY: Int, road2ID: Int = -1): Bool
    {
      return isRoad2AnchorAligned(planX, planY) &&
        canRoad2UsePlanCell(planX, planY) &&
        !gridOps.isPlanCellOccupied(grid, planX, planY) &&
        !gridOps.doesRoad2FootprintHitAnyRoad(grid, planX, planY) &&
        !isNearRoad1StartTile(planX, planY, road1StartX, road1StartY) &&
        !gridOps.hasRoad2ClearanceConflict(grid, planX, planY, road2ID) &&
        canRoad2AdvanceFromStart(grid, planX, planY, dx, dy, road2ID);
    }

// return whether one plan cell falls in the same or adjacent region tile to a ROAD1 origin
  function isNearRoad1StartTile(planX: Int, planY: Int, startX: Int, startY: Int): Bool
    {
      if (startX < 0 ||
          startY < 0)
        return false;

      var tileX = Std.int(planX / plan.PLAN_CELLS_PER_TILE);
      var tileY = Std.int(planY / plan.PLAN_CELLS_PER_TILE);
      var startTileX = Std.int(startX / plan.PLAN_CELLS_PER_TILE);
      var startTileY = Std.int(startY / plan.PLAN_CELLS_PER_TILE);

      return Math.abs(tileX - startTileX) <= 1 &&
        Math.abs(tileY - startTileY) <= 1;
    }

// return whether a ROAD2 start can legally take its first forward step
  function canRoad2AdvanceFromStart(grid: RoadPlanGrid, planX: Int, planY: Int,
      dx: Int, dy: Int, road2ID: Int = -1): Bool
    {
      var nextX = planX + dx * plan.ROAD2_GRID_STEP;
      var nextY = planY + dy * plan.ROAD2_GRID_STEP;
      return gridOps.isInPlanBounds(nextX, nextY) &&
        canRoad2UsePlanCell(nextX, nextY) &&
        !gridOps.doesRoad2FootprintHitAnyRoad(grid, nextX, nextY) &&
        !gridOps.hasRoad2ClearanceConflict(grid, nextX, nextY, road2ID);
    }

// return whether one ROAD2 step is leaving allowed orange-road area
  public function isRoad2GroundAtPlanCell(planX: Int, planY: Int): Bool
    {
      if (!canRoad2UsePlanCell(planX, planY))
        return true;
      var px = planX * plan.PLAN_CELL_SIZE + Std.int(plan.PLAN_CELL_SIZE / 2);
      var py = planY * plan.PLAN_CELL_SIZE + Std.int(plan.PLAN_CELL_SIZE / 2);
      return plan.sampleDensityAtPixel(px, py) < plan.ROAD2_MIN_CITY_DENSITY;
    }
}
