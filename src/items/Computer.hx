// base info for computer-like items
package items;

import l10n.Loc;

import Const;
import ItemInfo;
import _PlayerAction;
import game.Game;
import game._Item;

class Computer extends ItemInfo
{
// builds computer defaults
  public function new(game: Game)
    {
      super(game);
      type = 'computer';
    }

// builds computer-specific inventory actions
  override public function getInventoryActions(item: _Item): Array<_PlayerAction>
    {
      var actions = super.getInventoryActions(item);
      if (game.player.evolutionManager.getLevel(IMP_ENGRAM) >= 1 &&
          !game.player.vars.mapAbsorbed)
        actions.push({
          id: 'absorbMap.' + item.id,
          type: ACTION_INVENTORY,
          name: T('Absorb regional map'),
          nameClean: T('Absorb map'),
          energy: 15,
          item: item
        });
      if (game.player.vars.searchEnabled)
        actions.push({
          id: 'search.' + item.id,
          type: ACTION_INVENTORY,
          name: T('Use {item} to search', { item: Loc.colored('inventory-item', item) }),
          nameClean: T('Search'),
          energy: 10,
          item: item
        });
      return actions;
    }

// handles computer-specific inventory actions
  override public function action(actionID: String, action: _PlayerAction): Null<Bool>
    {
      return switch (actionID)
        {
          case 'absorbMap': absorbMapAction(action.item);
          case 'search': searchAction(action.item);
          default: super.action(actionID, action);
        };
    }

// performs absorb map action
  function absorbMapAction(item: _Item): Bool
    {
      game.log(T('You absorb the regional map into the engram.'));
      game.player.vars.mapAbsorbed = true;
      return true;
    }

// performs search action with computer devices
  function searchAction(item: _Item): Bool
    {
      var skillLevel = game.player.skills.getLevel(SKILL_COMPUTER);
      if (skillLevel == 0)
        {
          itemFailed(T('You require the computer use skill to do that.'));
          return false;
        }

      if (!game.area.isHabitat)
        {
          if (game.player.evolutionManager.getLevel(IMP_MICROHABITAT) > 0)
            itemFailed(T("This action requires intense concentration and time. You can only do it in a habitat."));
          else itemFailed(T("This action requires intense concentration and time. You cannot do it yet."));
          game.profile.addPediaArticle('msgConcentration');
          return false;
        }

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
          itemFailed(T('You have already researched all known persons.'));
          return false;
        }

      var mods = [];
      if (item.info.name == 'laptop')
        mods.push({ name: 'laptop', val: 10.0 });
      var rollSuccess = __Math.skill({
        id: SKILL_COMPUTER,
        level: skillLevel,
        mods: mods
        });
      if (!rollSuccess)
        {
          itemFailed(T('You have failed to use the human device properly. You still gain some insight.'));
          game.player.skills.increase(SKILL_COMPUTER, 1);
          return true;
        }

      game.scene.sounds.play('item-' + item.id);
      game.log(T('You use {item:the} to search for known persons data.', { item: Loc.thing(item.name) }));
      if (skillLevel < 99)
        game.player.skills.increase(SKILL_COMPUTER, 2);

      var cnt = 1;
      if (item.info.name == 'smartphone')
        cnt = 1;
      else if (item.info.name == 'laptop')
        cnt = 3;

      game.goals.complete(GOAL_USE_COMPUTER);
      game.goals.receive(GOAL_LEARN_ENGRAM);

      for (e in game.timeline)
        for (n in e.npc)
          {
            if (!n.nameKnown && !n.jobKnown)
              continue;

            if (n.fullyKnown())
              continue;

            if (game.timeline.difficulty == EASY)
              {
                n.researchFull();
                cnt--;
                if (cnt <= 0)
                  return true;
              }
            else
              {
                while (cnt > 0 && n.research())
                  cnt--;
                if (cnt <= 0)
                  return true;
              }
          }

      return true;
    }
}
