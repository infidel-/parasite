// player/AI inventory

package game;

import const.ItemsConst;
import objects.*;

class Inventory extends _SaveObject
{
  var game: Game;
  var _list: List<_Item>; // list of items
  public var weaponID: String; // currently active weapon

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
        game: game,
        id: info.id,
        info: info,
        name: info.name,
        event: null,
      };
      weaponID = null;
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {
    }

// add available actions to list (body window)
  public function getActions(): Array<_PlayerAction>
    {
      // disable inventory actions in region mode for now
      var tmp = [];
      if (game.location == LOCATION_REGION)
        return tmp;

      for (item in _list)
        {
          var itemName = item.getName();
          // add learning action
          if (!game.player.knowsItem(item.id))
            tmp.push({
              id: 'learn.' + item.id,
              type: ACTION_INVENTORY,
              name: 'Learn about ' + Const.col('inventory-item', itemName),
              energy: 10,
              isAgreeable: true,
              item: item
            });

          // can do stuff when item is known
          else
            {
              // read a readable
              if (item.info.type == 'readable')
                tmp.push({
                  id: 'read.' + item.id,
                  type: ACTION_INVENTORY,
                  name: 'Read ' + Const.col('inventory-item', itemName),
                  energy: 10,
                  isAgreeable: true,
                  item: item
                });

              // use computer
              else if (item.info.type == 'computer')
                {
                  if (game.player.evolutionManager.getLevel(IMP_ENGRAM) >= 1 &&
                      !game.player.vars.mapAbsorbed)
                    tmp.push({
                      id: 'absorbMap.' + item.id,
                      type: ACTION_INVENTORY,
                      name: 'Absorb regional map',
                      energy: 15,
                      item: item
                    });
                  if (game.player.vars.searchEnabled)
                    tmp.push({
                      id: 'search.' + item.id,
                      type: ACTION_INVENTORY,
                      name: 'Use ' +
                        Const.col('inventory-item', itemName) + ' to search',
                      energy: 10,
                      item: item
                    });
                }

              // eat nutrients
              else if (item.info.type == 'nutrients')
                tmp.push({
                  id: 'use.' + item.id,
                  type: ACTION_INVENTORY,
                  name: 'Consume ' + Const.col('inventory-item', itemName),
                  energy: 0,
                  item: item
                });

              // weapons can be marked as active
              else if (item.info.type == 'weapon')
                tmp.push({
                  id: 'active.' + item.id,
                  type: ACTION_INVENTORY,
                  name: 'Mark ' + Const.col('inventory-item', itemName) + ' as active',
                  energy: 0,
                  item: item
                });
            }

          // drop item
          tmp.push({
            id: 'drop.' + item.id,
            type: ACTION_INVENTORY,
            name: 'Drop ' + Const.col('inventory-item', itemName),
            energy: 0,
            item: item
          });
        }
      return tmp;
    }

// update actions list (hud)
  public function updateActionList()
    {
      for (item in _list)
        if (item.info.updateActionList != null)
          item.info.updateActionList(game, item);
    }

// ACTION: player inventory action
  public function action(action: _PlayerAction)
    {
      var actionID = action.id.substr(0, action.id.indexOf('.'));
      var ret = true;
      switch (actionID)
        {
          // read item
          case 'read':
            readAction(action.item);
          // generic use item
          case 'use':
            ret = useAction(action.item);
          // search for npc with item
          case 'search':
            ret = searchAction(action.item);
          // drop item
          case 'drop':
            dropAction(action.item);
          // learn about item
          case 'learn':
            learnAction(action.item);
          // throw money
          case 'throwMoney':
            throwMoneyAction(action.item);
          // absorb regional map
          case 'absorbMap':
            absorbMapAction(action.item);
          // mark as active
          case 'active':
            activeAction(action.item);
          default:
            Const.todo('no such action: ' + actionID);
        }

      // if action was completed, end turn, etc
      if (ret)
        {
          // spend energy
          game.player.actionEnergy(action);
          // end turn, etc
          if (game.location == LOCATION_AREA)
            game.playerArea.actionPost();

          else Const.todo('Inventory.action() in region mode!');
        }
    }

// ACTION: throw money
  function throwMoneyAction(item: _Item)
    {
      var range = 3;
      var time = 3;
      var tmp = game.area.getAIinRadius(
        game.playerArea.x, game.playerArea.y,
        range, false);

      game.log('Your host throws money around.');
      game.scene.sounds.play('item-money');
      removeItem(item);

      // spawn visual effects
      var xo = game.playerArea.x;
      var yo = game.playerArea.y;
      for (yy in yo - range...yo + range)
        for (xx in xo - range...xo + range)
          {
            if (!game.area.isWalkable(xx, yy))
              continue;

            if (Const.distanceSquared(xo, yo, xx, yy) >
                range * range)
              continue;

            new particles.ParticleMoney(game.scene,
              { x: xx, y: yy });
          }

      // affect all AI in range
      for (ai in tmp)
        {
          // do not affect self and dogs
          if (ai == game.player.host ||
              !ai.isHuman)
            continue;

          // set alertness
          if (ai.state == AI_STATE_IDLE)
            {
              ai.alertness = 100;
              ai.setState(AI_STATE_ALERT, REASON_PARASITE);
            }

          // AI effect event
          ai.onEffect({
            type: EFFECT_PARALYSIS,
            points: time,
            isTimer: true
          });
        }
      // repaint view with effects
      game.scene.updateCamera();

      return true;
    }

