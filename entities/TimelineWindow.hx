// event timeline GUI window

package entities;

import openfl.Assets;
import com.haxepunk.HXP;
import flash.display.Sprite;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.text.TextFieldAutoSize;

class TimelineWindow
{
  var game: Game; // game state

  var _textField: TextField; // text field
  var _back: Sprite; // window background
//  var _actionNames: List<String>; // list of currently available actions (names)
//  var _actionIDs: List<String>; // list of currently available actions (string IDs)

  public function new(g: Game)
    {
      game = g;

//      _actionNames = new List<String>();
//      _actionIDs = new List<String>();

      // actions list
      var font = Assets.getFont("font/04B_03__.ttf");
      _textField = new TextField();
      _textField.wordWrap = true;
//      _textField.autoSize = TextFieldAutoSize.LEFT;
      _textField.width = HXP.width;
      _textField.height = HXP.height;
      var fmt = new TextFormat(font.fontName, 16, 0xFFFFFF);
      fmt.align = TextFormatAlign.LEFT;
      _textField.defaultTextFormat = fmt;
      _back = new Sprite();
      _back.addChild(_textField);
      _back.x = 0;
      _back.y = 0;
      _back.width = HXP.width;
      _back.height = HXP.height;
      HXP.stage.addChild(_back);
    }

/*
// call action by id
  public function action(index: Int)
    {
      game.debug.action(index - 1);
      update(); // update display
      game.scene.hud.update(); // update HUD
    }
*/


// scroll window up/down
  public function scroll(n: Int)
    {
      _textField.scrollV += n;
    }


// scroll window to beginning
  public function scrollToBegin()
    {
      _textField.scrollV = 0;
    }


// scroll window to end 
  public function scrollToEnd()
    {
      _textField.scrollV = _textField.maxScrollV;
    }


// update and show window
  public function show()
    {
      update();
      _back.visible = true;
    }


// hide this window
  public function hide()
    {
      _back.visible = false;
    }


// update window text
  function update()
    {
      var buf = new StringBuf();

      buf.add('Event timeline\n===\n\n');

      for (event in game.timeline)
        {
          if (event.isHidden)
            continue;

          // first line
          buf.add('Event ' + event.num);
          if (event.location != null)
            {
              buf.add(': ');
              if (event.location.hasName)
                buf.add(event.location.name + ' ');
              buf.add('at (' + event.location.area.x + ',' + event.location.area.y + ')');
            }
          buf.add('\n');
        
          // event notes
          for (n in event.notes)
            if (n.isKnown)
              buf.add(' + ' + n.text + '\n');
            else buf.add(' - ? [' + n.clues + '/4]\n');

          // event participants
          buf.add('Participants:\n');
          for (npc in event.npc)
            {
              buf.add(' + ');
              buf.add(npc.name + ' ');
              buf.add('(' + npc.job + ') ');
              buf.add('at (' + npc.area.x + ',' + npc.area.y + ') ');
              buf.add('[photo] ');
              buf.add('[deceased]');
              buf.add('\n');
            }
        
          buf.add('\n');
        }

      _textField.htmlText = buf.toString();
      _textField.width = HXP.width;
      _textField.height = HXP.height;
      _back.graphics.clear();
      _back.graphics.beginFill(0x202020, .95);
      _back.graphics.drawRect(0, 0, _textField.width, _textField.height);
    }
}
