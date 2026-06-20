// new js ui hud
package ui;

import mods.AssetPath;
import js.Browser;
import js.Browser.document;
import js.html.TextAreaElement;
import js.html.DivElement;
import js.html.SpanElement;
import js.html.Element;
import js.html.KeyboardEvent;
import js.html.MouseEvent;

import game.*;
import ui.Targeting;

class HUD
{
  var game: Game;
  var ui: UI;
  public var state: _HUDState;
  var blinkingText: DivElement;
  var overlay: DivElement;
  public var container: DivElement;
  var consoleDiv: DivElement;
  var console: TextAreaElement;
  var consoleHint: DivElement;
  var consoleHistoryIndex: Int;
  var consoleHistoryDraft: String;
  var log: DivElement;
  var goals: DivElement;
  public var info: DivElement;
  // background atmosphere layer (color grade + grain + veins)
  public var atmo: DivElement;
  // topbar: location + turn counter + gear
  var topbar: DivElement;
  var topbarName: SpanElement;
  var topbarCoords: DivElement;
  var topbarTurn: SpanElement;
  var topbarPinSvg: Element;
  var lastTurn: Int = -1;          // detects turn advance for odometer tick
  var lastLocName: String = '';    // detects area change for decode + pin ping
  var lastLogKey: String = '';     // detects a genuinely new top log row
  var regionTooltip: RegionTooltip;
  var aiTooltip: AITooltip;
  // debug overlay div — created and updated only when Const.isDebug is true
  var debugInfo: DivElement;
  var menuButtons: Array<{
    state: _UIState,
    btn: DivElement,
  }>;
  public var targeting: Targeting;
  public var command: Command;
  var actions: DivElement;
  var actionButtons: List<DivElement>; // list of action buttons
  var listActions: List<_PlayerAction>; // list of currently available actions
  var listKeyActions: List<_PlayerAction>; // list of currently available keyboard actions
  var lastMouseX: Float = -1;
  var lastMouseY: Float = -1;
  var lastRegionTileX: Int = -1;
  var lastRegionTileY: Int = -1;

