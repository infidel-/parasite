package lighting;

// static atmospheric light stamp metadata in tile-space coordinates
typedef _AreaLightStamp = {
  var x: Float;
  var y: Float;
  var radiusTiles: Float;
  var intensity: Float;
  var tintR: Int;
  var tintG: Int;
  var tintB: Int;
  @:optional var kind: String;
  @:optional var falloffProfile: String;
  @:optional var saturationBoost: Float;
  @:optional var sourceGroupID: String;
}
