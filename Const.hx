import Player;

class Const
{
  public static var LAYER_MOUSE = 0; // mouse cursor layer - highest
  public static var LAYER_UI = 1; // ui layer
  public static var LAYER_AI = 10; // player, enemies, etc layer
  public static var LAYER_OBJECT = 20; // ground layer - bodies, items
  public static var LAYER_TILES = 30; // tilemap layer

  public static var TILE_WIDTH = 32; // tiles width, height
  public static var TILE_HEIGHT = 32;

  // text colors
  public static var COLOR_DEFAULT = 0;
  public static var COLOR_ALERT = 1;
  public static var COLOR_EVOLUTION = 2;
  public static var COLOR_AREA = 3;
  public static var COLOR_ORGAN = 4;
  public static var COLOR_WORLD = 5;

  // text color strings
  public static var TEXT_COLORS = 
    [ '#FFFFFF', '#FF0000', '#00FFFF', '#00AA00', '#DDDD00', '#FF9900' ];

  // entity spritemap indexes
  public static var FRAME_EMPTY = 0;


  public static var ROW_ALERT = 0;
  public static var FRAME_ALERT1 = 1;
  public static var FRAME_ALERT2 = 2;
  public static var FRAME_ALERT3 = 3;
  public static var FRAME_ALERTED = 4;

  // object row frames
  public static var FRAME_SEWER_HATCH = 0;

  public static var ROW_OBJECT = 1;
  public static var ROW_PARASITE = 2;
  public static var ROW_HUMAN = 3;
  public static var ROW_DOG = 4;
  public static var ROW_CIVILIAN = 5;
  public static var ROW_POLICE = 6;
  public static var FRAME_DEFAULT = 0;
  public static var FRAME_BODY = 1;
  public static var FRAME_MASK_POSSESSED = 2;
  public static var FRAME_MASK_REGION = 3;


  // tiles spritemap indexes
  public static var TILE_HIDDEN = 0;
  public static var TILE_GROUND = 1;
  public static var TILE_BUILDING = 2;

  public static var TILE_REGION_ROW = 8;
  public static var TILE_REGION_GROUND = 0;
  public static var TILE_REGION_CITY_LOW = 1;
  public static var TILE_REGION_CITY_MEDIUM = 2;
  public static var TILE_REGION_CITY_HIGH = 3;

  public static var TILE_WALKABLE = [ false, true, false ];
  public static var TILE_TYPE = [ 'hidden', 'ground', 'building' ];
  public static var TILE_WALKABLE_REGION = [ true, true, true, true];
  public static var TILE_TYPE_REGION = [ 'ground', 'cityLow', 'cityMed', 'cityHigh' ];


  // player stuff

  // movement directions
  public static var dirx = [ -1, -1, -1, 0, 0, 1, 1, 1 ];
  public static var diry = [ -1, 0, 1, -1, 1, -1, 0, 1 ];

  // common player actions 
  public static var PLAYER_ACTIONS =
    {
      // area
      attachHost: { id: 'attachHost', name: 'Attach To Host', energy: 0 },
      detach: { id: 'detach', name: 'Detach', energy: 0 },
      hardenGrip: { id: 'hardenGrip', name: 'Harden Grip', energy: 5 },
      invadeHost: { id: 'invadeHost', name: 'Invade Host', energy: 10 },
      reinforceControl: { id: 'reinforceControl', name: 'Reinforce Control', energy: 5 },
      doNothing: { id: 'doNothing', name: 'Do Nothing', energy: 0 },
      leaveHost: { id: 'leaveHost', name: 'Leave Host', energy: 0 },
      accessMemory: { id: 'accessMemory', name: 'Access Memory', energy: 0 },
      move: { id: 'move', name: 'Movement', energy: 0 },
//      enterSewers: { id: 'enterSewers', name: 'Enter Sewers', energy: 10 },

      // region
      enterArea: { id: 'enterArea', name: 'Enter Area', energy: 0 },
//      { id: '', name: '', ap:  },
    };


// get action by id
  public static inline function getAction(id: String): _PlayerAction
    {
      return Reflect.field(Const.PLAYER_ACTIONS, id);
    }


// get squared distance between two points
  public static inline function getDistSquared(x1: Int, y1: Int, x2: Int, y2: Int): Int
    {
      return (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1);
    }


// get distance between two points
  public static inline function getDist(x1: Int, y1: Int, x2: Int, y2: Int): Int
    {
      return Std.int(Math.sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1)));
    }


// log all object string and int properties 
  public static inline function debugObject(o: Dynamic)
    {
      var list: Array<Dynamic> = [ Inventory, Skills, Organs ];
      var fields = Reflect.fields(o);
      fields.sort(sortFunc);
      for (f in fields) 
        {
          var ff = Reflect.field(o, f);
          var className = Type.getClassName(Type.getClass(ff));
///          if (f == 'timers')
//            trace(f + ' ' + Type.getClassName(Type.getClass(ff)));
//          if (!Reflect.isFunction(ff) && 
//              (!Reflect.isObject(ff) || Type.getClass(ff) == String || f == 'name'))
          if (!Reflect.isFunction(ff) && 
              (!Reflect.isObject(ff) || className == null || className == 'String')) 
            Sys.println(f + ': ' + ff);

          else if (Lambda.has(list, Type.getClass(ff)))
            Sys.println(f + ': ' + ff);
        }
    }


  static function sortFunc(a: String, b: String)
    {
      if (a < b) return -1;
      if (a > b) return 1;
      return 0;
    }



// todo display
  public static inline function todo(s: String)
    {
      trace('TODO: ' + s);
    }


// return clamped value between min and max
  public static inline function clamp(v: Int, min: Int, ?max: Int): Int
    {
      if (v < min)
        v = min;
      else if (max != null && v > max)
        v = max;
      return v;
    }


// return clamped value between min and max (float)
  public static inline function clampFloat(v: Float, min: Float, ?max: Float): Float
    {
      if (v < min)
        v = min;
      else if (max != null && v > max)
        v = max;
      return v;
    }


// roll between X and Y
  public static inline function roll(min: Int, max: Int): Int
    {
      return min + Std.random(max - min + 1);
    }
}
