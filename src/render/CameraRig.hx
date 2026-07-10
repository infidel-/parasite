package render;

import three.Three;
import render.ActorAnim;
import game.Game;
import Const;
import _UIState;

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
  var sideAngle = 0.0;                                     // current walkway-side camera angle
  var sideAngleTarget = 0.0;                               // desired walkway-side camera angle
  var zt:{ from:Float, to:Float, dur:Float, p:Float, gated:Bool } = null; // active fixed-duration zoom tween (intro/outro); dur in BASE_MS multiples; gated holds while a UI window is up
  var ztDone:Void->Void = null;                           // fires once when the active tween completes
  var lastState:_PlayerState;                              // prev-frame player state (auto pull-out)
  var recoil = new Vector3();                              // transient player-shot camera kick, decays to 0
  var lampCorners:Map<Int,Int> = null;                    // grid vertex -> lamp dir; follow target bends past a post too

  public function new(game:Game, camera:PerspectiveCamera)
    {
      this.game = game;
      this.camera = camera;
    }

// receive the lamp-corner map (built once per scene) so the follow target bends past posts
  public function setLampCorners(corners:Map<Int,Int>):Void
    {
      lampCorners = corners;
    }

// snap the camera to the player on (re)build so the first frame is framed correctly
  public function reset():Void
    {
      camSlide = null;
      zt = null;
      ztDone = null;
      sideAngle = 0.0;
      sideAngleTarget = 0.0;
      lastState = game.player.state;
      zoom = zoomTarget = targetFor(lastState);
      update(0, true);
      camera.position.copy(pWorld).add(offset);
    }

// enter effect: snap to the closest zoom then tween back out to the resting target
  public function startIntro():Void
    {
      zoom = 0;
      applyOffset();
      camera.position.copy(pWorld).add(offset);
      zoomTweenTo(zoomTarget, RenderConfig.CAMERA.introMult, true); // gated: hold under the opening message window
    }

// start a fixed-duration zoom tween (dur in BASE_MS multiples, scaled by ANIM_SPEED); onDone
// fires once it completes. gated holds the tween while a UI window is up (enter intro under
// the opening message). used for the enter zoom-out and the leave zoom-in outro
  public function zoomTweenTo(to:Float, mult:Float, gated = false, ?onDone:Void->Void):Void
    {
      zt = { from: zoom, to: to, dur: mult, p: 0.0, gated: gated };
      ztDone = onDone;
    }

// leave outro: advance ONLY the zoom (tween) and reframe the camera from the last follow
// target. reads no game state — the game area is already torn down by the time this runs
  public function driftZoom(dtMs:Float):Void
    {
      tickZoom(dtMs);
      applyOffset();
      camera.position.copy(pWorld).add(offset);
      lookAt.copy(pWorld);
      lookAt.y += 1.5;
      camera.lookAt(lookAt);
    }

