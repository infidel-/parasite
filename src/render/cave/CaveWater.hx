package render.cave;

import three.Three;
import render.RenderConfig;
import render.world.PropShader.ShaderPatch;

// still water in the rimstone pools (asked for: "pools need water shader"). the basin glb keeps its
// water on the bottom row of its sheet (the deep pool left, the shallow band right), so the surface is
// folded into the basin's OWN material and keyed on uv — no second mesh, no second draw call. two
// terms, both fragment shader: ripples (drifting value noise in world xz, the slope by forward
// difference, render.sewer.SewerWater's) tilt a shading normal, and that normal catches a virtual
// light hung OFF the mirror of the camera by a fixed screen-space offset, so a flat pool misses it and
// only a ripple's steep side sparks — glints that crawl. a virtual light and not the scene's: a pool is
// dealt against any wall and the cave's only lamps are the mouths' moonlight, so SewerWater's real
// specular would leave most pools flat. the light first hung at a fixed WORLD direction 15 degrees off
// the mirror, and a flat pool sat inside the glint: the whole surface went a pale sticker blue
class CaveWater
{
  // the ripple clock in BASE_MS turns, and the knobs; uniform objects three keeps BY REFERENCE
  static var uTime = { value: 0.0 };
  static var uScale = { value: CaveStyle.WATER_SCALE };
  static var uAmp = { value: CaveStyle.WATER_AMP };
  static var uRate = { value: CaveStyle.WATER_RATE };
  static var uEdge = { value: CaveStyle.WATER_EDGE };
  static var uBand = { value: CaveStyle.WATER_BAND };
  static var uGlint = { value: new Color(CaveStyle.WATER_GLINT).multiplyScalar(CaveStyle.WATER_GLINT_MUL) };
  // the virtual light's offset off the mirror direction, in VIEW space (screen right, screen up), so it
  // stays the same angle off the mirror at every zoom
  static var uOff = { value: new Vector3(CaveStyle.WATER_OFF_X, CaveStyle.WATER_OFF_Y, 0) };

// fold the surface into the basin's material, once. call BEFORE render.world.VisionMask.patchMesh, so
// the mask's hook chains over this one. `mat` is Dynamic for the reason PropShader.patch gives (the
// externs declare no onBeforeCompile), and the done mark lives on the material object: a field
// Material.copy never carries, so a clone is never mistaken for patched
  public static function patch(mat:Dynamic):Void
    {
      if (mat.caveWater == true)
        return;
      mat.caveWater = true;
      mat.onBeforeCompile = function(shader:ShaderPatch, renderer:Dynamic)
        {
          shader.uniforms.caveWaterTime = uTime;
          shader.uniforms.caveWaterScale = uScale;
          shader.uniforms.caveWaterAmp = uAmp;
          shader.uniforms.caveWaterRate = uRate;
          shader.uniforms.caveWaterEdge = uEdge;
          shader.uniforms.caveWaterBand = uBand;
          shader.uniforms.caveWaterGlint = uGlint;
          shader.uniforms.caveWaterOff = uOff;
          // world xz, through the instance matrix: the basins are one InstancedMesh
          shader.vertexShader = 'varying vec2 vCaveWaterXZ;\n' +
            StringTools.replace(shader.vertexShader, '#include <project_vertex>',
              '#include <project_vertex>\n' +
              '#ifdef USE_INSTANCING\n' +
              '  vCaveWaterXZ = ( modelMatrix * instanceMatrix * vec4( transformed, 1.0 ) ).xz;\n' +
              '#else\n' +
              '  vCaveWaterXZ = ( modelMatrix * vec4( transformed, 1.0 ) ).xz;\n' +
              '#endif');
          shader.fragmentShader = 'uniform float caveWaterTime;\n' +
            'uniform float caveWaterScale;\n' +
            'uniform float caveWaterAmp;\n' +
            'uniform float caveWaterRate;\n' +
            'uniform float caveWaterEdge;\n' +
            'uniform float caveWaterBand;\n' +
            'uniform vec3 caveWaterGlint;\n' +
            'uniform vec3 caveWaterOff;\n' +
            'varying vec2 vCaveWaterXZ;\n' +
            'float caveWaterHash( vec2 p ) { return fract( sin( dot( p, vec2( 127.1, 311.7 ) ) ) * 43758.5453 ); }\n' +
            'float caveWaterNoise( vec2 p )\n' +
            '{\n' +
            '  vec2 i = floor( p );\n' +
            '  vec2 u = fract( p );\n' +
            '  u = u * u * ( 3.0 - 2.0 * u );\n' +
            '  return mix( mix( caveWaterHash( i ), caveWaterHash( i + vec2( 1.0, 0.0 ) ), u.x ),\n' +
            '    mix( caveWaterHash( i + vec2( 0.0, 1.0 ) ), caveWaterHash( i + vec2( 1.0, 1.0 ) ), u.x ), u.y );\n' +
            '}\n' +
            'float caveWaterHeight( vec2 p, float t )\n' +
            '{\n' +
            '  return caveWaterNoise( p + vec2( t, 0.6 * t ) ) +\n' +
            '    0.5 * caveWaterNoise( p * 2.03 + vec2( -0.8 * t, 1.1 * t ) );\n' +
            '}\n' +
            StringTools.replace(shader.fragmentShader, '#include <opaque_fragment>',
              // the water texels: the bottom row of the sheet, the shallow band at a share
              '#ifdef USE_MAP\n' +
              '  {\n' +
              '  float wMask = step( 0.5, vMapUv.y ) * ( vMapUv.x < 0.5 ? 1.0 : caveWaterBand );\n' +
              '  vec2 wp = vCaveWaterXZ * caveWaterScale;\n' +
              '  float wt = caveWaterTime * caveWaterRate;\n' +
              '  float wh = caveWaterHeight( wp, wt );\n' +
              '  vec2 wSlope = vec2( caveWaterHeight( wp + vec2( 0.1, 0.0 ), wt ) - wh,\n' +
              '    caveWaterHeight( wp + vec2( 0.0, 0.1 ), wt ) - wh ) * 10.0 * caveWaterAmp;\n' +
              '  vec3 wN = normalize( ( viewMatrix * vec4( normalize( vec3( -wSlope.x, 1.0, -wSlope.y ) ), 0.0 ) ).xyz );\n' +
              // the flat pool's mirror of the eye, pushed off by the screen-space offset
              '  vec3 wV = normalize( vViewPosition );\n' +
              '  vec3 wUp = normalize( ( viewMatrix * vec4( 0.0, 1.0, 0.0, 0.0 ) ).xyz );\n' +
              '  vec3 wL = normalize( reflect( -wV, wUp ) + caveWaterOff );\n' +
              '  float wG = smoothstep( caveWaterEdge, 1.0, dot( wN, normalize( wV + wL ) ) );\n' +
              '  outgoingLight += caveWaterGlint * wG * wMask;\n' +
              '  }\n' +
              '#endif\n' +
              '#include <opaque_fragment>');
        };
      // three keys programs on base params, not on the hook (render.sewer.SewerWater.surface's reason)
      mat.customProgramCacheKey = function()
        return 'caveWater';
    }

// run the ripple clock
  public static function tick(dtMs:Float):Void
    {
      uTime.value += dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
    }
}
