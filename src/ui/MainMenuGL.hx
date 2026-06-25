// unified WebGL main-menu scene: swirl background (graded) + alley environment
// (walls, night skyline, sodium lamps, swirling floor fog) + crowd-of-shadows
// with a trail-accumulation FBO + face-jumping parasite + drifting spores.
// replaces the separate MainMenuBackground (bg) + MainMenuCrowd (2D canvas).

package ui;

import js.Browser;
import js.html.CanvasElement;
import js.html.Image;
import js.html.webgl.RenderingContext;
import js.html.webgl.Program;
import js.html.webgl.Shader;
import js.html.webgl.Buffer;
import js.html.webgl.Texture;
import js.html.webgl.Framebuffer;
import mods.AssetPath;

private typedef _Member = {
  id: Int,
  srcX: Int,
  srcW: Int,
  worldX: Float,
  worldZ: Float,
  dir: Int,
  stepsLeft: Int,
  stepPhase: Float,
  stepSpeed: Float,
  stepDist: Float,
  pauseLeft: Float,
  hopAmp: Float,
  forwardSpeed: Float,
};

private typedef _Mote = { x: Float, size: Float, life: Float, age: Float };

private typedef _Lamp = {
  worldZ: Float, side: Int, cyan: Bool, h: Float, phase: Float, ph2: Float
};

// transient per-frame lamp draw data (head/pool positions + flicker inputs)
private typedef _LampDraw = {
  headX: Float, headY: Float, groundY: Float, scale: Float, fade: Float,
  phase: Float, ph2: Float, col: Array<Float>
};

@:expose
class MainMenuGL
{
  // ---- crowd / camera constants ----
  static inline var CELL_H = 192;
  static var CELL_WIDTHS = [80, 80, 80, 80, 80, 80, 80, 160];
  static inline var MEMBER_COUNT = 40;
  static inline var TARGET_FPS = 30;
  static inline var FRAME_INTERVAL = 1000.0 / 30.0;
  static inline var RES_SCALE = 0.65;
  static inline var FOCAL = 600.0;
  static inline var CAM_HEIGHT = 220.0;
  static inline var NEAR_Z = 60.0;
  static inline var FAR_Z = 700.0;
  static inline var FADE_RANGE = 200.0;
  static inline var CAM_FORWARD_SPEED = 4.0;
  static inline var MEMBER_FORWARD_SPEED = 16.0;
  static inline var SPRITE_WORLD_HEIGHT = 220.0;
  static inline var BASE_ALPHA = 0.1;
  static inline var TRAIL_KEEP = 0.95;
  // ---- parasite ----
  static inline var PARASITE_SIT_MIN = 3.0;
  static inline var PARASITE_SIT_MAX = 5.0;
  static inline var PARASITE_JUMP_DUR = 0.75;
  static inline var PARASITE_HEAD_RATIO = 0.11;
  static inline var PARASITE_WORLD_W = 80.0;
  static inline var PARASITE_NATIVE_W = 80.0;
  static inline var PARASITE_NATIVE_H = 60.0;
  static inline var WIDE_CELL_W = 160;
  static inline var WAIT = 0;
  static inline var RIDE = 1;
  static inline var JUMP = 2;
  // ---- tints (0..1) ----
  static var TINT_FAR = [0x16 / 255.0, 0x0e / 255.0, 0x26 / 255.0];
  static var TINT_NEAR = [0x4a / 255.0, 0x3a / 255.0, 0x66 / 255.0];
  static var PARASITE_TINT = [0xb4 / 255.0, 0x8f / 255.0, 0xd6 / 255.0];
  static var GLOW_TINT = [180 / 255.0, 143 / 255.0, 214 / 255.0];
  static var MOTE_TINT = [201 / 255.0, 168 / 255.0, 239 / 255.0];
  // ---- environment ----
  static var FOG = [0.10, 0.06, 0.18];
  static inline var WALL_X = 300.0;
  static inline var WALL_TOP = 600.0;
  static inline var WALL_DZ0 = 90.0;
  static inline var WALL_DZ1 = 700.0;
  static inline var WALL_SEGS = 8;
  static var WALL_COL_TOP = [0.11, 0.12, 0.15];
  static var WALL_COL_BOT = [0.055, 0.05, 0.085];
  static inline var SKY_DZ = 1400.0;
  static inline var SKY_SPREAD = 1800.0;
  static var SKY_COL = [0.05, 0.045, 0.09];
  static var SKY_RIM = [0.13, 0.18, 0.21];
  static inline var SKY_VEIL = 0.6;
  static inline var GROUND_G = 1000.0;
  static inline var GROUND_SEGS = 10;
  static var GROUND_COL = [0.01, 0.008, 0.018];
  static inline var LAMP_X = 470.0;
  static inline var LAMP_POLE_H = 300.0;
  static inline var LAMP_POLE_W = 9.0;
  static inline var LAMP_ARM = 78.0;
  static inline var LAMP_COUNT = 6;
  static var LAMP_SODIUM = [1.0, 0.6, 0.26];
  static var LAMP_CYAN = [0.42, 0.85, 0.78];
  static var LAMP_POLE_COL = [0.17, 0.17, 0.21];
  static var FOG_TINT = [0.3, 0.28, 0.37];
  static inline var FOG_STRENGTH = 0.18;
  static inline var FOG_TOP = 0.05;

  static var nextID = 0;

  var canvas: CanvasElement;
  var gl: RenderingContext;
  var running: Bool;
  var animId: Int;
  var lastFrame: Float;
  var startTime: Float;
  var elapsed: Float;
  var camZ: Float;
  var texAspect: Float;
  var bgEnabled: Bool;
  var parentEl: js.html.Element;

  // programs
  var bgProg: Program;
  var blitProg: Program;
  var spriteProg: Program;
  var envProg: Program;
  var fogProg: Program;
  var ok: Bool;

  // uniform/attrib locations (anon structs keyed by name)
  var bgLoc: Dynamic; // GL location bag, names match shader source — typed bag not worth it
  var blitLoc: Dynamic;
  var spriteLoc: Dynamic;
  var envLoc: Dynamic;
  var fogLoc: Dynamic;

  // buffers
  var quadFull: Buffer;
  var quadUnit: Buffer;
  var wallBuf: Buffer; var wallN: Int;
  var skyBuf: Buffer; var skyN: Int;
  var winBuf: Buffer; var winN: Int;
  var gndBuf: Buffer; var gndN: Int;
  var vigBuf: Buffer; var vigN: Int;
  var fogBuf: Buffer;
  var blackBuf: Buffer;

  // textures
  var bgTex: Texture; var bgReady: Bool;
  var atlasTex: Texture; var atlasReady: Bool; var atlasW: Int; var atlasH: Int;
  var parasiteTex: Texture; var parasiteReady: Bool;
  var glowTex: Texture;
  var softTex: Texture;
  var whiteTex: Texture;

  // trail accumulation FBO ping-pong
  var accum: Array<Framebuffer>;
  var accumTex: Array<Texture>;
  var fboW: Int; var fboH: Int; var cur: Int;

  // crowd + parasite state
  var members: Array<_Member>;
  var spritePool: Array<{ srcX: Int, srcW: Int }>;
  var parasiteState: Int;
  var parasiteTargetID: Int;
  var parasiteSitTimer: Float;
  var parasiteJumpT: Float;
  var parasiteFromX: Float;
  var parasiteFromY: Float;
  var parasiteFromScale: Float;
  var parasiteRenderX: Float;
  var parasiteRenderY: Float;
  var parasiteRenderScale: Float;
  var pGlow: { x: Float, y: Float, w: Float, h: Float, fade: Float };

  // spores + lamps
  var motes: Array<_Mote>;
  var lamps: Array<_Lamp>;
  var lampDraw: Array<_LampDraw>;

  public function new()
    {
      canvas = Browser.document.createCanvasElement();
      canvas.className = 'menu-bg-canvas';
      running = false;
      animId = 0;
      lastFrame = 0;
      startTime = Browser.window.performance.now();
      elapsed = 0;
      camZ = 0;
      texAspect = 3;
      bgEnabled = true;
      ok = false;
      atlasReady = false; parasiteReady = false; bgReady = false;
      atlasW = 720; atlasH = 192;
      fboW = 0; fboH = 0; cur = 0;
      members = [];
      spritePool = [];
      parasiteState = WAIT;
      parasiteTargetID = -1;
      parasiteRenderX = 0; parasiteRenderY = 0; parasiteRenderScale = 1;
      pGlow = null;

      gl = cast canvas.getContext('webgl', {
        alpha: false, antialias: false, depth: false,
        stencil: false, preserveDrawingBuffer: false,
      });
      if (gl == null)
        return;

      initGL();
      if (!ok)
        return;
      initTextures();
      initMotes();
      buildEnv();
      initLamps();
      initFog();
    }

// expose canvas for DOM insertion
  public function getCanvas(): CanvasElement
    return canvas;

// did the GL context + all programs come up?
  public function isOk(): Bool
    return ok;

