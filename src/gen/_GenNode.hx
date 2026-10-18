package gen;

// one node of the generation tree: a rect, what it is, and what it was divided into.
//
// the whole structure of an area is a tree of these — the area splits into blocks, a block into
// rooms or sub-blocks, a room into the runs and islands its furniture stands on — and one DFS
// (gen.GenTree.build) walks it, handing each node to the filler registered for its `kind`.
//
// NOT PERSISTED, deliberately. Nothing downstream reads blocks: the renderer, the lighting and the
// missions all re-derive what they need from the saved cell grid (render.facility.FacilityModel
// .fromArea, render.wild.WildModel, game.AreaGame.gate), and _Room already carries the one piece of
// per-room intent that has to survive a save. A persisted tree would be a second source of truth
// that every old save lacks, for no reader.
typedef _GenNode = {
  // inclusive bounds, the same convention _Room uses: x2,y2 is the LAST cell, not one past it
  var x1: Int;
  var y1: Int;
  var x2: Int;
  var y2: Int;
  // what this node is, and so which filler builds it: 'area', 'road', 'park', 'hangar', 'building',
  // 'parking', 'entryway', 'yard'. a kind with no filler registered is a leaf that writes nothing,
  // which is what lets a tree be built and inspected before its fillers exist
  var kind: String;
  // what this node divided into. filled by the node's own filler during the walk, so the tree is
  // grown by the traversal rather than built up front
  var children: Array<_GenNode>;
  // set when this node became a _Room, so a sub-block can find the room it belongs to without a
  // lookup by coordinate
  @:optional var roomID: Int;
  // free-form marks a filler leaves for its own children, e.g. which wall of a building this block
  // faces. same vocabulary as _Room.tags
  @:optional var tags: Array<String>;
}
