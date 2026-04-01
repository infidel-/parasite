// road styling, rasterization, and road painting helpers

package map;

import map.RoadType;
import map.Types.RoadMasks;
import map.Types.RoadSegment;
import map.Types.RoadStyle;

class Raster extends Ground
{
// return a sortable road-type order
  function getRoadTypeOrder(type: RoadType): Int
    {
      return switch (type) {
        case ROAD1: 0;
        case ROAD2: 1;
        case ROAD3: 2;
        case ROAD4: 3;
        case ROAD5: 4;
      };
    }

// return one road type from its sortable order
  function getRoadTypeByOrder(order: Int): RoadType
    {
      return switch (order) {
        case 0: ROAD1;
        case 1: ROAD2;
        case 2: ROAD3;
        case 3: ROAD4;
        default: ROAD5;
      };
    }

// rasterize road centerlines into planning masks
  function rasterizeRoadMasks(list: Array<RoadSegment>): RoadMasks
    {
      var masks: RoadMasks = {
        width: planWidth,
        height: planHeight,
        core: makeFloatGrid(planWidth, planHeight),
        shoulder: makeFloatGrid(planWidth, planHeight),
        feather: makeFloatGrid(planWidth, planHeight),
        occupancy: makeFloatGrid(planWidth, planHeight),
        color: makeIntGrid(planWidth, planHeight),
        paintSpan: makeIntGrid(planWidth, planHeight),
        axis: makeIntGrid(planWidth, planHeight),
        directionMask: makeIntGrid(planWidth, planHeight),
        priority: makeIntGrid(planWidth, planHeight),
      };

      for (road in list)
        rasterizeRoad(masks, road);

      return masks;
    }

// rasterize one road into the planning masks
  function rasterizeRoad(masks: RoadMasks, road: RoadSegment)
    {
      var style = getRoadStyle(road.type);
      var shoulderRadius = style.coreWidth / 2.0 + style.shoulderWidth;
      var featherRadius = shoulderRadius + style.featherWidth;
      var minX = Std.int(Math.floor((Math.min(road.x1, road.x2) - featherRadius) / PLAN_CELL_SIZE));
      var maxX = Std.int(Math.ceil((Math.max(road.x1, road.x2) + featherRadius) / PLAN_CELL_SIZE));
      var minY = Std.int(Math.floor((Math.min(road.y1, road.y2) - featherRadius) / PLAN_CELL_SIZE));
      var maxY = Std.int(Math.ceil((Math.max(road.y1, road.y2) + featherRadius) / PLAN_CELL_SIZE));

      minX = clampInt(minX, 0, planWidth - 1);
      maxX = clampInt(maxX, 0, planWidth - 1);
      minY = clampInt(minY, 0, planHeight - 1);
      maxY = clampInt(maxY, 0, planHeight - 1);

      for (yy in minY...maxY + 1)
        for (xx in minX...maxX + 1)
          {
            var px = xx * PLAN_CELL_SIZE + PLAN_CELL_SIZE / 2.0;
            var py = yy * PLAN_CELL_SIZE + PLAN_CELL_SIZE / 2.0;
            var dist = getPointToRoadDistance(px, py, road);

            if (style.featherWidth > 0 &&
                dist <= featherRadius)
              {
                var featherAlpha = (featherRadius - dist) / Math.max(style.featherWidth, 1);
                if (featherAlpha > 1.0)
                  featherAlpha = 1.0;
                masks.feather[xx][yy] = Math.max(masks.feather[xx][yy], featherAlpha);
              }

            if (dist <= shoulderRadius)
              {
                masks.shoulder[xx][yy] = 1.0;
                masks.occupancy[xx][yy] = 1.0;
              }

            if (dist <= style.coreWidth / 2.0)
              masks.core[xx][yy] = 1.0;

            if (dist <= featherRadius &&
                style.priority >= masks.priority[xx][yy])
              {
                var axisFlag = (road.y1 == road.y2 ? 1 : 2);
                var directionMask = getRoadSegmentDirectionMaskForCell(road, xx, yy);
                if (style.priority > masks.priority[xx][yy])
                  {
                    masks.priority[xx][yy] = style.priority;
                    masks.color[xx][yy] = style.color;
                    masks.paintSpan[xx][yy] = getRoadPaintSpan(road.type);
                    masks.axis[xx][yy] = axisFlag;
                    masks.directionMask[xx][yy] = directionMask;
                  }
                else
                  {
                    masks.color[xx][yy] = style.color;
                    masks.paintSpan[xx][yy] = Std.int(Math.max(masks.paintSpan[xx][yy],
                      getRoadPaintSpan(road.type)));
                    masks.axis[xx][yy] = masks.axis[xx][yy] | axisFlag;
                    masks.directionMask[xx][yy] = masks.directionMask[xx][yy] | directionMask;
                  }
              }
          }
    }

// return which sides of one plan cell are touched by one orthogonal segment
  function getRoadSegmentDirectionMaskForCell(road: RoadSegment, xx: Int, yy: Int): Int
    {
      var cellX = xx * PLAN_CELL_SIZE;
      var cellY = yy * PLAN_CELL_SIZE;
      var centerX = cellX + Std.int(PLAN_CELL_SIZE / 2);
      var centerY = cellY + Std.int(PLAN_CELL_SIZE / 2);
      var mask = 0;

      if (road.y1 == road.y2)
        {
          var minX = Std.int(Math.min(road.x1, road.x2));
          var maxX = Std.int(Math.max(road.x1, road.x2));
          if (minX < centerX)
            mask = mask | 1;
          if (maxX > centerX)
            mask = mask | 2;
          return mask;
        }

      var minY = Std.int(Math.min(road.y1, road.y2));
      var maxY = Std.int(Math.max(road.y1, road.y2));
      if (minY < centerY)
        mask = mask | 4;
      if (maxY > centerY)
        mask = mask | 8;
      return mask;
    }

// paint the rasterized road layers
  function paintRoads()
    {
      for (yy in 0...planHeight)
        for (xx in 0...planWidth)
          {
            var alpha = roadMasks.feather[xx][yy] * 0.16 +
              roadMasks.shoulder[xx][yy] * 0.26 +
              roadMasks.core[xx][yy] * 0.72;
            if (alpha <= 0.0)
              continue;

            ctx.globalAlpha = clampFloat(alpha, 0.0, 1.0);
            ctx.fillStyle = '#' + StringTools.hex(getRoadPaintColor(xx, yy), 6);
            var cellX = xx * PLAN_CELL_SIZE;
            var cellY = yy * PLAN_CELL_SIZE;
            var paintSpan = roadMasks.paintSpan[xx][yy];
            var axis = roadMasks.axis[xx][yy];
            var offset = Std.int((PLAN_CELL_SIZE - paintSpan) / 2);
            if (roadMasks.color[xx][yy] == COLOR_ROAD2)
              {
                paintRoad2WideCell(xx, yy, cellX, cellY, paintSpan, offset);
                continue;
              }
            if (paintSpan <= 0 || paintSpan >= PLAN_CELL_SIZE)
              {
                fillRoadRect(cellX, cellY, PLAN_CELL_SIZE, PLAN_CELL_SIZE);
                continue;
              }
            if (roadMasks.color[xx][yy] == COLOR_ROAD4 ||
                roadMasks.color[xx][yy] == COLOR_ROAD5)
              {
                paintThinRoadJoinCell(xx, yy, cellX, cellY, paintSpan, offset, axis);
                continue;
              }
            switch (axis)
              {
                case 1:
                  fillRoadRect(cellX, cellY + offset, PLAN_CELL_SIZE, paintSpan);
                case 2:
                  fillRoadRect(cellX + offset, cellY, paintSpan, PLAN_CELL_SIZE);
                case 3:
                  fillRoadRect(cellX, cellY + offset, PLAN_CELL_SIZE, paintSpan);
                  fillRoadRect(cellX + offset, cellY, paintSpan, PLAN_CELL_SIZE);
                default:
                  fillRoadRect(cellX + offset, cellY + offset, paintSpan, paintSpan);
              }
          }
      ctx.globalAlpha = 1.0;
    }

// fill one road rect in map canvas space
  function fillRoadRect(x: Int, y: Int, width: Int, height: Int)
    {
      ctx.fillRect(x, y, width, height);
    }

// paint one ROAD2 occupied cell using the paired 2-cell road band
  function paintRoad2WideCell(xx: Int, yy: Int, cellX: Int, cellY: Int,
      paintSpan: Int, offset: Int)
    {
      if (roadPlanGrid == null ||
          !roadPlanGrid.road2Cells[xx][yy])
        {
          fillRoadRect(cellX, cellY, PLAN_CELL_SIZE, PLAN_CELL_SIZE);
          return;
        }

      var axisMask = roadPlanGrid.road2AxisMask[xx][yy];
      if ((axisMask & 1) != 0)
        paintRoad2HorizontalCell(xx, yy, cellX, cellY, paintSpan, offset);
      if ((axisMask & 2) != 0)
        paintRoad2VerticalCell(xx, yy, cellX, cellY, paintSpan, offset);
      if (axisMask == 0)
        fillRoadRect(cellX + offset, cellY + offset, paintSpan, paintSpan);
    }

// paint the horizontal half of one ROAD2 cell inside its 2-row band
  function paintRoad2HorizontalCell(xx: Int, yy: Int, cellX: Int, cellY: Int,
      paintSpan: Int, offset: Int)
    {
      var topSpan = Std.int(Math.floor(paintSpan / 2.0));
      var bottomSpan = paintSpan - topSpan;

      if ((yy & 1) == 0 &&
          hasRoad2AxisPair(xx, yy, xx, yy + 1, 1))
        {
          fillRoadRect(cellX, cellY + PLAN_CELL_SIZE - topSpan, PLAN_CELL_SIZE, topSpan);
          return;
        }
      if ((yy & 1) == 1 &&
          hasRoad2AxisPair(xx, yy, xx, yy - 1, 1))
        {
          fillRoadRect(cellX, cellY, PLAN_CELL_SIZE, bottomSpan);
          return;
        }

      fillRoadRect(cellX, cellY + offset, PLAN_CELL_SIZE, paintSpan);
    }

// paint the vertical half of one ROAD2 cell inside its 2-column band
  function paintRoad2VerticalCell(xx: Int, yy: Int, cellX: Int, cellY: Int,
      paintSpan: Int, offset: Int)
    {
      var leftSpan = Std.int(Math.floor(paintSpan / 2.0));
      var rightSpan = paintSpan - leftSpan;

      if ((xx & 1) == 0 &&
          hasRoad2AxisPair(xx, yy, xx + 1, yy, 2))
        {
          fillRoadRect(cellX + PLAN_CELL_SIZE - leftSpan, cellY, leftSpan, PLAN_CELL_SIZE);
          return;
        }
      if ((xx & 1) == 1 &&
          hasRoad2AxisPair(xx, yy, xx - 1, yy, 2))
        {
          fillRoadRect(cellX, cellY, rightSpan, PLAN_CELL_SIZE);
          return;
        }

      fillRoadRect(cellX + offset, cellY, paintSpan, PLAN_CELL_SIZE);
    }

// return whether two neighboring ROAD2 cells belong to the same paired band
  function hasRoad2AxisPair(xx: Int, yy: Int, neighborX: Int, neighborY: Int, axisMask: Int): Bool
    {
      if (neighborX < 0 ||
          neighborY < 0 ||
          neighborX >= planWidth ||
          neighborY >= planHeight)
        return false;
      if (roadPlanGrid == null ||
          !roadPlanGrid.road2Cells[neighborX][neighborY] ||
          roadPlanGrid.road2IDs[neighborX][neighborY] != roadPlanGrid.road2IDs[xx][yy])
        return false;
      return (roadPlanGrid.road2AxisMask[neighborX][neighborY] & axisMask) != 0;
    }

// paint one thin road cell with join caps toward facing neighbors
  function paintThinRoadJoinCell(xx: Int, yy: Int, cellX: Int, cellY: Int,
      paintSpan: Int, offset: Int, axis: Int)
    {
      var left = hasRoadPaintFacingCell(xx - 1, yy, 1, 0);
      var right = hasRoadPaintFacingCell(xx + 1, yy, -1, 0);
      var up = hasRoadPaintFacingCell(xx, yy - 1, 0, 1);
      var down = hasRoadPaintFacingCell(xx, yy + 1, 0, -1);
      var directionMask = roadMasks.directionMask[xx][yy];
      var mid = offset + Std.int(Math.ceil(paintSpan / 2.0));

// paint the current cell core
      fillRoadRect(cellX + offset, cellY + offset, paintSpan, paintSpan);
      if ((axis & 1) != 0)
        {
          var paintLeft = (directionMask & 1) != 0 || left;
          var paintRight = (directionMask & 2) != 0 || right;
          if (paintLeft ||
              paintRight)
            {
              if (paintLeft)
                fillRoadRect(cellX, cellY + offset, mid, paintSpan);
              if (paintRight)
                fillRoadRect(cellX + offset, cellY + offset, PLAN_CELL_SIZE - offset,
                  paintSpan);
            }
          else
            fillRoadRect(cellX, cellY + offset, PLAN_CELL_SIZE, paintSpan);
        }
      if ((axis & 2) != 0)
        {
          var paintUp = (directionMask & 4) != 0 || up;
          var paintDown = (directionMask & 8) != 0 || down;
          if (paintUp ||
              paintDown)
            {
              if (paintUp)
                fillRoadRect(cellX + offset, cellY, paintSpan, mid);
              if (paintDown)
                fillRoadRect(cellX + offset, cellY + offset, paintSpan,
                  PLAN_CELL_SIZE - offset);
            }
          else
            fillRoadRect(cellX + offset, cellY, paintSpan, PLAN_CELL_SIZE);
        }
    }

// return whether one nearby cell carries a matching color and axis
  function hasRoadColorAxis(xx: Int, yy: Int, color: Int, axisFlag: Int): Bool
    {
      if (xx < 0 ||
          yy < 0 ||
          xx >= planWidth ||
          yy >= planHeight)
        return false;
      if (roadMasks.color[xx][yy] != color)
        return false;
      return (roadMasks.axis[xx][yy] & axisFlag) != 0;
    }

// return whether one nearby painted cell reaches this shared edge
  function hasRoadPaintFacingCell(xx: Int, yy: Int, dx: Int, dy: Int): Bool
    {
      if (xx < 0 ||
          yy < 0 ||
          xx >= planWidth ||
          yy >= planHeight)
        return false;
      if (roadMasks.color[xx][yy] == 0)
        return false;

      var paintSpan = roadMasks.paintSpan[xx][yy];
      if (paintSpan <= 0 ||
          paintSpan >= PLAN_CELL_SIZE)
        return true;

      if (roadMasks.color[xx][yy] == COLOR_ROAD4 ||
          roadMasks.color[xx][yy] == COLOR_ROAD5)
        {
          var directionMask = roadMasks.directionMask[xx][yy];
          if (directionMask != 0)
            {
              if (dx < 0)
                return (directionMask & 1) != 0;
              if (dx > 0)
                return (directionMask & 2) != 0;
              if (dy < 0)
                return (directionMask & 4) != 0;
              if (dy > 0)
                return (directionMask & 8) != 0;
              return false;
            }
        }

      if (dx != 0)
        return (roadMasks.axis[xx][yy] & 1) != 0;
      if (dy != 0)
        return (roadMasks.axis[xx][yy] & 2) != 0;
      return false;
    }

