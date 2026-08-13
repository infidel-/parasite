package three;

// hand-written minimal three.js externs — only the API this renderer uses.
// bound to a single vendored global `THREE` (app/three.global.js, an iife bundle
// of three core + the postprocessing addons, re-exported onto one namespace).
// Params that three takes as option-objects are typed Dynamic (pass anonymous
// structs). No ES modules / genes: the game bundle is a classic script.

@:native("THREE") extern class THREE {
  static var SRGBColorSpace:Dynamic;
  static var NoColorSpace:Dynamic;
  static var RepeatWrapping:Dynamic;
  static var ClampToEdgeWrapping:Dynamic;
  static var DoubleSide:Dynamic;
  static var FrontSide:Dynamic;
  static var BackSide:Dynamic;
  static var ACESFilmicToneMapping:Dynamic;
  static var NoToneMapping:Dynamic;
  // depth-compare funcs (Material.depthFunc); GreaterDepth draws only where occluded (x-ray outline)
  static var LessEqualDepth:Dynamic;
  static var GreaterDepth:Dynamic;
  static var PCFShadowMap:Dynamic; // WebGLRenderer.shadowMap.type — PCF shadows (soft since r181; PCFSoftShadowMap deprecated)
  // merge same-attribute geometries into one (BufferGeometryUtils). useGroups=false collapses them to a
  // single draw call, so each source's placement must already be baked into its verts (see geo.translate)
  static function mergeGeometries(geos:Array<Dynamic>, ?useGroups:Bool):Dynamic;
}

@:native("THREE.Vector2") extern class Vector2 {
  public function new(?x:Float, ?y:Float);
  public var x:Float;
  public var y:Float;
  public function set(x:Float, y:Float):Vector2;
}

@:native("THREE.Vector3") extern class Vector3 {
  public function new(?x:Float, ?y:Float, ?z:Float);
  public var x:Float;
  public var y:Float;
  public var z:Float;
  public function set(x:Float, y:Float, z:Float):Vector3;
  public function copy(v:Vector3):Vector3;
  public function normalize():Vector3; // scale to unit length in place, returns this
  public function add(v:Vector3):Vector3;
  public function addScaledVector(v:Vector3, s:Float):Vector3;
  public function applyQuaternion(q:Quaternion):Vector3;
  public function applyMatrix4(m:Matrix4):Vector3;
  public function project(cam:Object3D):Vector3;
  public function unproject(cam:Object3D):Vector3; // NDC -> world (inverse of project); used for cursor->ground picking
  public function lerp(v:Vector3, a:Float):Vector3;
  public function lerpVectors(a:Vector3, b:Vector3, t:Float):Vector3;
}

@:native("THREE.Euler") extern class Euler {
  public function new(?x:Float, ?y:Float, ?z:Float, ?order:String);
  public var x:Float;
  public var y:Float;
  public var z:Float;
  public function set(x:Float, y:Float, z:Float, ?order:String):Euler;
  public function setFromQuaternion(q:Quaternion, ?order:String):Euler;
}

@:native("THREE.Quaternion") extern class Quaternion {
  public function new();
  public function setFromAxisAngle(axis:Vector3, angle:Float):Quaternion;
  public function setFromUnitVectors(from:Vector3, to:Vector3):Quaternion;
  public function setFromEuler(e:Euler):Quaternion;
  public function multiply(q:Quaternion):Quaternion;
  public function copy(q:Quaternion):Quaternion;
}

@:native("THREE.Matrix4") extern class Matrix4 {
  public function new();
  public function compose(pos:Vector3, quat:Quaternion, scl:Vector3):Matrix4;
  public function multiplyMatrices(a:Matrix4, b:Matrix4):Matrix4;
}

@:native("THREE.Sphere") extern class Sphere {
  public function new();
  public var center:Vector3;
  public var radius:Float;
}

@:native("THREE.Frustum") extern class Frustum {
  public function new();
  public function setFromProjectionMatrix(m:Matrix4):Frustum;
  public function intersectsSphere(s:Sphere):Bool;
}

