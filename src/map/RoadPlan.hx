// active ROAD1/ROAD2/ROAD3/ROAD4/ROAD5 plan-grid generator and connector logic

package map;

import _AreaType;
import const.WorldConst;
import haxe.ds.StringMap;
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
      if (!Const.isDebug || !ROAD_PROFILE_VERBOSE)
        return;
      var total = (mapProfileTotalsMS.exists(label) ? mapProfileTotalsMS.get(label) : 0.0);
      var count = (mapProfileSampleCounts.exists(label) ? mapProfileSampleCounts.get(label) : 0);
      mapProfileTotalsMS.set(label, total + elapsedMS);
      mapProfileSampleCounts.set(label, count + 1);
    }

// accumulate one debug profiling counter
  function addMapProfileCount(label: String, amount: Int = 1)
    {
      if (!Const.isDebug || !ROAD_PROFILE_VERBOSE)
        return;
      var count = (mapProfileCounters.exists(label) ? mapProfileCounters.get(label) : 0);
      mapProfileCounters.set(label, count + amount);
    }

// trace one profiling phase and return a fresh timestamp
  function nextMapProfileTimestamp(label: String, startTS: Float): Float
    {
      if (!Const.isDebug)
        return 0;
      var nowTS = haxe.Timer.stamp() * 1000.0;
      profile('ROAD', label + ': ' + Std.int(nowTS - startTS) + ' ms');
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
          profile('ROAD', 'detail ' + label + ': ' + Std.int(total) +
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
        profile('ROAD', 'count ' + label + ': ' + mapProfileCounters.get(label));
    }

// trace one profiling summary line
  function traceMapProfileSummary(label: String)
    {
      profile('ROAD', label);
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

#if electron
// dump the generated road plan and final segments for one region map seed
  function dumpRoadPlan(grid: RoadPlanGrid, segments: Array<RoadSegment>)
    {
      var lines = [];
      lines.push('seed=' + mapSeed);
      lines.push('regionCells=' + regionWidth + 'x' + regionHeight);
      lines.push('fullCells=' + fullCellWidth + 'x' + fullCellHeight);
      lines.push('planCells=' + planWidth + 'x' + planHeight);
      lines.push('planCellsPerTile=' + PLAN_CELLS_PER_TILE);
      lines.push('roadSegments=' + segments.length);
      lines.push('areaLegend .=ground l=low m=medium h=downtown b=military f=facility s=sewers u=underground a=habitat c=corp');
      lines.push('roadLegend .=none 1=ROAD1 2=ROAD2 3=ROAD3 4=ROAD4 5=ROAD5 *=overlap');
      lines.push('attachmentLegend .=none a=empty attachment cell facing any road');
      lines.push('axisMaskLegend .=none 1=horizontal 2=vertical 3=both');
      lines.push('directionMaskLegend .=none hex masks use 1=left 2=right 4=up 8=down');
      lines.push('');
      lines.push('[area_types_full_cells]');
      appendAreaTypeDump(lines);
      lines.push('');
      lines.push('[road_tiles]');
      appendRoadTileDump(lines, grid);
      lines.push('');
      lines.push('[road_plan_cells]');
      appendRoadPlanDump(lines, grid);
      lines.push('');
      lines.push('[road_plan_attachment_cells]');
      appendRoadPlanAttachmentDump(lines, grid);
      lines.push('');
      lines.push('[road_plan_road2_axis_masks]');
      appendRoadPlanAxisMaskDump(lines, grid, ROAD2);
      lines.push('');
      lines.push('[road_plan_road3_direction_masks]');
      appendRoadPlanDirectionMaskDump(lines, grid, ROAD3);
      lines.push('');
      lines.push('[road_plan_road4_direction_masks]');
      appendRoadPlanDirectionMaskDump(lines, grid, ROAD4);
      lines.push('');
      lines.push('[road_plan_road5_direction_masks]');
      appendRoadPlanDirectionMaskDump(lines, grid, ROAD5);
      lines.push('');
      lines.push('[road_segments]');
      appendRoadSegmentDump(lines, segments);
      HostBridge.debugWriteRegionRoads(lines.join('\n') + '\n');
    }

// append one full-cell area-type dump to the output lines
  function appendAreaTypeDump(lines: Array<String>)
    {
      for (yy in 0...fullCellHeight)
        {
          var row = [];
          for (xx in 0...fullCellWidth)
            row.push(getRoadDumpAreaChar(areaTypes[xx][yy]));
          lines.push(row.join(''));
        }
    }

// append one region-tile road coverage dump to the output lines
  function appendRoadTileDump(lines: Array<String>, grid: RoadPlanGrid)
    {
      for (yy in 0...fullCellHeight)
        {
          var row = [];
          for (xx in 0...fullCellWidth)
            row.push(getRoadDumpTileChar(grid, xx, yy));
          lines.push(row.join(''));
        }
    }

// append one plan-cell road-tier dump to the output lines
  function appendRoadPlanDump(lines: Array<String>, grid: RoadPlanGrid)
    {
      for (yy in 0...planHeight)
        {
          var row = [];
          for (xx in 0...planWidth)
            row.push(getRoadDumpPlanChar(grid, xx, yy));
          lines.push(row.join(''));
        }
    }

// append one plan-cell attachment dump for any parent-road tier
  function appendRoadPlanAttachmentDump(lines: Array<String>, grid: RoadPlanGrid)
    {
      var parentTypes: Array<RoadType> = [ROAD1, ROAD2, ROAD3, ROAD4, ROAD5];

      for (yy in 0...planHeight)
        {
          var row = [];
          for (xx in 0...planWidth)
            row.push(gridOps.isThinRoadAttachmentCell(grid, xx, yy, parentTypes) ? 'a' : '.');
          lines.push(row.join(''));
        }
    }

// append one plan-cell axis-mask dump for one road tier
  function appendRoadPlanAxisMaskDump(lines: Array<String>, grid: RoadPlanGrid, type: RoadType)
    {
      for (yy in 0...planHeight)
        {
          var row = [];
          for (xx in 0...planWidth)
            row.push(getRoadDumpHexChar(gridOps.getRoadTypeAxisMaskAtPlanCell(grid, xx, yy, type)));
          lines.push(row.join(''));
        }
    }

// append one plan-cell direction-mask dump for one thin-road tier
  function appendRoadPlanDirectionMaskDump(lines: Array<String>, grid: RoadPlanGrid, type: RoadType)
    {
      for (yy in 0...planHeight)
        {
          var row = [];
          for (xx in 0...planWidth)
            row.push(getRoadDumpDirectionMaskChar(grid, xx, yy, type));
          lines.push(row.join(''));
        }
    }

// append one final road-segment list to the output lines
  function appendRoadSegmentDump(lines: Array<String>, segments: Array<RoadSegment>)
    {
      for (i in 0...segments.length)
        {
          var segment = segments[i];
          lines.push(i + ' ' + Std.string(segment.type) + ' ' +
            segment.x1 + ',' + segment.y1 + ' -> ' + segment.x2 + ',' + segment.y2);
        }
    }

// return one printable area-type marker for the road dump
  function getRoadDumpAreaChar(areaType: _AreaType): String
    {
      return switch (areaType) {
        case AREA_GROUND: '.';
        case AREA_CITY_LOW: 'l';
        case AREA_CITY_MEDIUM: 'm';
        case AREA_CITY_HIGH: 'h';
        case AREA_MILITARY_BASE: 'b';
        case AREA_FACILITY: 'f';
        case AREA_SEWERS: 's';
        case AREA_UNDERGROUND_LAB: 'u';
        case AREA_HABITAT: 'a';
        case AREA_CORP: 'c';
      };
    }

// return one printable road-tier marker for one region tile
  function getRoadDumpTileChar(grid: RoadPlanGrid, cellX: Int, cellY: Int): String
    {
      var matches = [];

      if (gridOps.hasRoadTypeInRegionTile(grid, cellX, cellY, ROAD1))
        matches.push('1');
      if (gridOps.hasRoadTypeInRegionTile(grid, cellX, cellY, ROAD2))
        matches.push('2');
      if (gridOps.hasRoadTypeInRegionTile(grid, cellX, cellY, ROAD3))
        matches.push('3');
      if (gridOps.hasRoadTypeInRegionTile(grid, cellX, cellY, ROAD4))
        matches.push('4');
      if (gridOps.hasRoadTypeInRegionTile(grid, cellX, cellY, ROAD5))
        matches.push('5');

      if (matches.length == 0)
        return '.';
      if (matches.length == 1)
        return matches[0];
      return '*';
    }

// return one printable direction-mask marker for one plan cell and road tier
  function getRoadDumpDirectionMaskChar(grid: RoadPlanGrid, planX: Int, planY: Int,
      type: RoadType): String
    {
      var mask = 0;

      if (gridOps.hasRoadTypeDirectionAtPlanCell(grid, planX, planY, -1, 0, type))
        mask = mask | 1;
      if (gridOps.hasRoadTypeDirectionAtPlanCell(grid, planX, planY, 1, 0, type))
        mask = mask | 2;
      if (gridOps.hasRoadTypeDirectionAtPlanCell(grid, planX, planY, 0, -1, type))
        mask = mask | 4;
      if (gridOps.hasRoadTypeDirectionAtPlanCell(grid, planX, planY, 0, 1, type))
        mask = mask | 8;

      return getRoadDumpHexChar(mask);
    }

// return one printable hex digit for one small road dump bitmask
  function getRoadDumpHexChar(mask: Int): String
    {
      if (mask <= 0)
        return '.';
      if (mask < 10)
        return Std.string(mask);
      return String.fromCharCode('a'.code + mask - 10);
    }

// return one printable road-tier marker for one plan cell
  function getRoadDumpPlanChar(grid: RoadPlanGrid, planX: Int, planY: Int): String
    {
      var matches = [];

      if (gridOps.hasRoadTypeAtPlanCell(grid, planX, planY, ROAD1))
        matches.push('1');
      if (gridOps.hasRoadTypeAtPlanCell(grid, planX, planY, ROAD2))
        matches.push('2');
      if (gridOps.hasRoadTypeAtPlanCell(grid, planX, planY, ROAD3))
        matches.push('3');
      if (gridOps.hasRoadTypeAtPlanCell(grid, planX, planY, ROAD4))
        matches.push('4');
      if (gridOps.hasRoadTypeAtPlanCell(grid, planX, planY, ROAD5))
        matches.push('5');

      if (matches.length == 0)
        return '.';
      if (matches.length == 1)
        return matches[0];
      return '*';
    }
#end

  function generateRoadGraph(): Array<RoadSegment>
    {
      var totalStartTS = 0.0;
      var phaseStartTS = 0.0;
      if (Const.isDebug)
        {
          totalStartTS = haxe.Timer.stamp() * 1000.0;
          phaseStartTS = totalStartTS;
          resetMapProfileStats();
        }
      initRoadPlanHelpers();
      phaseStartTS = nextMapProfileTimestamp('road.initRoadPlanHelpers', phaseStartTS);
      var grid = gridOps.makeRoadPlanGrid();
      phaseStartTS = nextMapProfileTimestamp('road.makeRoadPlanGrid', phaseStartTS);
      // the ROAD1 trunk decision lives in map.Highway, because area generation needs the same answer
      // with no map.Image to ask. `rng` is handed over rather than reproduced, so the draw sequence
      // is unchanged — see that class's header
      var road1 = Highway.lines({
        rng: rng,
        planWidth: planWidth,
        planHeight: planHeight,
        cellsPerTile: PLAN_CELLS_PER_TILE,
        blocked: function(px, py)
          return WorldConst.blocksRegionRoad1(gridOps.getAreaTypeAtPlanCell(px, py)),
        count: function(label, amount) addMapProfileCount(label, amount),
      });
      var primaryHorizontal = road1.primaryHorizontal;
      var primaryLine = road1.primaryLine;
      var primaryWalker = makePrimaryRoad1Walker(primaryHorizontal, primaryLine);
      var sideWalker = makeSideRoad1Walker(primaryHorizontal, primaryLine,
        road1.branchLine, road1.branchSign);

      walkRoad1(grid, cloneRoadWalker(primaryWalker));
      walkRoad1(grid, cloneRoadWalker(sideWalker));
      phaseStartTS = nextMapProfileTimestamp('road.walkRoad1', phaseStartTS);
      spawnRoad2AlongRoad1(grid, cloneRoadWalker(primaryWalker));
      spawnRoad2AlongRoad1(grid, cloneRoadWalker(sideWalker));
      phaseStartTS = nextMapProfileTimestamp('road.spawnRoad2AlongRoad1', phaseStartTS);
      road2Network.ensureRoad2Connectivity(grid);
      phaseStartTS = nextMapProfileTimestamp('road.ensureRoad2Connectivity.initial', phaseStartTS);
      road2Network.ensureCityRoad2Coverage(grid);
      phaseStartTS = nextMapProfileTimestamp('road.ensureCityRoad2Coverage', phaseStartTS);
      road2Network.ensureRoad2Connectivity(grid);
      phaseStartTS = nextMapProfileTimestamp('road.ensureRoad2Connectivity.final', phaseStartTS);
      if (ENABLE_ROAD3_COVERAGE_PASS)
        {
          thinCoverage.ensureCityRoad3Coverage(grid);
          phaseStartTS = nextMapProfileTimestamp('road.ensureCityRoad3Coverage', phaseStartTS);
          thinCoverage.pruneOrphanRoad3Components(grid);
          phaseStartTS = nextMapProfileTimestamp('road.pruneOrphanRoad3Components', phaseStartTS);
        }
      thinCoverage.ensureCityRoad4Coverage(grid);
      phaseStartTS = nextMapProfileTimestamp('road.ensureCityRoad4Coverage', phaseStartTS);
      thinCoverage.ensureCityRoad5Coverage(grid);
      phaseStartTS = nextMapProfileTimestamp('road.ensureCityRoad5Coverage', phaseStartTS);
      thinCoverage.ensureSpecialAreaRoadCoverage(grid);
      phaseStartTS = nextMapProfileTimestamp('road.ensureSpecialAreaRoadCoverage', phaseStartTS);

      roadPlanGrid = grid;
      var result = gridOps.compressRoadPlanGrid(grid);
#if electron
      if (Const.isDebug)
        dumpRoadPlan(grid, result);
#end
      if (Const.isDebug)
        {
          phaseStartTS = nextMapProfileTimestamp('road.compressRoadPlanGrid', phaseStartTS);
          traceMapProfileSummary('road.dump=region_roads.txt');
          traceMapProfileSummary('road.summary segments=' + result.length +
            ' plan=' + planWidth + 'x' + planHeight);
          if (ROAD_PROFILE_VERBOSE)
            {
              traceMapProfileSamples();
              traceMapProfileCounters();
            }
          nextMapProfileTimestamp('road.total', totalStartTS);
        }
      return result;
    }

// return whether one thin-road tier may use this area type
  function canThinRoadUseAreaType(type: RoadType, areaType: _AreaType): Bool
    {
      return switch (type) {
        case ROAD5: areaType != AREA_CITY_HIGH;
        default: true;
      };
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
            canSpawnThinCrossings: false,
            startDirectionMask: 0,
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
        canSpawnThinCrossings: false,
        startDirectionMask: 0,
        road2ID: -1,
        type: ROAD1,
      };
    }

// build the side ROAD1 walker configuration. the branch line and its direction are picked in
// map.Highway with the trunk's, so this is a pure builder
  function makeSideRoad1Walker(primaryHorizontal: Bool, primaryLine: Int, branchLine: Int,
      branchSign: Int): RoadWalker
    {
      if (primaryHorizontal)
        {
          var branchX = branchLine;
          var branchDy = branchSign;
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
            canSpawnThinCrossings: false,
            startDirectionMask: 0,
            road2ID: -1,
            type: ROAD1,
          };
        }

      var branchY = branchLine;
      var branchDx = branchSign;
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
        canSpawnThinCrossings: false,
        startDirectionMask: 0,
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
        canSpawnThinCrossings: walker.canSpawnThinCrossings,
        startDirectionMask: walker.startDirectionMask,
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
