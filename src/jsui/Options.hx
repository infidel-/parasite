
// yes/no window

package jsui;

import js.Browser;
import js.html.DivElement;
import js.html.InputElement;
import js.html.PointerEvent;

import game.Game;

class Options extends UIWindow
{
  var contents: DivElement;
  var restartText: DivElement;

  public function new(g: Game)
    {
      super(g, 'window-options');
      window.style.borderImage = "url('./img/window-dialog.png') 100 fill / 1 / 0 stretch";

      var title = Browser.document.createDivElement();
      title.id = 'window-options-title';
      title.innerHTML = 'OPTIONS';
      window.appendChild(title);
      contents = Browser.document.createDivElement();
      contents.id = 'window-options-contents';
      window.appendChild(contents);

      addCloseButton();
      close.onclick = function (e) {
        game.config.save(false);
        game.ui.closeWindow();
      }

      addSlider('Music volume', game.config.musicVolume,
        function (v: Float) {
          game.config.set('musicVolume', '' + Std.int(v), false);
          game.scene.soundManager.musicVolumeChanged();
        }, 0, 100, 1, 'int', '');
      addSlider('Effects volume', game.config.effectsVolume,
        function (v: Float) {
          game.config.set('effectsVolume', '' + Std.int(v), false);
        }, 0, 100, 1, 'int', '');
      addSlider('Ambience volume', game.config.ambientVolume,
        function (v: Float) {
          game.config.set('ambientVolume', '' + Std.int(v), false);
          game.scene.soundManager.ambientVolumeChanged();
        }, 0, 100, 1, 'int', '');
      addSlider('Movement delay', game.config.pathDelay,
        function (v: Float) {
          game.config.set('pathDelay', '' + Std.int(v), false);
        }, 0, 500, 10, 'int', 'ms');
      addSlider('Map scale', game.config.mapScale * 100,
        function (v: Float) {
          game.config.set('mapScale', '' + Const.round(v / 100.0), false);
          restartText.style.visibility = 'inherit';
        }, 10, 1000, 10, 'round', '%');
      addSlider('Font size', game.config.fontSize,
        function (v: Float) {
          game.config.set('fontSize', '' + v, false);
          restartText.style.visibility = 'inherit';
        }, 8, 40, 1, 'int', '');
      addCheckbox('Enable fullscreen',
        'fullscreen', game.config.fullscreen, '-55.6%');

      // advanced options
      var subtitle = Browser.document.createDivElement();
      subtitle.id = 'window-options-subtitle';
      subtitle.innerHTML = 'ADVANCED';
      contents.appendChild(subtitle);

      addSlider('Log lines in HUD', game.config.hudLogLines,
        function (v: Float) {
          game.config.set('hudLogLines', '' + Std.int(v), false);
          game.hudMessageList.clear();
        }, 1, 10, 1, 'int', '');
      addCheckbox('Center camera on player near map edges',
        'alwaysCenterCamera', game.config.alwaysCenterCamera, '-9%');
      addCheckbox('Laptop movement keys (uiojklm,.)',
        'laptopKeyboard', game.config.laptopKeyboard, '-23.6%');
      addCheckbox('Extended gameplay information',
        'extendedInfo', game.config.extendedInfo, '-26.9%');

      restartText = Browser.document.createDivElement();
      restartText.style.textAlign = 'center';
      restartText.style.fontWeight = 'bold';
      restartText.innerHTML = "The changes you've made will require restart.";
      restartText.style.visibility = 'hidden';
      contents.appendChild(restartText);
    }

// add checkbox to options
  function addCheckbox(label: String, id: String, val: Bool, pos: String)
    {
      var cont = Browser.document.createDivElement();
      cont.className = 'checkbox-contents';
      contents.appendChild(cont);

      var title = Browser.document.createLabelElement();
      title.className = 'checkbox-title';
      title.innerHTML = label;
      cont.appendChild(title);

      var cb = Browser.document.createInputElement();
      cb.id = 'option-' + id;
      cb.type = 'checkbox';
      cb.className = 'checkbox-element';
      cb.checked = val;
      title.appendChild(cb);
      cb.onclick = function (e: PointerEvent) {
        var targetID: String = untyped e.target.id;
        var el: InputElement = cast game.ui.getElement(targetID);
        var itemID = targetID.substr(7);
        game.config.set(itemID, (el.checked ? '1' : '0'), true);
      };

      var span = Browser.document.createSpanElement();
      span.className = 'checkbox-span';
      span.style.right = pos;
      title.appendChild(span);
    }

// add slider to options
  function addSlider(label: String, val: Float, set: Float -> Void,
      min: Float, max: Float, step: Float,  roundType: String,
      post: String)
    {
      var cont = Browser.document.createDivElement();
      cont.className = 'slider-contents';
      contents.appendChild(cont);

      var title = Browser.document.createDivElement();
      title.className = 'slider-title';
      title.innerHTML = label;
      cont.appendChild(title);

      var value = Browser.document.createDivElement();
      value.className = 'slider-value';
      value.innerHTML = roundValue(val, roundType) + post;

      var sliderwrap = Browser.document.createDivElement();
      sliderwrap.className = 'slider-wrapper';
      cont.appendChild(sliderwrap);
      var slider = Browser.document.createInputElement();
      slider.className = 'slider';
      slider.type = 'range';
      slider.min = '' + min;
      slider.max = '' + max;
      slider.step = '' + step;
      slider.value = '' + val;
      slider.oninput = function (e) {
        var val = slider.valueAsNumber;
        value.innerHTML = roundValue(val, roundType) + post;
        set(val);
      }
      sliderwrap.appendChild(slider);
      cont.appendChild(value);
    }

  function roundValue(v: Float, t: String): String
    {
      if (t == 'int')
        return '' + Std.int(v);
      else if (t == 'round')
        return '' + Const.round(v);

      return '?';
    }
}

