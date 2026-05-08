// persistent custos roster entry
package cult.base;

class CustodesData extends _SaveObject
{
  public var id: Int;
  public var type: _CustosType;
  public var areaID: Int;
  public var x: Int;
  public var y: Int;
  public var anchorX: Int;
  public var anchorY: Int;
  public var health: Int;
  public var maxHealth: Int;
  public static var _maxID: Int = 0;

  public function new(type: _CustosType, areaID: Int,
      x: Int, y: Int, anchorX: Int, anchorY: Int)
    {
      init();
      id = _maxID++;
      this.type = type;
      this.areaID = areaID;
      this.x = x;
      this.y = y;
      this.anchorX = anchorX;
      this.anchorY = anchorY;
      maxHealth = type == FIRMUS ? 26 : 16;
      health = maxHealth;
    }

// init Custos fields
  public function init()
    {
      id = 0;
      type = FIRMUS;
      areaID = -1;
      x = 0;
      y = 0;
      anchorX = 0;
      anchorY = 0;
      health = 1;
      maxHealth = 1;
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {}
}
