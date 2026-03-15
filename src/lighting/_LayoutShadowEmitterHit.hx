package lighting;

// one nearby emitter with cached distance to a caster
typedef _LayoutShadowEmitterHit = {
  var emitter: _LayoutShadowEmitter;
  var distSq: Float;
}
