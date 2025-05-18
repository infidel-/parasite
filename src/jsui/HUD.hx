// new js ui hud
package jsui;

import js.Browser;
import js.html.TextAreaElement;
import js.html.DivElement;
import js.html.KeyboardEvent;
import js.html.MouseEvent;

import game.*;

class HUD
{
  var game: Game;
  var ui: UI;
  public var state: _HUDState;
  var blinkingText: DivElement;
  var overlay: DivElement;
  var container: DivElement;
  var consoleDiv: DivElement;
  var console: TextAreaElement;
  var log: DivElement;
  var goals: DivElement;
  var info: DivElement;
#if mydebug
  var debugInfo: DivElement;
#end
  var menuButtons: Array<{
    state: _UIState,
    btn: DivElement,
  }>;
  var actions: DivElement;
  var actionButtons: List<DivElement>; // list of action buttons
  var listActions: List<_PlayerAction>; // list of currently available actions
  var listKeyActions: List<_PlayerAction>; // list of currently available keyboard actions
  var listTransparentElements: Array<DivElement>;
  var listElements: Array<DivElement>;

  public function new(u: UI, g: Game)
    {
      game = g;
      ui = u;
      state = HUD_DEFAULT;
      actionButtons = new List();
      listActions = new List();
      listKeyActions = new List();

      overlay = Browser.document.createDivElement();
      overlay.id = 'overlay';
      overlay.style.visibility = 'hidden';
      Browser.document.body.appendChild(overlay);

      blinkingText = Browser.document.createDivElement();
      blinkingText.innerHTML = 'You feel someone is watching.';
      blinkingText.className = 'highlight-text';
      blinkingText.id = 'blinking-text';
      blinkingText.style.opacity = '0';
      blinkingText.style.userSelect = 'none';
      Browser.document.body.appendChild(blinkingText);

      container = Browser.document.createDivElement();
      container.id = 'hud';
      container.style.visibility = 'visible';
      Browser.document.body.appendChild(container);

      consoleDiv = Browser.document.createDivElement();
      consoleDiv.className = 'console-div';
      consoleDiv.style.visibility = 'hidden';
      container.appendChild(consoleDiv);

      console = Browser.document.createTextAreaElement();
      console.id = 'hud-console';
      console.onkeydown = function(e: KeyboardEvent) {
        if (e.code == 'Escape')
          hideConsole();
        else if (e.code == 'Enter')
          {
            game.console.run(console.value);
            // kludge: needs a timeout or closes the event window
            Browser.window.setTimeout(hideConsole, 10);
          }
      }
      consoleDiv.appendChild(console);

      log = Browser.document.createDivElement();
      log.className = 'text';
      log.id = 'hud-log';
      log.style.borderImage = "url('./img/hud-log-border.png') 15 fill / 1 / 0 stretch";
      container.appendChild(log);

      goals = Browser.document.createDivElement();
      goals.className = 'text';
      goals.id = 'hud-goals';
      goals.style.borderImage = "url('./img/hud-goals-border.png') 24 fill / 1 / 0 stretch";
      container.appendChild(goals);

      info = Browser.document.createDivElement();
      info.className = 'text';
      info.id = 'hud-info';
      info.style.borderImage = "url('./img/hud-info-border.png') 36 20 36 fill / 1 / 0 stretch";
      container.appendChild(info);

#if mydebug
      debugInfo = Browser.document.createDivElement();
      debugInfo.className = 'text';
      debugInfo.id = 'hud-debug-info';
      container.appendChild(debugInfo);
#end

      // menu
      var buttons = Browser.document.createDivElement();
      buttons.id = 'hud-buttons';
      container.appendChild(buttons);
      menuButtons = [];
      addMenuButton(buttons, UISTATE_GOALS,
        Const.key('F1') + ': GOALS');
      addMenuButton(buttons, UISTATE_BODY,
        Const.key('F2') + ': BODY');
      addMenuButton(buttons, UISTATE_LOG,
        Const.key('F3') + ': LOG');
      addMenuButton(buttons, UISTATE_TIMELINE,
        Const.key('F4') + ': TIMELINE');
      addMenuButton(buttons, UISTATE_EVOLUTION,
        Const.key('F5') + ': EVO');

      // actions
      actions = Browser.document.createDivElement();
      actions.id = 'hud-actions';
      actions.style.borderImage = "url('./img/hud-actions-border.png') 28 fill / 1 / 0 stretch";
      container.appendChild(actions);

      listTransparentElements = [
        info,
        log,
        goals,
      ];
      listElements = [
        info,
        actions,
        log,
        goals,
      ];
    }

// show blinking text and set timeout
  public function showBlinkingText()
    {
      blinkingText.style.opacity = '1';
      Browser.window.setTimeout(function() {
        blinkingText.style.opacity = '0';
      }, 2000);
    }

// show glass wall overlay
// NOTE: dont really like it, the mouse cursor will not change without movement
  public inline function showOverlay()
    {
//      overlay.style.visibility = 'visible';
    }

// hide glass wall overlay
  public inline function hideOverlay()
    {
//      overlay.style.visibility = 'hidden';
    }

// add button to menu
  function addMenuButton(cont: DivElement, state: _UIState, str: String): DivElement
    {
      var btn = Browser.document.createDivElement();
      btn.innerHTML = str;
      btn.className = 'hud-button window-title';
      btn.style.borderImage = "url('./img/hud-button.png') 23 fill / 1 / 0 stretch";
      cont.appendChild(btn);
      menuButtons.push({
        state: state,
        btn: btn,
      });
      btn.onclick = function (e)
        {
          game.scene.sounds.play('click-hud');
          game.scene.sounds.play('window-open');
          game.ui.state = state; 
        }
      return btn;
    }

// get menu button
  public function getMenuButton(state: _UIState): DivElement
    {
      for (b in menuButtons)
        if (b.state == state)
          return b.btn;
      return null;
    }

// make hud transparent
  public function onMouseMove(e: MouseEvent)
    {
      for (el in listTransparentElements)
        {
          var r = el.getBoundingClientRect();
          if (r.x < e.clientX &&
              r.y < e.clientY &&
              e.clientX < r.x + r.width &&
              e.clientY < r.y + r.height)
            el.style.opacity = '0.1';
          else el.style.opacity = '0.9';
        }
    }

// show hide HUD
  public function toggle()
    {
      if (container.style.visibility == 'visible')
        hide();
      else show();
      if (game.location == LOCATION_AREA)
        game.scene.area.draw();
    }

// returns true if HUD is visible
  public function isVisible(): Bool
    {
      return (container.style.visibility == 'visible');
    }

