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
    },
    {
      keys: [ 'habitat_biomineral' ],
      path: RenderConfig.MODELS.habitatBiomineral,
      h: 2.88,
      yaw: HASHED,
      light: { color: 0x33bf59, mul: 1.0 }, // crystal green
      anim: null, // worked case by case; a mineral spire is the one organ that should NOT sway
    },
    {
      keys: [ 'habitat_assimilation' ],
      path: RenderConfig.MODELS.habitatAssimilation,
      h: 2.64, // wider than it is tall, so this spans ~4.8 of the cell and overhangs into its
               // neighbours — at 1.8 the arch read squat beside the preservator and lost the
               // "something you could step through" silhouette
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
    },
    {
      keys: [ 'habitat_preservator' ],
      path: RenderConfig.MODELS.habitatPreservator,
      h: 3.12,
      yaw: HASHED,
      light: { color: 0xd98c26, mul: 1.0 }, // amber core
      anim: null, // worked case by case
    },
    {
      keys: [ 'habitat_watcher' ],
      path: RenderConfig.MODELS.habitatWatcher,
      h: 2.16,
      yaw: HASHED,
      light: { color: 0xf28c80, mul: 1.2 }, // pale flesh-pink eye
      anim: null, // worked case by case
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
