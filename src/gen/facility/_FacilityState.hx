// generator - what one compound looks like while it is being built
//
// passed down every pass of facility generation and thrown away at the end of it. Nothing here is
// persisted: the cell grid inside the ctx is saved verbatim, and the two `all*` lists are copied
// into game.AreaGame.generatorInfo by the live adapter. See docs/area-gen.md.

package gen.facility;

import gen.GenCtx;

typedef _FacilityState = {
  // the grid being written, the seeded rng and the spawn list — NOT a game.AreaGame. Generation
  // reaches nothing else, which is what lets tools/genrun.mjs run this package with no Game behind
  // it; gen.GenSpawner turns the spawns into real objects afterwards
  var area: GenCtx;
  var mainRoadNorth: Bool;

  // temp state: the CURRENT structure's rooms and doors. every pass inside
  // FacilityBuilding.generateBuilding (fixDoors, makeDoorToCorridor, makeWindows,
  // generateRoomContents) works on these and must not see a previous structure's, so they are reset
  // per structure and folded into the two lists below
  var rooms: Array<_Room>;
  var doors: Array<_Door>;

  // every structure's rooms and doors, in generation order. this is what lands in
  // area.generatorInfo: the 3D layer places a ceiling light per room and fades a roof per structure,
  // and the missions and AreaView's room-reveal read the same record, so it has to describe the
  // WHOLE area rather than whichever building happened to be generated last
  var allRooms: Array<_Room>;
  var allDoors: Array<_Door>;
  // room ids are unique across the whole area, never restarted per structure: _Door.roomID1/2 and
  // _GeneratorInfo.getRoom() key on them, and they are also written into the cell grid as marks
  var nextRoomID: Int;
}
