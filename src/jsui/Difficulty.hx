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
        game.scene.sounds.play('click-menu');
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
        game.scene.sounds.play('click-menu');
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
        game.scene.sounds.play('click-menu');
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
        {
          game.group.difficulty = d;
        }
      else if (currentChoice.id == 'evolution')
        {
          game.player.evolutionManager.difficulty = d;
          if (game.player.evolutionManager.difficulty == EASY)
            game.player.vars.habitatsLeft = 1000;
          else if (game.player.evolutionManager.difficulty == NORMAL)
            game.player.vars.habitatsLeft = 10;
          else if (game.player.evolutionManager.difficulty == HARD)
            game.player.vars.habitatsLeft = 5;
          game.player.evolutionManager.giveStartingImprovements();
          // SPOON: give all basic imps
          if (game.config.spoonEvolutionBasic)
            game.player.evolutionManager.giveAllBasic();
        }
      else if (currentChoice.id == 'timeline')
        game.timeline.difficulty = d;
      else if (currentChoice.id == 'save')
        {
          game.player.saveDifficulty = d;
          if (game.player.saveDifficulty == EASY)
            game.player.vars.savesLeft = 10;
          else if (game.player.saveDifficulty == NORMAL)
            game.player.vars.savesLeft = 3;
          else if (game.player.saveDifficulty == HARD)
            game.player.vars.savesLeft = 1;
          game.save(1);
        }

      game.system('Difficulty selected for ' + currentChoice.title + ': ' + d);

      game.ui.closeWindow();
    }

  static var choices: Map<String, _Choice> = [
    'survival' => {
      id: 'survival',
      title: 'Survival',
      notes: [
        'Humans call the law slower. You will stop them from doing that when you jump on them. Minor early invasion chance bonus.',
        'Fast calling speed. Calls are not interrupted with attaching. Early invasion chance penalty.',
        'Same calling rules as normal. No free dog on exiting the sewers. Larger penalty for early invasion chance.',
      ]
    },

    'group' => {
      id: 'group',
      title: 'The Group',
      notes: [
        'Shows the exact numerical group and team information in the skills section. Limited shock and energy loss from habitat destruction.',
        'Shows group and team information described vaguely. Habitat destruction shock and energy loss is more severe.',
        'No group or team information available. Habitat destruction shock is harsh.',
      ]
    },

    'evolution' => {
      id: 'evolution',
      title: 'Evolution',
      notes: [
        'Gives 2 generic improvements. No limit for maximum improvement level. Host degradation is slower. No limit on total habitats amount.',
        'Gives 2 generic improvements. Maximum improvement level is 2, except for brain probe. Normal host degradation. Finite habitat amount per game.',
        'Gives 1 generic improvement. Maximum improvement level is 1, except for brain probe. Fast host degradation. Habitat limit decreased.',
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

    'save' => {
      id: 'save',
      title: 'Saving',
      notes: [
        'You can save your game anywhere, up to 10 times per one game.',
        'You can only save in region mode, 3 times per game.',
        'You can only save once per game while in region mode.',
      ]
    },
  ];
}

typedef _Choice = {
  var id: String;
  var title: String;
  var notes: Array<String>;
}