  function getRoadStyle(type: RoadType): RoadStyle
    {
      return switch (type) {
        case ROAD1: {
          coreWidth: 11,
          shoulderWidth: 0,
          featherWidth: 0,
          color: COLOR_ROAD1,
          priority: 0,
        };
        case ROAD2: {
          coreWidth: 4,
          shoulderWidth: 0,
          featherWidth: 0,
          color: COLOR_ROAD2,
          priority: 1,
        };
        case ROAD3: {
          coreWidth: 4,
          shoulderWidth: 0,
          featherWidth: 0,
          color: COLOR_ROAD3,
          priority: 4,
        };
        case ROAD4: {
          coreWidth: 4,
          shoulderWidth: 0,
          featherWidth: 0,
          color: COLOR_ROAD4,
          priority: 5,
        };
        case ROAD5: {
          coreWidth: 2,
          shoulderWidth: 0,
          featherWidth: 0,
          color: COLOR_ROAD5,
          priority: 6,
        };
      };
    }

// return the painted sub-cell span for one road tier
  function getRoadPaintSpan(type: RoadType): Int
    {
      return switch (type) {
        case ROAD1: PLAN_CELL_SIZE;
        case ROAD2: 3;
        case ROAD3: 3;
        case ROAD4: 4;
        case ROAD5: 2;
      };
    }

  function getRoadPaintColor(xx: Int, yy: Int): Int
    {
      return 0x42434a;
    }

// return the distance from a point to an axis-aligned road segment
  function getPointToRoadDistance(px: Float, py: Float, road: RoadSegment): Float
    {
      var tx = clampFloat(px, Math.min(road.x1, road.x2), Math.max(road.x1, road.x2));
      var ty = clampFloat(py, Math.min(road.y1, road.y2), Math.max(road.y1, road.y2));
      var dx = px - tx;
      var dy = py - ty;
      return Math.sqrt(dx * dx + dy * dy);
    }


}
