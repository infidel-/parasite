package render.world;

import three.Three;
import citygen.CityConfig;
import game.Game;
import render.Area3DTickOpts;
import render.Models;
import render.Models.ModelVariant;
import render.RenderConfig;

// one model path's batches over the SAME placements, plus the cell each placement stands on. an
// InstancedMesh carries exactly one material, so every look the prop can take is its own batch and a
// per-frame cull mask decides which one draws each placement — the idiom the street lamps already use
// to swap a post between its lit and its dead batch mid-outage (render.SceneSetup lampMask/lampMaskDead)
typedef PropBatch = {
  solid:Models.InstancedProp,        // the opaque prop, and the only batch that casts
  ghost:Models.InstancedProp,        // see-through twin, drawn for the placement under the player
  hull:Models.InstancedProp,         // backface outline shell, drawn only while the tactical view is up
  model:ObjModel,                    // the row these batches were built from, for the per-frame patches
  cells:Array<{ col:Int, row:Int }>, // indexed like the placements, so index i IS placement i's cell
  solidMask:Array<Bool>,
  ghostMask:Array<Bool>,
  hullMask:Array<Bool>,
  ghostIdx:Int,                      // placement the ghost serves, -1 for none. HELD across the
                                     // fade-out, when the player has already stepped off the cell
  t:Float,                           // ghost level, 0 solid .. 1 fully faded. one per BATCH, not per
                                     // instance: the player stands in exactly one cell
};

// how a prop is turned on its cell. the area kind owns the actual rule (only it knows what is solid);
// this only says WHICH rule to ask for
enum PropYaw {
  WALL;    // back to the adjacent wall — a ladder is bracketed to masonry and reads wrong free-standing
  HASHED;  // full-circle turn hashed off the cell, so four of a prop in one level are not clones
  FRONTAL; // FIXED, facing the resting camera. for a prop whose front IS its read — the assimilation
           // arch is a doorway with the orifice in one leg, and a hashed turn showed it edge-on as
           // often as not. fixed and not camera-TRACKING on purpose, the same call the frontal FX
           // quads make (see render.particles.Sparks): a solid prop that swung with an orbiting camera
           // would swim against its own shadow and the floor it stands on
}

// the coloured point light a prop emits. `mul` scales RenderConfig.PROP_LIGHT.intensity rather than
// setting an absolute one, so a single dial moves every glowing prop and a row only says how bright
// this one is RELATIVE to its neighbours. the pool that consumes it is render.particles.PropLights
typedef PropLight = {
  color:Int, // light colour — each organ's own glow hue, so the light reads as the thing luminescing
  mul:Float, // multiplier on PROP_LIGHT.intensity
};

// the idle motion folded into a prop's own shaders, or null for one that stands still. every
// amplitude and frequency here is a FRACTION of the prop's own height rather than a world number:
// Models.instanced scales by HEIGHT alone, so a hand-typed world constant stops meaning what it said
// the moment `h` is edited (the lesson SewerProp.margin -> `r` already paid for). the module that
// consumes it is render.world.PropShader
typedef PropAnim = {
  amp:Float,       // sway amplitude at the crown, as a fraction of the prop's height
  bend:Float,      // height falloff exponent — higher concentrates the motion further up
  rate:Float,      // sway speed as a BASE_MS multiplier (smaller = slower)
  strand:Float,    // phase cycles per prop-height across local XZ; 0 = the whole body flexes as one
  sheen:Float,     // shading-normal ripple amplitude — the crawling specular, no displacement
  sheenRate:Float, // ripple speed as a BASE_MS multiplier
};

// the pulsing "innards" sprite drawn INSIDE a prop hollow enough to show one: a single frontal
// additive quad, breathing on a slow scale beat, with its own map UVs disturbed in the FRAGMENT
// shader so the mass writhes instead of merely resizing. same fraction-of-height rule as PropAnim
// above, and for the same reason. the module that consumes it is render.actors.PropFX
typedef PropCore = {
  tex:String,      // RenderConfig.TEXTURES entry
  y:Float,         // centre height as a fraction of the prop's height
  z:Float,         // depth offset toward (+) / away from (-) the resting camera, same fraction
  size:Float,      // quad edge, same fraction
  lean:Float,      // radians the quad leans BACK toward the overhead camera. Sprites.TILT is the
                   // actor-sprite value and the default for anything glued to a leaning billboard;
                   // 0 stands it upright, which is what a prop of real vertical GEOMETRY wants — the
                   // lean pushes the quad's top away from the camera and out of the arch's own plane
  color:Int,       // tint
  glow:Float,      // HDR multiplier on the tint — what carries it over the bloom threshold
  alpha:Float,     // additive opacity
  pulse:Float,     // scale-breath depth (0.15 = +/-15% of `size`)
  pulseRate:Float, // breath speed as a BASE_MS multiplier
  warp:Float,      // uv disturbance amplitude, in uv units
  warpRate:Float,  // disturbance speed as a BASE_MS multiplier
};

