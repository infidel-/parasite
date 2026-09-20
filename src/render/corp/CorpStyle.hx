package render.corp;

import Const;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Surf;
import render.facility.ShellOpts;

// every art path and tuning constant for the CORP TOWER, and the ShellOpts that says how its saved
// grid is read.
//
// the corp office shares render.facility's EMITTERS and none of its art. That is the whole shape of
// this file: it fills the same ShellTex the compound's FacilityStyle.shell() fills, with a
// different set of labels, so render.facility.FacilityGeom builds a tower floor without knowing
// one exists.
class CorpStyle
{
  // ---- the shell ---------------------------------------------------------------------------

  // the colour the fog and the sky share. they MUST be the same value: render.world.VisionMask's
  // rim channel takes visibility to zero at the area border, and zero only reads as nothing rather
  // than as a silhouette when the surface fades toward what is behind it
  public static inline var SKY = 0x0a0e16;
  // fog. PULLED IN hard against the facility's 200/460, because a corp floor is small and what is
  // past its edge is a 20-storey drop rather than more lot — the far street belongs in haze
  public static inline var FOG_NEAR = 90.0;
  public static inline var FOG_FAR = 240.0;

  // only the lit glazing blooms
  public static inline var BLOOM_THRESHOLD = 0.72;

  // how far a glb prop is still drawn from the camera, world units
  public static inline var PROP_CULL_R = 120.0;

  // ---- art ---------------------------------------------------------------------------------
  //
  // the corp set, authored for this kind and shared with nothing. Values are FITTED against the
  // facility's own built ladder rather than predicted: an interior floor lands 0.090-0.124 linear
  // against the compound's 0.094-0.135, an interior wall 0.115-0.219 against its 0.137-0.159, and
  // the exterior 0.031 against its 0.033. Each label's gamma is in art/textures.json.
  //
  // EIGHT of the nine floors come off TWO packed 2x2 sheets, which is the trade docs/3d-textures.md
  // describes: a quarter of the cost, roughly double the wrap error, and the neighbours fixing a
  // chroma no solo roll reaches — right for a family of carpets and stones and wrong for anything
  // that tiles across a whole facade. The server room's raised-access panel is the one solo floor
  // for exactly that reason: its grid has to close, and a packed cell's wrap error is a visible
  // step in a panel joint.
  public static inline var WALL_EXTERIOR = 'textures/corp/wall-curtain.png';
  // the corridor, the open plan, the cubicle farm and the server room share one painted
  // plasterboard: in a real tower they are the same wall, and a room reads by its FLOOR and its
  // furniture. the four that differ are the four with a material of their own
  public static inline var WALL_OFFICE = 'textures/corp/wall-office.png';
  public static inline var WALL_MEETING = 'textures/corp/wall-meeting.png';
  public static inline var WALL_KITCHEN = 'textures/corp/wall-kitchen.png';
  public static inline var WALL_WASHROOM = 'textures/corp/wall-washroom.png';
  public static inline var WALL_EXEC = 'textures/corp/wall-exec.png';
  public static inline var WALL_LIFT = 'textures/corp/wall-lift.png';

  public static inline var FLOOR_CARPET = 'textures/corp/floor-carpet.png';
  public static inline var FLOOR_OPEN = 'textures/corp/floor-open.png';
  public static inline var FLOOR_CUBICLE = 'textures/corp/floor-cubicle.png';
  public static inline var FLOOR_MEETING = 'textures/corp/floor-meeting.png';
  public static inline var FLOOR_KITCHEN = 'textures/corp/floor-kitchen.png';
  public static inline var FLOOR_EXEC = 'textures/corp/floor-exec.png';
  public static inline var FLOOR_WASHROOM = 'textures/corp/floor-washroom.png';
  public static inline var FLOOR_SERVER = 'textures/corp/floor-server.png';
  public static inline var FLOOR_LIFT = 'textures/corp/floor-lift.png';

