// active ROAD1/ROAD2/ROAD3/ROAD4/ROAD5 plan-grid generator and connector logic

package map;

#if mydebug
import haxe.ds.StringMap;
#end
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

#if mydebug
  var mapProfileTotalsMS: StringMap<Float>;
  var mapProfileSampleCounts: StringMap<Int>;
  var mapProfileCounters: StringMap<Int>;

// reset the aggregated debug profiling state for one road generation
  function resetMapProfileStats()
    {
      mapProfileTotalsMS = new StringMap();
      mapProfileSampleCounts = new StringMap();
      mapProfileCounters = new StringMap();
    }

// accumulate one debug profiling sample
  function addMapProfileSample(label: String, elapsedMS: Float)
    {
      var total = (mapProfileTotalsMS.exists(label) ? mapProfileTotalsMS.get(label) : 0.0);
      var count = (mapProfileSampleCounts.exists(label) ? mapProfileSampleCounts.get(label) : 0);
      mapProfileTotalsMS.set(label, total + elapsedMS);
      mapProfileSampleCounts.set(label, count + 1);
    }

// accumulate one debug profiling counter
  function addMapProfileCount(label: String, amount: Int = 1)
    {
      var count = (mapProfileCounters.exists(label) ? mapProfileCounters.get(label) : 0);
      mapProfileCounters.set(label, count + amount);
    }

// trace one profiling phase and return a fresh timestamp
  function nextMapProfileTimestamp(label: String, startTS: Float): Float
    {
      var nowTS = haxe.Timer.stamp() * 1000.0;
      trace('MAP PROFILE ' + label + ': ' + Std.int(nowTS - startTS) + ' ms');
      return nowTS;
    }

// trace the aggregated debug profiling samples
  function traceMapProfileSamples()
    {
      var labels = [];

      for (label in mapProfileTotalsMS.keys())
        labels.push(label);
      labels.sort(sortMapProfileLabels);

      for (label in labels)
        {
          var total = mapProfileTotalsMS.get(label);
          var count = mapProfileSampleCounts.get(label);
          var avg = Math.round(total * 100.0 / count) / 100.0;
          trace('MAP PROFILE detail ' + label + ': ' + Std.int(total) +
            ' ms over ' + count + ' calls avg=' + avg + ' ms');
        }
    }

// trace the aggregated debug profiling counters
  function traceMapProfileCounters()
    {
      var labels = [];

      for (label in mapProfileCounters.keys())
        labels.push(label);
      labels.sort(sortMapProfileLabels);

      for (label in labels)
        trace('MAP PROFILE count ' + label + ': ' + mapProfileCounters.get(label));
    }

// trace one profiling summary line
  function traceMapProfileSummary(label: String)
    {
      trace('MAP PROFILE ' + label);
    }

// sort two profiling labels for stable debug output
  function sortMapProfileLabels(a: String, b: String): Int
    {
      if (a < b)
        return -1;
      if (a > b)
        return 1;
      return 0;
    }
#else
// ignore one profiling sample outside debug builds
  inline function addMapProfileSample(label: String, elapsedMS: Float)
    {
    }

// ignore one profiling counter outside debug builds
  inline function addMapProfileCount(label: String, amount: Int = 1)
    {
    }
#end

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
#if mydebug
      var totalStartTS = haxe.Timer.stamp() * 1000.0;
      var phaseStartTS = totalStartTS;
      resetMapProfileStats();
#end
      initRoadPlanHelpers();
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('road.initRoadPlanHelpers', phaseStartTS);
#end
      var grid = gridOps.makeRoadPlanGrid();
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('road.makeRoadPlanGrid', phaseStartTS);
#end
      var primaryHorizontal = rng.nextFloat() < 0.5;
      var primaryLine = pickCenteredRoad1Line(primaryHorizontal);
      var primaryWalker = makePrimaryRoad1Walker(primaryHorizontal, primaryLine);
      var sideWalker = makeSideRoad1Walker(primaryHorizontal, primaryLine);

      walkRoad1(grid, cloneRoadWalker(primaryWalker));
      walkRoad1(grid, cloneRoadWalker(sideWalker));
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('road.walkRoad1', phaseStartTS);
#end
      spawnRoad2AlongRoad1(grid, cloneRoadWalker(primaryWalker));
      spawnRoad2AlongRoad1(grid, cloneRoadWalker(sideWalker));
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('road.spawnRoad2AlongRoad1', phaseStartTS);
#end
      road2Network.ensureRoad2Connectivity(grid);
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('road.ensureRoad2Connectivity.initial', phaseStartTS);
#end
      road2Network.ensureCityRoad2Coverage(grid);
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('road.ensureCityRoad2Coverage', phaseStartTS);
#end
      road2Network.ensureRoad2Connectivity(grid);
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('road.ensureRoad2Connectivity.final', phaseStartTS);
#end
      if (ENABLE_ROAD3_COVERAGE_PASS)
        {
          thinCoverage.ensureCityRoad3Coverage(grid);
#if mydebug
          phaseStartTS = nextMapProfileTimestamp('road.ensureCityRoad3Coverage', phaseStartTS);
#end
        }
      thinCoverage.ensureCityRoad4Coverage(grid);
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('road.ensureCityRoad4Coverage', phaseStartTS);
#end
      thinCoverage.ensureCityRoad5Coverage(grid);
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('road.ensureCityRoad5Coverage', phaseStartTS);
#end

      var result = gridOps.compressRoadPlanGrid(grid);
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('road.compressRoadPlanGrid', phaseStartTS);
      traceMapProfileSummary('road.summary segments=' + result.length +
        ' plan=' + planWidth + 'x' + planHeight);
      traceMapProfileSamples();
      traceMapProfileCounters();
      nextMapProfileTimestamp('road.total', totalStartTS);
#end
      return result;
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
