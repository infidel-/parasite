package render.facility;

// where the workstation on one office desk cell stands, as render.facility.FacilityWork.at works it
// out. Replaced the anonymous `{ x, z, dir }` that function used to return, once a third pass needed
// the TOWER's hand as well as the set's centre — see `side`.
//
// THREE PASSES ASK FOR THIS AND NONE OF THEM MAY RUN FIRST: FacilityTables wants the centre for the
// contact pool under the screen, FacilityClutter wants the centre AND the tower to keep the desk's
// paperwork off both, and FacilityWork.build wants all of it for the geometry. So every field here is
// a pure function of the saved grid and nothing here is state
typedef WorkSpot = {
  // the set's centre, world: the screen's foot, and the point every other piece is measured off
  x:Float,
  z:Float,
  // the hand the desk's wall is on, in FacilityGeom.face's order
  dir:Int,
  // the tower's own centre, world — WORK_TOWER_OFF along the run axis from the centre above
  tx:Float,
  tz:Float,
  // and which way that is, +1 or -1 along the run axis. what says which END of the desk is free
  side:Float,
}
