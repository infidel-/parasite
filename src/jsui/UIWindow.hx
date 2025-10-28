// gui window

package jsui;

import js.Browser;
import js.html.DivElement;
import js.html.InputElement;
import js.html.LegendElement;
import js.html.SelectElement;
import js.html.OptionElement;
import js.html.PointerEvent;

import game.Game;

class UIWindow
{
  var game: Game;
  var window: DivElement;
  var bg: DivElement;
  var close: DivElement;
  var state: _UIState; // state this relates to

  public function new(g: Game, id: String)
    {
      game = g;
      bg = Browser.document.createDivElement();
      bg.className = 'window-bg';
      bg.id = id + '-bg';
      Browser.document.body.appendChild(bg);
      window = Browser.document.createDivElement();
      window.id = id;
      bg.style.visibility = 'hidden';
      window.className = 'window text';
      bg.appendChild(window);
    }

// add standard close button
  function addCloseButton()
    {
      close = Browser.document.createDivElement();
      close.className = 'hud-button window-common-close';
      close.innerHTML = 'CLOSE';
      close.style.borderImage = "url('./img/window-common-close.png') 92 fill / 1 / 0 stretch";
      close.onclick = function (e) {
        game.scene.sounds.play('click-menu');
        game.scene.sounds.play('window-close');
        game.ui.closeWindow();
      }
      window.appendChild(close);
    }

// add scrolled text block wrapped in fieldset
  function addBlockExtended(cont: DivElement, id: String, title: String,
      ?textClassName = 'scroller'): {
      text: DivElement,
      legend: LegendElement
    }
    {
      var fieldset = Browser.document.createFieldSetElement();
      fieldset.id = id;
      cont.appendChild(fieldset);
      var legend = Browser.document.createLegendElement();
      legend.className = 'window-title';
      legend.innerHTML = title;
      fieldset.appendChild(legend);
      var text = Browser.document.createDivElement();
      text.className = textClassName;
      fieldset.appendChild(text);
      return {
        text: text,
        legend: legend,
      };
    }

// add scrolled text block wrapped in fieldset
  function addBlock(cont: DivElement, id: String, title: String,
      ?textClassName = 'scroller'): DivElement
    {
      var x = addBlockExtended(cont, id, title, textClassName);
      return x.text;
    }

// add select to options
  function addSelect(
      contents: DivElement, label: String, id: String,
      options: Array<{ ?font: String, title: String, val: String, isSelected: Bool }>,
      set: String -> Void): DivElement
    {
      var cont = Browser.document.createDivElement();
      cont.className = 'select-contents';
      contents.appendChild(cont);

      var title = Browser.document.createDivElement();
      title.className = 'select-title';
      title.innerHTML = label;
      cont.appendChild(title);

      var el = Browser.document.createSelectElement();
      el.id = 'option-' + id;
      el.className = 'select-element';
      cont.appendChild(el);
      el.onclick = function (e: PointerEvent) {
        var select: SelectElement = untyped e.target;
        var op: OptionElement = cast select.options[select.selectedIndex];
        set(op.value);
      }

      var padding = Browser.document.createDivElement();
      padding.className = 'slider-value';
      cont.appendChild(padding);

      for (info in options)
        {
          var op = Browser.document.createOptionElement();
          op.className = 'select-element';
          if (info.font != null)
            op.style.fontFamily = info.font;
          op.style.fontSize = '150%';
          op.label = info.title;
          if (info.isSelected)
            op.selected = true;
          op.value = info.val;
          el.appendChild(op);
        }
      return cont;
    }

// add checkbox to options
  function addCheckbox(contents: DivElement, label: String, id: String,
      val: Bool, pos: String): InputElement
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

      return cb;
    }

// add slider to options
  function addSlider(contents: DivElement, label: String, val: Float,
      set: Float -> Void,
      min: Float, max: Float, step: Float, roundType: String,
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

// set window parameters
  public dynamic function setParams(obj: Dynamic)
    {}

// update window contents
  public dynamic function update()
    {}

// action handling
  public dynamic function action(index: Int)
    {}

// scroll window up/down
  public dynamic function scroll(n: Int)
    {}

// scroll window to beginning
  public dynamic function scrollToBegin()
    {}

// scroll window to end
  public dynamic function scrollToEnd()
    {}

// animate element content update
  function animate(actions: DivElement, ?className: String = 'content-updating')
    {
      var actionsBlock = actions;
      actionsBlock.classList.remove(className);
      // force a reflow so the animation restarts
      untyped actionsBlock.offsetHeight;
      actionsBlock.classList.add(className);
      haxe.Timer.delay(function() {
        actionsBlock.classList.remove(className);
      }, 300);
    }

// show window
  public function show(?skipAnimation: Bool = false)
    {
      update();
      bg.style.visibility = 'visible';
      // add fade-in animation
      if (!skipAnimation)
        bg.classList.add('window-fade-in');
      else
        {
          // set backdrop-filter to final state when skipping animation
          untyped bg.style.backdropFilter = 'saturate(50%) blur(2px)';
        }
    }

// hide window
  public function hide(?skipAnimation: Bool = false)
    {
      if (!skipAnimation)
        {
          // add fade-out animation
          bg.classList.add('window-fade-out');
          // hide after animation completes
          haxe.Timer.delay(function() {
            bg.style.visibility = 'hidden';
            bg.classList.remove('window-fade-out');
          }, 100);
        }
      else
        {
          // hide immediately when skipping animation
          bg.style.visibility = 'hidden';
        }
      // remove other animation classes
      bg.classList.remove('window-fade-in');
      bg.classList.remove('mainmenu-first-show');
    }
}