  // =========================================================================
  // GL plumbing
  // =========================================================================
  function compile(type: Int, src: String): Shader
    {
      var s = gl.createShader(type);
      gl.shaderSource(s, src);
      gl.compileShader(s);
      if (!gl.getShaderParameter(s, RenderingContext.COMPILE_STATUS))
        {
          trace('MainMenuGL compile: ' + gl.getShaderInfoLog(s));
          return null;
        }
      return s;
    }

  function makeProgram(vs: String, fs: String): Program
    {
      var v = compile(RenderingContext.VERTEX_SHADER, vs);
      var f = compile(RenderingContext.FRAGMENT_SHADER, fs);
      if (v == null || f == null)
        return null;
      var p = gl.createProgram();
      gl.attachShader(p, v);
      gl.attachShader(p, f);
      gl.linkProgram(p);
      if (!gl.getProgramParameter(p, RenderingContext.LINK_STATUS))
        {
          trace('MainMenuGL link: ' + gl.getProgramInfoLog(p));
          return null;
        }
      return p;
    }

  function initGL()
    {
      bgProg = makeProgram(BG_VS, BG_FS);
      blitProg = makeProgram(BLIT_VS, BLIT_FS);
      spriteProg = makeProgram(SPRITE_VS, SPRITE_FS);
      envProg = makeProgram(ENV_VS, ENV_FS);
      fogProg = makeProgram(FOG_VS, FOG_FS); // optional, null-checked in drawFog
      ok = (gl != null
        && bgProg != null
        && spriteProg != null
        && blitProg != null
        && envProg != null);
      if (!ok)
        return;

      quadFull = gl.createBuffer();
      gl.bindBuffer(RenderingContext.ARRAY_BUFFER, quadFull);
      gl.bufferData(RenderingContext.ARRAY_BUFFER,
        new js.lib.Float32Array([-1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, 1]),
        RenderingContext.STATIC_DRAW);
      quadUnit = gl.createBuffer();
      gl.bindBuffer(RenderingContext.ARRAY_BUFFER, quadUnit);
      gl.bufferData(RenderingContext.ARRAY_BUFFER,
        new js.lib.Float32Array([0, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1, 1]),
        RenderingContext.STATIC_DRAW);

      bgLoc = {
        pos: gl.getAttribLocation(bgProg, 'a_position'),
        time: gl.getUniformLocation(bgProg, 'u_time'),
        res: gl.getUniformLocation(bgProg, 'u_resolution'),
        tex: gl.getUniformLocation(bgProg, 'u_texture'),
        aspect: gl.getUniformLocation(bgProg, 'u_texAspect'),
      };
      blitLoc = {
        pos: gl.getAttribLocation(blitProg, 'a_position'),
        tex: gl.getUniformLocation(blitProg, 'u_tex'),
        mul: gl.getUniformLocation(blitProg, 'u_mul'),
      };
      spriteLoc = {
        quad: gl.getAttribLocation(spriteProg, 'a_quad'),
        rect: gl.getUniformLocation(spriteProg, 'u_rect'),
        uv: gl.getUniformLocation(spriteProg, 'u_uv'),
        tex: gl.getUniformLocation(spriteProg, 'u_tex'),
        color: gl.getUniformLocation(spriteProg, 'u_color'),
        alpha: gl.getUniformLocation(spriteProg, 'u_alpha'),
      };
      envLoc = {
        world: gl.getAttribLocation(envProg, 'a_world'),
        color: gl.getAttribLocation(envProg, 'a_color'),
        focal: gl.getUniformLocation(envProg, 'u_focal'),
        halfW: gl.getUniformLocation(envProg, 'u_halfW'),
        canvasH: gl.getUniformLocation(envProg, 'u_canvasH'),
        horizonY: gl.getUniformLocation(envProg, 'u_horizonY'),
        camHeight: gl.getUniformLocation(envProg, 'u_camHeight'),
        nearZ: gl.getUniformLocation(envProg, 'u_nearZ'),
        farZ: gl.getUniformLocation(envProg, 'u_farZ'),
        fadeRange: gl.getUniformLocation(envProg, 'u_fadeRange'),
        camZ: gl.getUniformLocation(envProg, 'u_camZ'),
        fog: gl.getUniformLocation(envProg, 'u_fog'),
        fadeMul: gl.getUniformLocation(envProg, 'u_fadeMul'),
        fogMul: gl.getUniformLocation(envProg, 'u_fogMul'),
        pattern: gl.getUniformLocation(envProg, 'u_pattern'),
        screen: gl.getUniformLocation(envProg, 'u_screen'),
        off: gl.getUniformLocation(envProg, 'u_off'),
        amul: gl.getUniformLocation(envProg, 'u_amul'),
      };
      if (fogProg != null)
        fogLoc = {
          pos: gl.getAttribLocation(fogProg, 'a_pos'),
          uv: gl.getAttribLocation(fogProg, 'a_uv'),
          time: gl.getUniformLocation(fogProg, 'u_time'),
          tint: gl.getUniformLocation(fogProg, 'u_tint'),
          strength: gl.getUniformLocation(fogProg, 'u_strength'),
          aspect: gl.getUniformLocation(fogProg, 'u_aspect'),
        };

      // 1x1 white texture for flat colored sprites (lamp poles)
      whiteTex = makeTex();
      gl.bindTexture(RenderingContext.TEXTURE_2D, whiteTex);
      gl.texImage2D(RenderingContext.TEXTURE_2D, 0, RenderingContext.RGBA,
        1, 1, 0, RenderingContext.RGBA, RenderingContext.UNSIGNED_BYTE,
        new js.lib.Uint8Array([255, 255, 255, 255]));
    }

  function makeTex(): Texture
    {
      var t = gl.createTexture();
      gl.bindTexture(RenderingContext.TEXTURE_2D, t);
      gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_WRAP_S, RenderingContext.CLAMP_TO_EDGE);
      gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_WRAP_T, RenderingContext.CLAMP_TO_EDGE);
      gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_MIN_FILTER, RenderingContext.LINEAR);
      gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_MAG_FILTER, RenderingContext.LINEAR);
      return t;
    }

  function loadTex(url: String, flipY: Bool, cb: Image -> Void): Texture
    {
      var tex = makeTex();
      var img = new Image();
      img.crossOrigin = 'anonymous';
      img.onload = function() {
        gl.bindTexture(RenderingContext.TEXTURE_2D, tex);
        gl.pixelStorei(RenderingContext.UNPACK_FLIP_Y_WEBGL, flipY ? 1 : 0);
        gl.texImage2D(RenderingContext.TEXTURE_2D, 0, RenderingContext.RGBA,
          RenderingContext.RGBA, RenderingContext.UNSIGNED_BYTE, img);
        gl.pixelStorei(RenderingContext.UNPACK_FLIP_Y_WEBGL, 0);
        cb(img);
      };
      img.src = url;
      return tex;
    }

  function initTextures()
    {
      atlasTex = loadTex(AssetPath.resolve('img/full-height.png'), true, function(img) {
        atlasW = img.naturalWidth; atlasH = img.naturalHeight;
        atlasReady = true; onAtlasReady();
      });
      parasiteTex = loadTex(AssetPath.resolve('img/parasite-large.png'), true, function(img) {
        parasiteReady = true;
      });
      // radial glow texture (procedural canvas)
      glowTex = makeRadial([
        { stop: 0.0, a: 1.0 }, { stop: 0.4, a: 0.5 }, { stop: 1.0, a: 0.0 }
      ]);
      // softer gaussian-ish falloff for lamp heads / pools
      softTex = makeRadial([
        { stop: 0.0, a: 0.85 }, { stop: 0.25, a: 0.42 },
        { stop: 0.55, a: 0.13 }, { stop: 1.0, a: 0.0 }
      ]);
    }

