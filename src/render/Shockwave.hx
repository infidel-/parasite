package render;

import three.Three;
import render.RenderConfig;
import render.particles.ScreamPulse3D;

// the silent-scream shockwave post pass and its per-frame driver: owns the ShaderPass (inserted
// before bloom by StreetView) and the live pulse list, projecting each wave front to screen
// space each frame and filling the shader's uniform slots. the pass is disabled outright when
// nothing screams (zero post cost). split out of StreetView, which only wires it up
class Shockwave {
  public var pass(default, null):ShaderPass;             // the screen-space ripple pass
  var camera:PerspectiveCamera;
  var screams:Array<ScreamPulse3D> = [];                 // live pulses driving the pass slots

  public function new(camera:PerspectiveCamera)
    {
      this.camera = camera;
      pass = build();
    }

// track a new scream pulse (its wave front drives one ripple slot until it dies)
  public function add(s:ScreamPulse3D):Void
    {
      screams.push(s);
    }

// build the shockwave pass: for each live pulse slot (uv center, ring radius in aspect-corrected
// uv, amplitude) pixels in a band around the expanding ring are displaced radially, warping the
// image under the wave front. slots with amplitude 0 are dead
  function build():ShaderPass
    {
      var n = RenderConfig.SCREAM.maxPulses;
      var p = new ShaderPass({
        uniforms: {
          tDiffuse: { value: null },
          aspect: { value: 1.0 },
          width: { value: RenderConfig.SCREAM.rippleWidth },
          cycles: { value: RenderConfig.SCREAM.rippleCycles },
          pulses: { value: [for (_ in 0...n * 4) 0.0] },
        },
        vertexShader: '
varying vec2 vUv;
void main() {
  vUv = uv;
  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}',
        fragmentShader: '
uniform sampler2D tDiffuse;
uniform float aspect;
uniform float width;
uniform float cycles;
uniform vec4 pulses[' + n + ']; // xy = uv center, z = ring radius (aspect-corrected uv), w = amplitude
varying vec2 vUv;
void main() {
  vec2 uv = vUv;
  for (int i = 0; i < ' + n + '; i++) {
    float amp = pulses[i].w;
    if (amp <= 0.0)
      continue;
    vec2 d = (vUv - pulses[i].xy) * vec2(aspect, 1.0);
    float dist = max(length(d), 1e-4);
    float diff = dist - pulses[i].z;
    float band = pulses[i].z * width + 1e-3;
    // water rings: concentric sine waves inside the band around the front, faded at the band
    // edges; as the front expands, diff sweeps and the rings visibly travel. amp is an ABSOLUTE
    // uv displacement (screen fraction) so the ripple stays visible at any ring size
    float m = 1.0 - smoothstep(0.0, band, abs(diff));
    float w = sin(diff / band * 6.28318 * cycles);
    uv -= (d / dist) * (w * m * amp) / vec2(aspect, 1.0);
  }
  gl_FragColor = texture2D(tDiffuse, uv);
}',
      });
      p.enabled = false;
      return p;
    }

// drive the pass from the live scream pulses: prune the dead, project each wave front to screen
// space (center + world-radius side points, in the shader's aspect-corrected uv metric) and fill
// the uniform slots. called once a frame by StreetView before the composer renders
  public function update():Void
    {
      var i = screams.length;
      while (i-- > 0)
        if (screams[i].done)
          screams.splice(i, 1);
      if (screams.length == 0)
        {
          pass.enabled = false;
          return;
        }
      var S = RenderConfig.SCREAM;
      pass.enabled = true;
      pass.uniforms.aspect.value = camera.aspect;
      var arr:Array<Float> = pass.uniforms.pulses.value;
      for (s in 0...S.maxPulses)
        arr[s * 4 + 3] = 0.0;
      var slot = 0;
      for (s in screams)
        {
          if (slot >= S.maxPulses)
            break;
          var c = new Vector3(s.cx, s.cy, s.cz).project(camera);
          // behind the camera: the projection flips, skip the ripple this frame
          if (c.z > 1)
            continue;
          var r = s.radius();
          // the ground ring is an ellipse on screen; take the wider of a world-x and a world-z
          // radius offset so the ripple band always covers the dome's leading edge
          var rx = uvDist(c, new Vector3(s.cx + r, s.cy, s.cz).project(camera));
          var rz = uvDist(c, new Vector3(s.cx, s.cy, s.cz + r).project(camera));
          arr[slot * 4] = (c.x + 1) / 2;
          arr[slot * 4 + 1] = (c.y + 1) / 2;
          arr[slot * 4 + 2] = Math.max(rx, rz);
          arr[slot * 4 + 3] = S.rippleAmp * s.strength();
          slot++;
        }
    }

// aspect-corrected uv-space distance between two projected NDC points (the shader's ring metric)
  function uvDist(a:Vector3, b:Vector3):Float
    {
      var dx = (b.x - a.x) / 2 * camera.aspect;
      var dy = (b.y - a.y) / 2;
      return Math.sqrt(dx * dx + dy * dy);
    }
}
