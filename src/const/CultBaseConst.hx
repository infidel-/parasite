// cult base organ metadata and helper rules
package const;

import _CultBaseOrganType;
import cult.base.CultBaseResources;

typedef CultBaseOrganInfo = {
  var type: _CultBaseOrganType;
  var name: String;
  var cost: CultBaseResources;
  var w: Int;
  var h: Int;
  var maxLevel: Int;
  var isDefense: Bool;
  var isGrowth: Bool;
}

class CultBaseConst
{
  public static inline var IMAGE_NAME = 'cultBase';
  public static inline var IMAGE_PATH = 'img/cult-base.png';
  public static inline var IMAGE_COLS = 8;
  public static inline var IMAGE_ROWS = 6;

  public static var BLOCK_COR_NEFANDUM: _IconBlock =
    { row: 0, col: 0, width: 2, height: 2 };
  public static var BLOCK_RIBWALL: _IconBlock =
    { row: 0, col: 2, width: 1, height: 1 };
  public static var BLOCK_RIBGATE: _IconBlock =
    { row: 0, col: 3, width: 1, height: 1 };
  public static var BLOCK_SPINE_TURRET: _IconBlock =
    { row: 0, col: 4, width: 1, height: 1 };
  public static var BLOCK_BLOOD_TRAP: _IconBlock =
    { row: 0, col: 5, width: 1, height: 1 };
  public static var BLOCK_FLESH_BLOCK: _IconBlock =
    { row: 0, col: 6, width: 2, height: 2 };
  public static var BLOCK_RAT_NEST: _IconBlock =
    { row: 2, col: 0, width: 2, height: 2 };
  public static var BLOCK_CRUSHER: _IconBlock =
    { row: 2, col: 2, width: 2, height: 2 };
  public static var BLOCK_GARBAGE_HEAP: _IconBlock =
    { row: 2, col: 4, width: 2, height: 2 };
  public static var BLOCK_BODY_STORAGE: _IconBlock =
    { row: 2, col: 6, width: 2, height: 2 };
  public static var BLOCK_CAULDRON: _IconBlock =
    { row: 4, col: 0, width: 2, height: 2 };

