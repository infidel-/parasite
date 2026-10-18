// hud objectives block: diamond marks + vein spine connectors
package ui.hud;

import js.Browser.document;
import js.html.DivElement;

import game.*;

class GoalsHud
{
  var game: Game;
  var goals: DivElement;
  var eyebrow: DivElement; // "GOALS" word, only shown when fully collapsed
  var compactBtn: DivElement; // notes on/off
  var collapseBtn: DivElement; // whole list on/off
  var rows: Map<_Goal, DivElement>; // goalId -> row element; displayed set, lags the model
  var pending: Array<{ action: String, id: _Goal }>; // goal anims deferred until UI is idle
  var onSlideEnd: js.html.Event -> Void = null; // clears the FLIP height animation once done

  public function new(g: Game, h: HUD)
    {
      game = g;
      rows = new Map();
      pending = [];
      goals = document.createDivElement();
      goals.className = 'hud-panel hud-text';
      goals.id = 'hud-goals';
      h.container.appendChild(goals);

      // header bits are persistent: rebuild() clears the panel, these go back in
      eyebrow = document.createDivElement();
      eyebrow.className = 'hud-eyebrow';
      eyebrow.textContent = 'Goals';
      goals.appendChild(eyebrow);

      // compact-mode toggle: hides the goal notes, leaving the titles
      compactBtn = document.createDivElement();
      compactBtn.className = 'hud-compact-btn evolution-tip';
      compactBtn.setAttribute('data-tip', 'Compact goals');
      compactBtn.innerHTML = UISvg.hudCompact();
      compactBtn.onclick = function (e)
        {
          game.config.set('compactGoals', game.config.compactGoals ? '0' : '1', true);
          game.scene.sounds.play('click-hud');
          applyState(true);
        }
      goals.appendChild(compactBtn);

      // collapse toggle: folds the whole list away to the eyebrow word and a +
      collapseBtn = document.createDivElement();
      collapseBtn.className = 'hud-compact-btn evolution-tip goals-collapse';
      collapseBtn.onclick = function (e)
        {
          game.config.set('collapsedGoals', game.config.collapsedGoals ? '0' : '1', true);
          game.scene.sounds.play('click-hud');
          applyState(true);
        }
      goals.appendChild(collapseBtn);

      // slide done: drop the inline overrides so the panel sizes to content again
      onSlideEnd = function (e)
        {
          if (e.target != goals ||
              (cast e : js.html.TransitionEvent).propertyName != 'height')
            return; // a row's own collapse transition, not ours
          goals.style.height = '';
          goals.style.width = '';
          goals.style.overflow = '';
          goals.style.transition = '';
          goals.removeEventListener('transitionend', onSlideEnd);
        };
      applyState(false);
    }

// apply the panel's three states from config: full, notes hidden, fully collapsed.
// the panel is bottom-right anchored and sizes to its content, so a bare class
// swap pops - FLIP it instead: measure both layouts, then ease the box between
  function applyState(anim: Bool)
    {
      var fromH = 0;
      var fromW = 0;
      if (anim)
        {
          // cancel a slide still running and measure the layout we are leaving
          goals.removeEventListener('transitionend', onSlideEnd);
          goals.style.transition = 'none';
          goals.style.height = '';
          goals.style.width = '';
          fromH = goals.offsetHeight;
          fromW = goals.offsetWidth;
        }
      var collapsed = game.config.collapsedGoals;
      goals.classList.toggle('hud-compact', game.config.compactGoals);
      goals.classList.toggle('hud-collapsed', collapsed);
      compactBtn.classList.toggle('active', game.config.compactGoals);
      collapseBtn.textContent = (collapsed ? '+' : '−');
      collapseBtn.setAttribute('data-tip', collapsed ? 'Expand goals' : 'Collapse goals');
      collapseBtn.classList.toggle('active', collapsed);
      if (!anim)
        return;
      var toH = goals.offsetHeight;
      var toW = goals.offsetWidth;
      if (toH == fromH && toW == fromW) // nothing to ease, and no transitionend to clean up after
        return;
      // start at the old box with the content clipped, ease to the new one
      goals.style.overflow = 'hidden';
      goals.style.height = fromH + 'px';
      goals.style.width = fromW + 'px';
      goals.getBoundingClientRect(); // force reflow so the start size sticks
      goals.style.transition = 'height 0.3s ease, width 0.3s ease';
      goals.style.height = toH + 'px';
      goals.style.width = toW + 'px';
      goals.addEventListener('transitionend', onSlideEnd);
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
      goals.appendChild(eyebrow); // cleared with the rows, put back
      goals.appendChild(compactBtn);
      goals.appendChild(collapseBtn);
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
