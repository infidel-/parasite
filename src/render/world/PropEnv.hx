package render.world;

import three.Three;
import render.world.PropEnvOpts;

// the INDOOR ENVIRONMENT: the room as a reflective prop sees it, folded into the handful of
// materials that are supposed to be METAL.
//
// it exists because a lab trolley is a steel frame and read as a grey slab. Measured on the shipped
// frame, over the trolley's own 1,110 pixels: mean 43.2 against a background of 42.3 — the prop was
// **0.9 of 255** different from the floor behind it — and every bit of its variation came from its
// albedo, because render.world.IndoorMask's fill was normal-blind and all 48 indoor fixtures hang at
// 5.8 aiming straight down.
//
// THE THIRD CAUSE, AND THE ONLY VIEW-DEPENDENT ONE. IndoorMaskOpts.bounce gives the fill a
// direction, so a shape reads; the baked COLOR_0 occlusion (tools/models.mjs) gives a prop its own
// crevices, so a hollow reads. Neither moves when the camera does. A reflection is the only term in
// this game that varies with the VIEW as well as the normal, which is what separates brushed steel
// from grey plastic.
//
// > PMREM WAS TRIED FIRST AND IS UNUSABLE IN THIS BUILD. The physical route is real metal —
// > `roughness` in models.json to keep a prop on MeshStandard, plus a prefiltered environment on
// > `scene.environment` — and it fails on a bug in the vendored three: **PMREMGenerator's blurred
// > mips come out black.** Measured on an isolated scene containing one sphere and nothing else, a
// > pure white equirect at envMapIntensity 1: roughness 0.05 -> 108.2, 0.15 -> 45.1, 0.25 -> **1.2**,
// > 0.45 and 0.8 -> **0**. Only mip 0 carries anything. Reproduced with a fresh PMREMGenerator, a
// > fresh renderer state and a clean unpatched MeshStandardMaterial, so it is not this codebase's
// > shader patches and not a timing problem. The band it does work in — roughness under ~0.2 — is
// > exactly the band tools/models.mjs documents as the half-float bloom catastrophe (GGX D goes as
// > roughness^-4 and one texel past 65504 turns the whole frame black). So there is no safe setting.
//
// SO IT IS AN INJECTION, which is what the rest of this package does anyway (VisionMask, IndoorMask,
// ContactMask). Three colour stops picked by the reflection vector's world Y, times a Schlick edge
// term, added to `reflectedLight.indirectSpecular` — about eight instructions, no texture, no
// envMap, no PMREM, and no `USE_ENVMAP` in the program key.
//
// IT WORKS ON LAMBERT, which the physical route could not, so the props keep render.Models.toLambert's
// cheap path and stay clear of the roughness minefield entirely — the metal is a look here, not a BRDF.
//
// AND THE GLINT HAS TO LIVE HERE TOO, because a REAL specular highlight cannot reach an indoor prop
// however the material is dialled. Holding a prop on MeshStandard is one number (`roughness` in
// models.json, which stops toLambert), and it was measured over the trolley's own 23.6k pixels at a
// pinned close-up: roughness 1.0 -> 0.4 -> 0.2 moved the mean 66.41 -> 66.25 -> 65.98 and left p99
// and max BIT-IDENTICAL. The reason is the light budget, not the BRDF — knocking out each term in
// turn: every analytic light in the room (the moon plus all 12 pooled spots) is **2.19 of 66.72**,
// i.e. **3.3%** of the prop's pixel; this reflection at 0.06 is 3.31; render.world.IndoorMask's flat
// fill plus albedo plus the baked AO is the remaining ~92%. A specular lobe can only ever modulate
// that 3.3%. Raising `metalness` to reach for a stronger F0 makes it worse, not better, and by a lot:
// diffuse is scaled by (1 - metalness), so metal 0.3 took the prop from +11.4 to **-2.6** against its
// own floor — DARKER than the tile behind it — and metal 0.5 at indoorDirect 3.0 blew the room out
// before the prop caught a highlight. So `propEnvSheen` below is a lobe on the FAKE environment,
// which is the one term here that is neither an analytic light nor scaled by IndoorMask.direct.
//
// AND IT GOES INTO `indirectDiffuse`, WHICH IS NOT A TYPO. The obvious accumulator for a reflection
// is `indirectSpecular`, it compiles clean, and on Lambert it is silently thrown away: this three
// emits `vec3 outgoingLight = reflectedLight.directDiffuse + reflectedLight.indirectDiffuse +
// totalEmissiveRadiance;` for a Lambert program — no specular terms in the sum at all. Written that
// way first and measured at exactly zero effect with the inject verifiably present in the compiled
// shader source. Which accumulator a term lands in is a plumbing detail here, not a claim about the
// light: nothing downstream treats the two differently, and `RE_IndirectDiffuse` ADDS rather than
// assigns, so seeding it before <lights_fragment_end> is safe.
class PropEnv
{
  // the view-anchored face glint's lobe: broad, so a face turned part way off its key still takes
  // some of it (a float literal, it is pasted into the GLSL)
  static inline var FACE_GLOSS = '8.0';