  public static var buildableTypes: Array<_CultBaseOrganType> = [
    RIBWALL,
    RIBGATE,
    SPINE_TURRET,
    BLOOD_TRAP,
    FLESH_BLOCK,
    RAT_NEST,
    CRUSHER,
    GARBAGE_HEAP,
    BODY_STORAGE,
    CAULDRON,
  ];

// returns metadata for one organ type
  public static function info(type: _CultBaseOrganType): CultBaseOrganInfo
    {
      switch (type)
        {
          case COR_NEFANDUM:
            return meta(type, 'Cor Nefandum', 0, 0, 0, 2, 2, 4, false, false);
          case RIBWALL:
            return meta(type, 'Murus Costarum', 0, 0, 3, 1, 1, 1, true, false);
          case RIBGATE:
            return meta(type, 'Porta Costarum', 4, 4, 6, 1, 1, 1, true, false);
          case SPINE_TURRET:
            return meta(type, 'Turris Spinarum', 6, 2, 10, 1, 1, 1, true, false);
          case BLOOD_TRAP:
            return meta(type, 'Tardans', 2, 6, 0, 1, 1, 1, true, false);
          case FLESH_BLOCK:
            return meta(type, 'Quadrum', 20, 5, 10, 2, 2, 3, false, true);
          case RAT_NEST:
            return meta(type, 'Nidus Murium', 8, 2, 4, 2, 2, 3, false, true);
          case CRUSHER:
            return meta(type, 'Fractor', 10, 4, 12, 2, 2, 3, false, true);
          case GARBAGE_HEAP:
            return meta(type, 'Cumulus', 12, 3, 4, 2, 2, 3, false, true);
          case BODY_STORAGE:
            return meta(type, 'Cadaverum', 8, 0, 6, 2, 2, 3, false, false);
          case CAULDRON:
            return meta(type, 'Caldarium', 18, 10, 10, 2, 2, 3, false, false);
        }
    }

// returns display name for one organ type
  public static function name(type: _CultBaseOrganType): String
    {
      return info(type).name;
    }

// returns cult base atlas block for one organ type
  public static function block(type: _CultBaseOrganType): _IconBlock
    {
      switch (type)
        {
          case COR_NEFANDUM:
            return BLOCK_COR_NEFANDUM;
          case RIBWALL:
            return BLOCK_RIBWALL;
          case RIBGATE:
            return BLOCK_RIBGATE;
          case SPINE_TURRET:
            return BLOCK_SPINE_TURRET;
          case BLOOD_TRAP:
            return BLOCK_BLOOD_TRAP;
          case FLESH_BLOCK:
            return BLOCK_FLESH_BLOCK;
          case RAT_NEST:
            return BLOCK_RAT_NEST;
          case CRUSHER:
            return BLOCK_CRUSHER;
          case GARBAGE_HEAP:
            return BLOCK_GARBAGE_HEAP;
          case BODY_STORAGE:
            return BLOCK_BODY_STORAGE;
          case CAULDRON:
            return BLOCK_CAULDRON;
        }
    }

// returns top-left cult base atlas icon for one organ type
  public static function icon(type: _CultBaseOrganType): _Icon
    {
      var b = block(type);
      return { row: b.row, col: b.col };
    }

// returns max health for level/type
  public static function maxHealth(type: _CultBaseOrganType, level: Int): Int
    {
      switch (type)
        {
          case COR_NEFANDUM:
            return 60 + 20 * (level - 1);
          case RIBWALL:
            return 18;
          case RIBGATE:
            return 24;
          case SPINE_TURRET:
            return 18;
          case BLOOD_TRAP:
            return 10;
          case FLESH_BLOCK:
            return 28 + 8 * (level - 1);
          case RAT_NEST:
            return 10 + 4 * (level - 1);
          case CRUSHER:
            return 24 + 8 * (level - 1);
          case GARBAGE_HEAP:
            return 18 + 6 * (level - 1);
          case BODY_STORAGE:
            return 20 + 6 * (level - 1);
          case CAULDRON:
            return 24 + 8 * (level - 1);
        }
    }

// returns build cost for one organ type
  public static function buildCost(type: _CultBaseOrganType): CultBaseResources
    {
      return info(type).cost.clone();
    }

// returns upgrade cost from current level to next level
  public static function upgradeCost(type: _CultBaseOrganType,
      level: Int): CultBaseResources
    {
      if (type == COR_NEFANDUM)
        {
          switch (level)
            {
              case 1:
                return new CultBaseResources(40, 30, 30);
              case 2:
                return new CultBaseResources(60, 45, 45);
              case 3:
                return new CultBaseResources(80, 60, 60);
              default:
                return new CultBaseResources();
            }
        }
      var cost = buildCost(type);
      if (level >= 2)
        {
          cost.flesh *= 2;
          cost.blood *= 2;
          cost.bone *= 2;
        }
      return cost;
    }

// returns repair cost rounded up to 25 percent of base cost
  public static function repairCost(type: _CultBaseOrganType): CultBaseResources
    {
      var cost = buildCost(type);
      cost.flesh = quarter(cost.flesh);
      cost.blood = quarter(cost.blood);
      cost.bone = quarter(cost.bone);
      return cost;
    }

// returns footprint tiles for one placed organ
  public static function footprint(type: _CultBaseOrganType,
      x: Int, y: Int): Array<{ x: Int, y: Int }>
    {
      var ret = [];
      var data = info(type);
      for (dy in 0...data.h)
        for (dx in 0...data.w)
          ret.push({ x: x + dx, y: y + dy });
      return ret;
    }

// returns true for organs that can chain beside ribwalls
  public static function isRib(type: _CultBaseOrganType): Bool
    {
      return type == RIBWALL || type == RIBGATE;
    }

// creates metadata object
  static function meta(type: _CultBaseOrganType, name: String,
      flesh: Int, blood: Int, bone: Int, w: Int, h: Int,
      maxLevel: Int, isDefense: Bool, isGrowth: Bool): CultBaseOrganInfo
    {
      return {
        type: type,
        name: name,
        cost: new CultBaseResources(flesh, blood, bone),
        w: w,
        h: h,
        maxLevel: maxLevel,
        isDefense: isDefense,
        isGrowth: isGrowth
      };
    }

// returns ceil(value / 4)
  static function quarter(value: Int): Int
    {
      if (value <= 0)
        return 0;
      return Std.int(Math.ceil(value / 4.0));
    }
}