  // one capping serves the wall head and the window head both: they ARE the same extrusion seen
  // from the same angle, which is the one case docs/3d-textures.md allows a label to be reused
  public static inline var CAP = 'textures/corp/cap-alu.png';
  public static inline var COPING = 'textures/corp/coping.png';
  // the glazing, one image per RUN LENGTH. their aspects are MEASURED off the built crops
  // (512x183 and 512x280) and not chosen — see ShellTex.aspect
  public static inline var WINDOW_3 = 'textures/corp/window-3bay.png';
  public static inline var WINDOW_2 = 'textures/corp/window-2bay.png';
  public static inline var WINDOW_ASPECT = 512 / 183.0;
  public static inline var WINDOW_ASPECT_2 = 512 / 280.0;

  // the FITTING art. one texture per FACE — a top is a different surface from a front, and one
  // sheet over both is the mistake docs/3d-geometry.md opens with
  public static inline var DESK_TOP = 'textures/corp/desk-top.png';
  public static inline var DESK_FRONT = 'textures/corp/desk-front.png';
  public static inline var DESK_SIDE = 'textures/corp/desk-side.png';
  public static inline var PARTITION = 'textures/corp/partition.png';
  public static inline var COUNTER_TOP = 'textures/corp/counter-top.png';
  public static inline var COUNTER_FRONT = 'textures/corp/counter-front.png';
  public static inline var VANITY_TOP = 'textures/corp/vanity-top.png';
  public static inline var STALL_PANEL = 'textures/corp/stall-panel.png';
  public static inline var TABLE_TOP = 'textures/corp/table-top.png';
  public static inline var TABLE_SIDE = 'textures/corp/table-side.png';
  public static inline var RACK_FRONT = 'textures/corp/rack-front.png';
  public static inline var RACK_SIDE = 'textures/corp/rack-side.png';
  public static inline var MIRROR = 'textures/corp/mirror.png';

  // ---- the fittings ------------------------------------------------------------------------
  //
  // every one of these is written at the compound's own scale, where FacilityStyle.WALL_H 6.0 is
  // one 3 m storey and a unit is therefore HALF A METRE. So a desk at 1.5 is 75 cm, a kitchen
  // counter at 1.8 is 90 cm, a cubicle spine at 2.8 is 1.4 m and a server rack at 4.0 is 2 m —
  // real heights, not chosen proportions.
  public static inline var DESK_H = 1.5;
  public static inline var COUNTER_H = 1.8;
  public static inline var TABLE_H = 1.5;
  public static inline var VANITY_H = 1.7;
  // the cubicle spine. 1.4 m is a real low-wall partition: over a seated head and under a standing
  // one, which is the whole point of the thing
  public static inline var PARTITION_H = 2.8;
  public static inline var PARTITION_T = 0.4;
  // a WC cubicle's own divider, 1.9 m, and a 15 cm panel
  public static inline var STALL_H = 3.8;
  public static inline var STALL_T = 0.3;
  // the mirror band over the basin run, sill to head
  public static inline var MIRROR_Y0 = 2.2;
  public static inline var MIRROR_Y1 = 4.4;
  // how far a fitting is pulled back inside its cell, so two units in a run still read as two and
  // a unit against masonry does not z-fight the wall slab
  public static inline var FIT_INSET = 0.12;
  // a server rack. 2 m tall and 1 m deep, standing against the aisle it is reached from
  public static inline var RACK_H = 4.0;
  public static inline var RACK_D = 2.0;

  // the material scales. a MATERIAL scale and never the object's own size: the laminate grain, the
  // drawer course, the felt weave and the perforation pitch are each chosen against the thing they
  // draw. the drawer front's art carries THREE courses over its square, so at 3.0 a 1.5-high
  // carcass shows half of them, which is the two drawers a 75 cm pedestal really has
  public static inline var DESK_TILE = 4.0;
  public static inline var DESK_FRONT_TILE = 3.0;
  public static inline var COUNTER_TILE = 4.0;
  public static inline var PARTITION_TILE = 2.8;
  public static inline var RACK_TILE = 2.0;
  public static inline var MIRROR_TILE = 4.4;

