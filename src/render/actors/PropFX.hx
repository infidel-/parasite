package render.actors;

import three.Three;
import citygen.CityConfig;
import game.Game;
import objects.AreaObject;
import objects.HabitatObject;
import render.RenderConfig;
import render.particles.Sprites;
import render.world.ObjModels;
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
  var ci:Int = 0;                         // next free core slot this frame
  var fi:Int = 0;                         // next free firefly slot this frame
  var t:Float = 0.0;                      // shared clock, in BASE_MS units

  public function new(game:Game, actorGroup:Group)
    {
      this.game = game;
      this.group = actorGroup;
      quad = new PlaneGeometry(1, 1);
    }

// place every visible prop's FX for this frame, then hide the pool tail. call once per frame from
// render.Actors.update. owns its own pools, so it does not have to sit inside the Sparks frame
  public function update(dtMs:Float):Void
    {
      ci = 0;
      fi = 0;
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
                   m.fly == null))
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
            }
        }
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

// the fireflies: n of them circling the prop MOSTLY PARALLEL TO THE FLOOR, each on a path of its own.
// they are evenly spaced only at t = 0 — from there every dot runs its own radius, height, speed and
// small plane tilt, breathes the radius slowly and wanders vertically on a separate beat, so the
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
// (render.View.warmup). only the CORE needs one: its uv-disturbed program has a cache key of its
// own, so without this it compiles on the first habitat entry as a frame hitch. the firefly quad is
// render.particles.Sparks.glowQuad's program, which that warm already covers
  public static function warmupMeshes():Array<Mesh>
    {
      var u:CoreUniforms = {
        phase: { value: 0.0 },
        warp: { value: 0.0 },
        rate: { value: 0.0 },
      };
      return [ new Mesh(new PlaneGeometry(1, 1), coreMaterial(RenderConfig.TEXTURES.fxInnards, u)) ];
    }
}
