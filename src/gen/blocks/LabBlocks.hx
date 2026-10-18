// the underground lab's node kinds and its room roles
//
// the lab is the corp's shape and not the compound's: one plate cut out of bedrock with its rooms
// carved off a corridor, so nothing at the area level is split and what the tree records is the
// plate, the lift, the corridor, its doorways and the rooms. gen.lab.LabPlan lays all of it in the
// plate's own fill; the room level is gen.lab.LabZones. See docs/area-gen.md.

package gen.blocks;

class LabBlocks
{
  // the area level: the plate, and what it carves
  public static inline var PLATE = 'plate';
  public static inline var LIFT = 'lift';
  public static inline var CORRIDOR = 'corridor';
  public static inline var DOOR = 'door';

  // the room roles, verbatim in _Room.role, and the room kinds they build
  public static inline var ROLE_ENTRANCE = 'entrance';
  public static inline var ROLE_VAT = 'vat';
  public static inline var ROLE_WORKSHOP = 'workshop';
  public static inline var ROLE_STORAGE = 'storage';
  public static inline var ROLE_RESEARCH = 'research';
  public static inline var ENTRANCE = 'room-entrance';
  public static inline var VAT = 'room-vat';
  public static inline var WORKSHOP = 'room-workshop';
  public static inline var STORAGE = 'room-storage';
  public static inline var RESEARCH = 'room-research';

  // the three service rooms, one of each on every level
  public static var SERVICE = [ ROLE_WORKSHOP, ROLE_STORAGE, ROLE_RESEARCH ];

// the room kind a role builds
  public static function kindOf(role: String): String
    {
      return 'room-' + role;
    }

// is this one of the lab's room kinds?
  public static function isRoom(kind: String): Bool
    {
      return kind == ENTRANCE ||
        kind == VAT ||
        kind == WORKSHOP ||
        kind == STORAGE ||
        kind == RESEARCH;
    }

// the floor a room of this role is laid in
  public static function floorOf(role: String): Int
    {
      return switch (role)
        {
          case ROLE_ENTRANCE: Const.TILE_LAB_FLOOR_ENTRANCE;
          case ROLE_VAT: Const.TILE_LAB_FLOOR_VAT;
          case ROLE_WORKSHOP: Const.TILE_LAB_FLOOR_WORKSHOP;
          case ROLE_STORAGE: Const.TILE_LAB_FLOOR_STORAGE;
          default: Const.TILE_LAB_FLOOR_RESEARCH;
        };
    }
}
