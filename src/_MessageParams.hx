// ui message parameters typedef
typedef _MessageParams = {
  // message text
  var text: String;
  // optional title
  @:optional var title: String;
  // optional title color
  @:optional var titleCol: String;
  // optional message color
  @:optional var col: String;
  // optional image name (without extension)
  @:optional var img: String;
}
