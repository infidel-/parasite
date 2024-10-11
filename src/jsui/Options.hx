// options window

package jsui;

import js.Browser;
import js.html.DivElement;

import game.Game;

class Options extends UIWindow
{
  var contents: DivElement;
  var spoonString: String;

  public function new(g: Game)
    {
      super(g, 'window-options');
      spoonString = '';
      window.style.borderImage = "url('./img/window-dialog.png') 100 fill / 1 / 0 stretch";

      var title = Browser.document.createDivElement();
      title.id = 'window-options-title';
      title.className = 'window-title';
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
          Const.TILE_SIZE =
            Std.int(Const.TILE_SIZE_CLEAN * game.config.mapScale);
          game.scene.updateCamera();
          game.scene.draw();
        }, 10, 1000, 10, 'round', '%');
      addSlider(contents, 'Minimap scale',
        game.config.minimapScale * 100,
        function (v: Float) {
          game.config.set('minimapScale', '' + Const.round(v / 100.0), false);
          if (game.location == LOCATION_AREA)
            game.scene.area.generateMinimap();
          game.scene.updateCamera();
          game.scene.draw();
        }, 60, 1000, 20, 'round', '%');

      // title font selector
      var fontTitles = [];
      for (f in Config.fontsTitle)
        fontTitles.push({
          title: f,
          val: f,
          isSelected: (game.config.fontTitle == f),
        });
      addSelect(contents, 'Title font', 'fontTitle', fontTitles,
        function (val: String) {
          game.config.set('fontTitle', val);
        });

      // font selector
      var fonts = [];
      for (f in Config.fonts)
        fonts.push({
          title: f,
          val: f,
          isSelected: (game.config.font == f),
        });
      addSelect(contents, 'Text font', 'font', fonts,
        function (val: String) {
          game.config.set('font', val);
        });
      addSlider(contents, 'Font size', game.config.fontSize,
        function (v: Float) {
          game.config.set('fontSize', '' + v, false);
        }, 8, 40, 1, 'int', '');

      var div = addSelect(contents, 'Overall difficulty', 'difficulty', [
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

      // presets button
      var presets = Browser.document.createLabelElement();
      presets.className = 'hud-button';
      presets.id = 'options-presets';
      presets.innerHTML = 'PRESETS';
      div.removeChild(div.lastChild); // remove padding 
      div.appendChild(presets);
      presets.onclick = function (e) {
        game.scene.sounds.play('click-menu');
        game.scene.sounds.play('window-close');
        game.ui.closeWindow();
        game.config.save(false);
        game.ui.state = UISTATE_PRESETS;
      }

      addCheckbox(contents, 'Skip tutorial ' +
        Const.smallgray('(needs overall difficulty set)'),
        'skipTutorial', game.config.skipTutorial, '-10.7ch');
      addCheckbox(contents, 'Enable fullscreen',
        'fullscreen', game.config.fullscreen, '-28.5ch');

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
        'alwaysCenterCamera', game.config.alwaysCenterCamera, '-4.4ch');
      addCheckbox(contents, 'Laptop movement keys (uiojklm,.)',
        'laptopKeyboard', game.config.laptopKeyboard, '-12.9ch');
      addCheckbox(contents, 'Extended gameplay information',
        'extendedInfo', game.config.extendedInfo, '-15ch');
      addCheckbox(contents, 'Shift-click/number repeat action',
        'shiftLongActions', game.config.shiftLongActions, '-13ch');
      addCheckbox(contents, 'Show mouse cursor on map',
        'mouseEnabled', game.config.mouseEnabled, '-18.5ch');

      // empty space
      var space = Browser.document.createDivElement();
      space.innerHTML = '<br><br>';
      contents.appendChild(space);
    }

// update difficulty settings
  override function update()
    {
      // base difficulty settings
      var options = [
        { title: 'Unset', val: '0', },
        { title: 'Easy', val: '1', },
        { title: 'Normal', val: '2', },
        { title: 'Hard', val: '3', },
      ];
      // add presets
      for (idx => info in game.profile.object.difficultyPresets)
        options.push({
          title: info.name,
          val: '' + (- idx - 1),
        });

      // add options
      var el = Browser.document.getElementById('option-difficulty');
      el.innerHTML = '';
      for (info in options)
        {
          var op = Browser.document.createOptionElement();
          op.className = 'select-element';
          op.label = info.title;
//          trace(game.config.difficulty, info.val);
          if (game.config.difficulty == Std.parseInt(info.val))
            op.selected = true;
          op.value = info.val;
          el.appendChild(op);
        }
    }
}