  // ---- the glb props -------------------------------------------------------------------------
  //
  // seven models, and the split between them is docs/3d-models.md's own triage rather than a
  // preference: the PLANT is generated (a head of forty leaves has no parametric description), and
  // the chair, the monitor, the keyboard and the WC pan are HAND-MODELLED because each of their
  // briefs is a number on this list. The cooler and the printer are generated because a stepped
  // body with a recessed tray IS a silhouette.
  //
  // every height is the number render.Models.instanced scales the mesh to, and it scales by HEIGHT
  // ALONE — so a width here is a claim about the footprint the contact field darkens and never a
  // second scale.
  public static inline var CHAIR_H = 2.2;      // 1.1 m to the top of the back
  public static inline var CHAIR_W = 1.3;
  public static inline var CHAIR_YAW_JIT = 0.30;
  // how far the chair's centre stands back from the desk cell's own edge, into the seat cell
  public static inline var CHAIR_OUT = 1.35;
  public static inline var MON_H = 1.66;       // the built mesh exactly, so the batch's scale is 1
  public static inline var MON_W = 1.95;
  public static inline var MON_D = 0.45;
  public static inline var KEY_H = 0.09;
  public static inline var KEY_W = 1.60;
  public static inline var KEY_D = 0.58;
  // where the two sit on the worktop, measured from the desk cell's BACK edge forward
  public static inline var MON_BACK = 0.85;
  public static inline var KEY_FWD = 2.55;
  // one desk cell in this many carries a workstation. A DESK RUN IS NOT A CALL CENTRE: every cell
  // manned puts a monitor every 2 m down a wall, which reads as a bank of screens rather than as
  // an office
  public static inline var WORK_EVERY = 2;
  public static inline var PLANT_H = 2.8;      // 1.4 m
  public static inline var PLANT_W = 1.35;
  public static inline var COOLER_H = 2.2;     // 1.1 m
  public static inline var COOLER_W = 0.55;
  public static inline var PRINTER_H = 2.2;
  public static inline var PRINTER_W = 1.05;
  public static inline var PRINTER_D = 1.30;
  public static inline var WC_H = 1.5;
  public static inline var WC_W = 0.80;
  public static inline var WC_D = 1.40;        // built to this exactly, so the cistern meets masonry
  // how far a wall-hugging prop's back stands off the masonry FACE (and not off the cell boundary,
  // which is a whole unit away — FacilityGeom.slab is what a corp wall really is)
  public static inline var PROP_GAP = 0.10;
  // one candidate cell in this many carries a floor prop, per family. a stride over the whole
  // candidate list and never a counter cap: the scan is row-major, so a cap spends the allowance
  // on the northernmost rooms (render.facility.FacilityDebris records it)
  public static inline var FLOOR_MAX = 10;

  // ---- the dressing --------------------------------------------------------------------------
  //
  // two PACK64 sheets and one 2x2 of signs. an 8x8 sheet is the wrong grid for a billboard and the
  // right one here, which is the measurement docs/3d-textures.md carries: a 1024 cut into 64 cells
  // hands each object ~89 px, and over the ~0.8 units one of these is DRAWN at that is 111 texels
  // per unit — half again past the carpet's own. density is art px over the size a thing is drawn
  // at, never over the cell it was cut from
  public static inline var CLUTTER_DESK_TEX = 'textures/corp/desk-clutter.png';
  public static inline var CLUTTER_UTIL_TEX = 'textures/corp/util-clutter.png';
  public static inline var CLUTTER_COLS = 8;
  public static inline var CLUTTER_CELLS = 64;
  // how many items a worktop cell may roll, and the roll REACHES ZERO on purpose: the empty cells
  // are what stop a desk run reading as a grid, which is the whole complaint this family answers
  public static inline var CLUTTER_MAX = 3;
  public static inline var CLUTTER_TRIES = 6;
  public static inline var CLUTTER_SZ = 0.55;
  public static inline var CLUTTER_SZ_VAR = 0.40;
  // how far proud of the worktop a decal lies. over the slab and under nothing
  public static inline var CLUTTER_Y = 0.03;
  public static inline var CLUTTER_CUT = 0.5;
  // and how far inside the worktop's own edge an item must keep its whole box
  public static inline var CLUTTER_INSET = 0.18;
  // the clearance between two items, counted ONCE per pair
  public static inline var CLUTTER_GAP = 0.10;

