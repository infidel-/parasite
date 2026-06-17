// main menu window

package ui;

import js.Browser;
import js.html.DivElement;
import js.html.SpanElement;
import js.html.ButtonElement;
import js.html.Element;

import game.Game;

class MainMenu extends UIWindow
{
  var contents: DivElement;
  var loadItem: ButtonElement;
  var saveItem: ButtonElement;
  var loadEnabled: Bool;
  var saveEnabled: Bool;
  static inline var DEFAULT_BG = 1;
  var currentBackground: Int;
  public var menuBg: MainMenuBackground;
  public var menuCrowd: MainMenuCrowd;

  // redesign state
  var titleName: SpanElement;       // .mm-name, gets per-letter glyph glitch
  var titleNameText: String;        // the true word ("PARASITE")
  var cursor: DivElement;           // .mm-cursor sliding highlight bar
  var items: Array<ButtonElement>;  // .mm-item buttons in display order
  var labels: Array<Element>;       // matching .mm-label spans
  var labelTexts: Array<String>;    // matching plain label strings
  var decodeEls: Array<{ el: Element, text: String }>; // text bits that decode on open
  var activeIndex: Int;
  var glitchTimer: Int;
  var restoreTimer: Int;
  var itemCount: Int;

  public function new(g: Game)
    {
      super(g, 'window-mainmenu');
      currentBackground = DEFAULT_BG;
      loadEnabled = false;
      saveEnabled = false;
      items = [];
      labels = [];
      labelTexts = [];
      decodeEls = [];
      activeIndex = 0;
      glitchTimer = 0;
      restoreTimer = 0;
      itemCount = 0;

      // dark scrim layer behind the WebGL canvas (no-GL fallback base)
      var scrim = Browser.document.createDivElement();
      scrim.className = 'mm-scrim';
      bg.insertBefore(scrim, window);
      // create WebGL background canvas
      menuBg = new MainMenuBackground();
      bg.insertBefore(menuBg.getCanvas(), window);
      // create crowd silhouette overlay (independent of aiArtEnabled)
      menuCrowd = new MainMenuCrowd();
      bg.insertBefore(menuCrowd.getCanvas(), window);
      // decorative layers above the canvas, below the panel
      addDecor();
      setBackground(currentBackground, game.config.aiArtEnabled);
      // randomize background
      if (!game.firstEverRun)
        {
          var bgIndex = 1 + Std.random(22);
          setBackground(bgIndex, game.config.aiArtEnabled);
        }
      // add class for initial fade-in animation
      if (game.firstEverRun)
        bg.classList.add('mainmenu-first-show');

      // corner brackets (drawn into the panel before the title/contents)
      window.insertAdjacentHTML('afterbegin', UISvg.corners());

      // title: glitchable PARASITE + version sub-line
      var title = Browser.document.createDivElement();
      title.id = 'window-mainmenu-title';
      var verText = 'v' + Version.getVersion()
#if demo
        + ' DEMO'
#end
      ;
      title.innerHTML = '<span class="mm-name" data-text="PARASITE">PARASITE</span>' +
        '<span class="mm-ver">' + verText + '</span>';
      window.appendChild(title);
      titleName = cast title.querySelector('.mm-name');
      titleNameText = 'PARASITE';
      var verEl = title.querySelector('.mm-ver');
      decodeEls.push({ el: titleName, text: titleNameText });
      decodeEls.push({ el: verEl, text: verText });

      // items nav (holds the sliding cursor + buttons)
      contents = Browser.document.createDivElement();
      contents.id = 'window-mainmenu-contents';
      window.appendChild(contents);
      cursor = Browser.document.createDivElement();
      cursor.className = 'mm-cursor';
      contents.appendChild(cursor);

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
#if electron
      addItem('MODS', function(e) {
        game.ui.state = UISTATE_MODS;
      });
#end
      addItem('ABOUT', function(e) {
        game.ui.state = UISTATE_ABOUT;
      });
#if electron
      addItem('QUIT', function(e) {
        HostBridge.quit();
      });
#end

      addCloseButton();
      close.style.display = 'none';
    }

// add the decorative overlay layers (sigil, aura, vignette) above the canvas, below the panel
  function addDecor()
    {
      // rotating organism sigil (inner group counter-spins via .mm-sigil-in)
      var tmp = Browser.document.createDivElement();
      tmp.innerHTML = UISvg.sigil();
      bg.insertBefore(tmp.firstElementChild, window);
      // breathing aura
      var aura = Browser.document.createDivElement();
      aura.className = 'mm-aura';
      bg.insertBefore(aura, window);
      // vignette
      var vignette = Browser.document.createDivElement();
      vignette.className = 'mm-vignette';
      bg.insertBefore(vignette, window);
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
      close.style.display = 'block';
      game.ui.canvas.style.visibility = 'visible';
    }

// save game
  function saveGame(e)
    {
      if (!saveEnabled)
        return;
      // all remaining checks done in game.save()
      game.save(1);
      game.ui.closeWindow();
    }

// action handling (number-key dispatch)
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
#if electron
      else if (index == 6)
        game.ui.state = UISTATE_MODS;
      else if (index == 7)
        HostBridge.quit();
#end
    }

