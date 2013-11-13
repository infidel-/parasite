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

  // entity spritemap indexes
  public static var FRAME_EMPTY = 0;


  public static var ROW_ALERT = 0;
  public static var FRAME_ALERT1 = 1;
  public static var FRAME_ALERT2 = 2;
  public static var FRAME_ALERT3 = 3;
  public static var FRAME_ALERTED = 4;

  public static var ROW_PARASITE = 1;
  public static var ROW_HUMAN = 2;
  public static var ROW_DOG = 3;
  public static var FRAME_DEFAULT = 0;
  public static var FRAME_MASK_POSSESSED = 1;
  public static var FRAME_BODY = 2;


  // tiles spritemap indexes
  public static var TILE_HIDDEN = 0;
  public static var TILE_GROUND = 1;
  public static var TILE_BUILDING = 2;
  public static var TILE_WALKABLE = [ false, true, false ];
  public static var TILE_TYPE = [ 'hidden', 'ground', 'building' ];

  // AI view distance
  // TODO: i could probably move these into AI class to change by different AIs
  public static var AI_VIEW_DISTANCE = 10;

  // number of turns AI stays alerted
  public static var AI_ALERTED_TIMER = 10;

  // player stuff

  // movement directions
  public static var dirx = [ -1, -1, -1, 0, 0, 1, 1, 1 ];
  public static var diry = [ -1, 0, 1, -1, 1, -1, 0, 1 ];

  // player actions and intents names
  public static var PLAYER_ACTIONS =
    {
      attachHost: { id: 'attachHost', name: 'Attach To Host', energy: 0 },
      detach: { id: 'detach', name: 'Detach', energy: 0 },
      hardenGrip: { id: 'hardenGrip', name: 'Harden Grip', energy: 5 },
      invadeHost: { id: 'invadeHost', name: 'Invade Host', energy: 10 },
      reinforceControl: { id: 'reinforceControl', name: 'Reinforce Control', energy: 5 },
      doNothing: { id: 'doNothing', name: 'Do Nothing', energy: 0 },
      leaveHost: { id: 'leaveHost', name: 'Leave Host', energy: 0 },
      accessMemory: { id: 'accessMemory', name: 'Access Memory', energy: 5 },
      move: { id: 'move', name: 'Movement', energy: 0 },
//      { id: '', name: '', ap:  },
    };


// get action by id
  public static inline function getAction(id: String): PlayerAction
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
      for (f in Reflect.fields(o))
        {
          var ff = Reflect.field(o, f);
          if (!Reflect.isFunction(ff) && 
              (!Reflect.isObject(ff) || Type.getClass(ff) == String))
            trace(f + ': ' + ff);
        }
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
}
