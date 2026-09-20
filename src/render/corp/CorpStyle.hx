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
  // PLACEHOLDERS, EVERY ONE, and they are the city's and the downtown district's rather than the
  // facility's so nothing here can quietly ship as reused compound art. Phase 3 of the 3D port
  // replaces the whole block with a `corp/` set; until it does, this exists so the shell can be
  // put on screen and walked around.
  //
  // the three PANE labels are the exception and are the facility's on purpose: a pane maps 0..1
  // over a quad whose height is derived from the art's own aspect (FacilityGeom.paneTall), so any
  // other image here is a STRETCH rather than a placeholder. They go when the corp window set is
  // authored and its aspect measured.
  public static inline var WALL_EXTERIOR = 'textures/downtown/glass-dark.png';
  public static inline var WALL_CORRIDOR = 'textures/city/wall-1.png';
  public static inline var WALL_OPEN = 'textures/city/wall-2.png';
  public static inline var WALL_CUBICLE = 'textures/city/wall-3.png';
  public static inline var WALL_MEETING = 'textures/city/wall-4.png';
  public static inline var WALL_KITCHEN = 'textures/city/wall-5.png';
  public static inline var WALL_EXEC = 'textures/city/wall-6.png';
  public static inline var WALL_WASHROOM = 'textures/city/wall-7.png';
  public static inline var WALL_SERVER = 'textures/downtown/wall-mechanical.png';
  public static inline var WALL_LIFT = 'textures/downtown/podium-sleek.png';

  public static inline var FLOOR_CARPET = 'textures/city/ground-walkway.png';
  public static inline var FLOOR_OPEN = 'textures/downtown/ground-walkway.png';
  public static inline var FLOOR_CUBICLE = 'textures/city/ground-alley.png';
  public static inline var FLOOR_MEETING = 'textures/downtown/ground-alley.png';
  public static inline var FLOOR_KITCHEN = 'textures/facility/floor-office.png';
  public static inline var FLOOR_EXEC = 'textures/facility/floor-wash.png';
  public static inline var FLOOR_WASHROOM = 'textures/facility/floor-tile.png';
  public static inline var FLOOR_SERVER = 'textures/facility/floor-concrete.png';
  public static inline var FLOOR_LIFT = 'textures/city/roof-base-concrete.png';

  public static inline var ROOF = 'textures/downtown/roof-base.png';
  public static inline var COPING = 'textures/city/coping.png';
  public static inline var WINDOW_LIT = 'textures/facility/window-ribbon-lit.png';
  public static inline var WINDOW_LIT_2 = 'textures/facility/window-ribbon-2tile-lit.png';
  public static inline var WINDOW_HIGH_TEX = 'textures/facility/window-high.png';
  public static inline var WINDOW_HEAD = 'textures/facility/window-head.png';

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
      var into = [for (_ in 0...render.facility.FacilityStyle.SURF_SLOTS) WALL_CORRIDOR];
      into[Surf.OPEN] = WALL_OPEN;
      into[Surf.CUBICLE] = WALL_CUBICLE;
      into[Surf.MEETING] = WALL_MEETING;
      into[Surf.KITCHEN] = WALL_KITCHEN;
      into[Surf.EXEC] = WALL_EXEC;
      into[Surf.WASHROOM] = WALL_WASHROOM;
      into[Surf.SERVER] = WALL_SERVER;
      into[Surf.LIFT] = WALL_LIFT;
      return {
        kind: 'corp',
        tex: {
          floor: floor,
          wallOut: WALL_EXTERIOR,
          wallInto: into,
          pane: WINDOW_LIT,
          pane2: WINDOW_LIT_2,
          paneHigh: WINDOW_HIGH_TEX,
          head: WINDOW_HEAD,
          roof: ROOF,
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
