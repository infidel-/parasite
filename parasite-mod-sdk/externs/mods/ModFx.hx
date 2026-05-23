// per-mod fx facade — named fx registry + RAF/canvas/overlay primitives.
// engine owns dispatch + scheduling + overlay div lifecycle; mods own the
// visual impl. mirrors engine src/mods/ModFx.hx
package mods;

import js.html.Element;

// fx implementation contract — registered via parasite.fx.register(id, impl)
typedef FxImpl =
{
  // called by parasite.fx.play(id, params); receives the dynamic params blob
  // the caller passed (schema is whatever the impl documents)
  play: Dynamic -> Void,
  // optional early-stop hook; called by parasite.fx.stop(id). use to cancel
  // in-flight tick channels, reset DOM state, etc.
  ?stop: Void -> Void,
};

@:native('window.parasiteHx["mods.ModFx"]')
extern class ModFx
{
  // register an fx implementation under id. id MUST start with mod-<modID>-
  // (rejected + console.error otherwise). duplicate id last-wins + warns.
  // impl must have a play function (rejected + console.error otherwise)
  public function register(id: String, impl: FxImpl): Void;

  // fire a registered fx by id. params is forwarded as-is to impl.play.
  // missing id warns once per id, no throw. impl exceptions caught + logged
  public function play(id: String, ?params: Dynamic): Void;

  // call registered fx's optional stop() to interrupt early. no-op if the
  // fx has no stop hook or is not registered
  public function stop(id: String): Void;

  // RAF-based per-frame scheduler. frameFn receives t in [0..1] each frame.
  // onDone fires once after frameFn(1.0). pass channelID = your fx id to
  // make re-plays interrupt the prior tick on that channel; without it,
  // parallel ticks coexist. RAF pauses on tab blur and resumes on return
  public function tick(durationMS: Int, frameFn: Float -> Void,
    ?onDone: Void -> Void, ?channelID: String): Void;

  // lazy-create and return the engine-owned fullscreen overlay div. mods set
  // their own styles per play(); engine owns el lifecycle (one per session,
  // reused across mods + ids). div is fixed-position, pointer-events: none,
  // z-index 9999, initial opacity 0. concurrent flashes from different mods
  // will stomp each other — last write wins
  public function overlay(): Element;

  // get the game's #canvas element (may be null pre-scene). useful for fx
  // that anchor on the rendered viewport (e.g. camera shake via CSS transform)
  public function canvas(): Element;
}
