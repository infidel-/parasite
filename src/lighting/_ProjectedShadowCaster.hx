package lighting;

import js.html.Image;

// source sprite footprint that can cast one projected shadow
typedef _ProjectedShadowCaster = {
  var layerID: Int;
  var image: Image;
  var maskKey: String;
  var srcRow: Int;
  var srcCol: Int;
  var blockW: Int;
  var blockH: Int;
  var centerX: Float;
  var centerY: Float;
  var skipSelfShadow: Bool;
}
