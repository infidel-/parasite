package lighting;

// short-lived dynamic particle light pulse metadata
typedef _TransientAtmosphereLight = {
  var x: Float;
  var y: Float;
  var radiusTiles: Float;
  var intensity: Float;
  var tintR: Int;
  var tintG: Int;
  var tintB: Int;
  var startTS: Float;
  var endTS: Float;
}
