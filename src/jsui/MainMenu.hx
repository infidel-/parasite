// main menu window

package jsui;

import js.Browser;
import js.html.DivElement;
import js.html.InputElement;
import js.html.PointerEvent;

import game.Game;

class MainMenu extends UIWindow
{
  var contents: DivElement;

  public function new(g: Game)
    {
      super(g, 'window-mainmenu');
      window.style.borderImage = "url('./img/window-dialog.png') 100 fill / 1 / 0 stretch";

      var title = Browser.document.createDivElement();
      title.id = 'window-mainmenu-title';
      title.innerHTML = 'PARASITE ' + Const.small(Const.col('gray',
        'v' + Version.getVersion()
#if demo
        + ' DEMO'
#end
        ));
      window.appendChild(title);
      contents = Browser.document.createDivElement();
      contents.id = 'window-mainmenu-contents';
      window.appendChild(contents);

      addItem('NEW GAME', function(e) {
        game.isStarted = true;
        game.ui.closeWindow();
        game.restart();
        close.style.display = 'block';
        game.ui.canvas.style.visibility = 'visible';
      });
      addItem('SAVE GAME ' + Const.small(Const.col('gray', '[unavailable]')), function(e) {
      });
      addItem('OPTIONS', function(e) {
        game.ui.state = UISTATE_OPTIONS;
      });
      addItem('QUIT', function(e) {
#if electron
        electron.renderer.IpcRenderer.invoke('quit');
#end
      });
      addCloseButton();
      close.style.display = 'none';
    }

// start new game
  function newGame(e)
    {
      game.isStarted = true;
      game.ui.closeWindow();
      game.restart();
      close.style.display = 'block';
      game.ui.canvas.style.visibility = 'visible';
    }

// action handling
  public override function action(index: Int)
    {
      if (index == 1)
        newGame(null);
      else if (index == 2) // save
        1;
      else if (index == 3)
        game.ui.state = UISTATE_OPTIONS;
      else if (index == 4)
#if electron
        electron.renderer.IpcRenderer.invoke('quit');
#else
        1;
#end
    }

// add menu item
  function addItem(label: String, f: Dynamic -> Void)
    {
      var cont = Browser.document.createDivElement();
      cont.className = 'window-mainmenu-cont';
      contents.appendChild(cont);

      var item = Browser.document.createDivElement();
      item.className = 'window-mainmenu-item';
      item.innerHTML = label;
      cont.appendChild(item);
      item.onclick = f;
    }

/*
// add slider to options
  function addSlider(label: String, val: Float, set: Float -> Void,
      min: Float, max: Float, step: Float,  roundType: String,
      post: String)
    {
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
    }*/
}


