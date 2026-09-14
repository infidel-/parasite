package gen;

// one object the generator wants standing in the area, recorded rather than constructed.
//
// THE REASON THIS TYPE EXISTS: `new Decoration(game, ...)` runs AreaObject.initPost, which runs
// createEntity(), which builds an ObjectEntity and reaches the renderer — so constructing a single
// decoration drags in the whole display stack and a Game to hang it off. A generator that does that
// can only run inside a booted game, which means the only way to check a layout is to launch
// Electron and walk across the compound.
//
// so generation records intents and gen.GenSpawner turns them into real AreaObjects afterwards, on
// the live path only. The headless oracle simply counts them. Nothing here is persisted — the
// spawned objects are, exactly as they always were.
typedef _GenSpawn = {
  // what to build: 'decoration', 'door', 'vent', 'sewerHatch', 'floorDrain'. the same strings
  // AreaObject.type carries, so a filter written against one reads correctly against the other —
  // game.FacilityAreaGenerator.clearTableSpots asks `o.type == 'decoration'` either way
  var type: String;
  var x: Int;
  var y: Int;
  // the entities64 cell a decoration draws with. THIS IS THE DECORATION'S IDENTITY and the only
  // part of it that survives a save: Const.fittingOf(row, col) is how the renderer recovers which
  // 3D fitting a saved decoration is, so the frame is a key and not a picture
  @:optional var row: Int;
  @:optional var col: Int;
  // a door's OPEN frame, on the same row as its closed one
  @:optional var col2: Int;
}
