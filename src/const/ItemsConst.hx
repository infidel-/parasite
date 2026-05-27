// item list

package const;

import Type;
import game.Game;
import ItemInfo;
import game._Item;
import haxe.ds.StringMap;
import items.*;

class ItemsConst
{
  public static var classes: Array<Class<ItemInfo>> = [
    // special
    Fists,
    Animal,
    ArmorNone,
    // weapons
    Baton,
    BrassKnuckles,
    Knife,
    CurvedKnife,
    BaseballBat,
    Machete,
    Katana,
    Stunner,
    Pistol,
    AssaultRifle,
    CombatShotgun,
    StunRifle,
    // armor
    KevlarArmor,
    FullBodyArmor,
    // misc
    Paper,
    Book,
    MobilePhone,
    Smartphone,
    Laptop,
    Radio,
    Money,
    Wallet,
    Cigarettes,
    Alcohol,
    Narcotics,
    RawSmash,
    Nutrients,
    SleepingPills,
    Contraceptives,
    ShipPart,
    Keycard
  ];

  public static var infos: StringMap<ItemInfo>;

// prepares item info instances; built-ins first, then mod-registered (§8.7)
  public static function init(game: Game)
    {
      infos = new StringMap<ItemInfo>();
      for (cls in classes)
        addInfo(game, cls);
      for (cls in mods.ModContentRegistry.items)
        addInfo(game, cls);
    }

// instantiate item class and register in infos; id collision = last-wins + log
  public static function addInfo(game: Game, cls: Class<ItemInfo>)
    {
      var info: ItemInfo = Type.createInstance(cls, [ game ]);
      if (infos.exists(info.id))
        Const.p('mod content collision on item id: ' + info.id + ' (last-wins)');
      infos.set(info.id, info);
    }

// spawn item by id
  public static function spawnItem(game: Game, id: String): _Item
    {
      var info = getInfo(id);
      if (info == null)
        {
          trace('No such item id: ' + id);
          return null;
        }
      var name = info.name;
      if (info.names != null)
        name = info.names[Std.random(info.names.length)];
      var item: _Item = {
        game: game,
        id: id,
        info: info,
        name: name,
        event: null,
      };
      return item;
    }

// return item info by id
  public static function getInfo(id: String): ItemInfo
    {
      if (infos == null)
        throw 'ItemsConst.init() was not called';
      var info = infos.get(id);
      if (info == null)
        throw 'No such item: ' + id;
      return info;
    }

// return item info by id, or null if missing (used on load when a mod that
// supplied the item is no longer enabled — caller scrubs orphan items)
  public static function tryGetInfo(id: String): ItemInfo
    {
      if (infos == null)
        return null;
      return infos.get(id);
    }
}
