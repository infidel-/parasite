typedef _SoundOptions = {
// always play?
  @:optional var always: Bool;
// can be delayed? (small delay to avoid same sounds playing together)
  @:optional var canDelay: Bool;
// x,y for in-world sounds
  @:optional var x: Int;
  @:optional var y: Int;
}
