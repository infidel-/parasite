package render;

import three.Three;

// options for render.LightCone.instanced. replaced the positional signature
// `instanced(group, bulbs, bulbY, radius, ?phases)` when the sewer needed a per-area top radius:
// a street lamp's shaft is a cone tapering to a point at the bulb, while a tunnel's is daylight
// down a MANHOLE, i.e. a column that is already wide where it starts
typedef LightConeOpts = {
  // parent for the batch — the scene's coneGroup, so the debug 5/0 keys hide it with the lamps
  group:Object3D,
  // each shaft's ground x/z (already pushed out over the road edge in a city)
  bulbs:Array<{ x:Float, z:Float }>,
  // bulb height: where the shaft starts
  bulbY:Float,
  // ground radius of the shaft, matched to the lit circle the SpotLight throws
  radius:Float,
  // minimum TOP radius. small (LAMP_CONE.topR) reads as a lamp cone; wide reads as a shaft down a hole
  topR:Float,
  // where the shaft starts along the bulb->ground axis, overriding LAMP_CONE.startFrac. the street's
  // is NEGATIVE (-0.1), which lifts the top a tenth of the bulb height ABOVE the bulb so it reaches
  // up into a lamp whose glowing part sits over the light position. a fixture whose bulbY already IS
  // its lens plane wants 0 instead, or the shaft starts in mid-air over the whole post
  ?startFrac:Float,
  // shaft tint. omitted = LAMP_CONE.color, the street amber every city cone uses. the tunnels pass
  // their own so a manhole shaft cannot be mistaken for the bracketed fixtures on the walls
  ?color:Int,
  // per-instance flicker phase, same length as bulbs. omitted or empty = a STEADY set, built once
  // and never touched; a non-empty one marks the batch LightCone.pulse repacks each frame
  ?phases:Array<Float>,
  // how much of the shaft's circle to build, radians. omitted = the whole 2*PI, which is right for
  // anything standing in the open — a mast, a manhole. A WALL-MOUNTED fitting is the case it exists
  // for: its light is cut off flat by the masonry it is bolted to, so a full shell puts half a cone
  // of lit air inside the building. PI is that half, and `yaws` is what aims it
  ?arc:Float,
  // per-instance heading, same length as bulbs, and only meaningful with `arc`: the kept wedge is
  // centred on the geometry's +z and this turns it to face outward. a full-circle batch does not
  // need one and does not pay for one — the whole set then shares an identity rotation
  ?yaws:Array<Float>,
};
