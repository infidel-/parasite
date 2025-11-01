// occasio choice window

package jsui;

import js.Browser;
import js.html.DivElement;
import js.html.ImageElement;
import StringTools;

import game.Game;

class Choice extends UIWindow
{
  var header: DivElement;
  var text: DivElement;
  var image: ImageElement;
  var note: DivElement;
  var params: _ChoiceParams;
  var defaultText: String;
  var buttons: Array<DivElement>;

  public function new(g: Game)
    {
      super(g, 'window-choice');
      window.className += ' window-dialog';
      window.style.borderImage = "url('./img/window-difficulty.png') 100 fill / 1 / 0 stretch";

      var outer = Browser.document.createSpanElement();
      window.appendChild(outer);

      header = Browser.document.createDivElement();
      header.className = 'window-dialog-text';
      outer.appendChild(header);

      image = Browser.document.createImageElement();
      image.className = 'message-img';
      image.style.marginTop = '0.5em';
      outer.appendChild(image);

      text = Browser.document.createDivElement();
      text.className = 'window-dialog-text';
      text.style.marginTop = '1em';
      text.style.minHeight = '4em';
      outer.appendChild(text);

      note = Browser.document.createDivElement();
      note.className = 'window-choice-notes small gray';
      note.style.minHeight = '4em';
      note.style.display = 'block';
      outer.appendChild(note);

      buttons = [];
      for (i in 0...3)
        {
          var idx = i;
          var btn = Browser.document.createDivElement();
          btn.className = 'hud-button window-dialog-button window-choice-' + (i + 1);
          btn.style.borderImage = "url('./img/window-dialog-button.png') 14 fill / 1 / 0 stretch";
          btn.onclick = function (_) {
            game.scene.sounds.play('click-menu');
            action(idx + 1);
          }
          btn.onmouseover = function (_) {
            showChoiceNote(idx);
          }
          btn.onmouseout = function (_) {
            hideChoiceNotes();
          }
          window.appendChild(btn);
          buttons.push(btn);
        }
      hideChoiceNotes();
    }

  function hideChoiceNotes()
    {
      note.innerHTML = '&nbsp;';
    }

  function showChoiceNote(index: Int)
    {
      if (params == null ||
          params.choices == null ||
          index < 0 ||
          index >= params.choices.length)
        return;

      note.innerHTML = params.choices[index];
    }

// set parameters
  public override function setParams(obj: Dynamic)
    {
      var newParams: _ChoiceParams = cast obj;
      params = newParams;
      if (params == null)
        return;

      header.innerHTML = '<center><h3>' + params.title + '</h3></center>';

      if (params.img != null && params.img != '')
        {
          image.src = params.img;
          image.style.display = 'block';
        }
      else
        {
          image.src = '';
          image.removeAttribute('src');
          image.style.display = 'none';
        }

      text.className = 'window-dialog-text';
      if (params.textClass != null &&
          StringTools.trim(params.textClass) != '')
        text.className += ' ' + params.textClass;

      defaultText = (params.text != null) ? params.text : '';
      text.innerHTML = defaultText;

      var buttonCount = params.buttons != null ? params.buttons.length : 0;
      for (i in 0...buttons.length)
        {
          var btn = buttons[i];
          if (i < buttonCount)
            {
              btn.style.display = 'block';
              btn.innerHTML = params.buttons[i];
            }
          else
            {
              btn.style.display = 'none';
              btn.innerHTML = '';
            }
        }

      hideChoiceNotes();
    }

// action
  public override function action(index: Int)
    {
      if (params == null ||
          params.f == null ||
          index < 0 ||
          params.buttons == null ||
          index >= params.buttons.length)
        {
          return;
        }
      params.f(params.src, index);
      game.ui.closeWindow();
    }
}

typedef _ChoiceParams = {
  @:optional var img: String;
  var title: String;
  var text: String;
  @:optional var choices: Array<String>;
  var buttons: Array<String>;
  var src: Dynamic;
  var f: Dynamic -> Int -> Void;
  @:optional var textClass: String;
}
