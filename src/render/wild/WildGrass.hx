package render.wild;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;
import render.Textures;
import render.wild.WildModel.Wild;

// the grass layer: cross-quad tufts, hash-placed per cell, merged per chunk block so a block is ONE
// draw call and render.Chunks drops whole blocks at once.
//
// the wind is a vertex-shader term folded into the material the tufts already draw with — the same
// trade render.world.PropShader and render.sewer.SewerMask make, and for the same reason: no extra
// pass, no extra geometry, no per-frame CPU work beyond advancing one shared clock. the phase and the
// height weight ride in on ONE vec2 attribute rather than being read off `uv`, because `uv` is only
// declared when the material happens to define USE_UV and this must not depend on that.
//
// alphaTest, never transparent: a transparent grass field would sort per mesh against the ground and
// against itself every frame, and at this density the cut is invisible anyway. DoubleSide is free
// here for the same reason — an alpha-tested opaque material draws DoubleSide in ONE pass, where a
// transparent one would draw it as two
class WildGrass
{
  static inline var CELL = CityConfig.CELL;

  // the clock every grass material references BY IDENTITY, in BASE_MS units — so writing .value
  // reaches every block at once (the uniform sharing render.world.PropShader.uTime uses)
  static var uTime = { value: 0.0 };

// advance the shared wind clock. called once per frame from WildArea.tick
  public static function tick(dtMs:Float):Void
    {
      uTime.value += dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
    }

// emit the grass, one merged mesh per chunk block
  public static function build(scene:Scene, m:Wild):Void
    {
      var B = render.Chunks.CELLS;
      var mat = material();
      var row = 0;
      while (row < m.h)
        {
          var col = 0;
          while (col < m.w)
            {
              block(scene, mat, m, col, row,
                (col + B <= m.w) ? B : m.w - col,
                (row + B <= m.h) ? B : m.h - row);
              col += B;
            }
          row += B;
        }
    }

// every tuft in one chunk block, merged into a single buffer
  static function block(scene:Scene, mat:MeshLambertMaterial, m:Wild, col0:Int, row0:Int, cw:Int, ch:Int):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var pos = [];
      var nor = [];
      var uv = [];
      var wind = [];
      var idx = [];
      for (dr in 0...ch)
        for (dc in 0...cw)
          {
            var col = col0 + dc;
            var row = row0 + dr;
            // a tree or a rock stands on its cell, and tufts pushing through its base read as grass
            // growing out of the trunk. the cell keeps its prop and loses its grass
            if (m.prop[row][col] >= 0)
              continue;
            // its own multipliers, mixed: must not correlate with the prop yaw/scale rolls
            var h = WildModel.mix((col * 19349663) ^ (row * 83492791));
            for (k in 0...WildStyle.TUFTS_PER_CELL)
              {
                h = WildModel.mix(h);
                // offsets inset from the cell edge, so a tuft never straddles into a neighbour that
                // decided it had a prop instead
                var px = (col + 0.15 + (h % 701) / 701.0 * 0.7) * CELL - half;
                var pz = (row + 0.15 + ((h >> 9) % 701) / 701.0 * 0.7) * CELL - half;
                var yaw = ((h >> 3) % 3600) / 3600.0 * Math.PI;
                var s = 1.0 + (((h >> 17) % 2001) / 1000.0 - 1.0) * WildStyle.TUFT_JITTER;
                tuft(pos, nor, uv, wind, idx, px, pz, yaw,
                  WildStyle.TUFT_W * s, WildStyle.TUFT_H * s, h);
              }
          }
      if (idx.length == 0)
        return;
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(pos, 3));
      geo.setAttribute('normal', new Float32BufferAttribute(nor, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(uv, 2));
      geo.setAttribute('aWind', new Float32BufferAttribute(wind, 2));
      geo.setIndex(idx);
      var mesh = new Mesh(geo, mat);
      // receives, never casts. a shadow-casting grass field would double the depth pass over hundreds
      // of thousands of alpha-tested triangles to produce a mat of noise nobody can read as a shadow
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }

