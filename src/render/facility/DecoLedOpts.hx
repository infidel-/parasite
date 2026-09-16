// what one run of blinking status specks needs. Replaces render.facility.FacilityDeco.machLights'
// nine positional args, which is where the repo's own arg-list rule bit: the second machine wants
// the SAME run at different slots, a different height and a different speck size, and appending
// three more bare Floats to a call already reading `(leds, x0, x1, z0, z1, y, h, dir, col, row)`
// is a call site nobody can check by eye.
//
// The three fields at the bottom are the ones that vary between the two machines, and they are
// fractions OF THE FACE and never world units on purpose: a unit is drawn by render.Models.instanced
// scaled by height alone, so a slot measured off the art holds at any size the family is dealt at.

package render.facility;

typedef DecoLedOpts = {
  // the unit's footprint, world — render.facility.FacilityDeco.rectOf's own rect
  x0:Float,
  x1:Float,
  z0:Float,
  z1:Float,
  // the floor it stands on, and how tall it stands
  y:Float,
  h:Float,
  // which of the cell's four hands its wall is on, in FacilityGeom.face's numbering
  dir:Int,
  // and its identity, which is the only thing separating two units' phase: the clock is shared and
  // the slot phases below are fixed
  col:Int,
  row:Int,
  // the slots, as fractions ACROSS the face from the TEXTURE'S own u origin
  us:Array<Float>,
  // how far UP the face the run sits, as a fraction of `h`
  v:Float,
  // each speck, as a fraction of the face's width
  size:Float,
  // and the slot the run turns from amber to green at — `blink` reads the hue channel
  greenFrom:Int,
  // WHICH PATTERN the run burns, as the base of that same hue channel: FacilityStyle.DECO_LED_CHASE
  // for the machine's one-way sequencer, .DECO_LED_SCAN for the analyser's bouncing head. Two units
  // standing five units apart in one shed, running the same five-dot chase, read as one object drawn
  // twice — which is what was reported — and a pattern is the only thing that can separate them: the
  // clock is shared and the slot phases are fixed
  mode:Float,
};
