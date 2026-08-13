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
  // shaft tint. omitted = LAMP_CONE.color, the street amber every city cone uses. the tunnels pass
  // their own so a manhole shaft cannot be mistaken for the bracketed fixtures on the walls
  ?color:Int,
  // per-instance flicker phase, same length as bulbs. omitted or empty = a STEADY set, built once
  // and never touched; a non-empty one marks the batch LightCone.pulse repacks each frame
  ?phases:Array<Float>,
};
