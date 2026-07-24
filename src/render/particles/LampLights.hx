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
  var owners:Array<LampPost> = [];        // the lamp each slot currently serves (null = free)
  var prevOwners:Array<LampPost> = [];    // last frame's owner per slot — a change means the caster's shadow map must re-render
  var shadowDirty:Array<Bool> = [];       // caster slots whose owner changed and still owe a shadow re-render
  var shadowCursor:Int = 0;               // round-robin start so a multi-slot reshuffle spreads one re-render per frame
  public static var lastShadowRenders = 0; // observability: lamp shadow passes dispatched this frame (0/1 with the cap)
  public static var lastShadowBacklog = 0; // observability: caster slots still owing a re-render (a burst shows here, drains 1/frame)
  var intens:Array<Float> = [];           // eased intensity per slot (ramps toward its target)
  var activeList:Array<LampPost> = []; // lamps lit above epsilon this frame (drives fake shadows)
  var bulbY:Float;

  public function new(group:Object3D)
    {
      var L = RenderConfig.LAMP_LIGHT;
      bulbY = CityConfig.CELL * L.yMul;
      // NOTE: never toggle .visible — an invisible spotlight drops out of NUM_SPOT_LIGHTS and forces
      // the very recompile this pool exists to avoid. idle == visible + intensity 0
      for (i in 0...L.pool)
        {
          var t = new Group();
          group.add(t);
          var l = new SpotLight(0xffb866, 0, CityConfig.CELL * 12, L.angle, L.penumbra, 1.6);
          l.target = t;
          // FIXED shadow casters: the first `shadowCasters` slots cast real shadows for their whole
          // life. never toggle castShadow per frame — it is part of the material program key
          // (NUM_SPOT_LIGHT_SHADOWS), so flipping it live forces the recompile this fixed pool avoids.
          // the nearest lit lamps tend to grab these low-index slots (update() fills nearest-first)
          if (i < L.shadowCasters)
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
          untyped lights[i].intensity = intens[i];
          // mark this caster's shadow dirty when its owner lamp actually changes (posts never move,
          // so the depth map is otherwise valid); the re-render is dispatched at most one-per-frame below
          if (i < L.shadowCasters && owners[i] != prevOwners[i])
            shadowDirty[i] = true;
          var o = owners[i];
          if (o != null)
            {
              lights[i].position.set(o.x, bulbY, o.z);
              targets[i].position.set(o.x, 0, o.z);
              activeList.push(o);
            }
        }
      // re-render at most ONE caster's shadow per frame: a full reshuffle dirties several slots at once,
      // and running all their whole-scene shadow-cull traversals in one frame is the submit spike. spread
      // them round-robin — the <=few-frame lag is hidden by the shadow.intensity cross-fade below
      lastShadowRenders = 0;
      for (n in 0...L.shadowCasters)
        {
          var idx = (shadowCursor + n) % L.shadowCasters;
          if (shadowDirty[idx])
            {
              untyped lights[idx].shadow.needsUpdate = true;
              shadowDirty[idx] = false;
              shadowCursor = (idx + 1) % L.shadowCasters;
              lastShadowRenders = 1;
              break;
            }
        }
      // publish the remaining backlog for the perf trace (0 normally; jumps on a multi-slot reshuffle)
      lastShadowBacklog = 0;
      for (i in 0...L.shadowCasters)
        if (shadowDirty[i])
          lastShadowBacklog++;
      // fade the shadow (not the light) near the casting-set boundary: three's shadow.intensity scales
      // shadow darkness 0..1 without touching brightness. edge = distance of the nearest lamp that did
      // NOT win a casting slot (owners[shadowCasters]); ramp each caster's shadow to 0 within fadeBand
      // cells of that edge, so a lamp swapping across the boundary hands its shadow off instead of
      // popping. no boundary lamp (fewer lit than casters+1) -> full-strength shadows, nothing to fade
      var casters = L.shadowCasters;
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
