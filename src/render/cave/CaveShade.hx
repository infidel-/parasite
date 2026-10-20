package render.cave;

import three.Three;
import render.RenderConfig;
import render.world.PropShader.ShaderPatch;

// the dressing's own shading, folded into the materials it already draws with (asked for: "the stones
// are all uniform"). the cave's fill is normal-blind ambient for most of a vertical face's light and the
// same on all four sides, so no light parts one stone from the next; this writes that into the albedo,
// where no fill can flatten it (render.world.ContactMask's reasoning). three terms on every piece: a
// value of its own per placement, hashed off its instance TRANSLATION (a hash off gl_InstanceID would
// move with any repack of the batch), smooth world-space noise so the stones of one pile part, and a
// dark foot climbing to the full value, so each piece stands on the floor.
//
// the crystals add two (asked for: "add shader to crystals or specular glint"): a band of light climbing
// through the cluster with a slow breath under it, and glints off a virtual light circling the eye, so
// the prisms' flat facets catch it one at a time — render.cave.CaveWater's light, made to move, since
// the gameplay camera barely does and a still light would leave every highlight frozen
class CaveShade
{
  // the clock in BASE_MS turns, and the knobs; uniform objects three keeps BY REFERENCE
  static var uTime = { value: 0.0 };
  static var uJit = { value: CaveStyle.SHADE_JIT };
  static var uNoise = { value: CaveStyle.SHADE_NOISE };
  static var uNoiseScale = { value: CaveStyle.SHADE_NOISE_SCALE };
  static var uFoot = { value: CaveStyle.SHADE_FOOT };
  static var uBandRate = { value: CaveStyle.CRYSTAL_BAND_RATE };
  static var uBandH = { value: CaveStyle.CRYSTAL_BAND_H };
  static var uBandW = { value: CaveStyle.CRYSTAL_BAND_W };
  static var uBandAmp = { value: CaveStyle.CRYSTAL_BAND_AMP };
  static var uBreathe = { value: CaveStyle.CRYSTAL_BREATHE };
  static var uBreatheRate = { value: CaveStyle.CRYSTAL_BREATHE_RATE };
  static var uGlintRate = { value: CaveStyle.GLINT_RATE };
  static var uGlintEdge = { value: CaveStyle.GLINT_EDGE };
  static var uGlint = { value: new Color(CaveStyle.GLINT).multiplyScalar(CaveStyle.GLINT_MUL) };
  static var uCut = { value: CaveStyle.CRYSTAL_DIFFUSE_CUT };

// fold the shading into one dressing material, once: `h` is the piece's world height, which the foot
// climbs over a share of (a basin a third of a unit high is all foot at SHADE_RISE, and went black),
// and `crystal` adds the band, the breath and the glints. call AFTER render.cave.CaveWater.patch (this
// chains the hook before it) and BEFORE render.world.VisionMask.patchMesh (which chains over this).
// `mat` is Dynamic for the reason PropShader.patch gives, and the done mark lives on the material, as
// CaveWater's does
  public static function patch(mat:Dynamic, h:Float, crystal:Bool):Void
    {
      if (mat.caveShade == true)
        return;
      mat.caveShade = true;
      var uRise = { value: Math.min(CaveStyle.SHADE_RISE, h * CaveStyle.SHADE_RISE_H) };
      var prev:Dynamic = mat.onBeforeCompile;
      // an OWN key only, for the reason render.world.VisionMask.patch gives
      var prevKey:Dynamic = untyped mat.hasOwnProperty('customProgramCacheKey') ?
        mat.customProgramCacheKey : null;
      mat.onBeforeCompile = function(shader:ShaderPatch, renderer:Dynamic)
        {
          if (prev != null)
            prev(shader, renderer);
          shader.uniforms.caveShadeTime = uTime;
          shader.uniforms.caveShadeJit = uJit;
          shader.uniforms.caveShadeNoiseAmp = uNoise;
          shader.uniforms.caveShadeNoiseScale = uNoiseScale;
          shader.uniforms.caveShadeFoot = uFoot;
          shader.uniforms.caveShadeRise = uRise;
          // world position and the instance's origin, through the instance matrix: the dressing is one
          // InstancedMesh per glb
          shader.vertexShader = 'varying vec3 vCaveShadeW;\nvarying vec3 vCaveShadeO;\n' +
            StringTools.replace(shader.vertexShader, '#include <project_vertex>',
              '#include <project_vertex>\n' +
              '#ifdef USE_INSTANCING\n' +
              '  vCaveShadeW = ( modelMatrix * instanceMatrix * vec4( transformed, 1.0 ) ).xyz;\n' +
              '  vCaveShadeO = ( modelMatrix * instanceMatrix[ 3 ] ).xyz;\n' +
              '#else\n' +
              '  vCaveShadeW = ( modelMatrix * vec4( transformed, 1.0 ) ).xyz;\n' +
              '  vCaveShadeO = modelMatrix[ 3 ].xyz;\n' +
              '#endif');
          var head = 'uniform float caveShadeTime;\n' +
            'uniform float caveShadeJit;\n' +
            'uniform float caveShadeNoiseAmp;\n' +
            'uniform float caveShadeNoiseScale;\n' +
            'uniform float caveShadeFoot;\n' +
            'uniform float caveShadeRise;\n' +
            'varying vec3 vCaveShadeW;\n' +
            'varying vec3 vCaveShadeO;\n' +
            'float caveShadeHash( vec3 p ) { return fract( sin( dot( p, vec3( 127.1, 311.7, 74.7 ) ) ) * 43758.5453 ); }\n' +
            'float caveShadeNoise( vec3 p )\n' +
            '{\n' +
            '  vec3 i = floor( p );\n' +
            '  vec3 u = fract( p );\n' +
            '  u = u * u * ( 3.0 - 2.0 * u );\n' +
            '  return mix( mix( mix( caveShadeHash( i ), caveShadeHash( i + vec3( 1.0, 0.0, 0.0 ) ), u.x ),\n' +
            '      mix( caveShadeHash( i + vec3( 0.0, 1.0, 0.0 ) ), caveShadeHash( i + vec3( 1.0, 1.0, 0.0 ) ), u.x ), u.y ),\n' +
            '    mix( mix( caveShadeHash( i + vec3( 0.0, 0.0, 1.0 ) ), caveShadeHash( i + vec3( 1.0, 0.0, 1.0 ) ), u.x ),\n' +
            '      mix( caveShadeHash( i + vec3( 0.0, 1.0, 1.0 ) ), caveShadeHash( i + vec3( 1.0, 1.0, 1.0 ) ), u.x ), u.y ), u.z );\n' +
            '}\n';
          // the origin is the same at every vertex, so the floor() holds the hash still across the piece
          var frag = StringTools.replace(shader.fragmentShader, '#include <color_fragment>',
            '#include <color_fragment>\n' +
            '  {\n' +
            '  float sId = caveShadeHash( floor( vCaveShadeO * 8.0 ) );\n' +
            '  float sN = caveShadeNoise( vCaveShadeW * caveShadeNoiseScale ) * 2.0 - 1.0;\n' +
            '  float sFoot = mix( caveShadeFoot, 1.0, smoothstep( 0.0, caveShadeRise, vCaveShadeW.y ) );\n' +
            '  diffuseColor.rgb *= ( 1.0 + caveShadeJit * ( 2.0 * sId - 1.0 ) + caveShadeNoiseAmp * sN ) * sFoot;\n' +
            '  }');
          if (crystal)
            {
              shader.uniforms.caveShadeBandRate = uBandRate;
              shader.uniforms.caveShadeBandH = uBandH;
              shader.uniforms.caveShadeBandW = uBandW;
              shader.uniforms.caveShadeBandAmp = uBandAmp;
              shader.uniforms.caveShadeBreathe = uBreathe;
              shader.uniforms.caveShadeBreatheRate = uBreatheRate;
              shader.uniforms.caveShadeGlintRate = uGlintRate;
              shader.uniforms.caveShadeGlintEdge = uGlintEdge;
              shader.uniforms.caveShadeGlint = uGlint;
              shader.uniforms.caveShadeCut = uCut;
              head += 'uniform float caveShadeBandRate;\n' +
                'uniform float caveShadeBandH;\n' +
                'uniform float caveShadeBandW;\n' +
                'uniform float caveShadeBandAmp;\n' +
                'uniform float caveShadeBreathe;\n' +
                'uniform float caveShadeBreatheRate;\n' +
                'uniform float caveShadeGlintRate;\n' +
                'uniform float caveShadeGlintEdge;\n' +
                'uniform vec3 caveShadeGlint;\n' +
                'uniform float caveShadeCut;\n';
              // the band and the breath scale the glow; the mask (the lit texels of the emissive map)
              // keeps the glints off the rock the prisms grow from, and takes most of the prisms' diffuse
              // away: their albedo is 4-5x the floor's, so the glow's own spotlight, hung over them,
              // washed them white. a glowing crystal's colour is its light, not what it reflects (this
              // runs before lights_lambert_fragment reads diffuseColor)
              frag = StringTools.replace(frag, '#include <emissivemap_fragment>',
                '#include <emissivemap_fragment>\n' +
                '  float caveShadeMask = 0.0;\n' +
                '  vec3 caveShadeTint = vec3( 0.0 );\n' +
                '#ifdef USE_EMISSIVEMAP\n' +
                '  caveShadeTint = emissiveColor.rgb;\n' +
                '  caveShadeMask = smoothstep( 0.05, 0.2, max( caveShadeTint.r, max( caveShadeTint.g, caveShadeTint.b ) ) );\n' +
                '#endif\n' +
                '  diffuseColor.rgb *= 1.0 - caveShadeCut * caveShadeMask;\n' +
                '  {\n' +
                '  float cPh = caveShadeHash( floor( vCaveShadeO * 8.0 ) + 7.0 );\n' +
                '  float cY = vCaveShadeW.y - vCaveShadeO.y;\n' +
                '  float cB = fract( caveShadeTime * caveShadeBandRate + cPh ) * ( caveShadeBandH + 2.0 * caveShadeBandW ) - caveShadeBandW;\n' +
                '  float cBand = 1.0 - smoothstep( 0.0, caveShadeBandW, abs( cY - cB ) );\n' +
                '  totalEmissiveRadiance *= ( 1.0 + caveShadeBreathe * sin( caveShadeTime * caveShadeBreatheRate + cPh * 6.2832 ) ) *\n' +
                '    ( 1.0 + caveShadeBandAmp * cBand );\n' +
                '  }');
              // the virtual light, in VIEW space: round the eye at a radius that wanders 0.1-1.0, so
              // over a few turns it passes every facet within ~25 degrees of facing the camera
              frag = StringTools.replace(frag, '#include <opaque_fragment>',
                '  {\n' +
                '  float gPh = caveShadeHash( floor( vCaveShadeO * 8.0 ) + 3.0 ) * 6.2832;\n' +
                '  float ga = caveShadeTime * caveShadeGlintRate + gPh;\n' +
                '  float gr = 0.55 + 0.45 * sin( ga * 0.37 + gPh );\n' +
                '  vec3 gV = normalize( vViewPosition );\n' +
                '  vec3 gL = normalize( vec3( gr * cos( ga ), gr * sin( ga ), 1.0 ) );\n' +
                '  float gG = smoothstep( caveShadeGlintEdge, 1.0, dot( normalize( normal ), normalize( gV + gL ) ) );\n' +
                '  outgoingLight += caveShadeGlint * ( 0.4 + caveShadeTint ) * gG * caveShadeMask;\n' +
                '  }\n' +
                '#include <opaque_fragment>');
            }
          shader.fragmentShader = head + frag;
        };
      // three keys programs on base params, not on the hook (render.sewer.SewerWater.surface's reason)
      var key = (crystal ? 'caveShadeCrystal' : 'caveShade');
      mat.customProgramCacheKey = function()
        return (prevKey != null ? prevKey() + '|' : '') + key;
    }

// run the band, breath and glint clock
  public static function tick(dtMs:Float):Void
    {
      uTime.value += dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
    }
}
