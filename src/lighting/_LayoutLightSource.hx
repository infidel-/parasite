package lighting;

// logical layout-light source before conversion into atmosphere stamps
typedef _LayoutLightSource = {
  var x: Float;
  var y: Float;
  var tintR: Int;
  var tintG: Int;
  var tintB: Int;
  var kind: String;
  var sourceGroupID: String;
}
