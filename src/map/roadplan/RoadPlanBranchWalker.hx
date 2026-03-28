// road-plan branch spawning and walker movement helpers

package map.roadplan;

import map.RoadPlan;
import map.RoadType;
import map.Types.GridPoint;
import map.Types.RoadBranchStart;
import map.Types.RoadPlanGrid;
import map.Types.RoadWalker;

@:access(map.Core)
@:access(map.Ground)
@:access(map.Raster)
@:access(map.RoadPlan)
class RoadPlanBranchWalker
{
  var plan: RoadPlan;
  var gridOps: RoadPlanGridOps;
  var road2Network: RoadPlanRoad2Network;

  public function new(plan: RoadPlan, gridOps: RoadPlanGridOps,
      road2Network: RoadPlanRoad2Network)
    {
      this.plan = plan;
      this.gridOps = gridOps;
      this.road2Network = road2Network;
    }

// build one thin-road walker config from one start and direction
  public function makeThinRoadWalker(startX: Int, startY: Int, dx: Int, dy: Int, type: RoadType,
      tSplitCountdown: Int = -1, canSpawnRoad4Crossings: Bool = false,
      startDirectionMask: Int = 0): RoadWalker
    {
      return {
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
        groundBlockCount: 0,
        localStopCount: getThinRoadLocalStopStart(type),
        tSplitCountdown: tSplitCountdown,
        canSpawnRoad4Crossings: canSpawnRoad4Crossings,
        startDirectionMask: startDirectionMask,
        road2ID: -1,
        type: type,
      };
    }

// return the starting local stop counter for capped thin-road walkers
  function getThinRoadLocalStopStart(type: RoadType): Int
    {
      if (type != ROAD4 &&
          type != ROAD5)
        return -1;

      var rampSteps = Std.int(Math.ceil(1.0 / plan.ROAD3_GROUND_STOP_CHANCE_STEP));
      var maxSteps = plan.PLAN_CELLS_PER_TILE * 2;
      var jitter = plan.randomRangeInt(0, Std.int(plan.PLAN_CELLS_PER_TILE / 3));
      return -(maxSteps - rampSteps) + jitter;
    }

// try spawning ROAD2 branches on both sides of one ROAD1 step
  public function trySpawnRoad2Branches(grid: RoadPlanGrid, walker: RoadWalker): Bool
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
      if (plan.rng.nextFloat() >= maxChance)
        return false;

      if (starts.length >= 2 &&
          plan.rng.nextFloat() < 0.70)
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
          var pick = plan.rng.nextFloat() * totalChance;
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
      if (!plan.isCityAreaType(gridOps.getAreaTypeAtPlanCell(start.x, start.y)))
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
      start = road2Network.snapRoad2Anchor(start.x, start.y);
      if (!road2Network.canUseRoad2Start(grid, start.x, start.y, branchDx, branchDy,
            road1StartX, road1StartY) ||
          !road2Network.canBuildRoad2Road1Bridge(grid, road1StepX, road1StepY, start.x,
            start.y, branchDx, branchDy))
        return;

      var road2ID = plan.nextRoad2ID++;
      road2Network.addRoad2Road1Bridge(grid, road1StepX, road1StepY, start.x, start.y,
        branchDx, branchDy, road2ID);
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
        groundBlockCount: 0,
        localStopCount: -1,
        tSplitCountdown: -1,
        canSpawnRoad4Crossings: false,
        startDirectionMask: 0,
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
          var anchor = road2Network.getRoad2AnchorFromRoad1Step(baseX, baseY, dx, dy);
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

      while (gridOps.isInPlanBounds(planX, planY))
        {
          if (road2Network.canUseRoad2Start(grid, planX, planY, dx, dy,
                road1StartX, road1StartY) &&
              (type != ROAD2 ||
              road2Network.canBuildRoad2Road1Bridge(grid, baseX, baseY, planX, planY, dx, dy)))
            {
              return {
                x: planX,
                y: planY,
              };
            }
          if (type == ROAD2)
            {
              planX += dx * plan.ROAD2_GRID_STEP;
              planY += dy * plan.ROAD2_GRID_STEP;
            }
          else
            {
              planX += dx;
              planY += dy;
            }
        }

      return null;
    }

// return the minimum branch-root offset in plan cells for one road tier
  function getRoadBranchRootClearance(type: RoadType): Int
    {
      if (type == ROAD2)
        return 2;

      var style = plan.getRoadStyle(type);
      var radius = style.coreWidth / 2.0 + style.shoulderWidth + style.featherWidth;
      return plan.clampInt(Std.int(Math.ceil(radius / plan.PLAN_CELL_SIZE)) + 1, 2, 5);
    }