// one tuft: two quads crossed at right angles about the vertical, base on the ground.
// the NORMALS point straight up rather than out of each quad's own face. that is not a shortcut: a
// vertical quad lit by its true normal goes black the moment it turns away from the moon, and a field
// of them flickers between bright and dark as the camera orbits. pointing them at the sky lights every
// tuft like the ground it grows out of, which is what a mass of thin blades actually does
  static function tuft(pos:Array<Float>, nor:Array<Float>, uv:Array<Float>, wind:Array<Float>,
    idx:Array<Int>, x:Float, z:Float, yaw:Float, w:Float, h:Float, hash:Int):Void
    {
      // one phase per TUFT, not per quad: its two blades are the same clump and lean together
      var phase = (hash % 6283) / 1000.0;
      for (q in 0...2)
        {
          var a = yaw + q * Math.PI / 2;
          var dx = Math.cos(a) * w / 2;
          var dz = Math.sin(a) * w / 2;
          var base = Std.int(pos.length / 3);
          // wound base-left, base-right, top-right, top-left; v is 0 at the ground and 1 at the tip
          inline function vtx(ox:Float, y:Float, oz:Float, u:Float, v:Float):Void
            {
              pos.push(x + ox);
              pos.push(y);
              pos.push(z + oz);
              nor.push(0.0);
              nor.push(1.0);
              nor.push(0.0);
              uv.push(u);
              uv.push(v);
              wind.push(phase);
              wind.push(v); // the height weight the wind offset scales by: nothing at the roots
            }
          vtx(-dx, 0.0, -dz, 0.0, 0.0);
          vtx(dx, 0.0, dz, 1.0, 0.0);
          vtx(dx, h, dz, 1.0, 1.0);
          vtx(-dx, h, -dz, 0.0, 1.0);
          idx.push(base);
          idx.push(base + 1);
          idx.push(base + 2);
          idx.push(base);
          idx.push(base + 2);
          idx.push(base + 3);
        }
    }

// the shared grass material, with the wind folded into its vertex shader
  static function material():MeshLambertMaterial
    {
      var mat = new MeshLambertMaterial({
        map: Textures.loadTexture(WildStyle.GRASS, 'facade', 1),
        side: THREE.DoubleSide,
        alphaTest: WildStyle.TUFT_ALPHA,
      });
      var mm:Dynamic = mat;
      mm.onBeforeCompile = function(shader:Dynamic)
        {
          shader.uniforms.wildWindT = uTime;
          shader.uniforms.wildWindAmp = { value: WildStyle.WIND_AMP };
          shader.uniforms.wildWindRate = { value: WildStyle.WIND_RATE };
          // the two axes run at 0.83 of each other and start on different phases, so a tuft traces a
          // small figure rather than sliding back and forth along one line
          shader.vertexShader = 'attribute vec2 aWind;\n' +
            'uniform float wildWindT;\n' +
            'uniform float wildWindAmp;\n' +
            'uniform float wildWindRate;\n' +
            StringTools.replace(shader.vertexShader, '#include <begin_vertex>',
              '#include <begin_vertex>\n' +
              '  {\n' +
              '  float wildT = wildWindT * wildWindRate;\n' +
              '  transformed.x += wildWindAmp * aWind.y * sin( wildT + aWind.x );\n' +
              '  transformed.z += wildWindAmp * aWind.y * 0.6 * sin( wildT * 0.83 + aWind.x * 1.7 + 1.3 );\n' +
              '  }');
        };
      // three keys its program cache on base material params and NOT on onBeforeCompile, so without a
      // key of our own a moving grass program could be handed to an identical still material
      mm.customProgramCacheKey = function() return 'wildGrass';
      return mat;
    }
}
