// ingame HUD

package ui;

import h2d.Bitmap;
import h2d.Graphics;
import h2d.Object;
import h2d.HtmlText;
import h2d.TextInput;
import hxd.Key;

import game.Game;

class HUD
{
  var game: Game; // game state link

  var _listActions: List<_PlayerAction>; // list of currently available actions
  var _container: Object;
  var _text: HtmlText; // actions list
  var _textBack: Graphics; // actions list background
  var _log: HtmlText; // last log lines
  var _logBack: Graphics; // log background
  var _console: TextInput; // console
  var _consoleBack: Graphics; // console background
  var _help: h2d.Text; // help
  var _helpBack: Graphics; // help background

  public function new(g: Game)
    {
      game = g;
      _listActions = new List<_PlayerAction>();
      _container = new Object();
      game.scene.add(_container, Const.LAYER_HUD);

      _consoleBack = new Graphics(_container);
      _console = new TextInput(game.scene.font, _consoleBack);
      _console.maxWidth = game.scene.win.width - 40;
      _console.textAlign = Left;
      _console.onKeyDown = handleConsoleInput;
      _consoleBack.x = 20;
      _consoleBack.y = 0;
      _consoleBack.visible = false;

      // log lines
      _logBack = new Graphics(_container);
      _log = new HtmlText(game.scene.font, _logBack);
      _log.maxWidth = game.scene.win.width - 40;
      _log.textAlign = Left;
      _logBack.x = 20;
      _logBack.y = game.config.fontSize + 10;

      // actions list
      _textBack = new Graphics(_container);
      _text = new HtmlText(game.scene.font, _textBack);
      _text.textAlign = Left;
      _textBack.x = 20;

      // help
      _helpBack = new Graphics(_container);
      _help = new h2d.Text(game.scene.font, _helpBack);
      _help.maxWidth = game.scene.win.width - 40;
      _help.textAlign = Left;
      _helpBack.x = 20;
      _helpBack.y = game.scene.win.height - game.config.fontSize - 8;

      @:privateAccess game.scene.window.addEventTarget(onEvent);
    }


// show console
  function onEvent(e: hxd.Event)
    {
      if (e.kind != ETextInput)
        return;

      if (!_consoleBack.visible && _container.visible &&
          e.charCode == 59) // ;
        {
          showConsole();
          return;
        }

      if (!consoleVisible())
        return;

      _console.text += String.fromCharCode(e.charCode);
    }


// handle misc console keys
  function handleConsoleInput(e: hxd.Event)
    {
      if (!consoleVisible())
        return;

      if (e.keyCode == Key.ENTER)
        runConsoleCommand();
      else if (e.keyCode == Key.ESCAPE)
        hideConsole();
      else if (e.keyCode == Key.BACKSPACE)
        _console.text = _console.text.substr(0, -1);
    }


// call action by id
  public function action(index: Int)
    {
      // find action name by index
      var i = 1;
      var action = null;
      for (a in _listActions)
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


// update player actions list
  inline function updateActionList()
    {
      if (game.isFinished)
        return;

      if (game.location == LOCATION_AREA)
        _listActions = game.playerArea.getActionList();

      else if (game.location == LOCATION_REGION)
        _listActions = game.playerRegion.getActionList();
    }


// get color for text (red, yellow, white)
  function getTextColor(val: Float, max: Float)
    {
      if (val > 0.7 * max)
        return '#FFFFFF';
      else if (val > 0.3 * max)
        return '#FFFF00';

      return '#FF0000';
    }


// update HUD window
  function updateWindow()
    {
      var buf = new StringBuf();

      buf.add('Turn: ' + game.turns + ', at (');
      if (game.location == LOCATION_AREA)
          buf.add(
            game.playerArea.x + ',' + game.playerArea.y + ')' +
#if mydebug
            ' A ' + Math.round(game.area.alertness) +
#end
            '<br>Actions: ' + game.playerArea.ap + '<br>');
      else if (game.location == LOCATION_REGION)
        buf.add(
          game.playerRegion.x + ',' + game.playerRegion.y + ')' +
#if mydebug
            ' A ' + Math.round(game.playerRegion.currentArea.alertness) +
#end
          '<br>' + game.playerRegion.currentArea.name + '<br>');
      buf.add('===<br>');

      var colEnergy = getTextColor(game.player.energy, game.player.maxEnergy);
      var time = (game.location == LOCATION_AREA ? 1 : 5);
      var energyPerTurn = __Math.parasiteEnergyPerTurn(time);
      buf.add('Energy: ' +
        "<font color='" + colEnergy + "'>" + game.player.energy + "</font>" +
        '/' + game.player.maxEnergy);
      buf.add(' [' + (energyPerTurn > 0 ? '+' : '') + energyPerTurn + '/t]<br>');
      var colHealth = getTextColor(game.player.health, game.player.maxHealth);
      buf.add('Health: ' +
        "<font color='" + colHealth + "'>" + game.player.health + "</font>" +
        '/' + game.player.maxHealth + '<br>');
      buf.add('===<br>');

      if (game.player.state == PLR_STATE_ATTACHED)
        buf.add("Grip: <font color='" +
          getTextColor(game.playerArea.attachHold, 100) + "'>" +
          game.playerArea.attachHold + "</font>/100<br>");

      // host stats
      else if (game.player.state == PLR_STATE_HOST)
        {
          buf.add(game.player.host.getNameCapped());
          if (game.player.host.isJobKnown)
            buf.add(' (' + game.player.host.job + ')<br>');
          else buf.add('<br>');
          if (game.player.host.isAttrsKnown)
            buf.add('STR ' + game.player.host.strength +
              ' CON ' + game.player.host.constitution +
              ' INT ' + game.player.host.intellect +
              ' PSY ' + game.player.host.psyche + '<br>');

          var colHealth = getTextColor(game.player.host.health,
            game.player.host.maxHealth);
          buf.add('Health: ' +
            "<font color='" + colHealth + "'>" + game.player.host.health + "</font>" +
            '/' + game.player.host.maxHealth + '<br>');

          var colControl = getTextColor(game.player.hostControl, 100);
          buf.add('Control: ' +
            "<font color='" + colControl + "'>" + game.player.hostControl + "</font>" +
            '/100<br>');

          var colEnergy = getTextColor(game.player.host.energy,
            game.player.host.maxEnergy);
          var energyPerTurn = __Math.fullHostEnergyPerTurn(time);
          buf.add("Energy: <font color='" + colEnergy + "'>" +
            game.player.host.energy + '</font>/' +
            game.player.host.maxEnergy);
          buf.add(' [' + (energyPerTurn > 0 ? '+' : '') +
            energyPerTurn + '/t]<br>');
          buf.add('Evolution direction:<br>  ');
          buf.add(game.player.evolutionManager.getEvolutionDirectionInfo());
          buf.add('<br>');
          var str = game.player.host.organs.getInfo();
          if (str != null)
            buf.add(str);
        }
      buf.add("<br>===<br><br>");

      // player actions
      var n = 1;
      if (!game.isFinished)
        for (action in _listActions)
          {
            buf.add(n + ': ');
            buf.add(action.name);
            if (action.energy != null && action.energy > 0)
              buf.add(' (' + action.energy + ' energy)');
            else if (action.energyFunc != null)
              buf.add(' (' + action.energyFunc(game.player) + ' energy)');
            if (action != _listActions.last())
              buf.add("<br>");
            n++;
          }

      if (game.isFinished)
        buf.add('<font color="#FF0000">Press ENTER to restart</font>');
      else if (_listActions.length == 0)
        buf.add('No available actions.');

      _text.text = buf.toString();
      _textBack.clear();
      _textBack.beginFill(0x202020, 0.75);
      _textBack.drawRect(0, 0, _text.textWidth, _text.textHeight);
      _textBack.endFill();
      _textBack.y = game.scene.win.height - _text.textHeight -
        game.config.fontSize - 12;
    }


  static var cnt = 0;
  public function test()
    {}


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

      _log.text = buf.toString();
      _logBack.clear();
      _logBack.beginFill(0x202020, 0.75);
      _logBack.drawRect(0, 0, _log.maxWidth, _log.textHeight);
      _logBack.endFill();
    }


