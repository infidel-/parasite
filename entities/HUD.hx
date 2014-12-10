// ingame HUD

package entities;

import openfl.Assets;
import com.haxepunk.HXP;
import com.haxepunk.Entity;
import com.haxepunk.graphics.Graphiclist;
import com.haxepunk.graphics.Text;
import flash.display.Sprite;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.text.TextFieldAutoSize;

class HUD
{
  var game: Game; // game state link

  var _textField: TextField; // actions list
  var _textFieldBack: Sprite; // actions list background
  var _listActions: List<_PlayerAction>; // list of currently available actions

  var _log: TextField; // last log lines 
  var _logBack: Sprite; // log background
  var _listLog: List<String>; // log lines (last 4)


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
      _log.autoSize = TextFieldAutoSize.LEFT;
      var fmt = new TextFormat(font.fontName, 16, 0xFFFFFF);
      fmt.align = TextFormatAlign.LEFT;
      _log.defaultTextFormat = fmt;
      _logBack = new Sprite();
      _logBack.addChild(_log);
      _logBack.x = 20;
      _logBack.y = 20;
      HXP.stage.addChild(_logBack);
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

      if (game.location == Game.LOCATION_AREA)
        game.area.player.action(action);

      else if (game.location == Game.LOCATION_REGION)
        game.region.player.action(action);
    }


// update player actions list
  inline function updateActionList()
    {
      if (game.location == Game.LOCATION_AREA)
        _listActions = game.area.player.getActionList();

      else if (game.location == Game.LOCATION_REGION)
        _listActions = game.region.player.getActionList();
    }


// update HUD window
  function updateWindow()
    {
      var buf = new StringBuf();

      // player intent
      buf.add('Turn: ' + game.turns + ', at (');
      if (game.location == Game.LOCATION_AREA)
          buf.add(
            game.area.player.x + ',' + game.area.player.y + ')\n' +
            'Actions: ' + game.area.player.ap + '\n');
      else if (game.location == Game.LOCATION_REGION)
        buf.add(
          game.region.player.x + ',' + game.region.player.y + ')\n' +
          game.region.currentArea.info.name + '\n');
      buf.add('===\n');

      var colEnergy = 
        (game.player.energy > 0.3 * game.player.maxEnergy ? '#FFFFFF' : '#FF0000');
      buf.add('Energy: ' + 
        "<font color='" + colEnergy + "'>" + game.player.energy + "</font>" +
        '/' + game.player.maxEnergy + '\n');
      var colHealth = 
        (game.player.health > 0.3 * game.player.maxHealth ? '#FFFFFF' : '#FF0000');
      buf.add('Health: ' + 
        "<font color='" + colHealth + "'>" + game.player.health + "</font>" +
        '/' + game.player.maxHealth + '\n');
      buf.add('===\n');

      if (game.player.state == PLR_STATE_ATTACHED)
        buf.add('Hold: ' + game.area.player.attachHold + '/100\n');

      // host stats
      else if (game.player.state == PLR_STATE_HOST)
        {
          buf.add(game.player.host.getNameCapped());
          if (game.player.host.isJobKnown)
            buf.add(' (' + game.player.host.job + ')\n');
          else buf.add('\n');
          var colHealth = 
            (game.player.host.health > 0.3 * game.player.host.maxHealth ? 
            '#FFFFFF' : '#FF0000');
          buf.add('Health: ' + 
            "<font color='" + colHealth + "'>" + game.player.host.health + "</font>" +
            '/' + game.player.host.maxHealth + '\n');

          var colControl = '#FFFFFF';
          if (game.player.hostControl < 30)
            colControl = '#FF0000';
          else if (game.player.hostControl < 70)
            colControl = '#FFFF00';
          buf.add('Control: ' + 
            "<font color='" + colControl + "'>" + game.player.hostControl + "</font>" +
            '/100\n');

          var colEnergy = 
            (game.player.host.energy > 0.3 * game.player.host.maxEnergy ? 
              '#FFFFFF' : '#FF0000');
          buf.add("Energy: <font color='" + colEnergy + "'>" + game.player.host.energy +
            '</font>/' + game.player.host.maxEnergy + '\n');
          buf.add('Evolution direction: ');
          buf.add(game.player.evolutionManager.getEvolutionDirectionInfo());
          buf.add('\n');
        }
/*
      buf.add('Intent: ');
      var action = Const.getAction(game.player.intent); 
      buf.add(action.name);
*/
      buf.add("\n===\n\n");

      // player actions
      var n = 1;
      for (action in _listActions)
        {
/*        
          if (a == selectedAction)
            buf.add('* ');
          else buf.add('  ');
*/

//          var action = Const.getAction(id); 
          buf.add(n + ': ');
          buf.add(action.name);
          if (action.energy > 0)
            buf.add(' (' + action.energy + ' energy)');
//          buf.add(' (' + action.ap + ' AP)');
          if (action != _listActions.last())
            buf.add("\n");
          n++;
        }

      if (_listActions.length == 0)
        buf.add('No available actions.');

      buf.add("\n===\n");
      if (game.player.state == PLR_STATE_HOST)
        {
          buf.add('\nF1: Inventory\n');
          buf.add('F2: Skills and knowledge\n');
          buf.add('F3: Controlled evolution\n');
          buf.add('F4: Body features\n');
        }

      if (!game.timeline.isLocked)
        buf.add('F5: Event timeline\n');

      _textField.htmlText = buf.toString();
      _textFieldBack.graphics.clear();
      _textFieldBack.graphics.beginFill(0x202020, .75);
      _textFieldBack.graphics.drawRect(0, 0, _textField.width, _textField.height);

      _textFieldBack.x = 20;
      _textFieldBack.y = HXP.windowHeight - _textField.height - 20;
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
      _logBack.graphics.clear();
      _logBack.graphics.beginFill(0x202020, .75);
      _logBack.graphics.drawRect(0, 0, _log.width, _log.height);
    }


// update HUD state from game state
  public function update()
    {
      updateActionList();
      updateWindow();
      updateLog();
    }
}
