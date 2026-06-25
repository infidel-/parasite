// pickpocket action logic — injected into the area action list by Entry and
// dispatched through the action's f callback. the action is marked virtual so
// the engine does not auto-spend the turn; we end the turn ourselves only on a
// real attempt (success/fail roll), leaving precondition failures free.
package;

class Pickpocket
{
// appends the Pickpocket action when the player (in a host) stands next to a
// human. called at the tail of the wrapped PlayerArea.updateActionList
  public static function injectAction(game: game.Game): Void
    {
      if (Std.string(game.player.state) != 'PLR_STATE_HOST')
        return;
      var pa = game.playerArea;
      var found = false;
      for (i in 0...Const.dirx.length)
        {
          var ai = game.area.getAI(pa.x + Const.dirx[i], pa.y + Const.diry[i]);
          if (ai != null && ai.isHuman)
            {
              found = true;
              break;
            }
        }
      if (!found)
        return;
      game.ui.hud.addAction({
        id: 'mod-pickpocket-action',
        type: 'ACTION_AREA',
        name: 'Pickpocket',
        energy: 0,
        isVirtual: true,
        f: function() run(game),
      });
    }

// runs a pickpocket attempt against the chosen adjacent target
  public static function run(game: game.Game): Void
    {
      var pa = game.playerArea;

      // collect adjacent humans
      var adj: Array<ai.AI> = [];
      for (i in 0...Const.dirx.length)
        {
          var ai = game.area.getAI(pa.x + Const.dirx[i], pa.y + Const.diry[i]);
          if (ai != null && ai.isHuman)
            adj.push(ai);
        }
      if (adj.length == 0)
        {
          game.actionFailed('There is no one beside you to rob.');
          return;
        }

      // single neighbor: auto-pick. multiple: require an active target
      var target = adj[0];
      if (adj.length > 1)
        {
          target = game.ui.hud.targeting.getAITarget();
          if (target == null)
            {
              game.actionFailed('Several people are close. Pick a target first.');
              return;
            }
          if (adj.indexOf(target) < 0)
            {
              game.actionFailed('That target is not within reach.');
              return;
            }
        }

      // target gating
      if (Std.string(target.state) != 'AI_STATE_IDLE')
        {
          game.actionFailed(target.getNameCapped() + ' is too alert to rob.');
          return;
        }
      if (target.isPlayerCultist())
        {
          game.actionFailed('You will not steal from your brethren and followers.');
          return;
        }
      if (!target.isHuman)
        {
          game.actionFailed('There is nothing to take.');
          return;
        }

      // host hands must have room — the engine caps inventory at host.maxItems
      // (same check the pickup/body-search paths use). fail fast so a full host
      // never overflows on a successful lift
      var host = game.player.host;
      if (host.inventory.length() >= host.maxItems)
        {
          game.actionFailed('Your host has no room to carry anything else.');
          return;
        }

      // build pickable list — loose items only (clothing/armor lives in a
      // separate slot and is never yielded here); skip non-concealable weapons
      var pick: Array<game._Item> = [];
      // Inventory.iterator() is typed Dynamic in the extern (engine returns a
      // bare hasNext/next iterator object) — the only untyped surface here; the
      // yielded items are cast back to the typed _Item
      var it: Dynamic = target.inventory.iterator();
      while (it.hasNext())
        {
          var item: game._Item = it.next();
          if (item.info.weapon != null &&
              !item.info.weapon.canConceal)
            continue;
          pick.push(item);
        }
      if (pick.length == 0)
        {
          game.actionFailed(target.getNameCapped() + ' has nothing you can lift.');
          return;
        }

      // roll the skill
      var item = pick[Std.random(pick.length)];
      var roll = __Math.skill({
        id: Entry.SKILL,
        level: game.player.skills.getLevel(Entry.SKILL),
      });
      if (roll)
        {
          target.inventory.removeItem(item);
          game.player.host.inventory.add(item);
          game.scene.sounds.play('action-pickpocket');
          game.log('You deftly lift ' + item.getName() + ' from ' +
            target.theName() + '.');
          game.player.skills.increase(Entry.SKILL, 5);
        }
      else
        {
          game.player.skills.increase(Entry.SKILL, 1);
          target.setState('AI_STATE_ALERT', null,
            ' catches your hand in his pocket!');
          game.actionFailed('Caught! ' + target.getNameCapped() +
            ' is now alerted.');
        }

      // a real attempt always costs the turn (the action is virtual, so the
      // engine does not advance time for us)
      pa.actionPost();
    }
}