// add menu item (indexed button with number + label, hover sets active)
  function addItem(label: String, f: Dynamic -> Void): ButtonElement
    {
      itemCount++;
      var num = (itemCount < 10 ? '0' : '') + itemCount;
      var item = Browser.document.createButtonElement();
      item.className = 'mm-item';
      item.innerHTML = '<span class="mm-num">' + num + '</span>' +
        '<span class="mm-label">' + label + '</span>';
      contents.appendChild(item);
      var labelEl = item.querySelector('.mm-label');
      var idx = items.length;
      items.push(item);
      labels.push(labelEl);
      labelTexts.push(label);
      decodeEls.push({ el: labelEl, text: label });
      item.onclick = function (e) {
        game.scene.sounds.play('click-menu');
        f(e);
      };
      // hover highlights the row (with a glyph re-decode)
      item.addEventListener('pointerenter', function(e) {
        setActive(idx, true);
      });
      return item;
    }

// move the sliding highlight bar to the active item
  function placeCursor()
    {
      var it = items[activeIndex];
      cursor.style.height = it.offsetHeight + 'px';
      cursor.style.transform = 'translateY(' + it.offsetTop + 'px)';
      cursor.style.opacity = '1';
    }

// set the active item (wraps); redecode re-scrambles its label
  function setActive(i: Int, redecode: Bool)
    {
      i = (i + items.length) % items.length;
      activeIndex = i;
      for (n in 0...items.length)
        items[n].classList.toggle('active', n == i);
      placeCursor();
      if (redecode)
        UIDecode.decodeTo(labels[i], labelTexts[i]);
    }

// handle in-menu keys: arrows move the highlight, Enter activates it
  public override function handleKey(key: String, code: String, altKey: Bool, ctrlKey: Bool): Bool
    {
      if (code == 'ArrowDown')
        navMove(1);
      else if (code == 'ArrowUp')
        navMove(-1);
      else if (key == 'Enter' ||
          key == 'NumpadEnter')
        navActivate();
      else return false;
      return true;
    }

// keyboard nav: move highlight up/down
  function navMove(dir: Int)
    {
      setActive(activeIndex + dir, true);
    }

// keyboard nav: activate the highlighted item
  function navActivate()
    {
      var it = items[activeIndex];
      if (it.classList.contains('mm-disabled'))
        return;
      it.classList.add('mm-pulse');
      Browser.window.setTimeout(function() { it.classList.remove('mm-pulse'); }, 320);
      it.click();
    }

// is the menu overlay currently visible
  inline function isVisible(): Bool
    {
      return (bg.style.visibility != 'hidden');
    }

// pin the title box to the real word's width so glyph swaps (different advance
// widths) don't reflow the panel — overflow:visible lets wider glyphs spill
  function pinTitleWidth()
    {
      titleName.style.width = 'auto';
      titleName.textContent = titleNameText;
      titleName.style.width = titleName.offsetWidth + 'px';
    }

