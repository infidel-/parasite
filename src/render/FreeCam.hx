package render;

import three.Three;
import js.Browser;

// toggle with F. While active: hold LMB + drag to look, WASD to fly, Space/Q
// up/down, numpad rotate, Shift slow. update() returns true while it owns the camera
class FreeCam {
  public var active(default, null):Bool = false;

  var camera:PerspectiveCamera;
  var keys = new Map<String, Bool>();
  var euler = new Euler(0, 0, 0, 'YXZ');
  var dragging = false;
  var yaw = 0.0;
  var pitch = 0.0;
  static inline var SPEED = 45.0;
  static inline var SENS = 0.0025;
  static inline var ROT = 1.6;

  var indicator:js.html.Element;
  var fwd = new Vector3();
  var right = new Vector3();

  public function new(camera:PerspectiveCamera, dom:Dynamic) {
    this.camera = camera;
    indicator = Browser.document.getElementById('mode');
    setIndicator();

    Browser.window.addEventListener('keydown', function(e:js.html.KeyboardEvent) {
      if (!Tools.enabled) return; // only in street-debug mode
      if (e.code == 'KeyF') { if (active) { active = false; setIndicator(); } else activate(); }
      if (active) keys.set(e.code, true);
    });
    Browser.window.addEventListener('keyup', function(e:js.html.KeyboardEvent) keys.remove(e.code));
    dom.addEventListener('mousedown', function(e:js.html.MouseEvent) { if (active && e.button == 0) dragging = true; });
    Browser.window.addEventListener('mouseup', function(_) dragging = false);
    Browser.window.addEventListener('mousemove', function(e:js.html.MouseEvent) {
      if (!active || !dragging) return;
      yaw -= e.movementX * SENS;
      pitch = Math.max(-1.5, Math.min(1.5, pitch - e.movementY * SENS));
    });
  }

  function setIndicator():Void {
    if (indicator == null) return;
    indicator.textContent = active ? 'FREE CAM' : 'FOLLOW';
    indicator.classList.toggle('free', active);
  }

// leave free-cam (called when street-debug mode turns off)
  public function deactivate():Void {
    active = false;
    keys = new Map();
    setIndicator();
  }

  public function activate():Void {
    active = true;
    euler.setFromQuaternion(camera.quaternion, 'YXZ');
    yaw = euler.y;
    pitch = euler.x;
    setIndicator();
  }

  // jump the free cam to look at a world point, framed from above-and-back by r
  public function focus(tx:Float, ty:Float, tz:Float, r:Float):Void {
    var dist = r * 2.2 + 16;
    lookFrom(tx, ty + dist * 0.9, tz + dist * 0.6, tx, ty, tz);
  }

  // place the cam at (p) and aim it at target (t); caller controls the framing.
  public function lookFrom(px:Float, py:Float, pz:Float, tx:Float, ty:Float, tz:Float):Void {
    camera.position.set(px, py, pz);
    var dx = tx - px, dy = ty - py, dz = tz - pz;
    var len = Math.sqrt(dx * dx + dy * dy + dz * dz);
    dx /= len; dy /= len; dz /= len;
    pitch = Math.asin(Math.max(-1, Math.min(1, dy)));
    yaw = Math.atan2(-dx, -dz);
    active = true;
    euler.set(pitch, yaw, 0, 'YXZ');
    camera.quaternion.setFromEuler(euler);
    setIndicator();
  }

  public function update(dtMs:Float):Bool {
    if (!active) return false;
    var dt = dtMs / 1000;
    if (keys.exists('Numpad8')) pitch -= ROT * dt;
    if (keys.exists('Numpad2')) pitch += ROT * dt;
    if (keys.exists('Numpad4')) yaw += ROT * dt;
    if (keys.exists('Numpad6')) yaw -= ROT * dt;
    pitch = Math.max(-1.5, Math.min(1.5, pitch));
    euler.set(pitch, yaw, 0, 'YXZ');
    camera.quaternion.setFromEuler(euler);
    var sp = SPEED * dt;
    if (keys.exists('ShiftLeft') || keys.exists('ShiftRight')) sp *= 0.12;
    fwd.set(0, 0, -1).applyQuaternion(camera.quaternion);
    right.set(1, 0, 0).applyQuaternion(camera.quaternion);
    if (keys.exists('KeyW')) camera.position.addScaledVector(fwd, sp);
    if (keys.exists('KeyS')) camera.position.addScaledVector(fwd, -sp);
    if (keys.exists('KeyA')) camera.position.addScaledVector(right, -sp);
    if (keys.exists('KeyD')) camera.position.addScaledVector(right, sp);
    if (keys.exists('Space')) camera.position.y += sp;
    if (keys.exists('KeyQ')) camera.position.y -= sp;
    return true;
  }
}
