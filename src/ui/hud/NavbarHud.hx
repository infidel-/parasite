// hud navbar block: membrane strip of icon cells (window shortcuts)
package ui.hud;

import js.Browser.document;
import js.html.DivElement;

import game.*;

class NavbarHud
{
  var game: Game;
  var hud: HUD;
  var buttons: DivElement;
  var menuButtons: Array<{
    state: _UIState,
    btn: DivElement,
  }>;

  public function new(g: Game, h: HUD)
    {
      game = g;
      hud = h;
      buttons = document.createDivElement();
      buttons.id = 'hud-buttons';
      buttons.className = 'hud-panel';
      h.container.appendChild(buttons);
      menuButtons = [];
      addMenuButton(UISTATE_GOALS, UISvg.hudNavGoals(), 'Goals');
      addMenuButton(UISTATE_BODY, UISvg.hudNavBody(), 'Body');
      addMenuButton(UISTATE_LOG, UISvg.hudNavLog(), 'Log');
      addMenuButton(UISTATE_TIMELINE, UISvg.hudNavTimeline(), 'Timeline');
      addMenuButton(UISTATE_EVOLUTION, UISvg.hudNavEvo(), 'Evo');
      addMenuButton(UISTATE_CULT, UISvg.hudNavCult(), 'Cult');
    }

// add icon cell to navbar menu
  function addMenuButton(state: _UIState, icon: String, label: String): DivElement
    {
      var btn = document.createDivElement();
      btn.innerHTML = icon + '<span class="hud-nav-label">' + label + '</span>';
      btn.title = label;
      // NOTE: must be the same with show/hide buttons at update()
      btn.className = 'hud-nav-cell';
      buttons.appendChild(btn);
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

// update menu buttons visibility
  public function update()
    {
      if (hud.state == HUD_TARGETING)
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
}
