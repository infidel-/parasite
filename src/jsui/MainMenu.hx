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
  var loadEnabled: Bool;
  var saveEnabled: Bool;
  static inline var DEFAULT_BG = 1;
  var currentBackground: Int;

  public function new(g: Game)
    {
      super(g, 'window-mainmenu');
      currentBackground = DEFAULT_BG;
      loadEnabled = false;
      saveEnabled = false;
      window.style.borderImage = "url('./img/window-dialog.png') 100 fill / 1 / 0 stretch";
      var swirl = Browser.document.createDivElement();
      swirl.className = 'window-swirl';
      bg.appendChild(swirl);
      setBackground(currentBackground, game.config.aiArtEnabled);
      // randomize background
      if (!game.firstEverRun)
        {
          var bgIndex = 1 + Std.random(10);
          setBackground(bgIndex, game.config.aiArtEnabled);
        }
//      UI.setVar('--main-menu-bg', 'url(./img/misc/bg13.jpg)');

      var title = Browser.document.createDivElement();
      title.id = 'window-mainmenu-title';
      title.className = 'window-title';
      title.innerHTML = 'PARASITE <span style="font-size: 70%;">' + Const.smallgray(
        'v' + Version.getVersion() +
#if demo
        ' <span class=small>DEMO</span>' +
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
#if electron
      addItem('QUIT', function(e) {
        electron.renderer.IpcRenderer.invoke('quit');
      });
#end

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
      if (!loadEnabled)
        return;
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
      if (!saveEnabled)
        return;
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
      loadEnabled = false;
      saveEnabled = false;
      saveItem.innerHTML = 'SAVE GAME';
      if (game.isStarted && !game.isFinished &&
          game.player.saveDifficulty != UNSET)
        saveItem.innerHTML +=
          '<br><span style="font-size: 70%;">' + Const.smallgray('[' +
          game.player.vars.savesLeft + ' saves left]') + '</span>';

      loadEnabled = game.saveExists(1);
      saveEnabled = (game.isStarted && !game.isFinished);
      if (game.isStarted)
        close.style.display = 'block';
#if !electron
      loadEnabled = false;
      saveEnabled = false;
#end
      // set button classes
      if (!loadEnabled)
        loadItem.className = 'window-mainmenu-item-disabled window-title';
      else loadItem.className = 'window-mainmenu-item window-title';
      if (!saveEnabled)
        saveItem.className = 'window-mainmenu-item-disabled window-title';
      else saveItem.className = 'window-mainmenu-item window-title';
    }

// update menu background and apply if AI art is enabled
  function setBackground(bgValue: Int, isEnabled: Bool)
    {
      currentBackground = bgValue;
      if (isEnabled)
        UI.setVar('--main-menu-bg', getBackgroundUrl());
    }

// expose current menu background for config toggles
  public function getCurrentBackground(): Int
    {
      return currentBackground;
    }

// build css url for current background image
  public function getBackgroundUrl(): String
    {
      return 'url(./img/misc/bg' + currentBackground + '.jpg)';
    }
}
