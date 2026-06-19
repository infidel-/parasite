// evolution GUI window — controlled-evolution improvement cards

package ui;

import js.Browser;
import js.html.DivElement;
import js.html.Element;
import js.html.ImageElement;
import js.html.SpanElement;
import mods.AssetPath;

import game.Game;
import game.Improv;
import const.EvolutionConst;

class Evolution extends UIWindow
{
  static inline var SVGNS = 'http://www.w3.org/2000/svg';

  var stats: SpanElement;
  var grid: DivElement;
  var footer: DivElement;
  var listActions: Array<_PlayerAction>;
  // imp by string id, so delegated card/toggle handlers can recompute detail
  var impByID: Map<String, Improv>;
  // remembered CUR/NEXT toggle state per card (persists across rebuilds)
  var nextState: Map<String, Bool>;
  // shared floating thumbnail preview + projection beam (appended to body)
  var prevEl: DivElement;
  var prevImg: ImageElement;
  var prevCap: SpanElement;
  var linkEl: Element;
  var poly: Element;
  var line1: Element;
  var line2: Element;
  var dot1: Element;
  var dot2: Element;
  var trackID: Int;
  var trackThumb: Element;
  var scrollTimer: Int;

  public function new(g: Game)
    {
      super(g, 'window-evolution');
      listActions = [];
      impByID = new Map();
      nextState = new Map();

      // shared HUD chrome: scrim + DNA helix glyph, frame, corners, veins, "EVO" watermark
      addHudChrome('EVO', UISvg.helix());

      // title row: name left, stat-chip strip right
      var title = Browser.document.createDivElement();
      title.className = 'win-title win-titlebar';
      title.innerHTML = '<span class="wt">EVOLUTION</span>';
      stats = Browser.document.createSpanElement();
      stats.className = 'win-stats';
      title.appendChild(stats);
      window.appendChild(title);

      // improvements list (grid of cards) fills the body
      var listEl = Browser.document.createDivElement();
      listEl.className = 'evolution-list';
      grid = Browser.document.createDivElement();
      grid.className = 'hud-scroll evolution-grid';
      listEl.appendChild(grid);
      window.appendChild(listEl);

      // footer: lone Stop-evolution action (shown while evolving)
      footer = Browser.document.createDivElement();
      footer.className = 'evolution-footer';
      window.appendChild(footer);

      addWinClose();
      buildPreview();
      wireGrid();
    }

// difficulty-capped maximum level for an improvement
  function maxLevelOf(imp: Improv): Int
    {
      var diff = game.player.evolutionManager.difficulty;
      var maxLevel = imp.info.maxLevel;
      if (imp.info.id == IMP_BRAIN_PROBE || diff == EASY)
        return maxLevel;
      else if (diff == NORMAL && maxLevel > 2)
        maxLevel = 2;
      else if (diff == HARD && maxLevel > 1)
        maxLevel = 1;
      return maxLevel;
    }

// level-state prose for the current view (suppressed when empty/fluff/todo); next adds the delta
  function levelNoteHTML(imp: Improv, next: Bool, maxLevel: Int): String
    {
      var ln = imp.info.levelNotes[imp.level];
      if (ln == null)
        ln = '';
      var low = ln.toLowerCase();
      if (ln == '' || low.indexOf('fluff') >= 0 || low.indexOf('todo') >= 0)
        return '';
      var s = ln;
      if (next && imp.level + 1 <= maxLevel)
        s += ' <span class="arr">&rarr;</span> ' + (imp.info.levelNotes[imp.level + 1] != null ? imp.info.levelNotes[imp.level + 1] : '');
      return '<span class="evolution-lvl-note">' + s + '</span>';
    }

// mechanical params (noteFunc); split on <br> into .pp cells so >1 fact lays out in 2 columns
  function paramsHTML(imp: Improv, next: Bool, maxLevel: Int): String
    {
      if (imp.info.noteFunc == null)
        return '';
      var isMax = imp.level + 1 > maxLevel;
      var l2 = (next && !isMax ? imp.info.levelParams[imp.level + 1] : null);
      var raw = imp.info.noteFunc(imp.info.levelParams[imp.level], l2);
      var cells = [];
      for (c in (~/<br\s*\/?>/i).split(raw))
        {
          var t = StringTools.trim(c);
          if (t != '')
            cells.push(t);
        }
      var buf = new StringBuf();
      buf.add('<span class="evolution-params' + (cells.length > 1 ? ' multi' : '') + '">');
      for (c in cells)
        buf.add('<span class="pp">' + c + '</span>');
      buf.add('</span>');
      return buf.toString();
    }

// full per-card detail block contents (level note + params)
  function detailHTML(imp: Improv, next: Bool, maxLevel: Int): String
    {
      return levelNoteHTML(imp, next, maxLevel) + paramsHTML(imp, next, maxLevel);
    }

// post-layout flags: no-lvl (no level note collapsed) + has-more (note overflows or has params)
  function refreshMore(card: Element, imp: Improv, next: Bool, maxLevel: Int)
    {
      card.classList.toggle('no-lvl', levelNoteHTML(imp, next, maxLevel) == '');
      var note = card.querySelector('.evolution-note');
      var noteOver = note.scrollHeight - note.clientHeight > 1;
      card.classList.toggle('has-more', noteOver || imp.info.noteFunc != null);
    }

// update window contents
  override function update()
    {
      var ept = __Math.epPerTurn();
      var energyPerTurn = __Math.evolutionEnergyPerTurn();

      // stat chips: energy/turn, ep/turn, host survival turns
      stats.innerHTML =
        '<span class="statchip evolution-tip energy" data-tip="Energy spent per turn while evolving">' +
          UISvg.bolt() + energyPerTurn + '<i>/t</i></span>' +
        '<span class="statchip evolution-tip ep" data-tip="Evolution points gained per turn">' +
          UISvg.star() + ept + '<i>/t</i></span>' +
        '<span class="statchip evolution-tip host" data-tip="Turns the host survives while evolving">' +
          UISvg.clockSmall() + Std.int(game.player.host.energy / energyPerTurn) + '</span>';

      // cards
      impByID = new Map();
      listActions = [];
      var isActive = game.player.evolutionManager.isActive;

      // stop action occupies hotkey 1 while evolving
      if (isActive)
        listActions.push({ id: 'stop', type: ACTION_EVOLUTION, name: 'Stop evolution', energy: 0 });

      var buf = new StringBuf();
      var i = 0;
      for (imp in game.player.evolutionManager)
        {
          impByID.set(imp.id, imp);
          var maxLevel = maxLevelOf(imp);
          var isMax = imp.level >= maxLevel;
          var isNow = isActive && game.player.evolutionManager.taskID == imp.id;
          var next = nextState.exists(imp.id) && nextState.get(imp.id);

          // upgradeable cards get a hotkey + an action entry
          var key = 0;
          if (!isMax)
            {
              listActions.push({ id: 'set.' + imp.id, type: ACTION_EVOLUTION, name: imp.info.name, energy: 0 });
              key = listActions.length;
            }

          var cls = 'evolution-card' + (isNow ? ' now' : '') + (isMax ? ' maxed' : '');
          buf.add('<button class="' + cls + '" data-imp="' + imp.id + '" style="--i:' + i + '"' + (isMax ? ' disabled' : '') + '>');
          var src = AssetPath.resolve('img/imp/' + (imp.id : String).toLowerCase() + '.jpg');
          buf.add('<span class="evolution-thumb"><img src="' + src + '" alt=""></span>');
          buf.add('<span class="evolution-bodycol">');

          // head: name + level indicator (or MAX) + CUR/NEXT toggle
          buf.add('<span class="evolution-head"><span class="evolution-name">' + imp.info.name + '</span>');
          if (isMax)
            buf.add('<span class="evolution-max">&#10003; MAX</span>');
          else
            {
              buf.add('<span class="evolution-lv">' +
                (imp.info.maxLevel > 1 ? imp.level + ' ' : '') +
                '<span class="arr">&rarr;</span> ' + (imp.level + 1) + '</span>');
              buf.add('<span class="evolution-tg" role="group" aria-label="level detail">' +
                '<span class="seg' + (!next ? ' on' : '') + '" data-s="cur">CUR</span>' +
                '<span class="seg' + (next ? ' on' : '') + '" data-s="next">NEXT</span></span>');
            }
          buf.add('</span>');

          // note + level detail
          buf.add('<span class="evolution-note">' + imp.info.note + '</span>');
          buf.add('<span class="evolution-detail">' + detailHTML(imp, next, maxLevel) + '</span>');

          // foot: EP bar + cost + turns + hotkey (only when upgradeable)
          if (!isMax)
            {
              var cost = EvolutionConst.epCostImprovement[imp.level];
              var fill = Std.int(imp.ep / cost * 100);
              var turns = Math.round((cost - imp.ep) / ept);
              buf.add('<span class="evolution-foot">');
              buf.add('<span class="evolution-bar"><span class="fill" style="width:' + fill + '%"></span></span>');
              buf.add('<span class="evolution-ep">' + imp.ep + '/' + cost + ' ' + UISvg.star('evolution-ico evolution-ico-ep') + '</span>');
              buf.add('<span class="evolution-meta"><span class="evolution-turns">' + UISvg.clockSmall('evolution-ico evolution-ico-time') + turns + '</span>' +
                '<span class="evolution-key">' + key + '</span></span>');
              buf.add('</span>');
            }
          buf.add('</span>'); // bodycol

          buf.add('<span class="evolution-more" aria-hidden="true"><i></i><i></i><i></i></span>');
          if (isNow)
            buf.add('<span class="evolution-tag">EVOLVING</span>');
          buf.add('</button>');
          i++;
        }
      if (i == 0)
        buf.add('<div class="evolution-empty">No improvements available.</div>');
      grid.innerHTML = buf.toString();

      // footer stop button (shown while evolving)
      if (isActive)
        footer.innerHTML = '<button class="evolution-stop"><span class="sq"></span>Stop evolution</button>';
      else footer.innerHTML = '';

      // re-flag has-more / no-lvl once laid out (note overflow needs real metrics)
      Browser.window.requestAnimationFrame(function(_) {
        for (id in impByID.keys())
          {
            var card = grid.querySelector('.evolution-card[data-imp="' + id + '"]');
            if (card == null)
              continue;
            var imp = impByID.get(id);
            refreshMore(card, imp, nextState.exists(id) && nextState.get(id), maxLevelOf(imp));
          }
      });
    }

// run an upgrade/stop action and refresh
  function runAction(a: _PlayerAction)
    {
      game.scene.sounds.play('click-action');
      game.player.evolutionManager.action(a);
      update();
      game.ui.hud.update();
    }

// keyboard hotkey dispatch (1..N)
  public override function action(index: Int)
    {
      var a = listActions[index - 1];
      if (a == null)
        return;
      runAction(a);
    }

// delegate card clicks (upgrade), CUR/NEXT toggle, thumbnail preview, scroll suppression
  function wireGrid()
    {
      grid.onclick = function(e) {
        var t: Element = cast e.target;
        // CUR/NEXT toggle takes priority over the card's upgrade click
        var seg = t.closest('.evolution-tg .seg');
        if (seg != null)
          {
            e.preventDefault();
            e.stopPropagation();
            toggleDetail(seg);
            return;
          }
        var card = t.closest('.evolution-card');
        if (card == null || card.classList.contains('maxed'))
          return;
        var id = card.getAttribute('data-imp');
        var imp = impByID.get(id);
        if (imp == null)
          return;
        runAction({ id: 'set.' + imp.id, type: ACTION_EVOLUTION, name: imp.info.name, energy: 0 });
      };

      // footer stop (rebuilt each update, so delegate from the window)
      footer.onclick = function(e) {
        var t: Element = cast e.target;
        if (t.closest('.evolution-stop') == null)
          return;
        for (a in listActions)
          if (a.id == 'stop')
            { runAction(a); break; }
      };

      // floating thumbnail preview
      grid.addEventListener('mouseover', function(e) {
        var t: Element = cast e.target;
        var thumb = t.closest('.evolution-thumb');
        if (thumb != null)
          showPreview(thumb);
      });
      grid.addEventListener('mouseout', function(e) {
        var t: Element = cast e.target;
        var thumb = t.closest('.evolution-thumb');
        var rel: Element = cast e.relatedTarget;
        if (thumb != null && (rel == null || !thumb.contains(rel)))
          hidePreview();
      });

      // suppress hover-expand while scrolling; preview coords go stale once the grid moves
      grid.addEventListener('scroll', function(e) {
        grid.classList.add('scrolling');
        hidePreview();
        Browser.window.clearTimeout(scrollTimer);
        scrollTimer = Browser.window.setTimeout(function() {
          grid.classList.remove('scrolling');
        }, 120);
      });
    }

// CUR/NEXT toggle: fade the detail out, swap contents mid-fade, fade back in
  function toggleDetail(seg: Element)
    {
      var card = seg.closest('.evolution-card');
      if (card == null)
        return;
      var id = card.getAttribute('data-imp');
      var imp = impByID.get(id);
      if (imp == null)
        return;
      var next = seg.getAttribute('data-s') == 'next';
      nextState.set(id, next);
      for (s in card.querySelectorAll('.evolution-tg .seg'))
        (cast s : Element).classList.toggle('on', s == seg);
      var det = card.querySelector('.evolution-detail');
      det.classList.add('swapping');
      var maxLevel = maxLevelOf(imp);
      haxe.Timer.delay(function() {
        det.innerHTML = detailHTML(imp, next, maxLevel);
        refreshMore(card, imp, next, maxLevel);
        det.classList.remove('swapping');
      }, 130);
    }

// build the shared preview plate + projection-beam overlay (once, on <body>)
  function buildPreview()
    {
      prevEl = Browser.document.createDivElement();
      prevEl.className = 'evolution-preview';
      prevEl.innerHTML = '<img alt=""><span class="evolution-preview-cap"></span>';
      Browser.document.body.appendChild(prevEl);
      prevImg = cast prevEl.querySelector('img');
      prevCap = cast prevEl.querySelector('.evolution-preview-cap');

      linkEl = Browser.document.createElementNS(SVGNS, 'svg');
      linkEl.setAttribute('class', 'evolution-preview-link');
      poly = Browser.document.createElementNS(SVGNS, 'polygon');
      line1 = Browser.document.createElementNS(SVGNS, 'line');
      line2 = Browser.document.createElementNS(SVGNS, 'line');
      line1.setAttribute('pathLength', '1');
      line2.setAttribute('pathLength', '1');
      dot1 = Browser.document.createElementNS(SVGNS, 'circle');
      dot2 = Browser.document.createElementNS(SVGNS, 'circle');
      dot1.setAttribute('r', '3');
      dot2.setAttribute('r', '3');
      linkEl.appendChild(poly);
      linkEl.appendChild(line1);
      linkEl.appendChild(line2);
      linkEl.appendChild(dot1);
      linkEl.appendChild(dot2);
      Browser.document.body.appendChild(linkEl);
    }

