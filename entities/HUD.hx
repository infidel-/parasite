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
  var _listActions: List<String>; // list of currently available actions

  var _log: TextField; // last log lines 
  var _logBack: Sprite; // log background
  var _listLog: List<String>; // log lines (last 4)


  public function new(g: Game)
    {
      game = g;
      _listActions = new List<String>();
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
    }
  

// call action by id
  public function action(index: Int)
    {
      // find action name by index
      var i = 1;
      var actionName = null;
      for (a in _listActions)
        if (i++ == index)
          {
            actionName = a;
            break;
          }
      if (actionName == null)
        return;

      game.player.action(actionName);
    }


// helper: add action to list and check for energy
  inline function addActionToList(name: String)
    {
      var action = Const.getAction(name);
      if (action.energy <= game.player.energy)
        _listActions.add(name);
    }


// update player actions list
  public function updateActionList()
    {
      _listActions.clear();

      // parasite is attached to host
      if (game.player.state == Player.STATE_ATTACHED)
        {
          addActionToList('hardenGrip');
          if (game.player.attachHold >= 90)
            addActionToList('invadeHost');
        }

      // parasite in control of host
      else if (game.player.state == Player.STATE_HOST)
        {
          addActionToList('reinforceControl');
          if (game.player.evolutionManager.getLevel('hostMemory') > 0)
            addActionToList('accessMemory');
          addActionToList('leaveHost');
        }

      // area object actions
      var o = game.area.getObjectAt(game.player.x, game.player.y);
      if (o == null)
        return;

      if (game.player.state != Player.STATE_ATTACHED && o.type == 'sewer_hatch')
        addActionToList('enterSewers');
    }


// update HUD window
  function updateWindow()
    {
      var buf = new StringBuf();

      // player intent
      buf.add('Turn: ' + game.turns + '\n');
      buf.add('Actions: ' + game.player.ap + '\n');
      buf.add('===\n');

/*
//      if (game.player.state == Player.STATE_PARASITE)
      buf.add('Chemical A: ' + game.player.chemicals[0] +
        '/' + game.player.maxChemicals[0] + '\n');
      buf.add('Chemical B: ' + game.player.chemicals[1] +
        '/' + game.player.maxChemicals[1] + '\n');
      buf.add('Chemical C: ' + game.player.chemicals[2] +
        '/' + game.player.maxChemicals[2] + '\n');
*/        
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

      if (game.player.state == Player.STATE_ATTACHED)
        buf.add('Hold: ' + game.player.attachHold + ' / 100\n');

      // host stats
      else if (game.player.state == Player.STATE_HOST)
        {
          buf.add(game.player.host.getNameCapped() + '\n');
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
          buf.add('Life expectancy: ' + game.player.hostTimer + '\n');
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
      for (id in _listActions)
        {
/*        
          if (a == selectedAction)
            buf.add('* ');
          else buf.add('  ');
*/

          var action = Const.getAction(id); 
          buf.add(n + ': ');
          buf.add(action.name);
          if (action.energy > 0)
            buf.add(' (' + action.energy + ' energy)');
//          buf.add(' (' + action.ap + ' AP)');
          if (id != _listActions.last())
            buf.add("\n");
          n++;
        }

      if (_listActions.length == 0)
        buf.add('No available actions.');

      buf.add("\n===\n");
      if (game.player.state == Player.STATE_HOST)
        {
          buf.add('\nF1: Inventory\n');
          buf.add('F2: Skills and knowledge\n');
          buf.add('F3: Controlled evolution\n');
          buf.add('F4: Body features\n');
        }

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
