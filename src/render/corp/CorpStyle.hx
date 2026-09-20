package render.corp;

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
        wallOf: CorpModel.wallOf,
        // and NO hangars: the lift car is nine cells of concrete in a ring of its own, which the
        // concrete-majority test would call a shed and arch a barrel vault over
        hangars: false,
      };
    }
}
