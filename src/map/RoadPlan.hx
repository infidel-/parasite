// active ROAD1/ROAD2/ROAD3/ROAD4/ROAD5 plan-grid generator and connector logic

package map;

import map.RoadType;
import map.Types.RoadPlanGrid;
import map.Types.RoadSegment;
import map.Types.RoadWalker;
import map.roadplan.RoadPlanBranchWalker;
import map.roadplan.RoadPlanGridOps;
import map.roadplan.RoadPlanRoad2Network;
import map.roadplan.RoadPlanThinCoverage;

class RoadPlan extends Raster
{
  var gridOps: RoadPlanGridOps;
  var road2Network: RoadPlanRoad2Network;
  var branchWalker: RoadPlanBranchWalker;
  var thinCoverage: RoadPlanThinCoverage;

// initialize the helper classes used by the road-plan pipeline
  function initRoadPlanHelpers()
    {
      if (gridOps != null)
        return;

      gridOps = new RoadPlanGridOps(this);
      road2Network = new RoadPlanRoad2Network(this, gridOps);
      branchWalker = new RoadPlanBranchWalker(this, gridOps, road2Network);
      thinCoverage = new RoadPlanThinCoverage(this, gridOps, branchWalker);
    }

  function generateRoadGraph(): Array<RoadSegment>
    {
      initRoadPlanHelpers();

      var grid = gridOps.makeRoadPlanGrid();
      var primaryHorizontal = rng.nextFloat() < 0.5;
      var primaryLine = pickCenteredRoad1Line(primaryHorizontal);
      var primaryWalker = makePrimaryRoad1Walker(primaryHorizontal, primaryLine);
      var sideWalker = makeSideRoad1Walker(primaryHorizontal, primaryLine);

      walkRoad1(grid, cloneRoadWalker(primaryWalker));
      walkRoad1(grid, cloneRoadWalker(sideWalker));
      spawnRoad2AlongRoad1(grid, cloneRoadWalker(primaryWalker));
      spawnRoad2AlongRoad1(grid, cloneRoadWalker(sideWalker));
      road2Network.ensureRoad2Connectivity(grid);
      road2Network.ensureCityRoad2Coverage(grid);
      road2Network.ensureRoad2Connectivity(grid);
      if (ENABLE_ROAD3_COVERAGE_PASS)
        thinCoverage.ensureCityRoad3Coverage(grid);
      thinCoverage.ensureCityRoad4Coverage(grid);
      thinCoverage.ensureCityRoad5Coverage(grid);

      return gridOps.compressRoadPlanGrid(grid);
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
            groundBlockCount: 0,
            localStopCount: -1,
            tSplitCountdown: -1,
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
        groundBlockCount: 0,
        localStopCount: -1,
        tSplitCountdown: -1,
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
            groundBlockCount: 0,
            localStopCount: -1,
            tSplitCountdown: -1,
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
        groundBlockCount: 0,
        localStopCount: -1,
        tSplitCountdown: -1,
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
        groundBlockCount: walker.groundBlockCount,
        localStopCount: walker.localStopCount,
        tSplitCountdown: walker.tSplitCountdown,
        road2ID: walker.road2ID,
        type: walker.type,
      };
    }

// walk one straight ROAD1 trunk without spawning branches
  function walkRoad1(grid: RoadPlanGrid, walker: RoadWalker)
    {
      while (gridOps.isInPlanBounds(walker.x, walker.y))
        {
          gridOps.addRoadPlanAxis(grid, walker.x, walker.y, walker.dx, walker.dy, walker.type);
          walker.x += walker.dx;
          walker.y += walker.dy;
        }
    }

// spawn ROAD2 branches along one already-built ROAD1 trunk
  function spawnRoad2AlongRoad1(grid: RoadPlanGrid, walker: RoadWalker)
    {
      var stepIndex = 0;

      while (gridOps.isInPlanBounds(walker.x, walker.y))
        {
          if (stepIndex > 0 &&
              stepIndex % ROAD2_MIN_SPAWN_GAP == 0)
            branchWalker.trySpawnRoad2Branches(grid, walker);
          walker.x += walker.dx;
          walker.y += walker.dy;
          stepIndex++;
        }
    }
}
