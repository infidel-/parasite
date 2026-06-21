// occasio choice window (psychedelic-pink occasion picker)

package ui;

import js.Browser;
import js.html.DivElement;
import js.html.ImageElement;
import mods.AssetPath;
import StringTools;

import game.Game;

class Choice extends UIWindow
{
  var card: DivElement;
  var hero: DivElement;
  var image: ImageElement;
  var titleEl: DivElement;
  var text: DivElement;
  var note: DivElement;
  var buttonsEl: DivElement;
  var params: _ChoiceParams;
  var defaultText: String;
  var buttons: Array<DivElement>;

  public function new(g: Game)
    {
      super(g, 'window-choice');
      window.className += ' window-dialog choice-win';

      // slick glass card holding the whole occasio
      card = Browser.document.createDivElement();
      card.className = 'choice-card';
      window.appendChild(card);

      // hero: filtered image + scrim + overlaid title
      hero = Browser.document.createDivElement();
      hero.className = 'choice-hero';
      image = Browser.document.createImageElement();
      image.className = 'choice-img';
      hero.appendChild(image);
      var grad = Browser.document.createDivElement();
      grad.className = 'choice-hero-grad';
      hero.appendChild(grad);
      titleEl = Browser.document.createDivElement();
      titleEl.className = 'choice-title';
      hero.appendChild(titleEl);
      card.appendChild(hero);

      // body: prose + choice rows + hover note
      var body = Browser.document.createDivElement();
      body.className = 'choice-body';
      card.appendChild(body);

      text = Browser.document.createDivElement();
      text.className = 'choice-text';
      body.appendChild(text);

      buttonsEl = Browser.document.createDivElement();
      buttonsEl.className = 'choice-buttons';
      body.appendChild(buttonsEl);

      note = Browser.document.createDivElement();
      note.className = 'choice-note';
      body.appendChild(note);

      buttons = [];
      for (i in 0...3)
        {
          var idx = i;
          var btn = Browser.document.createDivElement();
          btn.className = 'choice-btn';
          btn.style.setProperty('--i', '' + i);
          btn.onclick = function (_) {
            game.scene.sounds.play('click-menu');
            action(idx + 1);
          }
          btn.onmouseover = function (_) {
            game.scene.sounds.play('click-action');
            showChoiceNote(idx);
          }
          btn.onmouseout = function (_) {
            hideChoiceNotes();
          }
          buttonsEl.appendChild(btn);
          buttons.push(btn);
        }
      hideChoiceNotes();
    }

// reset the note row to its empty placeholder
  function hideChoiceNotes()
    {
      note.innerHTML = '&nbsp;';
      note.classList.remove('on');
    }

// show the hovered choice's outcome hint
  function showChoiceNote(index: Int)
    {
      if (params == null ||
          params.choices == null ||
          index < 0 ||
          index >= params.choices.length)
        return;

      note.innerHTML = params.choices[index];
      note.classList.add('on');
    }

// set parameters
  public override function setParams(obj: Dynamic)
    {
      var newParams: _ChoiceParams = cast obj;
      params = newParams;
      if (params == null)
        return;

      titleEl.innerHTML = params.title;

      if (params.img != null && params.img != '')
        {
          image.src = AssetPath.resolve(params.img);
          hero.style.display = 'block';
        }
      else
        {
          image.src = '';
          image.removeAttribute('src');
          hero.style.display = 'none';
        }

      text.className = 'choice-text';
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
              btn.style.display = 'flex';
              btn.innerHTML =
                '<span class="choice-key">' + (i + 1) + '</span>' +
                '<span class="choice-label">' + params.buttons[i] + '</span>';
            }
          else
            {
              btn.style.display = 'none';
              btn.innerHTML = '';
            }
        }

      hideChoiceNotes();
    }

// action (1-3)
  public override function action(id: Int)
    {
      if (params == null ||
          params.f == null ||
          id < 1 ||
          params.buttons == null ||
          id > params.buttons.length)
        {
          return;
        }
      params.f(params.src, id);
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
