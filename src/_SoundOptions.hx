typedef _SoundOptions = {
// always play?
  @:optional var always: Bool;
// can be delayed? (small random delay to avoid same sounds playing together)
  @:optional var canDelay: Bool;
  // delay in ms (always)
  @:optional var delay: Int;
// x,y for in-world sounds
  @:optional var x: Int;
  @:optional var y: Int;
// the volume to play at, 0-100, instead of the effects slider and any x,y falloff: a caller that
// worked its level out itself (render.AreaSounds' intermittent ambience)
  @:optional var volume: Float;
}
