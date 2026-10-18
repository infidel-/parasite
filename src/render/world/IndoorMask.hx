package render.world;

import js.Browser;
import three.Three;
import citygen.CityConfig;
import render.world.IndoorMaskOpts;

// the INDOOR MASK: a top-down texture saying whether a point is inside a building, sampled by world
// XZ inside every lit material an area draws with, and used to swap the LIGHTING there — the scene's
// ambient + hemisphere fill replaced by an indoor one, and the moon cut back to a fraction.
//
// it exists because a facility interior was lit by the compound's own night rig. the roof
// deliberately casts no shadow (render.facility.FacilityGeom.addRoof: a roof that fades would still
// shadow, and the shadow could not fade with it), so the moon's directional term lands on a
// laboratory floor at FULL strength through a solid ceiling, and the fill it lands over is moon-blue.
// a lab therefore read as the yard with a lid on.
//
// THE OBVIOUS FIX DOES NOT WORK, and the obituary is the point of this header. three's Light.layers
// is documented as picking which objects a light affects, but the renderer tests
// `object.layers.test( camera.layers )` when it COLLECTS lights (WebGLRenderer.projectObject) — a
// light is in the whole render or out of it, and there is no per-object light filtering anywhere in
// the pipeline. two ambient lights cannot be aimed at two sets of meshes. two render passes can, and
// they cost a second full frame.
//
// so this is the same trick render.world.VisionMask already plays for line of sight: no draw call,
// no pass, no geometry, one texture fetch folded into materials that already draw. two properties
// fall out of it that a per-mesh or per-object scheme would have had to build by hand —
//   MOVERS ARE FREE. an actor billboard is lit by where it STANDS, off the same lookup as the floor
//     under it, with no isIndoor call on the cpu and no per-object uniform.
//   THE TRANSITION IS SPATIAL, NOT TIMED. the mask is blurred, so walking through a door crossfades
//     over the blur width. there is no eased `t` here and nothing to tick.
//
// it is deliberately INDEPENDENT of VisionMask rather than folded into its spare channel: its own
// canvas, its own varying, its own uniforms. the two hooks chain in either order, neither has to know
// about the other, and the one surface that needs indoor light but NOT the vision mask — the actor
// billboards in render.particles.Sprites — can take this alone
class IndoorMask
{
  // the live tuning, and whether an area attached one at all. static for the reason VisionMask's are:
  // exactly one area is ever built
  static var opt:IndoorMaskOpts = null;
  public static var on(default, null):Bool = false;
  // the predicate the mask was painted from, kept so the CPU side can ask the same question the
  // shader is answering — see `indoorAt`
  static var pred:(Int, Int) -> Bool = null;

  static var canvas:js.html.CanvasElement = null;
  static var tex:CanvasTexture = null;
  // the unattached stand-in: one black texel. patched materials outside a facility still sample the
  // map every frame, and black reads as `inAmt` 0, which makes the whole injection an exact no-op
  // rather than something to branch around
  static var blank:CanvasTexture = null;

