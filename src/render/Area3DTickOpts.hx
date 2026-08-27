package render;

import three.Three;

// per-frame arguments for render.Area3D.tick — replaces what would otherwise be a
// tick(camPos, player, target, aiming, playerCol, playerRow, dtMs, outro, camera) call,
// well past the point a positional list stops being readable at the call site
typedef Area3DTickOpts = {
  // camera world position (occlusion traces camera -> player through it)
  camPos:Vector3,
  // smoothed player world position
  player:Vector3,
  // aim / confirmed target world position; null when nothing is targeted
  target:Vector3,
  // targeting mode: widen the occlusion corridor so flanking buildings fade too
  aiming:Bool,
  // player grid column (the live light pool picks the lamps nearest it)
  playerCol:Int,
  // player grid row
  playerRow:Int,
  // frame delta in ms, already hitch-clamped by the view loop
  dtMs:Float,
  // leave-outro frame: the area is despawned, so only camera-driven fades may run
  outro:Bool,
  // street-debug fly cam owns the camera: skip the occlusion pass (it traces to the player)
  freeCam:Bool,
  // the live camera, for per-frame instanced-prop frustum culling
  camera:PerspectiveCamera,
  // HUD up (Shift+Space hides it): the props' tactical outline shells are UI and go with it
  ui:Bool,
};
