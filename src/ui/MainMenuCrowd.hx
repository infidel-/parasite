// main menu crowd of human silhouettes drawn over the WebGL background.
// pseudo-3D: camera moves slowly forward, members hop sideways in arcs,
// new ones appear at the horizon, old ones recycle past the camera.

package ui;

import js.Browser;
import js.html.CanvasElement;
import js.html.CanvasRenderingContext2D;
import js.html.Image;

typedef _CrowdMember = {
  id: Int,            // monotonic, reassigned on recycle so parasite can detect host swap
  srcX: Int,          // pixel x in atlas
  srcW: Int,          // pixel width of this cell
  worldX: Float,      // anchor lateral position in world units
  worldZ: Float,      // depth in world units
  dir: Int,           // current walk direction (-1 or +1)
  stepsLeft: Int,     // steps remaining in current burst
  stepPhase: Float,   // 0..1 within current step
  stepSpeed: Float,   // 1/seconds per step
  stepDist: Float,    // lateral world-units per step
  pauseLeft: Float,   // seconds of pause remaining (>0 means pausing)
  hopAmp: Float,      // hop amplitude in world units
  forwardSpeed: Float, // world-Z units per second toward camera
};

@:expose
class MainMenuCrowd
{
  static inline var CELL_H = 192;
  // pixel widths of individual cells inside img/full-height.png (left-to-right)
  static var CELL_WIDTHS = [80, 80, 80, 80, 80, 80, 80, 160];
  static inline var MEMBER_COUNT = 40;
  static inline var TARGET_FPS = 30;
  static inline var FRAME_INTERVAL = 1000.0 / TARGET_FPS;

// camera and scene constants (world units, arbitrary)
  static inline var FOCAL = 600.0;
  static inline var CAM_HEIGHT = 220.0;
  static inline var NEAR_Z = 60.0;
  static inline var FAR_Z = 700.0;
  static inline var FADE_RANGE = 200.0;
  static inline var CAM_FORWARD_SPEED = 4.0;
  // mean per-member forward speed (world units / sec); randomized ±25%
  static inline var MEMBER_FORWARD_SPEED = 16.0;
  static inline var SPRITE_WORLD_HEIGHT = 220.0;
  // max silhouette opacity at full fade (0..1; lower = ghostlier)
  static inline var BASE_ALPHA = 0.1;
  // per-frame trail erase rate (0..1; higher = trail dissolves faster)
  static inline var TRAIL_DECAY = 0.05;

  // parasite face-jumper config
  static inline var PARASITE_SIT_MIN = 3.0;
  static inline var PARASITE_SIT_MAX = 5.0;
  static inline var PARASITE_JUMP_DUR = 0.75;
  // head anchor as fraction of sprite height from top
  static inline var PARASITE_HEAD_RATIO = 0.11;
  // parasite world width (scaled by host's perspective scale)
  static inline var PARASITE_WORLD_W = 80.0;
  static inline var PARASITE_NATIVE_W = 80.0;
  static inline var PARASITE_NATIVE_H = 60.0;
  // wide 2-person cell width — excluded from target pool
  static inline var WIDE_CELL_W = 160;
  static inline var PARASITE_STATE_WAIT = 0;
  static inline var PARASITE_STATE_RIDE = 1;
  static inline var PARASITE_STATE_JUMP = 2;
  // monotonic id counter for crowd members
  static var nextMemberID = 0;

  var canvas: CanvasElement;
  var ctx: CanvasRenderingContext2D;
  var atlasImg: Image;
  var atlasSil: CanvasElement;
  var atlasLoaded: Bool;
  var members: Array<_CrowdMember>;
  var spritePool: Array<{ srcX: Int, srcW: Int }>;
  var camZ: Float;
  var running: Bool;
  var visible: Bool;
  var animFrameId: Int;
  var lastRender: Float;
  var parentEl: js.html.Element;
  var lastDrawn: Int;
  var lastVisible: Int;
  // parasite icon flying between hosts
  var parasiteImg: Image;
  var parasiteSil: CanvasElement;
  var parasiteLoaded: Bool;
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

