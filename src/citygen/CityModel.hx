package citygen;

// pure city data model — no three.js. The generator (CityGen) produces a City;
// the renderer (render.World) consumes it. Keeping this dependency-free lets the
// real game reuse layout/logic without dragging in a renderer

enum abstract Tile(Int) from Int to Int {
  var Building = 0;
  var Road = 1;
  var Alley = 2;
  var Walkway = 3;
}

// a building footprint. winForce/winBlock carry direction overrides
// (0=+z,1=-z,2=+x,3=-x): force windows (courtyard inner faces) or block them
// (an L's back-courtyard faces). winInset > 0 insets a courtyard window run
class Building {
  public var col:Int;
  public var row:Int;
  public var w:Int;
  public var d:Int;
  public var h:Float;
  public var roof:Int;
  public var facade:Int;
  public var winForce:Array<Int>;
  public var winBlock:Array<Int>;
  public var winInset:Float;
  public var drop:Bool = false; // transient: generator marks degenerate shape pieces for removal
  public var shapeKeep:Bool = false; // transient: keep inner pieces of a valid composite shape
  public var skipWindowFloor:Int = -1; // transient/render hint: omit one zero-based window floor
  public var shop:Int = -1;       // -1 = normal building; 0..N-1 = single-story shop type index
  public var shopOpen:Bool = false; // shop only: lit/open (glows at night) vs dark/closed
  public var shopDoor:Int = 0;      // shop only: entrance-cell selector (hashed per street face)

  public function new(col:Int, row:Int, w:Int, d:Int, h:Float, roof:Int, facade:Int,
      ?winForce:Array<Int>, ?winBlock:Array<Int>, winInset:Float = 0) {
    this.col = col; this.row = row; this.w = w; this.d = d;
    this.h = h; this.roof = roof; this.facade = facade;
    this.winForce = winForce; this.winBlock = winBlock; this.winInset = winInset;
  }
}

typedef Cell = { col:Int, row:Int };

// a carved inner-courtyard rect (cell coords, inclusive): an enclosed open pocket ringed by
// buildings. used by the game layer to place clutter that must not block a through-corridor
typedef CourtRect = { x0:Int, y0:Int, x1:Int, y1:Int };

// debug locator for a П-shaped building: world centre + framing radius
// x/z/r = locator center + radius (overhead camera focus). `front`, when present, is
// the street cell directly outside the building's street face — the debug cycler
// teleports the player icon there (keeps the building's scale legible) while the
// camera keeps its usual overhead focus.
typedef PShape = { x:Float, z:Float, r:Float, ?front:{ col:Int, row:Int } };

// a П candidate: its strips (so the locator can verify all survived) + its locator
typedef PGroup = { strips:Array<Building>, ps:PShape };

// a composite candidate: its pieces + its locator; frontDir is required street face
typedef ShapeGroup = { pieces:Array<Building>, ps:PShape, ?frontDir:Int };

typedef City = {
  tiles:Array<Array<Tile>>,
  buildings:Array<Building>,
  lamps:Array<Cell>,
  start:Cell,
  deadends:Int,
  turns:Int,
  pshapes:Array<PShape>,
  turnspots:Array<PShape>,
  lshapes:Array<PShape>,
  tshapes:Array<PShape>,
  plusshapes:Array<PShape>,
  shopspots:Array<PShape>,
  courtyards:Array<CourtRect>,
};
