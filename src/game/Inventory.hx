// player/AI inventory

package game;

import const.ItemsConst;
import objects.*;

class Inventory extends _SaveObject
{
  var game: Game;
  var _list: List<_Item>; // list of items

  // item slots
  public var clothing(default, null): _Item;

  public function new(g: Game)
    {
      game = g;
      init();
      initPost(false);
    }

// init object before loading/post creation
  public function init()
    {
      _list = new List();
      var info = ItemsConst.armorNone;
      clothing = {
        id: info.id,
        info: info,
        name: info.name,
        event: null,
      };
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {
    }


// add available actions to list
  public function getActions(): Array<_PlayerAction>
    {
      // disable inventory actions in region mode for now
      var tmp = [];
      if (game.location == LOCATION_REGION)
        return tmp;

      for (item in _list)
        {
          var itemName =
            (game.player.knowsItem(item.id) ? item.name : item.info.unknown);
          // add learning action
          if (!game.player.knowsItem(item.id))
            tmp.push({
              id: 'learn.' + item.id,
              type: ACTION_INVENTORY,
              name: 'Learn about ' + Const.col('inventory-item', itemName),
              energy: 10,
              obj: item
            });

          // can do stuff when item is known
          if (game.player.knowsItem(item.id))
            {
              // read a readable
              if (item.info.type == 'readable')
                tmp.push({
                  id: 'read.' + item.id,
                  type: ACTION_INVENTORY,
                  name: 'Read ' + Const.col('inventory-item', itemName),
                  energy: 10,
                  obj: item
                });

              // use computer
              else if (item.info.type == 'computer' &&
                  game.player.vars.searchEnabled)
                tmp.push({
                  id: 'search.' + item.id,
                  type: ACTION_INVENTORY,
                  name: 'Use ' +
                    Const.col('inventory-item', itemName) + ' to search',
                  energy: 10,
                  obj: item
                });
            }

          // drop item
          tmp.push({
            id: 'drop.' + item.id,
            type: ACTION_INVENTORY,
            name: 'Drop ' + Const.col('inventory-item', itemName),
            energy: 0,
            obj: item
          });
        }
      return tmp;
    }


// ACTION: player inventory action
  public function action(action: _PlayerAction)
    {
      var item: _Item = untyped action.obj;
      var actionID = action.id.substr(0, action.id.indexOf('.'));
      var ret = true;

      // learn about item
      if (actionID == 'learn')
        learnAction(item);

      // read item
      else if (actionID == 'read')
        readAction(item);

      // search for npc with item
      else if (actionID == 'search')
        ret = searchAction(item);

      // drop item
      else if (actionID == 'drop')
        dropAction(item);

      // if action was completed, end turn, etc
      if (ret)
        {
          // spend energy
          game.player.host.energy -= action.energy;

          // end turn, etc
          if (game.location == LOCATION_AREA)
            game.playerArea.postAction();

          else Const.todo('Inventory.action() in region mode!');
        }
    }


// ACTION: read item
  function readAction(item: _Item)
    {
      // can only read books in habitat
      if (item.id == 'book' && !game.area.isHabitat)
        {
          if (game.player.evolutionManager.getLevel(IMP_MICROHABITAT) > 0)
            game.log("This action requires intense concentration and time. You can only do it in a habitat.", COLOR_HINT);
          else game.log("This action requires intense concentration and time. You cannot do it yet.", COLOR_HINT);
          return;
        }

      game.log('You study the contents of the ' + item.name + ' and destroy it.');
      var cnt = 0;
      cnt += (game.timeline.learnClues(item.event, true) ? 1 : 0);
      if (item.id == 'book') // 1 more clue try in books
        cnt += (game.timeline.learnClues(item.event, true) ? 1 : 0);
      if (Std.random(100) < 30)
        cnt += (game.timeline.learnSingleClue(item.event, true) ? 1 : 0);
      if (Std.random(100) < 10)
        cnt += (game.timeline.learnSingleClue(item.event, true) ? 1 : 0);

      // no clues learned
      if (cnt == 0)
        game.player.log('You have not been able to gain any clues.',
          COLOR_TIMELINE);

      // destroy item
      _list.remove(item);
    }


// ACTION: learn about item
  function learnAction(item: _Item)
    {
      game.log('You probe the brain of the host and learn that this item is a ' +
        item.name + '.');

      game.player.addKnownItem(item.id);

      // on first learn items
      game.goals.complete(GOAL_LEARN_ITEMS);
    }


// ACTION: search for npc information
  function searchAction(item: _Item): Bool
    {
      // player does not have computer skill
      var skillLevel = game.player.skills.getLevel(SKILL_COMPUTER);
      if (skillLevel == 0)
        {
          game.log('You require the computer use skill to do that.', COLOR_HINT);
          return false;
        }

      // can only do that in habitat
      if (!game.area.isHabitat)
        {
          if (game.player.evolutionManager.getLevel(IMP_MICROHABITAT) > 0)
            game.log("This action requires intense concentration and time. You can only do it in a habitat.", COLOR_HINT);
          else game.log("This action requires intense concentration and time. You cannot do it yet.", COLOR_HINT);
          return false;
        }

      // check if all npcs researched
      var allKnown = true;
      for (e in game.timeline)
        {
          if (e.isHidden)
            continue;

          if (!e.npcCanResearch())
            continue;

          allKnown = false;
          break;
        }

      if (allKnown)
        {
          game.log('You have already researched all known persons.', COLOR_HINT);
          return false;
        }

      // roll for skill
      var mods = [];
      if (item.info.name == 'laptop')
        mods.push({ name: 'laptop', val: 10.0 });
      var ret = __Math.skill({
        id: SKILL_COMPUTER,
        level: skillLevel,
        mods: mods
        });
      if (!ret)
        {
          game.log('You have failed to use the human device properly. You still gain some insight.');
          game.player.skills.increase(SKILL_COMPUTER, 1);
          return true;
        }

      game.log('You use the ' + item.name + ' to search for known persons data.');
      if (skillLevel < 99)
        game.player.skills.increase(SKILL_COMPUTER, 2);

      var cnt = 1;
      if (item.info.name == 'smartphone')
        cnt = 1;
      else if (item.info.name == 'laptop')
        cnt = 3;

      // goal completed - use computer
      game.goals.complete(GOAL_USE_COMPUTER);

      // find first event that has some half-known npcs
      for (e in game.timeline)
        for (n in e.npc)
          {
            if (!n.nameKnown && !n.jobKnown)
              continue;

            if (n.fullyKnown())
              continue;

            // easy difficulty - cnt acts as number npcs to fully research
            if (game.timeline.difficulty == EASY)
              {
                n.researchFull();
                cnt--;
                if (cnt <= 0)
                  return true;
              }
            else
              {
                // normal, hard difficulty - cnt acts as research tries count
                while (cnt > 0 && n.research())
                  cnt--;
                if (cnt <= 0)
                  return true;
              }
          }

      return true;
    }


// ACTION: drop item
  function dropAction(item: _Item)
    {
      var itemName = (game.player.knowsItem(item.info.id) ?
        item.name : item.info.unknown);

      var o = new GenericPickup(game, game.area.id,
        game.playerArea.x, game.playerArea.y,
        Const.FRAME_PICKUP);
      o.name = itemName;
      o.item = item;
      game.area.addObject(o);
      _list.remove(item);
      o.entity.setPosition(o.x, o.y);

      game.player.log('You drop the ' + Const.col('inventory-item', itemName) + '.');
    }


// list iterator
  public function iterator(): Iterator<_Item>
    {
      return _list.iterator();
    }


// clear list
  public inline function clear()
    {
      _list.clear();
    }


// checks whether this inventory contains this item ID
  public function has(id: String): Bool
    {
      for (item in _list)
        if (item.id == id)
          return true;

      return false;
    }


// remove item
  public function remove(id: String)
    {
      for (item in _list)
        if (item.id == id)
          {
            _list.remove(item);
            break;
          }
    }


// get first item that is a weapon
  public function getFirstWeapon(): _Item
    {
      for (item in _list)
        if (item.info.weapon != null)
          return item;

      return null;
    }


// add item by id
  public function addID(id: String, ?wear: Bool = false)
    {
      var info = ItemsConst.getInfo(id);
      if (info == null)
        {
          trace('No such item id: ' + id);
          return;
        }

      var name = info.name;
      if (info.names != null) // pick a name
        name = info.names[Std.random(info.names.length)];
      var item: _Item = {
        id: id,
        info: info,
        name: name,
        event: null,
      };

      // wear/wield item automatically
      if (wear)
        {
          if (info.type == 'clothing')
            clothing = item;
        }
      else _list.add(item);
    }


// add item
  public inline function add(item: _Item)
    {
      _list.add(item);
    }


  public function toString(): String
    {
      var tmp = [];
      for (o in _list)
        tmp.push(o.id);
      if (clothing.id != 'armorNone')
        tmp.push('clothing: ' + clothing.id);
      return tmp.join(', ');
    }


// ===============================================================================
}

