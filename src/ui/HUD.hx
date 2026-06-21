// new js ui hud — orchestrates per-block sub-classes in ui/hud/
package ui;

import js.Browser;
import js.Browser.document;
import js.html.DivElement;
import js.html.MouseEvent;

import game.*;
import ui.Targeting;
import ui.hud.*;

class HUD
{
  var game: Game;
  var ui: UI;
  public var state: _HUDState;
  var blinkingText: DivElement;
  var overlay: DivElement;
  public var container: DivElement;
  // background atmosphere layer (color grade + grain + veins)
  public var atmo: DivElement;
  // tooltips (shared by mouse glue and the stats block)
  public var regionTooltip: RegionTooltip;
  public var aiTooltip: AITooltip;
  // debug overlay div — created and updated only when Const.isDebug is true
  var debugInfo: DivElement;
  public var targeting: Targeting;
  public var command: Command;
  // per-block sub-classes (each owns its DOM, appended to container)
  var topbar: TopbarHud;
  var log: LogHud;
  var goals: GoalsHud;
  public var infoHud: InfoHud;
  var navbar: NavbarHud;
  var console: ConsoleHud;
  var actions: ActionsHud;
  var lastMouseX: Float = -1;
  var lastMouseY: Float = -1;
  var lastRegionTileX: Int = -1;
  var lastRegionTileY: Int = -1;

  // exposed for the region tooltip, which measures against the stats panel
  public var info(get, never): DivElement;
  inline function get_info(): DivElement
    return infoHud.info;

  public function new(u: UI, g: Game)
    {
      game = g;
      ui = u;
      state = HUD_DEFAULT;
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

      // per-block sub-classes
      console = new ConsoleHud(game, this);
      topbar = new TopbarHud(game, this);
      log = new LogHud(game, this);
      goals = new GoalsHud(game, this);
      infoHud = new InfoHud(game, this);

      if (Const.isDebug)
        {
          debugInfo = document.createDivElement();
          debugInfo.className = 'hud-panel hud-text';
          debugInfo.id = 'hud-debug-info';
          container.appendChild(debugInfo);
        }

      navbar = new NavbarHud(game, this);
      actions = new ActionsHud(game, this);
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

// get menu button (delegates to navbar block)
  public function getMenuButton(state: _UIState): DivElement
    return navbar.getMenuButton(state);

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

// console block delegates
  public function consoleVisible(): Bool
    return console.visible();

  public function showConsole()
    console.show();

  public function hideConsole()
    console.hide();

// update HUD state from game state
  public function update()
    {
      // drop the purple color-grade in region mode so map colors read true
      atmo.classList.toggle('region', game.location == LOCATION_REGION);
      if (game.location != LOCATION_REGION)
        {
          resetRegionTooltipHover();
          regionTooltip.hide();
        }
      if (game.location != LOCATION_AREA)
        aiTooltip.hide();
      actions.updateList();
      // NOTE: before info because info uses its height
      actions.updateActions();
      infoHud.update();
      log.update();
      navbar.update();
      goals.update();
      topbar.update();
      if (game.location == LOCATION_REGION)
        updateRegionTooltipHover(true);
      updateAITooltip();
      if (Const.isDebug)
        updateDebugInfo();
    }

// event log block delegate
  public function updateLog()
    log.update();

// action block delegates
  public function addAction(action: _PlayerAction)
    actions.addAction(action);

  public function addKeyAction(action: _PlayerAction)
    actions.addKeyAction(action);

  public function updateActions()
    actions.updateActions();

  public function action(index: Int, withRepeat: Bool)
    actions.action(index, withRepeat);

  public function keyAction(key: String): Bool
    return actions.keyAction(key);

// debug info
  function updateDebugInfo()
    {
      var buf = new StringBuf();
      buf.add('<div class="hud-eyebrow">Debug</div>');
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
