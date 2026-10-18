// generator - what one corp tower floor looks like while it is being built
//
// passed down every pass of corp generation and thrown away at the end of it. Nothing here is
// persisted: the cell grid inside the ctx is saved verbatim, and the two lists are copied into
// game.AreaGame.generatorInfo by the live adapter. See docs/area-gen.md.
//
// THERE IS NO `all*` PAIR HERE, unlike gen.facility._FacilityState, and that is not an omission: a
// corp area is ONE floor plate with one set of rooms, where a compound is two lab buildings plus a
// shed and had to fold three structures' records together.

package gen.corp;

import gen.GenCtx;

typedef _CorpState = {
  // the grid being written, the seeded rng and the spawn list — NOT a game.AreaGame. Generation
  // reaches nothing else, which is what lets tools/genrun.mjs run this package with no Game behind
  // it; gen.GenSpawner turns the spawns into real objects afterwards
  var area: GenCtx;

  // the floor plate's own rect, in cells, inclusive. read by the room-level passes, which need to
  // know where the outer wall ring is without walking back up the tree
  var px1: Int;
  var py1: Int;
  var px2: Int;
  var py2: Int;

  // which of the four outer walls the lift stands against, as the direction the main corridor runs
  // INWARD from it (game.AreaGenerator.DIR_*). the elevator block and the corridor both read it
  var frontDir: Int;

  // every room and door on the floor, in generation order. this is what lands in
  // area.generatorInfo
  var rooms: Array<_Room>;
  var doors: Array<_Door>;
  // room ids are unique across the area and are also written into the cell grid as marks
  var nextRoomID: Int;
}