  public function show()
    {
      // hack: restore opacity animation
      for (el in listElements)
        el.style.transition = '0.1s';
      container.style.visibility = 'visible';
    }

  public function hide()
    {
      // hack: remove opacity animation
      for (el in listElements)
        el.style.transition = '0s';
      container.style.visibility = 'hidden';
    }

  public function consoleVisible(): Bool
    {
      return (consoleDiv.style.visibility == 'visible');
    }

  public function showConsole()
    {
      consoleDiv.style.visibility = 'visible';
      console.value = '';
      Browser.window.setTimeout(function () {
        console.value = '';
      });
      console.focus();
    }

  public function hideConsole()
    {
      consoleDiv.style.visibility = 'hidden';
      ui.focus();
    }

// update HUD state from game state
  public function update()
    {
      updateActionList();
      // NOTE: before info because info uses its height
      updateActions();
      updateInfo();
      updateLog();
      updateMenu();
      updateGoals();
#if mydebug
      updateDebugInfo();
#end
    }

// update log display
  public function updateLog()
    {
      var buf = new StringBuf();
      for (l in game.hudMessageList)
        {
          buf.add('<span ');
          if (l.col == COLOR_ALERT)
            buf.add('class=highlight-text ');
          buf.add("style='color:");
          buf.add(Const.TEXT_COLORS[l.col]);
          buf.add("'>");
          buf.add(l.msg);
          buf.add("</span>");
          if (l.cnt > 1)
            {
              buf.add(" <span class=small style='color:var(--text-color-repeat)'>(x");
              buf.add(l.cnt);
              buf.add(")</span>");
            }
          buf.add('<br/>');
        }

      log.innerHTML = buf.toString();
    }

// update goals list
  function updateGoals()
    {
      var buf = new StringBuf();
      for (g in game.goals.iteratorCurrent())
        {
          var info = game.goals.getInfo(g);
          if (info.isHidden)
            continue;

          buf.add(Const.col('goal', info.name));
          if (info.isOptional)
            buf.add(' ' + Const.small(Const.col('gray', '[optional]')));
          buf.add('<br/>');
          buf.add(info.note + '<br/>');
          if (info.noteFunc != null)
            buf.add(info.noteFunc(game) + '<br/>');
          buf.add('<br/>');
        }
      var s = buf.toString().substr(0, buf.length - 10); // remove last two br's'
      goals.innerHTML = s;
    }

// get color for text (red, yellow, white)
  function getColor(val: Float, max: Float): String
    {
      if (val > 0.7 * max)
        return "style='color:var(--text-color-white)'";
      else if (val > 0.3 * max)
        return "style='color:var(--text-color-yellow)'";

      return "style='color:var(--text-color-red)' class=blinking-red";
    }

// update player info
  function updateInfo()
    {
      var buf = new StringBuf();
      buf.add('Turn: ' + game.turns);
      if (game.location == LOCATION_AREA)
          buf.add(Const.smallgray(' [' + game.playerArea.ap + ']') +
            ', at (' + game.playerArea.x + ',' + game.playerArea.y + ')' +
#if mydebug
            Const.smallgray(' A ' + Math.round(game.area.alertness)) +
#end
            '<br/>');
      else if (game.location == LOCATION_REGION)
        buf.add(', at (' +
          game.playerRegion.x + ',' + game.playerRegion.y + ')' +
#if mydebug
            ' A ' + Math.round(game.playerRegion.currentArea.alertness) +
#end
          '<br/>' + game.playerRegion.currentArea.name + '<br/>');
      buf.add('<hr/>');

      // parasite stats
      var time = (game.location == LOCATION_AREA ? 1 : 5);
      var energyPerTurn = __Math.parasiteEnergyPerTurn(time);
      buf.add('Energy: ' +
        "<font " + getColor(game.player.energy, game.player.maxEnergy) +
        ">" + game.player.energy + "</font>" +
        '/' + game.player.maxEnergy);
      buf.add(' ' + Const.col('gray',
        Const.small('[' + (energyPerTurn > 0 ? '+' : '') +
        energyPerTurn + '/t]')) + '<br/>');
      buf.add('Health: ' +
        "<font " + getColor(game.player.health, game.player.maxHealth) +
        ">" + game.player.health + "</font>" +
        '/' + game.player.maxHealth);
      // team distance if close
      if (!game.group.hudInfo(buf))
        buf.add('<br/>');
      buf.add('<hr/>');

      if (game.player.state == PLR_STATE_ATTACHED)
        {
          buf.add('Grip: ' +
            '<font ' + getColor(game.playerArea.attachHold, 100) + '>' +
            game.playerArea.attachHold + '</font>/100<br/>');
        }

      // host stats
      else if (game.player.state == PLR_STATE_HOST)
        {
          var host = game.player.host;
          if (host.isHuman)
            buf.add('<span class=hud-name>' + host.getNameCapped() + '</span>');
          else buf.add('<span class=hud-name>' + host.AName() + '</span>');
          // special symbols
          if (host.affinity >= 100)
            buf.add(Const.icon('symbiosis', ' &#127280; ')); // 🄰
          if (host.chat.consent >= 100)
            buf.add(Const.icon('symbiosis', ' &#127282; ')); // 🄲
          if (host.isCultist && host.cultID == game.cults[0].id)
            buf.add(Const.icon('follower', ' &#127285; ')); // 🄵

          if (host.isJobKnown)
            buf.add(' ' + Const.col('gray',
              Const.small('(' + host.job + ')<br/>')));
          else buf.add('<br/>');
          if (host.isAttrsKnown)
            buf.add('STR ' + host.strength +
              ' CON ' + host.constitution +
              ' INT ' + host.intellect +
              ' PSY ' + host.psyche + '<br/>');
          buf.add('Health: ' +
            '<font ' + getColor(host.health,
            host.maxHealth) + '>' +
            host.health + '</font>' +
            '/' + host.maxHealth + '<br/>');

          buf.add('Control: ' +
            '<font ' + getColor(game.player.hostControl, 100) + '>' + game.player.hostControl + '</font>' +
            '/100<br/>');

          // energy
          var energyPerTurn = __Math.fullHostEnergyPerTurn(time);
          buf.add("Energy: <font " + getColor(host.energy,
            host.maxEnergy) + ">" +
            host.energy + '</font>/' +
            host.maxEnergy);
          // energy spending
          if (energyPerTurn != 0)
            buf.add(' ' +
              Const.smallgray('[' + (energyPerTurn > 0 ? '+' : '') +
              energyPerTurn + '/t]'));
          // time to live
          if (energyPerTurn < 0)
            buf.add(' ' +
              Const.smallgray('[' +
              Math.ceil(game.player.host.energy / (- energyPerTurn)) + 't]'));
          // organ growth/evolution
          if (game.player.evolutionManager.isActive)
            {
              buf.add('<br>Evolution direction:<br/>  ');
              buf.add(game.player.evolutionManager.getEvolutionDirectionInfo());
            }
          var str = host.organs.getInfo();
          if (str != null)
            {
              buf.add('<br/>');
              buf.add(str);
            }
        }

      if (game.player.vars.isSpoonGame)
        buf.add("<div style='padding-top:10px;text-align:center;font-size:40%;font-weight:bold'>" +
          Const.col('yellow', 'SPOONED') + '</div>');
      info.innerHTML = buf.toString();
      if (game.player.state != PLR_STATE_HOST)
        info.className = 
          (game.player.energy <= 0.5 * game.player.maxEnergy ?
           'text highlight-text' : 'text');
      else info.className = 'text';
    }

#if mydebug
// debug info
  function updateDebugInfo()
    {
      var buf = new StringBuf();
      buf.add(
        'Tile resolution: ' +
        Std.int(game.scene.canvas.width / Const.TILE_SIZE) + 'x' +
        Std.int(game.scene.canvas.height / Const.TILE_SIZE) +
        '<br>emptyScreenCells: ' + game.scene.area.emptyScreenCells +
        ', maxAI: ' + game.area.getMaxAI() + '<br>');
      if (!game.group.isKnown)
        buf.add('Group known count: ' + game.group.knownCount + '<br/>');
      buf.add('Group priority: ' + Const.round(game.group.priority) +
        ', team timeout: ' + game.group.teamTimeout + '<br/>');
      if (game.group.team != null)
        buf.add('Team: ' + game.group.team + '<br/>');
      if (game.location == LOCATION_AREA)
        game.managerArea.debugInfo(buf);
      debugInfo.innerHTML = buf.toString();
    }
#end

// update menu buttons visibility
  function updateMenu()
    {
      var vis = false;
      for (m in menuButtons)
        {
          vis = false;
          if (m.state == UISTATE_GOALS ||
              m.state == UISTATE_LOG ||
              m.state == UISTATE_OPTIONS ||
              m.state == UISTATE_DEBUG ||
              m.state == UISTATE_YESNO) // exit
            vis = true;

          else if (m.state == UISTATE_BODY)
            {
              if (game.player.vars.inventoryEnabled ||
                  game.player.vars.skillsEnabled ||
                  game.player.vars.organsEnabled)
                vis = true;
            }
          else if (m.state == UISTATE_TIMELINE)
            {
              if (game.player.vars.timelineEnabled)
                vis = true;
            }

          else if (m.state == UISTATE_EVOLUTION)
            {
              if (game.player.state == PLR_STATE_HOST &&
                  game.player.evolutionManager.state > 0)
                vis = true;
            }
          m.btn.style.display = (vis ? 'flex' : 'none');
          // clear highlight on hide
          if (!vis && m.btn.className.indexOf('highlight') > 0)
            m.btn.className = 'hud-button';
        }
    }

// update player actions list
  inline function updateActionList()
    {
      listActions = new List();
      listKeyActions = new List();
      if (game.isFinished)
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

      // trying to chat
      if (state == HUD_CHAT)
        game.player.chat.updateActionList();
      // pick AI to chat with
      else if (state == HUD_CONVERSE_MENU)
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
        }
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
      while (actions.firstChild != null)
        actions.removeChild(actions.lastChild);
      var list = [ listActions, listKeyActions ];
      for (l in list)
        for (action in l)
          {
            var buf = new StringBuf();
            var key = '';
            if (game.config.shiftLongActions &&
                action.canRepeat &&
                ui.shiftPressed)
              key = 'S-';
            if (action.key != null)
              key += action.key.toUpperCase();
            else key += '' + n;
            var name = action.name;
            // dynamic action color
            if (action.id == 'probeBrain')
              name = game.playerArea.getProbeBrainActionName();
            buf.add(Const.key(key) + ': ' + name);
            if (action.energy != null &&
                action.energy > 0)
              buf.add(Const.cost(action.energy));
            else if (action.energyFunc != null)
              buf.add(Const.cost(action.energyFunc(game.player)));

            var btn = Browser.document.createDivElement();
            btn.innerHTML = buf.toString();
            btn.className = 'hud-action';
            btn.onclick = function (e) {
              game.scene.sounds.play('click-action');
              doAction(untyped e.shiftKey, action);
            }
            actions.appendChild(btn);
            n++;
          }
      if (n == 1)
        actions.innerHTML = 'No available actions.';
    }

// call numbered action by index
  public function action(index: Int, withRepeat: Bool)
    {
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

      if (game.location == LOCATION_AREA)
        game.playerArea.action(action);

      else if (game.location == LOCATION_REGION)
        game.playerRegion.action(action);

      return true;
    }

// reset hud state to default
  public function resetState()
    {
      switch (state)
        {
          case HUD_CHAT:
            game.player.chat.finish();
            game.log('The conversation was interrupted.');
          case HUD_CONVERSE_MENU:
            state = HUD_DEFAULT;
          case HUD_DEFAULT:
            // do nothing
        }
    }
}

