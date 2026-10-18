package render.wild;

// one grass tuft for render.wild.WildGrass.tuft — the five output buffers it appends to, and where
// that tuft stands.
//
// it replaced
//   tuft(pos, nor, uv, wind, idx, x, z, yaw, w, h, hash)
// which was already at 11 positional args when the tuft emitter gained a second caller
// (render.facility.FacilityLawn) and with it a `y`: the old signature sampled its own ground height
// off render.wild.WildHeight, which is the wilderness's sine field and answers nonsense anywhere
// else. the caller passes the height now — WildGrass.block off the height field, FacilityLawn off a
// compound's flat lawn
typedef TuftOpts = {
  // vertex positions, xyz per vertex
  pos:Array<Float>,
  // vertex normals, xyz per vertex. every tuft writes (0,1,0) — see WildGrass.tuft's header on why
  // that lie is deliberate and what cancels three's flip of it
  nor:Array<Float>,
  // texture coordinates, uv per vertex; v runs 0 at the roots to 1 at the tip
  uv:Array<Float>,
  // the wind attribute, vec2 per vertex: the tuft's phase, and the height weight the offset scales by
  wind:Array<Float>,
  // triangle indices
  idx:Array<Int>,
  // world x of the tuft's centre
  x:Float,
  // world y its roots sit at — the ground under (x, z), sampled by the caller
  y:Float,
  // world z of the tuft's centre
  z:Float,
  // which way its two crossed quads face, radians
  yaw:Float,
  // width of one quad, world units
  w:Float,
  // height of the blades, world units
  h:Float,
  // the placement hash this tuft was rolled from; its low bits become the wind phase
  hash:Int,
};