  public function new()
    {
      canvas = Browser.document.createCanvasElement();
      canvas.className = 'menu-crowd-canvas';
      ctx = canvas.getContext2d();
      atlasLoaded = false;
      running = false;
      visible = false;
      animFrameId = 0;
      lastRender = 0;
      lastDrawn = 0;
      lastVisible = 0;
      camZ = 0;
      members = [];
      spritePool = [];

      // load full-height crowd atlas
      atlasImg = new Image();
      atlasImg.onload = function() {
        atlasSil = bakeSilhouette(atlasImg);
        atlasLoaded = true;
        onAtlasReady();
      };
      atlasImg.src = 'img/full-height.png';

      // load parasite icon for host-jumping animation
      parasiteLoaded = false;
      parasiteState = PARASITE_STATE_WAIT;
      parasiteTargetID = -1;
      parasiteRenderX = 0;
      parasiteRenderY = 0;
      parasiteRenderScale = 1;
      parasiteImg = new Image();
      parasiteImg.onload = function() {
        // bake purple-tinted silhouette so parasite reads as a shadow
        parasiteSil = bakeSilhouette(parasiteImg, '#613961');
        parasiteLoaded = true;
      };
      parasiteImg.src = 'img/parasite-large.png';
    }

// build a tinted, alpha-preserving copy of an image (silhouette in given color)
  function bakeSilhouette(src: Image, color: String = '#000000'): CanvasElement
    {
      var c = Browser.document.createCanvasElement();
      c.width = src.naturalWidth;
      c.height = src.naturalHeight;
      var bctx = c.getContext2d();
      bctx.drawImage(src, 0, 0);
      bctx.globalCompositeOperation = 'source-in';
      bctx.fillStyle = color;
      bctx.fillRect(0, 0, c.width, c.height);
      bctx.globalCompositeOperation = 'source-over';
      return c;
    }

// fill spritePool from full-height atlas grid, then populate members
  function onAtlasReady()
    {
      if (!atlasLoaded)
        return;
      buildSpritePool();
      if (members.length == 0)
        spawnInitial();
    }

// gather every cell present in the full-height atlas (variable widths)
  function buildSpritePool()
    {
      spritePool = [];
      var x = 0;
      for (w in CELL_WIDTHS)
        {
          spritePool.push({ srcX: x, srcW: w });
          x += w;
        }
    }

// initial crowd spread: random z across full range so no horizon-only burst
  function spawnInitial()
    {
      members = [];
      for (_ in 0...MEMBER_COUNT)
        {
          var z = NEAR_Z + Math.random() * (FAR_Z - NEAR_Z);
          members.push(makeMember(z, true));
        }
    }

// create a member at a given depth (offset from camera)
  function makeMember(dz: Float, randomPhase: Bool): _CrowdMember
    {
      var s = spritePool[Std.random(spritePool.length)];
      var halfWidth = spawnHalfWidth();
      return {
        id: nextMemberID++,
        srcX: s.srcX,
        srcW: s.srcW,
        worldX: (Math.random() * 2 - 1) * halfWidth,
        worldZ: camZ + dz,
        dir: (Std.random(2) == 0 ? -1 : 1),
        stepsLeft: 3 + Std.random(4),
        stepPhase: randomPhase ? Math.random() : 0,
        stepSpeed: 1.3 + Math.random() * 0.8,
        stepDist: 6 + Math.random() * 5,
        pauseLeft: randomPhase ? Math.random() * 1.5 : 0,
        hopAmp: 5 + Math.random() * 3,
        forwardSpeed: MEMBER_FORWARD_SPEED * (0.75 + Math.random() * 0.5),
      };
    }

// world-X bound visible at depth dz (canvas half-width back-projected)
  function frustumHalfWidth(dz: Float): Float
    {
      var w = (canvas.width > 0 ? canvas.width : Browser.window.innerWidth);
      return (w * 0.5) * dz / FOCAL;
    }

// world-X spread for spawn: full visible width at far plane,
// so members appear distributed horizon-wide and naturally diverge as they approach
  function spawnHalfWidth(): Float
    {
      return frustumHalfWidth(FAR_Z);
    }

// recycle a member that has passed the camera back to the far plane
  function recycle(m: _CrowdMember)
    {
      var dz = FAR_Z + Math.random() * 30;
      var s = spritePool[Std.random(spritePool.length)];
      m.id = nextMemberID++;
      m.srcX = s.srcX;
      m.srcW = s.srcW;
      m.worldZ = camZ + dz;
      m.worldX = (Math.random() * 2 - 1) * spawnHalfWidth();
      m.dir = (Std.random(2) == 0 ? -1 : 1);
      m.stepsLeft = 3 + Std.random(4);
      m.stepPhase = 0;
      m.pauseLeft = Math.random() * 1.5;
      m.forwardSpeed = MEMBER_FORWARD_SPEED * (0.75 + Math.random() * 0.5);
    }

// expose canvas for DOM insertion
  public function getCanvas(): CanvasElement
    {
      return canvas;
    }

// start render loop and ensure canvas is in DOM
  public function show()
    {
      visible = true;
      if (canvas.parentElement == null && parentEl != null)
        // append to end so crowd canvas paints over MainMenuBackground canvas
        // (window child still on top via z-index/positioning)
        parentEl.appendChild(canvas);
      canvas.style.display = 'block';
      updateSize();
      // wipe any stale trail pixels left from previous show session
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      // reset timing so paused dt does not produce a giant jump
      lastRender = 0;
      // reset parasite roaming state on each menu show
      parasiteState = PARASITE_STATE_WAIT;
      parasiteTargetID = -1;
      if (!running)
        {
          running = true;
          animFrameId = Browser.window.requestAnimationFrame(render);
        }
    }

// stop render loop and detach canvas; member state persists
  public function hide()
    {
      visible = false;
      running = false;
      if (animFrameId != 0)
        {
          Browser.window.cancelAnimationFrame(animFrameId);
          animFrameId = 0;
        }
      if (canvas.parentElement != null)
        {
          parentEl = canvas.parentElement;
          canvas.remove();
        }
    }

// keep canvas size synced to window
  function updateSize()
    {
      var w = Browser.window.innerWidth;
      var h = Browser.window.innerHeight;
      if (canvas.width != w || canvas.height != h)
        {
          canvas.width = w;
          canvas.height = h;
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
      if (canvas.parentElement == null
          || canvas.parentElement.style.visibility == 'hidden')
        {
          running = false;
          animFrameId = 0;
          return;
        }

      // 30fps cap: bail this rAF tick if not enough time has elapsed
      if (lastRender != 0
          && timestamp - lastRender < FRAME_INTERVAL)
        {
          animFrameId = Browser.window.requestAnimationFrame(render);
          return;
        }
      var dt = (lastRender == 0 ? 1.0 / TARGET_FPS : (timestamp - lastRender) / 1000.0);
      // clamp big gaps (tab background, hide pause) so motion doesn't teleport
      if (dt > 0.1)
        dt = 0.1;
      lastRender = timestamp;

      updateSize();
      if (atlasLoaded && members.length > 0)
        {
          step(dt);
          updateParasite(dt);
          drawCrowd();
          drawParasite();
          // periodic snapshot
          if (Std.random(120) == 0)
            {
              var minZ = 1e9, maxZ = -1e9;
              var minX = 1e9, maxX = -1e9;
              for (m in members)
                {
                  if (m.worldZ < minZ) minZ = m.worldZ;
                  if (m.worldZ > maxZ) maxZ = m.worldZ;
                  if (m.worldX < minX) minX = m.worldX;
                  if (m.worldX > maxX) maxX = m.worldX;
                }
            }
        }
      else if (canvas.width > 0 && canvas.height > 0)
        ctx.clearRect(0, 0, canvas.width, canvas.height);

      animFrameId = Browser.window.requestAnimationFrame(render);
    }

// advance camera and walk state for every member
  function step(dt: Float)
    {
      camZ += CAM_FORWARD_SPEED * dt;
      for (m in members)
        {
          // forward only while stepping (hop = forward stride); paused = freeze depth
          if (m.pauseLeft <= 0)
            m.worldZ -= m.forwardSpeed * dt;
          if (m.pauseLeft > 0)
            {
              m.pauseLeft -= dt;
              if (m.pauseLeft <= 0)
                {
                  m.stepsLeft = 13 + Std.random(4);
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
          // lateral recycle when member projects beyond canvas edge
          else if (Math.abs(m.worldX) > frustumHalfWidth(dzNow) * 1.05)
            recycle(m);
        }
    }

// project and draw all members; sort by depth so near sprites are on top
  function drawCrowd()
    {
      // ghostly trail: fade existing pixels instead of clearing,
      // so old sprite positions linger then dissolve to background
      ctx.globalCompositeOperation = 'destination-out';
      ctx.fillStyle = 'rgba(0,0,0,' + TRAIL_DECAY + ')';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.globalCompositeOperation = 'source-over';
      ctx.imageSmoothingEnabled = true;
      untyped ctx.imageSmoothingQuality = 'high';
      var drawnCount = 0, visibleCount = 0;
      // sort descending by worldZ so we paint far-first
      members.sort(function(a, b) {
        return (b.worldZ < a.worldZ ? -1 : (b.worldZ > a.worldZ ? 1 : 0));
      });
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
          // aspect-correct on-screen width per cell
          var spriteW = spriteH * (m.srcW / CELL_H);
          var drawX = Math.round(screenX - spriteW * 0.5);
          var drawY = Math.round(groundY - spriteH - hopY);
          // depth fade: members spawn-in from horizon
          var fade = (FAR_Z - dz) / FADE_RANGE;
          if (fade > 1) fade = 1;
          if (fade < 0) fade = 0;
          ctx.globalAlpha = BASE_ALPHA * fade;
          // skip offscreen draws to keep counter meaningful
          if (drawX + spriteW < 0 || drawX > canvas.width
              || drawY + spriteH < 0 || drawY > canvas.height)
            continue;
          drawnCount++;
          if (fade > 0)
            visibleCount++;
          ctx.drawImage(atlasSil,
            m.srcX, 0,
            m.srcW, CELL_H,
            drawX, drawY, spriteW, spriteH);
        }
      ctx.globalAlpha = 1.0;
      lastDrawn = drawnCount;
      lastVisible = visibleCount;
    }

// find a crowd member by id (linear scan — pool is small)
  function findMemberByID(targetID: Int): _CrowdMember
    {
      for (m in members)
        if (m.id == targetID)
          return m;
      return null;
    }

// pick a non-wide host close to the reference screen point; null if none available
  function pickParasiteTarget(refX: Float, refY: Float, excludeID: Int): _CrowdMember
    {
      var pool = [];
      for (m in members)
        {
          var dz = m.worldZ - camZ;
          // skip too-near, too-far, the 2-person wide cell, and the current host
          if (dz < NEAR_Z + 80
              || dz > FAR_Z - 150
              || m.srcW >= WIDE_CELL_W
              || m.id == excludeID)
            continue;
          var p = projectFace(m);
          var dx = p.x - refX;
          var dy = p.y - refY;
          pool.push({ m: m, d2: dx * dx + dy * dy });
        }
      if (pool.length == 0)
        return null;
      // sort ascending by squared screen distance, sample from nearest few
      pool.sort(function(a, b) {
        return (a.d2 < b.d2 ? -1 : (a.d2 > b.d2 ? 1 : 0));
      });
      var k = (pool.length < 4 ? pool.length : 4);
      return pool[Std.random(k)].m;
    }

// project member's head/face anchor to screen space, including hop offset
  function projectFace(m: _CrowdMember): { x: Float, y: Float, scale: Float }
    {
      var dz = m.worldZ - camZ;
      if (dz < NEAR_Z)
        dz = NEAR_Z;
      var scale = FOCAL / dz;
      var halfW = canvas.width * 0.5;
      var horizonY = canvas.height * 0.4;
      var screenX = halfW + m.worldX * scale;
      var groundY = horizonY + CAM_HEIGHT * scale;
      var hopY = (m.pauseLeft > 0
        ? 0
        : Math.sin(m.stepPhase * Math.PI) * m.hopAmp * scale);
      var spriteH = SPRITE_WORLD_HEIGHT * scale;
      var faceY = (groundY - spriteH - hopY) + spriteH * PARASITE_HEAD_RATIO;
      return { x: screenX, y: faceY, scale: scale };
    }

// snapshot current render position, pick new host, transition to jump state
  function startJumpFromCurrent()
    {
      var t = pickParasiteTarget(parasiteRenderX, parasiteRenderY, parasiteTargetID);
      if (t == null)
        {
          // no valid target this frame — back to WAIT, retry on next tick
          parasiteState = PARASITE_STATE_WAIT;
          parasiteTargetID = -1;
          return;
        }
      parasiteFromX = parasiteRenderX;
      parasiteFromY = parasiteRenderY;
      parasiteFromScale = parasiteRenderScale;
      parasiteTargetID = t.id;
      parasiteJumpT = 0;
      parasiteState = PARASITE_STATE_JUMP;
    }

// advance parasite state machine — handles wait/ride/jump and host recycle
  function updateParasite(dt: Float)
    {
      if (!parasiteLoaded)
        return;
      switch (parasiteState)
        {
          case PARASITE_STATE_WAIT:
            // first acquisition: fly in from above the screen, picking a host near top-center
            var refX = canvas.width * 0.5;
            var refY = canvas.height * 0.4;
            var t = pickParasiteTarget(refX, refY, -1);
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
            parasiteState = PARASITE_STATE_JUMP;
          case PARASITE_STATE_RIDE:
            // detect host recycle: id will be missing
            if (findMemberByID(parasiteTargetID) == null)
              {
                startJumpFromCurrent();
                return;
              }
            parasiteSitTimer -= dt;
            if (parasiteSitTimer <= 0)
              startJumpFromCurrent();
          case PARASITE_STATE_JUMP:
            parasiteJumpT += dt / PARASITE_JUMP_DUR;
            if (parasiteJumpT >= 1.0)
              {
                // arrival: confirm target still alive, else re-jump
                if (findMemberByID(parasiteTargetID) == null)
                  {
                    startJumpFromCurrent();
                    return;
                  }
                parasiteState = PARASITE_STATE_RIDE;
                parasiteJumpT = 0;
                parasiteSitTimer = PARASITE_SIT_MIN
                  + Math.random() * (PARASITE_SIT_MAX - PARASITE_SIT_MIN);
              }
        }
    }

// draw parasite icon at current state position; trail-decay produces smear
  function drawParasite()
    {
      if (!parasiteLoaded
          || parasiteState == PARASITE_STATE_WAIT)
        return;
      var m = findMemberByID(parasiteTargetID);
      if (m == null)
        return;
      var p = projectFace(m);
      var x: Float, y: Float, scale: Float;
      if (parasiteState == PARASITE_STATE_RIDE)
        {
          x = p.x;
          y = p.y;
          scale = p.scale;
        }
      else
        {
          // smoothstep ease for natural in/out
          var t = parasiteJumpT;
          if (t > 1) t = 1;
          var te = t * t * (3 - 2 * t);
          x = parasiteFromX + (p.x - parasiteFromX) * te;
          y = parasiteFromY + (p.y - parasiteFromY) * te;
          // parabolic arc: peak at t=0.5, height grows with horizontal distance
          var dx = p.x - parasiteFromX;
          var arcH = 80 + Math.abs(dx) * 0.15;
          y -= arcH * 4 * te * (1 - te);
          scale = parasiteFromScale + (p.scale - parasiteFromScale) * te;
        }
      parasiteRenderX = x;
      parasiteRenderY = y;
      parasiteRenderScale = scale;
      var w = PARASITE_WORLD_W * scale;
      var h = w * (PARASITE_NATIVE_H / PARASITE_NATIVE_W);
      // match host fade, then 20% more transparent so parasite reads slightly lighter
      var dz = m.worldZ - camZ;
      var fade = (FAR_Z - dz) / FADE_RANGE;
      if (fade > 1) fade = 1;
      if (fade < 0) fade = 0;
      ctx.globalAlpha = BASE_ALPHA * fade * 0.5;
      ctx.drawImage(parasiteSil,
        x - w * 0.5, y - h * 0.5, w, h);
      ctx.globalAlpha = 1.0;
    }
}