// bake a white radial-gradient alpha texture from stop list
  function makeRadial(stops: Array<{ stop: Float, a: Float }>): Texture
    {
      var c = Browser.document.createCanvasElement();
      c.width = 64; c.height = 64;
      var g = c.getContext2d();
      var rg = g.createRadialGradient(32, 32, 0, 32, 32, 32);
      for (s in stops)
        rg.addColorStop(s.stop, 'rgba(255,255,255,' + s.a + ')');
      g.fillStyle = rg;
      g.fillRect(0, 0, 64, 64);
      var t = makeTex();
      gl.bindTexture(RenderingContext.TEXTURE_2D, t);
      gl.texImage2D(RenderingContext.TEXTURE_2D, 0, RenderingContext.RGBA,
        RenderingContext.RGBA, RenderingContext.UNSIGNED_BYTE, c);
      return t;
    }

// load / swap the background photo (called with css url() wrapper)
  public function setBackground(url: String)
    {
      if (gl == null)
        return;
      var imgUrl = url;
      if (StringTools.startsWith(imgUrl, 'url('))
        imgUrl = imgUrl.substring(4, imgUrl.length - 1);
      imgUrl = StringTools.replace(imgUrl, "'", "");
      imgUrl = StringTools.replace(imgUrl, '"', '');
      bgReady = false;
      bgTex = loadTex(AssetPath.resolve(imgUrl), false, function(img) {
        texAspect = img.naturalWidth / img.naturalHeight;
        bgReady = true;
      });
      bgEnabled = true;
    }

// toggle the photo layer (ai-art off => crowd/env over a dark clear)
  public function setBgEnabled(v: Bool)
    bgEnabled = v;

  function initFBOs(w: Int, h: Int)
    {
      if (fboW == w && fboH == h && accum != null)
        return;
      fboW = w; fboH = h;
      if (accum != null)
        for (i in 0...2)
          {
            gl.deleteFramebuffer(accum[i]);
            gl.deleteTexture(accumTex[i]);
          }
      accum = []; accumTex = [];
      for (i in 0...2)
        {
          var t = makeTex();
          gl.bindTexture(RenderingContext.TEXTURE_2D, t);
          gl.texImage2D(RenderingContext.TEXTURE_2D, 0, RenderingContext.RGBA,
            w, h, 0, RenderingContext.RGBA, RenderingContext.UNSIGNED_BYTE, null);
          var f = gl.createFramebuffer();
          gl.bindFramebuffer(RenderingContext.FRAMEBUFFER, f);
          gl.framebufferTexture2D(RenderingContext.FRAMEBUFFER, RenderingContext.COLOR_ATTACHMENT0,
            RenderingContext.TEXTURE_2D, t, 0);
          gl.clearColor(0, 0, 0, 0);
          gl.clear(RenderingContext.COLOR_BUFFER_BIT);
          accumTex[i] = t; accum[i] = f;
        }
      gl.bindFramebuffer(RenderingContext.FRAMEBUFFER, null);
      cur = 0;
    }

  function clearAccum()
    {
      if (accum == null)
        return;
      for (i in 0...2)
        {
          gl.bindFramebuffer(RenderingContext.FRAMEBUFFER, accum[i]);
          gl.clearColor(0, 0, 0, 0);
          gl.clear(RenderingContext.COLOR_BUFFER_BIT);
        }
      gl.bindFramebuffer(RenderingContext.FRAMEBUFFER, null);
    }

  // =========================================================================
  // crowd sim (ported from MainMenuCrowd)
  // =========================================================================
  inline function rand(n: Int): Int
    return Std.random(n);

  function onAtlasReady()
    {
      buildPool();
      if (members.length == 0)
        spawnInitial();
    }

  function buildPool()
    {
      spritePool = [];
      var x = 0;
      for (w in CELL_WIDTHS)
        {
          spritePool.push({ srcX: x, srcW: w });
          x += w;
        }
    }

  function spawnInitial()
    {
      members = [];
      for (_ in 0...MEMBER_COUNT)
        {
          var z = NEAR_Z + Math.random() * (FAR_Z - NEAR_Z);
          members.push(makeMember(z, true));
        }
    }

  function frustumHalf(dz: Float): Float
    {
      var w = (canvas.width > 0 ? canvas.width : Browser.window.innerWidth);
      return (w * 0.5) * dz / FOCAL;
    }

  inline function spawnHalf(): Float
    return frustumHalf(FAR_Z);

  function makeMember(dz: Float, randomPhase: Bool): _Member
    {
      var s = spritePool[rand(spritePool.length)];
      var hw = spawnHalf();
      return {
        id: nextID++, srcX: s.srcX, srcW: s.srcW,
        worldX: (Math.random() * 2 - 1) * hw, worldZ: camZ + dz,
        dir: (rand(2) == 0 ? -1 : 1), stepsLeft: 3 + rand(4),
        stepPhase: randomPhase ? Math.random() : 0,
        stepSpeed: 1.3 + Math.random() * 0.8, stepDist: 6 + Math.random() * 5,
        pauseLeft: randomPhase ? Math.random() * 1.5 : 0,
        hopAmp: 5 + Math.random() * 3,
        forwardSpeed: MEMBER_FORWARD_SPEED * (0.75 + Math.random() * 0.5),
      };
    }

  function recycle(m: _Member)
    {
      var dz = FAR_Z + Math.random() * 30;
      var s = spritePool[rand(spritePool.length)];
      m.id = nextID++; m.srcX = s.srcX; m.srcW = s.srcW;
      m.worldZ = camZ + dz; m.worldX = (Math.random() * 2 - 1) * spawnHalf();
      m.dir = (rand(2) == 0 ? -1 : 1); m.stepsLeft = 3 + rand(4);
      m.stepPhase = 0; m.pauseLeft = Math.random() * 1.5;
      m.forwardSpeed = MEMBER_FORWARD_SPEED * (0.75 + Math.random() * 0.5);
    }

  function step(dt: Float)
    {
      camZ += CAM_FORWARD_SPEED * dt;
      elapsed += dt;
      for (m in members)
        {
          if (m.pauseLeft <= 0)
            m.worldZ -= m.forwardSpeed * dt;
          if (m.pauseLeft > 0)
            {
              m.pauseLeft -= dt;
              if (m.pauseLeft <= 0)
                {
                  m.stepsLeft = 13 + rand(4);
                  m.stepPhase = 0;
                  m.pauseLeft = 0;
                }
            }
          else
            {
              m.stepPhase += m.stepSpeed * dt;
              while (m.stepPhase >= 1.0)
                {
                  m.stepPhase -= 1.0;
                  m.stepsLeft--;
                  if (m.stepsLeft <= 0)
                    {
                      m.pauseLeft = 0.8 + Math.random() * 1.4;
                      break;
                    }
                }
            }
          var dzNow = m.worldZ - camZ;
          if (dzNow < NEAR_Z)
            recycle(m);
          else if (Math.abs(m.worldX) > frustumHalf(dzNow) * 1.05)
            recycle(m);
        }
    }

  function findByID(id: Int): _Member
    {
      for (m in members)
        if (m.id == id)
          return m;
      return null;
    }

  function pickTarget(refX: Float, refY: Float, exclude: Int): _Member
    {
      var pool = [];
      for (m in members)
        {
          var dz = m.worldZ - camZ;
          if (dz < NEAR_Z + 80
              || dz > FAR_Z - 150
              || m.srcW >= WIDE_CELL_W
              || m.id == exclude)
            continue;
          var p = projectFace(m);
          var dx = p.x - refX;
          var dy = p.y - refY;
          pool.push({ m: m, d2: dx * dx + dy * dy });
        }
      if (pool.length == 0)
        return null;
      pool.sort(function(a, b) return (a.d2 < b.d2 ? -1 : (a.d2 > b.d2 ? 1 : 0)));
      var k = (pool.length < 4 ? pool.length : 4);
      return pool[rand(k)].m;
    }

  function projectFace(m: _Member): { x: Float, y: Float, scale: Float }
    {
      var dz = m.worldZ - camZ;
      if (dz < NEAR_Z)
        dz = NEAR_Z;
      var scale = FOCAL / dz;
      var halfW = canvas.width * 0.5;
      var horizonY = canvas.height * 0.4;
      var screenX = halfW + m.worldX * scale;
      var groundY = horizonY + CAM_HEIGHT * scale;
      var hopY = (m.pauseLeft > 0 ? 0 : Math.sin(m.stepPhase * Math.PI) * m.hopAmp * scale);
      var spriteH = SPRITE_WORLD_HEIGHT * scale;
      var faceY = (groundY - spriteH - hopY) + spriteH * PARASITE_HEAD_RATIO;
      return { x: screenX, y: faceY, scale: scale };
    }

  function startJump()
    {
      var t = pickTarget(parasiteRenderX, parasiteRenderY, parasiteTargetID);
      if (t == null)
        {
          parasiteState = WAIT;
          parasiteTargetID = -1;
          return;
        }
      parasiteFromX = parasiteRenderX;
      parasiteFromY = parasiteRenderY;
      parasiteFromScale = parasiteRenderScale;
      parasiteTargetID = t.id;
      parasiteJumpT = 0;
      parasiteState = JUMP;
    }

  function updateParasite(dt: Float)
    {
      if (!parasiteReady)
        return;
      switch (parasiteState)
        {
          case WAIT:
            var refX = canvas.width * 0.5;
            var refY = canvas.height * 0.4;
            var t = pickTarget(refX, refY, -1);
            if (t == null)
              return;
            parasiteFromX = canvas.width * 0.5;
            parasiteFromY = -80;
            parasiteFromScale = 0.5;
            parasiteRenderX = parasiteFromX;
            parasiteRenderY = parasiteFromY;
            parasiteRenderScale = parasiteFromScale;
            parasiteTargetID = t.id;
            parasiteJumpT = 0;
            parasiteState = JUMP;
          case RIDE:
            if (findByID(parasiteTargetID) == null)
              {
                startJump();
                return;
              }
            parasiteSitTimer -= dt;
            if (parasiteSitTimer <= 0)
              startJump();
          case JUMP:
            parasiteJumpT += dt / PARASITE_JUMP_DUR;
            if (parasiteJumpT >= 1.0)
              {
                if (findByID(parasiteTargetID) == null)
                  {
                    startJump();
                    return;
                  }
                parasiteState = RIDE;
                parasiteJumpT = 0;
                parasiteSitTimer = PARASITE_SIT_MIN
                  + Math.random() * (PARASITE_SIT_MAX - PARASITE_SIT_MIN);
              }
          default:
        }
    }

  // =========================================================================
  // spores
  // =========================================================================
  function initMotes()
    {
      motes = [];
      for (_ in 0...10)
        motes.push({ x: Math.random(), size: 2 + Math.random() * 3,
          life: 9 + Math.random() * 8, age: Math.random() * 9 });
    }

  function stepMotes(dt: Float)
    {
      for (o in motes)
        {
          o.age += dt;
          if (o.age >= o.life)
            {
              o.age = 0; o.x = Math.random();
              o.size = 2 + Math.random() * 3; o.life = 9 + Math.random() * 8;
            }
        }
    }

  // =========================================================================
  // environment geometry
  // =========================================================================
