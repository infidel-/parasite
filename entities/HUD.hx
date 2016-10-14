// ingame HUD

package entities;

import openfl.Assets;
import com.haxepunk.HXP;
import com.haxepunk.Entity;
import com.haxepunk.graphics.Graphiclist;
import com.haxepunk.graphics.Text;
import flash.display.Sprite;
import flash.text.TextField;
import flash.text.TextFieldType;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.text.TextFieldAutoSize;

import game.Game;

class HUD
{
  var game: Game; // game state link

  var _textField: TextField; // actions list
  var _textFieldBack: Sprite; // actions list background
  var _listActions: List<_PlayerAction>; // list of currently available actions

  var _log: TextField; // last log lines
  var _logBack: Sprite; // log background
  var _listLog: List<String>; // log lines (last 4)

  var _console: TextField; // console
  var _consoleBack: Sprite; // console background

  var _help: TextField; // help
  var _helpBack: Sprite; // help background

  public function new(g: Game)
    {
      game = g;
      _listActions = new List<_PlayerAction>();
      _listLog = new List<String>();

      // actions list
      var font = Assets.getFont("font/04B_03__.ttf");
      _textField = new TextField();
      _textField.autoSize = TextFieldAutoSize.LEFT;
      var fmt = new TextFormat(font.fontName, 16, 0xFFFFFF);
      fmt.align = TextFormatAlign.LEFT;
      _textField.defaultTextFormat = fmt;
      _textFieldBack = new Sprite();
      _textFieldBack.addChild(_textField);
      _textFieldBack.x = 20;
      _textFieldBack.y = 20;
      HXP.stage.addChild(_textFieldBack);

      // log lines
      var font = Assets.getFont("font/04B_03__.ttf");
      _log = new TextField();
      _log.width = HXP.width - 40;
      _log.wordWrap = true;
      _log.autoSize = TextFieldAutoSize.LEFT;
      var fmt = new TextFormat(font.fontName, 16, 0xFFFFFF);
      fmt.align = TextFormatAlign.LEFT;
      _log.defaultTextFormat = fmt;
      _logBack = new Sprite();
      _logBack.addChild(_log);
      _logBack.x = 20;
      _logBack.y = 20;
      HXP.stage.addChild(_logBack);

      // console
      var font = Assets.getFont("font/04B_03__.ttf");
      _console = new TextField();
      var fmt = new TextFormat(font.fontName, 16, 0xFFFFFF);
      fmt.align = TextFormatAlign.LEFT;
      _console.defaultTextFormat = fmt;
      _console.type = TextFieldType.INPUT;
      _consoleBack = new Sprite();
      _consoleBack.addChild(_console);
      _consoleBack.x = 20;
      _consoleBack.y = 0;
      _consoleBack.visible = false;
      _console.width = HXP.width - 40;
      _console.height = 20;
      HXP.stage.addChild(_consoleBack);

      // help
      var font = Assets.getFont("font/04B_03__.ttf");
      _help = new TextField();
      var fmt = new TextFormat(font.fontName, 16, 0xFFFFFF);
      fmt.align = TextFormatAlign.LEFT;
      _help.defaultTextFormat = fmt;
      _help.type = TextFieldType.INPUT;
      _helpBack = new Sprite();
      _helpBack.addChild(_help);
      _helpBack.x = 20;
      _helpBack.y = HXP.height - 20;
      _help.width = HXP.width - 40;
      _help.height = 20;
      HXP.stage.addChild(_helpBack);
    }


// add line to a log and remove first one
  public function log(s: String)
    {
      _listLog.add(s);
      if (_listLog.length > 4)
        _listLog.pop();

      updateLog(); // redraw the log just in case
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
            ', I ' + Math.round(game.area.interest) +
#end
            '\nActions: ' + game.playerArea.ap + '\n');
      else if (game.location == LOCATION_REGION)
        buf.add(
          game.playerRegion.x + ',' + game.playerRegion.y + ')' +
#if mydebug
            ' A ' + Math.round(game.playerRegion.currentArea.alertness) +
            ', I ' + Math.round(game.playerRegion.currentArea.interest) +
#end
          '\n' + game.playerRegion.currentArea.name + '\n');
      buf.add('===\n');

      var colEnergy = getTextColor(game.player.energy, game.player.maxEnergy);
      buf.add('Energy: ' +
        "<font color='" + colEnergy + "'>" + game.player.energy + "</font>" +
        '/' + game.player.maxEnergy + '\n');
      var colHealth = getTextColor(game.player.health, game.player.maxHealth);
      buf.add('Health: ' +
        "<font color='" + colHealth + "'>" + game.player.health + "</font>" +
        '/' + game.player.maxHealth + '\n');
      buf.add('===\n');

      if (game.player.state == PLR_STATE_ATTACHED)
        buf.add("Grip: <font color='" +
          getTextColor(game.playerArea.attachHold, 100) + "'>" +
          game.playerArea.attachHold + "</font>/100\n");

