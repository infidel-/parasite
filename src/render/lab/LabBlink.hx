package render.lab;

import render.RenderConfig;
import render.world.PropShader.ShaderPatch;

// the machines' painted indicator lamps, blinking where the art put them. models-src/lab/_ledmask.py
// finds the lamps on each machine's emissive map (small compact lit blobs on black, clear of every
// screen and fluid) and writes a CODE into the map's alpha: 255 is not a lamp, 250 a lamp burning
// steady, 16..239 a lamp blinking and the code its phase. Every lamp burns BLINK_GAIN over its paint
// (painted at the sheet's value, a lamp the size of a screw head is lost at the game camera), and a
// blinking one is multiplied by a square wave off its code — one of two rates and its own duty, both
// hashed off it — offset by a hash of the instance's place, so two of one machine never blink in step.
// A map with no alpha reads 1 and burns as it always did, so every lab piece takes the patch and only
// the lamps move.
// The clock is LabWater's shape (BASE_MS turns of ANIM_SPEED); the rates and depth are consts of the
// one program
class LabBlink
{
  static var uTime = { value: 0.0 };

// run the clock
  public static function tick(dtMs:Float):Void
    {
      uTime.value += dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
    }

// fold the blink into a piece's material. `mat` is Dynamic for the reason PropShader.patch gives: the
// material externs declare no onBeforeCompile / customProgramCacheKey
  public static function patch(mat:Dynamic):Void
    {
      mat.onBeforeCompile = function(shader:ShaderPatch, renderer:Dynamic)
        {
          shader.uniforms.labBlinkTime = uTime;
          shader.vertexShader = 'varying float vLabBlink;\n' +
            StringTools.replace(shader.vertexShader, '#include <begin_vertex>',
              '#include <begin_vertex>\n' +
              '  vLabBlink = 0.0;\n' +
              '#ifdef USE_INSTANCING\n' +
              '  vLabBlink = fract( sin( dot( instanceMatrix[3].xz, vec2( 12.9898, 78.233 ) ) ) *\n' +
              '    43758.5453 );\n' +
              '#endif');
          shader.fragmentShader = 'uniform float labBlinkTime;\n' +
            'varying float vLabBlink;\n' +
            // through float(): Haxe prints a whole Float as an int
            'const float LB_SLOW = float(' + LabStyle.BLINK_SLOW + ');\n' +
            'const float LB_FAST = float(' + LabStyle.BLINK_FAST + ');\n' +
            'const float LB_DEPTH = float(' + LabStyle.BLINK_DEPTH + ');\n' +
            'const float LB_GAIN = float(' + LabStyle.BLINK_GAIN + ');\n' +
            StringTools.replace(shader.fragmentShader, '#include <emissivemap_fragment>',
              '#include <emissivemap_fragment>\n' +
              '#ifdef USE_EMISSIVEMAP\n' +
              '  {\n' +
              '  float a = emissiveColor.a;\n' +
              '  float rate = mix( LB_SLOW, LB_FAST, step( 0.5, fract( a * 5.31 ) ) );\n' +
              '  float duty = 0.3 + 0.4 * fract( a * 11.7 );\n' +
              '  float on = step( duty, fract( labBlinkTime * rate + a * 17.0 + vLabBlink ) );\n' +
              '  float lamp = 1.0 - step( 0.99, a );\n' +
              '  float blink = 1.0 - step( 0.96, a );\n' +
              '  totalEmissiveRadiance *= mix( 1.0, LB_GAIN, lamp ) *\n' +
              '    mix( 1.0, 1.0 - LB_DEPTH * ( 1.0 - on ), blink );\n' +
              '  }\n' +
              '#endif');
        };
      // three keys programs on base params, not on the hook: its own key keeps this program apart
      // from every un-patched Lambert prop. VisionMask.patch chains this key into its own
      mat.customProgramCacheKey = function()
        return 'labBlink';
      mat.needsUpdate = true;
    }
}
