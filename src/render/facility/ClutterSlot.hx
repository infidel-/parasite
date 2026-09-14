package render.facility;

// one footprint on a flat surface, and the whole of this compound's occupancy model for one.
//
// A WORKTOP IS NEVER SPLIT INTO CELLS, IT IS CLAIMED. Every piece standing or lying on it adds its own
// box to ONE ordered list, and nothing placed after it may land on a box already in the list — so a
// slot is taken by exactly one piece whether that piece is a 2D decal, a billboard sprite or a glb.
// The list is built in PRIORITY order and that order is the whole arbitration: what cannot be moved
// goes in first (the decoration the generator left in the save, then the machines, whose offsets are
// geometry), and what rolls reads it.
//
// A BOX AND NOT THE RADIUS IT REPLACES, and an office desk is why. Three keep-clear CIRCLES used to
// stand in for whole families of object — WORK_CLEAR 1.05 for a screen, a tower and a keyboard
// TOGETHER, WORK_TRINKET_CLEAR 0.65 for objects 0.40 to 1.00 wide — and on a 4.0 x 2.6 desk that is
// wrong in both directions at once: a circle wide enough to cover the 0.8 x 1.5 tower also swallows
// the 1.1 units of free worktop in FRONT of it, and one sized to the tower's WIDTH leaves the rest of
// its depth unclaimed. Reported from the game both ways round, a decal under the tower and a lamp on
// the desk's paperwork. Everything here is an axis-aligned box on an axis-aligned desk and the exact
// test is two comparisons — cheaper than the fudge factor it retires.
//
// THE YAW IS ALREADY IN THE EXTENTS. A decal and a trinket are turned freely about their own centre,
// so `turned` resolves the box at the angle it is actually drawn at rather than reserving the
// half-DIAGONAL for every angle — which is 1.41x the object at a yaw of 0, and on a desk that is the
// difference between the paperwork fitting and not.
//
// AND THE CLEARANCE IS NOT. `hits` adds CLUTTER_GAP once per PAIR; carrying it inside both boxes
// counts it twice, which is 0.24 of a 2.6-deep desk spent on nothing
typedef ClutterSlot = {
  // centre, world
  x:Float,
  z:Float,
  // half extents on world x and z, the object's OWN — the gap between two of them is `hits`'
  hw:Float,
  hd:Float,
};

class ClutterSlotTools
{
// would a box of these half extents at (x, z) land on something already claimed? the separating-axis
// test for two axis-aligned rects, which is two comparisons: they miss if EITHER axis separates them,
// and that is the half of it a circle could never state
  public static function hits(slots:Array<ClutterSlot>, x:Float, z:Float, hw:Float,
      hd:Float):Bool
    {
      var g = FacilityStyle.CLUTTER_GAP;
      for (s in slots)
        if (Math.abs(x - s.x) < hw + s.hw + g &&
            Math.abs(z - s.z) < hd + s.hd + g)
          return true;
      return false;
    }

// the world-axis box of a w x d object turned `yaw` about its own centre
  public static function turned(x:Float, z:Float, w:Float, d:Float, yaw:Float):ClutterSlot
    {
      var c = Math.abs(Math.cos(yaw)), s = Math.abs(Math.sin(yaw));
      return {
        x: x,
        z: z,
        hw: (w * c + d * s) * 0.5,
        hd: (w * s + d * c) * 0.5,
      };
    }

// and the box of one that is NOT turned, which is every machine on a desk: a desk hugs a wall and a
// wall runs on an axis, so `alongX` is the whole of its rotation — true when the object's authored
// WIDTH lies on world x, which is render.facility.FacilityWork's own `dir < 2`
  public static function flat(x:Float, z:Float, w:Float, d:Float, alongX:Bool):ClutterSlot
    {
      return {
        x: x,
        z: z,
        hw: (alongX ? w : d) * 0.5,
        hd: (alongX ? d : w) * 0.5,
      };
    }
}