@:native("THREE.Color") extern class Color {
  public function new(?hex:Int);
  public function multiplyScalar(s:Float):Color;
  public function copy(c:Color):Color;                   // copy another color's channels in place
  public function lerpColors(a:Color, b:Color, t:Float):Color; // set this = a->b lerp (t in 0..1)
  public function setHex(hex:Int):Color;                 // set channels from 0xRRGGBB (sRGB-decoded)
}

@:native("THREE.Object3D") extern class Object3D {
  public var position:Vector3;
  public var rotation:Euler;
  public var quaternion:Quaternion;
  public var scale:Vector3;
  public var visible:Bool;
  public var castShadow:Bool;    // this object's geometry is rendered into shadow maps
  public var receiveShadow:Bool; // shadow maps are sampled onto this object's material
  public var renderOrder:Float;
  public var matrixWorld:Matrix4;
  public var userData:Dynamic;
  public var name:String;
  public var children:Array<Object3D>;
  public var parent:Null<Object3D>; // set by add()/remove(); null at a subtree root
  public var geometry:Dynamic;   // present on meshes; Dynamic for editor traversal
  public var material:Dynamic;
  public var isInstancedMesh:Bool;
  public function add(o:Object3D):Void;
  public function remove(o:Object3D):Void;
  public function traverse(cb:Object3D->Void):Void;
  public function applyMatrix4(m:Matrix4):Void;
  public function lookAt(v:Vector3):Void;
  public function clone(?recursive:Bool):Object3D; // deep-copy (recursive default true)
  public function updateMatrixWorld(?force:Bool):Void;
}

// axis-aligned bounding box (used to normalize loaded model scale/placement)
@:native("THREE.Box3") extern class Box3 {
  public function new();
  public var min:Vector3;
  public var max:Vector3;
  public function setFromObject(o:Object3D):Box3;
  public function getSize(target:Vector3):Vector3;
  public function getCenter(target:Vector3):Vector3;
}

@:native("THREE.Scene") extern class Scene extends Object3D {
  public function new();
  public var background:Dynamic;
  public var fog:Dynamic;
}

@:native("THREE.Fog") extern class Fog {
  public function new(color:Int, near:Float, far:Float);
}

@:native("THREE.PerspectiveCamera") extern class PerspectiveCamera extends Object3D {
  public function new(fov:Float, aspect:Float, near:Float, far:Float);
  public var aspect:Float;
  public var projectionMatrix:Matrix4;
  public var matrixWorldInverse:Matrix4;
  public function updateProjectionMatrix():Void;
}

@:native("THREE.WebGLRenderer") extern class WebGLRenderer {
  public function new(params:Dynamic);
  public var domElement:Dynamic;
  public var outputColorSpace:Dynamic;
  public var toneMapping:Dynamic;
  public var toneMappingExposure:Float;
  public var shadowMap:Dynamic;
  public var info:RendererInfo;
  public var autoClear:Bool;
  public function setPixelRatio(r:Float):Void;
  public function getPixelRatio():Float;                  // current render scale; passes sized outside the composer need it to match
  public function setSize(w:Float, h:Float):Void;
  public function clearDepth():Void;
  public function setViewport(x:Float, y:Float, w:Float, h:Float):Void;
  public function setScissor(x:Float, y:Float, w:Float, h:Float):Void;
  public function setScissorTest(on:Bool):Void;
  public function render(scene:Scene, camera:Dynamic):Void;
  public function setRenderTarget(target:Dynamic):Void; // bind an offscreen WebGLRenderTarget (null = default framebuffer); its color space is baked into every program's cacheKey
  public function compile(scene:Scene, camera:Dynamic):Void; // pre-warm: compile all scene materials' shader programs up front (avoids first-frame stall)
  public function compileAsync(scene:Scene, camera:Dynamic):Dynamic; // like compile() but parallel + non-blocking (KHR_parallel_shader_compile); returns a Promise resolving when programs are ready
}

@:native("THREE.OrthographicCamera") extern class OrthographicCamera extends Object3D {
  public function new(left:Float, right:Float, top:Float, bottom:Float, near:Float, far:Float);
  public function updateProjectionMatrix():Void;
}

