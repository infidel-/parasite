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
