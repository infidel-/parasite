// WebGL menu background - replaces SVG feTurbulence + CSS animation
// Renders distorted/swirly background image with slow organic movement

package ui;

import js.Browser;
import js.html.CanvasElement;
import js.html.webgl.RenderingContext;
import js.html.webgl.Program;
import js.html.webgl.Shader;
import js.html.webgl.Buffer;
import js.html.webgl.Texture;
import js.html.webgl.UniformLocation;

@:expose
class MenuBackground
{
  var canvas: CanvasElement;
  var gl: RenderingContext;
  var program: Program;
  var vertexBuffer: Buffer;
  var texture: Texture;
  var uTime: UniformLocation;
  var uResolution: UniformLocation;
  var uTexture: UniformLocation;
  var uTexAspect: UniformLocation;
  var startTime: Float;
  var animFrameId: Int;
  var running: Bool;
  var textureLoaded: Bool;
  var visible: Bool;
  var texAspect: Float;
  var parentEl: js.html.Element;

  static var VERTEX_SHADER = '
    attribute vec2 a_position;
    varying vec2 v_uv;
    void main() {
      v_uv = a_position * 0.5 + 0.5;
      v_uv.y = 1.0 - v_uv.y;
      gl_Position = vec4(a_position, 0.0, 1.0);
    }
  ';

  static var FRAGMENT_SHADER = '
    precision mediump float;
    varying vec2 v_uv;
    uniform sampler2D u_texture;
    uniform float u_time;
    uniform vec2 u_resolution;
    uniform float u_texAspect;