// advance the zoom one frame: a fixed-duration tween if active (intro/outro), else the
// exponential ease toward zoomTarget. the tween's completion callback fires here
  function tickZoom(dtMs:Float):Void
    {
      if (zt != null)
        {
          // hold a gated tween (enter intro) at its start until the UI is idle, so it doesn't
          // count down under the opening message window / any other modal
          if (zt.gated &&
              game.ui.state != UISTATE_DEFAULT)
            return;
          zt.p += dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
          var t = zt.p / zt.dur;
          if (t > 1)
            t = 1;
          zoom = zt.from + (zt.to - zt.from) * (1 - Math.pow(1 - t, 3)); // ease-out cubic: decelerates into the end
          zoomTarget = zt.to;
          if (t >= 1)
            {
              var cb = ztDone;
              zt = null;
              ztDone = null;
              if (cb != null)
                cb();
            }
        }
      else
        {
          var k = 1 - Math.pow(1 - RenderConfig.CAMERA.zoomLerp, dtMs / (1000 / 30));
          zoom += (zoomTarget - zoom) * k;
        }
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

// punch the camera back along a shot direction (world dx,dz), plus a slight upward jolt;
// player's own shots only. decays back to zero in update()
  public function kick(dx:Float, dz:Float):Void
    {
      var len = Math.sqrt(dx * dx + dz * dz);
      if (len < 0.001)
        { dx = 0; dz = -1; len = 1; }
      var a = RenderConfig.SHOT.recoilAmp;
      recoil.set(dx / len * a, a * 0.4, dz / len * a);
    }

// advance the follow target + zoom one frame; drive the camera only when followCamera
// (free-cam owns it otherwise, but pWorld still tracks the player so the ring follows)
  public function update(dtMs:Float, followCamera:Bool):Void
    {
      // follow target: ease toward the player's grid cell, bending past building corners the
      // same way the player billboard does so the camera never cuts diagonally through a wall
      var step = dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
      var bend = (camSlide != null ?
        ActorAnim.cornerBend(game.area, camSlide.col, camSlide.row, game.playerArea.x, game.playerArea.y, lampCorners) : null);
      camSlide = ActorAnim.slideTo(camSlide, game.playerArea.x, game.playerArea.y, step,
        bend != null ? bend.col : -1,
        bend != null ? bend.row : -1);
      pWorld.set(camSlide.x, 0, camSlide.z);
      sideAngleTarget = targetSideAngle();
      updateSideAngle(dtMs);
      // state drives the auto zoom target: close as a parasite, pulled out as a host
      var st = game.player.state;
      if (st != lastState)
        {
          zoomTarget = targetFor(st);
          lastState = st;
        }
      // ease the zoom (fixed-duration intro/outro tween, else exponential toward zoomTarget)
      tickZoom(dtMs);
      applyOffset();
      if (!followCamera) return;
      desired.copy(pWorld).add(offset);
      camera.position.lerp(desired, RenderConfig.CAMERA.follow);
      // player-shot recoil: a transient offset added post-follow, easing back to zero
      if (recoil.x != 0 ||
          recoil.y != 0 ||
          recoil.z != 0)
        {
          camera.position.add(recoil);
          var keep = Math.exp(-dtMs / RenderConfig.SHOT.recoilMs);
          recoil.set(recoil.x * keep, recoil.y * keep, recoil.z * keep);
          if (Math.abs(recoil.x) + Math.abs(recoil.y) + Math.abs(recoil.z) < 0.001)
            recoil.set(0, 0, 0);
        }
      lookAt.copy(pWorld);
      lookAt.y += 1.5;
      camera.lookAt(lookAt);
    }

// offset = lerp(near, far, zoom); lower zoom => lower y/z => more parallel to the ground
  function applyOffset():Void
    {
      var n = RenderConfig.CAMERA.near, f = RenderConfig.CAMERA.far;
      var ox = n.x + (f.x - n.x) * zoom;
      var oy = n.y + (f.y - n.y) * zoom;
      var oz = n.z + (f.z - n.z) * zoom;
      var c = Math.cos(sideAngle);
      var s = Math.sin(sideAngle);
      offset.set(ox * c + oz * s, oy, -ox * s + oz * c);
    }

// ease the camera's side angle toward its current walkway-side target
  function updateSideAngle(dtMs:Float):Void
    {
      var step = dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
      var k = 1 - Math.pow(1 - RenderConfig.CAMERA.sideTurnLerp, step);
      sideAngle += (sideAngleTarget - sideAngle) * k;
      if (Math.abs(sideAngleTarget - sideAngle) < 0.001)
        sideAngle = sideAngleTarget;
    }

// choose a small orbit that exposes a building directly beside the walkway
  function targetSideAngle():Float
    {
      var col = game.playerArea.x;
      var row = game.playerArea.y;
      var tile = game.area.getCellType(col, row);
      if (tile != Const.TILE_WALKWAY)
        return 0.0;
      var left = game.area.getCellType(col - 1, row);
      var right = game.area.getCellType(col + 1, row);
      var sideLeft = left == Const.TILE_BUILDING || left == Const.TILE_ALLEY;
      var sideRight = right == Const.TILE_BUILDING || right == Const.TILE_ALLEY;
      if (sideLeft == sideRight)
        return 0.0;
      // positive Y rotation moves the camera toward +X; stand outside the left wall, and vice versa
      return sideLeft ? RenderConfig.CAMERA.sideAngle : -RenderConfig.CAMERA.sideAngle;
    }

// auto zoom target on entering a state (host pulls out, parasite/attached stay close)
  inline function targetFor(st:_PlayerState):Float
    return st == _PlayerState.PLR_STATE_HOST ? RenderConfig.CAMERA.hostZoom : RenderConfig.CAMERA.parasiteZoom;

// wheel zoom-out ceiling per state (host reaches the absolute max, parasite/attached don't)
  inline function maxFor(st:_PlayerState):Float
    return st == _PlayerState.PLR_STATE_HOST ? 1.0 : RenderConfig.CAMERA.parasiteZoom;
}
