// options window

package jsui;

import js.Browser;
import js.html.DivElement;

import game.Game;

class Options extends UIWindow
{
  var contents: DivElement;
  var restartText: DivElement;
  var spoonString: String;

  public function new(g: Game)
    {
      super(g, 'window-options');
      spoonString = '';
      window.style.borderImage = "url('./img/window-dialog.png') 100 fill / 1 / 0 stretch";

      var title = Browser.document.createDivElement();
      title.id = 'window-options-title';
      window.appendChild(title);
      contents = Browser.document.createDivElement();
      contents.id = 'window-options-contents';
      window.appendChild(contents);

      // clickable letters
      for (letter in 'OPTIONS'.split(''))
        {
          var l = Browser.document.createSpanElement();
          l.innerHTML = letter;
          l.onclick = function (e) {
            spoonString += letter;
            if (spoonString.length > 5)
              spoonString = spoonString.substr(1, 6);
            if (spoonString != 'SPOON')
              return;
            game.ui.state = UISTATE_SPOON;
          }
          title.appendChild(l);
        }

      addCloseButton();
      close.onclick = function (e) {
        game.scene.sounds.play('click-menu');
        game.scene.sounds.play('window-close');
        game.config.save(false);
        game.ui.state = UISTATE_MAINMENU;
      }

      addSlider(contents, 'Music volume', game.config.musicVolume,
        function (v: Float) {
          game.config.set('musicVolume', '' + Std.int(v), false);
          game.scene.sounds.musicVolumeChanged();
        }, 0, 100, 1, 'int', '');
      addSlider(contents, 'Effects volume', game.config.effectsVolume,
        function (v: Float) {
          game.config.set('effectsVolume', '' + Std.int(v), false);
        }, 0, 100, 1, 'int', '');
      addSlider(contents, 'Ambience volume', game.config.ambientVolume,
        function (v: Float) {
          game.config.set('ambientVolume', '' + Std.int(v), false);
          game.scene.sounds.ambientVolumeChanged();
        }, 0, 100, 1, 'int', '');
      addSlider(contents, 'Repeat delay', game.config.repeatDelay,
        function (v: Float) {
          game.config.set('repeatDelay', '' + Std.int(v), false);
        }, 0, 500, 10, 'int', 'ms');
      addSlider(contents, 'Map scale', game.config.mapScale * 100,
        function (v: Float) {
          game.config.set('mapScale', '' + Const.round(v / 100.0), false);
          restartText.style.visibility = 'inherit';
        }, 10, 1000, 10, 'round', '%');
      addSlider(contents, 'Font size', game.config.fontSize,
        function (v: Float) {
          game.config.set('fontSize', '' + v, false);
          restartText.style.visibility = 'inherit';
        }, 8, 40, 1, 'int', '');
      addSelect(contents, 'Overall difficulty', 'difficulty', [
          {
            title: 'Unset',
            val: '0',
            isSelected: (game.config.difficulty == 0),
          },
          {
            title: 'Easy',
            val: '1',
            isSelected: (game.config.difficulty == 1),
          },
          {
            title: 'Normal',
            val: '2',
            isSelected: (game.config.difficulty == 2),
          },
          {
            title: 'Hard',
            val: '3',
            isSelected: (game.config.difficulty == 3),
          },
        ],
        function (val: String) {
          game.config.set('difficulty', val);
        });
      addCheckbox(contents, 'Skip tutorial ' +
        Const.smallgray('(needs overall difficulty set)'),
        'skipTutorial', game.config.skipTutorial, '-22.3%');
      addCheckbox(contents, 'Enable fullscreen',
        'fullscreen', game.config.fullscreen, '-55.6%');

      // advanced options
      var subtitle = Browser.document.createDivElement();
      subtitle.id = 'window-options-subtitle';
      subtitle.innerHTML = 'ADVANCED';
      contents.appendChild(subtitle);

      addSlider(contents, 'Log lines in HUD', game.config.hudLogLines,
        function (v: Float) {
          game.config.set('hudLogLines', '' + Std.int(v), false);
          game.hudMessageList.clear();
        }, 1, 10, 1, 'int', '');
      addCheckbox(contents, 'Center camera on player near map edges',
        'alwaysCenterCamera', game.config.alwaysCenterCamera, '-9%');
      addCheckbox(contents, 'Laptop movement keys (uiojklm,.)',
        'laptopKeyboard', game.config.laptopKeyboard, '-23.6%');
      addCheckbox(contents, 'Extended gameplay information',
        'extendedInfo', game.config.extendedInfo, '-26.9%');
      addCheckbox(contents, 'Shift-click/number repeat action',
        'shiftLongActions', game.config.shiftLongActions, '-24.7%');
      addCheckbox(contents, 'Show mouse cursor on map',
        'mouseEnabled', game.config.mouseEnabled, '-36.2%');

      restartText = Browser.document.createDivElement();
      restartText.style.textAlign = 'center';
      restartText.style.fontWeight = 'bold';
      restartText.innerHTML = "The changes you've made will require restart.";
      restartText.style.visibility = 'hidden';
      contents.appendChild(restartText);

      // empty space
      var space = Browser.document.createDivElement();
      space.innerHTML = '<br><br>';
      contents.appendChild(space);
    }
}

