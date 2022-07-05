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
  var loadItem: DivElement;
  var saveItem: DivElement;

  public function new(g: Game)
    {
      super(g, 'window-mainmenu');
      window.style.borderImage = "url('./img/window-dialog.png') 100 fill / 1 / 0 stretch";

      var title = Browser.document.createDivElement();
      title.id = 'window-mainmenu-title';
      title.innerHTML = 'PARASITE ' + Const.smallgray(
        'v' + Version.getVersion()
#if demo
        + ' DEMO'
#end
      );
      window.appendChild(title);
      contents = Browser.document.createDivElement();
      contents.id = 'window-mainmenu-contents';
      window.appendChild(contents);

      addItem('NEW GAME', newGame);
      loadItem = addItem('LOAD GAME', loadGame);
      saveItem = addItem('SAVE GAME', saveGame);
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

// load game
  function loadGame(e)
    {
      if (!game.saveExists(1))
        return;
      game.load(1);
      game.ui.closeWindow();
      game.ui.hud.update();
      close.style.display = 'block';
      game.ui.canvas.style.visibility = 'visible';
    }

// save game
  function saveGame(e)
    {
      if (!game.isStarted || game.isFinished)
        return;
      game.save(1);
      game.ui.closeWindow();
    }

// action handling
  public override function action(index: Int)
    {
      // skip tutorial
      if (index == 1)
        newGame(null);
      else if (index == 2)
        loadGame(null);
      else if (index == 3)
        saveGame(null);
      else if (index == 4)
        game.ui.state = UISTATE_OPTIONS;
      else if (index == 5)
#if electron
        electron.renderer.IpcRenderer.invoke('quit');
#else
        1;
#end
    }

// add menu item
  function addItem(label: String, f: Dynamic -> Void): DivElement
    {
      var cont = Browser.document.createDivElement();
      cont.className = 'window-mainmenu-cont';
      contents.appendChild(cont);

      var item = Browser.document.createDivElement();
      item.className = 'window-mainmenu-item';
      item.innerHTML = label;
      cont.appendChild(item);
      item.onclick = f;
      return item;
    }

  override function update()
    {
      saveItem.innerHTML = 'SAVE GAME';
      if (game.isStarted && !game.isFinished &&
          game.player.saveDifficulty != UNSET)
        saveItem.innerHTML += ' ' + Const.smallgray('[' +
          game.player.vars.savesLeft + ' saves left]');

      if (!game.saveExists(1))
        loadItem.className = 'window-mainmenu-item-disabled';
      else loadItem.className = 'window-mainmenu-item';
      if (!game.isStarted || game.isFinished)
        saveItem.className = 'window-mainmenu-item-disabled';
      else saveItem.className = 'window-mainmenu-item';
    }
}