// return the ROAD2 branch chance for one adjacent plan cell
  function getRoad2BranchChance(planX: Int, planY: Int): Float
    {
      return switch (gridOps.getAreaTypeAtPlanCell(planX, planY)) {
        case AREA_CITY_LOW, AREA_CITY_MEDIUM, AREA_CITY_HIGH: 0.70;
        default: 0.0;
      };
    }

// walk one ROAD2 or thin-road branch with turns, stops, and downgrades
  public function walkBranchRoad(grid: RoadPlanGrid, walker: RoadWalker)
    {
#if mydebug
      var profileLabel = 'branch.walkBranchRoad.' + Std.string(walker.type);
      var profileStartTS = haxe.Timer.stamp() * 1000.0;

// flush one branch-walk profiling sample before returning
      function finishWalkBranchRoadProfile(reason: String)
        {
          plan.addMapProfileSample(profileLabel, haxe.Timer.stamp() * 1000.0 - profileStartTS);
          plan.addMapProfileCount(profileLabel + '.exit.' + reason);
        }
#end
      if (walker.type == ROAD2)
        {
          var snapped = road2Network.snapRoad2Anchor(walker.x, walker.y);
          walker.x = snapped.x;
          walker.y = snapped.y;
          gridOps.addRoad2PlanStamp(grid, walker.x, walker.y, walker.road2ID,
            gridOps.getRoadAxisMask(walker.dx, walker.dy));
        }
      else if (walker.startDirectionMask != 0)
        gridOps.addRoadPlanDirectionMask(grid, walker.x, walker.y,
          walker.startDirectionMask, walker.type);
      else
        gridOps.addRoadPlanAxis(grid, walker.x, walker.y, walker.dx, walker.dy, walker.type);
      while (true)
        {
          var nextX = walker.x + (walker.type == ROAD2 ? walker.dx * plan.ROAD2_GRID_STEP : walker.dx);
          var nextY = walker.y + (walker.type == ROAD2 ? walker.dy * plan.ROAD2_GRID_STEP : walker.dy);
          if (!gridOps.isInPlanBounds(nextX, nextY))
            {
#if mydebug
              finishWalkBranchRoadProfile('outOfBounds');
#end
            return;
            }
          if ((walker.type == ROAD2 &&
              (gridOps.doesRoad2FootprintHitAnyRoad(grid, nextX, nextY, walker.x, walker.y) ||
              gridOps.hasRoad2ClearanceConflict(grid, nextX, nextY, walker.road2ID))) ||
              (walker.type != ROAD2 &&
              (gridOps.isPlanCellOccupied(grid, nextX, nextY) ||
              gridOps.hasParallelRoadFlankConflict(grid, nextX, nextY, walker.dx, walker.dy))))
            {
#if mydebug
              finishWalkBranchRoadProfile('blocked');
#end
            return;
            }
          var stopAfterPaint = isThinRoadType(walker.type) &&
            gridOps.hasAdjacentRoadNeighbor(grid, nextX, nextY, walker.x, walker.y);

          var nextArea = gridOps.getAreaTypeAtPlanCell(nextX, nextY);
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
              plan.rng.nextFloat() < 0.12 &&
              trySpawnRoadTurnBranch(grid, walker, ROAD3))
            {
              drawType = ROAD2;
            }
          else if (walker.type == ROAD2 &&
              shouldTurnRoadWalker(walker))
            trySpawnRoadTurnBranch(grid, walker, ROAD2);
          else if (!stopAfterPaint &&
              shouldTurnRoadWalker(walker))
            turned = tryTurnRoadWalker(grid, walker);

          if (drawType == ROAD2)
            gridOps.addRoad2PlanStamp(grid, walker.x, walker.y, walker.road2ID,
              gridOps.getRoadAxisMask(walker.dx, walker.dy));
          else if (turned)
            gridOps.addRoadPlanCorner(grid, walker.x, walker.y, oldDx, oldDy, walker.dx,
              walker.dy, drawType);
          else
            gridOps.addRoadPlanAxis(grid, walker.x, walker.y, oldDx, oldDy, drawType);

          if (stopAfterPaint)
            {
#if mydebug
              finishWalkBranchRoadProfile('stopAfterPaint');
#end
            return;
            }

          if (walker.tSplitCountdown >= 0)
            {
              walker.tSplitCountdown--;
              if (walker.tSplitCountdown <= 0)
                {
                  spawnRoad3TSplit(grid, walker);
 #if mydebug
                  finishWalkBranchRoadProfile('tSplit');
#end
                  return;
                }
            }

          if (shouldSpawnRoad4Crossing(walker, nextArea))
            trySpawnRoad4Crossing(grid, walker);

          if (walker.stopLockSteps > 0)
            {
              walker.stopLockSteps--;
              continue;
            }
          if (walker.type == ROAD2 &&
              road2Network.isRoad2GroundAtPlanCell(nextX, nextY))
            {
#if mydebug
              finishWalkBranchRoadProfile('road2Ground');
#end
            return;
            }
          if (isThinRoadType(walker.type))
            {
              if (walker.localStopCount >= 0)
                {
                  walker.localStopCount++;
                  if (plan.rng.nextFloat() < Math.min(1.0,
                      walker.localStopCount * plan.ROAD3_GROUND_STOP_CHANCE_STEP))
                    {
#if mydebug
                      finishWalkBranchRoadProfile('thinLocalStop');
#end
                    return;
                    }
                }
              if (plan.isCityAreaType(nextArea))
                walker.groundBlockCount = 0;
              else
                {
                  walker.groundBlockCount++;
                  if (plan.rng.nextFloat() < Math.min(1.0,
                      walker.groundBlockCount * plan.ROAD3_GROUND_STOP_CHANCE_STEP))
                    {
#if mydebug
                      finishWalkBranchRoadProfile('thinGroundStop');
#end
                    return;
                    }
                }
              continue;
            }
          if (!plan.isCityAreaType(nextArea))
            {
#if mydebug
              finishWalkBranchRoadProfile('leftCity');
#end
            return;
            }
        }
    }

