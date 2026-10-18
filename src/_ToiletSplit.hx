// generator - how a washroom was divided, as game.FacilityAreaGenerator.toiletPartition left it.
//
// the shape is a T: a BAR one cell in from the entrance wall with its two end cells left open, and a
// STEM from the middle of the bar to the far wall. Everything roomToilet then places has to know
// which of the two halves a cell is in and which strip is the lobby, and all of that is these five
// numbers — see that function's own header for the layout
typedef _ToiletSplit = {
  // the two cells left open at the ends of the bar: nothing may ever stand in them
  pass: Array<{ x: Int, y: Int }>,
  // does the BAR run along y (a door in a left/right wall)? the stem then runs along x
  vertical: Bool,
  // the bar's own column (vertical) or row (horizontal)
  bar: Int,
  // and the lobby strip's, on the entrance side of it. -1 on a room too small for a T
  lobby: Int,
  // where the stem crosses the bar: its row (vertical bar) or column (horizontal bar), which is also
  // what a cell's half is decided by. -1 when there is no stem, i.e. when the room has no halves
  stem: Int,
}