  // the uniform blocks every patched material references BY IDENTITY — three keeps the reference it
  // is handed in onBeforeCompile, so writing .value here reaches every material at once and an
  // update never has to walk them. same idiom, and same reason, as VisionMask's own
  static var uMap:Dynamic = { value: null };
  static var uScale:Dynamic = { value: new Vector2(0, 0) };
  static var uOrigin:Dynamic = { value: new Vector2(0, 0) };
  static var uAmb:Dynamic = { value: new Color(0x000000) };
  static var uDirect:Dynamic = { value: 1.0 };
  static var uBounce:Dynamic = { value: 0.0 };

// bind the mask to an area, painting it from the STATIC "is this cell inside a building" predicate.
//
// CALL THIS BEFORE THE AREA'S BUILDERS RUN, which is the one way it differs from VisionMask.attach
// (which sits happily after them). the mask's uniforms are shared by identity and could be filled at
// any time, but `on` is read by patch() at MATERIAL-CREATION time to decide whether to inject at all
  public static function attach(o:IndoorMaskOpts, w:Int, h:Int, isIndoor:(Int, Int) -> Bool):Void
    {
      opt = o;
      on = true;
      pred = isIndoor;
      paint(w, h, isIndoor);
      uMap.value = tex;
      // the fill as three itself would build it: an sRGB hex decoded to linear by Color, then scaled
      // by the intensity, which is exactly what WebGLLights does to an AmbientLight before it reaches
      // ambientLightColor. so this number is comparable with the scene rig's own
      uAmb.value = new Color(o.ambient).multiplyScalar(o.intensity);
      uDirect.value = o.direct;
      uBounce.value = o.bounce;
    }

// release it. every OTHER area kind runs through this, so a facility exit cannot leave the sewer
// sampling the last compound's floor plan. the black stand-in keeps already-patched materials — the
// actor billboards outlive the area — reading as a clean outdoors
  public static function detach():Void
    {
      opt = null;
      on = false;
      pred = null;
      uMap.value = ensureBlank();
      uDirect.value = 1.0;
      uBounce.value = 0.0;
    }

// is this cell inside a building — the same predicate the mask was painted from, asked on the CPU.
// false everywhere no mask is attached, which is every area kind but the facility and is what makes
// a caller need no branch of its own.
//
// it exists for render.actors.LampShadows, and the case it answers is a real one that a purely
// visual mask cannot: the fake shadow pass has no occlusion test at all, so a lamp OUTSIDE a wall
// throws an actor shadow onto the floor INSIDE it. keying on this rather than on any single fixture
// covers the whole family at once — the bulkhead lamp over a door, which is the closest outdoor
// light to an indoor actor by construction, the masts along the kerb, and in the other direction a
// ceiling fixture shadowing someone standing outside the window
  public static inline function indoorAt(col:Int, row:Int):Bool
    return pred != null && pred(col, row);

// paint the mask and upload it.
//
// one flat step blurred at its boundary, so it wants almost none of the resolution the vision mask's
// polygon edge does. two things are worth knowing about the shape:
//   GROWN by opt.grow. a wall cell has an indoor face and an outdoor face at the same xz and a
//     top-down mask cannot tell them apart; growing the region to the inner face of the wall slab is
//     what puts the two on opposite sides of the boundary, and it is why no material anywhere needs a
//     per-mesh override.
//   IT MUST NOT ESCAPE THE BUILDING, which is a constraint on the PREDICATE and not on this code:
//     the caller has to exclude any cell with the outdoors as a neighbour, or the grow lands a
//     grow's worth of interior light on the pavement. render.facility.FacilityModel.isInterior
//     carries that rule and the measurement that forced it
  static function paint(w:Int, h:Int, isIndoor:(Int, Int) -> Bool):Void
    {
      var P = opt.px;
      var src = Browser.document.createCanvasElement();
      src.width = w * P;
      src.height = h * P;
      var c = src.getContext2d();
      // opaque black rather than a cleared canvas: the mask is read as a plain channel value, and
      // leaving alpha in play only invites the browser to premultiply the blur into it
      c.fillStyle = '#000000';
      c.fillRect(0, 0, src.width, src.height);
      c.fillStyle = '#ff0000';
      // the overhang, in TEXELS. keep opt.px coarse enough that this lands on a whole one — a
      // fractional fillRect edge is resolved as partial coverage, which halves the boundary before
      // the blur has even run (see FacilityStyle.INDOOR.px for the measurement that found it)
      var g = opt.grow * P / CityConfig.CELL;
      for (row in 0...h)
        for (col in 0...w)
          if (isIndoor(col, row))
            c.fillRect(col * P - g, row * P - g, P + 2 * g, P + 2 * g);
      canvas = Browser.document.createCanvasElement();
      canvas.width = src.width;
      canvas.height = src.height;
      var d = canvas.getContext2d();
      // opt.blur is in WORLD units and the filter wants TEXELS — converted here, so changing opt.px
      // never silently rescales the doorway crossfade with it
      d.filter = 'blur(' + (opt.blur * P / CityConfig.CELL) + 'px)';
      d.drawImage(src, 0, 0);
      d.filter = 'none';
      tex = new CanvasTexture(canvas);
      // DATA, not colour, and the same four settings VisionMask.ensure lands on: an sRGB decode would
      // bend the boundary ramp, v has to run with the row index, and a mip chain would both cost a
      // regeneration and over-blur an edge at the grazing angles these cameras live at
      tex.colorSpace = THREE.NoColorSpace;
      tex.flipY = false;
      tex.generateMipmaps = false;
      tex.minFilter = THREE.LinearFilter;
      tex.magFilter = THREE.LinearFilter;
      // world XZ -> uv. CityConfig.cellToWorld puts the CENTRE of cell (col,row) at
      // (col - GRID/2 + 0.5) * CELL, so the continuous cell coordinate of a world x is
      // x / CELL + GRID / 2, and uv is that over the grid. resolution-independent: opt.px changes how
      // finely the step is sampled and nothing here
      uScale.value.set(1 / (CityConfig.CELL * w), 1 / (CityConfig.CELL * h));
      uOrigin.value.set(CityConfig.GRID / 2 / w, CityConfig.GRID / 2 / h);
    }

// the one black texel, built once
  static function ensureBlank():CanvasTexture
    {
      if (blank != null)
        return blank;
      var e = Browser.document.createCanvasElement();
      e.width = 1;
      e.height = 1;
      var c = e.getContext2d();
      c.fillStyle = '#000000';
      c.fillRect(0, 0, 1, 1);
      blank = new CanvasTexture(e);
      blank.colorSpace = THREE.NoColorSpace;
      blank.generateMipmaps = false;
      // one texel, so the filter cannot matter — LinearFilter only because it is the one the extern
      // carries, and a 1x1 map returns the same black either way
      blank.minFilter = THREE.LinearFilter;
      blank.magFilter = THREE.LinearFilter;
      return blank;
    }

// fold the indoor swap into one material, and hand it back so a builder can wrap it around the
// material it was already constructing.
//
// GATED AT THE CALL SITE, not here. render.world.VisionMask only calls this when a mask is attached,
// so a city/tunnel/wilderness surface compiles the shader it compiles today and pays nothing; the
// actor billboards call it ALWAYS, because their pool outlives the area and a per-area decision there
// would either mislight an actor or compile a second program the boot warm never cached.
//
// only the four LIT materials carry <lights_fragment_begin>. deciding that from the material rather
// than from the shader source matters: a hook that marked the material and then found no anchor would
// still have changed customProgramCacheKey, and an identical unpatched material would compile a
// second, byte-identical program under the other key
  public static function patch(mat:Dynamic):Dynamic
    {
      // the "already patched" mark lives on the HOOK and not in userData, for the reason VisionMask
      // carries an obituary for: Material.clone() copies userData but NOT onBeforeCompile, so a
      // userData flag rides onto the ghost clones render.Models makes and locks them out of a patch
      // they never received
      if (mat.fog == false ||
          (mat.onBeforeCompile != null &&
           mat.onBeforeCompile.indoorMask == true))
        return mat;
      if (mat.isMeshLambertMaterial != true &&
          mat.isMeshStandardMaterial != true &&
          mat.isMeshPhongMaterial != true &&
          mat.isMeshToonMaterial != true)
        return mat;
      // AFTER <lights_fragment_begin>, which is where three has accumulated every direct light into
      // reflectedLight and gathered ambient + light probe + hemisphere into `irradiance` — and before
      // <lights_fragment_end> combines them, so this is real light entering the shading equation and
      // not a tint painted over the result.
      //
      // `indoorDirect` scales ALL direct light, the moon and every spotlight alike, and that is a
      // limit of the anchor rather than a choice: the chunk sums point, spot and directional into one
      // reflectedLight and there is no seam between them to inject at. it is compensable, because a
      // fixture hung INSIDE is scaled by exactly this number — a ceiling light is tuned against it,
      // not around it. an outdoor lamp is untouched, since its own fragments read inAmt 0
      //
      // AND THE FILL IS A HEMISPHERE, NOT A CONSTANT, which is the one thing in here that shades a
      // SHAPE rather than a place. an AmbientLight is normal-blind by construction, and indoors it
      // was ~93% of a prop's pixel: measured on the lab trolley, the fill alone gave sd 7.14 over a
      // 44x44 box, the shipped frame 7.02, and sweeping `indoorDirect` from 0.3 to 2.0 — flooding
      // every light in the room 6.7x — moved it to 7.48. The lighting contributed NO form at all;
      // every bit of variation on that prop was its own albedo. It is not a shortage of light and it
      // is not a shadow problem: all 48 indoor fixtures hang at exactly 5.8 and aim straight down
      // (`tx,tz` equals each lamp's own `x,z` on all 48), while 55% of the trolley's normals face
      // SIDEWAYS, so N dot L is ~0 on the faces the camera mostly sees.
      //
      // `1 + bounce * dot(N, up)` is the cheapest term that has a direction at all — four
      // instructions, no light, no draw call, no program permutation. A VERTICAL surface lands on
      // exactly `indoorAmbient`, so the interior value ladder keeps its anchor and `bounce` 0 is a
      // byte-exact no-op.
      //
      // UP IS TAKEN THROUGH `viewMatrix` AND NOT READ OFF `geometryNormal.y`. Everything three hands
      // us at this anchor is in VIEW space — `geometryNormal` is the normalized `vNormal` varying —
      // and the facility camera sits at 65 degrees of pitch, so view-space y is nowhere near world
      // up. Rotating the world up vector into view space costs one mat4-vec4 and is the only form of
      // this that does not silently shade against the camera
      var inject =
        '  float inAmt = texture2D( indoorMap, vIndoorXZ * indoorScale + indoorOrigin ).r;\n' +
        '  float inDir = mix( 1.0, indoorDirect, inAmt );\n' +
        '  reflectedLight.directDiffuse *= inDir;\n' +
        '  reflectedLight.directSpecular *= inDir;\n' +
        '#if defined( RE_IndirectDiffuse )\n' +
        '  float inUp = dot( geometryNormal, normalize( ( viewMatrix * vec4( 0.0, 1.0, 0.0, 0.0 ) ).xyz ) );\n' +
        '  vec3 inFill = indoorAmbient * max( 0.0, 1.0 + indoorBounce * inUp );\n' +
        '  irradiance = mix( irradiance, inFill, inAmt );\n' +
        '#endif\n';
      var prev:Dynamic = mat.onBeforeCompile;
      // an OWN key only. three's Material carries a DEFAULT customProgramCacheKey on the PROTOTYPE
      // that returns this.onBeforeCompile.toString(), so the field is never null and taking it
      // blindly would call it unbound on every draw and blank the frame
      var prevKey:Dynamic = untyped mat.hasOwnProperty('customProgramCacheKey') ?
        mat.customProgramCacheKey : null;
      var hook:Dynamic = function(shader:Dynamic, renderer:Dynamic)
        {
          if (prev != null)
            prev(shader, renderer);
          shader.uniforms.indoorMap = uMap;
          shader.uniforms.indoorScale = uScale;
          shader.uniforms.indoorOrigin = uOrigin;
          shader.uniforms.indoorAmbient = uAmb;
          shader.uniforms.indoorDirect = uDirect;
          shader.uniforms.indoorBounce = uBounce;
          // the instanceMatrix branch is NOT optional: the door leaves and the park plants are
          // InstancedMesh and their placement lives in that matrix alone, so modelMatrix by itself
          // would pin a whole batch to the world origin and light it as whatever stands there
          shader.vertexShader = 'varying vec2 vIndoorXZ;\n' +
            StringTools.replace(shader.vertexShader, '#include <project_vertex>',
              '#include <project_vertex>\n' +
              '#ifdef USE_INSTANCING\n' +
              '  vIndoorXZ = ( modelMatrix * instanceMatrix * vec4( transformed, 1.0 ) ).xz;\n' +
              '#else\n' +
              '  vIndoorXZ = ( modelMatrix * vec4( transformed, 1.0 ) ).xz;\n' +
              '#endif');
          shader.fragmentShader = 'uniform sampler2D indoorMap;\n' +
            'uniform vec2 indoorScale;\n' +
            'uniform vec2 indoorOrigin;\n' +
            'uniform vec3 indoorAmbient;\n' +
            'uniform float indoorDirect;\n' +
            'uniform float indoorBounce;\n' +
            'varying vec2 vIndoorXZ;\n' +
            StringTools.replace(shader.fragmentShader, '#include <lights_fragment_begin>',
              '#include <lights_fragment_begin>\n' + inject);
        };
      // carry forward the marks of whatever hook we just wrapped, so an "already patched" test that
      // can only read the OUTERMOST hook still finds a marker that got chained over. without it two
      // markers that wrap each other both read as absent and re-patch every frame — a mutual loop
      // that compiles a new program per round
      if (prev != null)
        for (f in Reflect.fields(prev))
          Reflect.setField(hook, f, Reflect.field(prev, f));
      hook.indoorMask = true;
      mat.onBeforeCompile = hook;
      // three keys its program cache on base material params, NOT on onBeforeCompile — without a key
      // of our own an indoor-lit program could be handed to an identical plain material. the chained
      // key has to carry the wrapped hook's too, or a masked+indoor surface collides with a masked one
      mat.customProgramCacheKey = function()
        return (prevKey != null ? Std.string(Reflect.callMethod(mat, prevKey, [])) : '') +
          'indoor';
      mat.needsUpdate = true;
      // a material patched before any area attached (the actor billboards at boot) still has to
      // sample something
      if (uMap.value == null)
        uMap.value = ensureBlank();
      return mat;
    }
}
