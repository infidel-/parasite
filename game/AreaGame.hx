// basic game area info

package game;

import const.WorldConst;

class AreaGame
{
  var region: RegionGame;

  public var id: Int; // area id
  public var typeID: String; // area type id - city block, university, military base, etc
  public var tileID: Int; // tile id on tilemap
  public var isKnown: Bool; // has the player seen this area?
  public var hasHabitat: Bool; // does this area have a habitat?
  public var habitatAreaID: Int; // area id of habitat
  public var info: AreaInfo; // area info link
  public var width: Int;
  public var height: Int;
  public var x: Int; // x,y in region
  public var y: Int;
  public var event: scenario.Event; // event link
  public var npc: List<scenario.NPC>; // npc list

  public var alertnessMod: Float; // changes to alertness until next reset
  // we store all changes until player leaves the current area for propagation
  public var alertness(get, set): Float; // area alertness (authorities) (0-100%)
  var _alertness: Float; // actual alertness storage
  public var interest(default, set): Float; // area interest for secret groups (0-100%)

  static var _maxID: Int = 0; // area id counter

  public function new(r: RegionGame, tv: String, vx: Int, vy: Int, w: Int, h: Int)
    {
      region = r;
      isKnown = false;
      hasHabitat = false;
      id = _maxID++;
      x = vx;
      y = vy;
      width = w;
      height = w;
      _alertness = 0;
      alertnessMod = 0;
      interest = 0;
      habitatAreaID = 0;
      npc = new List();

      setType(tv);
    }


// change area type
  public function setType(t: String)
    {
      typeID = t;
      info = WorldConst.getAreaInfo(typeID);

      if (typeID == WorldConst.AREA_GROUND)
        tileID = Const.TILE_REGION_GROUND;
      else if (typeID == WorldConst.AREA_CITY_LOW)
        tileID = Const.TILE_REGION_CITY_LOW;
      else if (typeID == WorldConst.AREA_CITY_MEDIUM)
        tileID = Const.TILE_REGION_CITY_MEDIUM;
      else if (typeID == WorldConst.AREA_CITY_HIGH)
        tileID = Const.TILE_REGION_CITY_HIGH;
      else if (typeID == WorldConst.AREA_MILITARY_BASE)
        tileID = Const.TILE_REGION_MILITARY_BASE;
      else if (typeID == WorldConst.AREA_FACILITY)
        tileID = Const.TILE_REGION_FACILITY;
    }


// set alertness without counting changes 
// used in alertness propagation
  public inline function setAlertness(v: Float)
    {
      _alertness = Const.clampFloat(v, 0, 100.0); 
    }


  public function toString(): String
    {
      return '(' + x + ',' + y + '): ' + typeID + ' alertness:' + alertness +
        ' interest:' + interest;
    }


// ========================== SETTERS ====================================


  function get_alertness()
    { return _alertness; }

  function set_alertness(v: Float)
    {
      // save alertness changes for later use
      alertnessMod += v - _alertness;
      return _alertness = Const.clampFloat(v, 0, 100.0); 
    }

  function set_interest(v: Float)
    { return interest = Const.clampFloat(v, 0, 100.0); }
}