  public function new(u: UI, g: Game)
    {
      game = g;
      ui = u;
      state = HUD_DEFAULT;
      actionButtons = new List();
      listActions = new List();
      listKeyActions = new List();
      targeting = new Targeting(game, this);
      command = null;

      overlay = document.createDivElement();
      overlay.id = 'overlay';
      overlay.style.visibility = 'hidden';
      document.body.appendChild(overlay);

      blinkingText = document.createDivElement();
      blinkingText.innerHTML = 'You feel someone is watching.';
      blinkingText.className = 'highlight-text';
      blinkingText.id = 'blinking-text';
      blinkingText.style.opacity = '0';
      blinkingText.style.userSelect = 'none';
      blinkingText.style.visibility = 'hidden';
      document.body.appendChild(blinkingText);

      container = document.createDivElement();
      container.id = 'hud';
      container.style.visibility = 'visible';
      document.body.appendChild(container);

      // background atmosphere: purple color-grade + film grain + corner veins.
      // lives on its own body-level layer (not inside #hud) so toggling the HUD
      // with space does not hide the world tint.
      atmo = document.createDivElement();
      atmo.id = 'hud-atmo';
      var grade = document.createDivElement();
      grade.id = 'hud-grade';
      atmo.appendChild(grade);
      var veins = document.createDivElement();
      veins.id = 'hud-veins-wrap';
      veins.innerHTML = UISvg.hudVeins();
      atmo.appendChild(veins);
      document.body.appendChild(atmo);

      // initialize region tooltip
      regionTooltip = new RegionTooltip(game, this);
      // initialize area AI tooltip
      aiTooltip = new AITooltip(game, this);

      consoleDiv = document.createDivElement();
      consoleDiv.className = 'console-div';
      consoleDiv.style.visibility = 'hidden';
      container.appendChild(consoleDiv);

      console = document.createTextAreaElement();
      console.id = 'hud-console';
      consoleHistoryIndex = -1;
      consoleHistoryDraft = '';
      console.onkeydown = onConsoleKeyDown;
      console.oninput = function(_) updateConsoleHint();
      consoleDiv.appendChild(console);

      // gray inline hint overlay (sits over the textarea, typed part transparent)
      consoleHint = document.createDivElement();
      consoleHint.id = 'hud-console-hint';
      consoleHint.style.display = 'none';
      consoleDiv.appendChild(consoleHint);

      // topbar: location (pin + name + coords), turn counter, gear
      topbar = document.createDivElement();
      topbar.id = 'hud-topbar';
      topbar.innerHTML =
        '<div class="hud-loc">' + UISvg.hudPin() +
          '<div><div class="hud-loc-name"></div><div class="hud-loc-coords"></div></div></div>' +
        '<div class="hud-turn">' + UISvg.clockSmall('hud-ico-time') + '<span></span></div>' +
        '<div class="hud-right"><div class="hud-gear">' + UISvg.hudGear() + '</div></div>';
      container.appendChild(topbar);
      topbarName = cast topbar.querySelector('.hud-loc-name');
      topbarCoords = cast topbar.querySelector('.hud-loc-coords');
      topbarTurn = cast topbar.querySelector('.hud-turn span');
      topbarPinSvg = topbar.querySelector('.hud-loc svg');
      // gear opens options
      (cast topbar.querySelector('.hud-gear') : DivElement).onclick = function (e)
        {
          game.scene.sounds.play('click-hud');
          game.ui.state = UISTATE_MAINMENU;
        };

      log = document.createDivElement();
      log.className = 'hud-panel hud-text';
      log.id = 'hud-log';
      container.appendChild(log);

      goals = document.createDivElement();
      goals.className = 'hud-panel hud-text';
      goals.id = 'hud-goals';
      container.appendChild(goals);

      info = document.createDivElement();
      info.className = 'hud-panel hud-text hud-stats';
      info.id = 'hud-info';
      container.appendChild(info);


      if (Const.isDebug)
        {
          debugInfo = document.createDivElement();
          debugInfo.className = 'text';
          debugInfo.id = 'hud-debug-info';
          container.appendChild(debugInfo);
        }

      // menu / navbar (membrane strip of icon cells)
      var buttons = document.createDivElement();
      buttons.id = 'hud-buttons';
      buttons.className = 'hud-panel';
      container.appendChild(buttons);
      menuButtons = [];
      addMenuButton(buttons, UISTATE_GOALS, UISvg.hudNavGoals(), 'Goals');
      addMenuButton(buttons, UISTATE_BODY, UISvg.hudNavBody(), 'Body');
      addMenuButton(buttons, UISTATE_LOG, UISvg.hudNavLog(), 'Log');
      addMenuButton(buttons, UISTATE_TIMELINE, UISvg.hudNavTimeline(), 'Timeline');
      addMenuButton(buttons, UISTATE_EVOLUTION, UISvg.hudNavEvo(), 'Evo');
      addMenuButton(buttons, UISTATE_CULT, UISvg.hudNavCult(), 'Cult');
      // actions
      actions = document.createDivElement();
      actions.id = 'hud-actions';
      actions.className = 'hud-panel';
      container.appendChild(actions);
    }

// show blinking text and set timeout
  public function showBlinkingText()
    {
      blinkingText.style.visibility = 'visible';
      blinkingText.style.opacity = '1';
      Browser.window.setTimeout(function() {
        blinkingText.style.opacity = '0';
        Browser.window.setTimeout(function() {
          blinkingText.style.visibility = 'hidden';
        }, 2000);
      }, 2000);
    }

// show glass wall overlay
// NOTE: dont really like it, the mouse cursor will not change without movement
  public inline function showOverlay()
    {
//      overlay.style.visibility = 'visible';
    }

// hide glass wall overlay
  public inline function hideOverlay()
    {
//      overlay.style.visibility = 'hidden';
    }

// add icon cell to navbar menu
  function addMenuButton(cont: DivElement, state: _UIState, icon: String, label: String): DivElement
    {
      var btn = document.createDivElement();
      btn.innerHTML = icon + '<span class="hud-nav-label">' + label + '</span>';
      btn.title = label;
      // NOTE: must be the same with show/hide buttons at updateMenu()
      btn.className = 'hud-nav-cell';
      cont.appendChild(btn);
      menuButtons.push({
        state: state,
        btn: btn,
      });
      btn.onclick = function (e)
        {
          game.scene.sounds.play('click-hud');
          game.scene.sounds.play('window-open');
          game.ui.state = state; 
        }
      return btn;
    }

// get menu button
  public function getMenuButton(state: _UIState): DivElement
    {
      for (b in menuButtons)
        if (b.state == state)
          return b.btn;
      return null;
    }

// handle mouse move for region/AI tooltips (panels are click-through)
  public function onMouseMove(e: MouseEvent)
    {
      // check if mouse position changed enough to care
      var dx = e.clientX - lastMouseX;
      var dy = e.clientY - lastMouseY;
      if (dx * dx + dy * dy < 4) // ~2px threshold
        return; // mouse hasn't moved significantly

      if (ui.state != UISTATE_DEFAULT)
        {
          lastMouseX = e.clientX;
          lastMouseY = e.clientY;
          return;
        }

      if (game.location == LOCATION_REGION)
        updateRegionTooltipHover();
      else if (game.location == LOCATION_AREA)
        {
          resetRegionTooltipHover();
          regionTooltip.hide();
          updateAITooltip();
        }
      else
        {
          resetRegionTooltipHover();
          regionTooltip.hide();
          aiTooltip.hide();
        }

      lastMouseX = e.clientX;
      lastMouseY = e.clientY;
    }


// hide overlays when mouse leaves the canvas
public function onMouseLeave()
  {
    resetRegionTooltipHover();
    regionTooltip.hide();
    aiTooltip.hide();
  }

// reset cached hovered region tile
  function resetRegionTooltipHover()
    {
      lastRegionTileX = -1;
      lastRegionTileY = -1;
    }

// refresh region tooltip for the current hovered tile
  function updateRegionTooltipHover(?refreshVisible: Bool = false)
    {
      if (ui.state != UISTATE_DEFAULT ||
          game.location != LOCATION_REGION)
        {
          resetRegionTooltipHover();
          regionTooltip.hide();
          return;
        }

      var pos = game.scene.mouse.getXY();
      if (pos == null)
        {
          resetRegionTooltipHover();
          regionTooltip.hide();
          return;
        }

      var area = game.region.getXY(pos.x, pos.y);
      if (area == null)
        {
          resetRegionTooltipHover();
          regionTooltip.hide();
          return;
        }

      if (!refreshVisible &&
          area.x == lastRegionTileX &&
          area.y == lastRegionTileY)
        return;
      if (refreshVisible &&
          area.x == lastRegionTileX &&
          area.y == lastRegionTileY &&
          !regionTooltip.visible)
        return;

      lastRegionTileX = area.x;
      lastRegionTileY = area.y;
      regionTooltip.update();
      if (!regionTooltip.visible)
        resetRegionTooltipHover();
    }

// returns true if area AI inspect mode is active
  public function isAIInspectMode(): Bool
    {
      return (
        game.location == LOCATION_AREA &&
        ui.state == UISTATE_DEFAULT &&
        state == HUD_DEFAULT &&
        !game.isInputLocked() &&
        game.scene.controlPressed &&
        game.config.mouseEnabled
      );
    }

// updates area AI tooltip state
  public function updateAITooltip()
    {
      if (isAIInspectMode())
        aiTooltip.update();
      else aiTooltip.hide();
    }

// show hide HUD
  public function toggle()
    {
      if (container.style.visibility == 'visible')
        hide();
      else show();
      if (game.location == LOCATION_AREA)
        game.scene.area.draw();
    }

// returns true if HUD is visible
  public function isVisible(): Bool
    {
      return (container.style.visibility == 'visible');
    }

// show/hide the background atmosphere layer (kept out of HUD toggle; hidden on main menu)
  public function setAtmoVisible(v: Bool)
    {
      atmo.style.visibility = (v ? 'visible' : 'hidden');
    }

