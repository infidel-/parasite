// shared region map data shapes

package map;

import map.RoadType;

typedef DensityField = {
  width: Int,
  height: Int,
  values: Array<Array<Float>>,
}

typedef RoadStyle = {
  coreWidth: Int,
  shoulderWidth: Int,
  featherWidth: Int,
  color: Int,
  priority: Int,
}

typedef RoadSegment = {
  x1: Int,
  y1: Int,
  x2: Int,
  y2: Int,
  type: RoadType,
}

typedef RoadMasks = {
  width: Int,
  height: Int,
  core: Array<Array<Float>>,
  shoulder: Array<Array<Float>>,
  feather: Array<Array<Float>>,
  occupancy: Array<Array<Float>>,
  color: Array<Array<Int>>,
  paintSpan: Array<Array<Int>>,
  axis: Array<Array<Int>>,
  directionMask: Array<Array<Int>>,
  priority: Array<Array<Int>>,
}

typedef RoadPlanGrid = {
  width: Int,
  height: Int,
  horizontal: Array<Array<Int>>,
  vertical: Array<Array<Int>>,
  cornerOrder: Array<Array<Int>>,
  cornerMask: Array<Array<Int>>,
  road1Cells: Array<Array<Bool>>,
  road2Cells: Array<Array<Bool>>,
  road2IDs: Array<Array<Int>>,
  road2AxisMask: Array<Array<Int>>,
}

typedef RoadWalker = {
  x: Int,
  y: Int,
  dx: Int,
  dy: Int,
  originX: Int,
  originY: Int,
  horizontalSign: Int,
  verticalSign: Int,
  stepsSinceTurn: Int,
  stopLockSteps: Int,
  groundBlockCount: Int,
  localStopCount: Int,
  tSplitCountdown: Int,
  canSpawnThinCrossings: Bool,
  startDirectionMask: Int,
  road2ID: Int,
  type: RoadType,
}

typedef RoadBranchStart = {
  start: GridPoint,
  dx: Int,
  dy: Int,
  chance: Float,
  road1StartX: Int,
  road1StartY: Int,
  road1StepX: Int,
  road1StepY: Int,
}

typedef GridPoint = {
  x: Int,
  y: Int,
}

typedef ThinRoadStart = {
  x: Int,
  y: Int,
  dx: Int,
  dy: Int,
}

typedef Road2Attachment = {
  x: Int,
  y: Int,
  road2ID: Int,
  road1StepX: Int,
  road1StepY: Int,
  road1DX: Int,
  road1DY: Int,
}

typedef Road2Component = {
  cells: Array<GridPoint>,
  touchesRoad1: Bool,
}

typedef Road2Connector = {
  start: Road2Attachment,
  target: Road2Attachment,
}

typedef IntRect = {
  x: Int,
  y: Int,
  width: Int,
  height: Int,
}

typedef ThinAttachmentBucket = {
  key: Int,
  points: Array<GridPoint>,
}

typedef ThinAttachmentCache = {
  searchRect: IntRect,
  buckets: Array<ThinAttachmentBucket>,
}

typedef Road2CoverageAttachmentState = {
  road2Attachments: Array<Road2Attachment>,
  road1Attachments: Array<Road2Attachment>,
}

typedef BlockComponent = {
  cells: Array<GridPoint>,
  minX: Int,
  minY: Int,
  maxX: Int,
  maxY: Int,
}

typedef BlockRect = {
  x: Int,
  y: Int,
  width: Int,
  height: Int,
  density: Float,
}

typedef CityCoverageCandidate = {
  horizontal: Bool,
  cellX: Int,
  cellY: Int,
  startX: Int,
  startY: Int,
  endX: Int,
  endY: Int,
  span: Int,
  connections: Int,
}

typedef LocalGraphAnchor = {
  cellX: Int,
  cellY: Int,
  density: Float,
  degree: Int,
  maxDegree: Int,
  radius: Int,
}

typedef LocalGraphCandidate = {
  index: Int,
  score: Float,
  horizontalFirst: Bool,
}

typedef ParcelRect = {
  x: Int,
  y: Int,
  width: Int,
  height: Int,
  density: Float,
  isOpen: Bool,
}

typedef BuildingRect = {
  x: Int,
  y: Int,
  width: Int,
  height: Int,
}

typedef BuildingFootprint = {
  rects: Array<BuildingRect>,
  color: Int,
  density: Float,
  lotX: Int,
  lotY: Int,
  lotWidth: Int,
  lotHeight: Int,
  forecourtColor: Int,
  forecourtAlpha: Float,
  roofColor: Int,
  roofAlpha: Float,
  edgeAlpha: Float,
  shadowOffset: Int,
  shadowAlpha: Float,
}

typedef BuildingStyle = {
  buildChance: Float,
  margin: Int,
  minRatio: Float,
  maxRatio: Float,
  extraRectCount: Int,
  shadowAlpha: Float,
  forecourtAlpha: Float,
  centered: Bool,
}
