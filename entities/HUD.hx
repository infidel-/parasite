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
  var game: Game; // game state

  var _actionList: TextField; // actions list
  var _actionListBack: Sprite; // actions list background


  public function new(g: Game)
    {
      game = g;

      // actions list
      var font = Assets.getFont("font/04B_03__.ttf");
      _actionList = new TextField();
      _actionList.autoSize = TextFieldAutoSize.LEFT;
      var fmt = new TextFormat(font.fontName, 16, 0xFFFFFF);
      fmt.align = TextFormatAlign.LEFT;
      _actionList.defaultTextFormat = fmt;
      _actionListBack = new Sprite();
      _actionListBack.addChild(_actionList);
      _actionListBack.x = 20;
      _actionListBack.y = 20;
      HXP.stage.addChild(_actionListBack);
    }


// update actions list
  function updateActionList()
    {
      var buf = new StringBuf();

      // player intent
      buf.add('Turn: ' + game.turns + '\n');
      buf.add('Actions: ' + game.player.ap + '\n');

      if (game.player.state == Player.STATE_PARASITE)
        buf.add('Turns to live (no host): ' + game.player.parasiteNoHostTimer + '\n');

      else if (game.player.state == Player.STATE_ATTACHED)
        buf.add('Hold: ' + game.player.attachHold + '\n');
        
      else if (game.player.state == Player.STATE_HOST)
        {
          buf.add('Control: ' + game.player.hostControl + '\n');
          buf.add('Turns until host expiry: ' + game.player.hostTimer + '\n');
        }

      buf.add('Intent: ');
      var action = Const.getAction(game.player.intent); 
      buf.add(action.name);
//      if (action.ap > 0)
//        buf.add(' (' + action.ap + ' AP)');
      buf.add("\n\n");

      // player actions
      var n = 1;
      var list = game.player.actionList;
      for (id in list)
        {
/*        
          if (a == selectedAction)
            buf.add('* ');
          else buf.add('  ');
*/

          var action = Const.getAction(id); 
          buf.add(n + ': ');
          buf.add(action.name);
//          buf.add(' (' + action.ap + ' AP)');
          if (id != list.last())
            buf.add("\n");
          n++;
        }

      if (list.length == 0)
        buf.add('No available actions.');

      _actionList.text = buf.toString();
      _actionListBack.graphics.clear();
      _actionListBack.graphics.beginFill(0x202020, .75);
      _actionListBack.graphics.drawRect(0, 0, _actionList.width, _actionList.height);

      _actionListBack.x = 20;
      _actionListBack.y = HXP.windowHeight - _actionList.height - 20;
    }


  static var cnt = 0;
  public function test()
    {
      var oldtext = _actionList.text;
      var buf = new StringBuf();
      buf.add('Intent: Do Nothing\n\n');
      buf.add('1: Access Host Memory (5 AP)\n');
      buf.add('2: Leave Host (5 AP)\n');
      trace(cnt);
      cnt++;
      _actionList.text = 'random string ' + cnt; //buf.toString();
      _actionList.width += 20;
      if (cnt % 2 == 0)
        HXP.stage.removeChild(_actionListBack);
      else HXP.stage.addChild(_actionListBack);
    }


// update HUD state from game state
  public function update()
    {
      updateActionList();
    }
}
