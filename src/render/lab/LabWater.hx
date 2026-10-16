package render.lab;

import three.Three;
import render.RenderConfig;
import render.world.PropShader.ShaderPatch;

// the amber tanks' fluid, painted on their glass: the shell stays the see-through 0.3 pane
// render.lab.LabInterior.glass makes it, and this folds into it, in the piece's OWN frame (so every
// tank ripples alike whatever its turn), a lit fluid seen through the pane —
//   ripple — two crossed sine bands crawling up the pane, the slow light play of a lit liquid
//   bubbles — see-through rings, columns a WATER_COL apart, each with its own hashed rise and phase, a bubble
//            in some cells of each as they climb, wobbling as they go, below the fluid's top (WATER_TOP)
// both go into the emissive, at WATER_TINT times `level` (render.lab.LabArea dims it as the lab
// dies), and lift the pane's alpha on a bubble's rim only, so its middle stays clear. The clock is
// SewerWater's (BASE_MS turns of ANIM_SPEED), its rates consts of the program
class LabWater
{
  static var uTime = { value: 0.0 };
  static var uLevel = { value: 1.0 };

// run the clock and set how lit the fluid is, 1 full to 0 dark
  public static function tick(dtMs:Float, level:Float):Void
    {
      uTime.value += dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
      uLevel.value = level;
    }

// fold the fluid into a glass material. `mat` is Dynamic for the reason PropShader.patch gives: the
// material externs declare no onBeforeCompile / customProgramCacheKey
  public static function patch(mat:Dynamic):Void
    {
      var uTint = { value: new Color(LabStyle.WATER_TINT) };
      mat.onBeforeCompile = function(shader:ShaderPatch, renderer:Dynamic)
        {
          shader.uniforms.labWaterTime = uTime;
          shader.uniforms.labWaterLevel = uLevel;
          shader.uniforms.labWaterTint = uTint;
          shader.vertexShader = 'varying vec3 vLabWater;\n' +
            'varying float vLabWaterFace;\n' +
            StringTools.replace(shader.vertexShader, '#include <begin_vertex>',
              '#include <begin_vertex>\n' +
              '  vLabWater = transformed;\n' +
              '  vLabWaterFace = abs( objectNormal.z );');
          shader.fragmentShader = 'uniform float labWaterTime;\n' +
            'uniform float labWaterLevel;\n' +
            'uniform vec3 labWaterTint;\n' +
            'varying vec3 vLabWater;\n' +
            'varying float vLabWaterFace;\n' +
            // the rates and sizes as consts, through float(): Haxe prints a whole Float as an int
            'const float LW_RATE = float(' + LabStyle.WATER_RATE + ');\n' +
            'const float LW_COL = float(' + LabStyle.WATER_COL + ');\n' +
            'const float LW_CELL = float(' + LabStyle.WATER_CELL + ');\n' +
            'const float LW_RISE = float(' + LabStyle.WATER_RISE + ');\n' +
            'const float LW_BUBBLE = float(' + LabStyle.WATER_BUBBLE + ');\n' +
            'const float LW_TOP = float(' + LabStyle.WATER_TOP + ');\n' +
            'float labWaterHash( float n ) { return fract( sin( n * 12.9898 ) * 43758.5453 ); }\n' +
            // a bubble is SEE-THROUGH: a thin bright rim and a fleck of highlight up its left, the
            // fluid showing through its middle (a filled pale disc read as a white pill)
            'float labBubble( vec2 d, float r ) {\n' +
            '  float l = length( d );\n' +
            // its edges at least a screen pixel soft: a far bubble's rim is thinner than one, and
            // a hard one broke into dots
            '  float aa = max( fwidth( l ), r * 0.08 );\n' +
            '  float rim = smoothstep( r * 0.68 - aa, r * 0.68 + aa, l ) *\n' +
            '    ( 1.0 - smoothstep( r - 2.0 * aa, r, l ) );\n' +
            '  float hi = smoothstep( r * 0.3, r * 0.1, length( d - vec2( -0.35, 0.35 ) * r ) );\n' +
            '  return max( rim, hi );\n' +
            '}\n' +
            StringTools.replace(shader.fragmentShader, '#include <emissivemap_fragment>',
              '#include <emissivemap_fragment>\n' +
              '  {\n' +
              // across the pane whichever face it is (x on the front, z on the ends), and up it
              '  vec2 q = vec2( vLabWater.x + vLabWater.z, vLabWater.y );\n' +
              '  float t = labWaterTime;\n' +
              '  float rip = 0.6 * smoothstep( 0.55, 1.0,\n' +
              '    sin( q.y * 6.0 - t * LW_RATE + sin( q.x * 2.3 + t * 0.05 ) * 1.4 ) ) +\n' +
              '    0.4 * smoothstep( 0.7, 1.0, sin( q.x * 5.1 + q.y * 3.0 + t * 0.08 ) );\n' +
              // the bubbles of this column AND its two neighbours: a bubble sways up to 0.3 of a
              // column off its centre and is up to 0.39 of one wide, so it crosses into the next
              // column, and looked up in its own alone it was cut off at the line as it swayed
              '  float bub = 0.0;\n' +
              '  for ( int i = -1; i <= 1; i++ ) {\n' +
              '    float c = floor( q.x / LW_COL ) + float( i );\n' +
              '    float h = labWaterHash( c );\n' +
              '    float v = q.y / LW_CELL - t * LW_RISE * ( 0.6 + 0.8 * h ) - h * 7.0;\n' +
              '    float k = floor( v );\n' +
              '    float on = step( 0.55, labWaterHash( k * 3.1 + c * 17.0 ) );\n' +
              '    float bx = ( 0.5 + 0.3 * sin( t * 0.3 + h * 20.0 + k ) ) * LW_COL;\n' +
              '    vec2 d = vec2( q.x - c * LW_COL - bx, ( fract( v ) - 0.5 ) * LW_CELL );\n' +
              '    float r = LW_BUBBLE * ( 0.6 + 0.8 * labWaterHash( k + c ) );\n' +
              '    bub = max( bub, on * labBubble( d, r ) );\n' +
              '  }\n' +
              // only on a pane that faces the front: q.x runs x + z, so on a corner pane or round the
              // cylinder's flank a bubble's disc smears into a streak across it
              '  bub *= step( q.y, LW_TOP ) * smoothstep( 0.6, 0.9, vLabWaterFace );\n' +
              // a bubble burns PALER than the fluid, or it is lost on the bright amber behind the pane
              '  totalEmissiveRadiance += labWaterLevel * ( labWaterTint * ( 0.3 + 0.7 * rip ) +\n' +
              '    vec3( 0.75, 0.62, 0.4 ) * bub );\n' +
              '  diffuseColor.a = min( 1.0, diffuseColor.a + 0.12 * rip + 0.3 * bub );\n' +
              '  }');
        };
      // three keys programs on base params, not on the hook: its own key keeps this program off
      // every other glass shell. VisionMask.patch chains this key into its own
      mat.customProgramCacheKey = function()
        return 'labWater';
      mat.needsUpdate = true;
    }

// the clone vats' growth medium (render.lab.LabVats), in the cylinder's own frame (vat-fluid.glb is
// built at world size, its axis on y): the 2D vat's salad green instead of the sheet's olive — the
// sheet's luminance kept as texture, its hue replaced by VAT_TINT — with
//   swirl   — bands spiralling up the column, three turns round (whole, so atan's seam never shows)
//             and winding into a vortex on the lid, brightening the glow and thickening the medium
//   warp    — the same slow flow bending the sheet's own lookup, so its specks drift and waver: the
//             distortion of looking into moving liquid, without reading the screen behind it
//   bubbles — VAT_BUB_N columns round the column, each with its own hashed rise and phase
// all on the glow at `level` (the lab's death), the drain scaling the column under them. `mat` is
// Dynamic for PropShader.patch's reason
  public static function patchVat(mat:Dynamic):Void
    {
      var uTint = { value: new Color(LabStyle.VAT_TINT) };
      mat.onBeforeCompile = function(shader:ShaderPatch, renderer:Dynamic)
        {
          shader.uniforms.labWaterTime = uTime;
          shader.uniforms.labWaterLevel = uLevel;
          shader.uniforms.labVatTint = uTint;
          shader.vertexShader = 'varying vec3 vLabVat;\n' +
            StringTools.replace(shader.vertexShader, '#include <begin_vertex>',
              '#include <begin_vertex>\n' +
              '  vLabVat = transformed;');
          shader.fragmentShader = 'uniform float labWaterTime;\n' +
            'uniform float labWaterLevel;\n' +
            'uniform vec3 labVatTint;\n' +
            'varying vec3 vLabVat;\n' +
            'const float LV_RATE = float(' + LabStyle.VAT_SWIRL_RATE + ');\n' +
            'const float LV_WARP = float(' + LabStyle.VAT_WARP + ');\n' +
            'const float LV_LUM = float(' + LabStyle.VAT_SHEET_LUM + ');\n' +
            'const float LV_K = float(' + LabStyle.VAT_TINT_K + ');\n' +
            'const float LV_R = float(' + LabStyle.VAT_BUB_RIM + ');\n' +
            'const float LV_N = float(' + LabStyle.VAT_BUB_N + ');\n' +
            'const float LV_ON = float(' + LabStyle.VAT_BUB_ON + ');\n' +
            'const float LV_CELL = float(' + LabStyle.VAT_BUB_CELL + ');\n' +
            'const float LV_RISE = float(' + LabStyle.VAT_BUB_RISE + ');\n' +
            'const float LV_BUB = float(' + LabStyle.VAT_BUB_R + ');\n' +
            'float labVatHash( float n ) { return fract( sin( n * 12.9898 ) * 43758.5453 ); }\n' +
            // a bubble is SEE-THROUGH: a thin bright rim and a fleck of highlight up its left, the
            // fluid showing through its middle (a filled pale disc read as a white pill)
            'float labBubble( vec2 d, float r ) {\n' +
            '  float l = length( d );\n' +
            // its edges at least a screen pixel soft: a far bubble's rim is thinner than one, and
            // a hard one broke into dots
            '  float aa = max( fwidth( l ), r * 0.08 );\n' +
            '  float rim = smoothstep( r * 0.68 - aa, r * 0.68 + aa, l ) *\n' +
            '    ( 1.0 - smoothstep( r - 2.0 * aa, r, l ) );\n' +
            '  float hi = smoothstep( r * 0.3, r * 0.1, length( d - vec2( -0.35, 0.35 ) * r ) );\n' +
            '  return max( rim, hi );\n' +
            '}\n' +
            StringTools.replace(StringTools.replace(shader.fragmentShader, '#include <map_fragment>',
              // the angle round the axis and the height, the swirl and the warp off them
              '  float lvA = atan( vLabVat.z, vLabVat.x );\n' +
              '  float lvY = vLabVat.y;\n' +
              '  float lvT = labWaterTime;\n' +
              // the radius term only acts on the lid, where it winds the bands into a vortex
              '  float lvSwirl = smoothstep( 0.3, 1.0, sin( lvA * 3.0 + lvY * 1.4 +\n' +
              '    length( vLabVat.xz ) * 1.6 - lvT * LV_RATE +\n' +
              '    sin( lvY * 0.8 + lvT * 0.04 ) * 1.5 ) );\n' +
              '  vec2 lvWarp = LV_WARP * vec2( sin( lvY * 1.9 + lvA * 2.0 + lvT * 0.07 ),\n' +
              '    cos( lvA * 4.0 - lvY * 1.3 - lvT * 0.06 ) );\n' +
              '  float lvLum = LV_LUM;\n' +
              '#ifdef USE_MAP\n' +
              '  vec4 lvTex = texture2D( map, vMapUv + lvWarp );\n' +
              '  lvLum = dot( lvTex.rgb, vec3( 0.2126, 0.7152, 0.0722 ) );\n' +
              '  diffuseColor.rgb *= labVatTint * LV_K * ( lvLum / LV_LUM );\n' +
              '#endif'),
              '#include <emissivemap_fragment>',
              '#include <emissivemap_fragment>\n' +
              '  {\n' +
              // the bubbles: a column every 1/LV_N of the turn, cells LV_CELL tall climbing it, looked
              // up in this column and its two neighbours (a swaying one crosses the line), each
              // hashed by its index wrapped round the turn so the seam behind the axis has no edge
              '  float bub = 0.0;\n' +
              '  float lvU = ( lvA / 6.2831853 + 0.5 ) * LV_N;\n' +
              '  for ( int i = -1; i <= 1; i++ ) {\n' +
              '    float c = floor( lvU ) + float( i );\n' +
              '    float cw = mod( c, LV_N );\n' +
              '    float h = labVatHash( cw );\n' +
              '    float v = lvY / LV_CELL - lvT * LV_RISE * ( 0.6 + 0.8 * h ) - h * 7.0;\n' +
              '    float k = floor( v );\n' +
              '    float on = step( LV_ON, labVatHash( k * 3.1 + cw * 17.0 ) );\n' +
              '    float w = length( vLabVat.xz ) * 6.2831853 / LV_N *\n' +
              '      ( lvU - c - 0.5 - 0.25 * sin( lvT * 0.3 + h * 20.0 + k ) );\n' +
              '    vec2 d = vec2( w, ( fract( v ) - 0.5 ) * LV_CELL );\n' +
              '    float r = LV_BUB * ( 0.6 + 0.8 * labVatHash( k + cw ) );\n' +
              '    bub = max( bub, on * labBubble( d, r ) );\n' +
              '  }\n' +
              // only on the column's side: on the lid every column meets the axis, as spokes
              '  bub *= step( LV_R, length( vLabVat.xz ) );\n' +
              '  totalEmissiveRadiance = labWaterLevel * ( totalEmissiveRadiance *\n' +
              '    ( 0.35 + 0.65 * lvSwirl ) * ( 0.6 + 0.4 * lvLum / LV_LUM ) +\n' +
              '    vec3( 0.55, 0.85, 0.65 ) * bub );\n' +
              '  diffuseColor.a = min( 1.0, diffuseColor.a + 0.15 * lvSwirl + 0.25 * bub );\n' +
              '  }');
        };
      mat.customProgramCacheKey = function()
        return 'labVat';
      mat.needsUpdate = true;
    }

// the clone floating in the medium sways and bobs, as a body hanging in moving liquid seen through
// it would: a sideways sine growing with height off its feet, and a slow bob, each vat on its own
// phase off its place. `h0` is the glb's own height and `y0` its foot in its own units, which the
// instance scale takes to CLONE_H (the clone is a TRELLIS glb at its own size). `mat` is Dynamic for
// PropShader.patch's reason
  public static function patchClone(mat:Dynamic, h0:Float, y0:Float):Void
    {
      var k = h0 / LabStyle.CLONE_H;
      mat.onBeforeCompile = function(shader:ShaderPatch, renderer:Dynamic)
        {
          shader.uniforms.labWaterTime = uTime;
          shader.vertexShader = 'uniform float labWaterTime;\n' +
            'const float LC_H = float(' + h0 + ');\n' +
            'const float LC_Y0 = float(' + y0 + ');\n' +
            'const float LC_SWAY = float(' + LabStyle.CLONE_SWAY * k + ');\n' +
            'const float LC_BOB = float(' + LabStyle.CLONE_BOB * k + ');\n' +
            'const float LC_RATE = float(' + LabStyle.CLONE_SWAY_RATE + ');\n' +
            StringTools.replace(shader.vertexShader, '#include <begin_vertex>',
              '#include <begin_vertex>\n' +
              '  {\n' +
              '  float ph = 0.0;\n' +
              '#ifdef USE_INSTANCING\n' +
              '  ph = 6.2831853 * fract( sin( dot( instanceMatrix[3].xz, vec2( 12.9898, 78.233 ) ) ) *\n' +
              '    43758.5453 );\n' +
              '#endif\n' +
              '  float t = labWaterTime * LC_RATE + ph;\n' +
              '  float up = clamp( ( transformed.y - LC_Y0 ) / LC_H, 0.0, 1.0 );\n' +
              '  float yn = transformed.y / LC_H;\n' +
              '  transformed.x += sin( yn * 5.0 + t ) * LC_SWAY * up;\n' +
              '  transformed.z += cos( yn * 3.7 + t * 0.8 ) * LC_SWAY * 0.6 * up;\n' +
              '  transformed.y += sin( t * 0.45 ) * LC_BOB;\n' +
              '  }');
        };
      mat.customProgramCacheKey = function()
        return 'labClone';
      mat.needsUpdate = true;
    }

// the amber tanks' fetuses sway and bob in their fluid as the vats' clones do (patchClone), folded
// over the body's blink patch (render.lab.LabBlink) it chains. The fetuses are part of the body glb,
// so a vertex is one by its UV: the skin's rect and the eyes' (models-src/lab/mach/ambertanks.py's
// sheet layout, measured off its glb), the eyes' rect also holding a few plinth corners, which the
// foot gate keeps still, as it keeps the cords' roots on the tank floor. The sway is smooth in the
// piece's frame, so a fetus moves nearly whole and bends a little. `mat` is Dynamic for
// PropShader.patch's reason
  // ponytail: picked by uv rect; a rebuild that moves the skin or the eye on the sheet must re-measure
  // EMBRYO_SKIN / EMBRYO_EYE, or split the fetuses into their own glb
  public static function patchEmbryo(mat:Dynamic):Void
    {
      var prev = mat.onBeforeCompile;
      var key = mat.customProgramCacheKey;
      var sk = LabStyle.EMBRYO_SKIN, ey = LabStyle.EMBRYO_EYE;
      mat.onBeforeCompile = function(shader:ShaderPatch, renderer:Dynamic)
        {
          prev(shader, renderer);
          shader.uniforms.labWaterTime = uTime;
          shader.vertexShader = 'uniform float labWaterTime;\n' +
            'const float LE_SWAY = float(' + LabStyle.EMBRYO_SWAY + ');\n' +
            'const float LE_RATE = float(' + LabStyle.CLONE_SWAY_RATE + ');\n' +
            'const float LE_FOOT = float(' + LabStyle.EMBRYO_FOOT + ');\n' +
            'const vec4 LE_SKIN = vec4(' + sk.join(', ') + ');\n' +
            'const vec4 LE_EYE = vec4(' + ey.join(', ') + ');\n' +
            'float labEmbryoIn( vec2 p, vec4 r ) {\n' +
            '  return step( r.x, p.x ) * step( p.x, r.z ) * step( r.y, p.y ) * step( p.y, r.w );\n' +
            '}\n' +
            StringTools.replace(shader.vertexShader, '#include <begin_vertex>',
              '#include <begin_vertex>\n' +
              '  {\n' +
              '  float on = max( labEmbryoIn( uv, LE_SKIN ), labEmbryoIn( uv, LE_EYE ) ) *\n' +
              '    smoothstep( LE_FOOT, LE_FOOT + 0.5, transformed.y );\n' +
              '  float ph = 0.0;\n' +
              '#ifdef USE_INSTANCING\n' +
              '  ph = 6.2831853 * fract( sin( dot( instanceMatrix[3].xz, vec2( 12.9898, 78.233 ) ) ) *\n' +
              '    43758.5453 );\n' +
              '#endif\n' +
              '  float t = labWaterTime * LE_RATE + ph;\n' +
              '  vec3 p = transformed;\n' +
              '  transformed += on * LE_SWAY * vec3( sin( t + p.y * 2.2 + p.x * 1.3 ),\n' +
              '    0.7 * sin( t * 0.45 + p.x * 2.0 ),\n' +
              '    0.6 * cos( t * 0.8 + p.y * 1.7 + p.x ) );\n' +
              '  }');
        };
      mat.customProgramCacheKey = function()
        return key() + '+labEmbryo';
      mat.needsUpdate = true;
    }
}
