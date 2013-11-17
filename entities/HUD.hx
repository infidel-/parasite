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
  var _actionList: List<String>; // list of currently available actions


  public function new(g: Game)
    {
      game = g;
      _actionList = new List<String>();

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
    }


// call action by id
  public function action(index: Int)
    {
      // find action name by index
      var i = 1;
      var actionName = null;
      for (a in _actionList)
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
        _actionList.add(name);
    }


// update player actions list
  public function updateActionList()
    {
      _actionList.clear();

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
          addActionToList('accessMemory');
          addActionToList('leaveHost');
        }
    }


// update HUD window
  function updateWindow()
    {
      var buf = new StringBuf();

      // player intent
      buf.add('Turn: ' + game.turns + '\n');
      buf.add('Actions: ' + game.player.ap + '\n');
      if (game.player.humanSociety > 0)
        buf.add('Knowledge about human society: ' + game.player.humanSociety + '%\n');
      buf.add('===\n');

//      if (game.player.state == Player.STATE_PARASITE)
      buf.add('Chemical A: ' + game.player.chemicals[0] +
        '/' + game.player.maxChemicals[0] + '\n');
      buf.add('Chemical B: ' + game.player.chemicals[1] +
        '/' + game.player.maxChemicals[1] + '\n');
      buf.add('Chemical C: ' + game.player.chemicals[2] +
        '/' + game.player.maxChemicals[2] + '\n');
      buf.add('Energy: ' + game.player.energy +
        '/' + game.player.maxEnergy + '\n');
      buf.add('===\n');

      if (game.player.state == Player.STATE_ATTACHED)
        buf.add('Hold: ' + game.player.attachHold + ' / 100\n');
        
      else if (game.player.state == Player.STATE_HOST)
        {
          buf.add('Health: ' + game.player.host.health + '\n');
          buf.add('Control: ' + game.player.hostControl + '/100\n');
          buf.add('Life expectancy: ' + game.player.hostTimer + '\n');
        }

      buf.add('Intent: ');
      var action = Const.getAction(game.player.intent); 
      buf.add(action.name);
      buf.add("\n===\n\n");

      // player actions
      var n = 1;
      for (id in _actionList)
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
          if (id != _actionList.last())
            buf.add("\n");
          n++;
        }

      if (_actionList.length == 0)
        buf.add('No available actions.');

      buf.add("\n===\n");
      if (game.player.state == Player.STATE_HOST)
        buf.add('\nF1: Controlled evolution\n');

      _textField.text = buf.toString();
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


// update HUD state from game state
  public function update()
    {
      updateActionList();
      updateWindow();
    }
}
