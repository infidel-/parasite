// generator - area room info
typedef _Room = {
  var id: Int;
  var x1: Int;
  var y1: Int;
  var x2: Int; // last empty space
  var y2: Int;
  var w: Int;
  var h: Int;
  @:optional var role: String;
  @:optional var templateID: String;
  @:optional var tags: Array<String>;
}
