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
  public var menuGL: MainMenuGL; // unified bg + env + crowd + parasite scene

  // redesign state
  var titleName: SpanElement;       // .mainmenu-name, gets per-letter glyph glitch
  var titleNameText: String;        // the true word ("PARASITE")
  var cursor: DivElement;           // .mainmenu-cursor sliding highlight bar
  var items: Array<ButtonElement>;  // .mainmenu-item buttons in display order
  var labels: Array<Element>;       // matching .mainmenu-label spans
  var labelTexts: Array<String>;    // matching plain label strings
  var decodeEls: Array<{ el: Element, text: String }>; // text bits that decode on open
  var activeIndex: Int;
  var glitchTimer: Int;
  var restoreTimer: Int;
  var itemCount: Int;
  var cursorObserver: Dynamic; // ResizeObserver: re-places the highlight bar when rows reflow

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
      scrim.className = 'mainmenu-scrim';
      bg.insertBefore(scrim, window);
      // create the unified WebGL scene canvas (bg + environment + crowd + parasite)
      menuGL = new MainMenuGL();
      bg.insertBefore(menuGL.getCanvas(), window);
      // decorative layers above the canvas, below the panel
      addDecor();
      // pause the menu's decorative CSS animations while the app is unfocused
      Browser.window.addEventListener('blur', function(e) setMenuActive(false));
      Browser.window.addEventListener('focus', function(e) setMenuActive(true));
      Browser.document.addEventListener('visibilitychange', function(e) setMenuActive(!Browser.document.hidden));
#if electron
      // main-process push (renderer blur/visibilitychange don't fire reliably here)
      HostBridge.onFocusChange(function(focused) setMenuActive(focused));
#end
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
      title.innerHTML = '<span class="mainmenu-name" data-text="PARASITE">PARASITE</span>' +
        '<span class="mainmenu-ver">' + verText + '</span>';
      window.appendChild(title);
      titleName = cast title.querySelector('.mainmenu-name');
      titleNameText = 'PARASITE';
      var verEl = title.querySelector('.mainmenu-ver');
      decodeEls.push({ el: titleName, text: titleNameText });
      decodeEls.push({ el: verEl, text: verText });

      // items nav (holds the sliding cursor + buttons)
      contents = Browser.document.createDivElement();
      contents.id = 'window-mainmenu-contents';
      window.appendChild(contents);
      cursor = Browser.document.createDivElement();
      cursor.className = 'mainmenu-cursor';
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
        confirmQuit();
      });
#end

      // corner-X close (only shown in-game; see update()/loadGame())
      close = addWinClose();
      close.style.display = 'none';
    }

// add the decorative overlay layers (sigil, aura, vignette) above the canvas, below the panel
  function addDecor()
    {
      // rotating organism sigil (inner group counter-spins via .mainmenu-sigil-in)
      var tmp = Browser.document.createDivElement();
      tmp.innerHTML = UISvg.sigil();
      bg.insertBefore(tmp.firstElementChild, window);
      // breathing aura
      var aura = Browser.document.createDivElement();
      aura.className = 'mainmenu-aura';
      bg.insertBefore(aura, window);
      // vignette
      var vignette = Browser.document.createDivElement();
      vignette.className = 'mainmenu-vignette';
      bg.insertBefore(vignette, window);
    }

// load game: open the slot picker in load mode
  function loadGame(e)
    {
      if (!loadEnabled)
        return;
      game.ui.getComponent(UISTATE_SAVES).setParams({ mode: 'load' });
      game.ui.state = UISTATE_SAVES;
    }

// save game: open the slot picker in save mode
  function saveGame(e)
    {
      if (!saveEnabled)
        return;
      game.ui.getComponent(UISTATE_SAVES).setParams({ mode: 'save' });
      game.ui.state = UISTATE_SAVES;
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
        confirmQuit();
#end
    }

