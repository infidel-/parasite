// difficulty setting window

package ui;

import com.haxepunk.HXP;
import haxe.ui.components.Label;
import haxe.ui.components.Button;
import haxe.ui.core.Component;
import haxe.ui.core.Screen;
import haxe.ui.core.MouseEvent;
import haxe.ui.macros.ComponentMacros;
import game.Game;

class Difficulty extends UIWindow
{
  var title: Label;
  var text: Label;
  var currentChoice: _Choice;

  public function new(g: Game)
    {
      super(g);
      currentChoice = null;
      window = ComponentMacros.buildComponent("assets/ui/difficulty.xml");
//      var ww = Std.int(HXP.width / 2);
//      var hh = Std.int(HXP.height / 4);
      var w = 1000;
      var h = 300;
      window.width = w;
      window.height = h;
      window.x = Std.int(HXP.halfWidth - w / 2);
      window.y = Std.int(HXP.halfHeight - h / 2);
      HXP.stage.addChild(window);

      title = window.findComponent("title", null, true);
      text = window.findComponent("text", null, true);
      text.getTextInput().selectable = false;
      var button: Button = window.findComponent("easy", null, true);
      button.registerEvent(MouseEvent.MOUSE_OVER, onOver);
      button.registerEvent(MouseEvent.MOUSE_OUT, onOut);
      button.registerEvent(MouseEvent.CLICK, onClick);
      var button: Button = window.findComponent("normal", null, true);
      button.registerEvent(MouseEvent.MOUSE_OVER, onOver);
      button.registerEvent(MouseEvent.MOUSE_OUT, onOut);
      button.registerEvent(MouseEvent.CLICK, onClick);
      var button: Button = window.findComponent("hard", null, true);
      button.registerEvent(MouseEvent.MOUSE_OVER, onOver);
      button.registerEvent(MouseEvent.MOUSE_OUT, onOut);
      button.registerEvent(MouseEvent.CLICK, onClick);
      window.hide();
    }


// set choices
  public function setChoices(t: String)
    {
      currentChoice = choices[t];
      title.text = 'Difficulty: ' + currentChoice.title;
      text.text = 'Choose difficulty setting.';
    }


// on click
  function onClick(e: MouseEvent)
    {
      var d: _Difficulty = UNSET;
      if (e.target.id == 'easy')
        d = EASY;
      else if (e.target.id == 'normal')
        d = NORMAL;
      else if (e.target.id == 'hard')
        d = HARD;

      // set specific game difficulty setting
      if (currentChoice.id == 'group')
        game.group.difficulty = d;

      game.scene.closeWindow();
    }


// on mouse over
  function onOver(e: MouseEvent)
    {
      text.text = Reflect.field(currentChoice, e.target.id);
    }


// on mouse out
  function onOut(e: MouseEvent)
    {
      text.text = 'Choose difficulty setting.';
    }


  static var choices: Map<String, _Choice> = [
    'group' => {
      id: 'group',
      title: 'The Group',
      easy: 'Shows the exact numerical group priority information and team stats in skills and knowledges window.',
      normal: 'Shows group and team information described in vague words.',
      hard: 'No group or team information.',
    }
    ];
}


typedef _Choice = {
  var id: String;
  var title: String;
  var easy: String;
  var normal: String;
  var hard: String;
}