// return whether one road tier uses the shared thin-road rules
  function isThinRoadType(type: RoadType): Bool
    {
      return switch (type) {
        case ROAD3, ROAD4, ROAD5: true;
        default: false;
      };
    }

// try spawning a branch off one ROAD2 step instead of turning the parent
  function trySpawnRoadTurnBranch(grid: RoadPlanGrid, walker: RoadWalker,
      branchType: RoadType): Bool
    {
      var leftDx = walker.dy;
      var leftDy = -walker.dx;
      var rightDx = -walker.dy;
      var rightDy = walker.dx;
      var tryLeftFirst = plan.rng.nextFloat() < 0.5;

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

      var startX = walker.x + dx * plan.ROAD2_GRID_STEP;
      var startY = walker.y + dy * plan.ROAD2_GRID_STEP;
      if (!gridOps.isInPlanBounds(startX, startY))
        return false;

      if (branchType == ROAD2)
        {
          var snapped = road2Network.snapRoad2Anchor(startX, startY);
          startX = snapped.x;
          startY = snapped.y;
          if (!road2Network.canUseRoad2Start(grid, startX, startY, dx, dy, -1, -1, walker.road2ID))
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
            groundBlockCount: 0,
            localStopCount: -1,
            tSplitCountdown: -1,
            canSpawnRoad4Crossings: false,
            startDirectionMask: 0,
            road2ID: walker.road2ID,
            type: ROAD2,
          });
          return true;
        }

      if (!canUseBranchRoadStart(grid, startX, startY, dx, dy))
        return false;

      walkBranchRoad(grid, makeThinRoadWalker(startX, startY, dx, dy, branchType));
      return true;
    }

// spawn the perpendicular green branches for one forced T split
  function spawnRoad3TSplit(grid: RoadPlanGrid, walker: RoadWalker)
    {
      if (walker.type != ROAD3)
        return;

      var leftDx = walker.dy;
      var leftDy = -walker.dx;
      var rightDx = -walker.dy;
      var rightDy = walker.dx;

      if (canUseBranchRoadStart(grid, walker.x, walker.y, leftDx, leftDy, true))
        walkBranchRoad(grid, makeThinRoadWalker(walker.x, walker.y, leftDx, leftDy, ROAD3));
      if (canUseBranchRoadStart(grid, walker.x, walker.y, rightDx, rightDy, true))
        walkBranchRoad(grid, makeThinRoadWalker(walker.x, walker.y, rightDx, rightDy, ROAD3));
    }

// return whether one parent ROAD4 walker should try spawning a crossing this step
  function shouldSpawnRoad4Crossing(walker: RoadWalker, nextArea: _AreaType): Bool
    {
      return walker.type == ROAD4 &&
        walker.canSpawnRoad4Crossings &&
        plan.isCityAreaType(nextArea) &&
        walker.stepsSinceTurn > 0 &&
        walker.stepsSinceTurn % plan.ROAD4_CROSSING_INTERVAL == 0;
    }