// the fireflies orbiting a prop: as many as the object's habitat LEVEL, circling it MOSTLY PARALLEL
// TO THE FLOOR. everything below that is per-dot spread, and the spread is the whole point — one
// shared circle at one radius and one height reads as a rigid formation turning, not as a swarm. each
// dot rolls its own radius, height, speed and small plane tilt off these bases (stably, off the cell
// and its own index), then breathes its radius and wanders vertically on beats of its own. same
// fraction-of-the-prop's-height rule as PropCore and PropAnim
typedef PropFly = {
  tex:String,     // RenderConfig.TEXTURES entry — core, halo and flare baked into ONE sprite
  perLevel:Int,   // fireflies PER habitat level. not always 1: an improvement's cap is its own (see
                  // const.EvolutionConst — biomineral 3, preservator 3, watcher 2, and the
                  // assimilation cavity caps at ONE), so a raw level count would leave the arch with
                  // a single dot for the whole game
  y:Float,        // base ring height, as a fraction of the prop's height
  yVar:Float,     // per-dot height spread off it (+/-), same fraction. what puts the swarm in 3D
  r:Float,        // base ring radius, same fraction. keep it clear of the prop's own footprint
  rVar:Float,     // per-dot radius spread (+/-), and at half depth the slow breath on top of it
  tilt:Float,     // per-dot orbit-plane tilt SPREAD off horizontal (+/- radians). small: the ring is
                  // meant to read as flat, the depth comes from yVar and from the prop occluding it
  size:Float,     // quad edge, same fraction
  color:Int,      // tint
  glow:Float,     // HDR multiplier — this is what makes them bloom
  alpha:Float,    // additive opacity at the top of the twinkle
  rate:Float,     // base orbit speed as a BASE_MS multiplier
  rateVar:Float,  // per-dot speed spread as a fraction of it (+/-) — dots drift apart, then re-cross
  bob:Float,      // vertical wander amplitude, same fraction
  twinkle:Float,  // brightness modulation depth, 0..1 (opacity dips to alpha * (1 - twinkle))
  trail:Int,      // quads trailing BEHIND each dot, 0 for a bare mote. they are not remembered
                  // positions — the orbit is a closed form in the clock, so each is the same path
                  // evaluated at an earlier time (see render.actors.PropFX.drawFlies)
  trailGap:Float, // clock step between trailing samples, in BASE_MS units. trail * this is how far
                  // back the tail reaches, so the two together set its length
  trailSize:Float,// the tail-end quad's size as a fraction of the head's
};

// one object-backed glb prop. `keys` are AreaObject.getModelKey values rather than raw types because
// several classes can share a type and still want different props (every habitat object is type
// 'habitat', and that string is persisted game state — see objects.AreaObject.getModelKey)
typedef ObjModel = {
  keys:Array<String>, // getModelKey values that draw as this prop
  path:String,        // RenderConfig.MODELS entry
  h:Float,            // world height Models.instanced scales the prop to (CityConfig.CELL is 4)
  yaw:PropYaw,        // which turning rule the area kind is asked for
  light:PropLight,    // coloured point light this prop emits, or null for one that does not glow
  anim:PropAnim,      // idle motion folded into its shaders, or null for a prop that stands still
  core:PropCore,      // pulsing innards sprite drawn inside it, or null
  fly:PropFly,        // fireflies orbiting it, one per habitat level, or null
};

// area objects that render as a real 3D prop instead of their atlas sprite. the mapping lives here,
// in the render layer, keyed on the object TYPE — objects.AreaObject knows nothing about glbs, the
// same way it knows nothing about which texture its sprite comes from.
//
// props are placed once at area build (these objects never move) and instanced per model path, so a
// level pays one draw call per distinct prop however many of them stand in it. render.Actors skips
// its sprite marks entirely for a prop-backed object: the icon would stand inside the prop, and the
// tactical outline here traces the real geometry instead of the 2D art's silhouette
class ObjModels
{
  // frustum margin for every batch. deliberately generous: the SOLID batch is the one that casts, and
  // the sewer lamp shadow maps are STATIC (re-rendered only when a caster changes owner), so a prop
  // packed out at the wrong moment would lose its shadow from that map until the next hand-off
  static inline var CULL_R = CityConfig.CELL * 3;

