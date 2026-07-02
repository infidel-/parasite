// options window — instrument module cards

package ui;

import js.Browser;
import js.html.DivElement;
import js.html.InputElement;
import js.html.SelectElement;
import js.html.OptionElement;

import game.Game;

class Options extends UIWindow
{
  var body: DivElement;          // .options-body (holds cards)
  var spoonString: String;
  var cards: Array<_OptCardUI>;
  var cardBody: DivElement;      // current card's body while building
  var cardCount: DivElement;     // current card's count chip
  var cardRows: Int;
  static inline var MAX_OPEN = 2;

  public function new(g: Game)
    {
      super(g, 'window-options');
      spoonString = '';
      cards = [];

      addCorners();

      // titlebar with clickable OPTIONS letters (SPOON easter egg)
      var titlebar = Browser.document.createDivElement();
      titlebar.className = 'options-titlebar';
      var title = Browser.document.createDivElement();
      title.id = 'window-options-title';
      title.className = 'options-title';
      titlebar.appendChild(title);
      window.appendChild(titlebar);
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

      body = Browser.document.createDivElement();
      body.className = 'options-body';
      window.appendChild(body);

      // ---- AUDIO ----
      addCard('Audio');
      addOptSlider('Music volume', game.config.musicVolume, 0, 100, 1, 'int', '',
        function (v) {
          game.config.set('musicVolume', '' + Std.int(v), false);
          game.scene.sounds.musicVolumeChanged();
        });
      addOptSlider('Effects volume', game.config.effectsVolume, 0, 100, 1, 'int', '',
        function (v) {
          game.config.set('effectsVolume', '' + Std.int(v), false);
        });
      addOptSlider('Ambience volume', game.config.ambientVolume, 0, 100, 1, 'int', '',
        function (v) {
          game.config.set('ambientVolume', '' + Std.int(v), false);
          game.scene.sounds.ambientVolumeChanged();
        });

      // ---- INTERFACE ----
      addCard('Interface');
      addOptSlider('Repeat delay', game.config.repeatDelay, 0, 500, 10, 'int', 'ms',
        function (v) {
          game.config.set('repeatDelay', '' + Std.int(v), false);
        });
      addOptSlider('Map scale', game.config.mapScale * 100, 10, 1000, 10, 'round', '%',
        function (v) {
          game.config.set('mapScale', '' + Const.round(v / 100.0), false);
          Const.TILE_SIZE = Std.int(Const.TILE_SIZE_CLEAN * game.config.mapScale);
          game.scene.updateCamera();
          game.scene.draw();
        });
      addOptSlider('Minimap scale', game.config.minimapScale * 100, 60, 1000, 20, 'round', '%',
        function (v) {
          game.config.set('minimapScale', '' + Const.round(v / 100.0), false);
          if (game.location == LOCATION_AREA)
            game.scene.area.generateMinimap();
          game.scene.updateCamera();
          game.scene.draw();
        });

      // title font selector
      var fontTitles = [];
      for (f in Config.fontsTitle)
        fontTitles.push({ font: f, title: f, val: f, isSelected: (game.config.fontTitle == f) });
      addOptSelect('Title font', 'fontTitle', fontTitles, function (val) {
        game.config.set('fontTitle', val);
      });
      // text font selector
      var fonts = [];
      for (f in Config.fonts)
        fonts.push({ font: f, title: f, val: f, isSelected: (game.config.font == f) });
      addOptSelect('Text font', 'font', fonts, function (val) {
        game.config.set('font', val);
      });
      addOptSlider('Font size', game.config.fontSize, 8, 40, 1, 'int', '',
        function (v) {
          game.config.set('fontSize', '' + v, false);
        });
      // overall difficulty + inline PRESETS button
      addOptSelect('Overall difficulty', 'difficulty', [
          { title: 'Unset', val: '0', isSelected: (game.config.difficulty == 0) },
          { title: 'Easy', val: '1', isSelected: (game.config.difficulty == 1) },
          { title: 'Normal', val: '2', isSelected: (game.config.difficulty == 2) },
          { title: 'Hard', val: '3', isSelected: (game.config.difficulty == 3) },
        ],
        function (val) { game.config.set('difficulty', val); },
        true);

      // ---- GAMEPLAY ----
      addCard('Gameplay');
      addOptToggle('Skip tutorial ' + Const.smallgray('(needs overall difficulty set)'),
        'skipTutorial', game.config.skipTutorial);
      addOptToggle('Enable fullscreen', 'fullscreen', game.config.fullscreen);
      addOptToggle('Enable AI-generated artwork', 'aiArtEnabled', game.config.aiArtEnabled);

      // ---- ADVANCED ----
      addCard('Advanced');
      addOptSlider('Log lines in HUD', game.config.hudLogLines, 1, 10, 1, 'int', '',
        function (v) {
          game.config.set('hudLogLines', '' + Std.int(v), false);
          game.hudMessageList.clear();
        });
      addOptToggle('Center camera on player near map edges', 'alwaysCenterCamera', game.config.alwaysCenterCamera);
      addOptToggle('Laptop movement keys (uiojklm,.)', 'laptopKeyboard', game.config.laptopKeyboard);
      addOptToggle('Extended gameplay information', 'extendedInfo', game.config.extendedInfo);
      addOptToggle('Shift-click/number repeat action', 'shiftLongActions', game.config.shiftLongActions);
      addOptToggle('Show mouse cursor on map', 'mouseEnabled', game.config.mouseEnabled);
      addOptToggle('Show FPS counter', 'showFps', game.config.showFps,
        function (on) game.ui.hud.topbar.ensureFps());

      finishCard();
      // start with only the first MAX_OPEN cards expanded
      for (i in 0...cards.length)
        if (i >= MAX_OPEN)
          setCollapsed(cards[i], true);

      addWinClose(function (e) {
        game.scene.sounds.play('click-menu');
        game.scene.sounds.play('window-close');
        game.config.save(false);
        game.ui.state = UISTATE_MAINMENU;
      });
    }

// finalize the previous card's row count
  function finishCard()
    {
      if (cardCount != null)
        cardCount.innerHTML = (cardRows < 10 ? '0' : '') + cardRows;
    }

// start a new instrument card (section)
  function addCard(label: String)
    {
      finishCard();
      cardRows = 0;
      var idx = cards.length;
      var card = Browser.document.createDivElement();
      card.className = 'win-card';
      card.style.animationDelay = (0.04 * (idx + 1)) + 's';
      var hd = Browser.document.createDivElement();
      hd.className = 'win-card-hd';
      hd.innerHTML = '<svg class="options-caret" viewBox="0 0 10 10" aria-hidden="true"><path d="M2 1.5 L8 5 L2 8.5 Z" fill="currentColor"/></svg>' +
        '<span class="win-cname">' + label + '</span><span class="win-count">00</span>';
      cardCount = cast hd.querySelector('.win-count');
      var wrap = Browser.document.createDivElement();
      wrap.className = 'win-card-wrap';
      cardBody = Browser.document.createDivElement();
      cardBody.className = 'win-card-bd';
      wrap.appendChild(cardBody);
      var rec: _OptCardUI = { card: card, wrap: wrap };
      cards.push(rec);
      hd.onclick = function (e) {
        game.scene.sounds.play('click-submenu');
        var opening = card.classList.contains('collapsed');
        // enforce max-open: close the open card farthest (by index) from this one
        if (opening)
          {
            var open = [];
            for (c in cards)
              if (!c.card.classList.contains('collapsed'))
                open.push(c);
            if (open.length >= MAX_OPEN)
              {
                var far = open[0];
                for (c in open)
                  if (Math.abs(cards.indexOf(c) - idx) > Math.abs(cards.indexOf(far) - idx))
                    far = c;
                setCollapsed(far, true);
              }
          }
        setCollapsed(rec, !opening);
      };
      card.appendChild(hd);
      card.appendChild(wrap);
      body.appendChild(card);
    }

