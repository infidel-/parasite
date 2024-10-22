// main menu window

package jsui;

import js.Browser;
import js.html.DivElement;

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
      var swirl = Browser.document.createDivElement();
      swirl.className = 'window-swirl';
      bg.appendChild(swirl);
      // randomize background
      if (!game.firstEverRun)
        UI.setVar('--main-menu-bg', 'url(./img/misc/bg' + (1 + Std.random(8)) + '.jpg)');

      var title = Browser.document.createDivElement();
      title.id = 'window-mainmenu-title';
      title.className = 'window-title';
      title.innerHTML = 'PARASITE <span style="font-size: 70%;">' + Const.smallgray(
        'v' + Version.getVersion() +
#if demo
        + ' DEMO' +
#end
      '</span>');
      window.appendChild(title);
      contents = Browser.document.createDivElement();
      contents.id = 'window-mainmenu-contents';
      window.appendChild(contents);

      addItem('NEW GAME', function(e) {
        game.ui.state = UISTATE_NEWGAME;
      });
      loadItem = addItem('LOAD GAME', loadGame);
      saveItem = addItem('SAVE GAME', saveGame);
      addItem('PEDIA', function(e) {
        game.ui.state = UISTATE_PEDIA;
      });
      addItem('OPTIONS', function(e) {
        game.ui.state = UISTATE_OPTIONS;
      });
      addItem('ABOUT', function(e) {
        game.ui.state = UISTATE_ABOUT;
      });
      addItem('QUIT', function(e) {
#if electron
        electron.renderer.IpcRenderer.invoke('quit');
#end
      });

      addCloseButton();
      close.style.display = 'none';

      // empty space
      var space = Browser.document.createDivElement();
      space.innerHTML = '<br><br>';
      contents.appendChild(space);
    }

// load game
  function loadGame(e)
    {
      if (!game.saveExists(1))
        return;
      game.load(1);
      game.ui.closeWindow();
      game.ui.hud.update();
      game.scene.draw();
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
        game.ui.state = UISTATE_NEWGAME;
      else if (index == 2)
        loadGame(null);
      else if (index == 3)
        saveGame(null);
      else if (index == 4)
        game.ui.state = UISTATE_PEDIA;
      else if (index == 5)
        game.ui.state = UISTATE_OPTIONS;
      else if (index == 6)
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
      item.className = 'window-mainmenu-item window-title';
      item.innerHTML = label;
      cont.appendChild(item);
      item.onclick = function (e) {
        game.scene.sounds.play('click-menu');
        f(e);
      };
      return item;
    }

  override function update()
    {
      saveItem.innerHTML = 'SAVE GAME';
      if (game.isStarted && !game.isFinished &&
          game.player.saveDifficulty != UNSET)
        saveItem.innerHTML +=
          '<br><span style="font-size: 70%;">' + Const.smallgray('[' +
          game.player.vars.savesLeft + ' saves left]') + '</span>';

      if (!game.saveExists(1))
        loadItem.className = 'window-mainmenu-item-disabled window-title';
      else loadItem.className = 'window-mainmenu-item window-title';
      if (!game.isStarted || game.isFinished)
        saveItem.className = 'window-mainmenu-item-disabled window-title';
      else saveItem.className = 'window-mainmenu-item window-title';
      if (game.isStarted)
        close.style.display = 'block';
    }
}


