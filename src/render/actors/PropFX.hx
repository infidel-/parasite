package render.actors;

import three.Three;
import citygen.CityConfig;
import game.Game;
import objects.AreaObject;
import objects.HabitatObject;
import render.RenderConfig;
import render.particles.Sprites;
import render.world.ObjModels;
import render.actors.BoltOpts;
import render.world.ObjModels.PropArc;
import render.world.ObjModels.PropCore;
import render.world.ObjModels.PropFly;
import render.world.PropShader.ShaderPatch;
import render.world.WorldCtx;

// the per-slot uniform bag for one core quad, held BY IDENTITY: writing .value here reaches the
// compiled shader with no bookkeeping, the same uniform sharing render.sewer.SewerMask relies on.
// one bag per pool slot rather than one shared bag, because the phase is what stops two organs of
// the same kind in one level from writhing in lockstep
typedef CoreUniforms = {
  phase:{ value:Float }, // per-cell phase offset
  warp:{ value:Float },  // uv disturbance amplitude
  rate:{ value:Float },  // disturbance speed
};

// the grown props' LIVING FX: additive quads glued to a prop, on top of the vertex motion
// render.world.PropShader already folds into its geometry. two of them, both driven off one clock:
//   CORE  — a knot of innards hung inside the prop, breathing on a slow scale beat (pure CPU) with
//           its map UVs disturbed in the FRAGMENT shader, so the mass writhes instead of merely
//           resizing. the assimilation arch is a DOORWAY with nothing behind it, so its core hangs
//           in the opening and reads as a membrane stretched across the arch.
//   FLIES — one firefly per habitat LEVEL, orbiting a tilted ring. HDR-tinted so the composer's
//           bloom pass gives them their halo, over a sprite that already carries painted flare
//           spikes; that pairing is what the "fake lens flare" is.
//
// WHICH props get either is not decided here — it is the `core` and `fly` columns of
// render.world.ObjModels.MODELS, and a null column is simply never drawn.
//
// modelled on render.actors.LampShadows, which is this codebase's shape for the job: constructed by
// render.Actors, walks the area's objects itself, world-anchors FX to them, drives pooled quads, and
// holds NO per-area state — so an organ grown under the player draws on the frame it appears with no
// rebuild hook, and one destroyed stops drawing because it stops being found.
//
// it deliberately does NOT borrow render.particles.Sparks' pool, though the firefly quad is exactly
// what glowQuad draws. That pool's slots are reused by arbitrary callers every frame, so the core's
// per-slot shader patch would leak into whatever drew in that slot next; Sparks resets map, colour
// and opacity per call but has no uniform reset, and adding one would pollute a shared pool for a
// single caller. Its entry points are also both at seven positional args already
class PropFX {
  static var texCache:Map<String, Texture> = new Map();
  // scratch for the lightning tint, so the per-frame ribbon rebuild allocates no Colors
  static var arcTint = new Color();
  // the clock every core material references BY IDENTITY, in BASE_MS units — so the per-prop `rate`
  // values on the table row are plain multipliers, exactly as render.world.PropShader's are
  static var uTime = { value: 0.0 };

  var game:Game;
  var group:Group;                        // scene group the quads live in (the actor group)
  var quad:PlaneGeometry;                 // one unit plane shared by every quad here
  var cores:Array<Mesh> = [];             // core pool
  var coreMat:Array<MeshBasicMaterial> = []; // and its materials, one per slot (each own uniforms)
  var coreU:Array<CoreUniforms> = [];     // indexed with cores
  var flies:Array<Mesh> = [];             // firefly pool
  var flyMat:Array<MeshBasicMaterial> = [];
  // the lightning. ONE mesh and ONE draw call for every bolt on every prop in the level: a ribbon
  // rebuilt from scratch each frame, the shape render.particles.SlimeTrail already uses. a pooled
  // quad per segment would have been 30 calls for six 5-segment bolts
  var bolts:Mesh;
  var boltGeo:BufferGeometry;
  var boltPos:Array<Float> = [];
  var boltCol:Array<Float> = [];
  var boltIdx:Array<Int> = [];
  var ci:Int = 0;                         // next free core slot this frame
  var fi:Int = 0;                         // next free firefly slot this frame
  var t:Float = 0.0;                      // shared clock, in BASE_MS units