  function setCollapsed(rec: _OptCardUI, val: Bool)
    {
      rec.card.classList.toggle('collapsed', val);
      rec.wrap.classList.toggle('collapsed', val);
    }

// build a setting row; returns its control container
  function addRow(labelHtml: String): DivElement
    {
      cardRows++;
      var row = Browser.document.createDivElement();
      row.className = 'options-row';
      var label = Browser.document.createDivElement();
      label.className = 'options-label';
      label.innerHTML = labelHtml;
      row.appendChild(label);
      var ctl = Browser.document.createDivElement();
      ctl.className = 'options-ctl';
      row.appendChild(ctl);
      cardBody.appendChild(row);
      return ctl;
    }

// slider row with a recessed LED value readout
  function addOptSlider(label: String, value: Float, min: Float, max: Float,
      step: Float, roundType: String, post: String, set: Float -> Void)
    {
      var ctl = addRow(label);
      var slider: InputElement = Browser.document.createInputElement();
      slider.className = 'options-slider';
      slider.type = 'range';
      slider.min = '' + min;
      slider.max = '' + max;
      slider.step = '' + step;
      slider.value = '' + value;
      var val = Browser.document.createSpanElement();
      val.className = 'options-val';
      var upd = function() {
        var v = slider.valueAsNumber;
        val.innerHTML = fmtValue(v, roundType) + post;
        slider.style.setProperty('--fill', ((v - min) / (max - min) * 100) + '%');
      };
      slider.oninput = function (e) {
        upd();
        set(slider.valueAsNumber);
      };
      upd();
      ctl.appendChild(slider);
      ctl.appendChild(val);
    }

// toggle switch row (replaces the offset-checkbox). optional onSet runs after the
// config write, for toggles that need to act immediately (e.g. start the FPS meter)
  function addOptToggle(label: String, id: String, value: Bool, ?onSet: Bool -> Void)
    {
      var ctl = addRow(label);
      var sw = Browser.document.createDivElement();
      sw.className = 'win-switch' + (value ? ' on' : '');
      sw.onclick = function (e) {
        var on = !sw.classList.contains('on');
        sw.classList.toggle('on', on);
        game.config.set(id, (on ? '1' : '0'), true);
        if (onSet != null)
          onSet(on);
      };
      ctl.appendChild(sw);
    }

// select row (styled native); presets adds the inline PRESETS button (difficulty)
  function addOptSelect(label: String, id: String,
      options: Array<{ ?font: String, title: String, val: String, isSelected: Bool }>,
      set: String -> Void, ?presets: Bool = false)
    {
      var ctl = addRow(label);
      var wrap = Browser.document.createDivElement();
      wrap.className = 'options-selwrap';
      var sel: SelectElement = Browser.document.createSelectElement();
      sel.id = 'option-' + id;
      sel.className = 'options-select';
      for (info in options)
        {
          var op: OptionElement = Browser.document.createOptionElement();
          if (info.font != null)
            op.style.fontFamily = info.font;
          op.label = info.title;
          op.text = info.title;
          op.value = info.val;
          if (info.isSelected)
            op.selected = true;
          sel.appendChild(op);
        }
      sel.onchange = function (e) {
        set(sel.value);
      };
      wrap.appendChild(sel);
      ctl.appendChild(wrap);
      if (presets)
        {
          var pb = Browser.document.createDivElement();
          pb.className = 'options-presets';
          pb.innerHTML = 'Presets';
          pb.onclick = function (e) {
            game.scene.sounds.play('click-menu');
            game.scene.sounds.play('window-close');
            game.ui.closeWindow();
            game.config.save(false);
            game.ui.state = UISTATE_PRESETS;
          }
          ctl.appendChild(pb);
        }
    }

// format a slider value for the readout
  function fmtValue(v: Float, t: String): String
    {
      if (t == 'int')
        return '' + Std.int(v);
      else if (t == 'round')
        return '' + Const.round(v);
      return '' + v;
    }

// save config on Enter/Escape before the window closes
  public override function handleKey(key: String, code: String, altKey: Bool, ctrlKey: Bool): Bool
    {
      if (key == 'Enter' ||
          key == 'NumpadEnter' ||
          code == 'Escape')
        game.config.save(false);
      return false;
    }

  override function hide(?skipAnimation: Bool = false)
    {
      animatedHide();
    }

// rebuild difficulty select options (adds custom presets)
  override function update()
    {
      var options = [
        { title: 'Unset', val: '0' },
        { title: 'Easy', val: '1' },
        { title: 'Normal', val: '2' },
        { title: 'Hard', val: '3' },
      ];
      for (idx => info in game.profile.object.difficultyPresets)
        options.push({ title: info.name, val: '' + (- idx - 1) });

      var el = Browser.document.getElementById('option-difficulty');
      if (el == null)
        return;
      el.innerHTML = '';
      for (info in options)
        {
          var op: OptionElement = Browser.document.createOptionElement();
          op.className = 'select-element';
          op.label = info.title;
          op.text = info.title;
          if (game.config.difficulty == Std.parseInt(info.val))
            op.selected = true;
          op.value = info.val;
          el.appendChild(op);
        }
    }
}

typedef _OptCardUI = {
  card: DivElement,
  wrap: DivElement,
}
