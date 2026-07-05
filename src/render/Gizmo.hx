package render;

import three.Three;
import js.Browser;

// world-orientation gizmo: XYZ axes + canvas-sprite labels rendered into a fixed
// bottom-left corner viewport, in its own scene + ortho cam so bloom/world
// geometry/perspective don't touch it. Drawn only while street-debug mode is on.
class Gizmo {
  static var gizScene:Scene;
  static var gizCam:OrthographicCamera;
  static var fwd = new Vector3();
  static var origin = new Vector3();

// lazily build the axes scene + labels on first draw
  static function ensure():Void {
    if (gizScene != null) return;
    gizScene = new Scene(); // no background: transparent overlay over the scene corner
    gizScene.add(new AxesHelper(1));
    label('X', '#ff5555', 1.3, 0, 0);
    label('Y', '#55ff55', 0, 1.3, 0);
    label('Z', '#6688ff', 0, 0, 1.3);
    gizCam = new OrthographicCamera(-1.4, 1.4, 1.4, -1.4, 0.1, 10);
  }

// canvas-sprite axis label at the given gizmo-space position
  static function label(txt:String, color:String, x:Float, y:Float, z:Float):Void {
    var cv:Dynamic = Browser.document.createElement('canvas');
    cv.width = 64;
    cv.height = 64;
    var ctx:Dynamic = cv.getContext('2d');
    ctx.fillStyle = color;
    ctx.font = 'bold 52px sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(txt, 32, 36);
    var sp = new Sprite(new SpriteMaterial({ map: new CanvasTexture(cv), transparent: true, depthTest: false }));
    sp.position.set(x, y, z);
    sp.scale.set(0.5, 0.5, 0.5);
    gizScene.add(sp);
  }

// render the gizmo into a scissored 110×110 corner viewport, oriented like the main camera
  public static function draw(renderer:WebGLRenderer, camera:PerspectiveCamera):Void {
    ensure();
    var size = 110;
    // place the ortho cam 3 units behind the origin along the main view dir, look back
    // at the axes → gizmo shows world XYZ as the main camera currently sees them
    fwd.set(0, 0, -1).applyQuaternion(camera.quaternion);
    gizCam.position.set(0, 0, 0).addScaledVector(fwd, -3);
    gizCam.lookAt(origin);
    renderer.autoClear = false;
    renderer.clearDepth();
    renderer.setViewport(12, 12, size, size);
    renderer.setScissor(12, 12, size, size);
    renderer.setScissorTest(true);
    renderer.render(gizScene, gizCam);
    renderer.setScissorTest(false);
    renderer.setViewport(0, 0, Browser.window.innerWidth, Browser.window.innerHeight);
    renderer.autoClear = true;
  }
}