@:native("THREE.AxesHelper") extern class AxesHelper extends Object3D {
  public function new(size:Float);
}

typedef RendererInfo = {
  var autoReset:Bool;
  function reset():Void;
  var render:{ var triangles:Int; var calls:Int; };
  var memory:{ var geometries:Int; var textures:Int; };
  var programs:Array<Dynamic>;   // compiled shader programs; length jumps == a (re)compile happened
};

@:native("THREE.AmbientLight") extern class AmbientLight extends Object3D {
  public function new(color:Int, intensity:Float);
}
@:native("THREE.HemisphereLight") extern class HemisphereLight extends Object3D {
  public function new(sky:Int, ground:Int, intensity:Float);
}
@:native("THREE.DirectionalLight") extern class DirectionalLight extends Object3D {
  public function new(color:Int, intensity:Float);
  public var target:Object3D; // the point the light aims at (must be in the scene graph to update)
  public var shadow:Dynamic;  // LightShadow: .mapSize (Vector2), .bias, .normalBias, .camera (ortho)
}
@:native("THREE.PointLight") extern class PointLight extends Object3D {
  public function new(color:Int, intensity:Float, ?distance:Float, ?decay:Float);
}
// conical light: emits from position within a cone aimed at `target` (must be in the scene graph
// for its world matrix to update). angle = cone half-angle (rad), penumbra = soft edge 0..1
@:native("THREE.SpotLight") extern class SpotLight extends Object3D {
  public function new(color:Int, ?intensity:Float, ?distance:Float, ?angle:Float, ?penumbra:Float, ?decay:Float);
  public var target:Object3D;   // the point the cone aims at
  public var angle:Float;       // cone half-angle in radians
  public var penumbra:Float;    // soft-edge fraction (0 = hard, 1 = fully soft)
  public var distance:Float;    // falloff end
  public var intensity:Float;
  public var color:Color;       // bulb tint. a plain vec3 uniform, NOT in the program cache key, so a
                                // pooled slot may be recoloured per frame as it changes owner lamp
  public var shadow:Dynamic;    // LightShadow: .mapSize (Vector2), .bias, .camera (perspective, from angle)
}

@:native("THREE.BoxGeometry") extern class BoxGeometry {
  public function new(w:Float, h:Float, d:Float);
  public function translate(x:Float, y:Float, z:Float):BoxGeometry; // bakes the offset into vertices (from BufferGeometry), so a merged mesh needs no per-source transform
}
@:native("THREE.PlaneGeometry") extern class PlaneGeometry {
  public function new(w:Float, h:Float);
}
@:native("THREE.RingGeometry") extern class RingGeometry {
  public function new(inner:Float, outer:Float, seg:Int);
}
@:native("THREE.SphereGeometry") extern class SphereGeometry {
  public function new(r:Float, wseg:Int, hseg:Int, ?phiStart:Float, ?phiLength:Float, ?thetaStart:Float, ?thetaLength:Float);
  public function rotateX(a:Float):SphereGeometry; // bakes rotation into vertices (from BufferGeometry)
  public function scale(x:Float, y:Float, z:Float):SphereGeometry; // bakes scale into vertices
}
@:native("THREE.CylinderGeometry") extern class CylinderGeometry {
  public function new(rt:Float, rb:Float, h:Float, ?radial:Int, ?heightSeg:Int, ?openEnded:Bool, ?thetaStart:Float, ?thetaLength:Float);
  public function rotateZ(a:Float):CylinderGeometry; // bakes rotation into vertices (from BufferGeometry)
  public function translate(x:Float, y:Float, z:Float):CylinderGeometry; // bakes translation into vertices
  public function scale(x:Float, y:Float, z:Float):CylinderGeometry;
}
@:native("THREE.EdgesGeometry") extern class EdgesGeometry {
  public function new(geo:Dynamic, ?thresholdAngle:Float);
}

