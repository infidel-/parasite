package render;

import three.Three;
import render.particles.LampLights;

// one 3D-renderable AREA KIND. render.View owns everything generic — renderer, composer, camera
// rig, actor layer, input, fades, perf — and an Area3D owns what actually differs between kinds:
// the scene's fog + light rig, the static geometry, and the per-frame world tick (occlusion fades,
// window switches, live lamp pooling). render.CityArea is the streets, render.SewerArea the tunnels
interface Area3D
{
  // build the scene and its light rig (background, fog, fill lights, live lamp pool)
  function scene(renderer:WebGLRenderer, lampPool:Int):SceneSetup.SceneBundle;
  // emit all static geometry into that scene (and bucket it into spatial chunks)
  function build(scene:Scene):Void;
  // per-frame world tick — see render.Area3DTickOpts
  function tick(opts:Area3DTickOpts):Void;
  // tactical (zoomed-out) view toggle
  function setTactical(v:Bool):Void;
  // per-area bloom threshold: WHEN the glow starts
  function bloomThreshold():Float;
  // camera distance preset for this kind (streets are shallow, tunnels look near straight down)
  function cameraOffsets():RenderConfig.CameraOffsets;
  // render-only ground debris handed to the actor layer (deterministic, never persisted)
  function debris():Array<render.world.Debris.DebrisSpot>;
  // the citygen City behind this area, or null where there is none (the tunnels). only the debug
  // tools read it — asking the built area beats View keeping a second field in sync by hand
  function city():citygen.CityModel.City;
  // the live lamp pool was rebuilt by a settings change (View.setLampLights) — re-bind to it
  function setLampLights(l:LampLights):Void;
}
