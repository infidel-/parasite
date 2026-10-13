package render.lab;

import render.facility.FacilityModel.Surf;
import render.facility.FacilityStyle;
import render.facility.ShellOpts;

// the underground lab's art set and its tuning constants: the shell's ShellTex, the scene rig and
// the numbers the lab's own passes are written against.
//
// the lab is a SHELL KIND like the corp tower — render.facility's emitters build its floors, walls
// and doorways off this ShellTex — and it shares nothing else: every path below is lab art
// (art/textures.json `lab/*`, four packed 2x2 sheets and a door sheet)
class LabStyle
{
  // ---- the shell: floors, one per Surf the lab paints
  public static inline var FLOOR_ENTRANCE = 'textures/lab/floor-entrance.png';
  public static inline var FLOOR_VAT = 'textures/lab/floor-vat.png';
  public static inline var FLOOR_CORRIDOR = 'textures/lab/floor-corridor.png';
  public static inline var FLOOR_WORKSHOP = 'textures/lab/floor-workshop.png';
  public static inline var FLOOR_STORAGE = 'textures/lab/floor-storage.png';
  public static inline var FLOOR_RESEARCH = 'textures/lab/floor-research.png';
  public static inline var FLOOR_PAD = 'textures/lab/floor-pad.png';
  // the interior wall faces, picked off the room a face LOOKS INTO
  public static inline var WALL_ENTRANCE = 'textures/lab/wall-entrance.png';
  public static inline var WALL_VAT = 'textures/lab/wall-vat.png';
  public static inline var WALL_CORRIDOR = 'textures/lab/wall-corridor.png';
  public static inline var WALL_WORKSHOP = 'textures/lab/wall-workshop.png';
  public static inline var WALL_STORAGE = 'textures/lab/wall-storage.png';
  public static inline var WALL_RESEARCH = 'textures/lab/wall-research.png';
  // the bedrock: the cap over every rock cell (LabGeom) and the cladding on every wall face that
  // looks into rock, which the cap hides from this camera anyway
  public static inline var ROCK = 'textures/lab/rock.png';
  // the wall head, poured concrete
  public static inline var COPING = 'textures/lab/coping.png';
  // the four door leaves, one per look (LabDoors)
  public static inline var DOOR_BLAST = 'textures/lab/door-blast.png';
  public static inline var DOOR_SERVICE = 'textures/lab/door-service.png';
  public static inline var DOOR_RESEARCH = 'textures/lab/door-research.png';
  public static inline var DOOR_VAT = 'textures/lab/door-vat.png';

  // ---- the rock cap
  // how many cells past the area's edge the cap carries on, so the camera at the plate's rim looks
  // at more bedrock rather than at the fog colour where the grid stops
  public static inline var ROCK_MARGIN = 14;
  // the cap's own tile, world units per repeat — the rock's facets are fist-to-head sized at this
  public static inline var ROCK_TILE = 10.0;

  // ---- the doors
  // a blast leaf is a CELL wide (the doorway is two) and thicker than the compound's 0.12 leaf
  public static inline var DOOR_T = 0.28;
  // how far past CELL a leaf slides, so its stile does not stop in the reveal's own plane — the
  // trap FacilityStyle.DOOR_SLIDE_CLEAR records for the corp lift
  public static inline var DOOR_CLEAR = 0.06;
  // an opening slides shut or open over this many BASE_MS — heavier than the compound's swing
  public static inline var DOOR_MULT = 0.6;
  // a pair's cull radius about the opening's centre: a slid leaf's far stile is 2 CELL + DOOR_CLEAR
  // out, plus the leaf's own height for the sphere
  public static inline var DOOR_CULL_R = 10.0;

  // ---- the clone vats (render.lab.LabVats, models-src/lab/vat_build.py). every height is the glb's
  // measured one, so Models.instanced draws each part at scale 1 and the script's numbers hold
  public static inline var VAT_H = 9.8636;         // the frame, slab to the feed pipes' crown
  // the cylinder's axis north of the 2x3 footprint's centre: on the back 2x2's centre (AXIS_Y)
  public static inline var VAT_AXIS = 2.0;
  public static inline var VAT_GLASS_Y = 1.0;      // the base ring's top, where glass and medium stand
  public static inline var VAT_GLASS_H = 7.0;
  public static inline var VAT_FLUID_H = 6.7;
  public static inline var VAT_GLASS_OPACITY = 0.22;
  public static inline var VAT_FLUID_OPACITY = 0.62;
  // the medium lights itself through its own map, times this colour
  public static inline var VAT_FLUID_GLOW = 0x2f7a24;
  // the clone floats CLONE_FLOAT clear of the ring, CLONE_H from its feet to its tentacles' tips
  public static inline var CLONE_H = 5.0;
  public static inline var CLONE_FLOAT = 0.6;
  public static inline var CLONE_YAW = 0.0;
  public static inline var CLONE_SLUMP_H = 1.4;
  // the heap replaces the floating clone once the level is under this fraction of the clone's height
  public static inline var CLONE_SLUMP_AT = 0.35;
  // a purged vat drains over this many BASE_MS
  public static inline var VAT_DRAIN_MULT = 20.0;
  // each vat's own green lamp, inside the glass, faded out with its level
  public static inline var VAT_LAMP_Y = 5.0;
  public static inline var VAT_LAMP_COLOR = 0x52ff6e;
  public static inline var VAT_LAMP_MUL = 1.6;
  // a vat's cull radius about its placement: the frame is 7.8 x 11.8 and 10.3 tall
  public static inline var VAT_CULL_R = 12.0;

