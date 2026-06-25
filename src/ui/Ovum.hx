// ovum GUI window — parthenogenesis improvement selector (evolution-style cards, amber)

package ui;

import mods.AssetPath;
import js.Browser;
import js.html.DivElement;
import js.html.Element;
import js.html.SpanElement;

import game.Game;
import game.Improv;
import const.EvolutionConst;

class Ovum extends UIWindow
{
  var stats: SpanElement;
  var grid: DivElement;
  var listActions: Array<_PlayerAction>;
  // imp by string id, so delegated card handlers can toggle without index threading
  var impByID: Map<String, Improv>;
  // a toggle rebuild suppresses the entrance stagger and pulses only the changed card
  var suppressRise: Bool;
  var pulseID: String;

  public function new(g: Game)
    {
      super(g, 'window-ovum');
      listActions = [];
      impByID = new Map();

      // shared HUD chrome (amber), faint ovum image backdrop in place of the glyph
      addHudChrome('OVA', '');
      window.insertAdjacentHTML('afterbegin',
        '<div class="ovum-backdrop"><img src="' + AssetPath.resolve('img/imp/imp_ovum.jpg') + '" alt=""></div>');

      // title row: name left, ovum stat pills right
      var title = Browser.document.createDivElement();
      title.className = 'win-title win-titlebar';
      title.innerHTML = '<span class="wt">PARTHENOGENESIS</span>';
      stats = Browser.document.createSpanElement();
      stats.className = 'win-stats';
      title.appendChild(stats);
      window.appendChild(title);

      // improvement card grid fills the body
      var listEl = Browser.document.createDivElement();
      listEl.className = 'evolution-list';
      grid = Browser.document.createDivElement();
      grid.className = 'hud-scroll evolution-grid';
      listEl.appendChild(grid);
      window.appendChild(listEl);

      addWinClose();
      wireGrid();
    }

// update window contents
  override function update()
    {
      var ovum = game.player.evolutionManager.ovum;

      // count basic improvements marked for parthenogenesis
      var cntLocked = 0;
      for (imp in game.player.evolutionManager)
        if (imp.info.type == TYPE_BASIC
            && imp.isLocked)
          cntLocked++;
      var cap = ovum.level;

      // info pills: ovum level + points (xp/next) + marked/cap
      var pts = (ovum.level < 5
        ? ovum.xp + '/' + EvolutionConst.ovumXP[ovum.level]
        : 'MAX');
      stats.innerHTML =
        '<span class="statchip evolution-tip ovum-lvl" data-tip="Ovum level — how many improvements you may mark">' + UISvg.star() + 'LVL ' + ovum.level + '</span>' +
        '<span class="statchip evolution-tip ovum-pts" data-tip="Nurture points toward the next ovum level">' + pts + ' pts</span>' +
        '<span class="statchip evolution-tip ovum-mark" data-tip="Improvements marked to carry through parthenogenesis">' + cntLocked + '/' + cap + ' marked</span>';

      // cards: every basic improvement, click toggles its mark (capped at ovum level)
      impByID = new Map();
      listActions = [];
      var buf = new StringBuf();
      var i = 0;
      for (imp in game.player.evolutionManager)
        {
          if (imp.info.type != TYPE_BASIC)
            continue;
          impByID.set(imp.id, imp);
          var marked = imp.isLocked;
          // unmarked cards are locked out once the cap is reached
          var lockedOut = (!marked && cntLocked >= cap);

          // actionable cards get a hotkey + an action entry
          var key = 0;
          if (!lockedOut)
            {
              listActions.push({ id: 'toggle.' + imp.id, type: ACTION_UI, name: imp.info.name, energy: 0, obj: imp });
              key = listActions.length;
            }

          var cls = 'evolution-card ovum-card'
            + (marked ? ' marked' : '')
            + (lockedOut ? ' maxed' : '');
          buf.add('<button class="' + cls + '" data-imp="' + imp.id + '" style="--i:' + i + '"' + (lockedOut ? ' disabled' : '') + '>');
          var src = AssetPath.resolve('img/imp/' + (imp.id : String).toLowerCase() + '.jpg');
          buf.add('<span class="evolution-thumb"><img src="' + src + '" alt=""></span>');
          buf.add('<span class="evolution-bodycol">');

          // head: name + level + marked tag / hotkey
          buf.add('<span class="evolution-head"><span class="evolution-name">' + imp.info.name + '</span>');
          if (imp.info.maxLevel > 1)
            buf.add('<span class="evolution-lv">Lv ' + imp.level + '</span>');
          buf.add('<span class="ovum-badge">' +
            (marked ? '&#10003; MARKED' : (key > 0 ? '<span class="evolution-key">' + key + '</span>' : '')) +
            '</span>');
          buf.add('</span>');

          buf.add('<span class="evolution-note">' + imp.info.note + '</span>');
          buf.add('</span>'); // bodycol
          buf.add('</button>');
          i++;
        }
      if (i == 0)
        buf.add('<div class="evolution-empty">No improvements available.</div>');
      grid.innerHTML = buf.toString();

      // a toggle rebuild skips the entrance stagger; only the changed card pulses
      grid.classList.toggle('no-rise', suppressRise);
      if (suppressRise
          && pulseID != null)
        {
          var c = grid.querySelector('.evolution-card[data-imp="' + pulseID + '"]');
          if (c != null)
            c.classList.add('pulse');
        }
    }

// delegate card clicks to a mark toggle (locked-out cards ignored)
  function wireGrid()
    {
      grid.onclick = function(e) {
        var t: Element = cast e.target;
        var card = t.closest('.evolution-card');
        if (card == null
            || card.classList.contains('maxed'))
          return;
        var imp = impByID.get(card.getAttribute('data-imp'));
        if (imp == null)
          return;
        toggle(imp);
      };
    }

// keyboard hotkey dispatch (1..N)
  public override function action(index: Int)
    {
      var a = listActions[index - 1];
      if (a == null)
        return;
      toggle(a.obj);
    }

// the card for hotkey index, so keyboard shortcuts click/animate it
  public override function getButton(index: Int): js.html.Element
    {
      var a = listActions[index - 1];
      if (a == null)
        return null;
      // 'toggle.<impID>' -> the matching card
      return grid.querySelector('.evolution-card[data-imp="' + a.id.substr(7) + '"]');
    }

// flip an improvement's parthenogenesis mark and refresh
  function toggle(imp: Improv)
    {
      game.scene.sounds.play('click-action');
      imp.isLocked = !imp.isLocked;
      // in-place refresh: no entrance stagger, pulse the toggled card only
      suppressRise = true;
      pulseID = imp.id;
      update();
      suppressRise = false;
      pulseID = null;
      game.ui.hud.update();
    }

  override function hide(?skipAnimation: Bool = false)
    {
      animatedHide();
    }
}
