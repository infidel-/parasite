
// yes/no window

package jsui;

import js.Browser;
import js.html.DivElement;

import game.Game;

class Options extends UIWindow
{
  var contents: DivElement;
  var restartText: DivElement;

  public function new(g: Game)
    {
      super(g, 'window-options', true);
      window.style.borderImage = "url('./img/window-dialog.png') 100 fill / 1 / 0 stretch";

      var title = Browser.document.createDivElement();
      title.id = 'window-options-title';
      title.innerHTML = '<center><h3>OPTIONS</h3></center>';
      window.appendChild(title);
      contents = Browser.document.createDivElement();
      contents.id = 'window-options-contents';
      window.appendChild(contents);

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

      restartText = Browser.document.createDivElement();
      restartText.innerHTML = "<center>The changes you've made will require restart.</center>";
      restartText.style.visibility = 'hidden';
      contents.appendChild(restartText);
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

