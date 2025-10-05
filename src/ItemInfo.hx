// base class for item metadata

import game.Game;
import game._Item;

typedef ArmorInfo = {
  var canAttach: Bool;
  var damage: Int;
  var needleDeathChance: Int;
};

typedef WeaponInfo = {
  @:optional var sound: AISound;
  var isRanged: Bool;
  var skill: _Skill;
  var minDamage: Int;
  var maxDamage: Int;
  var verb1: String;
  var verb2: String;
  var type: _WeaponType;
};

class ItemInfo
{
  public var game: Game;
  public var id: String;
  public var type: String;
  public var isKnown: Bool;
  public var name: String;
  public var names: Array<String>;
  public var unknown: String;
  public var weapon: WeaponInfo;
  public var armor: ArmorInfo;
  public var areaObjectClass: Dynamic;
// constructs item info container with defaults
  public function new(game: Game)
    {
      this.game = game;
      isKnown = false;
      name = null;
      names = null;
      unknown = null;
      weapon = null;
      armor = null;
      areaObjectClass = null;
    }

// hook: handles player learning this item
  public function onLearn(): Void
    {
    }

// hook: updates inventory action list for this item
  public function updateActionList(item: _Item): Void
    {
    }
}
