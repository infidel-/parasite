// new js ui hud
package jsui;

import js.Browser;
import js.html.TextAreaElement;
import js.html.DivElement;
import js.html.KeyboardEvent;

import game.*;

class HUD
{
  var game: Game;
  var ui: UI;
  var container: DivElement;
  var consoleDiv: DivElement;
  var console: TextAreaElement;
  var log: DivElement;
  var goals: DivElement;
  var info: DivElement;
  var menuButtons: Array<{
    state: _UIState,
    btn: DivElement,
  }>;
  var actions: DivElement;
  var actionButtons: List<DivElement>; // list of action buttons
  var listActions: List<_PlayerAction>; // list of currently available actions
  var listKeyActions: List<_PlayerAction>; // list of currently available keyboard actions

  public function new(u: UI, g: Game)
    {
      game = g;
      ui = u;
      actionButtons = new List();
      listActions = new List();
      listKeyActions = new List();
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
            hideConsole();
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

      // menu
      var buttons = Browser.document.createDivElement();
      buttons.id = 'hud-buttons';
      container.appendChild(buttons);
      menuButtons = [];
      addMenuButton(buttons, UISTATE_GOALS, '1: GOALS');
      addMenuButton(buttons, UISTATE_INVENTORY, '2: INV');
      addMenuButton(buttons, UISTATE_SKILLS, '3: KNOW');
      addMenuButton(buttons, UISTATE_LOG, '4: LOG');
      addMenuButton(buttons, UISTATE_TIMELINE, '5: TIMELINE');
      addMenuButton(buttons, UISTATE_EVOLUTION, '6: EVO');
      addMenuButton(buttons, UISTATE_ORGANS, '7: BODY');
      addMenuButton(buttons, UISTATE_OPTIONS, '8: OPT');
#if mydebug
      addMenuButton(buttons, UISTATE_DEBUG, '9: DBG');
#end
      // should be unique state but no matter
      var btn = addMenuButton(buttons, UISTATE_YESNO, '10: EXIT');
/*
      btn.onClick = function (e: Event)
        {
          @:privateAccess game.scene.handleInput(Key.F10);
        }*/

      // actions
      actions = Browser.document.createDivElement();
      actions.id = 'hud-actions';
      actions.style.borderImage = "url('./img/hud-actions-border.png') 28 fill / 1 / 0 stretch";
      container.appendChild(actions);
    }

// add button to menu
  function addMenuButton(cont: DivElement, state: _UIState, str: String): DivElement
    {
      var btn = Browser.document.createDivElement();
      btn.innerHTML = 'F' + str;
      btn.className = 'hud-button';
      btn.style.borderImage = "url('./img/hud-button.png') 23 fill / 1 / 0 stretch";
      cont.appendChild(btn);
      menuButtons.push({
        state: state,
        btn: btn,
      });
      btn.onclick = function (e)
        { game.scene.state = state; }
      return btn;
    }

// show hide HUD
  public inline function toggle()
    {
      container.style.visibility =
        (container.style.visibility == 'visible' ? 'hidden' : 'visible');
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
/*
      updateConsole();*/
      updateGoals();
    }

// update log display
  public function updateLog()
    {
      var buf = new StringBuf();
      for (l in game.hudMessageList)
        {
          buf.add("<font color='");
          buf.add(Const.TEXT_COLORS[l.col]);
          buf.add("'>");
          buf.add(l.msg);
          buf.add("</font>");
          if (l.cnt > 1)
            {
              buf.add(" <font color='");
              buf.add(Const.TEXT_COLORS[_TextColor.COLOR_REPEAT]);
              buf.add("'>(x");
              buf.add(l.cnt);
              buf.add(")</font>");
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

          buf.add("<font color='" +
            Const.TEXT_COLORS[_TextColor.COLOR_GOAL] +
            "'>" + info.name + '</font><br/>');
          buf.add(info.note + '<br/>');
          if (info.note2 != null)
            buf.add(info.note2 + '<br/>');
          buf.add('<br/>');
        }
      var s = buf.toString().substr(0, buf.length - 10); // remove last two br's'

      goals.innerHTML = s;
    }

// get color for text (red, yellow, white)
  function getTextColor(val: Float, max: Float)
    {
      if (val > 0.7 * max)
        return 'var(--text-color-white)';
      else if (val > 0.3 * max)
        return 'var(--text-color-yellow)';

      return 'var(--text-color-red)';
    }

// update player info
  function updateInfo()
    {
      var buf = new StringBuf();
      buf.add('Turn: ' + game.turns + ', at (');
      if (game.location == LOCATION_AREA)
          buf.add(
            game.playerArea.x + ',' + game.playerArea.y + ')' +
#if mydebug
            ' A ' + Math.round(game.area.alertness) +
#end
            '<br/>Actions: ' + game.playerArea.ap + '<br/>');
      else if (game.location == LOCATION_REGION)
        buf.add(
          game.playerRegion.x + ',' + game.playerRegion.y + ')' +
#if mydebug
            ' A ' + Math.round(game.playerRegion.currentArea.alertness) +
#end
          '<br/>' + game.playerRegion.currentArea.name + '<br/>');
      buf.add('<hr/>');

      var colEnergy = getTextColor(game.player.energy, game.player.maxEnergy);
      var time = (game.location == LOCATION_AREA ? 1 : 5);
      var energyPerTurn = __Math.parasiteEnergyPerTurn(time);
      buf.add('Energy: ' +
        "<font style='color:" + colEnergy + "'>" + game.player.energy + "</font>" +
        '/' + game.player.maxEnergy);
      buf.add(' [' + (energyPerTurn > 0 ? '+' : '') + energyPerTurn + '/t]<br/>');
      var colHealth = getTextColor(game.player.health, game.player.maxHealth);
      buf.add('Health: ' +
        "<font style='color:" + colHealth + "'>" + game.player.health + "</font>" +
        '/' + game.player.maxHealth);

      if (game.player.state == PLR_STATE_ATTACHED)
        {
          buf.add('<br/><hr/>');
          buf.add("Grip: <font style='color:" +
            getTextColor(game.playerArea.attachHold, 100) + "'>" +
            game.playerArea.attachHold + "</font>/100<br/>");
        }

      // host stats
      else if (game.player.state == PLR_STATE_HOST)
        {
          buf.add('<br/><hr/>');
          buf.add(game.player.host.getNameCapped());
          if (game.player.host.isJobKnown)
            buf.add(' (' + game.player.host.job + ')<br/>');
          else buf.add('<br/>');
          if (game.player.host.isAttrsKnown)
            buf.add('STR ' + game.player.host.strength +
              ' CON ' + game.player.host.constitution +
              ' INT ' + game.player.host.intellect +
              ' PSY ' + game.player.host.psyche + '<br/>');

          var colHealth = getTextColor(game.player.host.health,
            game.player.host.maxHealth);
          buf.add('Health: ' +
            "<font style='color:" + colHealth + "'>" + game.player.host.health + "</font>" +
            '/' + game.player.host.maxHealth + '<br/>');

          var colControl = getTextColor(game.player.hostControl, 100);
          buf.add('Control: ' +
            "<font style='color:" + colControl + "'>" + game.player.hostControl + "</font>" +
            '/100<br/>');

          var colEnergy = getTextColor(game.player.host.energy,
            game.player.host.maxEnergy);
          var energyPerTurn = __Math.fullHostEnergyPerTurn(time);
          buf.add("Energy: <font style='color:" + colEnergy + "'>" +
            game.player.host.energy + '</font>/' +
            game.player.host.maxEnergy);
          buf.add(' [' + (energyPerTurn > 0 ? '+' : '') +
            energyPerTurn + '/t]<br/>');
          buf.add('Evolution direction:<br/>  ');
          buf.add(game.player.evolutionManager.getEvolutionDirectionInfo());
          var str = game.player.host.organs.getInfo();
          if (str != null)
            {
              buf.add('<br/>');
              buf.add(str);
            }
        }

      info.innerHTML = buf.toString();
    }

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

          else if (m.state == UISTATE_INVENTORY)
            {
              if (game.player.state == PLR_STATE_HOST &&
                  game.player.vars.inventoryEnabled)
                vis = true;
            }

          else if (m.state == UISTATE_SKILLS)
            {
              if (game.player.vars.skillsEnabled)
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

          else if (m.state == UISTATE_ORGANS)
            {
              if (game.player.state == PLR_STATE_HOST &&
                  game.player.vars.organsEnabled)
                vis = true;
            }

          m.btn.style.display = (vis ? 'flex' : 'none');
        }
    }

// update player actions list
  inline function updateActionList()
    {
      if (game.isFinished)
        return;

      listActions = new List();
      listKeyActions = new List();

      if (game.location == LOCATION_AREA)
        game.playerArea.updateActionList();

//      else if (game.location == LOCATION_REGION)
//        game.playerRegion.updateActionList();

      addKeyAction({
        id: 'skipTurn',
        type: (game.location == LOCATION_AREA ? ACTION_AREA : ACTION_REGION),
        name: 'Wait',
        energy: 0,
        key: 'KeyZ'
      });
    }

// add player action to numbered list
  public function addAction(a: _PlayerAction)
    {
      if (a.energy != null && a.energy <= game.player.energy)
        listActions.add(a);

      else if (a.energyFunc != null)
        {
          var e = a.energyFunc(game.player);
          if (e >= 0 && e <= game.player.energy)
            listActions.add(a);
        }
    }

// add player action to key list
  public function addKeyAction(a: _PlayerAction)
    {
      if (a.energy <= game.player.energy)
        listKeyActions.add(a);
    }

// update player actions
  function updateActions()
    {
      var n = 1;
      while (actions.firstChild != null)
        actions.removeChild(actions.lastChild);
      if (!game.isFinished)
        {
          var list = [ listActions, listKeyActions ];
          for (l in list)
            for (action in l)
              {
                var buf = new StringBuf();
                if (action.key != null)
                  buf.add(action.key.substr(3) + ': ');
                else buf.add(n + ': ');
                buf.add(action.name);
                if (action.energy != null && action.energy > 0)
                  buf.add(' (' + action.energy + ' energy)');
                else if (action.energyFunc != null)
                  buf.add(' (' + action.energyFunc(game.player) + ' energy)');

                var btn = Browser.document.createDivElement();
                btn.innerHTML = buf.toString();
                btn.className = 'hud-action';
                btn.onclick = function (e) {
                  if (game.location == LOCATION_AREA)
                    game.playerArea.action(action);

                  else if (game.location == LOCATION_REGION)
                    game.playerRegion.action(action);
                }
                actions.appendChild(btn);
                n++;
              }
        }

      if (game.isFinished)
        actions.innerHTML = '<font style="color:var(--text-color-red)">Press ENTER to restart</font>';
      else if (n == 1)
        actions.innerHTML = 'No available actions.';
/*

      _actions.text = buf.toString();
      _actionsBack.clear();
      _actionsBack.beginFill(0x202020, 0.75);
      _actionsBack.drawRect(0, 0, _actions.textWidth, _actions.textHeight);
      _actionsBack.endFill();
      _actionsBack.y = game.scene.win.height - _actions.textHeight -
        game.config.fontSize - 50;

      // clear old buttons
      for (b in _actionButtons)
        {
          b.back.remove();
          b.btn.remove();
        }
      _actionButtons = new List();

      if (game.isFinished || n == 1)
        return;

      // action buttons
      var n = 1;
      var list = [ _listActions, _listKeyActions ];
      for (l in list)
        for (action in l)
          addActionButton(n++, action.key);
      _actionsBack.addChild(_actions);
*/
    }

/*
// add player action button
  function addActionButton(n: Int, key: Null<Int>)
    {
      // button highlight
      var backOver = new Graphics(_actionsBack);
      backOver.y = (n - 1) * game.scene.font.lineHeight;
      backOver.clear();
      backOver.beginFill(0x777777, 0.75);
      backOver.drawRect(0, 0, _actions.textWidth,
        game.scene.font.lineHeight);
      backOver.endFill();
      backOver.visible = false;

      // button
      var btn = new Interactive(_actions.textWidth,
        game.scene.font.lineHeight, _actionsBack);
      btn.y = (n - 1) * game.scene.font.lineHeight;
      btn.cursor = game.scene.mouse.atlas[Mouse.CURSOR_ARROW];
      btn.onOver = function (e: Event)
        { backOver.visible = true; }
      btn.onOut = function (e: Event)
        { backOver.visible = false; }

      _actionButtons.add({
        back: backOver,
        btn: btn,
      });
    }*/

// call numbered action by index
  public function action(index: Int)
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

      if (game.location == LOCATION_AREA)
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
}

