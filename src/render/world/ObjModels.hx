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

// short lightning discharged by a prop that is a POWER source: brief jagged strokes that snap on
// somewhere round the body, crackle for a fraction of a second and die, another firing elsewhere.
// every bolt on every prop in the level is ONE mesh and ONE draw call — a hand-built ribbon rebuilt
// per frame, the idiom render.particles.SlimeTrail already uses — and NOT a quad per segment, which
// is what a pooled-sprite version would have cost (6 bolts x 5 segments = 30 calls instead of 1).
//
// nothing is stored per bolt. a slot's whole life is derived from which TIME BUCKET the clock is in:
// the bucket index seeds where the bolt strikes, which way it goes and how it kinks, and the position
// inside the bucket is its age. the shape RenderConfig.BLOOD's black-blood glints already use.
// same fraction-of-the-prop's-height rule as every column above. consumed by render.actors.PropFX
typedef PropArc = {
  perLevel:Int,  // bolt slots PER habitat level, so a grown organ crackles harder
  period:Float,  // one slot's strike-to-strike interval, in BASE_MS units
  duty:Float,    // fraction of that interval the bolt is alight — 0.18 means dark 82% of the cycle,
                 // which is what makes it read as a discharge and not as a permanent fixture
  segs:Int,      // straight pieces per bolt: the jaggedness resolution, and the vertex cost
  y:Float,       // strike height, fraction of the prop's height
  yVar:Float,    // and its spread (+/-)
  az:Float,      // HALF-RANGE of the strike azimuth about the prop's vertical axis, in radians,
                 // centred on world +Z where the resting camera is. this is what lets a bolt travel
                 // toward the camera instead of only across the screen — a plane-confined bolt can
                 // go left, right and up, and nothing else. a half-range rather than a full circle
                 // because a strike on the far side is simply hidden behind the body
  r:Float,       // radius of the strike point off the prop's axis, same fraction — put it ON the
                 // body's surface, because a strike inside the silhouette puts the first half of
                 // the bolt behind it
  rTop:Float,    // and that radius at the CROWN as a fraction of it, so strikes follow the prop's
                 // own taper. without it a high strike sits at full width and the bolt hangs in the
                 // air beside a crystal that has already narrowed to a point
  len:Float,     // bolt length, same fraction. SHORT is the whole look
  lenVar:Float,  // per-strike length spread as a fraction of it (+/-)
  spread:Float,  // how far the bolt may swing off straight-out-sideways (radians). NOT off radial —
                 // radial aims every high strike at the ceiling
  jag:Float,     // sideways kink amplitude, fraction of height. belled to 0 at both ends, so the
                 // bolt still starts on the body and ends in a point
  width:Float,   // ribbon HALF-width at the root, same fraction
  taper:Float,   // tip width as a fraction of the root's
  // the FLARE. a second ribbon down the same path, wide and dim, fading to nothing at its edges.
  // it exists because bloom output scales with the AREA of over-threshold pixels, and the core is a
  // ~5px thread: measured, it produced no halo whatsoever while an identical ribbon at 7x the width
  // haloed exactly like a wall lamp. raising `glow` does not substitute — ACES saturates the core
  // and intensity buys no area. it costs no draw call, only vertices on the same ribbon
  halo:Float,    // its half-width as a multiple of `width`
  haloDim:Float, // and its centreline brightness as a fraction of the core's. keep the product with
                 // `glow` over the bloom threshold or the flare adds light but no halo of its own
  color:Int,     // tint. a discharge core reads near-white, so pale beats saturated
  glow:Float,    // HDR multiplier — what carries it over the bloom threshold
};

