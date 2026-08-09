package render;

import three.Three;
import render.ActorAnim;
import game.Game;
import Const;
import _UIState;

typedef TacticalCameraState = {
  var zoomTarget:Float;
  var sideAngleTarget:Float;
}

// the 3D view's follow camera: eases a target toward the player's cell, holds a
// state-driven zoom (parasite close, host pulled out) and derives the camera offset +
// angle from it (closer = more parallel to the ground). wheel zooms in/out; free-cam
// (debug) bypasses this and owns the camera itself. render.View drives it each frame.
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
  var orbitYaw = 0.0;                                      // hold-RMB drag: horizontal orbit, added to sideAngle
  var orbitPitch = 0.0;                                    // hold-RMB drag: vertical orbit (tilt), clamped
  var orbiting = false;                                    // RMB held: hold the orbit; released: ease back to 0
  var zt:{ from:Float, to:Float, dur:Float, p:Float, gated:Bool } = null; // active fixed-duration zoom tween (intro/outro); dur in BASE_MS multiples; gated holds while a UI window is up
  var ztDone:Void->Void = null;                           // fires once when the active tween completes
  var lastState:_PlayerState;                              // prev-frame player state (auto pull-out)
  var recoil = new Vector3();                              // transient player-shot camera kick, decays to 0
  var lampCorners:Map<Int,Int> = null;                    // grid vertex -> lamp dir; follow target bends past a post too
  var tactical = false;
  var tacticalCamera:TacticalCameraState = null;

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

// begin a hold-RMB orbit: subsequent orbitDrag calls accumulate; released via orbitEnd
  public function orbitStart():Void
    {
      orbiting = true;
    }

// end the hold-RMB orbit: update() eases the accumulated orbit back to the resting view
  public function orbitEnd():Void
    {
      orbiting = false;
    }

// accumulate a mouse-drag delta into the orbit while RMB is held (dx = yaw, dy = pitch);
// pitch clamped so the camera never tilts below level or swings past straight overhead
  public function orbitDrag(dx:Float, dy:Float):Void
    {
      if (!orbiting)
        return;
      // inverted drag: dragging right/down swings the camera the opposite way (grab-the-world feel)
      orbitYaw -= dx * RenderConfig.CAMERA.orbitSens;
      orbitPitch -= dy * RenderConfig.CAMERA.orbitSens;
      var ym = RenderConfig.CAMERA.orbitYawMax;
      if (orbitYaw < -ym)
        orbitYaw = -ym;
      else if (orbitYaw > ym)
        orbitYaw = ym;
      if (orbitPitch < RenderConfig.CAMERA.orbitPitchMin)
        orbitPitch = RenderConfig.CAMERA.orbitPitchMin;
      else if (orbitPitch > RenderConfig.CAMERA.orbitPitchMax)
        orbitPitch = RenderConfig.CAMERA.orbitPitchMax;
    }

// snap the camera to the player on (re)build so the first frame is framed correctly
  public function reset():Void
    {
      camSlide = null;
      zt = null;
      ztDone = null;
      sideAngle = 0.0;
      sideAngleTarget = 0.0;
      orbitYaw = 0.0;
      orbitPitch = 0.0;
      orbiting = false;
      tactical = false;
      tacticalCamera = null;
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
      easeOrbitBack(dtMs); // drain any residual RMB orbit so the outro frames the player
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
      if (tactical)
        return;
      zoomTarget = Math.max(0, Math.min(maxFor(game.player.state),
        zoomTarget + dir * RenderConfig.CAMERA.zoomStep));
    }

