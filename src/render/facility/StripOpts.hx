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
  // how far the middle of the run leaves the straight chord, world units, ALONG n cross t
  bow:Float,
  // and how far it FALLS on the way across, as a FRACTION of the chord's own length. this is not the
  // bow under another name: the ribbon is widened along the bow's axis, so a bow can only ever swing
  // a run sideways, and a span hung between two poles has to carry its own weight instead. the drop
  // is perpendicular to the chord and taken out of world DOWN, so both ends stay bolted where they
  // are and a vertical run has no sag to take. omitted for every run bolted to a surface
  ?sag:Float,
  // plus a slow sine on top of it, same units, so two runs are not parallel curves
  wave:Float,
  // MESSY: world units of fast, seeded wander on top of the bow and the wave — two higher harmonics
  // at rolled frequencies, carried right up to the plugs, on CABLE_MESS_STEPS times the segments a
  // tidy run takes so the kinks are curves and not corners. A lead somebody threw across a floor
  // rather than one dressed along it. omitted (0) for every tidy run
  ?mess:Float,
  // the wander's phase, rolled ONCE off FacilityModel.mix and baked. nothing here ticks
  seed:Int,
};
