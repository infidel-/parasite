// the underground lab's OBJECT atlas: where the doors, the lift and the clone vats find their 2D
// icons. All that is left of the 2D lab tileset — the area is drawn in 3D (render.lab) and its
// tiles are tiles.Default's — and it stays for two reasons: the icons still draw what render.lab
// does not yet build, and objects.Door.canSeeThrough tells a lab door from a glass one by this image

package tiles;

class UndergroundLab
{
  public static var OBJECTS_IMAGE = 'undergroundLabObjects1';
  public static var OBJECTS_IMAGE_PATH = 'img/underground-lab-objects1.png';
  public static var DOOR_HORIZONTAL_CLOSED_LEFT: _Icon = { row: 6, col: 0 };
  public static var DOOR_HORIZONTAL_CLOSED_RIGHT: _Icon = { row: 6, col: 1 };
  public static var DOOR_HORIZONTAL_OPEN_LEFT: _Icon = { row: 7, col: 0 };
  public static var DOOR_HORIZONTAL_OPEN_RIGHT: _Icon = { row: 7, col: 1 };
  public static var DOOR_VERTICAL_CLOSED_UPPER: _Icon = { row: 6, col: 2 };
  public static var DOOR_VERTICAL_CLOSED_LOWER: _Icon = { row: 7, col: 2 };
  public static var DOOR_VERTICAL_OPEN_UPPER: _Icon = { row: 6, col: 3 };
  public static var DOOR_VERTICAL_OPEN_LOWER: _Icon = { row: 7, col: 3 };
  // NOTE: flushed cloning vat is +2 col from regular vat
  public static var CLONING_VAT: _IconBlock =
    { row: 6, col: 4, width: 2, height: 3 };
  public static var ELEVATOR: _IconBlock =
    { row: 8, col: 0, width: 2, height: 2 };
}