  public function show()
    {
      container.style.visibility = 'visible';
    }

  public function hide()
    {
      regionTooltip.hide();
      aiTooltip.hide();
      container.style.visibility = 'hidden';
    }

  public function consoleVisible(): Bool
    {
      return (consoleDiv.style.visibility == 'visible');
    }

  public function showConsole()
    {
      consoleDiv.style.visibility = 'visible';
      console.value = '';
      Browser.window.setTimeout(function () {
        console.value = '';
      });
      console.focus();
      consoleHistoryIndex = -1;
      consoleHistoryDraft = '';
      updateConsoleHint();
    }

  public function hideConsole()
    {
      consoleDiv.style.visibility = 'hidden';
      consoleHistoryIndex = -1;
      consoleHistoryDraft = '';
      consoleHint.style.display = 'none';
      ui.focus();
    }

// handle keyboard input for console
  function onConsoleKeyDown(e: KeyboardEvent)
    {
      // hide console
      if (e.code == 'Escape')
        {
          hideConsole();
        }
      // run console command
      else if (e.code == 'Enter')
        {
          game.console.run(console.value);
          consoleHistoryIndex = -1;
          consoleHistoryDraft = '';
          // kludge: needs a timeout or closes the event window
          Browser.window.setTimeout(hideConsole, 10);
        }
      // tab completion (longest common prefix; lists ambiguous candidates)
      else if (e.code == 'Tab')
        {
          e.preventDefault();
          var r = game.console.completion.complete(console.value);
          if (r.value != console.value)
            {
              console.value = r.value;
              setConsoleCaretToEnd();
            }
          if (r.list.length > 0)
            game.console.log(r.list.join(', '));
          updateConsoleHint();
        }
      // previous command in history
      else if (e.code == 'ArrowUp')
        {
          if (game.console.getHistoryLength() == 0)
            return;
          e.preventDefault();
          if (consoleHistoryIndex == -1)
            {
              consoleHistoryDraft = console.value;
              consoleHistoryIndex = game.console.getHistoryLength();
            }
          if (consoleHistoryIndex > 0)
            consoleHistoryIndex--;
          console.value = game.console.getHistoryEntry(consoleHistoryIndex);
          setConsoleCaretToEnd();
          updateConsoleHint();
        }
      // next command in history
      else if (e.code == 'ArrowDown')
        {
          if (consoleHistoryIndex == -1)
            return;
          e.preventDefault();
          consoleHistoryIndex++;
          if (consoleHistoryIndex >= game.console.getHistoryLength())
            {
              consoleHistoryIndex = -1;
              console.value = consoleHistoryDraft;
            }
          else
            {
              console.value = game.console.getHistoryEntry(consoleHistoryIndex);
            }
          setConsoleCaretToEnd();
          updateConsoleHint();
        }
    }

// refresh the gray inline hint overlay from the current console input
  function updateConsoleHint()
    {
      var val = console.value;
      var h = game.console.completion.hint(val);
      if (h == '')
        {
          consoleHint.style.display = 'none';
          return;
        }
      consoleHint.style.display = '';
      // align the overlay box exactly over the textarea
      consoleHint.style.left = console.offsetLeft + 'px';
      consoleHint.style.top = console.offsetTop + 'px';
      consoleHint.style.width = console.offsetWidth + 'px';
      // mirror the textarea's exact computed font so the ghost lines up
      var cs = Browser.window.getComputedStyle(console);
      consoleHint.style.fontFamily = cs.fontFamily;
      consoleHint.style.fontSize = cs.fontSize;
      consoleHint.style.fontWeight = cs.fontWeight;
      consoleHint.style.lineHeight = cs.lineHeight;
      consoleHint.style.letterSpacing = cs.letterSpacing;
      consoleHint.style.height = cs.height;
      // transparent copy of typed text pushes the gray hint to the caret position
      consoleHint.innerHTML =
        '<span class="chint-pre">' + escapeHTML(val) + '</span>' +
        '<span class="chint-ghost">' + escapeHTML(h) + '</span>';
    }

// escapes html special chars for hint rendering
  function escapeHTML(s: String): String
    {
      s = StringTools.replace(s, '&', '&amp;');
      s = StringTools.replace(s, '<', '&lt;');
      s = StringTools.replace(s, '>', '&gt;');
      return s;
    }

// move console caret to the end
  function setConsoleCaretToEnd()
    {
      Browser.window.setTimeout(function () {
        untyped console.setSelectionRange(
          console.value.length,
          console.value.length);
      });
    }

// update HUD state from game state
  public function update()
    {
      if (game.location != LOCATION_REGION)
        {
          resetRegionTooltipHover();
          regionTooltip.hide();
        }
      if (game.location != LOCATION_AREA)
        aiTooltip.hide();
      updateActionList();
      // NOTE: before info because info uses its height
      updateActions();
      updateInfo();
      updateLog();
      updateMenu();
      updateGoals();
      updateTopbar();
      if (game.location == LOCATION_REGION)
        updateRegionTooltipHover(true);
      updateAITooltip();
      if (Const.isDebug)
        updateDebugInfo();
    }

// update topbar: turn counter (odometer tick), location name (decode) + coords
  function updateTopbar()
    {
      // turn advance: number rolls over, brackets/word flash (css via .tick)
      if (game.turns != lastTurn)
        {
          if (lastTurn >= 0)
            {
              topbarTurn.className = 'tick';
              var nv = game.turns;
              haxe.Timer.delay(function () topbarTurn.textContent = '' + nv, 140);
              haxe.Timer.delay(function () topbarTurn.className = '', 400);
            }
          else topbarTurn.textContent = '' + game.turns;
          lastTurn = game.turns;
        }

      // location name + coords from current scope
      var name = '';
      var coords = '';
      if (game.location == LOCATION_AREA)
        {
          name = game.area.name;
          coords = game.playerArea.x + ',' + game.playerArea.y;
        }
      else if (game.location == LOCATION_REGION)
        {
          name = game.playerRegion.currentArea.name;
          coords = game.playerRegion.x + ',' + game.playerRegion.y;
        }
      if (name == null)
        name = '';
      topbarCoords.textContent = coords;

      // area change: pin pings, name resolves out of glyph noise
      if (name != lastLocName)
        {
          lastLocName = name;
          if (topbarPinSvg != null)
            {
              topbarPinSvg.classList.remove('ping');
              topbarPinSvg.getBoundingClientRect(); // reflow to retrigger
              topbarPinSvg.classList.add('ping');
            }
          decodeLocation(name);
        }
    }

// resolve a location name left-to-right out of glyph noise (~.56s)
  function decodeLocation(name: String)
    {
      var glyphs = '▒░#@%&╪◊$';
      var frames = 14;
      var frame = 0;
      function step()
        {
          var n = Std.int(name.length * frame / frames);
          var buf = name.substr(0, n);
          for (i in n...name.length)
            buf += glyphs.charAt(Std.random(glyphs.length));
          topbarName.textContent = buf;
          frame++;
          if (frame <= frames)
            haxe.Timer.delay(step, 40);
          else topbarName.textContent = name;
        }
      step();
    }

// update event log display (newest row first, older rows decay via css)
  public function updateLog()
    {
      var arr = [for (l in game.hudMessageList) l];
      // newest message sits at the tail of the list; detect a genuinely new top row
      var topKey = (arr.length > 0 ?
        arr[arr.length - 1].msg + '|' + arr[arr.length - 1].turn + '|' + arr[arr.length - 1].cnt : '');
      var isNewTop = (topKey != '' && topKey != lastLogKey);
      lastLogKey = topKey;

      var buf = new StringBuf();
      var i = arr.length - 1;
      var first = true;
      while (i >= 0)
        {
          var l = arr[i];
          var cls = 'hud-row';
          if (l.col == COLOR_ALERT)
            cls += ' highlight-text';
          if (first && isNewTop)
            cls += ' hud-row-new';
          var ts = (l.turn == null || l.turn == 0 ? '-' : '' + l.turn);
          buf.add('<div class="' + cls + '"><span class="ts">' + ts + '</span>');
          buf.add('<span class="msg" style="color:' + Const.TEXT_COLORS[l.col] + '">' + l.msg + '</span>');
          if (l.cnt > 1)
            buf.add(' <span class="xn">(x' + l.cnt + ')</span>');
          buf.add('</div>');
          first = false;
          i--;
        }
      log.innerHTML = buf.toString();
    }

// update objectives list (diamond marks + vein spine connectors)
  function updateGoals()
    {
      var buf = new StringBuf();
      var primaryAssigned = false;
      for (g in game.goals.iteratorCurrent())
        {
          var gi = game.goals.getInfo(g);
          if (gi.isHidden)
            continue;
          // first non-optional goal is the primary beacon, the rest are secondary
          var primary = (!primaryAssigned && !gi.isOptional);
          if (primary)
            primaryAssigned = true;
          buf.add('<div class="hud-grp"><div class="hud-obj">');
          buf.add(UISvg.hudDiamond(primary));
          buf.add('<div><div class="hud-ot">' + gi.name);
          if (gi.isOptional)
            buf.add(' <span class="hud-opt">[optional]</span>');
          buf.add('</div><div class="hud-od">' + gi.note);
          if (gi.noteFunc != null)
            buf.add('<br/>' + gi.noteFunc(game));
          buf.add('</div></div></div></div>'); // close od, name-wrap, obj, grp
        }
      goals.innerHTML = buf.toString();
    }

// get color for text (red, yellow, white)
  function getColor(val: Float, max: Float): String
    {
      if (val > 0.7 * max)
        return "style='color:var(--text-color-white)'";
      else if (val > 0.3 * max)
        return "style='color:var(--text-color-yellow)'";

      return "style='color:var(--text-color-red)' class=blinking-red";
    }

// update cult info
  function updateCult(buf: StringBuf)
    {
      var cult = game.cults[0];
      if (cult.state != CULT_STATE_ACTIVE)
        return;

      var r = cult.resources;
      buf.add('<hr><span style="color:var(--text-color-gray)" class=small><span class=small>' +
        'COM ' + Const.col('cult-power', r.getShort('combat')) +
        ', MED ' + Const.col('cult-power', r.getShort('media')) +
        ', LAW ' + Const.col('cult-power', r.getShort('lawfare')) +
        ', COR ' + Const.col('cult-power', r.getShort('corporate')) +
        ', POL ' + Const.col('cult-power', r.getShort('political')) +
        ', ' + Const.col('cult-power', r.getShort('money')) + Icon.money +
        '</span></span><br/>');
    }

// build one stat bar: icon + label + value, track + fill, with warn/dead states
// stat tags drive per-stat warn color (hc warns purple); fillClass picks the gradient
  function statBar(stat: String, icon: String, label: String,
      cur: Int, max: Int, fillClass: String, ?delta: String = ''): String
    {
      var pct = (max > 0 ? cur / max * 100 : 0);
      if (pct < 0)
        pct = 0;
      if (pct > 100)
        pct = 100;
      var cls = 'hud-bar';
      if (cur <= 0)
        cls += ' dead';
      else if (cur <= 0.25 * max)
        cls += ' warn';
      return '<div class="' + cls + '" data-stat="' + stat + '">' +
        '<div class="hud-bar-lbl"><span class="hud-bar-n">' + icon + label + '</span>' +
        '<span class="hud-bar-v"><span class="cur">' + cur + '</span>/' + max + delta + '</span></div>' +
        '<div class="hud-bar-track"><div class="hud-bar-fill ' + fillClass +
        '" style="width:' + pct + '%"></div></div></div>';
    }

// update player info: core stats as bars, the rest as text below
  function updateInfo()
    {
      var buf = new StringBuf();
      if (state == HUD_BASE_BUILDING &&
          game.cults[0].base != null)
        {
          buf.add(game.cults[0].base.hudInfo());
          info.innerHTML = buf.toString();
          info.className = 'hud-panel hud-text';
          return;
        }

      var time = (game.location == LOCATION_AREA ? 1 : 5);

      // parasite bars
      var ppt = __Math.parasiteEnergyPerTurn(time);
      var pdelta = (ppt != 0 ?
        '<small class="' + (ppt > 0 ? 'up' : 'down') + '">' + (ppt > 0 ? '+' : '') + ppt + '/t</small>' : '');
      buf.add('<div class="hud-stats-player">');
      buf.add('<div class="hud-eyebrow">Parasite</div>');
      buf.add(statBar('ph', UISvg.hudEye(), 'Health',
        game.player.health, game.player.maxHealth, 'health'));
      buf.add(statBar('pe', UISvg.hudBolt(), 'Energy',
        game.player.energy, game.player.maxEnergy, 'energy', pdelta));
      buf.add('</div>');

      // attachment grip
      if (game.player.state == PLR_STATE_ATTACHED)
        buf.add(statBar('hc', UISvg.hudControl(), 'Grip',
          game.playerArea.attachHold, 100, 'control'));

      // host bars
      else if (game.player.state == PLR_STATE_HOST)
        {
          var host = game.player.host;
          var hname = (host.isHuman ? host.getNameCapped() : host.AName());
          if (host.affinity >= 100)
            hname += ' ' + Icon.affinity;
          if (host.chat.consent >= 100)
            hname += ' ' + Icon.consent;
          if (host.isPlayerCultist())
            hname += ' ' + Icon.cultist;
          buf.add('<div class="hud-eyebrow">Host</div>');
          buf.add('<div class="hud-hostname">' + hname + '</div>');
          buf.add(statBar('hh', UISvg.hudHeart(), 'Health',
            host.health, host.maxHealth, 'health'));
          var hpt = __Math.fullHostEnergyPerTurn(time);
          var hdelta = '';
          if (hpt != 0)
            hdelta = '<small class="' + (hpt > 0 ? 'up' : 'down') + '">' + (hpt > 0 ? '+' : '') + hpt + '/t</small>';
          if (hpt < 0)
            hdelta += '<small class="down">' + Math.ceil(host.energy / (- hpt)) + 't</small>';
          buf.add(statBar('he', UISvg.hudBolt(), 'Energy',
            host.energy, host.maxEnergy, 'energy', hdelta));
          buf.add(statBar('hc', UISvg.hudControl(), 'Control',
            game.player.hostControl, 100, 'control'));
        }

      // extra textual context below the bars
      var ex = new StringBuf();
      // action points / area notes
      if (game.location == LOCATION_AREA)
        {
          ex.add(Const.smallgray('AP ' + game.playerArea.ap) +
            (Const.isDebug ? Const.smallgray(' A ' + Math.round(game.area.alertness)) : '') + '<br/>');
          if (game.area.isMissionArea())
            ex.add('<center>' + Const.smallcol('profane-ordeal', 'mission area') + '</center>');
        }
      else if (game.location == LOCATION_REGION)
        {
          var area = game.playerRegion.currentArea;
          if (Const.isDebug)
            ex.add(Const.smallgray('A ' + Math.round(area.alertness)) + '<br/>');
          if (area.highCrime)
            ex.add('<center>' + Const.smallgray('high crime') + '</center>');
          if (game.cults.length > 0 &&
              game.cults[0].ordeals.getMarkerMission(area) != null)
            ex.add('<center>' + Const.smallcol('profane-ordeal', 'mission area') + '</center>');
        }
      // team distance if close
      game.group.hudInfo(ex);
      // host attributes, evolution direction, organs
      if (game.player.state == PLR_STATE_HOST)
        {
          var host = game.player.host;
          if (host.isAttrsKnown)
            ex.add('STR ' + host.strength +
              ' CON ' + host.constitution +
              ' INT ' + host.intellect +
              ' PSY ' + host.psyche + '<br/>');
          if (game.player.evolutionManager.isActive)
            {
              ex.add(Const.small('Evolution direction:<br/>  '));
              ex.add(Const.small(game.player.evolutionManager.getEvolutionDirectionInfo()) + '<br/>');
            }
          var str = host.organs.getInfo();
          if (str != null)
            ex.add(str);
        }
      // cult resources line
      updateCult(ex);
      if (game.player.vars.isSpoonGame)
        ex.add("<div style='padding-top:10px;text-align:center;font-weight:bold'>" +
          Const.col('yellow', 'SPOONED') + '</div>');
      var exStr = ex.toString();
      if (exStr != '')
        buf.add('<div class="hud-info-extra">' + exStr + '</div>');

      info.innerHTML = buf.toString();
      if (regionTooltip.visible)
        regionTooltip.updatePosition();
      // low parasite energy pulses the panel when not hosting
      if (game.player.state != PLR_STATE_HOST)
        info.className =
          (game.player.energy <= 0.5 * game.player.maxEnergy ?
           'hud-panel hud-text hud-stats highlight-text' : 'hud-panel hud-text hud-stats');
      else info.className = 'hud-panel hud-text hud-stats';
    }

// debug info
  function updateDebugInfo()
    {
      var buf = new StringBuf();
      buf.add(
        'Tile resolution: ' +
        Std.int(game.scene.canvas.width / Const.TILE_SIZE) + 'x' +
        Std.int(game.scene.canvas.height / Const.TILE_SIZE) +
        '<br>emptyScreenCells: ' + game.scene.area.emptyScreenCells +
        ', maxAI: ' + game.area.getMaxAI() + '<br>');
      if (!game.group.isKnown)
        buf.add('Group known count: ' + game.group.knownCount + '<br/>');
      buf.add('Group priority: ' + Const.round(game.group.priority) +
        ', team timeout: ' + game.group.teamTimeout + '<br/>');
      if (game.group.team != null)
        buf.add('Team: ' + game.group.team + '<br/>');
      buf.add('<br/>' + game.scene.getRegionRenderStatsText() + '<br/>');
      buf.add('<br/>' + game.scene.getAreaRenderStatsText() + '<br/>');
      if (game.location == LOCATION_AREA)
        game.managerArea.debugInfo(buf);
      debugInfo.innerHTML = buf.toString();
    }

// update menu buttons visibility
  function updateMenu()
    {
      if (state == HUD_TARGETING)
        {
          for (m in menuButtons)
            {
              m.btn.style.display = 'none';
              if (m.btn.className.indexOf('highlight') > 0)
                m.btn.className = 'hud-nav-cell';
            }
          return;
        }

      var vis = false;
      for (m in menuButtons)
        {
          vis = false;
          if (m.state == UISTATE_GOALS ||
              m.state == UISTATE_LOG ||
              m.state == UISTATE_OPTIONS ||
              m.state == UISTATE_DEBUG ||
              m.state == UISTATE_YESNO) // exit
            vis = true;

          else if (m.state == UISTATE_BODY)
            {
              if (game.player.vars.inventoryEnabled ||
                  game.player.vars.skillsEnabled ||
                  game.player.vars.organsEnabled)
                vis = true;
            }
          else if (m.state == UISTATE_TIMELINE)
            {
              if (game.player.vars.timelineEnabled)
                vis = true;
            }

          else if (m.state == UISTATE_EVOLUTION)
            {
              if (game.player.state == PLR_STATE_HOST &&
                  game.player.evolutionManager.state > 0)
                vis = true;
            }

          else if (m.state == UISTATE_CULT)
            {
              if (game.cults[0].state == CULT_STATE_ACTIVE)
                vis = true;
            }
          m.btn.style.display = (vis ? 'flex' : 'none');
          // clear highlight on hide
          // NOTE: must be the same with addMenuButton()
          if (!vis && m.btn.className.indexOf('highlight') > 0)
            m.btn.className = 'hud-nav-cell';
        }
    }

// update player actions list
  inline function updateActionList()
    {
      listActions = new List();
      listKeyActions = new List();
      if (state == HUD_TARGETING)
        return;
      if (state == HUD_BASE_BUILDING)
        {
          if (game.cults[0].base != null)
            game.cults[0].base.updateActionList();
          return;
        }
      if (game.state == GAMESTATE_FINISH)
        {
          addKeyAction({
            id: 'restart',
            type: (game.location == LOCATION_AREA ? ACTION_AREA : ACTION_REGION),
            name: Const.col('red', 'RESTART'),
            energy: 0,
            // fake
            key: 'r'
          });
          return;
        }
      if (state == HUD_COMMAND_MENU)
        {
          command.updateActions();
          return;
        }

      // trying to chat
      if (state == HUD_CHAT)
        game.player.chat.updateActionList();
      // pick AI to chat with
      else if (state == HUD_CONVERSE_MENU)
        game.player.chat.converseMenu();
      else
        {
          if (game.location == LOCATION_AREA)
            game.playerArea.updateActionList();

          else if (game.location == LOCATION_REGION)
            game.playerRegion.updateActionList();

          addKeyAction({
            id: 'skipTurn',
            type: (game.location == LOCATION_AREA ? ACTION_AREA : ACTION_REGION),
            name: 'Wait',
            energy: 0,
            // fake
            key: 'z'
          });

          if (game.location == LOCATION_AREA &&
              game.player.state == PLR_STATE_HOST)
            {
              addKeyAction({
                id: 'targetMode',
                type: ACTION_AREA,
                name: 'Target',
                key: 't',
                isVirtual: true,
              });

              if (targeting.canShootTarget())
                addKeyAction({
                  id: 'shootTarget',
                  type: ACTION_AREA,
                  name: 'Shoot',
                  key: 's',
                  isVirtual: true,
                });

              if (targeting.canAttackTarget())
                addKeyAction({
                  id: 'attackTarget',
                  type: ACTION_AREA,
                  name: 'Attack',
                  key: 'a',
                  isVirtual: true,
                });
            }

          if (game.location == LOCATION_AREA &&
              command.hasFollowers())
            addKeyAction({
              id: 'commandMenu',
              type: ACTION_AREA,
              name: 'Command',
              key: 'c',
              isVirtual: true,
            });
        }
      command.updateActions();
    }

// add player action to numbered list
// NOTE: needs to be the same checks as in Player.acitonEnergy()
  public function addAction(action: _PlayerAction)
    {
      // reduce cost when host is agreeable
      if (action.isAgreeable &&
          game.player.hostAgreeable())
        action.energy = 1;
      if (game.player.actionCheckEnergy(action))
        listActions.add(action);
    }

// add player action to key list
  public function addKeyAction(action: _PlayerAction)
    {
      if (game.player.actionCheckEnergy(action))
        listKeyActions.add(action);
    }

// update player actions
  public function updateActions()
    {
      // clear old items
      var n = 1;
      while (actions.firstChild != null)
        actions.removeChild(actions.lastChild);

      // show targeting help instead of actions
      if (state == HUD_TARGETING)
        {
          var lines = [
            { k: 'Arrows', t: 'Rotate targets' },
            { k: 'Enter/Numpad5', t: 'Select target' },
            { k: 'ESC', t: 'Clear target' },
          ];
          for (line in lines)
            {
              var btn = document.createDivElement();
              btn.className = 'hud-act hud-act-help';
              btn.innerHTML = '<span class="hud-key">' + line.k + '</span>' +
                '<span class="hud-label">' + line.t + '</span>';
              actions.appendChild(btn);
            }
          return;
        }

      // populate action list
      var list = [ listActions, listKeyActions ];
      for (l in list)
        for (act in l)
          {
            // key label: optional S- repeat prefix, then letter key or running number
            var key = '';
            if (game.config.shiftLongActions &&
                act.canRepeat &&
                ui.shiftPressed)
              key = 'S-';
            var numbered = (act.key == null);
            if (act.key != null)
              key += act.key.toUpperCase();
            else key += '' + n;
            var name = act.name;
            // dynamic action color
            if (act.id == 'probeBrain')
              name = game.playerArea.getProbeBrainActionName();
            // energy cost (literal or computed)
            var cost = -1;
            if (act.energy != null &&
                act.energy > 0)
              cost = act.energy;
            else if (act.energyFunc != null)
              cost = act.energyFunc(game.player);

            var btn = document.createDivElement();
            btn.className = 'hud-act';
            var html = '<span class="hud-key' + (numbered ? ' num' : '') + '">' + key + '</span>' +
              '<span class="hud-label">' + name + '</span>';
            if (cost > 0)
              html += '<span class="hud-cost">' + cost + UISvg.hudCoin() + '</span>';
            btn.innerHTML = html;
            var actionIndex = n;
            btn.onclick = function (e) {
              game.scene.sounds.play('click-action');
              if (state == HUD_COMMAND_MENU)
                action(actionIndex, untyped e.shiftKey);
              else doAction(untyped e.shiftKey, act);
            }
            actions.appendChild(btn);
            n++;
          }
      if (n == 1)
        actions.innerHTML = '<div class="hud-act hud-act-none">No available actions.</div>';
    }

// call numbered action by index
  public function action(index: Int, withRepeat: Bool)
    {
      if (state == HUD_COMMAND_MENU)
        {
          var usedTime = command.action(index);
          if (usedTime &&
              game.location == LOCATION_AREA)
            game.playerArea.actionPost();
          return;
        }

      // find action name by index
      var i = 1;
      var action = null;
      for (a in listActions)
        if (i++ == index)
          {
            action = a;
            break;
          }
      if (action == null)
        return;
      doAction(withRepeat, action);
    }

// common action code for keys and mouse clicks
  function doAction(withRepeat: Bool, action: _PlayerAction)
    {
      if (state == HUD_TARGETING)
        return;
      if (action.id == 'targetMode')
        {
          targeting.enter();
          return;
        }
      if (action.id == 'shootTarget')
        {
          if (targeting.canShootTarget())
            game.playerArea.attackTargetAction(targeting.target);
          return;
        }
      if (action.id == 'attackTarget')
        {
          if (targeting.canAttackTarget())
            game.playerArea.attackTargetAction(targeting.target, true);
          return;
        }
      if (action.id == 'commandMenu')
        {
          command.enter();
          return;
        }
      if (withRepeat &&
          game.config.shiftLongActions &&
          action.canRepeat)
        {
          if (game.location == LOCATION_AREA)
            game.playerArea.setAction(action);
/*
          else if (game.location == LOCATION_REGION)
            game.playerRegion.action(action);*/
          return;
        }

      if (action.type == ACTION_CHAT)
        game.player.chat.action(action);
      else if (action.type == ACTION_CONVERSE_MENU)
        game.player.chat.actionConverseMenu(action);
      else if (action.type == ACTION_HOST)
        game.player.host.action(action);
      else if (action.type == ACTION_INVENTORY)
        game.player.host.inventory.action(action);
      else if (game.location == LOCATION_AREA)
        game.playerArea.action(action);

      else if (game.location == LOCATION_REGION)
        game.playerRegion.action(action);
    }

// call action by key
  public function keyAction(key: String): Bool
    {
      var action = null;
      for (a in listKeyActions)
        if (a.key == key)
          {
            action = a;
            break;
          }
      if (action == null)
        return false;
      if (action.id == 'commandMenu')
        {
          command.enter();
          return true;
        }
      if (action.id == 'targetMode' ||
          action.id == 'shootTarget' ||
          action.id == 'attackTarget')
        return false;

      if (game.location == LOCATION_AREA)
        game.playerArea.action(action);

      else if (game.location == LOCATION_REGION)
        game.playerRegion.action(action);

      return true;
    }

// reset hud state to default
  public function resetState()
    {
      switch (state)
        {
          case HUD_CHAT:
            game.player.chat.finish();
            game.log('The conversation was interrupted.');
          case HUD_CONVERSE_MENU:
            state = HUD_DEFAULT;
          case HUD_TARGETING:
            targeting.exit(false);
          case HUD_COMMAND_MENU:
            command.exit();
          case HUD_BASE_BUILDING:
            state = HUD_DEFAULT;
          case HUD_DEFAULT:
            // do nothing
        }
    }
}