@:native("THREE.BufferGeometry") extern class BufferGeometry {
  public function new();
  public var groups:Array<{ var start:Int; var count:Int; var materialIndex:Int; }>;
  public var index:Dynamic;       // .getX(i)
  public var attributes:Dynamic;  // .position.getX/getY/getZ
  public function setAttribute(name:String, attr:Dynamic):Void;
  public function setIndex(idx:Array<Int>):Void;
  public function computeVertexNormals():Void;
  public function clone():BufferGeometry;         // deep copy, attribute buffers included (render.Models.hullGeo bakes into one)
  public function computeBoundingSphere():Void;   // re-fit the cull sphere after mutating positions in place
  public function dispose():Void;
}

@:native("THREE.Float32BufferAttribute") extern class Float32BufferAttribute {
  public function new(arr:Array<Float>, itemSize:Int);
}

@:native("THREE.MeshStandardMaterial") extern class MeshStandardMaterial {
  public function new(params:Dynamic);
  public var map:Texture;
  public var emissive:Color;
  public var emissiveMap:Texture;
  public var emissiveIntensity:Float;
  public var alphaTest:Float; // fragments with map alpha below this are discarded (window-cutout sprites)
  public var userData:Dynamic;
}
@:native("THREE.MeshBasicMaterial") extern class MeshBasicMaterial {
  public function new(params:Dynamic);
  public var color:Color; // base color (mutate in place, e.g. lerpColors, for live tinting)
}
// diffuse-only lit material: per-pixel Lambert, no GGX specular lobe and no IBL. same map/emissive/
// shadow feature set as Standard minus roughness/metalness, so it is the drop-in for the fully matte
// city surfaces (all of which set roughness 1 / metalness 0) — see docs/3d-render.md
@:native("THREE.MeshLambertMaterial") extern class MeshLambertMaterial {
  public function new(params:Dynamic);
  public var map:Texture;
  public var emissive:Color;
  public var emissiveMap:Texture;
  public var emissiveIntensity:Float;
  public var alphaTest:Float; // fragments with map alpha below this are discarded (window-cutout sprites)
  public var userData:Dynamic;
}
@:native("THREE.ShaderMaterial") extern class ShaderMaterial {
  public function new(params:Dynamic);
  public var uniforms:Dynamic;
}
@:native("THREE.LineBasicMaterial") extern class LineBasicMaterial {
  public function new(params:Dynamic);
}
@:native("THREE.SpriteMaterial") extern class SpriteMaterial {
  public function new(params:Dynamic);
}

@:native("THREE.Mesh") extern class Mesh extends Object3D {
  public function new(geo:Dynamic, mat:Dynamic);
}
@:native("THREE.InstancedMesh") extern class InstancedMesh extends Object3D {
  public function new(geo:Dynamic, mat:Dynamic, count:Int);
  public var instanceMatrix:InstancedBufferAttribute; // per-instance transforms, 16 floats each
  public var count:Int; // instances actually drawn (<= allocated); trimmed per frame by Models.cull
  public function setMatrixAt(i:Int, m:Matrix4):Void;
  public function dispose():Void; // release GPU buffers when the mesh is thrown away
}
@:native("THREE.InstancedBufferAttribute") extern class InstancedBufferAttribute {
  public function new(array:Dynamic, itemSize:Int); // one value per instance (e.g. per-decal alpha)
  public var array:js.lib.Float32Array; // the raw backing buffer, itemSize floats per instance
  public var needsUpdate:Bool; // set true after writing `array` to re-upload
  public function setUsage(usage:Dynamic):InstancedBufferAttribute; // DynamicDrawUsage for per-frame updates
}
@:native("THREE.LineSegments") extern class LineSegments extends Object3D {
  public function new(geo:Dynamic, mat:Dynamic);
}
@:native("THREE.Group") extern class Group extends Object3D {
  public function new();
}
@:native("THREE.Sprite") extern class Sprite extends Object3D {
  public function new(mat:Dynamic);
}

