// base class for item metadata

import game.Game;
import game._Item;
import _PlayerAction;

typedef ArmorInfo = {
  var canAttach: Bool;
  var damage: Int;
  var needleDeathChance: Int;
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

// returns extra inventory actions for known items
  public function getInventoryActions(item: _Item): Array<_PlayerAction>
    {
      return [];
    }

// handles inventory action execution for this item
  public function action(actionID: String, action: _PlayerAction): Null<Bool>
    {
      return null;
    }

// logs item failure feedback with sound
  public function itemFailed(msg: String)
    {
      game.log(msg, COLOR_HINT);
      game.scene.sounds.play('item-fail');
    }
}
