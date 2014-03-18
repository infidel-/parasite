// basic world area info

import ConstWorld;

class WorldArea
{
  public var id: Int; // area id
  public var typeID: String; // area type id - city block, university, military base, etc
  public var info: AreaInfo; // area info link
  public var alertness(default, set): Float; // area alertness (authorities) (0-100%)
  public var interest(default, set): Float; // area interest for secret groups (0-100%)

  static var _maxID: Int = 0; // area id counter

  public function new(tv: String)
    {
      typeID = tv;
      id = _maxID++;
      info = ConstWorld.getAreaInfo(typeID);
      alertness = 0;
      interest = 0;
    }


// ========================== SETTERS ====================================

  function set_alertness(v: Float)
    { return alertness = Const.clampFloat(v, 0, 100.0); }
  function set_interest(v: Float)
    { return interest = Const.clampFloat(v, 0, 100.0); }
}