  public function new(game:Game, actorGroup:Group)
    {
      this.game = game;
      this.group = actorGroup;
      quad = new PlaneGeometry(1, 1);
      boltGeo = new BufferGeometry();
      bolts = new Mesh(boltGeo, boltMaterial());
      bolts.renderOrder = Sprites.ORD_ACTOR;
      bolts.visible = false;
      // the ribbon is rebuilt in WORLD coordinates every frame, so three must not frustum-test it
      // against a bounding sphere computed for whatever it happened to hold last frame
      untyped bolts.frustumCulled = false;
      group.add(bolts);
    }

// place every visible prop's FX for this frame, then hide the pool tail. call once per frame from
// render.Actors.update. owns its own pools, so it does not have to sit inside the Sparks frame
  public function update(dtMs:Float):Void
    {
      ci = 0;
      fi = 0;
      boltPos.splice(0, boltPos.length);
      boltCol.splice(0, boltCol.length);
      boltIdx.splice(0, boltIdx.length);
      if (RenderConfig.PROP_FX.enabled)
        {
          t += dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
          uTime.value = t;
          var los = game.player.vars.losEnabled;
          // walked from the area every frame rather than cached at area build, for the reason
          // render.particles.PropLights states: the list is a handful of objects, render.Actors
          // already asks modelFor() about every one of them on the same frame, and a cache would
          // need an invalidation hook on every add and remove
          for (o in game.area.getObjects())
            {
              var m = ObjModels.modelFor(o.getModelKey());
              if (m == null ||
                  (m.core == null &&
                   m.fly == null &&
                   m.arc == null))
                continue;
              // these quads are NOT patched with the tunnel vision mask (nothing in the sprite or
              // spark layers is), so the fog does not hide them and LOS is the only thing that can.
              // without this a firefly would burn merrily in a room the player has never entered
              if (los &&
                  !game.playerArea.sees(o.x, o.y))
                continue;
              var w = CityConfig.cellToWorld(o.x, o.y);
              var floor = WorldCtx.floorY(o.x, o.y);
              // per-cell phase: two organs of a kind in one level never move together, and nothing
              // has to be stored per object. the hash LampShadows.gatherBarrels already uses
              var ph = o.x * 12.9898 + o.y * 78.233;
              if (m.core != null)
                drawCore(m.core, m.h, w.x, floor, w.z, ph);
              if (m.fly != null)
                drawFlies(m.fly, m.h, w.x, floor, w.z, ph, level(o) * m.fly.perLevel);
              if (m.arc != null)
                drawArcs(m.arc, m.h, w.x, floor, w.z, ph, level(o) * m.arc.perLevel);
            }
        }
      uploadBolts();
      for (i in ci...cores.length)
        cores[i].visible = false;
      for (i in fi...flies.length)
        flies[i].visible = false;
    }

// how many fireflies orbit this object: its habitat level. anything that is not a habitat organ
// gets one, which no shipped row can reach — the exit ladder carries no `fly` column
  inline function level(o:AreaObject):Int
    {
      var h = Std.downcast(o, HabitatObject);
      return h != null ? h.level : 1;
    }

// the innards quad: frontal (fixed yaw, leaned back by Sprites.TILT like the actor sprites — the
// rule for anything glued to a world entity), breathing on a slow scale beat. the WRITHE is the
// shader's half; this only sets its uniforms and the size
  function drawCore(c:PropCore, h:Float, x:Float, floor:Float, z:Float, ph:Float):Void
    {
      var m = coreSlot(c.tex);
      var u = coreU[ci];
      u.phase.value = ph;
      u.warp.value = c.warp;
      u.rate.value = c.warpRate;
      var mat = coreMat[ci];
      mat.opacity = c.alpha;
      // HDR: past 1 is what carries it over the bloom threshold, the recipe render.TacticalGrid and
      // render.PathLine use. toneMapped is deliberately left alone — three forces every material to
      // NoToneMapping while rendering into the composer's targets, so the flag is inert here, and it
      // IS part of the program cache key, so flipping it per frame would be churn for nothing
      mat.color.setHex(c.color);
      mat.color.multiplyScalar(c.glow);
      var s = h * c.size * (1 + c.pulse * Math.sin(t * c.pulseRate + ph));
      m.position.set(x, floor + h * c.y, z + h * c.z);
      m.rotation.set(-c.lean, 0, 0);
      m.scale.set(s, s, 1);
      m.renderOrder = Sprites.ORD_ACTOR;
      m.visible = true;
      ci++;
    }

// the fireflies: n of them flying round the prop MOSTLY PARALLEL TO THE FLOOR, each on a path of its
// own. they are evenly spaced only at t = 0 — from there every dot runs its own radius, height, speed
// and small plane tilt, breathes the radius slowly and wanders vertically on a separate beat, so the
// swarm drifts apart and re-crosses instead of holding formation. what reads as 3D is the HEIGHT
// SPREAD plus the prop itself occluding whichever dots are on the far side (depthTest stays on, see
// the pool below); a tilted ring was tried first and just looked like a hoop turning
  function drawFlies(f:PropFly, h:Float, x:Float, floor:Float, z:Float, ph:Float, n:Int):Void
    {
      var step = 2 * Math.PI / n;
      var seg = f.trail + 1;
      for (i in 0...n)
        {
          // four stable per-dot rolls. keyed on the CELL phase as well as the index, so two organs of
          // a kind in one level do not fly the same swarm — and, like the phase itself, this is
          // derived rather than stored, so a firefly needs no state and no spawn/despawn bookkeeping
          var h1 = roll(ph + i * 12.9898);
          var h2 = roll(ph + i * 78.233 + 3.7);
          var h3 = roll(ph + i * 37.719 + 11.3);
          var h4 = roll(ph + i * 21.317 + 27.1);
          var spin = f.rate * (1 + f.rateVar * (h1 * 2 - 1));
          var base = i * step + ph;
          var tl = f.tilt * (h3 * 2 - 1);
          var cy = floor + h * (f.y + f.yVar * (h4 * 2 - 1));
          // the head at j = 0, then the tail behind it — sampled by evaluating the SAME path at
          // earlier clock values rather than remembering where the dot has been. the orbit is a
          // closed form in `t`, so a past position is exact and costs one more evaluation, while a
          // history buffer would be state to allocate, seed on first sight and invalidate on every
          // area rebuild. it also means the tail is correct on the frame a prop first appears
          for (j in 0...seg)
            {
              var ts = t - j * f.trailGap;
              var k = 1 - j / seg; // 1 at the head, easing to 0 down the tail
              var a = ts * spin + base;
              // radius: the dot's own offset off the base, breathing on top at half that depth —
              // which is what stops the path being a circle
              var rad = h * f.r * (1 + f.rVar * (h2 * 2 - 1)) *
                (1 + f.rVar * 0.5 * Math.sin(ts * spin * 0.37 + h3 * 2 * Math.PI));
              var rx = Math.cos(a) * rad;
              var rz = Math.sin(a) * rad;
              var m = flySlot(f.tex);
              var mat = flyMat[fi];
              // twinkle: dips to alpha * (1 - twinkle) and back on a beat of its own. sampled at the
              // segment's OWN past time, so the tail carries the head's brightness history instead of
              // a flat ramp. k * k on top of it — a comet falls off faster than linear, and linear
              // reads as a dashed line
              mat.opacity = f.alpha * k * k *
                (1 - f.twinkle * (0.5 - 0.5 * Math.sin(ts * spin * 2.3 + h4 * 2 * Math.PI)));
              mat.color.setHex(f.color);
              mat.color.multiplyScalar(f.glow);
              m.position.set(x + rx,
                cy - rz * Math.sin(tl) + h * f.bob * Math.sin(ts * spin * 0.61 + h1 * 2 * Math.PI),
                z + rz * Math.cos(tl));
              m.rotation.set(-Sprites.TILT, 0, 0);
              var q = h * f.size * (f.trailSize + (1 - f.trailSize) * k);
              m.scale.set(q, q, 1);
              m.renderOrder = Sprites.ORD_ACTOR;
              m.visible = true;
              fi++;
            }
        }
    }

// the lightning: n slots, each striking on its own beat somewhere round the prop. every bolt appends
// into the shared ribbon buffers, so the whole level's discharge is one draw call however many props
// are crackling. nothing is stored per bolt — a slot's life is derived from which TIME BUCKET the
// clock is in, so the bucket index is what seeds where this strike lands and the position inside the
// bucket is its age. that is the shape RenderConfig.BLOOD's black-blood glints already use, and it
// means a bolt is correct on the frame a prop first appears and needs no spawn or despawn hook
  function drawArcs(a:PropArc, h:Float, x:Float, floor:Float, z:Float, ph:Float, n:Int):Void
    {
      arcTint.setHex(a.color);
      // the resting camera's view direction, ~53 degrees down and looking along -Z. it is used ONLY
      // to face the ribbon and never to place it, which is why a fixed value is honest here: the
      // whole sprite layer already assumes this camera (Sprites.TILT, PropYaw.FRONTAL), and a bolt
      // is on screen for a quarter of a second
      var vx = 0.0;
      var vy = -0.8;
      var vz = -0.6;
      for (i in 0...n)
        {
          // which strike this slot is on, and how far through it we are. `cyc` grows forever, so the
          // bucket is a fresh integer per strike and every one lands somewhere new
          var cyc = t / a.period + roll(ph + i * 61.7);
          var bucket = Math.floor(cyc);
          var s = (cyc - bucket) / a.duty; // 0..1 over the bolt's life, past 1 = dark
          if (s >= 1)
            continue;
          var b1 = roll(bucket * 12.9898 + i * 78.233 + ph);
          var b2 = roll(bucket * 37.719 + i * 21.317 + ph + 3.7);
          var b3 = roll(bucket * 53.113 + i * 91.700 + ph + 11.3);
          var b4 = roll(bucket * 17.310 + i * 44.900 + ph + 27.1);
          // where it strikes: a height, then a point on the body's OWN SURFACE at that height —
          // radius narrowed by the prop's taper, at an azimuth round its vertical axis. on the
          // surface and not inside it: a strike point within the body puts the first half of the
          // bolt behind it, which is what four earlier placement attempts were really fighting.
          //
          // the AZIMUTH is what lets a bolt travel toward the camera. it is centred on world +Z (the
          // resting camera's direction) and spans +/- `az`, so bolts fan forward and across both
          // flanks; a half-range rather than a full circle because a strike on the far side is
          // simply hidden behind the crystal
          var sy = h * (a.y + a.yVar * (b2 * 2 - 1));
          var rad = h * a.r * (1 + (a.rTop - 1) * (sy / h));
          var azm = Math.PI * 0.5 + a.az * (b1 * 2 - 1);
          var ox = Math.cos(azm);
          var oz = Math.sin(azm);
          var sx = x + ox * rad;
          var syw = floor + sy;
          var sz = z + oz * rad;
          // and it leaves straight OUT along that azimuth, swung up or down by `spread`
          var sw = a.spread * (b3 * 2 - 1);
          var cs = Math.cos(sw);
          var dx = ox * cs;
          var dy = Math.sin(sw);
          var dz = oz * cs;
          var len = h * a.len * (1 + a.lenVar * (b4 * 2 - 1));
          var ex = sx + dx * len;
          var ey = syw + dy * len;
          var ez = sz + dz * len;
          // the width axis: perpendicular to BOTH the bolt and the view, so a bolt aimed at the
          // camera still shows its full width instead of going edge-on and vanishing. one axis
          // serves the kink as well, which keeps the zigzag facing the camera too
          var nx = dy * vz - dz * vy;
          var ny = dz * vx - dx * vz;
          var nz = dx * vy - dy * vx;
          var nl = Math.sqrt(nx * nx + ny * ny + nz * nz);
          // a bolt aimed exactly along the view has no such axis, and normalizing a zero vector is
          // NaN — not a cosmetic bug here: ONE NaN texel goes through the bloom downsample and
          // blacks out the WHOLE frame, which this log already carries an entry for. any axis will
          // do in that case, because the bolt is a point on screen
          if (nl < 1e-4)
            {
              nx = 1;
              ny = 0;
              nz = 0;
              nl = 1;
            }
          nx /= nl;
          ny /= nl;
          nz /= nl;
          // a discharge does not fade smoothly, it stutters out: a linear decay with a few sub
          // flashes riding it. the sine's floor is 0.10, so this never goes negative
          var bright = (1 - s) * (0.55 + 0.45 * Math.sin(s * 21.0 + b1 * 2 * Math.PI));
          // TWO ribbons down the SAME path: a wide soft halo, then the hot core over it. the halo is
          // there for the BLOOM PASS, and it is not optional decoration — measured, the core thread
          // alone produced NO halo at all (p95 fell 230 -> 32 in one pixel, against a wall lamp's
          // smooth 245 -> 183 -> 111 -> 72 -> 50), because bloom output scales with the AREA of
          // over-threshold pixels and a ~5px thread has almost none. Raising `glow` does not fix it:
          // at 12 the core read the same 230 (ACES saturates it) and still had no skirt. The same
          // ribbon at 7x the width haloed exactly like the lamp, which is what this pass buys back
          var o:BoltOpts = {
            arc: a,
            h: h,
            ph: ph,
            bucket: bucket,
            slot: i,
            sx: sx,
            sy: syw,
            sz: sz,
            ex: ex,
            ey: ey,
            ez: ez,
            nx: nx,
            ny: ny,
            nz: nz,
            bright: bright * a.haloDim,
            wMul: a.halo,
            edge: 0.0,
          };
          boltRibbon(o);
          o.bright = bright;
          o.wMul = 1.0;
          o.edge = 1.0;
          boltRibbon(o);
        }
    }

// emit one pass of one bolt: THREE vertices per station (left edge, centreline, right edge) and four
// triangles per segment, so a pass can carry a real cross-section gradient instead of a flat bar.
// the core pass sets edge and centre alike and reads as a bright thread with a hard edge; the halo
// pass sets the edges to 0, and that falloff is the whole difference between a flare and a plank
  function boltRibbon(o:BoltOpts):Void
    {
      var a = o.arc;
      var v0 = Std.int(boltPos.length / 3);
      for (k in 0...(a.segs + 1))
        {
          var f = k / a.segs;
          // the kink. belled to 0 at the ROOT only — the bolt has to start on the body, but a tip
          // that also tapers to the centreline reads as a smooth worm rather than as an arc that
          // snapped somewhere. sqrt puts the bell's rise inside the first segment.
          // keyed on the bucket and the slot and NOT on the pass, which is what keeps the halo on
          // exactly the zigzag the core runs down
          var kink = o.h * a.jag * Math.sqrt(f) *
            (roll(o.bucket * 7.13 + o.slot * 3.7 + k * 29.3 + o.ph) * 2 - 1);
          var cx = o.sx + (o.ex - o.sx) * f + o.nx * kink;
          var cy = o.sy + (o.ey - o.sy) * f + o.ny * kink;
          var cz = o.sz + (o.ez - o.sz) * f + o.nz * kink;
          var w = o.h * a.width * o.wMul * (1 - (1 - a.taper) * f);
          boltVert(cx + o.nx * w, cy + o.ny * w, cz + o.nz * w);
          boltVert(cx, cy, cz);
          boltVert(cx - o.nx * w, cy - o.ny * w, cz - o.nz * w);
          // brightest at the root, where the current is leaving the crystal
          var c = o.bright * (1 - f * 0.75) * a.glow;
          boltColour(c * o.edge);
          boltColour(c);
          boltColour(c * o.edge);
          if (k < a.segs)
            {
              // two quads per segment, centreline to each edge. winding is irrelevant: the material
              // is DoubleSide, and additive blending has no order to get wrong
              var q = v0 + k * 3;
              boltIdx.push(q);
              boltIdx.push(q + 3);
              boltIdx.push(q + 1);
              boltIdx.push(q + 1);
              boltIdx.push(q + 3);
              boltIdx.push(q + 4);
              boltIdx.push(q + 1);
              boltIdx.push(q + 4);
              boltIdx.push(q + 2);
              boltIdx.push(q + 2);
              boltIdx.push(q + 4);
              boltIdx.push(q + 5);
            }
        }
    }

// one ribbon vertex. the plane is upright and at the prop's own depth, so a bolt's root sits at the
// crystal's mid-depth and the near half of the body occludes it — which is the read wanted, an arc
// emerging from inside the mineral rather than one pasted over its silhouette
  inline function boltVert(wx:Float, wy:Float, wz:Float):Void
    {
      boltPos.push(wx);
      boltPos.push(wy);
      boltPos.push(wz);
    }

// one ribbon vertex colour. HDR: the tint is LINEAR (Color.setHex decodes sRGB) and `c` already
// carries the row's glow, so a peak lands well over BLOOM_THRESHOLD and the bloom pass is the flare.
// there is no alpha channel here on purpose — additive blending means brightness IS the opacity
  inline function boltColour(c:Float):Void
    {
      boltCol.push(arcTint.r * c);
      boltCol.push(arcTint.g * c);
      boltCol.push(arcTint.b * c);
    }

// hand this frame's ribbon to the GPU, or hide the mesh if nothing struck. fresh attributes rather
// than a preallocated buffer with a draw range, which is what render.particles.SlimeTrail does and
// what the counts here justify: six 5-segment bolts is 72 vertices
  function uploadBolts():Void
    {
      if (boltIdx.length == 0)
        {
          bolts.visible = false;
          return;
        }
      boltGeo.setAttribute('position', new Float32BufferAttribute(boltPos, 3));
      boltGeo.setAttribute('color', new Float32BufferAttribute(boltCol, 3));
      boltGeo.setIndex(boltIdx);
      bolts.visible = true;
    }

// a stable 0..1 off one float seed. the standard fract(sin(x) * k) hash, which is what the cell phase
// this feeds already is — deterministic, so a firefly's own radius, height and speed are the same on
// every frame and after every reload, with nothing stored anywhere
  inline function roll(seed:Float):Float
    {
      var v = Math.sin(seed) * 43758.5453;
      return v - Math.floor(v);
    }

// get (or lazily build) the next core quad, bound to `tex`. each slot owns its material AND its
// uniform bag: they are what carry the per-prop phase, so they cannot be shared across slots
  function coreSlot(path:String):Mesh
    {
      var m = cores[ci];
      if (m == null)
        {
          var u:CoreUniforms = {
            phase: { value: 0.0 },
            warp: { value: 0.0 },
            rate: { value: 0.0 },
          };
          var mat = coreMaterial(path, u);
          m = new Mesh(quad, mat);
          cores[ci] = m;
          coreMat[ci] = mat;
          coreU[ci] = u;
          group.add(m);
        }
      coreMat[ci].map = texture(path);
      return m;
    }

// get (or lazily build) the next firefly quad, bound to `tex`. a plain additive quad — the same
// material render.particles.Sparks.glowQuad builds, so it shares that program and costs no compile
  function flySlot(path:String):Mesh
    {
      var m = flies[fi];
      if (m == null)
        {
          var mat = baseMaterial(path);
          m = new Mesh(quad, mat);
          flies[fi] = m;
          flyMat[fi] = mat;
          group.add(m);
        }
      flyMat[fi].map = texture(path);
      return m;
    }

// the plain additive quad material both pools start from. depthWrite off (nothing here should mask
// what is behind it) but depthTest deliberately ON: that is what lets the arch's near braids occlude
// the membrane hung in its opening and the far half of the firefly ring pass behind the body.
//
// forceSinglePass is worth DOUBLE the whole feature's cost and is not optional. three renders a
// transparent DoubleSide material as TWO single-side passes (side FrontSide, then BackSide), each a
// draw call and each its own program — measured here at +32 calls for 16 quads before this flag went
// on, +16 after. what the split buys is correct back-to-front ordering between the two faces, and
// ADDITIVE blending is commutative, so there is nothing to order. DoubleSide itself stays: these are
// fixed-yaw quads and the player can orbit the camera behind them
  static function baseMaterial(path:String):MeshBasicMaterial
    {
      return new MeshBasicMaterial({
        map: texture(path),
        transparent: true,
        depthWrite: false,
        side: THREE.DoubleSide,
        forceSinglePass: true,
        blending: THREE.AdditiveBlending,
      });
    }

// the lightning ribbon's material. `vertexColors` is what carries both the fade along a bolt and its
// decay over its own life — no map, no per-bolt uniform and no opacity write, because under additive
// blending brightness IS the opacity and a vertex colour of 0 adds nothing. same forceSinglePass as
// the quads above: DoubleSide is needed (the ribbon is a flat shape the player can orbit behind) and
// without the flag three would draw it as two single-side passes for two calls instead of one
  static function boltMaterial():MeshBasicMaterial
    {
      return new MeshBasicMaterial({
        vertexColors: true,
        transparent: true,
        depthWrite: false,
        side: THREE.DoubleSide,
        forceSinglePass: true,
        blending: THREE.AdditiveBlending,
      });
    }

// a core quad's material, with the uv disturbance folded in. patched ONCE, at creation: this
// material is ours alone, nothing else chains onto it and three never clones it, so none of the
// mark-forwarding render.world.PropShader has to do applies here
  static function coreMaterial(path:String, u:CoreUniforms):MeshBasicMaterial
    {
      var mat = baseMaterial(path);
      // Dynamic at a real boundary, not for convenience: three's material externs declare no
      // onBeforeCompile and no customProgramCacheKey, and cannot without a Material supertype —
      // Standard, Basic and Lambert are three unrelated classes in three.Three (render.world
      // .PropShader carries the same note for the same reason)
      var d:Dynamic = mat;
      d.onBeforeCompile = function(shader:ShaderPatch, _)
        {
          shader.uniforms.coreTime = uTime;
          shader.uniforms.corePhase = u.phase;
          shader.uniforms.coreWarp = u.warp;
          shader.uniforms.coreWarpRate = u.rate;
          // <map_fragment> is the ONLY tap of the base-colour map, so replacing it whole IS the
          // disturbance. the two sines beat at 0.83 of each other so the mass never traces a
          // straight line back and forth — the shape render.world.PropShader's sway uses. the
          // chunk's DECODE_VIDEO_TEXTURE branch is dropped: it is a VideoTexture path only, and
          // nothing here can ever set one
          shader.fragmentShader =
            'uniform float coreTime;\n' +
            'uniform float corePhase;\n' +
            'uniform float coreWarp;\n' +
            'uniform float coreWarpRate;\n' +
            StringTools.replace(shader.fragmentShader, '#include <map_fragment>',
              '#ifdef USE_MAP\n' +
              '  vec2 coreUv = vMapUv;\n' +
              '  coreUv.x += coreWarp * sin( vMapUv.y * 9.0 + coreTime * coreWarpRate + corePhase );\n' +
              '  coreUv.y += coreWarp * sin( vMapUv.x * 7.0 - coreTime * coreWarpRate * 0.83 + corePhase * 1.7 );\n' +
              '  diffuseColor *= texture2D( map, coreUv );\n' +
              '#endif');
        };
      // three keys its program cache on base material params and NOT on onBeforeCompile, so without
      // a key of our own the disturbed program could be handed to a firefly quad, which shares every
      // other parameter with this one
      d.customProgramCacheKey = function() return 'propCore';
      return mat;
    }

// load one FX texture, once per path. ClampToEdgeWrapping is load-bearing for the core: a disturbed
// uv leaves 0..1 at the rim, and under the default RepeatWrapping that tap wraps to the OPPOSITE
// edge and smears the sprite across itself. clamped, it reads the art's own transparent margin
  static function texture(path:String):Texture
    {
      var t = texCache.get(path);
      if (t == null)
        {
          t = render.Textures.loadTexture(path, 'wall');
          t.wrapS = t.wrapT = THREE.ClampToEdgeWrapping;
          texCache.set(path, t);
        }
      return t;
    }

// throwaway meshes carrying the exact materials this pool builds, for the boot shader pre-warm
// (render.View.warmup). the CORE needs one because its uv-disturbed program has a cache key of its
// own; the LIGHTNING needs one because `vertexColors` is in three's program key, so its ribbon is a
// permutation nothing else in the scene compiles. without either they compile on the first habitat
// entry as a frame hitch. the firefly quad is render.particles.Sparks.glowQuad's program, which that
// warm already covers
  public static function warmupMeshes():Array<Mesh>
    {
      var u:CoreUniforms = {
        phase: { value: 0.0 },
        warp: { value: 0.0 },
        rate: { value: 0.0 },
      };
      // one degenerate triangle, but a REAL one: it has to carry a `color` attribute, or the warm
      // geometry does not match what the ribbon actually feeds the same material at runtime
      var g = new BufferGeometry();
      g.setAttribute('position', new Float32BufferAttribute([ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 ], 3));
      g.setAttribute('color', new Float32BufferAttribute([ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 ], 3));
      return [
        new Mesh(new PlaneGeometry(1, 1), coreMaterial(RenderConfig.TEXTURES.fxInnards, u)),
        new Mesh(g, boltMaterial()),
      ];
    }
}