// ACTION: mark weapon as active
  function activeAction(item: _Item)
    {
      game.log('You will now attack with ' + item.name + '.');
      weaponID = item.id;
    }

// ACTION: generic use item
  function useAction(item: _Item): Bool
    {
      if (item.info.type == 'nutrients')
        {
          game.log('Your host gnaws the delicious nutrients recovering health and energy.');
          game.scene.sounds.play('item-nutrients');
          game.player.host.health += 10;
          game.player.host.energy += 50;
        }
      return true;
    }

// ACTION: read item
  function readAction(item: _Item)
    {
      // can only read books in habitat
      if (item.id == 'book' && !game.area.isHabitat)
        {
          if (game.player.evolutionManager.getLevel(IMP_MICROHABITAT) > 0)
            itemFailed("This action requires intense concentration and time. You can only do it in a habitat.");
          else itemFailed("This action requires intense concentration and time. You cannot do it yet.");
          game.profile.addPediaArticle('msgConcentration');
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
      game.scene.sounds.play('item-' + item.id);

      // destroy item
      _list.remove(item);
    }


// ACTION: learn about item
  function learnAction(item: _Item)
    {
      game.log('You probe the brain of the host and learn that this item is a ' +
        Const.col('inventory-item', item.name) + '.');
      game.player.addKnownItem(item.id);
      if (item.info.onLearn != null)
        item.info.onLearn(game, game.player);

      // on first learn items
      game.goals.complete(GOAL_LEARN_ITEMS);

      // goal completion
      if (item.info.type == 'phone' ||
          item.id == 'smartphone' ||
          item.info.type == 'radio')
        game.goals.complete(GOAL_TUTORIAL_COMMS);
    }


// ACTION: search for npc information
  function searchAction(item: _Item): Bool
    {
      // player does not have computer skill
      var skillLevel = game.player.skills.getLevel(SKILL_COMPUTER);
      if (skillLevel == 0)
        {
          itemFailed('You require the computer use skill to do that.');
          return false;
        }

      // can only do that in habitat
      if (!game.area.isHabitat)
        {
          if (game.player.evolutionManager.getLevel(IMP_MICROHABITAT) > 0)
            itemFailed("This action requires intense concentration and time. You can only do it in a habitat.");
          else itemFailed("This action requires intense concentration and time. You cannot do it yet.");
          game.profile.addPediaArticle('msgConcentration');
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
          itemFailed('You have already researched all known persons.');
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
          itemFailed('You have failed to use the human device properly. You still gain some insight.');
          game.player.skills.increase(SKILL_COMPUTER, 1);
          return true;
        }

      game.scene.sounds.play('item-' + item.id);
      game.log('You use the ' + item.name + ' to search for known persons data.');
      if (skillLevel < 99)
        game.player.skills.increase(SKILL_COMPUTER, 2);

      var cnt = 1;
      if (item.info.name == 'smartphone')
        cnt = 1;
      else if (item.info.name == 'laptop')
        cnt = 3;

      // goals completed
      game.goals.complete(GOAL_USE_COMPUTER);
      game.goals.receive(GOAL_LEARN_ENGRAM);

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
      game.area.addItem(game.playerArea.x, game.playerArea.y, item);
      _list.remove(item);
      var itemName = (game.player.knowsItem(item.info.id) ?
        item.name : item.info.unknown);
      game.player.log('You drop the ' + Const.col('inventory-item', itemName) + '.');
      game.scene.sounds.play('item-drop');
    }

// ACTION: absorb regional map
  function absorbMapAction(item: _Item)
    {
      game.log('You absorb the regional map into the engram.');
      game.player.vars.mapAbsorbed = true;
    }

// item failed log and sound
  function itemFailed(msg: String)
    {
      game.log(msg);
      game.scene.sounds.play('item-fail');
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

// returns first item with this id from this inventory
  public function get(id: String): _Item
    {
      for (item in _list)
        if (item.id == id)
          return item;
      return null;
    }

// returns all items with this id
  public function getAll(id: String): Array<_Item>
    {
      var ret = [];
      for (item in _list)
        if (item.id == id)
          ret.push(item);
      return ret;
    }

// remove item by id
  public function remove(id: String)
    {
      for (item in _list)
        if (item.id == id)
          {
            _list.remove(item);
            break;
          }
    }

// remove item
  public function removeItem(item: _Item)
    {
      _list.remove(item);
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
  public function addID(id: String, ?wear: Bool = false): _Item
    {
      var item = ItemsConst.spawnItem(game, id);
      // wear/wield item automatically
      if (wear)
        {
          if (item.info.type == 'clothing')
            clothing = item;
        }
      else _list.add(item);
      return item;
    }


// add item
  public inline function add(item: _Item)
    {
      _list.add(item);
    }

  public function length(): Int
    {
      return _list.length;
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
}

