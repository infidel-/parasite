package render.lab;

import three.Three;
import render.RenderConfig;
import render.world.PropShader.ShaderPatch;

// the amber tanks' fluid, painted on their glass: the shell stays the see-through 0.3 pane
// render.lab.LabInterior.glass makes it, and this folds into it, in the piece's OWN frame (so every
// tank ripples alike whatever its turn), a lit fluid seen through the pane —
//   ripple — two crossed sine bands crawling up the pane, the slow light play of a lit liquid
//   bubbles — pale specks, columns a WATER_COL apart, each with its own hashed rise and phase, a bubble in some
//            cells of each as they climb, wobbling as they go, below the fluid's top (WATER_TOP)
// both go into the emissive, at WATER_TINT times `level` (render.lab.LabArea dims it as the lab
// dies), and lift the pane's alpha where they burn so a bubble reads solid. The clock is
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
            StringTools.replace(shader.vertexShader, '#include <begin_vertex>',
              '#include <begin_vertex>\n' +
              '  vLabWater = transformed;');
          shader.fragmentShader = 'uniform float labWaterTime;\n' +
            'uniform float labWaterLevel;\n' +
            'uniform vec3 labWaterTint;\n' +
            'varying vec3 vLabWater;\n' +
            // the rates and sizes as consts, through float(): Haxe prints a whole Float as an int
            'const float LW_RATE = float(' + LabStyle.WATER_RATE + ');\n' +
            'const float LW_COL = float(' + LabStyle.WATER_COL + ');\n' +
            'const float LW_CELL = float(' + LabStyle.WATER_CELL + ');\n' +
            'const float LW_RISE = float(' + LabStyle.WATER_RISE + ');\n' +
            'const float LW_BUBBLE = float(' + LabStyle.WATER_BUBBLE + ');\n' +
            'const float LW_TOP = float(' + LabStyle.WATER_TOP + ');\n' +
            'float labWaterHash( float n ) { return fract( sin( n * 12.9898 ) * 43758.5453 ); }\n' +
            StringTools.replace(shader.fragmentShader, '#include <emissivemap_fragment>',
              '#include <emissivemap_fragment>\n' +
              '  {\n' +
              // across the pane whichever face it is (x on the front, z on the ends), and up it
              '  vec2 q = vec2( vLabWater.x + vLabWater.z, vLabWater.y );\n' +
              '  float t = labWaterTime;\n' +
              '  float rip = 0.6 * smoothstep( 0.55, 1.0,\n' +
              '    sin( q.y * 6.0 - t * LW_RATE + sin( q.x * 2.3 + t * 0.05 ) * 1.4 ) ) +\n' +
              '    0.4 * smoothstep( 0.7, 1.0, sin( q.x * 5.1 + q.y * 3.0 + t * 0.08 ) );\n' +
              '  float c = floor( q.x / LW_COL );\n' +
              '  float h = labWaterHash( c );\n' +
              '  float v = q.y / LW_CELL - t * LW_RISE * ( 0.6 + 0.8 * h ) - h * 7.0;\n' +
              '  float k = floor( v );\n' +
              '  float on = step( 0.55, labWaterHash( k * 3.1 + c * 17.0 ) );\n' +
              '  float bx = ( 0.5 + 0.3 * sin( t * 0.3 + h * 20.0 + k ) ) * LW_COL;\n' +
              '  vec2 d = vec2( q.x - c * LW_COL - bx, ( fract( v ) - 0.5 ) * LW_CELL );\n' +
              '  float r = LW_BUBBLE * ( 0.6 + 0.8 * labWaterHash( k + c ) );\n' +
              '  float bub = on * smoothstep( r, r * 0.6, length( d ) ) *\n' +
              '    step( q.y, LW_TOP );\n' +
              // a bubble burns PALER than the fluid, or it is lost on the bright amber behind the pane
              '  totalEmissiveRadiance += labWaterLevel * ( labWaterTint * ( 0.3 + 0.7 * rip ) +\n' +
              '    vec3( 0.75, 0.62, 0.4 ) * bub );\n' +
              '  diffuseColor.a = min( 1.0, diffuseColor.a + 0.12 * rip + 0.6 * bub );\n' +
              '  }');
        };
      // three keys programs on base params, not on the hook: its own key keeps this program off
      // every other glass shell. VisionMask.patch chains this key into its own
      mat.customProgramCacheKey = function()
        return 'labWater';
      mat.needsUpdate = true;
    }
}
