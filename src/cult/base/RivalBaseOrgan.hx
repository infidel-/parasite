// persistent rival base organ record
package cult.base;

class RivalBaseOrgan extends _SaveObject
{
  public var id: Int;
  public var type: _RivalBaseOrganType;
  public var name: String;
  public var areaID: Int;
  public var x: Int;
  public var y: Int;
  public var width: Int;
  public var height: Int;
  public var health: Int;
  public var maxHealth: Int;
  public var icon: _Icon;
  public var destroyed: Bool;
  public static var _maxID: Int = 0;

  public function new(type: _RivalBaseOrganType, name: String, areaID: Int,
      x: Int, y: Int, width: Int, height: Int, maxHealth: Int, icon: _Icon)
    {
      init();
      id = _maxID++;
      this.type = type;
      this.name = name;
      this.areaID = areaID;
      this.x = x;
      this.y = y;
      this.width = width;
      this.height = height;
      this.maxHealth = maxHealth;
      health = maxHealth;
      this.icon = icon;
    }

// init organ fields
  public function init()
    {
      id = 0;
      type = RIVAL_SANCTUM;
      name = 'rival sanctum';
      areaID = -1;
      x = 0;
      y = 0;
      width = 1;
      height = 1;
      health = 1;
      maxHealth = 1;
      icon = { row: 4, col: 2 };
      destroyed = false;
    }

// called after load
  public function initPost(onLoad: Bool)
    {
      destroyed = health <= 0;
    }

// returns occupied footprint tiles
  public function footprint(): Array<{ x: Int, y: Int }>
    {
      var ret = [];
      for (dy in 0...height)
        for (dx in 0...width)
          ret.push({ x: x + dx, y: y + dy });
      return ret;
    }
}
