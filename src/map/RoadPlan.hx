// active ROAD1/ROAD2/ROAD3/ROAD4/ROAD5 plan-grid generator and connector logic

package map;

import _AreaType;
import const.WorldConst;
#if electron
import js.node.Fs;
#end
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
      Fs.writeFileSync('region_roads.txt', lines.join('\n') + '\n');
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
          thinCoverage.pruneOrphanRoad3Components(grid);
#if mydebug
          phaseStartTS = nextMapProfileTimestamp('road.pruneOrphanRoad3Components', phaseStartTS);
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
      thinCoverage.ensureSpecialAreaRoadCoverage(grid);
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('road.ensureSpecialAreaRoadCoverage', phaseStartTS);
#end

      var result = gridOps.compressRoadPlanGrid(grid);
#if electron
      dumpRoadPlan(grid, result);
#end
#if mydebug
      phaseStartTS = nextMapProfileTimestamp('road.compressRoadPlanGrid', phaseStartTS);
      traceMapProfileSummary('road.dump=region_roads.txt');
      traceMapProfileSummary('road.summary segments=' + result.length +
        ' plan=' + planWidth + 'x' + planHeight);
      traceMapProfileSamples();
      traceMapProfileCounters();
      nextMapProfileTimestamp('road.total', totalStartTS);
#end
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

// return a centered ROAD1 line shifted away from blocked area cells
  function pickCenteredRoad1Line(horizontal: Bool): Int
    {
      var limit = (horizontal ? planHeight : planWidth);
      var jitter = clampInt(Std.int(limit / 10), 4, PLAN_CELLS_PER_TILE * 2);
      return pickRoad1LineAvoidingBlockedAreas(horizontal, jitter, 'road1.primary');
    }

// return a centered ROAD1 branch coordinate shifted away from blocked area cells
  function pickCenteredRoad1Branch(primaryHorizontal: Bool): Int
    {
      var limit = (primaryHorizontal ? planWidth : planHeight);
      var jitter = clampInt(Std.int(limit / 12), 3, PLAN_CELLS_PER_TILE * 2);
      return pickRoad1LineAvoidingBlockedAreas(!primaryHorizontal, jitter, 'road1.branch');
    }

// return the nearest centered ROAD1 line that avoids blocked area cells when possible
  function pickRoad1LineAvoidingBlockedAreas(horizontal: Bool, jitter: Int, profileLabel: String): Int
    {
      var limit = (horizontal ? planHeight : planWidth);
      var targetLine = clampInt(Std.int(limit / 2) + randomRangeInt(-jitter, jitter),
        1, limit - 2);
      var bestLine = targetLine;
      var bestHitCount = countRoad1BlockedAreaHits(horizontal, targetLine);
      var bestOffset = 0;

      if (bestHitCount == 0)
        return targetLine;

      for (offset in 1...limit)
        {
          var lowerLine = targetLine - offset;
          if (lowerLine >= 1)
            {
              var lowerHitCount = countRoad1BlockedAreaHits(horizontal, lowerLine);
              if (lowerHitCount == 0)
                {
#if mydebug
                  addMapProfileCount(profileLabel + '.blockedAreaRerolls');
                  addMapProfileCount(profileLabel + '.shiftCells', offset);
#end
                  return lowerLine;
                }
              if (lowerHitCount < bestHitCount ||
                  (lowerHitCount == bestHitCount &&
                  offset < bestOffset))
                {
                  bestLine = lowerLine;
                  bestHitCount = lowerHitCount;
                  bestOffset = offset;
                }
            }

          var upperLine = targetLine + offset;
          if (upperLine <= limit - 2)
            {
              var upperHitCount = countRoad1BlockedAreaHits(horizontal, upperLine);
              if (upperHitCount == 0)
                {
#if mydebug
                  addMapProfileCount(profileLabel + '.blockedAreaRerolls');
                  addMapProfileCount(profileLabel + '.shiftCells', offset);
#end
                  return upperLine;
                }
              if (upperHitCount < bestHitCount ||
                  (upperHitCount == bestHitCount &&
                  offset < bestOffset))
                {
                  bestLine = upperLine;
                  bestHitCount = upperHitCount;
                  bestOffset = offset;
                }
            }
        }

#if mydebug
      addMapProfileCount(profileLabel + '.fallbacks');
      addMapProfileCount(profileLabel + '.fallbackBlockedAreaCells', bestHitCount);
#end
      return bestLine;
    }

// count how many blocked-area plan cells a 3-cell-wide ROAD1 line would cross
  function countRoad1BlockedAreaHits(horizontal: Bool, line: Int): Int
    {
      var hitCount = 0;

      if (horizontal)
        {
          var minY = clampInt(line - 1, 0, planHeight - 1);
          var maxY = clampInt(line + 1, 0, planHeight - 1);

          for (xx in 0...planWidth)
            for (yy in minY...maxY + 1)
              if (WorldConst.blocksRegionRoad1(gridOps.getAreaTypeAtPlanCell(xx, yy)))
                hitCount++;
          return hitCount;
        }

      var minX = clampInt(line - 1, 0, planWidth - 1);
      var maxX = clampInt(line + 1, 0, planWidth - 1);

      for (yy in 0...planHeight)
        for (xx in minX...maxX + 1)
          if (WorldConst.blocksRegionRoad1(gridOps.getAreaTypeAtPlanCell(xx, yy)))
            hitCount++;
      return hitCount;
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
            canSpawnThinCrossings: false,
            startDirectionMask: 0,
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
