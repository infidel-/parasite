package render.military;

import render.facility.FacilityModel;
import render.facility.FacilityModel.Surf;
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
  public static inline var EXIT_SIGN = 'textures/military/exit-sign.png';
  public static inline var WALL_POINTS = 'textures/military/wall-points.png';
  public static inline var ROOF_CLUTTER = 'textures/military/roof-clutter.png';

  // the inside: one floor per room kind and one wall face per surface it looks into
  public static inline var FLOOR_BARRACKS = 'textures/military/floor-barracks.png';
  public static inline var FLOOR_MESS = 'textures/military/floor-mess.png';
  public static inline var FLOOR_BRIEFING = 'textures/military/floor-briefing.png';
  public static inline var FLOOR_OFFICE = 'textures/military/floor-office.png';
  public static inline var FLOOR_LATRINE = 'textures/military/floor-latrine.png';
  public static inline var FLOOR_CORRIDOR = 'textures/military/floor-corridor.png';
  public static inline var FLOOR_HANGAR = 'textures/military/floor-hangar.png';
  public static inline var WALL_CORRIDOR = 'textures/military/wall-corridor.png';
  public static inline var WALL_ROOM = 'textures/military/wall-room.png';
  public static inline var WALL_OFFICE = 'textures/military/wall-office.png';
  public static inline var WALL_LATRINE = 'textures/military/wall-latrine.png';

  // the light: sodium-amber yard masts over an olive-grey fill under a less blue moon, cool-green
  // fluorescent tubes indoors, and warm bulkheads over the doors
  public static inline var MAST_COLOR = 0xffb066;
  public static inline var LAMP_COLOR = 0xc4d0b4;
  public static inline var DOOR_LAMP_COLOR = 0xffa040;
  // a fit grid cell an object stands on (`objects`): not 0, under FacilityModel.FIT_HOLE and under
  // every tile id fitOf deals
  public static inline var FIT_OBJECT = 1;
  // the hangar's wall head: two storeys, so the shutters stand over the jet's 9.8 tail ("hangar doors
  // are too small for the plane to pass through ... military hangar should be double the height").
  // Only the first storey is a wall: the second fades with the vault (FacilityGeom.storey), so inside
  // the shed reads as tall as it always did ("we don't really need to see them while inside")
  public static inline var HANGAR_H = 2 * FacilityStyle.WALL_H;

// the base's ShellOpts: the compound's reading of the grid in the base's own art
  public static function shell():ShellOpts
    {
      var o = FacilityStyle.shell();
      var t = o.tex;
      o.kind = 'military';
      o.hangarH = HANGAR_H;
      o.surfOf = surfOf;
      o.fitOf = fitOf;
      // every floor slot the base can reach, each in its own art. TILE and OFFICE are the lab
      // building's room surfaces and a base deals neither, but a cell the theme pass leaves on them
      // still gets the office floor rather than the laboratory's
      var floor = [for (_ in 0...FacilityStyle.SURF_SLOTS) (null : String)];
      floor[Surf.TILE] = FLOOR_OFFICE;
      floor[Surf.OFFICE] = FLOOR_OFFICE;
      floor[Surf.HQ] = FLOOR_OFFICE;
      floor[Surf.LINO] = FLOOR_CORRIDOR;
      floor[Surf.CONCRETE] = FLOOR_HANGAR;
      floor[Surf.WASH] = FLOOR_LATRINE;
      floor[Surf.BARRACKS] = FLOOR_BARRACKS;
      floor[Surf.MESS] = FLOOR_MESS;
      floor[Surf.BRIEFING] = FLOOR_BRIEFING;
      t.floor = floor;
      var into = [for (_ in 0...FacilityStyle.SURF_SLOTS) WALL_ROOM];
      into[Surf.LINO] = WALL_CORRIDOR;
      into[Surf.HQ] = WALL_OFFICE;
      into[Surf.OFFICE] = WALL_OFFICE;
      into[Surf.BRIEFING] = WALL_OFFICE;
      into[Surf.WASH] = WALL_LATRINE;
      t.wallInto = into;
      t.wallOut = WALL_EXTERIOR;
      // the windows are the facility units repainted on their own cut, so their aspects are the same
      t.pane = WINDOW_LIT;
      t.pane2 = WINDOW_LIT_2;
      t.paneHigh = WINDOW_HIGH;
      t.head = WINDOW_HEAD;
      t.roof = ROOF;
      t.capRoof = true;
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
      t.exitSign = EXIT_SIGN;
      t.wallPoints = WALL_POINTS;
      t.roofClutter = ROOF_CLUTTER;
      t.mastColor = MAST_COLOR;
      t.lampColor = LAMP_COLOR;
      t.doorLampColor = DOOR_LAMP_COLOR;
      return o;
    }

// the lockers, the gun cabinet and the safe the generator stands as objects, marked FIT_OBJECT in the
// fit grid fitOf filled, for render.facility.FacilityCable's socket test
  public static function objects(m:Facility, area:game.AreaGame):Void
    {
      for (o in area.getObjects())
        if (o.type == 'locker' ||
            o.type == 'gunCabinet' ||
            o.type == 'safe')
          m.fit[o.y][o.x] = FIT_OBJECT;
    }

// tile id -> fitting: every piece of room furniture is its own tile id, so render.facility
// .FacilityCable hangs no socket behind a bunk and drops a lead off a radio rack (MilitaryInterior
// .powered). The floors and everything outside the rooms are 0
  public static function fitOf(t:Int):Int
    {
      return (t > Const.TILE_MIL_FLOOR_LATRINE &&
        t <= Const.TILE_MIL_SHOWER ? t : 0);
    }

// tile id -> surface, the compound's reading plus the base's own row-20 room floors. Its
// furniture reads as plain room floor (TILE), which FacilityModel.themeRooms then paints in the
// room's own theme, so a bunk stands on barracks boards and not on a hole
  public static function surfOf(t:Int):Surf
    {
      if (t == Const.TILE_MIL_FLOOR_BARRACKS)
        return Surf.BARRACKS;
      if (t == Const.TILE_MIL_FLOOR_MESS)
        return Surf.MESS;
      if (t == Const.TILE_MIL_FLOOR_BRIEFING)
        return Surf.BRIEFING;
      if (t == Const.TILE_MIL_FLOOR_HQ)
        return Surf.HQ;
      if (t == Const.TILE_MIL_FLOOR_LATRINE)
        return Surf.WASH;
      // a hangar's fuel drums stand on its floor. Left to the row-19 catch-all they were LOT, a
      // square of yard apron sunk KERB_DROP into the shed's concrete at every drum cell ("hangar floor
      // in front of barrels is different (hole again?)"). Not off the west neighbour like a parked
      // vehicle's footprint: on the west wall that neighbour IS the wall
      if (t == Const.TILE_MIL_DRUMS)
        return Surf.CONCRETE;
      if (t >= Const.OFFSET_ROW20)
        return Surf.TILE;
      return FacilityModel.surfOf(t);
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
