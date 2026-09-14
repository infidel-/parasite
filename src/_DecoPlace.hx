// where one decoration may appear: the place tags gen.Deco deals it by.
//
// This replaces Const._Fitting's two booleans (`high`, `themed`) with two LISTS, which is the whole
// point: `high` could only ever say "not low", and `themed` could only say "not in the random roll",
// so the washroom's cubicle had to be excluded by a flag rather than described by where it belongs.
// A place tag says it directly — a cubicle's block is the washroom, and nothing filters it out of a
// laboratory because it was never in that list.
//
// `frames` is still the persisted identity and must stay unique across the table: an objects
// .Decoration saves only imageRow/imageCol, and Const.fittingOf(row, col) is what reads the kind back
// out of a save made before any of this existed. Never renumber a frame; add one.

import Const;

typedef _DecoPlace = {
  // stable name, for a log line or a pack override. not persisted
  var id: String;
  // every entities64 cell that draws this decoration. one is picked at random when it is dealt
  var frames: Array<_FittingFrame>;
  // what render.facility.FacilityDeco draws it as in 3D. absent = it keeps its 2D sprite
  @:optional var kind: _FittingKind;
  // which SURFACE it stands on: 'floor-high' (standing furniture, plain masonry behind it),
  // 'floor-low' (knee-high, may stand under glazing), 'table' (on a bench worktop)
  var mount: Array<String>;
  // which kind of room it belongs in: 'lab', 'cabinet' (a researcher's office), 'toilet'. These are
  // the same strings _Room.role carries (gen.facility.FacilityTemp.ROLE_*), with 'lab' for the null
  // role, so a room deals its own furniture by passing its own role through
  var blocks: Array<String>;
}