// try spawning one ROAD4 crossing branch from the current parent road
  function trySpawnRoad4Crossing(grid: RoadPlanGrid, walker: RoadWalker): Bool
    {
      var roll = plan.rng.nextFloat();
      if (roll >= plan.ROAD4_CROSSING_RIGHT_CHANCE + plan.ROAD4_CROSSING_LEFT_CHANCE)
        return false;

      var dx = 0;
      var dy = 0;
      if (roll < plan.ROAD4_CROSSING_RIGHT_CHANCE)
        {
          dx = -walker.dy;
          dy = walker.dx;
#if mydebug
          plan.addMapProfileCount('branch.walkBranchRoad.ROAD4.crossingRoll.right');
#end
        }
      else
        {
          dx = walker.dy;
          dy = -walker.dx;
#if mydebug
          plan.addMapProfileCount('branch.walkBranchRoad.ROAD4.crossingRoll.left');
#end
        }

      if (!canUseBranchRoadStart(grid, walker.x, walker.y, dx, dy, true))
        {
#if mydebug
          plan.addMapProfileCount('branch.walkBranchRoad.ROAD4.crossingBlocked');
#end
          return false;
        }

      walkBranchRoad(grid, makeThinRoadWalker(walker.x, walker.y, dx, dy, ROAD4, -1, false,
        gridOps.getRoadDirectionMask(dx, dy)));
#if mydebug
      plan.addMapProfileCount('branch.walkBranchRoad.ROAD4.crossingSpawned');
#end
      return true;
    }

// return whether one non-ROAD2 branch can start and move one step
  public function canUseBranchRoadStart(grid: RoadPlanGrid, planX: Int, planY: Int,
      dx: Int, dy: Int, allowOccupiedStart: Bool = false): Bool
    {
      var nextX = planX + dx;
      var nextY = planY + dy;
      return (allowOccupiedStart ||
        !gridOps.isPlanCellOccupied(grid, planX, planY)) &&
        gridOps.isInPlanBounds(nextX, nextY) &&
        !gridOps.isPlanCellOccupied(grid, nextX, nextY) &&
        !gridOps.hasParallelRoadFlankConflict(grid, planX, planY, dx, dy) &&
        !gridOps.hasParallelRoadFlankConflict(grid, nextX, nextY, dx, dy);
    }

// return whether one branch walker should try a spontaneous turn
  function shouldTurnRoadWalker(walker: RoadWalker): Bool
    {
      if (!canRoadWalkerTurn(walker))
        return false;
      if (walker.tSplitCountdown >= 0)
        return false;

      return switch (walker.type) {
        case ROAD2: plan.rng.nextFloat() < 0.30;
        case ROAD3: plan.rng.nextFloat() < 0.06;
        case ROAD4, ROAD5: false;
        default: false;
      };
    }

// return whether one branch walker is allowed to turn yet
  function canRoadWalkerTurn(walker: RoadWalker): Bool
    {
      return walker.stepsSinceTurn >= plan.ROAD_BRANCH_MIN_TURN_STEPS &&
        walker.stepsSinceTurn % plan.PLAN_CELLS_PER_TILE == 0;
    }

// try turning one branch walker and mark the corner cell on the new axis
  function tryTurnRoadWalker(grid: RoadPlanGrid, walker: RoadWalker): Bool
    {
      var leftDx = walker.dy;
      var leftDy = -walker.dx;
      var rightDx = -walker.dy;
      var rightDy = walker.dx;
      var tryLeftFirst = plan.rng.nextFloat() < 0.5;

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

      var nextX = walker.x + (walker.type == ROAD2 ? dx * plan.ROAD2_GRID_STEP : dx);
      var nextY = walker.y + (walker.type == ROAD2 ? dy * plan.ROAD2_GRID_STEP : dy);
      if (!gridOps.isInPlanBounds(nextX, nextY))
        return false;

      if (walker.type != ROAD2)
        {
          return !gridOps.isPlanCellOccupied(grid, nextX, nextY) &&
            !gridOps.hasParallelRoadFlankConflict(grid, walker.x, walker.y, dx, dy) &&
            !gridOps.hasParallelRoadFlankConflict(grid, nextX, nextY, dx, dy);
        }

      return !gridOps.doesRoad2FootprintHitAnyRoad(grid, nextX, nextY, walker.x, walker.y) &&
        !gridOps.hasRoad2ClearanceConflict(grid, nextX, nextY, walker.road2ID);
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
}
