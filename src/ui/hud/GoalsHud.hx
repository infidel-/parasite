// hud objectives block: diamond marks + vein spine connectors
package ui.hud;

import js.Browser.document;
import js.html.DivElement;

import game.*;

class GoalsHud
{
  var game: Game;
  var goals: DivElement;
  var rows: Map<_Goal, DivElement>; // goalId -> row element; displayed set, lags the model
  var pending: Array<{ action: String, id: _Goal }>; // goal anims deferred until UI is idle

  public function new(g: Game, h: HUD)
    {
      game = g;
      rows = new Map();
      pending = [];
      goals = document.createDivElement();
      goals.className = 'hud-panel hud-text';
      goals.id = 'hud-goals';
      h.container.appendChild(goals);
    }

// build a row's inner HTML (diamond + name + note) for a goal
  function rowInner(g: _Goal, primary: Bool): String
    {
      var gi = game.goals.getInfo(g);
      var buf = new StringBuf();
      buf.add('<div class="hud-obj">');
      buf.add(UISvg.hudDiamond(primary));
      buf.add('<div><div class="hud-ot">' + gi.name);
      if (gi.isOptional)
        buf.add(' <span class="hud-opt">optional</span>');
      buf.add('</div><div class="hud-od">' + gi.note);
      if (gi.noteFunc != null)
        buf.add('<br/>' + gi.noteFunc(game));
      buf.add('</div></div></div>'); // close od, name-wrap, obj
      return buf.toString();
    }

// full instant resync from the model (no animation): init + post-load
  public function rebuild()
    {
      while (goals.firstChild != null)
        goals.removeChild(goals.lastChild);
      rows = new Map();
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
          var row = document.createDivElement();
          row.className = 'hud-grp';
          row.innerHTML = rowInner(g, primary);
          goals.appendChild(row);
          rows.set(g, row);
        }
    }

// refresh dynamic note text + primary/secondary beacon on displayed rows.
// add/remove is event-driven (playGoalEvent), so this never touches the row set
  public function update()
    {
      var primaryAssigned = false;
      for (g in game.goals.iteratorCurrent())
        {
          var row = rows.get(g);
          if (row == null) // not displayed (hidden, or arriving via a queued event)
            continue;
          var gi = game.goals.getInfo(g);
          var primary = (!primaryAssigned && !gi.isOptional);
          if (primary)
            primaryAssigned = true;
          row.innerHTML = rowInner(g, primary);
        }
    }

// defer a goal animation until the UI is idle (back to DEFAULT), so intervening
// windows (message, difficulty, ...) don't hide it; play now if already idle
  public function queue(action: String, id: _Goal)
    {
      pending.push({ action: action, id: id });
      if (game.ui.state == UISTATE_DEFAULT)
        flush();
    }

// play all deferred goal animations (UI returned to DEFAULT, HUD visible)
  public function flush()
    {
      for (g in pending)
        playGoalEvent(g.action, g.id);
      pending = [];
    }

// drop deferred goal animations without playing (load / reset)
  public function clearQueue()
    {
      pending = [];
    }

// play a goal change on the (now visible) HUD: appear / complete / fail
  function playGoalEvent(action: String, id: _Goal)
    {
      if (action == 'added')
        {
          if (rows.exists(id)) // already shown (rebuild beat the event)
            return;
          var gi = game.goals.tryGetInfo(id);
          if (gi == null || gi.isHidden)
            return;
          // arrival: row slides/flashes in, diamond pops (goal-new drives it)
          var row = document.createDivElement();
          row.className = 'hud-grp goal-new';
          row.innerHTML = rowInner(id, false);
          goals.appendChild(row);
          rows.set(id, row);
          update(); // recompute primary/secondary now that a row was added
          haxe.Timer.delay(function() row.classList.remove('goal-new'), 1500);
        }
      else // completed | failed
        {
          var row = rows.get(id);
          if (row == null)
            return;
          rows.remove(id);
          // phase 1: mark done/failed - strike line draws across the title, lingers
          var obj: js.html.Element = cast row.firstElementChild; // .hud-obj
          if (obj != null)
            obj.classList.add(action == 'failed' ? 'fail' : 'done');
          // phase 2: after the strike has been read, collapse the row away
          haxe.Timer.delay(function() collapseRow(row), 1000);
        }
    }

// collapse a finished goal row to zero height, then remove it
  function collapseRow(row: DivElement)
    {
      row.style.height = row.scrollHeight + 'px'; // fix height so it can transition to 0
      untyped row.offsetHeight; // force reflow
      row.classList.add('goal-clear');
      row.addEventListener('transitionend', function(e) {
        if (e.propertyName != 'height')
          return;
        if (row.parentNode != null)
          row.parentNode.removeChild(row);
        update();
      });
      // fallback if transitionend never fires
      haxe.Timer.delay(function() {
        if (row.parentNode != null)
          {
            row.parentNode.removeChild(row);
            update();
          }
      }, 600);
    }
}
