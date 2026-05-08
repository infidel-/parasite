// persistent cult base organ record
package cult.base;

import const.CultBaseConst;

class CultBaseOrgan extends _SaveObject
{
  public var id: Int;
  public var type: _CultBaseOrganType;
  public var level: Int;
  public var areaID: Int;
  public var x: Int;
  public var y: Int;
  public var direction: Int;
  public var health: Int;
  public var broken: Bool;
  public static var _maxID: Int = 0;

  public function new(type: _CultBaseOrganType, areaID: Int,
      x: Int, y: Int, ?direction: Int = 0)
    {
      init();
      id = _maxID++;
      this.type = type;
      this.areaID = areaID;
      this.x = x;
      this.y = y;
      this.direction = direction;
      health = maxHealth();
    }

// init organ fields
  public function init()
    {
      id = 0;
      type = COR_NEFANDUM;
      level = 1;
      areaID = -1;
      x = 0;
      y = 0;
      direction = 0;
      health = 1;
      broken = false;
    }

// repair loaded health fields
  public function initPost(onLoad: Bool)
    {
      if (health <= 0 && type != COR_NEFANDUM)
        {
          health = 0;
          broken = true;
        }
    }

// returns max health for current level/type
  public function maxHealth(): Int
    {
      return CultBaseConst.maxHealth(type, level);
    }

// returns true when organ can function
  public function isWorking(): Bool
    {
      return !broken && health > 0;
    }

// returns repair cost
  public function repairCost(): CultBaseResources
    {
      return CultBaseConst.repairCost(type);
    }

// returns next level upgrade cost
  public function upgradeCost(): CultBaseResources
    {
      return CultBaseConst.upgradeCost(type, level);
    }

// returns occupied footprint tiles
  public function footprint(): Array<{ x: Int, y: Int }>
    {
      return CultBaseConst.footprint(type, x, y);
    }
}
