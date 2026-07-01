// save/load slot picker window — manual slots + the autosave slot (load only)

package ui;

import js.Browser;
import js.html.DivElement;

import game.Game;

#if electron
class Saves extends UIWindow
{
  var mode: String = 'load'; // 'save' | 'load'
  var body: DivElement;      // .mods-body (slot rows)
  var title: DivElement;     // titlebar heading
  var rowEls: Array<DivElement> = []; // visible rows in display order (number-key targets)

  public function new(g: Game)
    {
      super(g, 'window-saves');

      addCorners();

      // titlebar: heading + subtitle (text set per-mode in rebuild)
      var titlebar = Browser.document.createDivElement();
      titlebar.className = 'mods-titlebar';
      title = Browser.document.createDivElement();
      title.className = 'mods-title';
      var sub = Browser.document.createDivElement();
      sub.className = 'mods-sub';
      sub.innerHTML = 'memory slots';
      titlebar.appendChild(title);
      titlebar.appendChild(sub);
      window.appendChild(titlebar);

      body = Browser.document.createDivElement();
      body.className = 'mods-body';
      window.appendChild(body);

      addWinClose(function (e) {
        game.scene.sounds.play('click-menu');
        game.scene.sounds.play('window-close');
        game.ui.state = UISTATE_MAINMENU;
      });
    }

// receive { mode } before the window opens
  public override function setParams(obj: Dynamic)
    {
      // trust boundary: untyped event payload assembled at the call site
      var o: { mode: String } = cast obj;
      mode = (o != null && o.mode != null ? o.mode : 'load');
    }

// rebuild the slot list for the current mode
  function rebuild()
    {
      body.innerHTML = '';
      rowEls = [];
      title.innerHTML = (mode == 'save' ? 'SAVE GAME' : 'LOAD GAME');

      // load mode: autosave slot pinned on top (load only) if present
      if (mode == 'load' &&
          game.saveExists(Game.AUTOSAVE_SLOT))
        addRow(Game.AUTOSAVE_SLOT);

      // manual slots 1..N
      var any = false;
      for (slot in 1...Game.MANUAL_SLOTS + 1)
        {
          var exists = game.saveExists(slot);
          if (mode == 'load' && !exists)
            continue; // load list shows filled slots only
          addRow(slot);
          any = true;
        }

      // empty-state hint (only the load list can end up empty)
      if (!any &&
          !(mode == 'load' && game.saveExists(Game.AUTOSAVE_SLOT)))
        {
          var empty = Browser.document.createDivElement();
          empty.className = 'win-empty';
          empty.innerHTML = 'No saved games yet.';
          body.appendChild(empty);
        }
    }

// one slot row: number + scenario/meta + status pill, wired to save/load
  function addRow(slot: Int)
    {
      var isAuto = (slot == Game.AUTOSAVE_SLOT);
      var exists = game.saveExists(slot);
      var meta = Loader.peekMeta(slot);

      var row = Browser.document.createDivElement();
      row.className = 'mods-row saves-row';
      if (isAuto)
        row.classList.add('saves-auto');
      else if (!exists)
        row.classList.add('saves-empty');
      body.appendChild(row);
      rowEls.push(row); // number-key target (1-based, display order)

      // slot number / autosave marker
      var num = Browser.document.createDivElement();
      num.className = 'saves-num';
      num.innerHTML = (isAuto ? UISvg.clockSmall() : (slot < 10 ? '0' : '') + slot);
      row.appendChild(num);

      // name + meta line
      var main = Browser.document.createDivElement();
      main.className = 'mods-main';
      var line = Browser.document.createDivElement();
      line.className = 'mods-line';
      var name = (meta != null ? meta.scenario : (exists ? 'Saved game' : 'Empty slot'));
      line.innerHTML = '<span class="mods-name">' + name + '</span>';
      main.appendChild(line);
      var sub = Browser.document.createDivElement();
      sub.className = 'mods-reason saves-meta';
      if (meta != null)
        sub.innerHTML = meta.area + ' · turn ' + meta.turns + ' · ' + relTime(meta.time);
      else if (exists)
        sub.innerHTML = 'no preview info';
      else
        sub.innerHTML = 'click to save here';
      main.appendChild(sub);
      row.appendChild(main);

      // status pill
      var status = Browser.document.createDivElement();
      status.className = 'mods-status ' +
        (isAuto ? 'st-active' : exists ? 'st-active' : 'st-off');
      status.innerHTML = (isAuto ? 'AUTOSAVE' : exists ? 'SAVED' : 'EMPTY');
      row.appendChild(status);

      // click: load (any existing slot) or save (manual slots, save mode)
      row.onclick = function (e) {
        if (mode == 'load')
          {
            if (!exists)
              return;
            doLoad(slot);
          }
        else if (!isAuto)
          {
            if (exists)
              confirmOverwrite(slot);
            else doSave(slot);
          }
      };
    }

// load a slot and reveal the game
  function doLoad(slot: Int)
    {
      game.scene.sounds.play('click-menu');
      game.load(slot);
      game.ui.closeWindow();
      game.ui.canvas.style.visibility = 'visible';
    }

// save into a slot (game.save handles difficulty prompt + caps), then close
  function doSave(slot: Int)
    {
      game.scene.sounds.play('click-menu');
      game.save(slot);
      game.ui.closeWindow();
    }

// confirm before clobbering a filled manual slot.
// back=SAVES handles cancel; YesNo runs dismiss() after func and would override
// any nav we did here, so the confirm action is deferred one tick to run after it.
  function confirmOverwrite(slot: Int)
    {
      var p: _YesNoParams = {
        text: 'Overwrite slot ' + slot + '?',
        sub: 'The save currently in this slot will be replaced.',
        danger: true,
        back: _UIState.UISTATE_SAVES,
        func: function(yes: Bool) {
          if (yes)
            Browser.window.setTimeout(function() doSave(slot), 0);
        }
      };
      game.ui.getComponent(UISTATE_YESNO).setParams(p);
      game.scene.sounds.play('window-open');
      game.ui.state = UISTATE_YESNO;
    }

// compact relative-time label from an epoch-ms timestamp
  function relTime(time: Float): String
    {
      var secs = Std.int((Date.now().getTime() - time) / 1000);
      if (secs < 60)
        return 'just now';
      if (secs < 3600)
        return Std.int(secs / 60) + 'm ago';
      if (secs < 86400)
        return Std.int(secs / 3600) + 'h ago';
      return Std.int(secs / 86400) + 'd ago';
    }

// number key 1..9 = nth visible row; pressButton dispatches its click for us
  public override function getButton(index: Int): js.html.Element
    {
      if (index < 1 ||
          index > rowEls.length)
        return null;
      return rowEls[index - 1];
    }

  override function hide(?skipAnimation: Bool = false)
    {
      animatedHide();
    }

  override function update()
    {
      rebuild();
    }
}
#end
