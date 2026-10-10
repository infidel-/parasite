package render.military;

import render.facility.FacilityModel;
import render.facility.FacilityRigOpts;
import render.facility.FacilityStyle;
import render.facility.ShellOpts;

// a military base's own art and light, handed to the facility emitters it is built with: the
// compound's ShellOpts and rig with every surface swapped (art/textures.json military/*). the
// GEOMETRY is the compound's — the same block buildings, hangar, ground and gate derivation — and
// nothing a player can see is
class MilitaryStyle
{
  public static inline var WALL_EXTERIOR = 'textures/military/wall-exterior.png';
  public static inline var ROOF = 'textures/military/roof.png';
  public static inline var COPING = 'textures/military/coping.png';
  public static inline var WINDOW_HEAD = 'textures/military/window-head.png';
  public static inline var WINDOW_LIT = 'textures/military/window-ribbon-lit.png';
  public static inline var WINDOW_LIT_2 = 'textures/military/window-ribbon-2tile-lit.png';
  public static inline var WINDOW_HIGH = 'textures/military/window-high.png';
  public static inline var DOOR_ENTRANCE = 'textures/military/door-entrance.png';
  public static inline var DOOR_INNER = 'textures/military/door-inner.png';
  public static inline var DOOR_HEAVY = 'textures/military/door-heavy.png';
  public static inline var DOOR_PRIVATE = 'textures/military/door-private.png';
  public static inline var DOOR_SHUTTER = 'textures/military/door-shutter.png';
  public static inline var DOOR_LAMP = 'textures/military/door-lamp.png';
  public static inline var WALL_HANGAR = 'textures/military/wall-hangar.png';
  public static inline var ROOF_HANGAR = 'textures/military/roof-hangar.png';
  public static inline var GROUND_ROAD = 'textures/military/ground-road.png';
  public static inline var GROUND_WALKWAY = 'textures/military/ground-walkway.png';
  // the lot is the motor pool's and the helipad's own apron concrete, the same material at the same
  // scale (render.military.MilitaryGeom)
  public static inline var GROUND_LOT = 'textures/military/apron.png';
  public static inline var GROUND_KERB = 'textures/military/ground-kerb.png';
  public static inline var GROUND_PAINT = 'textures/military/ground-paint.png';
  public static inline var ZONE = 'textures/military/floor-hazard.png';
  public static inline var GRIME = 'textures/military/grime.png';
  public static inline var CABLE = 'textures/military/cable.png';
  public static inline var ELEC = 'textures/military/electrical-pack.png';

  // the light: sodium-amber yard masts over an olive-grey fill under a less blue moon, cool-green
  // fluorescent tubes indoors, and warm bulkheads over the doors
  public static inline var MAST_COLOR = 0xffb066;
  public static inline var LAMP_COLOR = 0xc4d0b4;
  public static inline var DOOR_LAMP_COLOR = 0xffa040;

// the base's ShellOpts: the compound's reading of the grid in the base's own art
  public static function shell():ShellOpts
    {
      var o = FacilityStyle.shell();
      var t = o.tex;
      o.kind = 'military';
      t.wallOut = WALL_EXTERIOR;
      // the windows are the facility units repainted on their own cut, so their aspects are the same
      t.pane = WINDOW_LIT;
      t.pane2 = WINDOW_LIT_2;
      t.paneHigh = WINDOW_HIGH;
      t.head = WINDOW_HEAD;
      t.roof = ROOF;
      t.coping = COPING;
      t.shutter = DOOR_SHUTTER;
      t.door = [DOOR_ENTRANCE, DOOR_INNER, DOOR_HEAVY, DOOR_PRIVATE, DOOR_HEAVY];
      t.hood = DOOR_LAMP;
      t.hangarWall = WALL_HANGAR;
      t.vault = ROOF_HANGAR;
      t.road = GROUND_ROAD;
      t.walkway = GROUND_WALKWAY;
      t.lot = GROUND_LOT;
      t.kerb = GROUND_KERB;
      t.paint = GROUND_PAINT;
      t.zone = ZONE;
      t.grime = GRIME;
      t.cable = CABLE;
      t.elec = ELEC;
      t.mastColor = MAST_COLOR;
      t.lampColor = LAMP_COLOR;
      t.doorLampColor = DOOR_LAMP_COLOR;
      return o;
    }

// the base's night rig: the compound's sky and fog over a warmer, greener fill
  public static function rig():FacilityRigOpts
    {
      var r = FacilityStyle.rig();
      r.ambient = 0x4c5348;
      r.hemiSky = 0x5c6450;
      r.hemiGround = 0x1c1d14;
      r.moon = 0x8c96a8;
      return r;
    }
}
