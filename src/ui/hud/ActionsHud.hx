// hud actions block: numbered action ring + game dispatch (keys and clicks)
package ui.hud;

import js.Browser.document;
import js.html.DivElement;

import game.*;

class ActionsHud
{
  var game: Game;
  var hud: HUD;
  var actions: DivElement;
  var listActions: List<_PlayerAction>; // list of currently available actions
  var listKeyActions: List<_PlayerAction>; // list of currently available keyboard actions
  var listButtons: Array<DivElement> = []; // rendered action buttons, indexed by hotkey (1-based)
  var listSig = ''; // signature of the last rendered action set (drives change animation)

  public function new(g: Game, h: HUD)
    {
      game = g;
      hud = h;
      listActions = new List();
      listKeyActions = new List();
      actions = document.createDivElement();
      actions.id = 'hud-actions';
      actions.className = 'hud-panel';
      h.container.appendChild(actions);
    }

// update player actions list
  public inline function updateList()
    {
      listActions = new List();
      listKeyActions = new List();
      if (hud.state == HUD_TARGETING)
        return;
      if (hud.state == HUD_BASE_BUILDING)
        {
          if (game.cults[0].base != null)
            game.cults[0].base.updateActionList();
          return;
        }
      if (game.state == GAMESTATE_FINISH)
        {
          addKeyAction({
            id: 'restart',
            type: (game.location == LOCATION_AREA ? ACTION_AREA : ACTION_REGION),
            name: Const.col('red', 'RESTART'),
            energy: 0,
            // fake
            key: 'r'
          });
          return;
        }
      if (hud.state == HUD_COMMAND_MENU)
        {
          hud.command.updateActions();
          return;
        }
      // ground-items submenu: the full list of tile pickups + a Back item. nothing else
      // (no movement, no other actions) is offered while it is open
      if (hud.state == HUD_PICKUP_MENU)
        {
          for (a in game.playerArea.getTileItemActions())
            addAction(a);
          addAction({
            id: 'pickupMenu.abort',
            type: ACTION_AREA,
            name: 'Back',
            isVirtual: true,
          });
          return;
        }

      // trying to chat
      if (hud.state == HUD_CHAT)
        game.player.chat.updateActionList();
      // pick AI to chat with
      else if (hud.state == HUD_CONVERSE_MENU)
        game.player.chat.converseMenu();
      else
        {
          if (game.location == LOCATION_AREA)
            game.playerArea.updateActionList();

          else if (game.location == LOCATION_REGION)
            game.playerRegion.updateActionList();

          addKeyAction({
            id: 'skipTurn',
            type: (game.location == LOCATION_AREA ? ACTION_AREA : ACTION_REGION),
            name: 'Wait',
            energy: 0,
            // fake
            key: 'z'
          });

          if (game.location == LOCATION_AREA &&
              game.player.state == PLR_STATE_HOST)
            {
              addKeyAction({
                id: 'targetMode',
                type: ACTION_AREA,
                name: 'Target',
                key: 't',
                isVirtual: true,
              });

              if (hud.targeting.canShootTarget())
                addKeyAction({
                  id: 'shootTarget',
                  type: ACTION_AREA,
                  name: 'Shoot',
                  key: 's',
                  isVirtual: true,
                });

              if (hud.targeting.canAttackTarget())
                addKeyAction({
                  id: 'attackTarget',
                  type: ACTION_AREA,
                  name: 'Attack',
                  key: 'a',
                  isVirtual: true,
                });
            }

          if (game.location == LOCATION_AREA &&
              hud.command.hasFollowers())
            addKeyAction({
              id: 'commandMenu',
              type: ACTION_AREA,
              name: 'Command',
              key: 'c',
              isVirtual: true,
            });
        }
      hud.command.updateActions();
    }

// add player action to numbered list
// NOTE: needs to be the same checks as in Player.acitonEnergy()
  public function addAction(action: _PlayerAction)
    {
      // reduce cost when host is agreeable
      if (action.isAgreeable &&
          game.player.hostAgreeable())
        action.energy = 1;
      if (game.player.actionCheckEnergy(action))
        listActions.add(action);
    }

// add player action to key list
  public function addKeyAction(action: _PlayerAction)
    {
      if (game.player.actionCheckEnergy(action))
        listKeyActions.add(action);
    }

// update player actions
  public function updateActions()
    {
      // clear old items
      var n = 1;
      listButtons = [];
      while (actions.firstChild != null)
        actions.removeChild(actions.lastChild);

      // show targeting help instead of actions
      if (hud.state == HUD_TARGETING)
        {
          var btn = document.createDivElement();
          btn.className = 'hud-act hud-act-hint';
          btn.innerHTML = '<b>↑↓</b> Rotate · <b>Enter</b> Select · <b>Esc</b> Clear';
          actions.appendChild(btn);
          return;
        }

      // populate action list; listButtons keeps each row by hotkey index, plus a
      // signature so we only replay the entrance cascade when the set changes
      var sig = '';
      var list = [ listActions, listKeyActions ];
      for (l in list)
        for (act in l)
          {
            // key label: optional S- repeat prefix, then letter key or running number
            var key = '';
            if (game.config.shiftLongActions &&
                act.canRepeat &&
                game.ui.shiftPressed)
              key = 'S-';
            var numbered = (act.key == null);
            if (act.key != null)
              key += act.key.toUpperCase();
            else key += '' + n;
            var name = act.name;
            // dynamic action color
            if (act.id == 'probeBrain')
              name = game.playerArea.getProbeBrainActionName();
            // energy cost (literal or computed)
            var cost = -1;
            if (act.energy != null &&
                act.energy > 0)
              cost = act.energy;
            else if (act.energyFunc != null)
              cost = act.energyFunc(game.player);

            sig += act.id + ':' + key + '|';
            var btn = document.createDivElement();
            btn.className = 'hud-act';
            btn.style.setProperty('--i', '' + (n - 1));
            var html = '<span class="hud-key' + (numbered ? ' num' : '') + '">' + key + '</span>' +
              '<span class="hud-label">' + name + '</span>';
            if (cost > 0)
              html += '<span class="hud-cost">' + cost + UISvg.hudEnergy() + '</span>';
            btn.innerHTML = html;
            // hover previews this action's energy cost on the matching bar
            if (cost > 0)
              {
                var costStat = (game.player.state == PLR_STATE_HOST ? 'he' : 'pe');
                btn.onmouseenter = function (e) hud.infoHud.previewCost(costStat, cost);
                btn.onmouseleave = function (e) hud.infoHud.clearCostPreview();
              }
            var actionIndex = n;
            btn.onclick = function (e) {
              game.scene.sounds.play('click-action');
              if (hud.state == HUD_COMMAND_MENU)
                action(actionIndex, untyped e.shiftKey);
              else doAction(untyped e.shiftKey, act);
            }
            actions.appendChild(btn);
            listButtons.push(btn);
            n++;
          }
      if (n == 1)
        actions.innerHTML = '<div class="hud-act hud-act-none">No available actions.</div>';

      // action set changed -> play the staggered entrance cascade once
      if (sig != listSig)
        for (btn in listButtons)
          btn.classList.add('hud-act-in');
      listSig = sig;
    }

// press the nth on-screen action button (1-based), as if clicked, so a
// keyboard shortcut animates and plays sound via the button's own onclick
  public function pressAction(index: Int, shift: Bool)
    {
      if (index < 1 ||
          index > listButtons.length ||
          !ui.UI.pressButton(listButtons[index - 1], shift))
        action(index, shift); // not on screen: keep old direct behavior
    }

// call numbered action by index
  public function action(index: Int, withRepeat: Bool)
    {
      if (hud.state == HUD_COMMAND_MENU)
        {
          var usedTime = hud.command.action(index);
          if (usedTime &&
              game.location == LOCATION_AREA)
            game.playerArea.actionPost();
          return;
        }

      // find action name by index
      var i = 1;
      var action = null;
      for (a in listActions)
        if (i++ == index)
          {
            action = a;
            break;
          }
      if (action == null)
        return;
      doAction(withRepeat, action);
    }

// common action code for keys and mouse clicks
  function doAction(withRepeat: Bool, action: _PlayerAction)
    {
      if (hud.state == HUD_TARGETING)
        return;
      if (action.id == 'targetMode')
        {
          hud.targeting.enter();
          return;
        }
      if (action.id == 'shootTarget')
        {
          if (hud.targeting.canShootTarget())
            game.playerArea.attackTargetAction(hud.targeting.target);
          return;
        }
      if (action.id == 'attackTarget')
        {
          if (hud.targeting.canAttackTarget())
            game.playerArea.attackTargetAction(hud.targeting.target, true);
          return;
        }
      if (action.id == 'commandMenu')
        {
          hud.command.enter();
          return;
        }
      if (withRepeat &&
          game.config.shiftLongActions &&
          action.canRepeat)
        {
          if (game.location == LOCATION_AREA)
            game.playerArea.setAction(action);
/*
          else if (game.location == LOCATION_REGION)
            game.playerRegion.action(action);*/
          return;
        }

      if (action.type == ACTION_CHAT)
        game.player.chat.action(action);
      else if (action.type == ACTION_CONVERSE_MENU)
        game.player.chat.actionConverseMenu(action);
      else if (action.type == ACTION_HOST)
        game.player.host.action(action);
      else if (action.type == ACTION_INVENTORY)
        game.player.host.inventory.action(action);
      else if (game.location == LOCATION_AREA)
        game.playerArea.action(action);

      else if (game.location == LOCATION_REGION)
        game.playerRegion.action(action);
    }

// call action by key
  public function keyAction(key: String): Bool
    {
      var action = null;
      for (a in listKeyActions)
        if (a.key == key)
          {
            action = a;
            break;
          }
      if (action == null)
        return false;
      if (action.id == 'commandMenu')
        {
          hud.command.enter();
          return true;
        }
      if (action.id == 'targetMode' ||
          action.id == 'shootTarget' ||
          action.id == 'attackTarget')
        return false;

      if (game.location == LOCATION_AREA)
        game.playerArea.action(action);

      else if (game.location == LOCATION_REGION)
        game.playerRegion.action(action);

      return true;
    }
}