// 32-bit linear congruential generator -> deterministic env layout
  function makeLcg(seed: Int): Void -> Float
    {
      var s = seed;
      return function() {
        s = (s * 1664525 + 1013904223) >>> 0;
        return s / 4294967296.0;
      };
    }

// push two triangles (quad) into a float array; each vert = x,y,dz, r,g,b,a
  function pushQuad(a: Array<Float>, p0, p1, p2, p3, c0, c1, c2, c3)
    {
      inline function v(p: Array<Float>, c: Array<Float>)
        {
          a.push(p[0]); a.push(p[1]); a.push(p[2]);
          a.push(c[0]); a.push(c[1]); a.push(c[2]); a.push(c[3]);
        }
      v(p0, c0); v(p1, c1); v(p2, c2);
      v(p0, c0); v(p2, c2); v(p3, c3);
    }

  function buildEnv()
    {
      // alley walls: two converging planes, vertical gradient, segmented for fog
      var wall: Array<Float> = [];
      var cTop = WALL_COL_TOP.concat([0.9]);
      var cBot = WALL_COL_BOT.concat([0.9]);
      for (side in [-1, 1])
        {
          var x = side * WALL_X;
          for (i in 0...WALL_SEGS)
            {
              var dz0 = WALL_DZ0 + (WALL_DZ1 - WALL_DZ0) * (i / WALL_SEGS);
              var dz1 = WALL_DZ0 + (WALL_DZ1 - WALL_DZ0) * ((i + 1) / WALL_SEGS);
              pushQuad(wall, [x, 0, dz0], [x, WALL_TOP, dz0], [x, WALL_TOP, dz1], [x, 0, dz1],
                cBot, cTop, cTop, cBot);
            }
        }
      wallBuf = gl.createBuffer();
      gl.bindBuffer(RenderingContext.ARRAY_BUFFER, wallBuf);
      gl.bufferData(RenderingContext.ARRAY_BUFFER, new js.lib.Float32Array(wall), RenderingContext.STATIC_DRAW);
      wallN = Std.int(wall.length / 7);

      // skyline: faceted tenement silhouette + scattered lit windows
      var sky: Array<Float> = [];
      var win: Array<Float> = [];
      var rng = makeLcg(0x9e37);
      var dz = SKY_DZ;
      var sc = SKY_COL.concat([0.96]);
      var rim = SKY_RIM.concat([0.96]);
      var x = -SKY_SPREAD;
      while (x < SKY_SPREAD)
        {
          var w = 90 + rng() * 170;
          var h = 300 + rng() * 680;
          var x0 = x;
          var x1 = x + w;
          pushQuad(sky, [x0, 0, dz], [x0, h, dz], [x1, h, dz], [x1, 0, dz], sc, rim, rim, sc);
          if (rng() < 0.45)
            {
              var bx0 = x0 + w * 0.3;
              var bx1 = bx0 + 22 + rng() * 30;
              var bh = h + 18 + rng() * 46;
              pushQuad(sky, [bx0, h, dz], [bx0, bh, dz], [bx1, bh, dz], [bx1, h, dz], sc, rim, rim, sc);
            }
          var wy = 40.0;
          while (wy < h - 28)
            {
              var wx = x0 + 16;
              while (wx < x1 - 16)
                {
                  if (rng() < 0.32)
                    {
                      var warm = rng() < 0.72;
                      var inten = 0.035 + rng() * 0.09;
                      var col = warm ? [1.0, 0.74, 0.4, inten] : [0.5, 0.86, 0.86, inten];
                      pushQuad(win, [wx, wy, dz], [wx, wy + 15, dz], [wx + 9, wy + 15, dz], [wx + 9, wy, dz],
                        col, col, col, col);
                    }
                  wx += 30;
                }
              wy += 40;
            }
          x += w + (24 + rng() * 64);
        }
      skyBuf = gl.createBuffer();
      gl.bindBuffer(RenderingContext.ARRAY_BUFFER, skyBuf);
      gl.bufferData(RenderingContext.ARRAY_BUFFER, new js.lib.Float32Array(sky), RenderingContext.STATIC_DRAW);
      skyN = Std.int(sky.length / 7);
      winBuf = gl.createBuffer();
      gl.bindBuffer(RenderingContext.ARRAY_BUFFER, winBuf);
      gl.bufferData(RenderingContext.ARRAY_BUFFER, new js.lib.Float32Array(win), RenderingContext.STATIC_DRAW);
      winN = Std.int(win.length / 7);

      // ground: dark asphalt plane, opaque near, fades into the horizon
      var gnd: Array<Float> = [];
      var G = GROUND_G;
      for (i in 0...GROUND_SEGS)
        {
          var dz0 = NEAR_Z + (FAR_Z - NEAR_Z) * (i / GROUND_SEGS);
          var dz1 = NEAR_Z + (FAR_Z - NEAR_Z) * ((i + 1) / GROUND_SEGS);
          var a0 = 0.99 * (1 - Math.pow(i / GROUND_SEGS, 3.0));
          var a1 = 0.99 * (1 - Math.pow((i + 1) / GROUND_SEGS, 3.0));
          var c0 = GROUND_COL.concat([a0]);
          var c1 = GROUND_COL.concat([a1]);
          pushQuad(gnd, [-G, 0, dz0], [-G, 0, dz1], [G, 0, dz1], [G, 0, dz0], c0, c1, c1, c0);
        }
      gndBuf = gl.createBuffer();
      gl.bindBuffer(RenderingContext.ARRAY_BUFFER, gndBuf);
      gl.bufferData(RenderingContext.ARRAY_BUFFER, new js.lib.Float32Array(gnd), RenderingContext.STATIC_DRAW);
      gndN = Std.int(gnd.length / 7);

      // screen-space bottom vignette
      var vig: Array<Float> = [];
      var cb = [0.008, 0.006, 0.016, 0.96];
      var ct = [0.008, 0.006, 0.016, 0.0];
      var yb = -1.0;
      var yt = 0.18;
      pushQuad(vig, [-1, yb, 0], [-1, yt, 0], [1, yt, 0], [1, yb, 0], cb, ct, ct, cb);
      vigBuf = gl.createBuffer();
      gl.bindBuffer(RenderingContext.ARRAY_BUFFER, vigBuf);
      gl.bufferData(RenderingContext.ARRAY_BUFFER, new js.lib.Float32Array(vig), RenderingContext.STATIC_DRAW);
      vigN = Std.int(vig.length / 7);
    }

  function initLamps()
    {
      lamps = [];
      var rng = makeLcg(0x51ed);
      for (i in 0...LAMP_COUNT)
        {
          var dz = NEAR_Z + (FAR_Z - NEAR_Z) * (i / LAMP_COUNT) + rng() * 30;
          lamps.push({ worldZ: camZ + dz, side: (i % 2 == 0 ? -1 : 1), cyan: rng() < 0.25,
            h: LAMP_POLE_H * (0.82 + rng() * 0.42), phase: rng() * 6.28, ph2: 0.7 + rng() * 0.8 });
        }
    }

  function stepLamps()
    {
      for (l in lamps)
        {
          var dz = l.worldZ - camZ;
          if (dz < 70)
            {
              l.worldZ = camZ + FAR_Z + Math.random() * 120;
              l.cyan = Math.random() < 0.25;
              l.h = LAMP_POLE_H * (0.82 + Math.random() * 0.42);
              l.phase = Math.random() * 6.28;
              l.ph2 = 0.7 + Math.random() * 0.8;
            }
        }
    }

  function initFog()
    {
      if (fogProg == null)
        return;
      var yt = FOG_TOP;
      var v = [-1, -1, 0, 0, -1, yt, 0, 1, 1, yt, 1, 1, -1, -1, 0, 0, 1, yt, 1, 1, 1, -1, 1, 0];
      fogBuf = gl.createBuffer();
      gl.bindBuffer(RenderingContext.ARRAY_BUFFER, fogBuf);
      gl.bufferData(RenderingContext.ARRAY_BUFFER, new js.lib.Float32Array(v), RenderingContext.STATIC_DRAW);
    }

  // =========================================================================
  // lifecycle
  // =========================================================================
  function size()
    {
      var w = Std.int(Math.max(1, Math.round(Browser.window.innerWidth * RES_SCALE)));
      var h = Std.int(Math.max(1, Math.round(Browser.window.innerHeight * RES_SCALE)));
      if (canvas.width != w || canvas.height != h)
        {
          canvas.width = w;
          canvas.height = h;
        }
      initFBOs(w, h);
    }

