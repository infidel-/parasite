package render;

import three.Three;

// THE FAR CITY GOES SOFT: one full-screen quad with a blur shader in the composer, masked by the
// street's own alpha channel.
//
// WHY A PASS AND NOT A MIP BIAS. The third defect pass reasoned its way to a texture LOD bias
// folded into the street's materials, on the grounds that a fragment shader cannot blur what is
// behind it. That is true of a WORLD-space quad and false of a SCREEN-space one: the composer has
// already copied the frame into a render target by the time a pass runs, so a pass has the frame
// as a texture and can do whatever it likes with it. The bias measured −1% of high-frequency
// energy at 110-230 units (docs/3d-changes.md) because a minified texture has almost no detail
// left to lose and most of what still reads as structure out there is GEOMETRY — roof edges,
// parapets, the lit-pane grid — which no map bias can touch. A screen-space blur touches all of it.
//
// AND THE MASK IS THE ALPHA CHANNEL, WHICH COSTS NOTHING. A depth-masked blur is the textbook
// version and it wants a DepthTexture on the composer's targets, which are multisampled and are
// rebuilt by View.setAA whenever the AA setting changes. The cheaper route is that an OPAQUE
// material's alpha output is dead data — nothing downstream reads it — so render.corp.CorpStreet
// writes `1 - farness` there and this pass reads it back. Everything that does NOT write it (the
// office, the sky, every other area kind) comes out at alpha 1, i.e. mask 0, i.e. untouched, which
// is why the pass is safe to leave in the chain.
//
// IT SITS BEFORE GTAO, because GTAOPass composites its own opaque quad and would overwrite the
// alpha the mask lives in.
//
// EACH TAP IS WEIGHTED BY ITS OWN MASK, the standard depth-of-field guard: without it a sharp
// foreground (the parapet, a window mullion) bleeds into the soft background behind it and the
// tower grows a halo.
class StreetBlur
{
  // how far the kernel reaches at full blur, in pixels at 1080p — scaled by the real height so the
  // softening is the same fraction of the frame at any resolution
  static inline var RADIUS_PX = 5.0;
  // taps per axis of the (separable-looking but single-pass) 3x3 ring, at two radii
  public var pass(default, null):ShaderPass;

  public function new()
    {
      pass = build();
      pass.enabled = false;
    }

// size the kernel to the backbuffer, so the blur is resolution independent
  public function resize(w:Int, h:Int):Void
    {
      var u:Dynamic = pass.uniforms;
      u.texel.value.set(1.0 / w, 1.0 / h);
      u.radius.value = RADIUS_PX * (h / 1080.0);
    }

  function build():ShaderPass
    {
      return new ShaderPass({
        uniforms: {
          tDiffuse: { value: null },
          texel: { value: new Vector2(1.0 / 1920.0, 1.0 / 1080.0) },
          radius: { value: RADIUS_PX },
        },
        vertexShader: '
varying vec2 vUv;
void main() {
  vUv = uv;
  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}',
        fragmentShader: '
uniform sampler2D tDiffuse;
uniform vec2 texel;
uniform float radius;
varying vec2 vUv;
// the 12 offsets of two rings, in units of the kernel radius. two rings rather than one because a
// single ring at this reach reads as a ghost rather than as softness
const vec2 K[12] = vec2[12](
  vec2( 1.0, 0.0), vec2(-1.0, 0.0), vec2( 0.0, 1.0), vec2( 0.0,-1.0),
  vec2( 0.7, 0.7), vec2(-0.7, 0.7), vec2( 0.7,-0.7), vec2(-0.7,-0.7),
  vec2( 2.0, 0.6), vec2(-2.0,-0.6), vec2( 0.6,-2.0), vec2(-0.6, 2.0));
void main() {
  vec4 c = texture2D(tDiffuse, vUv);
  float m = 1.0 - c.a;
  if (m <= 0.002)
    {
      gl_FragColor = vec4(c.rgb, 1.0);
      return;
    }
  vec3 sum = c.rgb;
  float wsum = 1.0;
  for (int i = 0; i < 12; i++)
    {
      vec2 uv = vUv + K[i] * radius * m * texel;
      vec4 s = texture2D(tDiffuse, uv);
      // weight by the TAP\'s own mask, so nothing sharp in front bleeds into what is behind it.
      // CLAMPED, and the clamp is load-bearing: alpha is dead data only for the draws that leave
      // it at 1, and an ADDITIVE one accumulates it (src ONE + dst ONE), so a stack of glow quads
      // reads back 2 or 3. Unclamped that is a NEGATIVE weight, wsum can pass through zero, and
      // the single NaN texel it divides out is smeared over half the frame by the bloom that
      // follows -- one black frame. max() makes wsum >= 1 by construction
      float w = max(0.0, 1.0 - s.a);
      sum += s.rgb * w;
      wsum += w;
    }
  gl_FragColor = vec4(mix(c.rgb, sum / wsum, m), 1.0);
}',
      });
    }
}
