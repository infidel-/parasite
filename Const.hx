import game.*;

class Const
{
  public static var LAYER_MOUSE = 0; // mouse cursor layer - highest
  public static var LAYER_UI = 1; // ui layer
  public static var LAYER_EFFECT = 5; // visual effects layer 
  public static var LAYER_AI = 10; // player, enemies, etc layer
  public static var LAYER_OBJECT = 20; // ground layer - bodies, items
  public static var LAYER_TILES = 30; // tilemap layer

  public static var TILE_WIDTH = 32; // tiles width, height
  public static var TILE_HEIGHT = 32;

  // text color strings
  public static var TEXT_COLORS: Map<_TextColor, String> = 
    [ 
      COLOR_DEFAULT => '#FFFFFF',
      COLOR_DEBUG => '#555555',
      COLOR_ALERT => '#FF0000',
      COLOR_EVOLUTION => '#00FFFF',
      COLOR_AREA => '#00AA00',
      COLOR_ORGAN => '#DDDD00',
      COLOR_WORLD => '#FF9900',
      COLOR_HINT => '#A020F0',
      COLOR_TIMELINE => '#F03378',
      COLOR_MESSAGE => '#1CD450',
    ];

  // entity spritemap indexes
  public static var FRAME_EMPTY = 0;

  // alert row frames
  public static var FRAME_ALERT1 = 1;
  public static var FRAME_ALERT2 = 2;
  public static var FRAME_ALERT3 = 3;
  public static var FRAME_ALERTED = 4;
  public static var FRAME_PANIC = 5;
  public static var FRAME_PARALYSIS = 6;

  // region row frames
  public static var FRAME_EVENT_UNKNOWN = 1;
  public static var FRAME_EVENT_KNOWN = 2;
  public static var FRAME_EVENT_NPC = 3;
  public static var FRAME_HABITAT = 4;

  // object row frames
  public static var FRAME_SEWER_HATCH = 0;
  public static var FRAME_PAPER = 1;

  // effect row frames
  public static var FRAME_PANIC_GAS = 0;
  public static var FRAME_PARALYSIS_GAS = 1;

  public static var ROW_ALERT = 0;
  public static var ROW_REGION_ICON = 1;
  public static var ROW_OBJECT = 2;
  public static var ROW_EFFECT = 3;
  public static var ROW_PARASITE = 4;
  public static var ROW_HUMAN = 5;
  public static var ROW_DOG = 6;
  public static var ROW_CIVILIAN = 7;
  public static var ROW_POLICE = 8;
  public static var ROW_SOLDIER = 9;
  public static var ROW_AGENT = 10;
  public static var ROW_BLACKOPS = 11;

  public static var FRAME_DEFAULT = 0;
  public static var FRAME_BODY = 1;
  public static var FRAME_MASK_POSSESSED = 2;
  public static var FRAME_MASK_REGION = 3;


  // tiles spritemap indexes
  public static var TILE_HIDDEN = 0;
  public static var TILE_GROUND = 1;
  public static var TILE_BUILDING = 2;
  public static var TILE_ROCK = 3;
  public static var TILE_TREE = 4;
  public static var TILE_WALL = 5;

  public static var TILE_REGION_ROW = 8;
  public static var TILE_REGION_GROUND = 0;
  public static var TILE_REGION_CITY_LOW = 1;
  public static var TILE_REGION_CITY_MEDIUM = 2;
  public static var TILE_REGION_CITY_HIGH = 3;
  public static var TILE_REGION_MILITARY_BASE = 4;
  public static var TILE_REGION_FACILITY = 5;

  public static var TILE_WALKABLE = [ false, true, false, false, false,
    false ];
  public static var TILE_TYPE = [ 'hidden', 'ground', 'building', 'rock', 'tree', 
    'wall' ];
  public static var TILE_WALKABLE_REGION = [ true, true, true, true, true, true ];
//  public static var TILE_TYPE_REGION = [ 'ground', 'cityLow', 'cityMed', 'cityHigh' ];

  public static var greekLetters = [ 'Alpha', 'Beta', 'Gamma', 'Delta', 'Epsilon',
    'Zeta', 'Eta', 'Theta', 'Iota', 'Kappa', 'Lambda', 'Mu', 'Nu', 'Xi', 'Omicron',
    'Pi', 'Rho', 'Sigma', 'Tau', 'Upsilon', 'Phi', 'Chi', 'Psi', 'Omega' ];

  // player stuff

  // movement directions
  public static var dirx = [ -1, -1, -1, 0, 0, 1, 1, 1 ];
  public static var diry = [ -1, 0, 1, -1, 1, -1, 0, 1 ];

  // common player actions 
  public static var PLAYER_ACTIONS: Map<String, _PlayerAction> =
    [
      // area
      'attachHost' => { id: 'attachHost', type: ACTION_AREA, name: 'Attach To Host', energy: 0 },
      'detach' => { id: 'detach', type: ACTION_AREA, name: 'Detach', energy: 0 },
      'hardenGrip' => { id: 'hardenGrip', type: ACTION_AREA, name: 'Harden Grip', energy: 5 },
      'invadeHost' => { id: 'invadeHost', type: ACTION_AREA, name: 'Invade Host', energy: 10 },
      'reinforceControl' => { id: 'reinforceControl', type: ACTION_AREA, name: 'Reinforce Control', energy: 5 },
      'doNothing' => { id: 'doNothing', type: ACTION_AREA, name: 'Do Nothing', energy: 0 },
      'leaveHost' => { id: 'leaveHost', type: ACTION_AREA, name: 'Leave Host', energy: 0 },
      'probeBrain' => { id: 'probeBrain', type: ACTION_AREA, name: 'Probe Brain', energy: 0 },
      'learnObject' => { id: 'learnObject', type: ACTION_AREA, name: 'Learn About Object', energy: 10 },
      'leaveArea' => { id: 'leaveArea', type: ACTION_AREA, name: 'Leave Area', energy: 0 },
      'move' => { id: 'move', type: ACTION_AREA, name: 'Movement', energy: 0 },

      // region
      'enterArea' => { id: 'enterArea', type: ACTION_REGION, name: 'Enter Area', energy: 0 },
    ];

// get action by id
  public static inline function getAction(id: String): _PlayerAction
    {
      return PLAYER_ACTIONS.get(id);
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
      var list: Array<Dynamic> = [ Inventory, Skills, Organs, Effects ];
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
