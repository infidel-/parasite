// older unused road-generation helpers kept for future reuse

package map;

import game.*;
import map.RoadType;
import map.Types.BlockRect;
import map.Types.CityCoverageCandidate;
import map.Types.GridPoint;
import map.Types.LocalGraphAnchor;
import map.Types.LocalGraphCandidate;
import map.Types.RoadMasks;
import map.Types.RoadSegment;

class LegacyRoads extends RoadPlan
{
  function selectMainLines(isHorizontal: Bool): Array<Int>
    {
      var lineCount = (isHorizontal ? fullCellHeight : fullCellWidth);
      var baseDesired = clampInt(2 + Std.int(Math.floor(
        (isHorizontal ? regionHeight : regionWidth) / 18.0 +
        overallDensity * 1.8)), 2, 4);
      var desired = clampInt(Std.int(Math.ceil(baseDesired / 3.0)), 1, 1);
      var candidates = [];

      for (line in 1...lineCount - 1)
        {
          var score = getRoadLineScore(isHorizontal, line, true);
          candidates.push({ line: line, score: score });
        }

      candidates.sort(function(a, b)
        {
          if (a.score > b.score) return -1;
          if (a.score < b.score) return 1;
          return a.line - b.line;
        });

      var selected = [];
      var minSpacing = 6;
      if (overallDensity >= 0.62)
        minSpacing = 4;
      else if (overallDensity >= 0.40)
        minSpacing = 5;
      for (candidate in candidates)
        {
          if (selected.length >= desired)
            break;
          if (!isFarFromLines(candidate.line, selected, minSpacing))
            continue;
          selected.push(candidate.line);
        }

      if (selected.length == 0)
        selected.push(Std.int(lineCount / 2));

      selected.sort(sortInt);
      return selected;
    }

// add one tier of local roads as a short-connection graph between sampled anchors
  function addLocalGraphRoads(out: Array<RoadSegment>, type: RoadType)
    {
      var cells = game.region.getCells();
      var anchors = collectLocalGraphAnchors(cells, type);

      anchors.sort(function(a, b)
        {
          if (a.cellY != b.cellY)
            return a.cellY - b.cellY;
          return a.cellX - b.cellX;
        });

      for (i in 0...anchors.length)
        {
          var anchor = anchors[i];
          if (anchor.degree >= anchor.maxDegree)
            continue;

          var candidates: Array<LocalGraphCandidate> = [];
          for (j in 0...anchors.length)
            {
              if (i == j)
                continue;

              var other = anchors[j];
              if (other.degree >= other.maxDegree)
                continue;

              var dist = getLocalGraphAnchorDistance(anchor, other);
              if (dist <= 0 ||
                  dist > Std.int(Math.max(anchor.radius, other.radius)))
                continue;

              var preferredHorizontal = shouldPreferLocalGraphHorizontal(anchor, other, type);
              var canPreferred = canBuildLocalGraphConnection(cells, anchor, other,
                preferredHorizontal);
              var canOther = canBuildLocalGraphConnection(cells, anchor, other,
                !preferredHorizontal);
              if (!canPreferred &&
                  !canOther)
                continue;

              candidates.push({
                index: j,
                score: getLocalGraphCandidateScore(anchor, other, dist, type),
                horizontalFirst: (canPreferred ? preferredHorizontal : !preferredHorizontal),
              });
            }

          candidates.sort(function(a, b)
            {
              if (a.score > b.score) return -1;
              if (a.score < b.score) return 1;
              return a.index - b.index;
            });

          for (candidate in candidates)
            {
              if (anchor.degree >= anchor.maxDegree)
                break;

              var other = anchors[candidate.index];
              if (other.degree >= other.maxDegree)
                continue;

              var added = addCoverageRoads(out,
                makeLocalGraphConnectionRoads(anchor, other, type, candidate.horizontalFirst));
              if (added.length == 0)
                continue;

              anchor.degree++;
              other.degree++;
            }
        }
    }

// collect sampled local-graph anchors for one road tier
  function collectLocalGraphAnchors(cells: Array<Array<AreaGame>>,
      type: RoadType): Array<LocalGraphAnchor>
    {
      var anchors = [];

      for (y in 0...regionHeight)
        for (x in 0...regionWidth)
          {
            var cell = cells[x][y];
            if (!isCityAreaType(cell.typeID))
              continue;
            if (!shouldPlaceLocalGraphAnchor(cells, x, y, type))
              continue;

            var density = getAreaDensityValue(cell.typeID);
            anchors.push({
              cellX: x,
              cellY: y,
              density: density,
              degree: 0,
              maxDegree: getLocalGraphAnchorMaxDegree(type, density),
              radius: getLocalGraphAnchorRadius(type, density),
            });
          }

      return anchors;
    }

// return whether one city tile should host a local-graph anchor
  function shouldPlaceLocalGraphAnchor(cells: Array<Array<AreaGame>>,
      cellX: Int, cellY: Int, type: RoadType): Bool
    {
      var density = getAreaDensityValue(cells[cellX][cellY].typeID);
      var neighbors = countCityNeighbors(cells, cellX, cellY);
      var chance = switch (type) {
        case ROAD3:
          0.28 + density * 0.22 + neighbors * 0.04;
        case ROAD4:
          0.16 + density * 0.22 + neighbors * 0.03;
        case ROAD5:
          0.08 + density * 0.18 + neighbors * 0.02;
        default:
          0.0;
      };
      return hashFloat(cellX, cellY, getRoadTypeOrder(type) * 211 + 61) <
        clampFloat(chance, 0.0, 0.82);
    }

// return how many city neighbors one tile has
  function countCityNeighbors(cells: Array<Array<AreaGame>>, cellX: Int, cellY: Int): Int
    {
      var neighbors = 0;

      if (cellX > 0 &&
          isCityAreaType(cells[cellX - 1][cellY].typeID))
        neighbors++;
      if (cellX < regionWidth - 1 &&
          isCityAreaType(cells[cellX + 1][cellY].typeID))
        neighbors++;
      if (cellY > 0 &&
          isCityAreaType(cells[cellX][cellY - 1].typeID))
        neighbors++;
      if (cellY < regionHeight - 1 &&
          isCityAreaType(cells[cellX][cellY + 1].typeID))
        neighbors++;

      return neighbors;
    }

// return the desired max degree for one local-graph anchor
  function getLocalGraphAnchorMaxDegree(type: RoadType, density: Float): Int
    {
      return switch (type) {
        case ROAD3:
          2 + Std.int(Math.floor(density * 2.6));
        case ROAD4:
          1 + Std.int(Math.floor(density * 2.2));
        case ROAD5:
          1 + Std.int(Math.floor(density * 1.3));
        default:
          1;
      };
    }

// return the connection radius for one local-graph anchor
  function getLocalGraphAnchorRadius(type: RoadType, density: Float): Int
    {
      return switch (type) {
        case ROAD3:
          2 + Std.int(Math.floor(density * 2.0));
        case ROAD4:
          2 + Std.int(Math.floor(density * 1.5));
        case ROAD5:
          1 + Std.int(Math.floor(density * 1.5));
        default:
          2;
      };
    }

// return the manhattan distance between two local-graph anchors
  function getLocalGraphAnchorDistance(a: LocalGraphAnchor, b: LocalGraphAnchor): Int
    {
      return Std.int(Math.abs(a.cellX - b.cellX) + Math.abs(a.cellY - b.cellY));
    }

// return whether a local-graph connection should start horizontally
  function shouldPreferLocalGraphHorizontal(a: LocalGraphAnchor, b: LocalGraphAnchor,
      type: RoadType): Bool
    {
      var dx = Math.abs(a.cellX - b.cellX);
      var dy = Math.abs(a.cellY - b.cellY);
      if (dx != dy)
        return dx >= dy;
      return hashFloat(a.cellX * 31 + b.cellX, a.cellY * 37 + b.cellY,
        getRoadTypeOrder(type) * 223 + 79) < 0.5;
    }

// return the desirability score for one local-graph candidate connection
  function getLocalGraphCandidateScore(a: LocalGraphAnchor, b: LocalGraphAnchor,
      dist: Int, type: RoadType): Float
    {
      var straightBonus = (a.cellX == b.cellX || a.cellY == b.cellY ? 0.22 : 0.0);
      var densityScore = (a.density + b.density) * 0.48;
      var degreePenalty = (a.degree + b.degree) * 0.18;
      var noise = hashFloat(a.cellX * 97 + b.cellX * 17,
        a.cellY * 89 + b.cellY * 23, getRoadTypeOrder(type) * 227 + 83) * 0.12;
      return densityScore + straightBonus + noise - dist * 0.26 - degreePenalty;
    }

// return whether two local anchors can be connected through city tiles
  function canBuildLocalGraphConnection(cells: Array<Array<AreaGame>>,
      a: LocalGraphAnchor, b: LocalGraphAnchor, horizontalFirst: Bool): Bool
    {
      if (a.cellX == b.cellX)
        return isCityCoverageRun(cells, a.cellX, a.cellY, b.cellX, b.cellY);
      if (a.cellY == b.cellY)
        return isCityCoverageRun(cells, a.cellX, a.cellY, b.cellX, b.cellY);

      if (horizontalFirst)
        {
          return isCityCoverageRun(cells, a.cellX, a.cellY, b.cellX, a.cellY) &&
            isCityCoverageRun(cells, b.cellX, a.cellY, b.cellX, b.cellY);
        }

      return isCityCoverageRun(cells, a.cellX, a.cellY, a.cellX, b.cellY) &&
        isCityCoverageRun(cells, a.cellX, b.cellY, b.cellX, b.cellY);
    }

// create one local-graph connection as straight or single-turn road segments
  function makeLocalGraphConnectionRoads(a: LocalGraphAnchor, b: LocalGraphAnchor,
      type: RoadType, horizontalFirst: Bool): Array<RoadSegment>
    {
      var startLaneX = getRegionCellLanePixelX(a.cellX, type);
      var startLaneY = getRegionCellLanePixelY(a.cellY, type);
      var endLaneX = getRegionCellLanePixelX(b.cellX, type);
      var endLaneY = getRegionCellLanePixelY(b.cellY, type);
      var roads = [];

      if (a.cellY == b.cellY)
        {
          roads.push({
            x1: startLaneX,
            y1: startLaneY,
            x2: endLaneX,
            y2: startLaneY,
            type: type,
          });
          return roads;
        }
      if (a.cellX == b.cellX)
        {
          roads.push({
            x1: startLaneX,
            y1: startLaneY,
            x2: startLaneX,
            y2: endLaneY,
            type: type,
          });
          return roads;
        }

      if (horizontalFirst)
        {
          roads.push({
            x1: startLaneX,
            y1: startLaneY,
            x2: endLaneX,
            y2: startLaneY,
            type: type,
          });
          roads.push({
            x1: endLaneX,
            y1: startLaneY,
            x2: endLaneX,
            y2: endLaneY,
            type: type,
          });
          return roads;
        }

      roads.push({
        x1: startLaneX,
        y1: startLaneY,
        x2: startLaneX,
        y2: endLaneY,
        type: type,
      });
      roads.push({
        x1: startLaneX,
        y1: endLaneY,
        x2: endLaneX,
        y2: endLaneY,
        type: type,
      });
      return roads;
    }

// return the sampled per-tile lane offset for one local-road tier
  function getCityMeshOffset(type: RoadType): Int
    {
      return getCityMeshOffsetForIndex(type, true, 0);
    }

// return the sampled lane offset for one row or column index
  function getCityMeshOffsetForIndex(type: RoadType, horizontal: Bool, fixedIndex: Int): Int
    {
      var choices = switch (type) {
        case ROAD3: (horizontal ? [20, 36] : [28, 44]);
        case ROAD4: (horizontal ? [12, 44] : [20, 52]);
        case ROAD5: (horizontal ? [20, 52] : [12, 44]);
        default: [28];
      };
      var pick = Std.int(hashFloat(fixedIndex, horizontal ? 7 : 13,
        getRoadTypeOrder(type) * 191 + 43) * choices.length);
      return choices[clampInt(pick, 0, choices.length - 1)];
    }

// pick denser side-road lines between mains
  function selectSideLines(isHorizontal: Bool, reservedLines: Array<Int>): Array<Int>
    {
      var lineCount = (isHorizontal ? fullCellHeight : fullCellWidth);
      var maxCount = getMaxSideRoadLineCount(isHorizontal);
      var candidates = [];

      for (line in 1...lineCount - 1)
        {
          if (!isFarFromLines(line, reservedLines, 2))
            continue;
          var score = getRoadLineScore(isHorizontal, line, false);
          if (score < 0.10)
            continue;
          candidates.push({ line: line, score: score });
        }

      candidates.sort(function(a, b)
        {
          if (a.score > b.score) return -1;
          if (a.score < b.score) return 1;
          return a.line - b.line;
        });

      var selected = [];
      for (candidate in candidates)
        {
          if (selected.length >= maxCount)
            break;
          var spacing = getSideRoadLineSpacing(candidate.score);
          if (!isFarFromLines(candidate.line, selected, spacing))
            continue;
          if (!isFarFromLines(candidate.line, reservedLines,
              clampInt(spacing - 1, 2, spacing)))
            continue;
          selected.push(candidate.line);
        }

      selected.sort(sortInt);
      return selected;
    }

// score a whole-row or whole-column road corridor
  function getRoadLineScore(isHorizontal: Bool, line: Int, isMain: Bool): Float
    {
      var count = (isHorizontal ? fullCellWidth : fullCellHeight);
      var values = [];
      var sum = 0.0;
      var active = 0;
      for (i in 0...count)
        {
          var value = (isHorizontal ? densityField.values[i][line] : densityField.values[line][i]);
          values.push(value);
          sum += value;
          if (value >= 0.18)
            active++;
        }

      var avg = sum / count;
      var activeFrac = active / count;
      var windowSize = (isMain ?
        clampInt(Std.int(Math.floor(count / 4.0)), 3, 7) :
        clampInt(Std.int(Math.floor(count / 5.0)), 2, 5));
      var windowSum = 0.0;
      var peak = 0.0;
      for (i in 0...values.length)
        {
          windowSum += values[i];
          if (i >= windowSize)
            windowSum -= values[i - windowSize];
          if (i >= windowSize - 1)
            peak = Math.max(peak, windowSum / windowSize);
        }

      var center = (line + 0.5) / (isHorizontal ? fullCellHeight : fullCellWidth);
      var centerBias = 1.0 - Math.abs(center - 0.5) * (isMain ? 1.2 : 1.6);
      var noise = hashFloat(line, isHorizontal ? 3 : 7, isMain ? 19 : 29) * 0.03;
      if (isMain)
        return avg * 0.34 + peak * 0.46 + activeFrac * 0.12 + centerBias * 0.08 + noise;
      return avg * 0.16 + peak * 0.58 + activeFrac * 0.22 + centerBias * 0.02 + noise;
    }

// add side roads as segmented branches between main roads
  function addSideRoads(out: Array<RoadSegment>,
      horizontalMainLines: Array<Int>, verticalMainLines: Array<Int>)
    {
      var horizontalSideLines = selectSideLines(true, horizontalMainLines);
      var verticalSideLines = selectSideLines(false, verticalMainLines);
      var horizontalMainCenters = getLineCenters(horizontalMainLines, ROAD1, true);
      var verticalMainCenters = getLineCenters(verticalMainLines, ROAD1, false);

      for (line in horizontalSideLines)
        addSegmentedRoadsForLine(out, true, line, verticalMainCenters, ROAD2,
          getSideRoadSegmentMinScore(getRoadLineScore(true, line, false)),
          getRoadLineScore(true, line, false));
      for (line in verticalSideLines)
        addSegmentedRoadsForLine(out, false, line, horizontalMainCenters, ROAD2,
          getSideRoadSegmentMinScore(getRoadLineScore(false, line, false)),
          getRoadLineScore(false, line, false));
    }

// add segmented roads between neighboring anchor lines
  function addSegmentedRoadsForLine(out: Array<RoadSegment>, isHorizontal: Bool,
      line: Int, anchors: Array<Int>, type: RoadType, minScore: Float,
      lineScore: Float)
    {
      if (anchors.length < 2)
        return;

      var center = getRoadLinePixel(line, type, isHorizontal);
      for (i in 0...anchors.length - 1)
        {
          var start = anchors[i];
          var end = anchors[i + 1];
          if (end - start < CLEAN_TILE_SIZE * 2)
            continue;

          var segment = createBranchSegment(isHorizontal, center,
            start, end, line, i, type, lineScore);

          if (getRoadSegmentScore(segment) < minScore)
            continue;

          out.push(segment);
        }
    }

// add one tier of local roads inside blocks
  function addLocalRoads(out: Array<RoadSegment>, baseBlocks: Array<BlockRect>,
      type: RoadType)
    {
      for (block in baseBlocks)
        {
          var count = getLocalRoadCount(block, type);
          if (count <= 0)
            continue;

          var inset = getLocalRoadInset(type);
          var extend = getLocalRoadExtension(type);
          var primaryVertical = block.width >= block.height;

          for (i in 0...count)
            {
              var vertical = primaryVertical;
              if (shouldUseSecondaryLocalRoadAxis(block, i, count, type))
                vertical = !vertical;

              if (shouldCurveLocalRoad(block, type, i))
                {
                  var curved = buildCurvedLocalRoad(block, type, vertical, i, count, inset);
                  if (curved != null &&
                      canAddLocalRoadSegments(out, curved))
                    {
                      for (segment in curved)
                        out.push(segment);
                      continue;
                    }
                }

              if (vertical)
                {
                  var minX = block.x + inset;
                  var maxX = block.x + block.width - inset;
                  if (maxX - minX < CLEAN_TILE_SIZE / 2)
                    continue;
                  var pathX = pickConnectorCoordinate(minX, maxX, i, count);
                  var candidate = {
                    x1: pathX,
                    y1: clampInt(block.y - extend, 0, fullPixelHeight),
                    x2: pathX,
                    y2: clampInt(block.y + block.height + extend, 0, fullPixelHeight),
                    type: type,
                  };
                  if (hasParallelRoadConflict(out, candidate))
                    continue;
                  out.push(candidate);
                }
              else
                {
                  var minY = block.y + inset;
                  var maxY = block.y + block.height - inset;
                  if (maxY - minY < CLEAN_TILE_SIZE / 2)
                    continue;
                  var pathY = pickConnectorCoordinate(minY, maxY, i, count);
                  var candidate = {
                    x1: clampInt(block.x - extend, 0, fullPixelWidth),
                    y1: pathY,
                    x2: clampInt(block.x + block.width + extend, 0, fullPixelWidth),
                    y2: pathY,
                    type: type,
                  };
                  if (hasParallelRoadConflict(out, candidate))
                    continue;
                  out.push(candidate);
                }
            }
        }
    }

// return how many local roads one block should receive for one tier
  function getLocalRoadCount(block: BlockRect, type: RoadType): Int
    {
      var longSide = Math.max(block.width, block.height);
      var shortSide = Math.min(block.width, block.height);
      var support = clampFloat((block.density - 0.20) / 0.80, 0.0, 1.0);

      return switch (type) {
        case ROAD3:
          if (longSide < CLEAN_TILE_SIZE * 3 ||
              shortSide < Std.int(CLEAN_TILE_SIZE * 1.5) ||
              block.density < 0.22)
            0;
          else {
            var count = 1;
            if (support >= 0.28 && longSide >= CLEAN_TILE_SIZE * 5) count++;
            clampInt(count * 4, 4, 8);
          };
        case ROAD4:
          if (longSide < Std.int(CLEAN_TILE_SIZE * 2.5) ||
              shortSide < CLEAN_TILE_SIZE ||
              block.density < 0.24)
            0;
          else {
            var count = 1;
            if (support >= 0.00 && longSide >= CLEAN_TILE_SIZE * 3) count++;
            if (support >= 0.18 && longSide >= CLEAN_TILE_SIZE * 4) count++;
            if (support >= 0.42 && longSide >= CLEAN_TILE_SIZE * 5 &&
                shortSide >= Std.int(CLEAN_TILE_SIZE * 1.5)) count++;
            clampInt(count * 4, 4, 16);
          };
        case ROAD5:
          if (longSide < CLEAN_TILE_SIZE * 2 ||
              shortSide < CLEAN_TILE_SIZE ||
              block.density < 0.28)
            0;
          else {
            var count = 1;
            if (support >= 0.00 && longSide >= Std.int(CLEAN_TILE_SIZE * 2.5)) count++;
            if (support >= 0.12 && longSide >= CLEAN_TILE_SIZE * 3) count++;
            if (support >= 0.28 && longSide >= CLEAN_TILE_SIZE * 4) count++;
            if (support >= 0.48 && longSide >= CLEAN_TILE_SIZE * 5 &&
                shortSide >= Std.int(CLEAN_TILE_SIZE * 1.25)) count++;
            clampInt(count * 4, 4, 20);
          };
        default:
          0;
      };
    }

// return whether one local road should flip onto the secondary axis
  function shouldUseSecondaryLocalRoadAxis(block: BlockRect, index: Int,
      count: Int, type: RoadType): Bool
    {
      if (count < 2 || index == 0)
        return false;

      var shortSide = Math.min(block.width, block.height);
      return switch (type) {
        case ROAD3:
          block.density >= 0.42 &&
            shortSide >= Std.int(CLEAN_TILE_SIZE * 2.25) &&
            index % 2 == 1;
        case ROAD4:
          shortSide >= Std.int(CLEAN_TILE_SIZE * 1.75) &&
            (index % 2 == 1 || count >= 4);
        case ROAD5:
          shortSide >= Std.int(CLEAN_TILE_SIZE * 1.5) &&
            index % 2 == 1;
        default:
          false;
      };
    }

// return the placement inset for one local road tier
  function getLocalRoadInset(type: RoadType): Int
    {
      return switch (type) {
        case ROAD3: Std.int(CLEAN_TILE_SIZE / 2);
        case ROAD4: Std.int(CLEAN_TILE_SIZE / 3);
        case ROAD5: Std.int(CLEAN_TILE_SIZE / 4);
        default: Std.int(CLEAN_TILE_SIZE / 2);
      };
    }

// return how far a local road should extend into surrounding roads
  function getLocalRoadExtension(type: RoadType): Int
    {
      return switch (type) {
        case ROAD3: 0;
        case ROAD4: 0;
        case ROAD5: 0;
        default: Std.int(CLEAN_TILE_SIZE / 2);
      };
    }

// return whether a local road should bend 90 degrees
  function shouldCurveLocalRoad(block: BlockRect, type: RoadType, index: Int): Bool
    {
      var shortSide = Math.min(block.width, block.height);
      if (shortSide < Std.int(CLEAN_TILE_SIZE * 1.5))
        return false;

      var chance = switch (type) {
        case ROAD3: 0.28;
        case ROAD4: 0.38;
        case ROAD5: 0.48;
        default: 0.0;
      };
      return hashFloat(Std.int(block.x / PLAN_CELL_SIZE) + index,
        Std.int(block.y / PLAN_CELL_SIZE), getRoadTypeOrder(type) * 41 + 503) < chance;
    }

// build one L-shaped local road as two orthogonal segments
  function buildCurvedLocalRoad(block: BlockRect, type: RoadType,
      verticalFirst: Bool, index: Int, count: Int, inset: Int): Array<RoadSegment>
    {
      var result = [];
      var minX = block.x + inset;
      var maxX = block.x + block.width - inset;
      var minY = block.y + inset;
      var maxY = block.y + block.height - inset;
      if (maxX - minX < CLEAN_TILE_SIZE / 2 ||
          maxY - minY < CLEAN_TILE_SIZE / 2)
        return null;

      if (verticalFirst)
        {
          var pathX = pickConnectorCoordinate(minX, maxX, index, count);
          var turnY = pickConnectorCoordinate(minY, maxY, index + 1, count + 1);
          var fromTop = hashFloat(pathX, turnY, 557) < 0.5;
          var toRight = hashFloat(pathX, turnY, 563) < 0.5;
          var endX = (toRight ? block.x + block.width : block.x);
          result.push({
            x1: pathX,
            y1: (fromTop ? block.y : turnY),
            x2: pathX,
            y2: (fromTop ? turnY : block.y + block.height),
            type: type,
          });
          result.push({
            x1: Std.int(Math.min(pathX, endX)),
            y1: turnY,
            x2: Std.int(Math.max(pathX, endX)),
            y2: turnY,
            type: type,
          });
        }
      else
        {
          var pathY = pickConnectorCoordinate(minY, maxY, index, count);
          var turnX = pickConnectorCoordinate(minX, maxX, index + 1, count + 1);
          var fromLeft = hashFloat(turnX, pathY, 569) < 0.5;
          var toBottom = hashFloat(turnX, pathY, 571) < 0.5;
          var endY = (toBottom ? block.y + block.height : block.y);
          result.push({
            x1: (fromLeft ? block.x : turnX),
            y1: pathY,
            x2: (fromLeft ? turnX : block.x + block.width),
            y2: pathY,
            type: type,
          });
          result.push({
            x1: turnX,
            y1: Std.int(Math.min(pathY, endY)),
            x2: turnX,
            y2: Std.int(Math.max(pathY, endY)),
            type: type,
          });
        }

      return result;
    }

// return whether a list of local-road segments can be added cleanly
  function canAddLocalRoadSegments(out: Array<RoadSegment>, segments: Array<RoadSegment>): Bool
    {
      for (segment in segments)
        if (hasParallelRoadConflict(out, segment))
          return false;
      return true;
    }

// add at least one road through every visible city tile that lacks one
  function ensureCityTileRoads(out: Array<RoadSegment>)
    {
      var cells = game.region.getCells();
      var coverage = buildRegionCellRoadCoverageMap(rasterizeRoadMasks(out));

      for (y in 0...regionHeight)
        for (x in 0...regionWidth)
          {
            if (!isCityAreaType(cells[x][y].typeID))
              continue;
            if (coverage[x][y])
              continue;

            var added = addCoverageRoads(out,
              buildCityTileCoverageRoadsOfType(cells, coverage, x, y, ROAD4));
            markRegionCellRoadCoverage(coverage, added);
          }
    }

// add at least one local rgb road through every low/medium city tile that lacks one
  function ensureCityTileLocalRoads(out: Array<RoadSegment>)
    {
      var cells = game.region.getCells();
      var localRoads = [];
      for (road in out)
        if (isLocalRoadType(road.type))
          localRoads.push(road);

      var coverage = buildRegionCellRoadCoverageMap(rasterizeRoadMasks(localRoads));

      for (y in 0...regionHeight)
        for (x in 0...regionWidth)
          {
            var type = cells[x][y].typeID;
            if (type != AREA_CITY_LOW &&
                type != AREA_CITY_MEDIUM)
              continue;
            if (coverage[x][y])
              continue;

            var added = addCoverageRoads(out,
              buildCityTileCoverageRoadsOfType(cells, coverage, x, y,
                getGuaranteedLocalRoadType(type)));
            for (road in added)
              localRoads.push(road);
            markRegionCellRoadCoverage(coverage, added);
          }
    }

// build a meaningful road-coverage map over visible region tiles
  function buildRegionCellRoadCoverageMap(masks: RoadMasks): Array<Array<Bool>>
    {
      var coverage = makeBoolGrid(regionWidth, regionHeight);

      for (y in 0...regionHeight)
        for (x in 0...regionWidth)
          coverage[x][y] = getRegionCellRoadCoverage(masks, x, y) >=
            MIN_CITY_TILE_ROAD_COVERAGE;

      return coverage;
    }

// return the core-road coverage ratio inside one visible region tile
  function getRegionCellRoadCoverage(masks: RoadMasks, cellX: Int, cellY: Int): Float
    {
      var inset = Std.int(CLEAN_TILE_SIZE / 4);
      var pixelStartX = (cellX + HALO_CELLS) * CLEAN_TILE_SIZE + inset;
      var pixelEndX = (cellX + HALO_CELLS + 1) * CLEAN_TILE_SIZE - inset - 1;
      var pixelStartY = (cellY + HALO_CELLS) * CLEAN_TILE_SIZE + inset;
      var pixelEndY = (cellY + HALO_CELLS + 1) * CLEAN_TILE_SIZE - inset - 1;
      var startX = clampInt(Std.int(pixelStartX / PLAN_CELL_SIZE), 0, planWidth - 1);
      var endX = clampInt(Std.int(pixelEndX / PLAN_CELL_SIZE), 0, planWidth - 1);
      var startY = clampInt(Std.int(pixelStartY / PLAN_CELL_SIZE), 0, planHeight - 1);
      var endY = clampInt(Std.int(pixelEndY / PLAN_CELL_SIZE), 0, planHeight - 1);
      var covered = 0;
      var total = 0;

      for (yy in startY...endY + 1)
        for (xx in startX...endX + 1)
          {
            total++;
            if (masks.core[xx][yy] > 0.0)
              covered++;
          }

      if (total == 0)
        return 0.0;
      return covered / total;
    }

// build guaranteed coverage roads for one city tile with one specific tier
  function buildCityTileCoverageRoadsOfType(cells: Array<Array<AreaGame>>,
      coverage: Array<Array<Bool>>, cellX: Int, cellY: Int,
      type: RoadType): Array<RoadSegment>
    {
      var preferredHorizontal = shouldUseHorizontalCityCoverage(cells, cellX, cellY);
      var density = getAreaDensityValue(cells[cellX][cellY].typeID);
      var source: LocalGraphAnchor = {
        cellX: cellX,
        cellY: cellY,
        density: density,
        degree: 0,
        maxDegree: 1,
        radius: MAX_CITY_COVERAGE_TURN_DISTANCE,
      };
      var target = findNearestCoveredCityTile(cells, coverage, cellX, cellY);
      if (target != null)
        {
          var targetAnchor: LocalGraphAnchor = {
            cellX: target.x,
            cellY: target.y,
            density: getAreaDensityValue(cells[target.x][target.y].typeID),
            degree: 0,
            maxDegree: 1,
            radius: MAX_CITY_COVERAGE_TURN_DISTANCE,
          };
          if (canBuildLocalGraphConnection(cells, source, targetAnchor, preferredHorizontal))
            return makeLocalGraphConnectionRoads(source, targetAnchor, type, preferredHorizontal);
          if (canBuildLocalGraphConnection(cells, source, targetAnchor, !preferredHorizontal))
            return makeLocalGraphConnectionRoads(source, targetAnchor, type, !preferredHorizontal);
        }

      return [makeSingleTileCoverageRoad(cellX, cellY, type, preferredHorizontal)];
    }

// return whether one road tier is one of the local rgb tiers
  function isLocalRoadType(type: RoadType): Bool
    {
      return switch (type) {
        case ROAD3, ROAD4, ROAD5: true;
        default: false;
      };
    }

// return the guaranteed local-road tier for one city area type
  function getGuaranteedLocalRoadType(type: _AreaType): RoadType
    {
      return switch (type) {
        case AREA_CITY_LOW: ROAD3;
        case AREA_CITY_MEDIUM: ROAD4;
        case AREA_CITY_HIGH: ROAD5;
        default: ROAD3;
      };
    }

// return the score for one fallback coverage candidate
  function getCityCoverageCandidateScore(candidate: CityCoverageCandidate): Int
    {
      var spanWeight = (candidate.connections > 0 ? 20 : 4);
      return candidate.connections * 1000 + candidate.span * spanWeight;
    }

// create one short in-tile fallback road for a still-uncovered city tile
  function makeSingleTileCoverageRoad(cellX: Int, cellY: Int,
      type: RoadType, horizontal: Bool): RoadSegment
    {
      var tileStartX = (cellX + HALO_CELLS) * CLEAN_TILE_SIZE;
      var tileStartY = (cellY + HALO_CELLS) * CLEAN_TILE_SIZE;
      var laneX = getRegionCellLanePixelX(cellX, type);
      var laneY = getRegionCellLanePixelY(cellY, type);
      if (horizontal)
        {
          return {
            x1: tileStartX,
            y1: laneY,
            x2: tileStartX + CLEAN_TILE_SIZE,
            y2: laneY,
            type: type,
          };
        }

      return {
        x1: laneX,
        y1: tileStartY,
        x2: laneX,
        y2: tileStartY + CLEAN_TILE_SIZE,
        type: type,
      };
    }

// build a short L-shaped fallback road toward the nearest covered city tile
  function buildCityTileTurnRoadsOfType(cells: Array<Array<AreaGame>>,
      coverage: Array<Array<Bool>>, cellX: Int, cellY: Int,
      type: RoadType, preferredHorizontal: Bool): Array<RoadSegment>
    {
      var target = findNearestCoveredCityTile(cells, coverage, cellX, cellY);
      if (target == null)
        return null;

      if (canBuildCityCoverageTurn(cells, cellX, cellY, target.x, target.y, preferredHorizontal))
        return makeCityCoverageTurnRoads(cellX, cellY, target.x, target.y, type,
          preferredHorizontal);
      if (canBuildCityCoverageTurn(cells, cellX, cellY, target.x, target.y,
          !preferredHorizontal))
        return makeCityCoverageTurnRoads(cellX, cellY, target.x, target.y, type,
          !preferredHorizontal);

      return null;
    }

// find the nearest already-covered city tile for a fallback turn
  function findNearestCoveredCityTile(cells: Array<Array<AreaGame>>,
      coverage: Array<Array<Bool>>, cellX: Int, cellY: Int): GridPoint
    {
      var best = null;
      var bestDist = 999999;

      for (y in 0...regionHeight)
        for (x in 0...regionWidth)
          {
            if ((x == cellX && y == cellY) ||
                !coverage[x][y] ||
                !isCityAreaType(cells[x][y].typeID))
              continue;

            var dist = Std.int(Math.abs(x - cellX) + Math.abs(y - cellY));
            if (dist > MAX_CITY_COVERAGE_TURN_DISTANCE)
              continue;
            if (dist < bestDist)
              {
                bestDist = dist;
                best = { x: x, y: y };
              }
          }

      return best;
    }

// return whether a fallback turn can stay inside city tiles
  function canBuildCityCoverageTurn(cells: Array<Array<AreaGame>>,
      startX: Int, startY: Int, endX: Int, endY: Int,
      horizontalFirst: Bool): Bool
    {
      if (horizontalFirst)
        {
          if (!isCityCoverageRun(cells, startX, startY, endX, startY))
            return false;
          return isCityCoverageRun(cells, endX, startY, endX, endY);
        }

      if (!isCityCoverageRun(cells, startX, startY, startX, endY))
        return false;
      return isCityCoverageRun(cells, startX, endY, endX, endY);
    }

// return whether every cell in one straight fallback run is city
  function isCityCoverageRun(cells: Array<Array<AreaGame>>,
      startX: Int, startY: Int, endX: Int, endY: Int): Bool
    {
      if (startY == endY)
        {
          var minX = Std.int(Math.min(startX, endX));
          var maxX = Std.int(Math.max(startX, endX));
          for (x in minX...maxX + 1)
            if (!isCityAreaType(cells[x][startY].typeID))
              return false;
          return true;
        }

      var minY = Std.int(Math.min(startY, endY));
      var maxY = Std.int(Math.max(startY, endY));
      for (y in minY...maxY + 1)
        if (!isCityAreaType(cells[startX][y].typeID))
          return false;
      return true;
    }

// create two orthogonal fallback segments between two city tiles
  function makeCityCoverageTurnRoads(startX: Int, startY: Int,
      endX: Int, endY: Int, type: RoadType,
      horizontalFirst: Bool): Array<RoadSegment>
    {
      var startLaneX = getRegionCellLanePixelX(startX, type);
      var startLaneY = getRegionCellLanePixelY(startY, type);
      var endLaneX = getRegionCellLanePixelX(endX, type);
      var endLaneY = getRegionCellLanePixelY(endY, type);
      var roads = [];

      if (horizontalFirst)
        {
          if (startLaneX != endLaneX)
            roads.push({
              x1: startLaneX,
              y1: startLaneY,
              x2: endLaneX,
              y2: startLaneY,
              type: type,
            });
          if (startLaneY != endLaneY)
            roads.push({
              x1: endLaneX,
              y1: startLaneY,
              x2: endLaneX,
              y2: endLaneY,
              type: type,
            });
        }
      else
        {
          if (startLaneY != endLaneY)
            roads.push({
              x1: startLaneX,
              y1: startLaneY,
              x2: startLaneX,
              y2: endLaneY,
              type: type,
            });
          if (startLaneX != endLaneX)
            roads.push({
              x1: startLaneX,
              y1: endLaneY,
              x2: endLaneX,
              y2: endLaneY,
              type: type,
            });
        }

      return roads;
    }

// add normalized coverage roads while skipping exact duplicates
  function addCoverageRoads(out: Array<RoadSegment>, incoming: Array<RoadSegment>): Array<RoadSegment>
    {
      var added = [];

      for (road in incoming)
        {
          var normalized = normalizeRoad(road);
          if (normalized == null ||
              containsRoadSegment(out, normalized) ||
              containsRoadSegment(added, normalized))
            continue;

          out.push(normalized);
          added.push(normalized);
        }

      return added;
    }

// return whether one list already contains one exact road segment
  function containsRoadSegment(list: Array<RoadSegment>, road: RoadSegment): Bool
    {
      for (existing in list)
        if (areSameRoad(existing, road))
          return true;
      return false;
    }

// mark visible region tiles crossed by guaranteed fallback roads
  function markRegionCellRoadCoverage(coverage: Array<Array<Bool>>, roads: Array<RoadSegment>)
    {
      for (road in roads)
        markRegionCellRoadCoverageByRoad(coverage, road);
    }

// mark one visible region tile run as covered by one fallback road
  function markRegionCellRoadCoverageByRoad(coverage: Array<Array<Bool>>, road: RoadSegment)
    {
      var normalized = normalizeRoad(road);
      if (normalized == null)
        return;

      if (normalized.y1 == normalized.y2)
        {
          var cellY = clampInt(Std.int(normalized.y1 / CLEAN_TILE_SIZE) - HALO_CELLS,
            0, regionHeight - 1);
          var startCellX = clampInt(Std.int(Math.floor(
            Math.min(normalized.x1, normalized.x2) / CLEAN_TILE_SIZE)) - HALO_CELLS,
            0, regionWidth - 1);
          var endCellX = clampInt(Std.int(Math.ceil(
            Math.max(normalized.x1, normalized.x2) / CLEAN_TILE_SIZE)) - HALO_CELLS - 1,
            0, regionWidth - 1);
          for (x in startCellX...endCellX + 1)
            coverage[x][cellY] = true;
          return;
        }

      var cellX = clampInt(Std.int(normalized.x1 / CLEAN_TILE_SIZE) - HALO_CELLS,
        0, regionWidth - 1);
      var startCellY = clampInt(Std.int(Math.floor(
        Math.min(normalized.y1, normalized.y2) / CLEAN_TILE_SIZE)) - HALO_CELLS,
        0, regionHeight - 1);
      var endCellY = clampInt(Std.int(Math.ceil(
        Math.max(normalized.y1, normalized.y2) / CLEAN_TILE_SIZE)) - HALO_CELLS - 1,
        0, regionHeight - 1);
      for (y in startCellY...endCellY + 1)
        coverage[cellX][y] = true;
    }

// return the sampled lane x position for one visible region tile
  function getRegionCellLanePixelX(cellX: Int, type: RoadType): Int
    {
      return (cellX + HALO_CELLS) * CLEAN_TILE_SIZE +
        getCityMeshOffsetForIndex(type, false, cellX);
    }

// return the sampled lane y position for one visible region tile
  function getRegionCellLanePixelY(cellY: Int, type: RoadType): Int
    {
      return (cellY + HALO_CELLS) * CLEAN_TILE_SIZE +
        getCityMeshOffsetForIndex(type, true, cellY);
    }

// return the best fallback coverage span for one city tile and axis
  function getCityCoverageCandidate(cells: Array<Array<AreaGame>>, coverage: Array<Array<Bool>>,
      cellX: Int, cellY: Int, horizontal: Bool): CityCoverageCandidate
    {
      var minCell = (horizontal ? cellX : cellY);
      var maxCell = minCell;
      var connections = 0;

      while (true)
        {
          var next = minCell - 1;
          if (next < 0)
            break;
          var nx = (horizontal ? next : cellX);
          var ny = (horizontal ? cellY : next);
          if (!isCityAreaType(cells[nx][ny].typeID))
            break;
          minCell = next;
          if (coverage[nx][ny])
            {
              connections++;
              break;
            }
        }

      while (true)
        {
          var next = maxCell + 1;
          if (next >= (horizontal ? regionWidth : regionHeight))
            break;
          var nx = (horizontal ? next : cellX);
          var ny = (horizontal ? cellY : next);
          if (!isCityAreaType(cells[nx][ny].typeID))
            break;
          maxCell = next;
          if (coverage[nx][ny])
            {
              connections++;
              break;
            }
        }

      var startX = (cellX + HALO_CELLS) * CLEAN_TILE_SIZE + Std.int(CLEAN_TILE_SIZE / 2);
      var startY = (cellY + HALO_CELLS) * CLEAN_TILE_SIZE + Std.int(CLEAN_TILE_SIZE / 2);
      var endX = startX;
      var endY = startY;
      if (horizontal)
        {
          startX = (minCell + HALO_CELLS) * CLEAN_TILE_SIZE;
          endX = (maxCell + HALO_CELLS + 1) * CLEAN_TILE_SIZE;
        }
      else
        {
          startY = (minCell + HALO_CELLS) * CLEAN_TILE_SIZE;
          endY = (maxCell + HALO_CELLS + 1) * CLEAN_TILE_SIZE;
        }

      return {
        horizontal: horizontal,
        cellX: cellX,
        cellY: cellY,
        startX: startX,
        startY: startY,
        endX: endX,
        endY: endY,
        span: maxCell - minCell + 1,
        connections: connections,
      };
    }

// return whether a fallback city-tile road should run horizontally
  function shouldUseHorizontalCityCoverage(cells: Array<Array<AreaGame>>, cellX: Int, cellY: Int): Bool
    {
      var horizontal = 0;
      var vertical = 0;

      if (cellX > 0 &&
          isCityAreaType(cells[cellX - 1][cellY].typeID))
        horizontal++;
      if (cellX < regionWidth - 1 &&
          isCityAreaType(cells[cellX + 1][cellY].typeID))
        horizontal++;
      if (cellY > 0 &&
          isCityAreaType(cells[cellX][cellY - 1].typeID))
        vertical++;
      if (cellY < regionHeight - 1 &&
          isCityAreaType(cells[cellX][cellY + 1].typeID))
        vertical++;

      if (horizontal != vertical)
        return horizontal > vertical;
      return hashFloat(cellX, cellY, 887) < 0.5;
    }

// return whether a candidate local road crowds an existing parallel road
  function hasParallelRoadConflict(list: Array<RoadSegment>, candidate: RoadSegment): Bool
    {
      var candidateHorizontal = candidate.y1 == candidate.y2;
      for (road in list)
        {
          if (candidateHorizontal != (road.y1 == road.y2))
            continue;
          if (!roadsOverlapAlongAxis(candidate, road))
            continue;

          var centerGap = candidateHorizontal ?
            Math.abs(candidate.y1 - road.y1) :
            Math.abs(candidate.x1 - road.x1);
          if (centerGap < getParallelRoadMinGap(candidate.type, road.type))
            return true;
        }

      return false;
    }

// return whether two parallel roads overlap enough to matter
  function roadsOverlapAlongAxis(a: RoadSegment, b: RoadSegment): Bool
    {
      if (a.y1 == a.y2)
        {
          var overlap = Math.min(a.x2, b.x2) - Math.max(a.x1, b.x1);
          return overlap >= CLEAN_TILE_SIZE;
        }

      var overlap = Math.min(a.y2, b.y2) - Math.max(a.y1, b.y1);
      return overlap >= CLEAN_TILE_SIZE;
    }

// return the minimum centerline gap between two parallel roads
  function getParallelRoadMinGap(aType: RoadType, bType: RoadType): Int
    {
      var a = getRoadStyle(aType);
      var b = getRoadStyle(bType);
      var aRadius = a.coreWidth / 2.0 + a.shoulderWidth;
      var bRadius = b.coreWidth / 2.0 + b.shoulderWidth;
      return Std.int(Math.ceil(aRadius + bRadius + PLAN_CELL_SIZE));
    }

// create a full-span horizontal or vertical road segment
  function createFullSpanRoad(isHorizontal: Bool, line: Int, type: RoadType): RoadSegment
    {
      var center = getRoadLinePixel(line, type, isHorizontal);
      if (isHorizontal)
        {
          return {
            x1: 0,
            y1: center,
            x2: fullPixelWidth,
            y2: center,
            type: type,
          };
        }
      return {
        x1: center,
        y1: 0,
        x2: center,
        y2: fullPixelHeight,
        type: type,
      };
    }

// create one branch-like segment between neighboring anchors
  function createBranchSegment(isHorizontal: Bool, center: Int,
      start: Int, end: Int, line: Int, index: Int, type: RoadType,
      lineScore: Float): RoadSegment
    {
      var span = end - start;
      var keepFullChance = 0.16 + clampFloat((lineScore - 0.16) / 0.60, 0.0, 1.0) * 0.46;
      var keepFull = hashFloat(line, index, (isHorizontal ? 101 : 131)) < keepFullChance;
      var segStart = start;
      var segEnd = end;

      if (!keepFull && type == ROAD2)
        {
          var support = clampFloat((lineScore - 0.14) / 0.62, 0.0, 1.0);
          var minRatio = 0.34 + support * 0.20;
          var maxRatio = 0.54 + support * 0.24;
          var lenRatio = minRatio + hashFloat(line, index, 149) * (maxRatio - minRatio);
          var len = Std.int(span * lenRatio);
          len = clampInt(len, CLEAN_TILE_SIZE * 2, span);
          var fromStart = shouldBranchFromStart(isHorizontal, center,
            start, end, line, index);
          if (fromStart)
            segEnd = segStart + len;
          else
            segStart = segEnd - len;
        }

      if (isHorizontal)
        {
          return {
            x1: segStart,
            y1: center,
            x2: segEnd,
            y2: center,
            type: type,
          };
        }

      return {
        x1: center,
        y1: segStart,
        x2: center,
        y2: segEnd,
        type: type,
      };
    }

// return the maximum number of side-road lines for one axis
  function getMaxSideRoadLineCount(isHorizontal: Bool): Int
    {
      var span = (isHorizontal ? regionHeight : regionWidth);
      var base = Std.int(span * (0.40 + overallDensity * 1.05));
      return clampInt(base * 4, 16, 72);
    }

// return the spacing to enforce around a side-road line
  function getSideRoadLineSpacing(score: Float): Int
    {
      if (score >= 0.72)
        return 1;
      if (score >= 0.38)
        return 1;
      if (score >= 0.18)
        return 2;
      return 3;
    }

// return the minimum kept score for side-road segments on one line
  function getSideRoadSegmentMinScore(lineScore: Float): Float
    {
      if (lineScore >= 0.72)
        return 0.05;
      if (lineScore >= 0.38)
        return 0.08;
      if (lineScore >= 0.18)
        return 0.11;
      return 0.14;
    }

// return whether a branch segment should extend from the start anchor
  function shouldBranchFromStart(isHorizontal: Bool, center: Int,
      start: Int, end: Int, line: Int, index: Int): Bool
    {
      var startDensity = sampleDensityAtPixel(isHorizontal ? start : center,
        isHorizontal ? center : start);
      var endDensity = sampleDensityAtPixel(isHorizontal ? end : center,
        isHorizontal ? center : end);
      if (Math.abs(startDensity - endDensity) < 0.05)
        return hashFloat(line, index, 173) < 0.5;
      return startDensity >= endDensity;
    }

// return a deterministic jittered road center in clean-pixel space
  function getRoadLinePixel(line: Int, type: RoadType, isHorizontal: Bool): Int
    {
      var base = line * CLEAN_TILE_SIZE + Std.int(CLEAN_TILE_SIZE / 2);
      var jitterMax = switch (type) {
        case ROAD1: Std.int(CLEAN_TILE_SIZE / 8);
        case ROAD2: Std.int(CLEAN_TILE_SIZE / 5);
        case ROAD3: Std.int(CLEAN_TILE_SIZE / 4);
        case ROAD4: Std.int(CLEAN_TILE_SIZE / 3);
        case ROAD5: Std.int(CLEAN_TILE_SIZE / 3);
      };
      var salt = switch (type) {
        case ROAD1: 41;
        case ROAD2: 67;
        case ROAD3: 89;
        case ROAD4: 107;
        case ROAD5: 127;
      };
      var jitter = Std.int((hashFloat(line, isHorizontal ? 13 : 17, salt) - 0.5) *
        jitterMax * 2);
      var limit = isHorizontal ? fullPixelHeight : fullPixelWidth;
      return clampInt(base + jitter, Std.int(CLEAN_TILE_SIZE / 2),
        limit - Std.int(CLEAN_TILE_SIZE / 2));
    }

// return line centers in clean-pixel space
  function getLineCenters(lines: Array<Int>, type: RoadType, isHorizontal: Bool): Array<Int>
    {
      var centers = [];
      for (line in lines)
        centers.push(getRoadLinePixel(line, type, isHorizontal));
      centers.sort(sortInt);
      return centers;
    }

// score one road segment by average sampled density
  function getRoadSegmentScore(road: RoadSegment): Float
    {
      var sampleCount = Std.int(Math.max(
        Math.abs(road.x2 - road.x1),
        Math.abs(road.y2 - road.y1)) / PLAN_CELL_SIZE);
      sampleCount = clampInt(sampleCount, 1, 256);

      var sum = 0.0;
      for (i in 0...sampleCount + 1)
        {
          var t = i / sampleCount;
          var px = Std.int(road.x1 + (road.x2 - road.x1) * t);
          var py = Std.int(road.y1 + (road.y2 - road.y1) * t);
          sum += sampleDensityAtPixel(px, py);
        }

      return sum / (sampleCount + 1);
    }

// normalize, filter, and merge redundant road segments
  function cleanupRoads(list: Array<RoadSegment>): Array<RoadSegment>
    {
      var normalized = [];
      for (road in list)
        {
          var norm = normalizeRoad(road);
          if (norm == null)
            continue;
          if (!passesRoadSupport(norm))
            continue;
          normalized.push(norm);
        }

      normalized.sort(compareRoads);

      var merged = [];
      for (road in normalized)
        {
          if (merged.length == 0)
            {
              merged.push(road);
              continue;
            }

          var last = merged[merged.length - 1];
          if (canMergeRoads(last, road))
            merged[merged.length - 1] = mergeRoads(last, road);
          else if (!areSameRoad(last, road))
            merged.push(road);
        }

      return merged;
    }

// normalize a road so coordinates are ordered
  function normalizeRoad(road: RoadSegment): RoadSegment
    {
      if (road.x1 == road.x2)
        {
          if (road.y2 < road.y1)
            {
              return {
                x1: road.x1,
                y1: road.y2,
                x2: road.x2,
                y2: road.y1,
                type: road.type,
              };
            }
          if (road.y2 == road.y1)
            return null;
          return road;
        }

      if (road.y1 == road.y2)
        {
          if (road.x2 < road.x1)
            {
              return {
                x1: road.x2,
                y1: road.y1,
                x2: road.x1,
                y2: road.y2,
                type: road.type,
              };
            }
          if (road.x2 == road.x1)
            return null;
          return road;
        }

      return null;
    }

// return whether a road has enough local support to keep
  function passesRoadSupport(road: RoadSegment): Bool
    {
      if (road.type == ROAD1)
        return true;

      var avg = getRoadSegmentScore(road);
      var startDensity = sampleDensityAtPixel(road.x1, road.y1);
      var endDensity = sampleDensityAtPixel(road.x2, road.y2);
      var minDensity = Math.min(startDensity, endDensity);
      var maxDensity = Math.max(startDensity, endDensity);

      if (road.type == ROAD2)
        {
          return avg >= 0.20 &&
            maxDensity >= 0.22 &&
            minDensity >= 0.10;
        }
      if (road.type == ROAD3)
        {
          return avg >= 0.16 &&
            maxDensity >= 0.18 &&
            minDensity >= 0.06;
        }
      if (road.type == ROAD4)
        {
          return avg >= 0.12 &&
            maxDensity >= 0.14 &&
            minDensity >= 0.04;
        }

      return avg >= 0.09 &&
        maxDensity >= 0.11 &&
        minDensity >= 0.02;
    }

// compare roads for deterministic merge ordering
  function compareRoads(a: RoadSegment, b: RoadSegment): Int
    {
      var typeDelta = getRoadTypeOrder(a.type) - getRoadTypeOrder(b.type);
      if (typeDelta != 0)
        return typeDelta;

      var aHorizontal = a.y1 == a.y2;
      var bHorizontal = b.y1 == b.y2;
      if (aHorizontal != bHorizontal)
        return (aHorizontal ? -1 : 1);

      if (aHorizontal)
        {
          if (a.y1 != b.y1)
            return a.y1 - b.y1;
          if (a.x1 != b.x1)
            return a.x1 - b.x1;
          return a.x2 - b.x2;
        }

      if (a.x1 != b.x1)
        return a.x1 - b.x1;
      if (a.y1 != b.y1)
        return a.y1 - b.y1;
      return a.y2 - b.y2;
    }

// return whether two roads are identical
  function areSameRoad(a: RoadSegment, b: RoadSegment): Bool
    {
      return a.type == b.type &&
        a.x1 == b.x1 &&
        a.y1 == b.y1 &&
        a.x2 == b.x2 &&
        a.y2 == b.y2;
    }

// return whether two roads can be merged into one segment
  function canMergeRoads(a: RoadSegment, b: RoadSegment): Bool
    {
      if (a.type != b.type)
        return false;

      var aHorizontal = a.y1 == a.y2;
      if (aHorizontal != (b.y1 == b.y2))
        return false;

      var gap = PLAN_CELL_SIZE * 2;
      if (aHorizontal)
        {
          return a.y1 == b.y1 &&
            b.x1 <= a.x2 + gap;
        }

      return a.x1 == b.x1 &&
        b.y1 <= a.y2 + gap;
    }

// merge two compatible roads into one segment
  function mergeRoads(a: RoadSegment, b: RoadSegment): RoadSegment
    {
      if (a.y1 == a.y2)
        {
          return {
            x1: Std.int(Math.min(a.x1, b.x1)),
            y1: a.y1,
            x2: Std.int(Math.max(a.x2, b.x2)),
            y2: a.y2,
            type: a.type,
          };
        }

      return {
        x1: a.x1,
        y1: Std.int(Math.min(a.y1, b.y1)),
        x2: a.x2,
        y2: Std.int(Math.max(a.y2, b.y2)),
        type: a.type,
      };
    }

}