// the glow that lives ON a prop's own surface rather than in the air around it: motes travelling a
// slow helix through the body, masked to the part of the prop the baked albedo says is mineral. same
// fraction-of-the-prop's-height rule as everything above, and for the same reason. the module that
// consumes it is render.world.PropGlow
typedef PropShine = {
  // the mask. greenness as a RATIO, diffuseColor.g / max(r, b), so it means the same in linear and
  // sRGB and does not move with how dark a texel is. measured on the shipped biomineral atlas: the
  // mineral sits near 2.3, the violet body near 0.87, with a clean gap between — these two numbers
  // are the one thing here that a re-baked mesh could invalidate, so re-measure them if it is
  keyLo:Float,      // ratio where the glow starts fading in
  keyHi:Float,      // and where it is fully lit
  color:Int,        // tint, normally the row's own `light` colour
  glow:Float,       // HDR multiplier on it — what carries the mote peaks over the bloom threshold
  base:Float,       // steady floor over the whole mask, so the mineral reads as luminescent at rest
  // the motes. count is per ROW and NOT per habitat level: a per-instance count would need an
  // attribute beside instanceMatrix, and Models.cull repacks that matrix alone every frame, so the
  // two would desync the moment the camera moved
  motes:Int,        // travelling loci, baked into the shader as a literal loop bound
  mote:Float,       // peak brightness of one, at its own centre
  moteR:Float,      // its reach, as a fraction of the prop's height — this is the dot's SIZE
  r:Float,          // helix radius at the foot, same fraction. track the prop's own profile
  rTop:Float,       // radius at the crown as a fraction of `r`, so a spire's motes stay on it
  rise:Float,       // climb speed as a BASE_MS multiplier (one lap foot to crown)
  spin:Float,       // sweep speed, same units. deliberately unrelated to `rise`, so no mote ever
                    // retraces its own path
  front:Float,      // HALF-ARC the sweep is allowed, in radians either side of the CAMERA — not of
                    // the prop, whose `yaw` is hashed per placement. keeps every mote on the near
                    // face, at the cost of the lap: the angle ping-pongs instead of orbiting, so a
                    // mote eases, reverses at the silhouette and comes back. PI is a full sweep
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
  shine:PropShine,    // travelling motes on its own surface, or null
  arc:PropArc,        // short lightning discharged off it, or null
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
      shine: null, // and nothing on it is alive enough to luminesce
      arc: null,   // nor carries any current
    },
    {
      keys: [ 'habitat_biomineral' ],
      path: RenderConfig.MODELS.habitatBiomineral,
      h: 3.74, // 1.3x the 2.88 it shipped at, with the other three organs
      yaw: HASHED,
      // THE one organ that really lights its room. pale rather than the saturated crystal green the
      // surface glow uses: a point light washes every surface it reaches, and at full saturation it
      // tints the masonry and the floor green instead of reading as light coming off a green thing
      light: { color: 0x8fe3b0, mul: 1.0 },
      anim: null, // worked case by case; a mineral spire is the one organ that should NOT sway
      core: null, // it is solid rock — there is nothing hollow to hang a membrane in
      fly: null,  // the arch owns the orbiting-mote vocabulary; this organ is a POWER source, so it
                  // discharges instead — see `arc` below
      // motes travelling up the crystal itself. every number is in units of the prop's own height,
      // and the helix is fitted to its measured profile: mean surface radius runs 0.264 of the height
      // at the foot to 0.074 at the crown, so `r`/`rTop` reproduce that taper and `moteR` is wide
      // enough to reach the surface from just inside it
      shine: {
        // the mineral is 23.4% of the baked atlas and it is spread over the WHOLE body, 12-26% in
        // every height band — so this has to be a colour key, not a region.
        // MEASURED off the baked atlas in LINEAR, which is the only place this can be read: the
        // ratio's percentiles are p50 0.62 / p70 0.78 for the body and p80 1.45 / p95 1.67 for the
        // mineral, so the gap is 0.8..1.4 and NOT the 2.3-vs-0.87 an sRGB reading suggests. get this
        // wrong and the failure is not a missing glow, it is SPECKLE: a band the mineral never
        // saturates leaves every mineral texel mid-ramp, where the art's own fine grain modulates
        // the mask pixel by pixel. this band leaves 23.4% fully lit, 72.5% fully dark and only 4.1%
        // ramping — and that 4.1% is the real boundary between crystal and flesh
        keyLo: 0.95,
        keyHi: 1.35,
        color: 0x33bf59, // crystal green, the hue the row's own point light carried
        // 2.8 puts a mote peak at linear luminance 1.09 against BLOOM_THRESHOLD 0.9, so the motes
        // halo and nothing else does — the resting `base` lands at 0.11, far under
        glow: 2.8,
        // the floor is SMALL, and the first pass got this wrong by ~7x. emissive is added in LINEAR
        // space straight onto the lit colour, and the crystal's albedo is only ~0.03 linear (mean
        // sRGB 46) — so 0.10 here put a flat 0.41 green over the whole mask and the prop read as one
        // solid blob with the motes invisible inside it. 0.015 lands the resting glow near 45 sRGB,
        // which is a mineral that luminesces rather than one that is switched on
        base: 0.015,
        // twice as many, half the size. lit AREA therefore drops to a quarter each and to half
        // overall, so the prop dims a little while reading busier — the peak is unchanged, which is
        // what keeps every one of them over the bloom threshold
        motes: 8,
        mote: 1.6,     // hot enough that the core clips and blooms into a defined dot, not a lit patch
        moteR: 0.0325, // ~0.12 world units across a body 2.76 wide — a speck, which is the ask
        r: 0.26,
        rTop: 0.30,
        // both slow: `t` runs at 1 per BASE_MS, i.e. 6.67/s, so this is a ~12.5s climb under a ~16s
        // there-and-back sweep. the two are deliberately unrelated, so a mote never retraces a path
        rise: 0.012,
        spin: 0.06,
        front: 0.9, // ~52 degrees either side of the camera. well short of the 90 where a mote would
                    // slide behind the body, and short of it by enough that it is not grazing the
                    // silhouette either — the sweep is SLOWEST at its extremes, so whatever angle
                    // this is, motes spend most of their time sitting at it
      },
      // and the reason this organ exists: it makes POWER. short green discharges snapping off the
      // crystal, pale-cored the way a real arc is. every number is in units of `h` again
      arc: {
        perLevel: 2,   // 2 slots at level 1, 6 at 3 — a grown formation crackles harder
        // 10 BASE_MS units is ~1.5s per slot and `duty` lights it for ~0.27s of that, so 6 slots
        // strike ~4x a second and ~1 is alight at any moment. it goes fully dark ~30% of the time,
        // which is correct for a discharge — the surface motes are what keep the prop alive between
        period: 10.0,
        duty: 0.18,
        segs: 7,    // more pieces than the eye needs, because too few reads as one smooth curve
        y: 0.5,
        yVar: 0.3,  // a 0.6 h band — off the body's flanks, not off the point at the crown
        az: 2.0,    // ~115 degrees either side of the camera direction: forward, and across both
                    // flanks, stopping short of straight behind where the crystal would hide it
        r: 0.30,    // the body's measured mean surface radius at its base (0.264 h) with a little
                    // over, so the root sits on the surface rather than just inside it
        rTop: 0.28, // and at the crown — the same taper the surface motes' helix is fitted to
        len: 0.26,
        lenVar: 0.4, // 0.16..0.36 of h = 0.58..1.36 world. SHORT — a stub, not a fork of sky lightning
        spread: 0.9, // +/- 52 degrees off horizontal, so some climb and some drop
        jag: 0.05,   // ~0.19 world of kink across a 0.58-1.36 long bolt
        width: 0.022, // ~0.08 world half-width, ~5px total at this camera: a bright thread
        taper: 0.25,
        halo: 4.0,     // ~40px across, which is the area bloom needs to see
        haloDim: 0.45, // centreline linear luma 0.80 x glow 3.2 x 0.45 = 1.15, over the 0.9 threshold,
                       // so the flare blooms in its own right rather than only feeding the core's
        color: 0x8cff9e, // linear luma 0.80, x3.2 = 2.55 against BLOOM_THRESHOLD 0.9 — it flares hard
        glow: 3.2,
      },
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
      // null so it claims no pool slot: the pool is live now and the biomineral is the organ that
      // lights its room. maw violet was 0x8c2ecc / mul 0.9, for when the arch gets its own lighting
      light: null,
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
      shine: null, // its glow is the membrane in the opening, not anything on the braids
      arc: null,   // and the biomineral is the power organ, not this one
    },
    {
      keys: [ 'habitat_preservator' ],
      path: RenderConfig.MODELS.habitatPreservator,
      h: 4.06, // 1.3x the 3.12 it shipped at, with the other three organs — the tallest of the four
      yaw: HASHED,
      light: null, // amber core was 0xd98c26 / mul 1.0 — see the assimilation row above
      anim: null, // worked case by case
      core: null,
      fly: null,
      shine: null,
      arc: null,
    },
    {
      keys: [ 'habitat_watcher' ],
      path: RenderConfig.MODELS.habitatWatcher,
      h: 2.81, // 1.3x the 2.16 it shipped at, with the other three organs
      yaw: HASHED,
      light: null, // pale flesh-pink eye was 0xf28c80 / mul 1.2 — see the assimilation row above
      anim: null, // worked case by case
      core: null,
      fly: null,
      shine: null,
      arc: null,
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
