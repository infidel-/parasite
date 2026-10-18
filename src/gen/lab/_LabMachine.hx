package gen.lab;

// one kind of machine the underground lab stands, as gen.lab.LabKinds.MACHINES lists them. Its index
// in that table is its identity: the cell its footprint starts from holds
// Const.TILE_LAB_MACHINE0 + index, and that is all a save keeps of it
typedef _LabMachine = {
  // short name, also the model's key (render.lab draws `lab/<name>`)
  var name: String;
  // its footprint in cells: `len` along its long side, `depth` across it. A wall machine backs onto
  // its wall with the long side
  var len: Int;
  var depth: Int;
  // does it stand against a wall (its back to the masonry), or out on the floor
  var wall: Bool;
  // can the cell be walked: a one-cell unit hung or stood in the wall's margin, like a locker
  var stand: Bool;
  // the room roles it is dealt in (gen.blocks.LabBlocks.ROLE_*)
  var rooms: Array<String>;
}
