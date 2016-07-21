// player/AI inventory

package game;

import const.ItemsConst;
import objects.*;

class Inventory
{
  var game: Game;
  var _list: List<_Item>; // list of items

  public function new(g: Game)
    {
      game = g;
      _list = new List<_Item>();
    }


// add available actions to list
  public function getActions(): List<_PlayerAction>
    {
      var tmp = new List<_PlayerAction>();

      // disable inventory actions in region mode for now
      if (game.location == LOCATION_REGION)
        return tmp;

      for (item in _list)
        {
          // add learning action
          if (!game.player.knowsItem(item.id))
            tmp.add({
              id: 'learn.' + item.id,
              type: ACTION_INVENTORY,
              name: 'Learn about ' + item.info.unknown,
              energy: 10,
              obj: item
              });

          // can do stuff when item is known
          if (game.player.knowsItem(item.id))
            {
              // read a readable
              if (item.info.type == 'readable')
                tmp.add({
                  id: 'read.' + item.id,
                  type: ACTION_INVENTORY,
                  name: 'Read ' + item.name,
                  energy: 10,
                  obj: item
                  });

              // use computer
              else if (item.info.type == 'computer')
                tmp.add({
                  id: 'search.' + item.id,
                  type: ACTION_INVENTORY,
                  name: 'Use ' + item.name + ' to search',
                  energy: 10,
                  obj: item
                  });
            }

          // drop item
          tmp.add({
            id: 'drop.' + item.id,
            type: ACTION_INVENTORY,
            name: 'Drop ' +
              (game.player.knowsItem(item.id) ? item.name : item.info.unknown),
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
          game.log("This requires intense concentration and time. You can only do it in a habitat.", COLOR_HINT);
          return;
        }

      game.log('You study the contents of the ' + item.name + ' and destroy it.');
      var cnt = 0;
      cnt += (game.timeline.learnClue(item.event, true) ? 1 : 0);
      if (item.id == 'book') // 1 more clue in books
        cnt += (game.timeline.learnClue(item.event, true) ? 1 : 0);
      if (Std.random(100) < 30)
        cnt += (game.timeline.learnClue(item.event, true) ? 1 : 0);
      if (Std.random(100) < 10)
        cnt += (game.timeline.learnClue(item.event, true) ? 1 : 0);

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
      game.log('You probe the brain of the host and learn what that item is for.');

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
          game.log("This requires intense concentration and time. You can only do it in a habitat.", COLOR_HINT);
          return false;
        }

      // check if all npcs researched
      var allKnown = true;
      for (e in game.timeline)
        {
          if (e.isHidden)
            continue;

          if (!e.npcSomethingKnown())
            continue;

          if (e.npcFullyKnown())
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
      if (!_Math.skill(skillLevel, SKILL_COMPUTER))
        {
          game.log('You have failed to use the human device properly.');
          return true;
        }

      game.log('You use the ' + item.name + ' to search for known persons data.');

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

            while (cnt > 0 && n.research())
              cnt--;
            if (cnt <= 0)
              return true;
          }

      return true;
    }


// ACTION: drop item
  function dropAction(item: _Item)
    {
      var tmpname = (game.player.knowsItem(item.info.id) ?
        item.name : item.info.unknown);

      var o = new GenericPickup(game, game.playerArea.x, game.playerArea.y,
        Const.FRAME_PICKUP);
      o.name = tmpname;
      o.item = item;
      game.area.addObject(o);
      _list.remove(item);

      game.player.log('You drop the ' + tmpname + '.');
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
  public function addID(id: String)
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
      var item = { id: id, info: info, name: name };
      _list.add(item);
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
      return tmp.join(', ');
    }


// ===============================================================================
}