    // simplex-style noise hash
    vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
    vec2 mod289v2(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
    vec3 permute(vec3 x) { return mod289(((x * 34.0) + 1.0) * x); }

    float snoise(vec2 v) {
      const vec4 C = vec4(0.211324865405187, 0.366025403784439,
                         -0.577350269189626, 0.024390243902439);
      vec2 i = floor(v + dot(v, C.yy));
      vec2 x0 = v - i + dot(i, C.xx);
      vec2 i1;
      i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
      vec4 x12 = x0.xyxy + C.xxzz;
      x12.xy -= i1;
      i = mod289v2(i);
      vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0))
                                   + i.x + vec3(0.0, i1.x, 1.0));
      vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy),
                               dot(x12.zw, x12.zw)), 0.0);
      m = m * m;
      m = m * m;
      vec3 x = 2.0 * fract(p * C.www) - 1.0;
      vec3 h = abs(x) - 0.5;
      vec3 ox = floor(x + 0.5);
      vec3 a0 = x - ox;
      m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
      vec3 g;
      g.x = a0.x * x0.x + h.x * x0.y;
      g.yz = a0.yz * x12.xz + h.yz * x12.yw;
      return 130.0 * dot(m, g);
    }

    void main() {
      // aspect-correct "cover" UV mapping
      float screenAspect = u_resolution.x / u_resolution.y;
      vec2 uv = v_uv;
      if (u_texAspect > screenAspect) {
        // image wider than screen: fit height, crop width
        float scale = screenAspect / u_texAspect;
        uv.x = uv.x * scale + (1.0 - scale) * 0.5;
      } else {
        // image taller than screen: fit width, crop height
        float scale = u_texAspect / screenAspect;
        uv.y = uv.y * scale + (1.0 - scale) * 0.5;
      }

      // replicate original CSS background-animation (200s infinite alternate)
      // 0%:   scale(1.0)
      // 50%:  scale(1.2) translate(1%, 0%)
      // 100%: scale(1.1) translate(1%, 1%)
      // alternates: 90s forward, 90s back = 180s cycle
      float cycle = 180.0;
      float phase = mod(u_time, cycle) / 90.0; // 0 to 2
      if (phase > 1.0) phase = 2.0 - phase;     // triangle wave 0->1->0

      // horizontal pan: left to right and back
      float panAmount = 0.08;
      float panX = mix(-panAmount, panAmount, phase);
      uv.x += panX;

      // static swirls (~200px features)
      vec2 noiseCoord = v_uv * u_resolution * 0.005;
      float nx = snoise(noiseCoord);
      float ny = snoise(noiseCoord + 100.0);
      vec2 staticDisp = vec2(nx, ny) * (10.0 / u_resolution);

      // slow drifting swirls (larger, slowly evolving)
      float timeAnim = u_time * 0.05;
      float dx = snoise(vec2(noiseCoord.x * 0.3 + timeAnim, noiseCoord.y * 0.3));
      float dy = snoise(vec2(noiseCoord.x * 0.3, noiseCoord.y * 0.3 + timeAnim + 100.0));
      vec2 driftDisp = vec2(dx, dy) * (8.0 / u_resolution);

      uv += staticDisp + driftDisp;

      uv = clamp(uv, 0.0, 1.0);
      vec4 color = texture2D(u_texture, uv);

      // color grading: brightness(80%) saturate(90%)
      color.rgb *= 0.8;
      float gray = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
      color.rgb = mix(vec3(gray), color.rgb, 0.9);

      gl_FragColor = color;
    }
  ';

  public function new()
    {
      canvas = Browser.document.createCanvasElement();
      canvas.className = 'menu-bg-canvas';
      running = false;
      textureLoaded = false;
      visible = false;
      animFrameId = 0;
      texAspect = 1.0;

      gl = cast canvas.getContext('webgl', {
        alpha: false,
        antialias: false,
        depth: false,
        stencil: false,
        preserveDrawingBuffer: false,
      });

      if (gl == null)
        return;

      initShaders();
      initGeometry();
      texture = gl.createTexture();
      startTime = js.lib.Date.now();
    }

  function initShaders()
    {
      var vs = compileShader(RenderingContext.VERTEX_SHADER, VERTEX_SHADER);
      var fs = compileShader(RenderingContext.FRAGMENT_SHADER, FRAGMENT_SHADER);
      if (vs == null || fs == null)
        return;

      program = gl.createProgram();
      gl.attachShader(program, vs);
      gl.attachShader(program, fs);
      gl.linkProgram(program);

      if (!gl.getProgramParameter(program, RenderingContext.LINK_STATUS))
        {
          trace('MenuBackground: shader link error: ' + gl.getProgramInfoLog(program));
          return;
        }

      gl.useProgram(program);
      uTime = gl.getUniformLocation(program, 'u_time');
      uResolution = gl.getUniformLocation(program, 'u_resolution');
      uTexture = gl.getUniformLocation(program, 'u_texture');
      uTexAspect = gl.getUniformLocation(program, 'u_texAspect');
    }

  function compileShader(type: Int, source: String): Shader
    {
      var shader = gl.createShader(type);
      gl.shaderSource(shader, source);
      gl.compileShader(shader);
      if (!gl.getShaderParameter(shader, RenderingContext.COMPILE_STATUS))
        {
          trace('MenuBackground: shader compile error: ' + gl.getShaderInfoLog(shader));
          gl.deleteShader(shader);
          return null;
        }
      return shader;
    }

  function initGeometry()
    {
      // fullscreen quad (two triangles)
      var vertices: Array<Float> = [
        -1, -1,
         1, -1,
        -1,  1,
        -1,  1,
         1, -1,
         1,  1,
      ];
      vertexBuffer = gl.createBuffer();
      gl.bindBuffer(RenderingContext.ARRAY_BUFFER, vertexBuffer);
      gl.bufferData(RenderingContext.ARRAY_BUFFER,
        new js.lib.Float32Array(vertices),
        RenderingContext.STATIC_DRAW);

      var aPos = gl.getAttribLocation(program, 'a_position');
      gl.enableVertexAttribArray(aPos);
      gl.vertexAttribPointer(aPos, 2, RenderingContext.FLOAT, false, 0, 0);
    }