  // ---- the lift (render.lab.LabLift, models-src/lab/lift_build.py)
  public static inline var LIFT_SHAFT_H = 9.87;    // the shaft glb's measured height
  public static inline var LIFT_DECK_GLB_H = 2.74; // the car glb's, guard rail and clamps included
  public static inline var LIFT_DECK_H = 0.25;     // the deck's tread, which is what anyone stands on
  // the car comes down from this far up the shaft on arrival, over this many BASE_MS. 5.5 keeps its
  // rope clamps under the sheave the whole way
  public static inline var LIFT_DROP = 5.5;
  public static inline var LIFT_MULT = 16.0;
  public static inline var LIFT_CULL_R = 10.0;

  // ---- the furniture and the box machines (render.lab.LabInterior): a piece's cull radius about its
  // placement, the container's half-diagonal and its height
  public static inline var PIECE_CULL_R = 9.0;

  // ---- the rig. no moon and no sky: the bedrock is the ceiling, so the background and the fog are
  // one near-black (render.world.VisionMask fades unseen cells TO this, so they must match)
  public static inline var DARK = 0x040608;
  // fog closes in well past the camera's own reach (CAMERA_FACILITY, up to ~51 units off), so the
  // room the player stands in is never fogged and the far end of the corridor is
  public static inline var FOG_NEAR = 64.0;
  public static inline var FOG_FAR = 150.0;
  // the fill. cold and low — the lamps are what light this place
  public static inline var AMBIENT = 0x3a4657;
  public static inline var AMBIENT_I = 2.4;
  public static inline var HEMI_SKY = 0x46536e;
  public static inline var HEMI_GROUND = 0x141a22;
  public static inline var HEMI_I = 1.4;

// the lab's ShellOpts: how render.lab.LabModel reads the saved grid, and what the shell is dressed in
  public static function shell():ShellOpts
    {
      var floor = [for (_ in 0...FacilityStyle.SURF_SLOTS) (null : String)];
      floor[Surf.LINO] = FLOOR_CORRIDOR;
      floor[Surf.LAB_ENTRANCE] = FLOOR_ENTRANCE;
      floor[Surf.LAB_VAT] = FLOOR_VAT;
      floor[Surf.LAB_WORKSHOP] = FLOOR_WORKSHOP;
      floor[Surf.LAB_STORAGE] = FLOOR_STORAGE;
      floor[Surf.LAB_RESEARCH] = FLOOR_RESEARCH;
      floor[Surf.LAB_PAD] = FLOOR_PAD;
      var into = [for (_ in 0...FacilityStyle.SURF_SLOTS) WALL_CORRIDOR];
      into[Surf.LAB_ENTRANCE] = WALL_ENTRANCE;
      into[Surf.LIFT] = WALL_ENTRANCE;
      into[Surf.LAB_VAT] = WALL_VAT;
      into[Surf.LAB_PAD] = WALL_VAT;
      into[Surf.LAB_WORKSHOP] = WALL_WORKSHOP;
      into[Surf.LAB_STORAGE] = WALL_STORAGE;
      into[Surf.LAB_RESEARCH] = WALL_RESEARCH;
      return {
        kind: 'lab',
        tex: {
          floor: floor,
          wallOut: ROCK,
          wallInto: into,
          // the lab has no windows and no light wells, so nothing draws these; filled with real lab
          // art so a stray pane could never fall back to another kind's
          pane: WALL_CORRIDOR,
          pane2: WALL_CORRIDOR,
          aspect: 1.0,
          aspect2: 1.0,
          paneHigh: WALL_CORRIDOR,
          head: COPING,
          roof: COPING,
          coping: COPING,
          shutter: null,
          pocket: null,
          sill: null,
          // FacilityDoors never runs here (LabDoors slides its own leaves), so this is only ever
          // indexed by nothing — five so the array is the length the emitter expects
          door: [DOOR_BLAST, DOOR_SERVICE, DOOR_SERVICE, DOOR_RESEARCH, DOOR_VAT],
          circ: Surf.LINO,
          hood: COPING,
        },
        surfOf: LabModel.surfOf,
        wallOf: LabModel.wallOf,
        fitOf: function(t:Int) return 0,
        tableOf: function(t:Int) return false,
        // the lab's partitions are cut out of the same bedrock as its perimeter
        wallIn: FacilityStyle.WALL_T,
        hangars: false,
        hangarH: FacilityStyle.WALL_H,
        deck: false,
        parapet: false,
      };
    }
}
