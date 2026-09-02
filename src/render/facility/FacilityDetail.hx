package render.facility;

import render.facility.FacilityModel.Facility;
import render.world.ContactMaskOpts;

// what the facility hands render.world.ContactMask to paint its fake ambient occlusion from: the
// masonry, as rectangles.
//
// there is no geometry in this file and that is the whole design. THE QUAD VERSION WAS BUILT FIRST
// AND SHIPPED BROKEN — one gradient quad per wall face, the shape render.sewer.SewerDetail and
// render.world.roofs.RoofShadows both use — and it failed on a fact this file's own `slab` call
// makes obvious in hindsight: a sewer wall face IS the cell boundary, so its strips tile, while a
// facility wall is a SLAB that insets by (CELL - thick)/2 wherever the wall line does not carry.
// Counting how many strips covered each point along one straight run measured `111...1111211132` —
// a GAP at every inset, a DOUBLE or TRIPLE at every notch, and since a quad's alpha is uniform along
// its run, every one of those steps was a hard edge. Reported from the game as missing corners and
// lines beside doors; the band was in fact discontinuous everywhere.
//
// a blurred field has no tiles to fail to meet, so the corners, the doorways, the insets, the
// notches and the T-junctions are all just edges in one picture
class FacilityDetail
{
// every rectangle of masonry in the compound, as the SOLID boxes and the HOLES punched back out of
// them. ContactMask paints them in that order.
//
// two subtleties, both of them the reason this returns rects rather than a per-cell predicate:
//   A WALL CELL IS THE UNION OF ITS RUNS, NEVER ITS BOUNDING BOX. `slab` is the box, and at a corner
//     or a T it is strictly bigger than the masonry — the difference is exactly `notches`, so the
//     boxes go in as solid and the notches come back out as holes. Erasing them is also what puts
//     the blur round an inside corner, which is where the quad version needed a radial it never got.
//   A DOORWAY HOLDS NO MASONRY AT FLOOR LEVEL. `carries` counts a door cell so the wall line reads
//     as continuous through it — right for the shell, which has a lintel to emit up at DOOR_H, and
//     wrong down here. Skipping it is the whole of the doorway behaviour: no masonry, no darkening,
//     and the band fades out into the opening over the blur width with nothing written for it
  public static function masonry(m:Facility):{ solid:Array<ContactRect>, holes:Array<ContactRect> }
    {
      var solid:Array<ContactRect> = [];
      var holes:Array<ContactRect> = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!FacilityModel.isWall(m, col, row) ||
                FacilityModel.isDoor(m, col, row))
              continue;
            solid.push(FacilityGeom.slab(m, col, row));
            for (n in FacilityGeom.notches(m, col, row))
              holes.push(n);
          }
      return {
        solid: solid,
        holes: holes,
      };
    }
}
