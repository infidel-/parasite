// new game window

package jsui;

import js.Browser;
import js.html.DivElement;
import js.html.InputElement;
import js.html.PointerEvent;

import game.Game;

class NewGame extends UIWindow
{
  var contents: DivElement;

  public function new(g: Game)
    {
      super(g, 'window-newgame');
      window.style.borderImage = "url('./img/window-dialog.png') 100 fill / 1 / 0 stretch";

      var title = Browser.document.createDivElement();
      title.id = 'window-newgame-title';
      title.innerHTML = 'SELECT SCENARIO';
      window.appendChild(title);
      contents = Browser.document.createDivElement();
      contents.id = 'window-newgame-contents';
      window.appendChild(contents);

      addItem('SCENARIO A', function (e) {
        game.scene.sounds.play('click-menu');
        newGame('alien');
      });
      addItem('SANDBOX', function (e) {
        game.scene.sounds.play('click-menu');
        newGame('sandbox');
      });
      addCloseButton();
      close.onclick = function (e) {
        game.scene.sounds.play('click-menu');
        game.ui.state = UISTATE_MAINMENU;
      }
    }

// start new game
  function newGame(scenarioID: String)
    {
      game.scenarioStringID = scenarioID;
      game.isStarted = true;
      game.ui.closeWindow();
      game.restart();
      game.ui.canvas.style.visibility = 'visible';
    }

// action handling
  public override function action(index: Int)
    {
      // skip tutorial
      if (index == 1)
        newGame('alien');
      else if (index == 2)
        newGame('sandbox');
    }

// add menu item
  function addItem(label: String, f: Dynamic -> Void): DivElement
    {
      var cont = Browser.document.createDivElement();
      cont.className = 'window-newgame-cont';
      contents.appendChild(cont);

      var item = Browser.document.createDivElement();
      item.className = 'window-newgame-item';
      item.innerHTML = label;
      cont.appendChild(item);
      item.onclick = f;
      return item;
    }
}