// start render loop; re-insert canvas if it was detached
  public function show()
    {
      if (gl == null)
        return;
      if (canvas.parentElement == null && parentEl != null)
        parentEl.insertBefore(canvas, parentEl.firstChild);
      canvas.style.display = 'block';
      lastFrame = 0;
      size();
      clearAccum();
      if (!running)
        {
          running = true;
          renderLoop();
        }
    }

// stop the render loop (canvas stays in DOM; show() restarts)
  public function hide()
    {
      running = false;
      if (animId != 0)
        {
          Browser.window.cancelAnimationFrame(animId);
          animId = 0;
        }
    }

  function renderLoop()
    {
      if (!running)
        {
          animId = 0;
          return;
        }
      if (gl == null)
        return;
      // self-stop if the menu was hidden (CSS visibility) or detached
      if (canvas.parentElement == null
          || canvas.parentElement.style.visibility == 'hidden')
        {
          running = false;
          animId = 0;
          return;
        }
      animId = Browser.window.requestAnimationFrame(function(_) renderLoop());
      var now = Browser.window.performance.now();
      if (lastFrame != 0 && now - lastFrame < FRAME_INTERVAL)
        return; // 30fps cap
      var dt = (lastFrame == 0 ? 1.0 / TARGET_FPS : (now - lastFrame) / 1000.0);
      if (dt > 0.1)
        dt = 0.1;
      lastFrame = now;
      size();
      if (atlasReady && members.length > 0)
        {
          step(dt);
          updateParasite(dt);
        }
      stepMotes(dt);
      stepLamps();
      draw(now);
    }

  // =========================================================================
  // render
  // =========================================================================
  function draw(now: Float)
    {
      var W = canvas.width;
      var H = canvas.height;
      // 1) accumulation pass: fade trail, draw fresh silhouettes into off-screen buffer
      var src = cur;
      var dst = 1 - cur;
      gl.bindFramebuffer(RenderingContext.FRAMEBUFFER, accum[dst]);
      gl.viewport(0, 0, W, H);
      gl.disable(RenderingContext.BLEND);
      blit(accumTex[src], TRAIL_KEEP);
      if (atlasReady)
        {
          gl.enable(RenderingContext.BLEND);
          gl.blendFunc(RenderingContext.ONE, RenderingContext.ONE_MINUS_SRC_ALPHA);
          drawCrowd();
          drawParasiteSprite();
        }
      else pGlow = null;
      cur = dst;
      // 2) screen: bg -> env -> lamp poles -> crowd accum -> fog -> additive glows
      gl.bindFramebuffer(RenderingContext.FRAMEBUFFER, null);
      gl.viewport(0, 0, W, H);
      gl.disable(RenderingContext.BLEND);
      if (bgReady && bgEnabled)
        drawBG(now);
      else
        {
          gl.clearColor(0.04, 0.02, 0.05, 1);
          gl.clear(RenderingContext.COLOR_BUFFER_BIT);
        }
      gl.enable(RenderingContext.BLEND);
      gl.blendFunc(RenderingContext.ONE, RenderingContext.ONE_MINUS_SRC_ALPHA);
      drawEnv();
      drawLampPoles();
      blit(accumTex[cur], 1.0);
      drawFog();
      gl.blendFunc(RenderingContext.ONE, RenderingContext.ONE);
      drawLampGlow();
      drawEnvEmissive();
      drawParasiteGlow();
      drawMotes();
      gl.disable(RenderingContext.BLEND);
    }

  function blit(tex: Texture, mul: Float)
    {
      gl.useProgram(blitProg);
      gl.bindBuffer(RenderingContext.ARRAY_BUFFER, quadFull);
      gl.enableVertexAttribArray(blitLoc.pos);
      gl.vertexAttribPointer(blitLoc.pos, 2, RenderingContext.FLOAT, false, 0, 0);
      gl.activeTexture(RenderingContext.TEXTURE0);
      gl.bindTexture(RenderingContext.TEXTURE_2D, tex);
      gl.uniform1i(blitLoc.tex, 0);
      gl.uniform1f(blitLoc.mul, mul);
      gl.drawArrays(RenderingContext.TRIANGLES, 0, 6);
    }

  function drawBG(now: Float)
    {
      gl.useProgram(bgProg);
      gl.bindBuffer(RenderingContext.ARRAY_BUFFER, quadFull);
      gl.enableVertexAttribArray(bgLoc.pos);
      gl.vertexAttribPointer(bgLoc.pos, 2, RenderingContext.FLOAT, false, 0, 0);
      gl.uniform1f(bgLoc.time, (now - startTime) / 1000);
      gl.uniform2f(bgLoc.res, canvas.width, canvas.height);
      gl.uniform1f(bgLoc.aspect, texAspect);
      gl.activeTexture(RenderingContext.TEXTURE0);
      gl.bindTexture(RenderingContext.TEXTURE_2D, bgTex);
      gl.uniform1i(bgLoc.tex, 0);
      gl.drawArrays(RenderingContext.TRIANGLES, 0, 6);
    }

  function beginSprites()
    {
      gl.useProgram(spriteProg);
      gl.bindBuffer(RenderingContext.ARRAY_BUFFER, quadUnit);
      gl.enableVertexAttribArray(spriteLoc.quad);
      gl.vertexAttribPointer(spriteLoc.quad, 2, RenderingContext.FLOAT, false, 0, 0);
    }

  function sprite(tex: Texture, dx: Float, dy: Float, w: Float, h: Float,
      u0: Float, uw: Float, color: Array<Float>, alpha: Float)
    {
      var W = canvas.width;
      var H = canvas.height;
      var x0 = dx / W * 2 - 1;
      var y0 = 1 - dy / H * 2;
      var wx = w / W * 2;
      var wy = -(h / H * 2);
      gl.uniform4f(spriteLoc.rect, x0, y0, wx, wy);
      gl.uniform4f(spriteLoc.uv, u0, 1.0, uw, -1.0);
      gl.activeTexture(RenderingContext.TEXTURE0);
      gl.bindTexture(RenderingContext.TEXTURE_2D, tex);
      gl.uniform1i(spriteLoc.tex, 0);
      gl.uniform3f(spriteLoc.color, color[0], color[1], color[2]);
      gl.uniform1f(spriteLoc.alpha, alpha);
      gl.drawArrays(RenderingContext.TRIANGLES, 0, 6);
    }

  function drawCrowd()
    {
      beginSprites();
      members.sort(function(a, b) return (b.worldZ < a.worldZ ? -1 : (b.worldZ > a.worldZ ? 1 : 0)));
      var halfW = canvas.width * 0.5;
      var horizonY = canvas.height * 0.4;
      for (m in members)
        {
          var dz = m.worldZ - camZ;
          if (dz < NEAR_Z || dz > FAR_Z + 50)
            continue;
          var scale = FOCAL / dz;
          var screenX = halfW + m.worldX * scale;
          var groundY = horizonY + CAM_HEIGHT * scale;
          var hopY = (m.pauseLeft > 0 ? 0 : Math.sin(m.stepPhase * Math.PI) * m.hopAmp * scale);
          var spriteH = SPRITE_WORLD_HEIGHT * scale;
          var spriteW = spriteH * (m.srcW / CELL_H);
          var drawX = screenX - spriteW * 0.5;
          var drawY = groundY - spriteH - hopY;
          var fade = (FAR_Z - dz) / FADE_RANGE;
          if (fade > 1) fade = 1;
          if (fade < 0) fade = 0;
          if (drawX + spriteW < 0 || drawX > canvas.width
              || drawY + spriteH < 0 || drawY > canvas.height)
            continue;
          var nf = (dz - NEAR_Z) / (FAR_Z - NEAR_Z);
          nf = 1 - (nf < 0 ? 0 : (nf > 1 ? 1 : nf)); // 0 far -> 1 near
          var col = [
            TINT_FAR[0] + (TINT_NEAR[0] - TINT_FAR[0]) * nf,
            TINT_FAR[1] + (TINT_NEAR[1] - TINT_FAR[1]) * nf,
            TINT_FAR[2] + (TINT_NEAR[2] - TINT_FAR[2]) * nf,
          ];
          sprite(atlasTex, drawX, drawY, spriteW, spriteH, m.srcX / atlasW, m.srcW / atlasW, col, BASE_ALPHA * fade);
        }
    }

  function drawParasiteSprite()
    {
      if (!parasiteReady || parasiteState == WAIT)
        {
          pGlow = null;
          return;
        }
      var m = findByID(parasiteTargetID);
      if (m == null)
        {
          pGlow = null;
          return;
        }
      var p = projectFace(m);
      var x: Float, y: Float, scale: Float;
      if (parasiteState == RIDE)
        {
          x = p.x; y = p.y; scale = p.scale;
        }
      else
        {
          var t = parasiteJumpT;
          if (t > 1) t = 1;
          var te = t * t * (3 - 2 * t);
          x = parasiteFromX + (p.x - parasiteFromX) * te;
          y = parasiteFromY + (p.y - parasiteFromY) * te;
          var dx = p.x - parasiteFromX;
          var arcH = 80 + Math.abs(dx) * 0.15;
          y -= arcH * 4 * te * (1 - te);
          scale = parasiteFromScale + (p.scale - parasiteFromScale) * te;
        }
      parasiteRenderX = x; parasiteRenderY = y; parasiteRenderScale = scale;
      var w = PARASITE_WORLD_W * scale;
      var h = w * (PARASITE_NATIVE_H / PARASITE_NATIVE_W);
      var dz = m.worldZ - camZ;
      var fade = (FAR_Z - dz) / FADE_RANGE;
      if (fade > 1) fade = 1;
      if (fade < 0) fade = 0;
      beginSprites();
      sprite(parasiteTex, x - w * 0.5, y - h * 0.5, w, h, 0, 1, PARASITE_TINT, Math.min(1, BASE_ALPHA * fade * 2.0));
      pGlow = { x: x, y: y, w: w, h: h, fade: fade };
    }

  function drawParasiteGlow()
    {
      if (pGlow == null)
        return;
      beginSprites();
      var pulse = 0.5 + 0.5 * Math.sin(elapsed * 2.6);
      var gsize = Math.max(pGlow.w, pGlow.h) * (1.7 + pulse * 0.6);
      var a = Math.min(0.85, BASE_ALPHA * pGlow.fade * 6.0 * (0.55 + pulse * 0.45));
      sprite(glowTex, pGlow.x - gsize * 0.5, pGlow.y - gsize * 0.5, gsize, gsize, 0, 1, GLOW_TINT, a);
    }

  function drawMotes()
    {
      if (motes == null)
        return;
      beginSprites();
      var W = canvas.width;
      var H = canvas.height;
      for (o in motes)
        {
          var pr = o.age / o.life;
          var a = Math.sin(pr * Math.PI) * 0.55;
          if (a <= 0.01)
            continue;
          var x = o.x * W;
          var y = (1.05 - pr * 1.2) * H;
          var sz = o.size * RES_SCALE * 3.2;
          sprite(glowTex, x - sz * 0.5, y - sz * 0.5, sz, sz, 0, 1, MOTE_TINT, a);
        }
    }

  function drawFog()
    {
      if (fogProg == null || fogBuf == null)
        return;
      gl.useProgram(fogProg);
      gl.bindBuffer(RenderingContext.ARRAY_BUFFER, fogBuf);
      gl.enableVertexAttribArray(fogLoc.pos);
      gl.vertexAttribPointer(fogLoc.pos, 2, RenderingContext.FLOAT, false, 16, 0);
      gl.enableVertexAttribArray(fogLoc.uv);
      gl.vertexAttribPointer(fogLoc.uv, 2, RenderingContext.FLOAT, false, 16, 8);
      gl.uniform1f(fogLoc.time, elapsed);
      gl.uniform1f(fogLoc.strength, FOG_STRENGTH);
      gl.uniform1f(fogLoc.aspect, canvas.width / Math.max(1, canvas.height));
      gl.uniform3f(fogLoc.tint, FOG_TINT[0], FOG_TINT[1], FOG_TINT[2]);
      gl.drawArrays(RenderingContext.TRIANGLES, 0, 6);
    }

  // ---------- environment draw ----------
  function envSetup()
    {
      gl.useProgram(envProg);
      gl.uniform1f(envLoc.focal, FOCAL);
      gl.uniform1f(envLoc.halfW, canvas.width * 0.5);
      gl.uniform1f(envLoc.canvasH, canvas.height);
      gl.uniform1f(envLoc.horizonY, canvas.height * 0.4);
      gl.uniform1f(envLoc.camHeight, CAM_HEIGHT);
      gl.uniform1f(envLoc.nearZ, NEAR_Z);
      gl.uniform1f(envLoc.farZ, FAR_Z);
      gl.uniform1f(envLoc.fadeRange, FADE_RANGE);
      gl.uniform1f(envLoc.camZ, camZ);
      gl.uniform3f(envLoc.fog, FOG[0], FOG[1], FOG[2]);
    }

  function envDraw(buf: Buffer, n: Int, fadeMul: Float, fogMul: Float, pattern: Float,
      screen: Float, offX: Float, offY: Float, amul: Float)
    {
      if (buf == null || n == 0)
        return;
      gl.uniform1f(envLoc.screen, screen);
      gl.uniform2f(envLoc.off, offX, offY);
      gl.uniform1f(envLoc.amul, amul);
      gl.bindBuffer(RenderingContext.ARRAY_BUFFER, buf);
      gl.enableVertexAttribArray(envLoc.world);
      gl.vertexAttribPointer(envLoc.world, 3, RenderingContext.FLOAT, false, 28, 0);
      gl.enableVertexAttribArray(envLoc.color);
      gl.vertexAttribPointer(envLoc.color, 4, RenderingContext.FLOAT, false, 28, 12);
      gl.uniform1f(envLoc.fadeMul, fadeMul);
      gl.uniform1f(envLoc.fogMul, fogMul);
      gl.uniform1f(envLoc.pattern, pattern);
      gl.drawArrays(RenderingContext.TRIANGLES, 0, n);
    }

