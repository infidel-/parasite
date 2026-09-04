package render.facility;

// one wall-hugging thing's silhouette on the masonry behind it — what render.facility.FacilityDetail
// .stand collects and `halos` draws a contact shadow from.
//
// replaces stand(col, row, dir, a0, a1, y, h), which is seven positional arguments and so a call
// site of bare numbers where the two spans and the two heights are silently swappable. the emitter
// takes the wall slab and its room-facing plane off `col`/`row`/`dir` itself, so a caller hands over
// what it already computed for its own placement and re-derives nothing.
typedef FacilityHaloOpts = {
  // the standing thing's OWN cell, not the wall's — the emitter steps to the masonry itself
  col:Int,
  row:Int,
  // which hand that masonry is on, in render.facility.FacilityGeom's numbering (0 = -z, 1 = +z,
  // 2 = -x, 3 = +x). the face the shadow lands on is the opposite one, `dir ^ 1`
  dir:Int,
  // the thing's extent ALONG that wall, world units. it is a span and not a width because the
  // callers have already slid or clamped their object against the wall's own ends
  a0:Float,
  a1:Float,
  // how many CELLS it runs along that wall — 1 for a single object, more for a bench block or a
  // casework run. it exists only so the emitter can clamp to the whole run's masonry rather than to
  // the first cell's slab, which would cut a 4-cell run down to one
  len:Int,
  // the floor it stands on, world units
  y:Float,
  // and how tall it stands off that floor
  h:Float,
}