// flicker one or two random letters of the title to glyph noise, then restore
  function letterGlitch()
    {
      if (!isVisible())
        {
          glitchTimer = 0;
          return;
        }
      var arr = titleNameText.split('');
      var hits = (Math.random() < 0.3 ? 2 : 1);
      for (k in 0...hits)
        arr[Std.random(arr.length)] = UIDecode.randomGlyph();
      titleName.textContent = arr.join('');
      Browser.window.clearTimeout(restoreTimer);
      restoreTimer = Browser.window.setTimeout(function() {
        if (isVisible())
          titleName.textContent = titleNameText;
      }, 55 + Std.random(70));
      glitchTimer = Browser.window.setTimeout(letterGlitch, 600 + Std.random(1760));
    }

// start the title glitch loop (after the open-decode settles)
  function startGlitch()
    {
      Browser.window.clearTimeout(glitchTimer);
      pinTitleWidth();
      // re-pin after the web font swaps in
      Browser.window.setTimeout(function() { if (isVisible()) pinTitleWidth(); }, 500);
      glitchTimer = Browser.window.setTimeout(letterGlitch, 900);
    }

// stop the title glitch and restore the real word
  function stopGlitch()
    {
      Browser.window.clearTimeout(glitchTimer);
      Browser.window.clearTimeout(restoreTimer);
      glitchTimer = 0;
      titleName.textContent = titleNameText;
    }

// run the open effects: every text bit resolves out of glyph noise, staggered
  function openEffects()
    {
      for (i in 0...decodeEls.length)
        {
          var d = decodeEls[i];
          d.el.textContent = '';
          Browser.window.setTimeout(function() {
            UIDecode.decodeTo(d.el, d.text);
          }, 90 + i * 70);
        }
      // reset highlight to the first item; place the bar once layout settles
      activeIndex = 0;
      for (n in 0...items.length)
        items[n].classList.toggle('active', n == 0);
      cursor.style.opacity = '0';
      Browser.window.requestAnimationFrame(function(t) {
        Browser.window.requestAnimationFrame(function(t2) { placeCursor(); });
      });
      startGlitch();
    }

  override function show(?skipAnimation: Bool = false)
    {
      update();
      bg.style.visibility = 'visible';
      if (game.config.aiArtEnabled)
        menuBg.show();
      menuCrowd.show();
      bg.classList.add('mm-open');
      // add animation class for regular fade-in
      if (!skipAnimation && !bg.classList.contains('mainmenu-first-show'))
        bg.classList.add('window-fade-in');
      openEffects();
    }

  override function hide(?skipAnimation: Bool = false)
    {
      // set visibility immediately so MainMenuBackground render loop can detect it
      bg.style.visibility = 'hidden';
      menuBg.hide();
      menuCrowd.hide();
      bg.classList.remove('mm-open');
      stopGlitch();
      super.hide(skipAnimation);
    }

// update menu items based on game state
override function update()
  {
    loadEnabled = false;
    saveEnabled = false;
    // refresh the save-game sub-note (saves left / mission area)
    var sub = saveItem.querySelector('.mm-sub');
    if (sub != null)
      sub.remove();
    if (game.isStarted &&
        game.state == GAMESTATE_RUNNING &&
        game.player.saveDifficulty != UNSET)
      {
        // show mission area indicator instead of saves left when in mission area
        var text = game.player.vars.savesLeft + ' saves left';
        var col = 'gray';
        if (game.player.inMissionArea())
          {
            text = 'mission area';
            col = 'red';
          }
        var note = Browser.document.createSpanElement();
        note.className = 'mm-sub';
        note.innerHTML = Const.smallcol(col, '[' + text + ']');
        saveItem.appendChild(note);
      }

    loadEnabled = game.saveExists(1);
    saveEnabled = (game.isStarted && game.state == GAMESTATE_RUNNING);
    if (game.isStarted)
      close.style.display = 'block';
#if !electron
      loadEnabled = false;
      saveEnabled = false;
#end
      // toggle disabled state
      loadItem.classList.toggle('mm-disabled', !loadEnabled);
      saveItem.classList.toggle('mm-disabled', !saveEnabled);
    }

// update menu background and apply if AI art is enabled
  function setBackground(bgValue: Int, isEnabled: Bool)
    {
      currentBackground = bgValue;
      if (isEnabled)
        menuBg.setBackground(getBackgroundUrl());
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
