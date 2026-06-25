// hud info block: core stats as bars, the rest as text below.
// built once as a persistent skeleton; update() pokes data in place so CSS
// transitions (compact toggle, bar fills) survive turn updates
package ui.hud;

import js.Browser.document;
import js.html.Element;
import js.html.DivElement;
import js.html.SpanElement;

import game.*;

// live refs into one persistent stat bar
typedef BarRefs = {
  box: DivElement,    // .hud-bar[data-stat]
  lbl: SpanElement,   // .hud-bar-lbl-txt (stat name word)
  val: SpanElement,   // .hud-bar-v (value readout)
  fill: DivElement,   // .hud-bar-fill
  track: DivElement,  // .hud-bar-track
}

class InfoHud
{
  var game: Game;
  var hud: HUD;
  public var info: DivElement; // exposed: region tooltip measures against it
  var prevStat: Map<String, Int> = new Map(); // last rendered value per data-stat (change diff)
  var statMax: Map<String, Int> = new Map(); // last rendered max per data-stat (cost preview)

  // persistent skeleton refs
  var compactBtn: DivElement;
  var baseInfo: DivElement; // base-building takeover region
  var playerSection: DivElement;
  var hostSection: DivElement;
  var hostEyebrow: DivElement;
  var hostname: DivElement;
  var hostnameText: SpanElement;
  var hostnameBadges: SpanElement;
  var extraWrap: DivElement;
  var regionContext: DivElement; // area notes + team info
  var evoStrip: DivElement; // evolution direction + organs
  var cultLine: DivElement; // cult resources
  var spoonMark: DivElement; // SPOONED marker
  var bars: Map<String, BarRefs> = new Map();
  var regionCache: Map<String, String> = new Map(); // last html per region (skip unchanged writes)
  var prevCultVals: Array<String> = []; // last cult resource value texts (change pulse)
  var prevEvo: Map<String, String> = new Map(); // last evo/organ turn-eta per row name (change pulse)

