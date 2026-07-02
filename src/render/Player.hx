package render;

import three.Three;
import citygen.CityConfig;
import citygen.CityConfig.cellToWorld;
import citygen.CityModel.City;

// the controlled human: a billboard sprite + a flat purple marker ring, sliding
// one cell per turn with a smoothstep tween
class Player {
  public var group:Group;
  public var avatar:Mesh; // upright billboard plane (yaws to camera, never tips flat)
  public var col:Int;
  public var row:Int;
  public var isMoving(get, never):Bool;
  public var position(get, never):Vector3;

  var moving = false;
  var t = 0.0;
  var from = new Vector3();
  var to = new Vector3();

  function get_isMoving():Bool return moving;
  function get_position():Vector3 return group.position;

  public function new(scene:Scene, city:City) {
    group = new Group();
    scene.add(group);

    var ring = new Mesh(
      new RingGeometry(CityConfig.CELL * 0.42, CityConfig.CELL * 0.52, 40),
      new MeshBasicMaterial({ color: 0xb46bff, transparent: true, opacity: 0.9, side: THREE.DoubleSide, depthWrite: false }));
    ring.rotation.x = -Math.PI / 2;
    ring.position.y = 0.06;
    group.add(ring);

    var tex = new TextureLoader().load(RenderConfig.TEXTURES.player);
    tex.colorSpace = THREE.SRGBColorSpace;
    var s = CityConfig.CELL * 0.81;
    // upright plane (not a Sprite): stands vertically in the world; faceCamera() yaws it
    // around Y only to face the camera, so it never tips flat under an overhead camera
    avatar = new Mesh(new PlaneGeometry(s, s),
      new MeshBasicMaterial({ map: tex, transparent: true, depthWrite: false, side: THREE.DoubleSide }));
    avatar.position.y = s * 0.5;
    group.add(avatar);

    col = city.start.col;
    row = city.start.row;
    var start = cellToWorld(col, row);
    group.position.set(start.x, 0, start.z);
  }

  // instant teleport (no tween) — used by the debug cycler to stand the player in
  // front of the inspected building
  public function placeAt(col:Int, row:Int):Void {
    this.col = col;
    this.row = row;
    var w = cellToWorld(col, row);
    group.position.set(w.x, 0, w.z);
    moving = false;
  }

  // yaw the upright avatar around the vertical axis to face the camera (Y-billboard):
  // it stays standing vertically and only turns horizontally toward the viewer
  public function faceCamera(cam:Vector3):Void {
    avatar.rotation.y = Math.atan2(cam.x - group.position.x, cam.z - group.position.z);
  }

  public function moveTo(col:Int, row:Int):Bool {
    if (moving) return false;
    this.col = col;
    this.row = row;
    var w = cellToWorld(col, row);
    from.copy(group.position);
    to.set(w.x, 0, w.z);
    t = 0;
    moving = true;
    return true;
  }

  public function update(dtMs:Float):Void {
    if (!moving) return;
    t = Math.min(1, t + dtMs / RenderConfig.MOVE_MS);
    var e = t * t * (3 - 2 * t); // smoothstep
    group.position.lerpVectors(from, to, e);
    if (t >= 1) moving = false;
  }
}
