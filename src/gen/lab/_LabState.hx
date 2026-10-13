// generator - what one underground lab looks like while it is being built
//
// passed down every pass of lab generation and thrown away at the end of it. Nothing here is
// persisted: the cell grid inside the ctx is saved verbatim, and the rooms, doors and mission hints
// are copied into game.AreaGame.generatorInfo by the live adapter. See docs/area-gen.md.

package gen.lab;

import gen.GenCtx;

typedef _LabState = {
  // the grid being written, the seeded rng and the spawn list
  var area: GenCtx;
  // every room and doorway, in generation order: the lobby, the vat chamber, then the service rooms
  var rooms: Array<_Room>;
  var doors: Array<_Door>;
  // the corridor's top row (it is two high) and its first and last column
  var corridorY: Int;
  var cx1: Int;
  var cx2: Int;
  // the vat chamber, its doorway's upper cell, the four 2x3 pads round its middle and their records,
  // which is the contract objects.mission.CloneVat's mission reads (game._GeneratorMissionHints)
  var vatRoomID: Int;
  var vatDoor: _Point;
  var vatAnchors: Array<_Point>;
  var reservedRects: Array<_ReservedRect>;
  // cells no furniture may take: the pads, the bare ring round them, and the cells beside the lift
  var keep: Array<Array<Bool>>;
  // how many of each machine kind the level stands so far, so a zone deals the rarest one first and
  // a level shows as many kinds as it has room for
  var used: Array<Int>;
  // how many layouts the plate drew before one fitted, for the stats
  var tries: Int;
}