  // the wall signs. ONE sheet, four quadrants, four DIFFERENT aspects — see CorpSigns.ASPECT
  public static inline var SIGN_TEX = 'textures/corp/signs.png';
  // the longest edge of a sign quad; the other edge comes off the art's own aspect
  public static inline var SIGN_MAX = 2.1;
  // the height of a sign's CENTRE. clear of the tallest thing that can stand under it (a server
  // rack at RACK_H 4.0) and under the head of a WALL_H 6.0 storey
  public static inline var SIGN_Y = 4.6;
  // how far proud of the wall slab a sign hangs
  public static inline var SIGN_PROUD = 0.05;
  // and the shortest run of unbroken masonry that earns one. a sign every cell turns a wall into
  // a strip of stickers
  public static inline var SIGN_RUN_MIN = 3;

// the tower's own ShellOpts: how CorpModel reads a saved corp grid, and what the shell is dressed
// in. the shape FacilityStyle.shell() has, and the reason both exist
  public static function shell(): ShellOpts
    {
      var floor = [for (_ in 0...render.facility.FacilityStyle.SURF_SLOTS) (null : String)];
      floor[Surf.CARPET] = FLOOR_CARPET;
      floor[Surf.OPEN] = FLOOR_OPEN;
      floor[Surf.CUBICLE] = FLOOR_CUBICLE;
      floor[Surf.MEETING] = FLOOR_MEETING;
      floor[Surf.KITCHEN] = FLOOR_KITCHEN;
      floor[Surf.EXEC] = FLOOR_EXEC;
      floor[Surf.WASHROOM] = FLOOR_WASHROOM;
      floor[Surf.SERVER] = FLOOR_SERVER;
      floor[Surf.LIFT] = FLOOR_LIFT;
      // an interior face is picked off the surface it LOOKS INTO, so the corridor side of a
      // partition is painted board and the boardroom side of the same slab is not
      var into = [for (_ in 0...render.facility.FacilityStyle.SURF_SLOTS) WALL_OFFICE];
      into[Surf.MEETING] = WALL_MEETING;
      into[Surf.KITCHEN] = WALL_KITCHEN;
      into[Surf.EXEC] = WALL_EXEC;
      into[Surf.WASHROOM] = WALL_WASHROOM;
      into[Surf.LIFT] = WALL_LIFT;
      return {
        kind: 'corp',
        tex: {
          floor: floor,
          wallOut: WALL_EXTERIOR,
          wallInto: into,
          pane: WINDOW_3,
          pane2: WINDOW_2,
          aspect: WINDOW_ASPECT,
          aspect2: WINDOW_ASPECT_2,
          // a tower floor has no light well, so nothing ever draws this — it is filled with the
          // three-bay art so the warm compiles the same material the game will ask for
          paneHigh: WINDOW_3,
          head: CAP,
          roof: CAP,
          coping: COPING,
          // a tower floor has no roll-up shutter
          shutter: null,
          circ: Surf.CARPET,
        },
        surfOf: CorpModel.surfOf,
        fitOf: CorpModel.fitOf,
        tableOf: Const.isCorpTableTile,
        wallOf: CorpModel.wallOf,
        // and NO hangars: the lift car is nine cells of concrete in a ring of its own, which the
        // concrete-majority test would call a shed and arch a barrel vault over
        hangars: false,
      };
    }
}