// switch between the player's saved follow zoom and the tactical overhead zoom; both ways
// retarget and let update()'s exponential eases animate the transition (no snap)
  public function setTactical(v:Bool):Void
    {
      if (tactical == v)
        return;
      tactical = v;
      if (tactical)
        {
          tacticalCamera = {
            zoomTarget: zoomTarget,
            sideAngleTarget: sideAngleTarget,
          };
          zt = null;
          ztDone = null;
          zoomTarget = 1.0;
          sideAngleTarget = 0.0;
          return;
        }
      zoomTarget = tacticalCamera.zoomTarget;
      sideAngleTarget = tacticalCamera.sideAngleTarget;
      tacticalCamera = null;
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
      // tactical pins the side-angle target at 0: no walkway-side orbit (it would swing the
      // camera and flip the occlusion block selection); the ease still runs both ways
      if (!tactical)
        sideAngleTarget = targetSideAngle();
      updateSideAngle(dtMs);
      easeOrbitBack(dtMs);
      // state drives the auto zoom target: close as a parasite, pulled out as a host
      var st = game.player.state;
      if (st != lastState)
        {
          // during tactical the live zoom is pinned; retarget the saved state instead so the
          // exit restore lands on the new state's zoom, not the one saved at entry
          if (tactical)
            tacticalCamera.zoomTarget = targetFor(st);
          else zoomTarget = targetFor(st);
          lastState = st;
        }
      // ease the zoom (fixed-duration intro/outro tween, else exponential toward zoomTarget;
      // tactical rides the same ease with its target pinned at 1.0 by setTactical)
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
      // hold-RMB pitch: tilt the (behind, up) = (oz, oy) pair in its vertical plane (distance kept).
      // effective elevation = base atan2(oy,oz) - pitch; cap it below vertical so a raise at high
      // zoom-out can't carry the camera past the top and flip it around to the front
      var pit = orbitPitch;
      var minPit = Math.atan2(oy, oz) - RenderConfig.CAMERA.orbitElevMax;
      if (pit < minPit)
        pit = minPit;
      var cp = Math.cos(pit);
      var sp = Math.sin(pit);
      var ry = oy * cp - oz * sp;
      var rz = oy * sp + oz * cp;
      // yaw = walkway side-angle + hold-RMB drag yaw, rotated about Y
      var a = sideAngle + orbitYaw;
      var c = Math.cos(a);
      var s = Math.sin(a);
      offset.set(ox * c + rz * s, ry, -ox * s + rz * c);
    }

// while RMB is released, ease the hold-RMB orbit (yaw + pitch) back toward the resting view
  function easeOrbitBack(dtMs:Float):Void
    {
      if (orbiting)
        return;
      // 2x return speed: the snap back to the resting view is twice as fast as the hold-drag ease
      var step = 2 * dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
      var k = 1 - Math.pow(1 - RenderConfig.CAMERA.orbitReturnLerp, step);
      orbitYaw += (0 - orbitYaw) * k;
      orbitPitch += (0 - orbitPitch) * k;
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

// how many city cells of ground the follow camera can cover, at its widest (zoom 1.0, the host
// wheel-out ceiling from maxFor). PURE: derived from RenderConfig.CAMERA alone, so the game logic
// can call it with no live camera and no scene — it sizes the AI spawn budget/region, which must
// track what the player can actually SEE rather than the 2D canvas (the 2D rect scales with pixel
// count, this does not: fov is fixed and only aspect moves).
// deliberately always zoom 1.0, never the live/state zoom: a parasite's ceiling is 0.3, so keying
// off the player state would swing the budget on every attach/detach and churn spawns.
// the ground patch is a trapezoid (perspective), narrow at the near edge and wide at the far one
  public static function maxFootprintCells(aspect:Float):Float
    {
      var c = RenderConfig.CAMERA;
      // camera offset at full zoom-out; the rig aims at pWorld.y + 1.5, so pitch is measured to that
      var camY = c.near.y + (c.far.y - c.near.y) * 1.0;
      var camZ = c.near.z + (c.far.z - c.near.z) * 1.0;
      var pitch = Math.atan2(camY - 1.5, camZ);
      var half = c.fov / 2 * Math.PI / 180;
      // where the top/bottom frustum planes meet the ground. the near edge can land BEHIND the
      // camera (pitch + half > 90 degrees at this steep angle) — that is correct, not a bug
      var zFar = camZ - camY / Math.tan(pitch - half);
      var zNear = camZ - camY / Math.tan(pitch + half);
      var tanH = Math.tan(half) * aspect;
      var wFar = 2 * Math.sqrt((camZ - zFar) * (camZ - zFar) + camY * camY) * tanH;
      var wNear = 2 * Math.sqrt((camZ - zNear) * (camZ - zNear) + camY * camY) * tanH;
      var area = Math.abs(zNear - zFar) * (wNear + wFar) / 2;
      return area / (citygen.CityConfig.CELL * citygen.CityConfig.CELL);
    }
}