  public function new(g: Game, h: HUD)
    {
      game = g;
      hud = h;
      info = document.createDivElement();
      info.className = 'hud-panel hud-text hud-stats';
      info.id = 'hud-info';
      h.container.appendChild(info);

      // compact-mode toggle: persistent, survives in-place updates
      compactBtn = document.createDivElement();
      compactBtn.className = 'hud-compact-btn';
      compactBtn.title = 'Compact info';
      compactBtn.innerHTML = UISvg.hudCompact();
      compactBtn.onclick = function (e)
        {
          var v = !game.config.compactHud;
          game.config.set('compactHud', v ? '1' : '0', true);
          game.scene.sounds.play('click-hud');
          info.classList.toggle('hud-compact', v);
          compactBtn.classList.toggle('active', v);
        }
      info.appendChild(compactBtn);

      // base-building takes over the whole panel
      baseInfo = document.createDivElement();
      baseInfo.style.display = 'none';
      info.appendChild(baseInfo);

      // parasite section (purple-tinted bars)
      playerSection = document.createDivElement();
      playerSection.className = 'hud-stats-player';
      var eb = document.createDivElement();
      eb.className = 'hud-eyebrow';
      eb.textContent = 'Parasite';
      playerSection.appendChild(eb);
      bars['ph'] = makeBar('ph', UISvg.hudEye(), 'Health', 'health');
      bars['pe'] = makeBar('pe', UISvg.hudBolt(), 'Energy', 'energy');
      playerSection.appendChild(bars['ph'].box);
      playerSection.appendChild(bars['pe'].box);
      info.appendChild(playerSection);

      // host / attachment section
      hostSection = document.createDivElement();
      hostEyebrow = document.createDivElement();
      hostEyebrow.className = 'hud-eyebrow';
      hostEyebrow.textContent = 'Host';
      hostSection.appendChild(hostEyebrow);
      hostname = document.createDivElement();
      hostname.className = 'hud-hostname';
      hostnameText = document.createSpanElement();
      hostnameText.className = 'hud-hostname-text';
      hostnameBadges = document.createSpanElement();
      hostnameBadges.className = 'hud-hostname-badges';
      hostname.appendChild(hostnameText);
      hostname.appendChild(hostnameBadges);
      hostSection.appendChild(hostname);
      bars['hh'] = makeBar('hh', UISvg.hudHeart(), 'Health', 'health');
      bars['he'] = makeBar('he', UISvg.hudBolt(), 'Energy', 'energy');
      bars['hc'] = makeBar('hc', UISvg.hudControl(), 'Control', 'control');
      hostSection.appendChild(bars['hh'].box);
      hostSection.appendChild(bars['he'].box);
      hostSection.appendChild(bars['hc'].box);
      info.appendChild(hostSection);

      // extra textual context
      extraWrap = document.createDivElement();
      extraWrap.className = 'hud-info-extra';
      regionContext = document.createDivElement();
      evoStrip = document.createDivElement();
      evoStrip.className = 'hud-evo-strip';
      cultLine = document.createDivElement();
      cultLine.className = 'hud-cult';
      spoonMark = document.createDivElement();
      spoonMark.className = 'hud-spoon';
      extraWrap.appendChild(regionContext);
      extraWrap.appendChild(evoStrip);
      extraWrap.appendChild(cultLine);
      extraWrap.appendChild(spoonMark);
      info.appendChild(extraWrap);
    }

// build one persistent stat bar: icon + label, value, track + fill.
// icon/label/fillClass are fixed per stat; updateBar() pokes the rest
  function makeBar(stat: String, icon: String, label: String, fillClass: String): BarRefs
    {
      var box = document.createDivElement();
      box.className = 'hud-bar';
      box.setAttribute('data-stat', stat);
      box.innerHTML =
        '<div class="hud-bar-lbl"><span class="hud-bar-n">' + icon +
        '<span class="hud-bar-lbl-txt">' + label + '</span></span>' +
        '<span class="hud-bar-v"></span></div>' +
        '<div class="hud-bar-track"><div class="hud-bar-fill ' + fillClass + '"></div></div>';
      return {
        box: box,
        lbl: cast box.querySelector('.hud-bar-lbl-txt'),
        val: cast box.querySelector('.hud-bar-v'),
        fill: cast box.querySelector('.hud-bar-fill'),
        track: cast box.querySelector('.hud-bar-track'),
      };
    }

// update one stat bar in place: value, fill (width + --pct for vertical compact
// gauge), warn/dead state, and a transient spend/gain ghost + floating ±N
  function updateBar(b: BarRefs, stat: String, cur: Int, max: Int, ?delta: String = '', ?label: String = null)
    {
      b.box.style.display = '';
      if (label != null)
        b.lbl.textContent = label;
      var pct = (max > 0 ? cur / max * 100 : 0);
      if (pct < 0)
        pct = 0;
      if (pct > 100)
        pct = 100;
      // change since last render drives the spend/gain trail + floating number
      var prev = (prevStat.exists(stat) ? prevStat.get(stat) : cur);
      var change = cur - prev;
      var oldPct = (max > 0 ? prev / max * 100 : 0);
      if (oldPct < 0)
        oldPct = 0;
      if (oldPct > 100)
        oldPct = 100;
      prevStat.set(stat, cur);
      statMax.set(stat, max);
      // value: cur in its own span, /max separable for compact mode.
      // clear any prior pulse class first, else recreating .cur below replays
      // the flash animation on every update (stale-class bug)
      b.val.classList.remove('flash-up', 'flash-down');
      b.val.innerHTML = '<span class="cur">' + cur + '</span>' +
        '<span class="hud-bar-max">/' + max + '</span>' + delta;
      // fill drives horizontal width (normal) and --pct (compact vertical height)
      b.fill.style.width = pct + '%';
      b.fill.style.setProperty('--pct', pct + '%');
      b.box.classList.toggle('dead', cur <= 0);
      b.box.classList.toggle('warn', cur > 0 && cur <= 0.25 * max);
      // clear prior transient overlays before replaying
      var og = b.track.querySelector('.hud-bar-ghost');
      if (og != null)
        og.remove();
      var of = b.box.querySelector('.hud-bar-float');
      if (of != null)
        of.remove();
      // ghost overlay on the changed segment + floating ±N
      if (change != 0)
        {
          var ghost = document.createDivElement();
          ghost.className = 'hud-bar-ghost ' + (change < 0 ? 'spend' : 'gain');
          ghost.style.left = (change < 0 ? pct : oldPct) + '%';
          ghost.style.width = (change < 0 ? oldPct - pct : pct - oldPct) + '%';
          b.track.appendChild(ghost);
          var fl = document.createSpanElement();
          fl.className = 'hud-bar-float ' + (change > 0 ? 'up' : 'down');
          fl.textContent = (change > 0 ? '+' : '') + change;
          b.box.appendChild(fl);
          // pulse the value itself (compact mode hides the float); .cur was just
          // recreated above with no flash class, so adding it plays fresh
          b.val.classList.add(change > 0 ? 'flash-up' : 'flash-down');
        }
    }

// show/hide a skeleton element
  inline function setShown(el: Element, b: Bool)
    {
      el.style.display = (b ? '' : 'none');
    }

// set a text region: hide when empty, only rewrite innerHTML on change.
// returns whether the region is shown
  function setRegion(div: DivElement, key: String, html: String): Bool
    {
      if (html == null || html == '')
        {
          div.style.display = 'none';
          return false;
        }
      div.style.display = '';
      if (regionCache.get(key) != html)
        {
          div.innerHTML = html;
          regionCache.set(key, html);
        }
      return true;
    }

// retrigger a one-shot change pulse on an element (fresh or persistent)
  inline function pulse(el: Element)
    {
      el.classList.remove('hud-pulse');
      el.getBoundingClientRect();
      el.classList.add('hud-pulse');
    }

// pulse cult resource values that changed since last render
  function flashCult()
    {
      var vals = cultLine.querySelectorAll('.v');
      for (i in 0...vals.length)
        {
          var el: Element = cast vals.item(i);
          if (i < prevCultVals.length &&
              prevCultVals[i] != el.textContent)
            pulse(el);
        }
      prevCultVals = [];
      for (i in 0...vals.length)
        prevCultVals.push((cast vals.item(i) : Element).textContent);
    }

// pulse evo/organ turn-eta pills that changed since last render
  function flashEvo()
    {
      var rows = evoStrip.querySelectorAll('.hud-feat');
      var next = new Map<String, String>();
      for (i in 0...rows.length)
        {
          var row: Element = cast rows.item(i);
          var pill = row.querySelector('.hud-turn-pill');
          if (pill == null)
            continue;
          var nameEl = row.querySelector('.hud-feat-name');
          var name = (nameEl != null ? nameEl.textContent : '' + i);
          next.set(name, pill.textContent);
          if (prevEvo.exists(name) &&
              prevEvo.get(name) != pill.textContent)
            pulse(pill);
        }
      prevEvo = next;
    }

// build cult resources inner html (empty if no active cult)
  function cultInner(): String
    {
      var cult = game.cults[0];
      if (cult.state != CULT_STATE_ACTIVE)
        return '';
      var r = cult.resources;
      // dim label + magenta value, dot-separated, centered
      function res(lbl: String, v: String): String
        return '<span class="r">' + (lbl != '' ? '<span class="l">' + lbl + '</span>' : '') +
          '<span class="v">' + v + '</span></span>';
      return res('COM', r.getShort('combat')) +
        res('MED', r.getShort('media')) +
        res('LAW', r.getShort('lawfare')) +
        res('COR', r.getShort('corporate')) +
        res('POL', r.getShort('political')) +
        res('', r.getShort('money') + Icon.money);
    }

// update player info in place
  public function update()
    {
      // base-building: hand the whole panel to base hud info
      if (hud.state == HUD_BASE_BUILDING &&
          game.cults[0].base != null)
        {
          setRegion(baseInfo, 'base', game.cults[0].base.hudInfo());
          setShown(playerSection, false);
          setShown(hostSection, false);
          setShown(extraWrap, false);
          setShown(compactBtn, false);
          info.className = 'hud-panel hud-text';
          return;
        }
      setShown(baseInfo, false);
      setShown(playerSection, true);
      setShown(compactBtn, true);

      var time = (game.location == LOCATION_AREA ? 1 : 5);

      // parasite bars
      var ppt = __Math.parasiteEnergyPerTurn(time);
      var pdelta = (ppt != 0 ?
        '<small class="' + (ppt > 0 ? 'up' : 'down') + '">' + (ppt > 0 ? '+' : '') + ppt + '/t</small>' : '');
      updateBar(bars['ph'], 'ph', game.player.health, game.player.maxHealth);
      updateBar(bars['pe'], 'pe', game.player.energy, game.player.maxEnergy, pdelta);

      // attachment: grip only
      if (game.player.state == PLR_STATE_ATTACHED)
        {
          setShown(hostSection, true);
          setShown(hostEyebrow, false);
          setShown(hostname, false);
          setShown(bars['hh'].box, false);
          setShown(bars['he'].box, false);
          updateBar(bars['hc'], 'hc', game.playerArea.attachHold, 100, '', 'Grip');
        }

      // host bars + name
      else if (game.player.state == PLR_STATE_HOST)
        {
          var host = game.player.host;
          setShown(hostSection, true);
          setShown(hostEyebrow, true);
          setShown(hostname, true);
          hostnameText.innerHTML = (host.isHuman ? host.getNameCapped() : host.AName());
          var badges = '';
          if (host.affinity >= 100)
            badges += Icon.affinity;
          if (host.chat.consent >= 100)
            badges += Icon.consent;
          if (host.isPlayerCultist())
            badges += Icon.cultist;
          hostnameBadges.innerHTML = badges;
          updateBar(bars['hh'], 'hh', host.health, host.maxHealth);
          var hpt = __Math.fullHostEnergyPerTurn(time);
          var hdelta = '';
          if (hpt != 0)
            hdelta = '<small class="' + (hpt > 0 ? 'up' : 'down') + '">' + (hpt > 0 ? '+' : '') + hpt + '/t</small>';
          if (hpt < 0)
            hdelta += '<small class="down">' + Math.ceil(host.energy / (- hpt)) + 't</small>';
          updateBar(bars['he'], 'he', host.energy, host.maxEnergy, hdelta);
          updateBar(bars['hc'], 'hc', game.player.hostControl, 100, '', 'Control');
        }

      // free parasite: no host section
      else setShown(hostSection, false);

      // area notes + team info
      var ctx = '';
      if (game.location == LOCATION_AREA)
        {
          if (game.area.isMissionArea())
            ctx += '<center>' + Const.smallcol('profane-ordeal', 'mission area') + '</center>';
        }
      else if (game.location == LOCATION_REGION)
        {
          var area = game.playerRegion.currentArea;
          if (area.highCrime)
            ctx += '<center>' + Const.smallgray('high crime') + '</center>';
          if (game.cults.length > 0 &&
              game.cults[0].ordeals.getMarkerMission(area) != null)
            ctx += '<center>' + Const.smallcol('profane-ordeal', 'mission area') + '</center>';
        }
      var gbuf = new StringBuf();
      game.group.hudInfo(gbuf);
      ctx += gbuf.toString();
      var shownCtx = setRegion(regionContext, 'ctx', ctx);

      // evolution direction + organs (host only)
      var feat = '';
      if (game.player.state == PLR_STATE_HOST)
        {
          if (game.player.evolutionManager.isActive)
            feat += game.player.evolutionManager.getEvolutionDirectionInfo();
          feat += game.player.host.organs.getInfo();
        }
      var shownEvo = setRegion(evoStrip, 'evo', feat);
      if (shownEvo)
        flashEvo();

      // cult resources
      var shownCult = setRegion(cultLine, 'cult', cultInner());
      if (shownCult)
        flashCult();

      // spoon marker
      var spoonHtml = (game.player.vars.isSpoonGame ? Const.col('yellow', 'SPOONED') : '');
      var shownSpoon = setRegion(spoonMark, 'spoon', spoonHtml);

      setShown(extraWrap, shownCtx || shownEvo || shownCult || shownSpoon);

      // panel class: stats base + low-energy pulse + compact mode
      info.className = 'hud-panel hud-text hud-stats';
      if (game.player.state != PLR_STATE_HOST &&
          game.player.energy <= 0.5 * game.player.maxEnergy)
        info.classList.add('highlight-text');
      info.classList.toggle('hud-compact', game.config.compactHud);
      compactBtn.classList.toggle('active', game.config.compactHud);

      if (hud.regionTooltip.visible)
        hud.regionTooltip.updatePosition();
      if (hud.aiTooltip.visible)
        hud.aiTooltip.updatePosition();
    }

// hover cost preview: hatch the segment a costed action would spend on its bar.
// pokes the live DOM directly (no rebuild happens while an action is hovered)
  public function previewCost(stat: String, cost: Int)
    {
      clearCostPreview();
      if (cost <= 0 ||
          !statMax.exists(stat))
        return;
      var max = statMax.get(stat);
      var cur = prevStat.get(stat);
      if (max <= 0)
        return;
      var track = info.querySelector('.hud-bar[data-stat="' + stat + '"] .hud-bar-track');
      if (track == null)
        return;
      var lo = (cur - cost < 0 ? 0 : cur - cost);
      var el = document.createDivElement();
      el.className = 'hud-bar-cost';
      el.style.left = (lo / max * 100) + '%';
      el.style.width = ((cur - lo) / max * 100) + '%';
      track.appendChild(el);
    }

// remove the hover cost-preview hatch
  public function clearCostPreview()
    {
      var el = info.querySelector('.hud-bar-cost');
      if (el != null)
        el.remove();
    }
}
