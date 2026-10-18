package render.facility;

// one small object standing on an office desk, as render.facility.FacilityWork.trinket rolls it.
//
// TWO PASSES ASK FOR THIS AND NEITHER MAY RUN FIRST, exactly as for WorkSpot beside it: FacilityWork
// itself wants the placements for the batches and the contact pools, and FacilityClutter wants them
// to keep the desk's paperwork off them. So this is a pure function of the saved grid too
typedef TrinketSpot = {
  // which of FacilityWork.TRINKETS this is — the index carries the model, the height and the extents
  kind:Int,
  // and where it stands, world. The y is always FacilityStyle.BENCH_H: a desk is the only thing these
  // ever stand on
  x:Float,
  z:Float,
  // and which way it is turned. NOT the desk's own yaw, which is what every one of them took for one
  // build: four desks in a row with four mugs all facing the same way is a shop display. A mug and a
  // plant have no front worth aiming, a lamp and a tray only read as PUT DOWN if they are not square
  // to the edge, so this is a free turn rolled off the cell
  yaw:Float,
}
