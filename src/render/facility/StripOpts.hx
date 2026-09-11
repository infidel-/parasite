package render.facility;

// one cable run, as render.facility.FacilityCable.strip takes it. REPLACED the 5-positional
// strip(b, a, c, dir, seed) when the floor runs arrived and it would have grown to nine: the plane
// stopped being a wall face, the bow stopped being gravity, and neither could be spelled by an Int.
typedef StripOpts = {
  // where the run starts and ends, world. both must lie IN the plane `n` describes
  a:Array<Float>,
  c:Array<Float>,
  // the plane the ribbon lies in, as its NORMAL — the wall's own outward normal for a run bolted to
  // masonry, straight up for one lying on a floor. the ribbon is widened and bowed along
  // n cross t, so it never leaves this plane
  n:Array<Float>,
  // and which way the bow should point, as a hint vector: down for a wall run, out into the room for
  // one along a skirting. null — or a chord too nearly parallel to it to answer — leaves the side to
  // the seed, which is what a cable dropped across a floor actually does
  ?side:Array<Float>,
  // how far the middle of the run leaves the straight chord, world units
  bow:Float,
  // plus a slow sine on top of it, same units, so two runs are not parallel curves
  wave:Float,
  // the wander's phase, rolled ONCE off FacilityModel.mix and baked. nothing here ticks
  seed:Int,
};
