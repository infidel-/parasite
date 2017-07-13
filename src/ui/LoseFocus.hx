// blur on top of everything when UI loses focus

package ui;

import openfl.Assets;
import com.haxepunk.HXP;
import flash.display.Sprite;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.text.TextFieldAutoSize;


class LoseFocus
{
  var _textField: TextField; // text field
  var _back: Sprite; // window background

  public function new()
    {
      var font = Assets.getFont(Const.FONT);
      _textField = new TextField();
      _textField.wordWrap = true;
      _textField.width = HXP.width;
      _textField.height = HXP.height;
      var textFormat = new TextFormat(font.fontName, 30, 0xFFFFFF);
      textFormat.align = TextFormatAlign.CENTER;
      _textField.defaultTextFormat = textFormat;
      _textField.htmlText = '<center>LOST WINDOW FOCUS</center>';
      _textField.y = HXP.height / 2;
      _back = new Sprite();
      _back.addChild(_textField);
      _back.x = 0;
      _back.y = 0;
      _back.width = HXP.width;
      _back.height = HXP.height;
      _back.graphics.clear();
      _back.graphics.beginFill(0x202020, .95);
      _back.graphics.drawRect(0, 0, _textField.width, _textField.height);
      _back.visible = false;
      HXP.stage.addChild(_back);
    }


// update and show window
  public function show()
    {
      _back.visible = true;
    }


// hide this window
  public function hide()
    {
      _back.visible = false;
    }
}