  inline function setLine(ln: Element, x1: Float, y1: Float, x2: Float, y2: Float)
    {
      ln.setAttribute('x1', '' + x1);
      ln.setAttribute('y1', '' + y1);
      ln.setAttribute('x2', '' + x2);
      ln.setAttribute('y2', '' + y2);
    }

// geometry only (re-run every frame while the card settles after expand/lift)
  function positionPreview(thumb: Element)
    {
      var card = thumb.closest('.evolution-card');
      if (card == null)
        return;
      var vw = Browser.window.innerWidth;
      var vh = Browser.window.innerHeight;
      var w = Math.round(vw * 0.30);
      var h = Math.round(w * 9 / 16);
      var pad = 14;
      prevEl.style.width = w + 'px';
      var cr = card.getBoundingClientRect();
      var tr = thumb.getBoundingClientRect();
      var left = cr.right + pad;
      var side = 1;
      if (left + w > vw - 12)
        {
          left = cr.left - pad - w;
          side = -1;
        }
      left = Math.max(12, Math.min(vw - 12 - w, left));
      var top = tr.top + tr.height / 2 - h / 2;
      top = Math.max(12, Math.min(vh - 12 - h, top));
      prevEl.style.left = left + 'px';
      prevEl.style.top = top + 'px';

      // beam: thumb facing edge -> preview facing edge; ends tuck past the rounded corners
      var pedge = (side > 0 ? left : left + w);
      var ov = 16, sp = 14, ovT = 12, spT = 12;
      var tx = (side > 0 ? tr.right : tr.left) - side * ovT;
      var tyT = tr.top + spT;
      var tyB = tr.bottom - spT;
      var px = pedge + side * ov;
      var pyT = top + sp;
      var pyB = top + h - sp;
      linkEl.setAttribute('width', '' + vw);
      linkEl.setAttribute('height', '' + vh);
      setLine(line1, tx, tyT, px, pyT);
      setLine(line2, tx, tyB, px, pyB);
      poly.setAttribute('points', tx + ',' + tyT + ' ' + tx + ',' + tyB + ' ' + px + ',' + pyB + ' ' + px + ',' + pyT);
      dot1.setAttribute('cx', '' + tx);
      dot1.setAttribute('cy', '' + tyT);
      dot2.setAttribute('cx', '' + tx);
      dot2.setAttribute('cy', '' + tyB);
    }

// show the floating preview for a thumbnail; track the card as it settles
  function showPreview(thumb: Element)
    {
      var card = thumb.closest('.evolution-card');
      if (card == null)
        return;
      var img: ImageElement = cast thumb.querySelector('img');
      if (img == null || img.src == '')
        return;
      prevImg.src = img.src;
      var name = card.querySelector('.evolution-name');
      prevCap.textContent = (name != null ? name.textContent : '');
      positionPreview(thumb);
      prevEl.classList.add('show');
      // restart the draw-in even on a direct thumb -> thumb move
      linkEl.classList.remove('show');
      untyped linkEl.offsetWidth;
      linkEl.classList.add('show');

      Browser.window.cancelAnimationFrame(trackID);
      trackThumb = thumb;
      var start = Browser.window.performance.now();
      function track(now: Float)
        {
          if (trackThumb != thumb)
            return;
          positionPreview(thumb);
          if (now - start < 420)
            trackID = Browser.window.requestAnimationFrame(track);
        }
      trackID = Browser.window.requestAnimationFrame(track);
    }

  function hidePreview()
    {
      Browser.window.cancelAnimationFrame(trackID);
      trackThumb = null;
      prevEl.classList.remove('show');
      linkEl.classList.remove('show');
    }

  override function hide(?skipAnimation: Bool = false)
    {
      hidePreview();
      animatedHide();
    }
}
