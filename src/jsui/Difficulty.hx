// difficulty selection window

package jsui;

import js.Browser;
import js.html.DivElement;

import game.Game;

class Difficulty extends UIWindow
{
  var text: DivElement;
  var func: Bool -> Void;
  var currentChoice: _Choice;
  var defaultText: String;

  public function new(g: Game)
    {
      super(g, 'window-difficulty');
      window.className += ' window-dialog';
      window.style.borderImage = "url('./img/window-difficulty.png') 100 fill / 1 / 0 stretch";

      text = Browser.document.createDivElement();
      text.className = 'window-dialog-text';
      window.appendChild(text);

      var easy = Browser.document.createDivElement();
      easy.className = 'hud-button window-dialog-button';
      easy.id = 'window-difficulty-easy';
      easy.innerHTML = 'EASY';
      easy.style.borderImage = "url('./img/window-dialog-button.png') 14 fill / 1 / 0 stretch";
      easy.onclick = function (e) {
        action(1);
      }
      easy.onmouseover = function (e) {
        text.innerHTML = currentChoice.notes[0];
      }
      easy.onmouseout = function (e) {
        text.innerHTML = defaultText;
      }
      window.appendChild(easy);

      var normal = Browser.document.createDivElement();
      normal.className = 'hud-button window-dialog-button';
      normal.id = 'window-difficulty-normal';
      normal.innerHTML = 'NORMAL';
      normal.style.borderImage = "url('./img/window-dialog-button.png') 14 fill / 1 / 0 stretch";
      normal.onclick = function (e) {
        action(2);
      }
      normal.onmouseover = function (e) {
        text.innerHTML = currentChoice.notes[1];
      }
      normal.onmouseout = function (e) {
        text.innerHTML = defaultText;
      }
      window.appendChild(normal);

      var hard = Browser.document.createDivElement();
      hard.className = 'hud-button window-dialog-button';
      hard.id = 'window-difficulty-hard';
      hard.innerHTML = 'HARD';
      hard.style.borderImage = "url('./img/window-dialog-button.png') 14 fill / 1 / 0 stretch";
      hard.onclick = function (e) {
        action(3);
      }
      hard.onmouseover = function (e) {
        text.innerHTML = currentChoice.notes[2];
      }
      hard.onmouseout = function (e) {
        text.innerHTML = defaultText;
      }
      window.appendChild(hard);
    }

// set parameters
  public override function setParams(obj: Dynamic)
    {
      var t: String = obj;
      currentChoice = choices[t];
      defaultText =
        '<center><h3>Difficulty: ' + currentChoice.title + '</h3><br>' +
        'Choose difficulty setting.</center>';
      text.innerHTML = defaultText;
    }

// action
  public override function action(index: Int)
    {
      var d: _Difficulty = UNSET;
      if (index == 1)
        d = EASY;
      else if (index == 2)
        d = NORMAL;
      else if (index == 3)
        d = HARD;
      else return;

      // set specific game difficulty setting
      if (currentChoice.id == 'survival')
        game.player.difficulty = d;
      else if (currentChoice.id == 'group')
        game.group.difficulty = d;
      else if (currentChoice.id == 'evolution')
        {
          game.player.evolutionManager.difficulty = d;
          game.player.evolutionManager.giveStartingImprovements();
        }
      else if (currentChoice.id == 'timeline')
        game.timeline.difficulty = d;

      game.log('Difficulty selected for ' + currentChoice.title + ': ' + d);

      game.ui.closeWindow();
    }

  static var choices: Map<String, _Choice> = [
    'survival' => {
      id: 'survival',
      title: 'Survival',
      notes: [
        'Humans call the law slower. You will stop them from doing that when you jump on them.',
        'Fast calling speed. Calls are not interrupted with attaching.',
        'Same calling rules as normal.',
      ]
    },

    'group' => {
      id: 'group',
      title: 'The Group',
      notes: [
        'Shows the exact numerical group priority information and team stats in skills and knowledges window.',
        'Shows group and team information described in vague words.',
        'No group or team information.',
      ]
    },

    'evolution' => {
      id: 'evolution',
      title: 'Evolution',
      notes: [
        'Gives 4 generic improvements. No limits for maximum improvement level.',
        'Gives 2 generic improvements. Maximum improvement level is 2, except for brain probe.',
        'Gives 1 generic improvement. Maximum improvement level is 1, except for brain probe.',
      ]
    },

    'timeline' => {
      id: 'timeline',
      title: 'Timeline',
      notes: [
        '1-3 clues on each learn attempt. Fast computer research.',
        '1-2 clues on each learn attempt. Normal computer research.',
        '1 clue on each learn attempt. Normal computer research.',
      ]
    },
  ];
}

typedef _Choice = {
  var id: String;
  var title: String;
  var notes: Array<String>;
}
