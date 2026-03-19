package lighting;

// one dynamic-shadow emitter candidate prepared for debug output
typedef _DynamicShadowDebugEmitterInfo = {
  var emitter: _LayoutShadowEmitter;
  var distSq: Float;
  var isInRange: Bool;
  var hasLOS: Bool;
  var isInsideCaster: Bool;
  var isUsed: Bool;
}
