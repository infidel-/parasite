package render;

import three.Three;
import render.ActorAnim;
import game.Game;

// the street view's follow camera: eases a target toward the player's cell, holds a
// state-driven zoom (parasite close, host pulled out) and derives the camera offset +
// angle from it (closer = more parallel to the ground). wheel zooms in/out; free-cam
// (debug) bypasses this and owns the camera itself. StreetView drives it each frame.
class CameraRig {
  var game:Game;
  var camera:PerspectiveCamera;

  var camSlide:PosSlide;                                   // follow target (player cell) slide
  var pWorld = new Vector3();                              // current follow-target world pos
  var offset = new Vector3();                              // camera offset from pWorld (zoom-derived)
  var desired = new Vector3();                             // camera goal = pWorld + offset
  var lookAt = new Vector3();                              // aim point (pWorld, raised a touch)

  var zoom = 1.0;                                          // current normalized zoom 0..1
  var zoomTarget = 1.0;                                    // eased-toward zoom
  var lastState:_PlayerState;                              // prev-frame player state (auto pull-out)

  public function new(game:Game, camera:PerspectiveCamera)
    {
      this.game = game;
      this.camera = camera;
    }

// snap the camera to the player on (re)build so the first frame is framed correctly
  public function reset():Void
    {
      camSlide = null;
      lastState = game.player.state;
      zoom = zoomTarget = targetFor(lastState);
      update(0, true);
      camera.position.copy(pWorld).add(offset);
    }

// the current follow-target world pos (the ring tracks this)
  public inline function playerWorld():Vector3
    return pWorld;

// nudge the zoom target one wheel notch (dir: +1 = out, -1 = in), clamped to the state cap
  public function zoomBy(dir:Int):Void
    {
      zoomTarget = Math.max(0, Math.min(maxFor(game.player.state),
        zoomTarget + dir * RenderConfig.CAMERA.zoomStep));
    }

// advance the follow target + zoom one frame; drive the camera only when followCamera
// (free-cam owns it otherwise, but pWorld still tracks the player so the ring follows)
  public function update(dtMs:Float, followCamera:Bool):Void
    {
      // follow target: ease toward the player's grid cell
      var step = dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
      camSlide = ActorAnim.slideTo(camSlide, game.playerArea.x, game.playerArea.y, step);
      pWorld.set(camSlide.x, 0, camSlide.z);
      // state drives the auto zoom target: close as a parasite, pulled out as a host
      var st = game.player.state;
      if (st != lastState)
        {
          zoomTarget = targetFor(st);
          lastState = st;
        }
      // frame-rate-independent smoothing: zoomLerp is tuned per 30fps frame, dt-compensated
      // so the ease feels identical at any render rate (exact exponential decay)
      var k = 1 - Math.pow(1 - RenderConfig.CAMERA.zoomLerp, dtMs / (1000 / 30));
      zoom += (zoomTarget - zoom) * k;
      applyOffset();
      if (!followCamera) return;
      desired.copy(pWorld).add(offset);
      camera.position.lerp(desired, RenderConfig.CAMERA.follow);
      lookAt.copy(pWorld);
      lookAt.y += 1.5;
      camera.lookAt(lookAt);
    }

// offset = lerp(near, far, zoom); lower zoom => lower y/z => more parallel to the ground
  function applyOffset():Void
    {
      var n = RenderConfig.CAMERA.near, f = RenderConfig.CAMERA.far;
      offset.set(n.x + (f.x - n.x) * zoom, n.y + (f.y - n.y) * zoom, n.z + (f.z - n.z) * zoom);
    }

// auto zoom target on entering a state (host pulls out, parasite/attached stay close)
  inline function targetFor(st:_PlayerState):Float
    return st == _PlayerState.PLR_STATE_HOST ? RenderConfig.CAMERA.hostZoom : RenderConfig.CAMERA.parasiteZoom;

// wheel zoom-out ceiling per state (host reaches the absolute max, parasite/attached don't)
  inline function maxFor(st:_PlayerState):Float
    return st == _PlayerState.PLR_STATE_HOST ? 1.0 : RenderConfig.CAMERA.parasiteZoom;
}