  // every object-backed prop there is. ONE table: build() places from it, render.View warms every
  // entry at boot, modelFor() is the lookup and render.particles.PropLights reads the `light` rows —
  // so a new prop is a row here plus its path in RenderConfig.MODELS, nothing to keep in sync by hand.
  // heights are world units against a 4-unit cell; the sprite each replaces was a 3.0 square.
  // the habitat organs' light colours are each prop's OWN glow hue, carried over from the emissive map
  // that used to do this job on the prop's surface alone (see RenderConfig.PROP_LIGHT)
  public static final MODELS:Array<ObjModel> = [
    {
      keys: [ 'sewer_exit', 'habitat_exit' ],
      path: RenderConfig.MODELS.sewerExit,
      h: 4.0,
      yaw: WALL,
      light: null, // a ladder is masonry and rungs, not a grown thing
      anim: null,  // and bolted to a wall, so it had better not breathe
      core: null,  // nor has it any insides
      fly: null,
    },
    {
      keys: [ 'habitat_biomineral' ],
      path: RenderConfig.MODELS.habitatBiomineral,
      h: 3.74, // 1.3x the 2.88 it shipped at, with the other three organs
      yaw: HASHED,
      light: { color: 0x33bf59, mul: 1.0 }, // crystal green
      anim: null, // worked case by case; a mineral spire is the one organ that should NOT sway
      core: null, // its own treatment comes later, and is meant to be nothing like the arch's
      fly: null,
    },
    {
      keys: [ 'habitat_assimilation' ],
      path: RenderConfig.MODELS.habitatAssimilation,
      h: 3.43, // 1.3x the 2.64 it shipped at, with the other three organs. wider than it is tall, so
               // this now spans ~4.6 world units against a 4-unit cell and overhangs a third of a cell
               // into each neighbour — at 1.8 the arch read squat beside the preservator and lost the
               // "something you could step through" silhouette. everything hung on it (the core quad,
               // the firefly ring) is authored as a FRACTION of this, so it all scales with the row
      yaw: FRONTAL,
      light: { color: 0x8c2ecc, mul: 0.9 }, // maw violet
      // an arch of braided tentacles: the limbs drift, both legs stay planted. `strand` is what
      // stops it reading as one slab tipping side to side — at 3 cycles over its own height the
      // near and far braids of the arch are visibly out of step
      anim: {
        amp: 0.02,
        bend: 1.6,
        rate: 0.2,
        strand: 3.0,
        sheen: 0.06,
        sheenRate: 0.5,
      },
      // the arch is a DOORWAY with nothing behind it, so the membrane hangs in the opening rather
      // than inside a body, sized to fill it and sat at mid-height. the tint is the row's own maw
      // violet, the one the pulled point light carried.
      // EVERY number here is in units of `h`, and the arch's own art measures 1.35 h wide, 1 h tall
      // and 0.65 h deep — quote those ratios rather than world units, or the whole block goes stale
      // the next time the row is resized (it has been, by 1.3x, once already)
      core: {
        tex: RenderConfig.TEXTURES.fxInnards,
        y: 0.46,
        // dead centre of the braid depth, which is enough to put the near braids IN FRONT of the
        // membrane — they occlude it instead of it painting additively over them. going further back
        // is the tempting move and it is wrong: the tunnel camera looks down ~53 degrees, so moving a
        // thing away also moves it UP the screen by dz * sin(53), and cancelling that with `y` costs
        // dz * tan(53) — 1.3x the depth move — which drops the quad's bottom edge through the floor
        z: 0.0,
        // 0.99 h of quad. the art's knot fills only the middle ~65% of its frame, so what reads is
        // ~0.64 h — it fills the opening's height and laps onto the inner edge of each braid, which
        // additive blending turns into the throat glowing through them. it CANNOT match the old
        // LEANED look at any value: upright, the quad's height projects by cos(53 deg) = 0.60 against
        // the leaned version's 0.95, and buying that 1.57x back needs more quad than the arch is tall
        size: 0.99,
        lean: 0.0, // UPRIGHT. the arch is real vertical geometry and the membrane hangs in its
                   // opening, so the actor-sprite lean would tip the quad's top out through the back
        color: 0x8c2ecc,
        glow: 2.6, // the WALL_LAMP_GLOW figure — what it takes to clear BLOOM_THRESHOLD 0.9
        // brighter than the leaned version needed, and this is the only lever left: standing it
        // upright cost 1.57x of apparent height and the arch caps how much size can buy back
        alpha: 0.72,
        // both slow on purpose: `t` runs at 1 per BASE_MS, so 6.67/s — these are a ~17s breath and a
        // ~7s writhe. anything faster reads as a flicker rather than something alive and idling
        pulse: 0.14,
        pulseRate: 0.06,
        warp: 0.05, // in uv units, so ~5% of the sprite. 2.0 drives every tap past the clamp and the
                    // membrane disappears outright — which is how the patch was proved to be live
        warpRate: 0.13,
      },
      // ONE mote circling the arch roughly parallel to the floor, dragging a fading tail. in units of
      // `h` again (the arch is 1.35 h wide, so 0.67 h of half-span): the radius band 0.35..0.55 h is
      // INSIDE that, so the mote flies through the opening rather than round the outside and laps the
      // membrane, which is the point. the height band 0.27..0.83 h plus the braids occluding the far
      // side of the circle is what reads as 3D — the ring's own tilt is only a small per-dot jitter
      fly: {
        tex: RenderConfig.TEXTURES.fxFirefly,
        perLevel: 1, // IMP_ASSIMILATION caps at level 1, so this IS the arch's whole count
        y: 0.55,
        yVar: 0.28,
        r: 0.45,
        rVar: 0.22,
        tilt: 0.25,
        size: 0.22,
        color: 0xb46bff,
        glow: 3.0,
        alpha: 0.8,
        rate: 0.18,
        rateVar: 0.45,
        bob: 0.10,
        twinkle: 0.5,
        trail: 9,        // 10 quads all told, so ~10 draw calls for the whole swarm
        trailGap: 0.5,   // 9 * 0.5 of clock behind the head = ~46 degrees of arc at this speed
        trailSize: 0.25,
      },
    },
    {
      keys: [ 'habitat_preservator' ],
      path: RenderConfig.MODELS.habitatPreservator,
      h: 4.06, // 1.3x the 3.12 it shipped at, with the other three organs — the tallest of the four
      yaw: HASHED,
      light: { color: 0xd98c26, mul: 1.0 }, // amber core
      anim: null, // worked case by case
      core: null,
      fly: null,
    },
    {
      keys: [ 'habitat_watcher' ],
      path: RenderConfig.MODELS.habitatWatcher,
      h: 2.81, // 1.3x the 2.16 it shipped at, with the other three organs
      yaw: HASHED,
      light: { color: 0xf28c80, mul: 1.2 }, // pale flesh-pink eye
      anim: null, // worked case by case
      core: null,
      fly: null,
    },
  ];

// the prop an object draws as, or null for the ordinary sprite path. a linear scan of five rows,
// which is cheaper than the map it would take to avoid it — render.Actors asks once per object per
// frame and the answer is null for everything in a city
  public static function modelFor(key:String):ObjModel
    {
      for (m in MODELS)
        for (k in m.keys)
          if (k == key)
            return m;
      return null;
    }

// place every prop-backed object in the area, grouped per model. `yaw` decides which way a prop faces
// from its cell and is handed the model's own PropYaw, so one callback serves every kind (a ladder
// wants its back to a wall, a grown thing a hashed turn, an arch a fixed frontal one); the area kind
// owns that rule, because only it knows what is solid. the returned batches MUST be handed to cull()
// every frame — Models.instanced turns three's own frustum cull off, so nothing else trims their counts
  public static function build(scene:Scene, game:Game, yaw:Int->Int->PropYaw->Float):Array<PropBatch>
    {
      var byPath:Map<String, Array<{ x:Float, z:Float, yaw:Float }>> = new Map();
      var cellsByPath:Map<String, Array<{ col:Int, row:Int }>> = new Map();
      for (o in game.area.getObjects())
        {
          var m = modelFor(o.getModelKey());
          if (m == null)
            continue;
          if (!byPath.exists(m.path))
            {
              byPath.set(m.path, []);
              cellsByPath.set(m.path, []);
            }
          var w = CityConfig.cellToWorld(o.x, o.y);
          byPath.get(m.path).push({ x: w.x, z: w.z, yaw: yaw(o.x, o.y, m.yaw) });
          // pushed in the SAME iteration as its placement, so the two share an index — and that shared
          // index is the whole mechanism turning "the player stands on cell X" into an instance to fade
          cellsByPath.get(m.path).push({ col: o.x, row: o.y });
        }
      var C = RenderConfig.OBJMARK;
      var out:Array<PropBatch> = [];
      // walked in TABLE order rather than over the map, so the batch list is deterministic and each
      // path is instanced at its own authored height
      for (m in MODELS)
        {
          var places = byPath.get(m.path);
          if (places == null)
            continue;
          out.push({
            solid: Models.instanced(scene, m.path, places, m.h, SOLID),
            ghost: Models.instanced(scene, m.path, places, m.h, GHOST),
            hull: Models.instanced(scene, m.path, places, m.h, HULL(C.color, C.hullW)),
            model: m,
            cells: cellsByPath.get(m.path),
            solidMask: [for (_ in places) true],
            ghostMask: [for (_ in places) false],
            hullMask: [for (_ in places) false],
            ghostIdx: -1,
            t: 0.0,
          });
        }
      return out;
    }

// tear every batch out of the scene, so build() can run again after an object was added to or removed
// from the live area. ONLY the ghost and hull materials are disposed: those are made per batch (a
// clone and a fresh MeshBasicMaterial), while SOLID reuses the glb template's own shared material and
// every geometry here — hull shells included — is cached per path in Models, so disposing either
// would corrupt the next batch built over the same model
  public static function dispose(scene:Scene, batches:Array<PropBatch>):Void
    {
      for (b in batches)
        {
          for (p in [ b.solid, b.ghost, b.hull ])
            if (p.mesh != null)
              scene.remove(p.mesh);
          if (b.ghost.mesh != null)
            b.ghost.mesh.material.dispose();
          if (b.hull.mesh != null)
            b.hull.mesh.material.dispose();
        }
    }

// per-frame prop pass: fade the prop the player is STANDING on to see-through so its body does not
// hide the sprite (the tunnel camera looks near straight down and the exit ladder is a whole cell
// tall), show the outline shells while the tactical view is up, then repack all three batches for the
// frustum cull. call once per frame from the area kind's tick
  public static function cull(batches:Array<PropBatch>, opts:Area3DTickOpts, tactical:Bool):Void
    {
      var G = RenderConfig.PROP_GHOST;
      // the leave-outro despawns the area and reports cell 0/0 — a LEGAL grid cell, so it must not be
      // read as a position. nobody stands anywhere, and a faded prop eases back to solid while the
      // camera pulls out instead of staying see-through for the whole shot
      var col = opts.outro ? -1 : opts.playerCol;
      var row = opts.outro ? -1 : opts.playerRow;
      for (b in batches)
        {
          // the glb resolves through a loader callback, so every batch is mesh-less for the first few
          // frames. one test covers all three: Models.get queues the callbacks per path and flushes
          // them together, so they land on the same frame
          if (b.solid.mesh == null)
            continue;
          var idx = -1;
          for (i in 0...b.cells.length)
            if (b.cells[i].col == col &&
                b.cells[i].row == row)
              idx = i;
          if (idx >= 0)
            b.ghostIdx = idx;
          // dt-compensated ease, the same shape render.Occlusion fades a building with. an exponential
          // tail never reaches 0, and the handover BACK to the opaque batch is gated on it, so snap it
          var k = 1 - Math.pow(1 - G.lerp, opts.dtMs / (1000 / 30));
          b.t += ((idx >= 0 ? 1.0 : 0.0) - b.t) * k;
          if (idx < 0 &&
              b.t < G.snap)
            b.t = 0;
          // the fading placement stays with the GHOST batch for the whole fade in both directions: at
          // t = 0 the ghost is a pixel-identical clone of the solid, so neither handover shows
          for (i in 0...b.cells.length)
            {
              var g = i == b.ghostIdx && (idx >= 0 || b.t > 0);
              b.ghostMask[i] = g;
              b.solidMask[i] = !g;
              b.hullMask[i] = tactical;
            }
          // one opacity for the batch is correct BECAUSE only one placement can be mid-fade. a true
          // cross-dissolve is impossible here and must not be attempted: the solid material is shared
          // by every other placement, so dimming it would dim every copy of the prop in the level
          b.ghost.mesh.material.opacity = 1 - b.t * (1 - G.alpha);
          Models.cull(b.solid, opts.camera, CULL_R, b.solidMask);
          Models.cull(b.ghost, opts.camera, CULL_R, b.ghostMask);
          Models.cull(b.hull, opts.camera, CULL_R, b.hullMask);
        }
    }
}
