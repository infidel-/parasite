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
  cells:Array<{ col:Int, row:Int }>, // indexed like the placements, so index i IS placement i's cell
  solidMask:Array<Bool>,
  ghostMask:Array<Bool>,
  hullMask:Array<Bool>,
  ghostIdx:Int,                      // placement the ghost serves, -1 for none. HELD across the
                                     // fade-out, when the player has already stepped off the cell
  t:Float,                           // ghost level, 0 solid .. 1 fully faded. one per BATCH, not per
                                     // instance: the player stands in exactly one cell
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

// the baked glb an object type draws as, or null for the ordinary sprite path
  public static function modelFor(type:String):String
    {
      return switch (type)
        {
          case 'sewer_exit', 'habitat_exit': RenderConfig.MODELS.sewerExit;
          default: null;
        };
    }

// place every prop-backed object in the area, grouped per model path. `yaw` decides which way a prop
// faces from its cell (a ladder wants its back to a wall); the area kind owns that rule, because only
// it knows what is solid. the returned batches MUST be handed to cull() every frame — Models.instanced
// turns three's own frustum cull off, so nothing else ever trims their instance counts
  public static function build(scene:Scene, game:Game, targetH:Float, yaw:Int->Int->Float):Array<PropBatch>
    {
      var byPath:Map<String, Array<{ x:Float, z:Float, yaw:Float }>> = new Map();
      var cellsByPath:Map<String, Array<{ col:Int, row:Int }>> = new Map();
      for (o in game.area.getObjects())
        {
          var path = modelFor(o.type);
          if (path == null)
            continue;
          if (!byPath.exists(path))
            {
              byPath.set(path, []);
              cellsByPath.set(path, []);
            }
          var w = CityConfig.cellToWorld(o.x, o.y);
          byPath.get(path).push({ x: w.x, z: w.z, yaw: yaw(o.x, o.y) });
          // pushed in the SAME iteration as its placement, so the two share an index — and that shared
          // index is the whole mechanism turning "the player stands on cell X" into an instance to fade
          cellsByPath.get(path).push({ col: o.x, row: o.y });
        }
      var C = RenderConfig.OBJMARK;
      var out:Array<PropBatch> = [];
      for (path => places in byPath)
        out.push({
          solid: Models.instanced(scene, path, places, targetH, SOLID),
          ghost: Models.instanced(scene, path, places, targetH, GHOST),
          hull: Models.instanced(scene, path, places, targetH, HULL(C.color, C.hullW)),
          cells: cellsByPath.get(path),
          solidMask: [for (_ in places) true],
          ghostMask: [for (_ in places) false],
          hullMask: [for (_ in places) false],
          ghostIdx: -1,
          t: 0.0,
        });
      return out;
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