// load background image from URL and upload as texture
  public function setBackground(url: String)
    {
      if (gl == null)
        return;

      // strip css url() wrapper if present
      var imgUrl = url;
      if (StringTools.startsWith(imgUrl, 'url('))
        imgUrl = imgUrl.substring(4, imgUrl.length - 1);

      // strip quotes
      imgUrl = StringTools.replace(imgUrl, "'", "");
      imgUrl = StringTools.replace(imgUrl, '"', '');

      textureLoaded = false;
      var img = Browser.document.createImageElement();
      img.crossOrigin = 'anonymous';
      img.onload = function() {
        if (gl == null)
          return;
        texAspect = img.naturalWidth / img.naturalHeight;
        gl.bindTexture(RenderingContext.TEXTURE_2D, texture);
        gl.texImage2D(RenderingContext.TEXTURE_2D, 0,
          RenderingContext.RGBA, RenderingContext.RGBA,
          RenderingContext.UNSIGNED_BYTE, img);
        gl.texParameteri(RenderingContext.TEXTURE_2D,
          RenderingContext.TEXTURE_WRAP_S, RenderingContext.CLAMP_TO_EDGE);
        gl.texParameteri(RenderingContext.TEXTURE_2D,
          RenderingContext.TEXTURE_WRAP_T, RenderingContext.CLAMP_TO_EDGE);
        gl.texParameteri(RenderingContext.TEXTURE_2D,
          RenderingContext.TEXTURE_MIN_FILTER, RenderingContext.LINEAR);
        gl.texParameteri(RenderingContext.TEXTURE_2D,
          RenderingContext.TEXTURE_MAG_FILTER, RenderingContext.LINEAR);
        textureLoaded = true;
      };
      img.src = imgUrl;
    }

// get the canvas element for DOM insertion
  public function getCanvas(): CanvasElement
    {
      return canvas;
    }

// start render loop and insert canvas into DOM
  public function show()
    {
      if (gl == null)
        return;
      visible = true;
      // re-insert canvas into DOM if removed
      if (canvas.parentElement == null && parentEl != null)
        parentEl.insertBefore(canvas, parentEl.firstChild);
      canvas.style.display = 'block';
      updateSize();
      if (!running)
        {
          running = true;
          render(0);
        }
    }

// stop render loop and remove canvas from DOM
  public function hide()
    {
      visible = false;
      running = false;
      if (animFrameId != 0)
        {
          Browser.window.cancelAnimationFrame(animFrameId);
          animFrameId = 0;
        }
      // remove from DOM to fully release GPU resources
      if (canvas.parentElement != null)
        {
          parentEl = canvas.parentElement;
          canvas.remove();
        }
    }

// update canvas size to match window
  function updateSize()
    {
      var w = Browser.window.innerWidth;
      var h = Browser.window.innerHeight;
      if (canvas.width != w || canvas.height != h)
        {
          canvas.width = w;
          canvas.height = h;
          if (gl != null)
            gl.viewport(0, 0, w, h);
        }
    }

// main render callback
  function render(timestamp: Float)
    {
      if (!running)
        {
          animFrameId = 0;
          return;
        }

      if (gl == null)
        return;

      // stop loop if canvas was removed from DOM (menu closed)
      if (canvas.parentElement == null)
        {
          running = false;
          animFrameId = 0;
          return;
        }

      // stop loop if parent element is hidden (menu closed with animation)
      if (canvas.parentElement.style.visibility == 'hidden')
        {
          running = false;
          animFrameId = 0;
          return;
        }

      updateSize();

      if (textureLoaded && program != null)
        {
          gl.useProgram(program);
          var elapsed = (js.lib.Date.now() - startTime) / 1000.0;
          gl.uniform1f(uTime, elapsed);
          gl.uniform2f(uResolution, canvas.width, canvas.height);
          gl.uniform1f(uTexAspect, texAspect);
          gl.activeTexture(RenderingContext.TEXTURE0);
          gl.bindTexture(RenderingContext.TEXTURE_2D, texture);
          gl.uniform1i(uTexture, 0);
          gl.drawArrays(RenderingContext.TRIANGLES, 0, 6);
        }

      // reschedule only if still running
      if (running)
        animFrameId = Browser.window.requestAnimationFrame(render);
    }

// clean up
  public function dispose()
    {
      hide();
      if (gl != null)
        {
          if (texture != null)
            gl.deleteTexture(texture);
          if (vertexBuffer != null)
            gl.deleteBuffer(vertexBuffer);
          if (program != null)
            gl.deleteProgram(program);
        }
      if (canvas.parentElement != null)
        canvas.parentElement.removeChild(canvas);
    }
}