// solid black floor up to the skyline base + dark veil over the sky
  function drawBlackGround()
    {
      var H = canvas.height;
      var scale = FOCAL / SKY_DZ;
      var clipTop = 1.0 - 2.0 * ((H * 0.4 + CAM_HEIGHT * scale) / H);
      var yb = clipTop - 0.05;
      var yt = clipTop + 0.03;
      var av = SKY_VEIL;
      var at = SKY_VEIL * 0.8;
      var v = new js.lib.Float32Array([
        -1, -1, 0, 0, 0, 0, 1, -1, yb, 0, 0, 0, 0, 1, 1, yb, 0, 0, 0, 0, 1,
        -1, -1, 0, 0, 0, 0, 1, 1, yb, 0, 0, 0, 0, 1, 1, -1, 0, 0, 0, 0, 1,
        -1, yb, 0, 0, 0, 0, 1, -1, yt, 0, 0, 0, 0, av, 1, yt, 0, 0, 0, 0, av,
        -1, yb, 0, 0, 0, 0, 1, 1, yt, 0, 0, 0, 0, av, 1, yb, 0, 0, 0, 0, 1,
        -1, yt, 0, 0, 0, 0, av, -1, 1, 0, 0, 0, 0, at, 1, 1, 0, 0, 0, 0, at,
        -1, yt, 0, 0, 0, 0, av, 1, 1, 0, 0, 0, 0, at, 1, yt, 0, 0, 0, 0, av,
      ]);
      if (blackBuf == null)
        blackBuf = gl.createBuffer();
      gl.bindBuffer(RenderingContext.ARRAY_BUFFER, blackBuf);
      gl.bufferData(RenderingContext.ARRAY_BUFFER, v, RenderingContext.DYNAMIC_DRAW);
      envDraw(blackBuf, 18, 0, 0, 0, 1, 0, 0, 1);
    }