@:native("THREE.Texture") extern class Texture {
  public function new();
  public var uuid:String;
  public var image:Dynamic;
  public var needsUpdate:Bool;
  public var colorSpace:Dynamic;
  public var wrapS:Dynamic;
  public var wrapT:Dynamic;
  public var repeat:Vector2;
  public var offset:Vector2;
  public var center:Vector2;
  public var rotation:Float;
  public var anisotropy:Int;
  public var flipY:Bool; // glb textures ship flipY=false; a CanvasTexture defaults to true
  public var premultiplyAlpha:Bool; // premultiply on upload; pairs with material.premultipliedAlpha. needed for
                                    // hand-painted alpha, whose junk RGB under near-transparent texels otherwise
                                    // bleeds out as saturated specks once minified
  public var channel:Int; // which uv attribute this map samples (0 = `uv`, 1 = `uv1`, ...)
  public function clone():Texture;
  public function dispose():Void; // free the GPU texture — needed for one-off canvas-baked maps, which
                                  // render.View.disposeScene deliberately leaves alone (it assumes cached ones)
}
@:native("THREE.CanvasTexture") extern class CanvasTexture extends Texture {
  public function new(canvas:Dynamic);
}
@:native("THREE.TextureLoader") extern class TextureLoader {
  public function new();
  public function load(path:String, ?onLoad:Dynamic, ?onProgress:Dynamic, ?onError:Dynamic):Texture;
}

typedef Intersection = {
  var object:Object3D;
  @:optional var face:{ var materialIndex:Int; };
  @:optional var faceIndex:Int;
  @:optional var instanceId:Int;
  var distance:Float;
};

@:native("THREE.Raycaster") extern class Raycaster {
  public function new();
  public function setFromCamera(ndc:Vector2, cam:Object3D):Void;
  public function intersectObjects(objs:Array<Object3D>, recursive:Bool):Array<Intersection>;
}

// --- postprocessing addons (re-exported onto the same THREE global by the vendor bundle) ---
@:native("THREE.EffectComposer") extern class EffectComposer {
  public function new(renderer:WebGLRenderer);
  public var renderTarget1:Dynamic; // composer's primary offscreen RT (set .samples for MSAA)
  public var renderTarget2:Dynamic; // composer's ping-pong RT (kept in sync with rt1)
  public function addPass(p:Dynamic):Void;
  public function render():Void;
  public function setSize(w:Float, h:Float):Void;
  public function setPixelRatio(r:Float):Void; // render scale: resizes both targets AND every pass to w*r
  public function dispose():Void; // release the composer's render targets (bloom etc.) on teardown
}
@:native("THREE.RenderPass") extern class RenderPass {
  public function new(scene:Scene, camera:Object3D);
}
@:native("THREE.UnrealBloomPass") extern class UnrealBloomPass {
  public function new(resolution:Vector2, strength:Float, radius:Float, threshold:Float);
  public var enabled:Bool;
}
// ground-truth ambient occlusion; renders its own depth + normal prepass of the scene each frame,
// so it is enabled-gated (a disabled pass is skipped whole by the composer) — see render.View.setAO
@:native("THREE.GTAOPass") extern class GTAOPass {
  public function new(scene:Scene, camera:Object3D, width:Float, height:Float);
  public var enabled:Bool;                                 // false = composer skips the pass and its prepass entirely
  public var blendIntensity:Float;                         // AO darkening strength over the beauty pass
  public function setSize(w:Float, h:Float):Void;          // resize the AO/denoise/prepass render targets
  public function updateGtaoMaterial(params:Dynamic):Void; // radius/distanceExponent/thickness/scale/samples
  public function dispose():Void;                          // frees its RTs/noise textures — composer.dispose() does NOT touch passes
}
@:native("THREE.OutputPass") extern class OutputPass {
  public function new();
}
@:native("THREE.ShaderPass") extern class ShaderPass {
  public function new(shader:Dynamic);
  public var enabled:Bool;
  public var uniforms:Dynamic; // the pass's CLONED uniform set (write values here, not on the source shader object)
}
// glb loader (re-exported onto the THREE global by the vendor bundle); gltf.scene is the root Group
@:native("THREE.GLTFLoader") extern class GLTFLoader {
  public function new();
  public function load(url:String, onLoad:GLTF -> Void, ?onProgress:Dynamic -> Void, ?onError:Dynamic -> Void):Void;
}
typedef GLTF = {
  var scene:Object3D; // root node of the loaded model
};