// confirm before quitting to desktop (danger dialog)
// open directly: ui.event() only auto-drains the queue at UISTATE_DEFAULT,
// so from the open menu we must set params + state ourselves
  function confirmQuit()
    {
      var p: _YesNoParams = {
        text: 'Quit to desktop?',
        sub: 'This will end your current session.',
        danger: true,
        back: _UIState.UISTATE_MAINMENU,
        func: function(yes: Bool) {
#if electron
          if (yes)
            HostBridge.quit();
#end
        }
      };
      game.ui.getComponent(UISTATE_YESNO).setParams(p);
      game.scene.sounds.play('window-open');
      game.ui.state = UISTATE_YESNO;
    }

// add menu item (indexed button with number + label, hover sets active)
  function addItem(label: String, f: Dynamic -> Void): ButtonElement
    {
      itemCount++;
      var num = (itemCount < 10 ? '0' : '') + itemCount;
      var item = Browser.document.createButtonElement();
      item.className = 'mainmenu-item';
      item.innerHTML = '<span class="mainmenu-num">' + num + '</span>' +
        '<span class="mainmenu-label">' + label + '</span>';
      contents.appendChild(item);
      var labelEl = item.querySelector('.mainmenu-label');
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
      if (code == 'ArrowDown' ||
          key == 'ArrowDown')
        navMove(1);
      else if (code == 'ArrowUp' ||
          key == 'ArrowUp')
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
      if (it.classList.contains('mainmenu-disabled'))
        return;
      it.classList.add('mainmenu-pulse');
      Browser.window.setTimeout(function() { it.classList.remove('mainmenu-pulse'); }, 320);
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

// pin each menu label to its real text width so the hover decode-scramble
// (random glyphs, different advance widths) spills via overflow:visible
// instead of reflowing the centered list — same trick as pinTitleWidth
  function pinLabelWidths()
    {
      for (i in 0...labels.length)
        {
          var el = labels[i];
          el.style.width = 'auto';
          el.textContent = labelTexts[i];
          el.style.width = el.offsetWidth + 'px';
        }
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
      pinLabelWidths();
      // re-pin after the web font swaps in
      Browser.window.setTimeout(function() { if (isVisible()) { pinTitleWidth(); pinLabelWidths(); } }, 500);
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
      // rows reflow after first paint (web font load, config font-size applied) and the
      // early rAF placement lands on stale metrics. A ResizeObserver re-places the bar
      // whenever a row's size actually changes, so it always settles correctly.
      if (cursorObserver == null)
        {
          var cb = function(entries, obs) {
            if (isVisible())
              placeCursor();
          };
          cursorObserver = js.Syntax.code("new ResizeObserver({0})", cb);
          cursorObserver.observe(contents);
          for (it in items)
            cursorObserver.observe(it);
        }
      startGlitch();
    }

  override function show(?skipAnimation: Bool = false)
    {
      update();
      bg.style.display = '';
      bg.style.visibility = 'visible';
      menuGL.setBgEnabled(game.config.aiArtEnabled);
      menuGL.show();
      bg.classList.add('mainmenu-open');
      // add animation class for regular fade-in
      if (!skipAnimation && !bg.classList.contains('mainmenu-first-show'))
        bg.classList.add('window-fade-in');
      openEffects();
    }

  override function hide(?skipAnimation: Bool = false)
    {
      // render loop self-stops via its visibility check; show() restarts it
      menuGL.hide();
      bg.classList.remove('mainmenu-open');
      stopGlitch();
      animatedHide(true); // keep display set: WebGL canvas mustn't go through display:none
    }

// pause the decorative CSS animations when the app loses focus (leaves the 3D running)
  function setMenuActive(active: Bool)
    {
      if (bg.style.visibility == 'hidden')
        return;
      bg.classList.toggle('menu-inactive', !active);
    }

// update menu items based on game state
override function update()
  {
    loadEnabled = false;
    saveEnabled = false;
    // refresh the save-game sub-note (saves left / mission area)
    var sub = saveItem.querySelector('.mainmenu-sub');
    if (sub != null)
      sub.remove();
    if (game.isStarted &&
        game.state == GAMESTATE_RUNNING &&
        game.player.saveDifficulty != UNSET)
      {
        // saves-left chip uses a floppy glyph + count; NOOB shows an infinity glyph (display font lacks ∞); mission area shows alert text
        var noob = (game.player.saveDifficulty == NOOB);
        var savesText = (noob ?
          '<svg class="mainmenu-sub-ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M12 12c-2-2.67-4-4-6-4a4 4 0 1 0 0 8c2 0 4-1.33 6-4Zm0 0c2 2.67 4 4 6 4a4 4 0 0 0 0-8c-2 0-4 1.33-6 4Z"/></svg>' :
          '' + game.player.vars.savesLeft);
        var html = UISvg.floppy('mainmenu-sub-ico') + ' ' + savesText;
        var alert = false;
        if (game.player.inMissionArea())
          {
            html = 'mission area';
            alert = true;
          }
        var note = Browser.document.createSpanElement();
        // themed css tooltip (native title is swallowed by the menu-item hover)
        note.className = (alert ? 'mainmenu-sub alert evolution-tip' : 'mainmenu-sub evolution-tip');
        note.innerHTML = html;
        note.setAttribute('data-tip', noob ? 'Unlimited saves' : game.player.vars.savesLeft + ' saves left');
        saveItem.appendChild(note);
      }

    // load enabled if any slot (autosave or manual) holds a save
    loadEnabled = false;
    for (slot in Game.AUTOSAVE_SLOT...Game.MANUAL_SLOTS + 1)
      if (game.saveExists(slot))
        {
          loadEnabled = true;
          break;
        }
    saveEnabled = (game.isStarted && game.state == GAMESTATE_RUNNING);
    if (game.isStarted)
      close.style.display = 'flex';
#if !electron
      loadEnabled = false;
      saveEnabled = false;
#end
      // toggle disabled state
      loadItem.classList.toggle('mainmenu-disabled', !loadEnabled);
      saveItem.classList.toggle('mainmenu-disabled', !saveEnabled);

#if electron
      // boot offer: if an exit-autosave survives, ask to resume (once per launch)
      if (!autosavePrompted &&
          !game.isStarted &&
          game.saveExists(Game.AUTOSAVE_SLOT))
        {
          autosavePrompted = true;
          Browser.window.setTimeout(promptAutosave, 1);
        }
#end
    }

  var autosavePrompted: Bool = false; // boot autosave offer shown this launch

// offer to resume from the exit-autosave slot.
// back=MAINMENU handles cancel; the load is deferred one tick so it runs after
// YesNo's dismiss() (which would otherwise force us back to the menu).
  function promptAutosave()
    {
      var p: _YesNoParams = {
        text: 'Autosave exists. Load?',
        sub: 'Resume from where you last left off.',
        back: _UIState.UISTATE_MAINMENU,
        func: function(yes: Bool) {
          if (!yes)
            return;
          Browser.window.setTimeout(function() {
            // close BEFORE loading (like New Game) so the load's fader.cover paints in sync
            // with the 3D build timer instead of being desynced by post-load UI work
            game.ui.closeWindow();
            game.ui.canvas.style.visibility = 'visible';
            game.load(Game.AUTOSAVE_SLOT);
          }, 0);
        }
      };
      game.ui.getComponent(UISTATE_YESNO).setParams(p);
      game.scene.sounds.play('window-open');
      game.ui.state = UISTATE_YESNO;
    }

// update menu background and apply if AI art is enabled
  function setBackground(bgValue: Int, isEnabled: Bool)
    {
      currentBackground = bgValue;
      menuGL.setBgEnabled(isEnabled);
      if (isEnabled)
        menuGL.setBackground(getBackgroundUrl());
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