// skyline: opaque core (occludes bg) + soft offset halo for blurry edges
  function drawSkylineBlurred()
    {
      var W = canvas.width;
      var H = canvas.height;
      var rx = 7.0 / W * 2.0;
      var ry = 7.0 / H * 2.0;
      envDraw(skyBuf, skyN, 0, 0, 0, 0, 0, 0, 0.85);
      var ring = [[-1, 0], [1, 0], [0, -1], [0, 1], [-1, -1], [1, -1], [-1, 1], [1, 1]];
      for (t in ring)
        envDraw(skyBuf, skyN, 0, 0, 0, 0, t[0] * rx, t[1] * ry, 0.12);
    }

  function drawEnv()
    {
      envSetup();
      drawBlackGround();
      drawSkylineBlurred();
    }

  function drawEnvEmissive()
    {
      envSetup();
      envDraw(winBuf, winN, 0, 0, 0, 0, 0, 0, 1);
    }

  function drawLampPoles()
    {
      if (lamps == null)
        return;
      beginSprites();
      var halfW = canvas.width * 0.5;
      var horizonY = canvas.height * 0.4;
      var pc = LAMP_POLE_COL;
      lampDraw = [];
      var sorted = lamps.copy();
      sorted.sort(function(a, b) return (b.worldZ < a.worldZ ? -1 : (b.worldZ > a.worldZ ? 1 : 0)));
      for (l in sorted)
        {
          var dz = l.worldZ - camZ;
          if (dz < 70 || dz > FAR_Z + 50)
            continue;
          var scale = FOCAL / dz;
          var screenX = halfW + l.side * LAMP_X * scale;
          var groundY = horizonY + CAM_HEIGHT * scale;
          var topY = horizonY + (CAM_HEIGHT - l.h) * scale;
          var poleW = Math.max(1, LAMP_POLE_W * scale);
          var fade = (FAR_Z - dz) / FADE_RANGE;
          if (fade > 1) fade = 1;
          if (fade < 0) fade = 0;
          sprite(whiteTex, screenX - poleW * 0.5, topY, poleW, groundY - topY, 0, 1, pc, 0.85 * fade);
          var armLen = LAMP_ARM * scale;
          var armEndX = screenX - l.side * armLen;
          var armT = Math.max(1, poleW * 0.85);
          sprite(whiteTex, Math.min(screenX, armEndX), topY, armLen, armT, 0, 1, pc, 0.85 * fade);
          var dropH = Math.max(2, LAMP_POLE_W * scale * 1.8);
          sprite(whiteTex, armEndX - armT * 0.5, topY, armT, dropH, 0, 1, pc, 0.85 * fade);
          lampDraw.push({ headX: armEndX, headY: topY + dropH, groundY: groundY, scale: scale, fade: fade,
            phase: l.phase, ph2: l.ph2, col: (l.cyan ? LAMP_CYAN : LAMP_SODIUM) });
        }
    }

  function drawLampGlow()
    {
      if (lampDraw == null || lampDraw.length == 0)
        return;
      beginSprites();
      for (d in lampDraw)
        {
          // steady mostly; rare short strobe burst (failing sodium lamp), desynced
          var flick = 0.82 + 0.18 * d.ph2;
          var t = elapsed * d.ph2 + d.phase;
          var win = Math.sin(t * 0.21 + d.phase * 2.3);
          if (win > 0.92)
            {
              var fast = 0.5 + 0.5 * Math.sin(elapsed * 38.0) * Math.sin(elapsed * 57.0 + d.phase * 4.0);
              flick *= 0.3 + 0.7 * fast;
            }
          var head = Math.max(8, LAMP_POLE_W * d.scale * 7.5);
          sprite(softTex, d.headX - head * 0.5, d.headY - head * 0.5, head, head, 0, 1, d.col, Math.min(0.85, 0.65 * d.fade * flick));
          var core = Math.max(3, LAMP_POLE_W * d.scale * 1.8);
          sprite(whiteTex, d.headX - core * 0.5, d.headY - core * 0.5, core, core, 0, 1, d.col, Math.min(0.95, 0.9 * d.fade * flick));
          var poolW = LAMP_POLE_H * d.scale * 1.5;
          var poolH = poolW * 0.3;
          sprite(softTex, d.headX - poolW * 0.5, d.groundY - poolH * 0.55, poolW, poolH, 0, 1, d.col, Math.min(0.3, 0.28 * d.fade * flick));
        }
    }

  // =========================================================================
  // shaders
  // =========================================================================
  static var BG_VS = '
    attribute vec2 a_position;
    varying vec2 v_uv;
    void main() {
      v_uv = a_position * 0.5 + 0.5;
      v_uv.y = 1.0 - v_uv.y;
      gl_Position = vec4(a_position, 0.0, 1.0);
    }
  ';

  static var BG_FS = '
    precision mediump float;
    varying vec2 v_uv;
    uniform sampler2D u_texture;
    uniform float u_time;
    uniform vec2 u_resolution;
    uniform float u_texAspect;
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
      float screenAspect = u_resolution.x / u_resolution.y;
      vec2 uv = v_uv;
      if (u_texAspect > screenAspect) {
        float scale = screenAspect / u_texAspect;
        uv.x = uv.x * scale + (1.0 - scale) * 0.5;
      } else {
        float scale = u_texAspect / screenAspect;
        uv.y = uv.y * scale + (1.0 - scale) * 0.5;
      }
      float cycle = 180.0;
      float phase = mod(u_time, cycle) / 90.0;
      if (phase > 1.0) phase = 2.0 - phase;
      float panAmount = 0.08;
      float panX = mix(-panAmount, panAmount, phase);
      uv.x += panX;
      vec2 noiseCoord = v_uv * u_resolution * 0.005;
      float nx = snoise(noiseCoord);
      float ny = snoise(noiseCoord + 100.0);
      vec2 staticDisp = vec2(nx, ny) * (10.0 / u_resolution);
      float timeAnim = u_time * 0.05;
      float dx = snoise(vec2(noiseCoord.x * 0.3 + timeAnim, noiseCoord.y * 0.3));
      float dy = snoise(vec2(noiseCoord.x * 0.3, noiseCoord.y * 0.3 + timeAnim + 100.0));
      vec2 driftDisp = vec2(dx, dy) * (8.0 / u_resolution);
      uv += staticDisp + driftDisp;
      uv = clamp(uv, 0.0, 1.0);
      vec2 ctr = uv - 0.5;
      float ca = dot(ctr, ctr) * 0.012;
      vec2 cdir = normalize(ctr + vec2(1e-5));
      vec4 color = texture2D(u_texture, uv);
      color.r = texture2D(u_texture, uv + cdir * ca).r;
      color.b = texture2D(u_texture, uv - cdir * ca).b;
      float gray = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
      gray = pow(gray, 1.25);
      vec3 cLo = vec3(0.10, 0.06, 0.18);
      vec3 cMid = vec3(0.227, 0.165, 0.36);
      vec3 cHi = vec3(0.45, 0.82, 0.68);
      vec3 graded = gray < 0.5 ? mix(cLo, cMid, gray * 2.0) : mix(cMid, cHi, (gray - 0.5) * 2.0);
      color.rgb = mix(graded, color.rgb * 1.08, 0.16);
      color.rgb *= 0.92;
      float highlight = smoothstep(0.3, 0.6, gray);
      float gate = snoise(uv * 5.0 + vec2(sin(u_time * 0.12) * 0.4, cos(u_time * 0.09) * 0.4));
      gate = smoothstep(0.0, 0.4, gate);
      float fineGate = snoise(uv * 20.0 + vec2(sin(u_time * 0.2 + 1.0) * 0.3));
      fineGate = smoothstep(0.2, 0.5, fineGate);
      float brightSpots = smoothstep(0.45, 0.7, gray);
      float glisten = highlight * gate * 0.25 + brightSpots * fineGate * 0.2;
      color.rgb += glisten * vec3(0.55, 1.0, 0.85);
      float glow = 0.0;
      float r1 = 7.0 / u_resolution.x;
      vec3 lum = vec3(0.2126, 0.7152, 0.0722);
      glow += dot(texture2D(u_texture, uv + vec2(r1, 0.0)).rgb, lum);
      glow += dot(texture2D(u_texture, uv + vec2(-r1, 0.0)).rgb, lum);
      glow += dot(texture2D(u_texture, uv + vec2(0.0, r1)).rgb, lum);
      glow += dot(texture2D(u_texture, uv + vec2(0.0, -r1)).rgb, lum);
      glow = glow * 0.25;
      float glowMask = smoothstep(0.25, 0.5, glow);
      color.rgb += glowMask * 0.3 * vec3(0.6, 1.0, 0.95);
      float breathe = 0.94 + 0.06 * sin(u_time * 0.5);
      color.rgb *= breathe;
      float grain = snoise(v_uv * u_resolution * 0.5 + vec2(u_time * 37.0, u_time * 23.0));
      color.rgb += grain * mix(0.03, 0.006, smoothstep(0.2, 0.7, gray));
      gl_FragColor = color;
    }
  ';

  static var BLIT_VS = '
    attribute vec2 a_position; varying vec2 v_uv;
    void main() { v_uv = a_position * 0.5 + 0.5; gl_Position = vec4(a_position, 0.0, 1.0); }';

  static var BLIT_FS = '
    precision mediump float; varying vec2 v_uv; uniform sampler2D u_tex; uniform float u_mul;
    void main() { gl_FragColor = texture2D(u_tex, v_uv) * u_mul; }';

  static var SPRITE_VS = '
    attribute vec2 a_quad; uniform vec4 u_rect; uniform vec4 u_uv; varying vec2 v_uv;
    void main() { v_uv = u_uv.xy + a_quad * u_uv.zw; gl_Position = vec4(u_rect.xy + a_quad * u_rect.zw, 0.0, 1.0); }';

  static var SPRITE_FS = '
    precision mediump float; varying vec2 v_uv; uniform sampler2D u_tex; uniform vec3 u_color; uniform float u_alpha;
    void main() { float a = texture2D(u_tex, v_uv).a * u_alpha; gl_FragColor = vec4(u_color * a, a); }';

  static var ENV_VS = '
    attribute vec3 a_world; attribute vec4 a_color;
    uniform float u_focal,u_halfW,u_canvasH,u_horizonY,u_camHeight,u_nearZ,u_farZ,u_fadeRange,u_camZ,u_fadeMul,u_fogMul,u_screen,u_amul;
    uniform vec2 u_off;
    uniform vec3 u_fog;
    varying vec4 v_color; varying float v_dz; varying float v_y;
    void main() {
      if (u_screen > 0.5) { v_color = vec4(a_color.rgb, a_color.a * u_amul); v_dz = u_farZ; v_y = 0.0; gl_Position = vec4(a_world.xy + u_off, 0.0, 1.0); return; }
      float dz = a_world.z; if (dz < u_nearZ) dz = u_nearZ;
      float scale = u_focal / dz;
      float sx = u_halfW + a_world.x * scale;
      float sy = u_horizonY + (u_camHeight - a_world.y) * scale;
      float fade = clamp((u_farZ - dz) / u_fadeRange, 0.0, 1.0);
      float nf = 1.0 - clamp((dz - u_nearZ) / (u_farZ - u_nearZ), 0.0, 1.0);
      vec3 rgb = mix(u_fog, a_color.rgb, mix(1.0, nf, u_fogMul));
      v_color = vec4(rgb, a_color.a * mix(1.0, fade, u_fadeMul) * u_amul);
      v_dz = dz; v_y = a_world.y;
      gl_Position = vec4(sx / u_halfW - 1.0 + u_off.x, 1.0 - (sy / u_canvasH) * 2.0 + u_off.y, 0.0, 1.0);
    }';

  static var ENV_FS = '
    precision mediump float; varying vec4 v_color; varying float v_dz; varying float v_y;
    uniform float u_camZ,u_pattern;
    void main() { vec3 rgb = v_color.rgb;
      if (u_pattern > 0.5) {
        float course = abs(fract((v_dz - u_camZ) * 0.018) - 0.5) * 2.0;
        float line = smoothstep(0.86, 1.0, course);
        float band = smoothstep(0.86, 1.0, abs(fract(v_y * 0.016) - 0.5) * 2.0);
        rgb *= 1.0 - (line + band) * 0.1;
      }
      gl_FragColor = vec4(rgb * v_color.a, v_color.a);
    }';

  static var FOG_VS = '
    attribute vec2 a_pos; attribute vec2 a_uv; varying vec2 v_uv;
    void main() { v_uv = a_uv; gl_Position = vec4(a_pos, 0.0, 1.0); }';

  static var FOG_FS = '
    precision highp float; varying vec2 v_uv; uniform float u_time,u_strength,u_aspect; uniform vec3 u_tint;
    vec3 mod289(vec3 x){return x-floor(x*(1.0/289.0))*289.0;}
    vec2 mod289v2(vec2 x){return x-floor(x*(1.0/289.0))*289.0;}
    vec3 permute(vec3 x){return mod289(((x*34.0)+1.0)*x);}
    float snoise(vec2 v){ const vec4 C=vec4(0.211324865405187,0.366025403784439,-0.577350269189626,0.024390243902439);
      vec2 i=floor(v+dot(v,C.yy)); vec2 x0=v-i+dot(i,C.xx);
      vec2 i1=(x0.x>x0.y)?vec2(1.0,0.0):vec2(0.0,1.0);
      vec4 x12=x0.xyxy+C.xxzz; x12.xy-=i1; i=mod289v2(i);
      vec3 p=permute(permute(i.y+vec3(0.0,i1.y,1.0))+i.x+vec3(0.0,i1.x,1.0));
      vec3 m=max(0.5-vec3(dot(x0,x0),dot(x12.xy,x12.xy),dot(x12.zw,x12.zw)),0.0); m=m*m; m=m*m;
      vec3 x=2.0*fract(p*C.www)-1.0; vec3 h=abs(x)-0.5; vec3 ox=floor(x+0.5); vec3 a0=x-ox;
      m*=1.79284291400159-0.85373472095314*(a0*a0+h*h);
      vec3 g; g.x=a0.x*x0.x+h.x*x0.y; g.yz=a0.yz*x12.xz+h.yz*x12.yw; return 130.0*dot(m,g); }
    float fbm(vec2 p){ float s=0.0,a=0.5; for(int i=0;i<2;i++){ s+=a*snoise(p); p*=2.02; a*=0.4; } return s; }
    void main() {
      vec2 uv=v_uv;
      vec2 p=vec2(uv.x*u_aspect,uv.y)*1.15;
      float t=u_time*0.025;
      p.x+=t*0.4;
      vec2 q=vec2(fbm(p+vec2(0.0,t)), fbm(p+vec2(3.1,-t)));
      vec2 r=vec2(fbm(p+1.3*q+vec2(1.7,t)), fbm(p+1.3*q+vec2(8.3,-t)));
      float d=fbm(p+1.6*r)*0.5+0.5;
      float density=smoothstep(0.35,1.0,d);
      float vfall=smoothstep(1.0,0.0,uv.y);
      density=(density*0.85+vfall*0.08)*vfall*u_strength;
      gl_FragColor=vec4(u_tint*density,density);
    }';
}
