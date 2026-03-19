@:structInit
class _AIStateSearchArea extends _SaveObject
{
  public var originX: Int;
  public var originY: Int;
  public var radius: Int;
  public var pointID: Int;

// create persisted search-area state
  public function new(originX: Int, originY: Int, radius: Int,
      pointID: Int)
    {
      this.originX = originX;
      this.originY = originY;
      this.radius = radius;
      this.pointID = pointID;
    }

// init default search-area state
  public function init()
    {
      originX = -1;
      originY = -1;
      radius = 1;
      pointID = 0;
    }
}