  function updateHelp()
    {
      var buf = new StringBuf();
      var prefix =
#if js
        (game.scene.controlKey == 'alt' ? "A-" : "C-");
#else
        "F";
#end

      buf.add(prefix + '1: Goals  ');
      if (game.player.state == PLR_STATE_HOST)
        {
          if (game.player.vars.inventoryEnabled)
            buf.add(prefix + '2: Inventory  ');
        }
      if (game.player.vars.skillsEnabled)
        buf.add(prefix + '3: Knowledge  ');
      buf.add(prefix + '4: Log  ');

      if (game.player.vars.timelineEnabled)
        buf.add(prefix + '5: Timeline  ');

      if (game.player.state == PLR_STATE_HOST)
        {
          if (game.player.evolutionManager.state > 0)
            buf.add(prefix + '6: Evolution  ');
          if (game.player.vars.organsEnabled)
            buf.add(prefix + '7: Body features  ');
        }

#if mydebug
      buf.add(prefix + '9: Debug  ');
#end
#if !js
      buf.add(prefix + '10: Exit');
#end

      _help.text = buf.toString();
      _helpBack.clear();
      _helpBack.beginFill(0x202020, 0.75);
      _helpBack.drawRect(0, 0, _help.maxWidth, _help.textHeight);
      _helpBack.endFill();
    }


// update HUD state from game state
  public function update()
    {
      updateActionList();
      updateWindow();
      updateLog();
      updateHelp();
      updateConsole();
    }


// show debug console
  public function showConsole()
    {
      _console.text = '';
      _consoleBack.visible = true;
      _console.focus();
    }


// hide debug console
  public function hideConsole()
    {
      _consoleBack.visible = false;
    }


// is console visible?
  public inline function consoleVisible(): Bool
    {
      return _consoleBack.visible;
    }


// run console command and close it
  public inline function runConsoleCommand()
    {
      game.console.run(_console.text);
      hideConsole();
    }


// update console text
  function updateConsole()
    {
      _consoleBack.clear();
      _consoleBack.beginFill(0x202020, 0.75);
      _consoleBack.drawRect(0, 0, _console.maxWidth, _console.textHeight);
      _consoleBack.endFill();
    }


// show hide HUD
  public inline function toggle()
    {
      _container.visible = !_container.visible;
    }
}
