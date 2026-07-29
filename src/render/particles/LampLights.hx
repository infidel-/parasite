package render.particles;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;

// fixed pool of K spotlights for street lamps — same discipline as FlameLights/MuzzleLights: created
// once, kept in the scene forever at intensity 0, never added/removed/hidden, so NUM_SPOT_LIGHTS stays
// constant and three never recompiles the lit materials. each frame the K nearest lamps to the player
// claim a light aimed straight down; the rest idle at 0. lets the city place HUNDREDS of lamp posts
// (models + cones are instanced) while only ever paying for K live spotlights
class LampLights {
  var lights:Array<SpotLight> = [];
  var targets:Array<Group> = [];
  var owner:Object3D;                     // the group the pool was added to, so dispose() can take it back out
  // how many of THIS pool's slots cast a shadow map. derived, never read from config directly: every
  // caster loop below indexes the per-slot arrays, so a caster count above the pool size walks off the
  // end of `lights` (and a pool of 0 would crash outright). min() makes any pool size legal by itself
  var casters:Int;
  var owners:Array<LampPost> = [];        // the lamp each slot currently serves (null = free)
  var prevOwners:Array<LampPost> = [];    // last frame's owner per slot — a change means the caster's shadow map must re-render
  var shadowDirty:Array<Bool> = [];       // caster slots whose owner changed and still owe a shadow re-render
  var shadowCursor:Int = 0;               // round-robin start so a multi-slot reshuffle spreads one re-render per frame
  public static var lastShadowRenders = 0; // observability: lamp shadow passes dispatched this frame (0/1 with the cap)
  public static var lastShadowBacklog = 0; // observability: caster slots still owing a re-render (a burst shows here, drains 1/frame)
  var intens:Array<Float> = [];           // eased intensity per slot (ramps toward its target)
  var activeList:Array<LampPost> = []; // lamps lit above epsilon this frame (drives fake shadows)
  var bulbY:Float;
  public var flickT:Float = 0.0;          // raw-ms flicker clock, see flicker() below (read by LightCone.pulse)

// failing-sodium lamp at time t (raw ms) with a per-lamp phase. TWO gate sines ride on top of each
// other: a fast one that breaks the lit stretches with ~1s stutter bursts, and a slow one that every
// ~20s takes the bulb all the way out for a few seconds (ramping in and out so it never pops). NOT
// FlameLights.flicker — that is a warm breathe floored at 0.55 that never goes dark, which is a fire,
// not a dying bulb. raw ms on purpose: a failing bulb is physical, so it bypasses ANIM_SPEED. every
// gate takes its own phase offset, so neighbouring lamps neither stutter nor die in unison
  public static inline function flicker(t:Float, phase:Float):Float
    {
      var L = RenderConfig.LAMP_LIGHT;
      var f = L.flickSteady + (1 - L.flickSteady) * (0.5 + 0.5 * Math.sin(phase * 3.7));
      // the uneven flutter, shared by the bursts and by the outage ramps
      var fast = L.flickMin + (1 - L.flickMin) * (0.5 + 0.5 * Math.sin(t * L.flickFastA) * Math.sin(t * L.flickFastB + phase * 4.0));
      var g = Math.sin(t * L.flickGate + phase * 2.3);
      if (g > L.flickGateOn)
        {
          // the outage: 0 at the window's edges, 1 at its centre
          var d = (g - L.flickGateOn) / (1 - L.flickGateOn);
          if (d >= L.flickOutEdge)
            return 0; // dead black
          // stuttering down into it and back out — the (1 - d/edge) ramp is what keeps the bulb from
          // dropping straight from full brightness to black
          return f * (1 - d / L.flickOutEdge) * fast;
        }
      // between outages the bulb is lit, but a faster gate keeps interrupting it with short bursts
      if (Math.sin(t * L.flickBurst + phase * 1.7) > L.flickBurstOn)
        return f * fast;
      return f;
    }

// build a pool of `pool` live spotlights. pool is the config value (vidLampLights), NOT
// RenderConfig.LAMP_LIGHT.pool — that is only the default the config is seeded from
  public function new(group:Object3D, pool:Int)
    {
      var L = RenderConfig.LAMP_LIGHT;
      owner = group;
      casters = pool < L.shadowCasters ? pool : L.shadowCasters;
      bulbY = CityConfig.CELL * L.yMul;
      // NOTE: never toggle .visible — an invisible spotlight drops out of NUM_SPOT_LIGHTS and forces
      // the very recompile this pool exists to avoid. idle == visible + intensity 0
      for (i in 0...pool)
        {
          var t = new Group();
          group.add(t);
          var l = new SpotLight(0xffb866, 0, CityConfig.CELL * 12, L.angle, L.penumbra, 1.6);
          l.target = t;
          // FIXED shadow casters: the first `shadowCasters` slots cast real shadows for their whole
          // life. never toggle castShadow per frame — it is part of the material program key
          // (NUM_SPOT_LIGHT_SHADOWS), so flipping it live forces the recompile this fixed pool avoids.
          // the nearest lit lamps tend to grab these low-index slots (update() fills nearest-first)
          if (i < casters)
            {
              l.castShadow = true;
              // static shadow map: the map re-renders only when this slot's owner lamp changes (see
              // update()), NOT every frame — posts never move, and intensity/shadow.intensity easing
              // are main-pass uniforms, not depth inputs. cuts up to `shadowCasters` passes per frame
              untyped l.shadow.autoUpdate = false;
              untyped l.shadow.mapSize.set(L.shadowMapSize, L.shadowMapSize);
              l.shadow.bias = L.shadowBias;
              var sc:Dynamic = l.shadow.camera;
              sc.near = 0.5;
              sc.far = CityConfig.CELL * 12;
              sc.updateProjectionMatrix();
            }
          group.add(l);
          lights.push(l);
          targets.push(t);
          owners.push(null);
          prevOwners.push(null);
          shadowDirty.push(false);
          intens.push(0);
        }
    }

// the lamp spotlights, as plain Object3Ds, for the debug on/off toggles
  public function debugList():Array<Object3D>
    return [for (l in lights) (l : Object3D)];

// take every light + target back out of the scene, so a differently-sized pool can replace this one
// (config vidLampLights). removing SpotLights changes NUM_SPOT_LIGHTS, which three folds into the
// material program key — the lit materials recompile on the next frame by themselves
  public function dispose():Void
    {
      for (l in lights)
        owner.remove(l);
      for (t in targets)
        owner.remove(t);
      lights = [];
      targets = [];
      owners = [];
      activeList = [];
    }

// the lamps lit this frame — their bulb x/z feed the fake cast-shadow pass
  public inline function active():Array<LampPost>
    return activeList;

// pool slots stick to their lamp and ramp intensity so lamps fade in/out instead of blinking: each
// frame the POOL nearest in-range lamps are "desired"; a slot keeps serving its lamp (target = full)
// until the lamp leaves the desired set (target = 0, fades out), then frees for a new lamp. call once
// per frame before the actor pass
  public function update(lamps:Array<LampPost>, playerCol:Int, playerRow:Int, dtMs:Float):Void
    {
      var L = RenderConfig.LAMP_LIGHT;
      flickT += dtMs;
      // desired = the pool-nearest in-range lamps, nearest first
      var range2 = L.lightRangeCells * L.lightRangeCells;
      // squared cell distance player->lamp — drives the in-range filter, the nearest-first desired
      // order, and the shadow-caster routing below
      function d2(lp:LampPost):Int
        {
          var dc = lp.col - playerCol;
          var dr = lp.row - playerRow;
          return dc * dc + dr * dr;
        }
      var near:Array<LampPost> = [];
      for (lp in lamps)
        if (d2(lp) <= range2)
          near.push(lp);
      near.sort(function(a, b) return d2(a) - d2(b));
      var desired = near.length < lights.length ? near : near.slice(0, lights.length);
      // targets: an owned slot stays lit while its lamp is still desired, else fades out
      var targetI = [for (i in 0...lights.length) (owners[i] != null && desired.indexOf(owners[i]) >= 0) ? L.intensity : 0.0];
      // hand faded-out / free slots to desired lamps that no owner is serving yet (nearest first)
      for (lp in desired)
        {
          var served = false;
          for (o in owners)
            if (o == lp) { served = true; break; }
          if (served)
            continue;
          for (i in 0...lights.length)
            if (intens[i] <= 0.001 && (owners[i] == null || desired.indexOf(owners[i]) < 0))
              {
                owners[i] = lp; // position + intensity applied in the publish pass below
                targetI[i] = L.intensity;
                break;
              }
        }
      // ease every slot toward its target
      var step = L.intensity * dtMs * RenderConfig.ANIM_SPEED / (RenderConfig.BASE_MS * L.fadeMul);
      for (i in 0...lights.length)
        {
          var tgt = targetI[i];
          if (intens[i] < tgt)
            intens[i] = Math.min(tgt, intens[i] + step);
          else if (intens[i] > tgt)
            intens[i] = Math.max(tgt, intens[i] - step);
          if (intens[i] <= 0.001)
            owners[i] = null; // fully dark → free for reuse
        }
      // route nearest lit lamps into the low (shadow-casting) slots: sort the slot CONTENTS (owner +
      // eased intensity) by distance so slots 0..shadowCasters-1 always serve the nearest lit lamps.
      // the physical SpotLights and their FIXED castShadow never move — only which lamp each serves —
      // so no light visibly jumps; only the shadow hands off to the nearer post. dark slots sort last
      var order = [for (i in 0...lights.length) i];
      order.sort(function(a, b)
        {
          var da = owners[a] == null ? 0x7fffffff : d2(owners[a]);
          var db = owners[b] == null ? 0x7fffffff : d2(owners[b]);
          return da - db;
        });
      owners = [for (i in 0...lights.length) owners[order[i]]];
      intens = [for (i in 0...lights.length) intens[order[i]]];
      // publish: apply each slot's intensity and move its SpotLight onto its (distance-sorted) owner
      activeList = [];
      for (i in 0...lights.length)
        {
          var o = owners[i];
          // flicker MULTIPLIES the published intensity and never touches intens[] — that array is both
          // the pure fade ease and the `<= 0.001 -> free the slot` test, so scaling it in place would
          // hand a sputtering lamp's slot away mid-blink
          var fl = (o != null && o.phase != 0) ? flicker(flickT, o.phase) : 1.0;
          untyped lights[i].intensity = intens[i] * fl;
          // mark this caster's shadow dirty when its owner lamp actually changes (posts never move,
          // so the depth map is otherwise valid); the re-render is dispatched at most one-per-frame below
          if (i < casters && owners[i] != prevOwners[i])
            shadowDirty[i] = true;
          if (o != null)
            {
              o.flick = fl; // read by FlameShadows so the fake ground shadow breathes with the bulb
              lights[i].position.set(o.x, bulbY, o.z);
              targets[i].position.set(o.x, 0, o.z);
              activeList.push(o);
            }
        }
      // re-render at most ONE caster's shadow per frame: a full reshuffle dirties several slots at once,
      // and running all their whole-scene shadow-cull traversals in one frame is the submit spike. spread
      // them round-robin — the <=few-frame lag is hidden by the shadow.intensity cross-fade below
      lastShadowRenders = 0;
      for (n in 0...casters)
        {
          var idx = (shadowCursor + n) % casters;
          if (shadowDirty[idx])
            {
              untyped lights[idx].shadow.needsUpdate = true;
              shadowDirty[idx] = false;
              shadowCursor = (idx + 1) % casters;
              lastShadowRenders = 1;
              break;
            }
        }
      // publish the remaining backlog for the perf trace (0 normally; jumps on a multi-slot reshuffle)
      lastShadowBacklog = 0;
      for (i in 0...casters)
        if (shadowDirty[i])
          lastShadowBacklog++;
      // fade the shadow (not the light) near the casting-set boundary: three's shadow.intensity scales
      // shadow darkness 0..1 without touching brightness. edge = distance of the nearest lamp that did
      // NOT win a casting slot (owners[casters]); ramp each caster's shadow to 0 within fadeBand
      // cells of that edge, so a lamp swapping across the boundary hands its shadow off instead of
      // popping. no boundary lamp (fewer lit than casters+1) -> full-strength shadows, nothing to fade
      var edge = (casters < lights.length && owners[casters] != null) ? Math.sqrt(d2(owners[casters])) : 1e9;
      for (i in 0...casters)
        {
          var o = owners[i];
          var s = 0.0;
          if (o != null)
            {
              s = (edge - Math.sqrt(d2(o))) / L.shadowFadeBand;
              s = s < 0 ? 0 : (s > 1 ? 1 : s);
            }
          untyped lights[i].shadow.intensity = s;
        }
      // remember this frame's owners so the next frame can detect a caster hand-off (shadow re-render)
      prevOwners = owners.copy();
    }
}