  static var opt:PropEnvOpts = null;
  public static var on(default, null):Bool = false;

  // shared by identity, the same idiom IndoorMask's uniforms use: writing .value here reaches every
  // patched material at once
  static var uSky:Dynamic = { value: new Color(0x000000) };
  static var uHorizon:Dynamic = { value: new Color(0x000000) };
  static var uGround:Dynamic = { value: new Color(0x000000) };
  static var uStrength:Dynamic = { value: 0.0 };
  static var uKey:Dynamic = { value: new Color(0x000000) };
  static var uKeyDir:Dynamic = { value: new Vector3(0, 1, 0) };
  static var uGloss:Dynamic = { value: 1.0 };
  static var uSheen:Dynamic = { value: 0.0 };

// bind the environment for an area. unlike IndoorMask.attach this may run at any point — the
// materials hold the uniform blocks by identity and `apply` decides on its own whether to inject
  public static function attach(o:PropEnvOpts):Void
    {
      opt = o;
      on = true;
      uSky.value = new Color(o.sky);
      uHorizon.value = new Color(o.horizon);
      uGround.value = new Color(o.ground);
      uStrength.value = o.intensity;
      uKey.value = new Color(o.key);
      uKeyDir.value = new Vector3(o.keyDir[0], o.keyDir[1], o.keyDir[2]).normalize();
      uGloss.value = o.gloss;
      uSheen.value = o.sheen;
    }

// release it. every other area kind runs through this, so a tunnel prop cannot go on reflecting the
// last compound's ceiling. zeroing the strength is what makes an already-patched material — a prop
// batch outlives nothing here, but the pattern matches IndoorMask and costs one write — a no-op
  public static function detach():Void
    {
      opt = null;
      on = false;
      uStrength.value = 0.0;
      uSheen.value = 0.0;
    }

// fold the reflection into one material, and hand it back the way IndoorMask.patch does.
//
// `face` is a second glint for THIS material alone, for brushed steel that has to flash on its flat
// faces: the room's key is a WORLD direction, and from the tactical pitch a top reflects it away
// from the camera and a side reflects the floor, so only a chamfer strip ever catches it. This one
// is anchored to the VIEW, two keys over and under the camera's line of sight, so a top and a side
// each flash as the camera turns onto them. Its strength is a uniform of the material's own, so the
// program stays the shared `propenv` one and every other prop carries it at 0.
//
// GATED ON `on`, because this is only ever called from a prop builder that may run before or after
// the scene rig depending on when its glb resolves — and a material patched with the strength at 0
// would carry the instructions forever for nothing
  public static function apply(mat:Dynamic, face:Float = 0.0):Dynamic
    {
      if (mat == null ||
          !on ||
          (mat.onBeforeCompile != null &&
           mat.onBeforeCompile.propEnv == true))
        return mat;
      if (mat.isMeshLambertMaterial != true &&
          mat.isMeshStandardMaterial != true &&
          mat.isMeshPhongMaterial != true)
        return mat;
      // AFTER <lights_fragment_begin>, for the same reason IndoorMask anchors there: it is where
      // three has declared `geometryNormal` and `geometryViewDir` and has not yet combined anything.
      //
      // WORLD UP COMES THROUGH `viewMatrix`. Everything at this anchor is in VIEW space, and the
      // facility camera sits at 65 degrees of pitch, so reading `.y` off the reflection vector
      // directly would shade against the camera instead of against the room.
      //
      // the edge term is Schlick with a 0.08 floor rather than a physical 0.04: this is standing in
      // for a whole BRDF, so the face-on case has to carry some reflection or a flat panel turns
      // black where a real one would show the ceiling
      var inject =
        '  vec3 peUp = normalize( ( viewMatrix * vec4( 0.0, 1.0, 0.0, 0.0 ) ).xyz );\n' +
        '  vec3 peRef = reflect( -geometryViewDir, geometryNormal );\n' +
        '  float peY = dot( peRef, peUp );\n' +
        '  vec3 peCol = peY > 0.0 ? mix( propEnvHorizon, propEnvSky, peY ) : mix( propEnvHorizon, propEnvGround, -peY );\n' +
        '  float peF = 0.08 + 0.92 * pow( 1.0 - clamp( dot( geometryNormal, geometryViewDir ), 0.0, 1.0 ), 5.0 );\n' +
        '  vec3 peKey = normalize( ( viewMatrix * vec4( propEnvKeyDir, 0.0 ) ).xyz );\n' +
        '  float peS = pow( max( dot( peRef, peKey ), 0.0 ), propEnvGloss );\n' +
        '  reflectedLight.indirectDiffuse += peCol * propEnvStrength * peF + propEnvKey * ( propEnvSheen * peS );\n' +
        '  float peT = pow( max( dot( peRef, normalize( vec3( 0.0, 0.77, 0.63 ) ) ), 0.0 ), ' + FACE_GLOSS + ' );\n' +
        '  float peD = pow( max( dot( peRef, normalize( vec3( 0.0, -0.76, -0.65 ) ) ), 0.0 ), ' + FACE_GLOSS + ' );\n' +
        '  reflectedLight.indirectDiffuse += propEnvKey * ( propEnvFace * ( peT + peD ) );\n';
      var prev:Dynamic = mat.onBeforeCompile;
      // an OWN key only — three's Material carries a DEFAULT customProgramCacheKey on the PROTOTYPE
      // that returns onBeforeCompile.toString(), so taking it blindly calls it unbound every draw
      var prevKey:Dynamic = untyped mat.hasOwnProperty('customProgramCacheKey') ?
        mat.customProgramCacheKey : null;
      var uFace:Dynamic = { value: face };
      var hook:Dynamic = function(shader:Dynamic, renderer:Dynamic)
        {
          if (prev != null)
            prev(shader, renderer);
          shader.uniforms.propEnvSky = uSky;
          shader.uniforms.propEnvHorizon = uHorizon;
          shader.uniforms.propEnvGround = uGround;
          shader.uniforms.propEnvStrength = uStrength;
          shader.uniforms.propEnvKey = uKey;
          shader.uniforms.propEnvKeyDir = uKeyDir;
          shader.uniforms.propEnvGloss = uGloss;
          shader.uniforms.propEnvSheen = uSheen;
          shader.uniforms.propEnvFace = uFace;
          shader.fragmentShader = 'uniform vec3 propEnvSky;\n' +
            'uniform vec3 propEnvHorizon;\n' +
            'uniform vec3 propEnvGround;\n' +
            'uniform float propEnvStrength;\n' +
            'uniform vec3 propEnvKey;\n' +
            'uniform vec3 propEnvKeyDir;\n' +
            'uniform float propEnvGloss;\n' +
            'uniform float propEnvSheen;\n' +
            'uniform float propEnvFace;\n' +
            StringTools.replace(shader.fragmentShader, '#include <lights_fragment_begin>',
              '#include <lights_fragment_begin>\n' + inject);
        };
      // carry forward the marks of whatever hook this just wrapped, so an "already patched" test that
      // can only read the OUTERMOST hook still finds a marker that got chained over
      if (prev != null)
        for (f in Reflect.fields(prev))
          Reflect.setField(hook, f, Reflect.field(prev, f));
      hook.propEnv = true;
      mat.onBeforeCompile = hook;
      mat.customProgramCacheKey = function()
        return (prevKey != null ? Std.string(Reflect.callMethod(mat, prevKey, [])) : '') +
          'propenv';
      mat.needsUpdate = true;
      return mat;
    }
}
