package gen.cave;

// what one cave generation hands back besides the grid
typedef _CaveState = {
  // the chambers, recorded as generatorInfo.rooms with role 'chamber'
  var rooms: Array<_Room>;
  // the two cave mouths (habitat exits), each on floor backed by a straight rock run north, west or east
  var exits: Array<{ x: Int, y: Int }>;
  // rolls it took to get an acceptable cave (CaveGen.MAX_TRIES means the last one was kept as it was)
  var tries: Int;
}