      // host stats
      else if (game.player.state == PLR_STATE_HOST)
        {
          buf.add(game.player.host.getNameCapped());
          if (game.player.host.isJobKnown)
            buf.add(' (' + game.player.host.job + ')\n');
          else buf.add('\n');
          if (game.player.host.isAttrsKnown)
            buf.add('STR ' + game.player.host.strength +
              ' CON ' + game.player.host.constitution +
              ' INT ' + game.player.host.intellect +
              ' PSY ' + game.player.host.psyche + '\n');

          var colHealth = getTextColor(game.player.host.health,
            game.player.host.maxHealth);
          buf.add('Health: ' +
            "<font color='" + colHealth + "'>" + game.player.host.health + "</font>" +
            '/' + game.player.host.maxHealth + '\n');

          var colControl = getTextColor(game.player.hostControl, 100);
          buf.add('Control: ' +
            "<font color='" + colControl + "'>" + game.player.hostControl + "</font>" +
            '/100\n');

          var colEnergy = getTextColor(game.player.host.energy,
            game.player.host.maxEnergy);
          buf.add("Energy: <font color='" + colEnergy + "'>" +
            game.player.host.energy + '</font>/' +
            game.player.host.maxEnergy + '\n');
          buf.add('Evolution direction:\n  ');
          buf.add(game.player.evolutionManager.getEvolutionDirectionInfo());
          buf.add('\n');
          var str = game.player.host.organs.getInfo();
          if (str != null)
            buf.add(str);
        }
      buf.add("\n===\n\n");

      // player actions
      var n = 1;
      for (action in _listActions)
        {
          buf.add(n + ': ');
          buf.add(action.name);
          if (action.energy != null && action.energy > 0)
            buf.add(' (' + action.energy + ' energy)');
          else if (action.energyFunc != null)
            buf.add(' (' + action.energyFunc(game.player) + ' energy)');
          if (action != _listActions.last())
            buf.add("\n");
          n++;
        }

      if (_listActions.length == 0)
        buf.add('No available actions.');

      _textField.htmlText = buf.toString();
      _textFieldBack.graphics.clear();
      _textFieldBack.graphics.beginFill(0x202020, .75);
      _textFieldBack.graphics.drawRect(0, 0, _textField.width, _textField.height);

      _textFieldBack.x = 20;
      _textFieldBack.y = HXP.windowHeight - _textField.height - 30;
    }


  static var cnt = 0;
  public function test()
    {
      var oldtext = _textField.text;
      var buf = new StringBuf();
      buf.add('Intent: Do Nothing\n\n');
      buf.add('1: Access Host Memory (5 AP)\n');
      buf.add('2: Leave Host (5 AP)\n');
      trace(cnt);
      cnt++;
      _textField.text = 'random string ' + cnt; //buf.toString();
      _textField.width += 20;
      if (cnt % 2 == 0)
        HXP.stage.removeChild(_textFieldBack);
      else HXP.stage.addChild(_textFieldBack);
    }


// update log display
  function updateLog()
    {
      var buf = new StringBuf();
      for (l in _listLog)
        {
          buf.add(l);
          buf.add('\n');
        }

      _log.htmlText = buf.toString();
      _log.width = HXP.width - 40;
      _logBack.graphics.clear();
      _logBack.graphics.beginFill(0x202020, .75);
      _logBack.graphics.drawRect(0, 0, _log.width, _log.height);
    }


  function updateHelp()
    {
      var buf = new StringBuf();

      buf.add('F1: Goals  ');
      if (game.player.state == PLR_STATE_HOST)
        {
          if (game.player.vars.inventoryEnabled)
            buf.add('F2: Inventory  ');
        }
      if (game.player.vars.skillsEnabled)
        buf.add('F3: Knowledge  ');
      buf.add('F4: Log  ');

      if (game.player.vars.timelineEnabled)
        buf.add('F5: Timeline  ');

      if (game.player.state == PLR_STATE_HOST)
        {
          if (game.player.evolutionManager.state > 0)
            buf.add('F6: Evolution  ');
          if (game.player.vars.organsEnabled)
            buf.add('F7: Body features  ');
        }

#if mydebug
      buf.add('F9: Debug  ');
#end
      buf.add('F10: Exit');

      _help.htmlText = buf.toString();
      _helpBack.graphics.clear();
      _helpBack.graphics.beginFill(0x202020, .75);
      _helpBack.graphics.drawRect(0, 0, _help.width, _help.height);
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
#if mydebug
      _console.text = '';
      _consoleBack.visible = true;
      HXP.stage.focus = _console;
#end
    }


// hide debug console
  public function hideConsole()
    {
#if mydebug
      _consoleBack.visible = false;
#end
    }


// is console visible?
  public inline function consoleVisible(): Bool
    {
      return _consoleBack.visible;
    }


// run console command and close it
  public inline function runConsoleCommand()
    {
#if mydebug
      game.console.run(_console.text);
      hideConsole();
#end
    }


// update console text
  public function updateConsole()
    {
      _consoleBack.graphics.clear();
      _consoleBack.graphics.beginFill(0x202020, .75);
      _consoleBack.graphics.drawRect(0, 0, _console.width, _console.height);
    }


// show hide HUD
  public inline function show(state: Bool)
    {
      _textFieldBack.visible = state;
      _logBack.visible = state;
      _helpBack.visible = state;
    }
}
