import game.*;

class Const
{
  public static var FONTS = [ 16, 24, 32, 40 ];
  public static var LAYER_MOUSE = 10; // mouse cursor layer - highest
  public static var LAYER_UI = 9; // ui windows layer
  public static var LAYER_HUD = 8; // ui layer
  public static var LAYER_TILEMAP = 7; // tilemap view layer
  public static var LAYER_DOT = 5; // path doths layer
  public static var LAYER_EFFECT = 4; // visual effects layer
  public static var LAYER_PLAYER = 3; // player, enemies, etc layer
  public static var LAYER_AI = 2; // player, enemies, etc layer
  public static var LAYER_OBJECT = 1; // ground layer - bodies, items
  public static var LAYER_TILES = 0; // tilemap layer

  public static var TILE_SIZE_CLEAN = 64; // file tile size
  public static var TILE_SIZE = TILE_SIZE_CLEAN; // screen tile size

  // text color strings
  public static var TEXT_COLORS: Map<_TextColor, String> =
    [
      COLOR_DEFAULT => '#FFFFFF',
      COLOR_ALERT => '#FC420E',
      COLOR_ORGAN => '#e0e13a',
      COLOR_EVOLUTION => '#73f3ff',
      COLOR_DEBUG => '#a7a7a7',
      COLOR_HINT => '#e36767',
      COLOR_TIMELINE => '#f7af46',
      COLOR_MESSAGE => '#30FF6B',
      COLOR_GOAL => '#92B9FF',
    ];
  // copy-pasted for now
  // TODO: move to TEXT_COLORS
  public static var TEXT_COLORS_INT: Map<_TextColor, Int> =
    [
      COLOR_DEFAULT => 0xFFFFFF,
      COLOR_DEBUG => 0x777777,
      COLOR_ALERT => 0xFF2222,
      COLOR_EVOLUTION => 0x00FFFF,
      COLOR_ORGAN => 0xDDDD00,
      COLOR_HINT => 0xA020F0,
      COLOR_TIMELINE => 0xF03378,
      COLOR_MESSAGE => 0x1CD450,
      COLOR_GOAL => 0x4788FF,
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
  public static var FRAME_CALLING = 7;
  public static var FRAME_SLIME = 8;

  // region row frames
  public static var FRAME_EVENT_UNKNOWN = 1;
  public static var FRAME_EVENT_KNOWN = 2;
  public static var FRAME_EVENT_NPC = 3;
  public static var FRAME_HABITAT = 4;
  public static var FRAME_EVENT_NPC_AREA = 5;
  public static var FRAME_HABITAT_AMBUSHED = 6;

  // object row frames
  public static var FRAME_SEWER_HATCH = 0;
  public static var FRAME_PAPER = 1;
  public static var FRAME_BOOK = 2;
  public static var FRAME_EVENT_OBJECT = 3;
  public static var FRAME_PICKUP = 4;
  public static var FRAME_HUMAN_BODY = 5;
  public static var FRAME_DOG_BODY = 6;
  public static var FRAME_NUTRIENT = 7;

  // effect row frames
  public static var FRAME_PANIC_GAS = 0;
  public static var FRAME_PARALYSIS_GAS = 1;

  // parasite row frames
  public static var FRAME_PARASITE = 0;
  public static var FRAME_DOG = 1;
  public static var FRAME_MASK_CONTROL = 2;
  public static var FRAME_MASK_ATTACHED = 3;
  public static var FRAME_DOT = 4;

  public static var ROW_ALERT = 0;
  public static var ROW_REGION_ICON = 1;
  public static var ROW_OBJECT = 2;
  public static var ROW_EFFECT = 3;
  public static var ROW_PARASITE = 4;

  public static var ROW_BIOMINERAL = 5;
  public static var ROW_ASSIMILATION = 6;
  public static var ROW_WATCHER = 7;

  public static var FRAME_DEFAULT = 0;


  // tiles spritemap indexes
  // row 0
  public static var TILE_HIDDEN = 0;
  public static var TILE_GROUND = 1;
  public static var TILE_BUILDING = 2;
  public static var TILE_ROCK = 3;
  public static var TILE_WALL = 4;
  public static var TILE_TREE1 = 5;
  public static var TILE_BUSH = 9;
  public static var TILE_GRASS = 10;

  // row 1
  public static var OFFSET_REGION = 16;
  public static var TILE_REGION_GROUND = OFFSET_REGION + 0;
  public static var TILE_CITY_LOW = OFFSET_REGION + 1;
  public static var TILE_CITY_MEDIUM = OFFSET_REGION + 2;
  public static var TILE_CITY_HIGH = OFFSET_REGION + 3;
  public static var TILE_FACILITY1 = OFFSET_REGION + 4;
  public static var TILE_MILITARY_BASE1 = OFFSET_REGION + 8;

  // row 2
  public static var OFFSET_AREA = 32;
  public static var TILE_ROAD = OFFSET_AREA + 0;
  public static var TILE_ALLEY = OFFSET_AREA + 1;
  public static var TILE_WALKWAY = OFFSET_AREA + 2;
  public static var TILE_WINDOW1 = OFFSET_AREA + 3;
  public static var TILE_WINDOWH1 = OFFSET_AREA + 4;
  public static var TILE_WINDOWH2 = OFFSET_AREA + 5;
  public static var TILE_WINDOWH3 = OFFSET_AREA + 6;
  public static var TILE_WINDOWV1 = OFFSET_AREA + 7;
  public static var TILE_WINDOWV2 = OFFSET_AREA + 8;
  public static var TILE_WINDOWV3 = OFFSET_AREA + 9;
  public static var TILE_DOOR_CABINET = OFFSET_AREA + 10;
  public static var TILE_DOOR_CABINET_OPEN = OFFSET_AREA + 11;
  public static var TILE_DOOR_DOUBLE = OFFSET_AREA + 12;
  public static var TILE_DOOR_DOUBLE_OPEN = OFFSET_AREA + 13;
  public static var TILE_DOOR_GLASS = OFFSET_AREA + 14;
  public static var TILE_DOOR_GLASS_OPEN = OFFSET_AREA + 15;

  // row 3
  public static var OFFSET_ROW3 = 48;
  public static var TILE_FLOOR_TILE = OFFSET_ROW3 + 0;
  public static var TILE_FLOOR_LINO = OFFSET_ROW3 + 1;

  public static var OFFSET_CITY = 64;

  public static var TILE_CITY_WALKABLE = [ true ];

  public static var TILE_WALKABLE = [
    // row 0
    false, true, false, true, false, false, false, false,
    false, true, true, true, false, false, false, false,
    // row 1 - region
    true, true, true, true, true, true, true, true,
    true, true, true, true, true, true, true, true,
    // row 2 - roads, indoor
    true, true, true, false, false, false, false, false,
    false, false, false, true, false, true, false, true,
    // row 3 - floor
    true, true, true, true,
    true, true, true, true,
    true, true, true, true,
    true, true, true, true,

    // row 4+ - region tiles
    true, true, true, true,
    true, true, true, true,
    true, true, true, true,
    true, true, true, true,

    true, true, true, true,
    true, true, true, true,
    true, true, true, true,
    true, true, true, true,

    true, true, true, true,
    true, true, true, true,
    true, true, true, true,
    true, true, true, true,

    true, true, true, true,
    true, true, true, true,
    true, true, true, true,
    true, true, true, true,
  ];
  public static var TILE_SEETHROUGH = [
    // row 0
    false, true, false, true, false, false, false, false,
    false, true, true, true, false, false, false, false,
    // row 1 - region
    true, true, true, true, true, true, true, true,
    true, true, true, true, true, true, true, true,
    // row 2 - roads, indoor
    true, true, true, true, true, true, true, true,
    true, true, true, true, true, true, true, true,
    // row 3 - floor
    true, true, true, true,
    true, true, true, true,
    true, true, true, true,
    true, true, true, true,

    // row 4+ - region tiles
    true, true, true, true,
    true, true, true, true,
    true, true, true, true,
    true, true, true, true,

    true, true, true, true,
    true, true, true, true,
    true, true, true, true,
    true, true, true, true,

    true, true, true, true,
    true, true, true, true,
    true, true, true, true,
    true, true, true, true,

    true, true, true, true,
    true, true, true, true,
    true, true, true, true,
    true, true, true, true,
  ];
  public static var TILE_TYPE = [ 'hidden', 'ground', 'building', 'rock',
    'wall', 'tree', 'tree', 'tree', 'tree', 'grass' ];
//  public static var TILE_WALKABLE_REGION = [ true, true, true, true, true, true ];
//  public static var TILE_TYPE_REGION = [ 'ground', 'cityLow', 'cityMed', 'cityHigh' ];

  // player stuff

  // movement directions
  public static var dirx = [ -1, -1, -1, 0, 0, 1, 1, 1 ];
  public static var diry = [ -1, 0, 1, -1, 1, -1, 0, 1 ];
  public static var dir4x = [ -1, 0, 0, 1 ];
  public static var dir4y = [ 0, -1, 1, 0 ];


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
      var classes: Array<String> = [ 'String' ];
      var fields = Reflect.fields(o);
      fields.sort(sortFunc);
      for (f in fields)
        {
          var ff = Reflect.field(o, f);
          var cl = Type.getClass(ff);
          if (cl == null)
            continue;
          var className = Type.getClassName(cl);
          if ((ff + '').indexOf('function') == 0)
            continue;

          // library classes and anonymous objects
          if (!Reflect.isFunction(ff) &&
              (!Reflect.isObject(ff) ||
               className == null || Lambda.has(classes, className)))
            Const.p(f + ': ' + ff);

          // lists
          else if (className == 'List')
            {
              var l: List<Dynamic> = cast ff;
              var tmp = [];
              for (x in l)
                tmp.push(x);

              Const.p(f + ': ' + tmp.join(', '));
            }

          // ingame classes
          else if (Lambda.has(list, Type.getClass(ff)))
            Const.p(f + ': ' + ff);
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


// round to 1 decimal
  public static inline function round(x: Float): Float
    {
      return Math.round(x * 10) / 10;
    }


// calc distance squared
  public static inline function distanceSquared(x1: Int, y1: Int, x2: Int, y2: Int)
    {
      return (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1);
    }


// print stuff
  public static inline function p(s: Dynamic)
    {
#if js
      js.Browser.console.log(s);
#else
      Sys.println(s);
#end
    }

  public static inline function key(s: String)
    {
      return '<span style="font-weight:bold; color:var(--text-color-gray)">' + s + '</span>';
    }

  public static inline function bold(s: String)
    {
      return '<span style="font-weight:bold">' + s + '</span>';
    }

  public static inline function small(s: String)
    {
      return '<span class=small>' + s + '</span>';
    }

  public static inline function smallgray(s: String)
    {
      return '<span style="color:var(--text-color-gray)" class=small>' + s + '</span>';
    }

  public static inline function narrative(s: String)
    {
      return '<span class=narrative>' + s + '</span>';
    }

// return the string wrapped into color marker
  public static inline function col(col: String, s: String)
    {
      return "<span style='color:var(--text-color-" + col + ")'>" +
        s + '</span>';
    }

// trace call stack for debug
  public static inline function traceStack()
    {
      trace(haxe.CallStack.toString(haxe.CallStack.callStack()));
    }


// capitalize string
  public static inline function capitalize(s: String): String
    {
      return s.substr(0, 1).toUpperCase() + s.substr(1);
    }
}
