// body GUI window — inventory / knowledge / features dashboard

package ui;

import js.Browser;
import js.html.DivElement;
import js.html.SpanElement;
import js.html.Element;
import mods.AssetPath;

import game.Effect;
import game.Game;
import game.Improv;
import const.*;

class Body extends UIWindow
{
  var statsEl: SpanElement;        // titlebar growth stat chips
  var nameEl: SpanElement;         // titlebar host name
  var invBlock: DivElement;        // INVENTORY block (disabled toggle)
  var invCount: Element;           // INVENTORY count chip
  var invGrid: DivElement;         // inventory cell grid
  var parBlock: DivElement;        // PARASITE knowledge block
  var parScroll: Element;          // parasite skills scroll body
  var hostBlock: DivElement;       // HOST knowledge block
  var hostScroll: Element;         // host scroll body
  var featBlock: DivElement;       // FEATURES block
  var featCount: Element;          // FEATURES count chip
  var featScroll: Element;         // features scroll body
  var listInventoryActions: Array<_PlayerAction>;
  var listOrgansActions: Array<_PlayerAction>;
  var actionPrefix: String;        // action prefix: inventory or body

  public function new(g: Game)
    {
      super(g, 'window-body');
      listInventoryActions = [];
      listOrgansActions = [];

      // shared HUD chrome: scrim + cell glyph, frame, corners, veins, "BODY" watermark
      addHudChrome('BODY', UISvg.cell());

      // title row: name left, growth stat-chip strip right
      var title = Browser.document.createDivElement();
      title.className = 'win-title win-titlebar';
      title.innerHTML = '<span class="wt">BODY</span><span class="body-host-name"></span>';
      nameEl = cast title.querySelector('.body-host-name');
      statsEl = Browser.document.createSpanElement();
      statsEl.className = 'win-stats';
      title.appendChild(statsEl);
      window.appendChild(title);

      // three columns by content weight: (inventory+parasite) | host | features
      var cols = Browser.document.createDivElement();
      cols.className = 'body-cols';
      window.appendChild(cols);

      // col 1: INVENTORY (3) over PARASITE knowledge (2)
      var col1 = Browser.document.createDivElement();
      col1.className = 'body-col';
      cols.appendChild(col1);
      invBlock = Browser.document.createDivElement();
      invBlock.className = 'body-block body-block-inv';
      invBlock.style.setProperty('--i', '0');
      invBlock.innerHTML =
        '<div class="body-block-title">INVENTORY <span class="body-cnt"></span></div>' +
        '<div class="hud-scroll body-scroll"><div class="body-inv-grid"></div></div>';
      col1.appendChild(invBlock);
      invCount = invBlock.querySelector('.body-cnt');
      invGrid = cast invBlock.querySelector('.body-inv-grid');
      parBlock = Browser.document.createDivElement();
      parBlock.className = 'body-block body-block-par';
      parBlock.style.setProperty('--i', '1');
      parBlock.innerHTML =
        '<div class="body-kn-h">PARASITE</div>' +
        '<div class="hud-scroll body-scroll"></div>';
      col1.appendChild(parBlock);
      parScroll = parBlock.querySelector('.body-scroll');

      // col 2: HOST knowledge (the dense mass)
      var col2 = Browser.document.createDivElement();
      col2.className = 'body-col';
      cols.appendChild(col2);
      hostBlock = Browser.document.createDivElement();
      hostBlock.className = 'body-block';
      hostBlock.style.setProperty('--i', '2');
      hostBlock.innerHTML =
        '<div class="body-block-title">HOST <span class="body-cnt" style="visibility:hidden">0</span></div>' +
        '<div class="hud-scroll body-scroll"></div>';
      col2.appendChild(hostBlock);
      hostScroll = hostBlock.querySelector('.body-scroll');

      // col 3: body features (active + available, scroller soaks slack)
      var col3 = Browser.document.createDivElement();
      col3.className = 'body-col';
      cols.appendChild(col3);
      featBlock = Browser.document.createDivElement();
      featBlock.className = 'body-block';
      featBlock.style.setProperty('--i', '3');
      featBlock.innerHTML =
        '<div class="body-block-title">FEATURES <span class="body-cnt"></span></div>' +
        '<div class="hud-scroll body-scroll"></div>';
      col3.appendChild(featBlock);
      featCount = featBlock.querySelector('.body-cnt');
      featScroll = featBlock.querySelector('.body-scroll');

      addWinClose();
      wire();
    }

// update window contents
  override function update()
    {
      // titlebar host name (empty when not hosting)
      nameEl.innerHTML = (game.player.state == PLR_STATE_HOST ?
        game.player.host.theName() : '');
      updateStats();
      updateInventory();
      updateParasite();
      updateHost();
      updateFeatures();
    }

// titlebar growth chips: energy/turn, gp/turn, host survival turns
  function updateStats()
    {
      statsEl.innerHTML = '';
      if (game.player.state != PLR_STATE_HOST ||
          !game.player.vars.organsEnabled)
        return;
      var energyPT = __Math.growthEnergyPerTurn();
      var gpPT = __Math.gpPerTurn();
      var survive = (energyPT > 0 ? Std.int(game.player.host.energy / energyPT) : 0);
      statsEl.innerHTML =
        '<span class="statchip evolution-tip energy" data-tip="Energy spent per turn while growing body features">' +
          UISvg.bolt() + energyPT + '<i>/t</i></span>' +
        '<span class="statchip evolution-tip gp" data-tip="Growth points gained per turn">' +
          UISvg.star() + gpPT + '<i>/t</i></span>' +
        '<span class="statchip evolution-tip host" data-tip="Turns the host survives while growing">' +
          UISvg.clockSmall() + survive + '</span>';
    }

// inventory cells: key chip + item thumb + name/[active] + inline actions
  function updateInventory()
    {
      listInventoryActions = [];
      var disabled = (game.player.state != PLR_STATE_HOST ||
        !game.player.host.isHuman ||
        !game.player.vars.inventoryEnabled);
      invBlock.classList.toggle('disabled', disabled);
      if (disabled)
        {
          invCount.innerHTML = '';
          invGrid.innerHTML = '<div class="body-empty">Unavailable</div>';
          return;
        }
      var inv = game.player.host.inventory;
      invCount.innerHTML = inv.length() + '/' + game.player.host.maxItems;
      var actions = (game.player.vars.inventoryEnabled ? inv.getActions() : []);
      var buf = new StringBuf();
      var activeMarked = false;
      var hasItems = false;
      for (item in inv)
        {
          hasItems = true;
          var knows = game.player.knowsItem(item.id);
          var name = (knows ? item.name : item.info.unknown);
          var isActive = (item.id == inv.weaponID && !activeMarked);
          if (isActive)
            activeMarked = true;

          // collect this item's actions; first action index drives the key chip
          var actBuf = new StringBuf();
          var firstIdx = 0;
          var first = true;
          for (a in actions)
            {
              if (a.item != item)
                continue;
              // reduce cost when host is agreeable
              if (a.isAgreeable && game.player.hostAgreeable())
                a.energy = 1;
              listInventoryActions.push(a);
              var idx = listInventoryActions.length;
              if (firstIdx == 0)
                firstIdx = idx;
              if (!first)
                actBuf.add(', ');
              first = false;
              var label = (a.nameClean != null ? a.nameClean : a.name);
              actBuf.add('<span class="body-act" data-inv="' + idx + '">' + label + '</span>');
              if (a.energy > 0)
                actBuf.add(' <span class="body-cost">' + a.energy + UISvg.hudEnergy() + '</span>');
            }

          buf.add('<div class="body-inv-cell">');
          if (firstIdx > 0)
            buf.add('<span class="body-key">C-' + firstIdx + '</span>');
          buf.add('<span class="body-inv-thumb' + (isActive ? ' active' : '') + '">' + UISvg.bodyItem() + '</span>');
          buf.add('<span class="body-inv-main">');
          buf.add('<span class="body-inv-item' + (knows ? '' : ' body-inv-unknown') + '">' + name +
            (isActive ? ' <span class="body-inv-active">[active]</span>' : '') + '</span>');
          buf.add('<span class="body-inv-acts">' + actBuf.toString() + '</span>');
          buf.add('</span></div>');
        }
      if (!hasItems)
        buf.add('<div class="body-empty">no items</div>');
      invGrid.innerHTML = buf.toString();
    }

// parasite skills/knowledges + habitats + group info
  function updateParasite()
    {
      parBlock.classList.toggle('disabled', !game.player.vars.skillsEnabled);
      var buf = new StringBuf();
      var i = 0;
      for (skill in game.player.skills.sorted())
        {
          buf.add(skillRow(skill, true, i));
          i++;
        }
      if (i == 0)
        buf.add('<div class="body-empty">no skills</div>');

      // habitats remaining
      if (game.player.evolutionManager.isKnown(IMP_MICROHABITAT) &&
          game.player.vars.habitatsLeft < 100)
        buf.add('<div class="body-kn-line hab gray">' + UISvg.bodyHabitat() +
          ' Habitats left: ' + game.player.vars.habitatsLeft + '</div>');

      // group/team info
      var gbuf = new StringBuf();
      game.group.getInfo(gbuf);
      var gstr = gbuf.toString();
      if (gstr != '')
        buf.add('<div class="body-kn-line">' + gstr + '</div>');

      parScroll.innerHTML = buf.toString();
    }

// host job + skills + traits + attributes + effects
// blocks always render; gated data falls back to unknown/- placeholders
  function updateHost()
    {
      hostBlock.classList.toggle('disabled', !game.player.vars.skillsEnabled);
      // host is null when floating; attrs/job gated behind brain probe levels
      var host = (game.player.state == PLR_STATE_HOST ? game.player.host : null);
      var attrsKnown = (host != null && host.isAttrsKnown);
      var jobKnown = (host != null && host.isJobKnown);
      var buf = new StringBuf();

      // job + income line
      buf.add('<div class="body-sub-h">JOB</div>');
      if (jobKnown)
        buf.add('<div class="body-host-jobline">' + UISvg.bodyJob() +
          '<span class="body-host-job">' + host.job + '</span>' +
          '<span class="gray">&middot; income ' + host.income + '</span></div>');
      else
        buf.add('<div class="body-empty">unknown</div>');

      // host skills (hidden animal attack skill skipped)
      buf.add('<div class="body-sub-h body-sub-h-gap">SKILLS</div>');
      if (attrsKnown)
        {
          var i = 0;
          for (skill in host.skills.sorted())
            {
              if (skill.info.id == SKILL_ATTACK)
                continue;
              buf.add(skillRow(skill, false, i));
              i++;
            }
          if (i == 0)
            buf.add('<div class="body-empty">none</div>');
        }
      else
        buf.add('<div class="body-empty">unknown</div>');

      // traits panel (alphabetical)
      buf.add('<div class="body-sub-h body-sub-h-gap">TRAITS</div>');
      if (attrsKnown)
        {
          if (host.traits.length > 0)
            {
              var infos = [];
              for (t in host.traits)
                infos.push(TraitsConst.getInfo(t));
              infos.sort(function(a, b) {
                var an = a.name.toLowerCase();
                var bn = b.name.toLowerCase();
                return (an < bn ? -1 : (an > bn ? 1 : 0));
              });
              buf.add('<div class="body-host-panel">');
              for (info in infos)
                buf.add('<div class="body-trait">' + UISvg.bodyTrait() +
                  '<div><div class="body-trait-name">' + info.name + '</div>' +
                  '<div class="body-trait-note">' + info.note + '</div></div></div>');
              buf.add('</div>');
            }
          else
            buf.add('<div class="body-empty">none</div>');
        }
      else
        buf.add('<div class="body-empty">unknown</div>');

      // attribute tiles (always shown; '-' when not probed)
      buf.add('<div class="body-sub-h body-sub-h-gap">ATTRIBUTES</div>');
      buf.add('<div class="body-attr-grid">');
      buf.add(attrTile('str', 'STR', UISvg.attrStr(), (host != null ? host.strength : 0), attrsKnown));
      buf.add(attrTile('con', 'CON', UISvg.attrCon(), (host != null ? host.constitution : 0), attrsKnown));
      buf.add(attrTile('int', 'INT', UISvg.attrInt(), (host != null ? host.intellect : 0), attrsKnown));
      buf.add(attrTile('psy', 'PSY', UISvg.attrPsy(), (host != null ? host.psyche : 0), attrsKnown));
      buf.add('</div>');

      // effects panel
      buf.add('<div class="body-eff-h body-sub-h-gap">EFFECTS</div>');
      if (attrsKnown)
        {
          var effects = new Array<Effect>();
          for (effect in host.effects)
            if (!effect.isHidden)
              effects.push(effect);
          if (effects.length > 0)
            {
              effects.sort(function(a, b) {
                return (a.name < b.name ? -1 : (a.name > b.name ? 1 : 0));
              });
              buf.add('<div class="body-host-panel">');
              for (effect in effects)
                buf.add('<div class="body-eff-row">' + UISvg.bodyEffect() + ' ' + effect.name +
                  (effect.isTimer ? '<span class="body-eff-t">' +
                    UISvg.clockSmall('body-ico body-ico-time') + effect.points + '</span>' : '') +
                  '</div>');
              buf.add('</div>');
            }
          else
            buf.add('<div class="body-empty">none</div>');
        }
      else
        buf.add('<div class="body-empty">unknown</div>');

      hostScroll.innerHTML = buf.toString();
    }

// one skill/knowledge row: icon + name + micro-bar (skipped for boolean skills) + %
  function skillRow(skill: Dynamic, parasite: Bool, i: Int): String
    {
      var isKnow = (parasite && skill.info.isKnowledge == true);
      var name = (skill.info.group != null ? skill.info.group + ': ' : '') + skill.info.name;
      var isBool = (skill.info.isBool != null && skill.info.isBool);
      var buf = new StringBuf();
      buf.add('<div class="body-sk' + (isKnow ? ' know' : '') + '" style="--i:' + i + '">');
      buf.add(UISvg.bodySkill());
      buf.add('<span class="body-sk-name">' + name + '</span>');
      if (isKnow)
        buf.add('<span class="body-sk-tag">KNOW</span>');
      if (!isBool)
        buf.add('<span class="body-sk-bar"><span class="fill" style="--p:' + skill.level + '%"></span></span>' +
          '<span class="body-sk-pct">' + skill.level + '%</span>');
      buf.add('</div>');
      return buf.toString();
    }

// one attribute tile: filled glyph + value + label + 10-segment bar
// known=false renders '-' value with an empty bar (not yet brain-probed)
  function attrTile(mod: String, label: String, ico: String, v: Int, known: Bool = true): String
    {
      return '<div class="body-atile ' + mod + '">' + ico +
        '<div class="body-atile-head"><span class="body-atile-v">' + (known ? '' + v : '-') + '</span>' +
        '<span class="body-atile-k">' + label + '</span></div>' +
        '<span class="body-atile-bar" style="--v:' + (known ? v : 0) + '"><span class="fill"></span></span></div>';
    }

// features: grown organs (active) + available/growing organs (grow actions)
// reform=true replays the staggered card settle (used when switching grow target)
  function updateFeatures(?reform: Bool = false)
    {
      listOrgansActions = [];
      var disabled = (game.player.state != PLR_STATE_HOST ||
        !game.player.vars.organsEnabled);
      featBlock.classList.toggle('disabled', disabled);
      if (disabled)
        {
          featCount.innerHTML = '';
          featScroll.innerHTML = '<div class="body-empty">Unavailable</div>';
          return;
        }
      var host = game.player.host;
      featCount.innerHTML = host.organs.length() + '/' + host.maxOrgans;
      var buf = new StringBuf();
      var i = 0;

      // grown + in-progress organs both occupy body slots -> shown together up top
      var notRegion = (game.location != LOCATION_REGION);
      var hasFeature = false;
      for (organ in host.organs)
        {
          var imp = game.player.evolutionManager.getImprov(organ.id);
          if (organ.isActive)
            buf.add(activeCard(imp, organ, i));
          // in-progress (currently growing or half-grown); resume needs no free slot
          else
            buf.add(availCard(imp, organ,
              organ.id == host.organs.getCurrentID(), notRegion, i));
          i++;
          hasFeature = true;
        }
      if (!hasFeature)
        buf.add('<div class="body-empty">no body features</div>');

      // available features not yet started; a free slot is required to begin.
      // a 0-gp in-progress organ counts as free (replacing it prunes it on switch)
      buf.add('<div class="body-sub-h body-sub-h-gap">AVAILABLE FEATURES</div>');
      var cur = host.organs.getCurrentID();
      var freeable = (cur != null && host.organs.get(cur).gp == 0);
      if (host.organs.length() >= host.maxOrgans && !freeable)
        buf.add('<div class="body-empty">all slots taken</div>');
      else
        {
          var hasAvail = false;
          for (imp in game.player.evolutionManager)
            {
              // not available yet or has no organ
              if (imp.level == 0 || imp.info.organ == null)
                continue;
              // already grown or in progress (shown above)
              if (host.organs.get(imp.info.id) != null)
                continue;
              buf.add(availCard(imp, null, false, notRegion, i));
              i++;
              hasAvail = true;
            }
          if (!hasAvail)
            buf.add('<div class="body-empty">No features available</div>');
        }

      featScroll.innerHTML = buf.toString();
      // replay the cascade only on a grow-target switch (open uses .body-intro)
      featScroll.classList.toggle('body-feat-reform', reform);
    }

// grown feature card: thumbnail + name/level + note + level-note (+ timeout)
  function activeCard(imp: Improv, organ: Dynamic, i: Int): String
    {
      var organInfo = imp.info.organ;
      var src = AssetPath.resolve('img/imp/' + (organ.id : String).toLowerCase() + '.jpg');
      var levelNote = cleanLevelNote(imp, organ.level);
      var buf = new StringBuf();
      buf.add('<div class="body-organ active" style="--i:' + i + '">');
      buf.add('<span class="body-organ-thumb"><img src="' + src + '" alt=""></span>');
      buf.add('<span class="body-organ-body">');
      buf.add('<span class="body-organ-h"><span class="body-organ-name">' + organInfo.name + '</span>' +
        '<span class="body-organ-lv">' + organ.level + '</span>');
      if (organInfo.hasTimeout && organ.timeout > 0)
        buf.add('<span class="body-organ-turns" style="margin-left:auto">' +
          UISvg.clockSmall('body-ico body-ico-time') + organ.timeout + '</span>');
      buf.add('</span>');
      buf.add('<span class="body-organ-note">' + organInfo.note + '</span>');
      if (levelNote != '')
        buf.add('<span class="body-organ-sub">' + levelNote + '</span>');
      buf.add('</span></div>');
      return buf.toString();
    }

// available feature card: thumbnail + name + (GROWING) + note + gp bar / turns / S-key
  function availCard(imp: Improv, organ: Dynamic, isNow: Bool, canGrow: Bool, i: Int): String
    {
      var organInfo = imp.info.organ;
      var src = AssetPath.resolve('img/imp/' + (imp.id : String).toLowerCase() + '.jpg');
      var gp = (organ != null ? organ.gp : 0);
      var gpMax = organInfo.gp;
      var fill = (gpMax > 0 ? Std.int(gp / gpMax * 100) : 0);
      var turns = Math.round((gpMax - gp) / __Math.gpPerTurn());

      // growable (not already in progress) becomes an S-key grow action
      var key = 0;
      if (canGrow && !isNow)
        {
          listOrgansActions.push({
            id: 'set.' + imp.id,
            type: ACTION_ORGAN,
            name: organInfo.name + ' ' + imp.level,
            energy: 0,
          });
          key = listOrgansActions.length;
        }

      var buf = new StringBuf();
      buf.add('<div class="body-organ avail' + (isNow ? ' now' : '') + '"' +
        (key > 0 ? ' data-organ="' + imp.id + '"' : '') +
        ' style="--i:' + i + '">');
      buf.add('<span class="body-organ-thumb"><img src="' + src + '" alt=""></span>');
      buf.add('<span class="body-organ-body">');
      buf.add('<span class="body-organ-h"><span class="body-organ-name">' + organInfo.name + '</span>' +
        '<span class="body-organ-lv">' + imp.level + '</span>' +
        (isNow ? '<span class="body-organ-growing">GROWING</span>' : '') + '</span>');
      buf.add('<span class="body-organ-note">' + organInfo.note + '</span>');
      buf.add('<span class="body-organ-foot">');
      buf.add('<span class="body-organ-bar"><span class="fill" style="width:' + fill + '%"></span></span>');
      buf.add('<span class="body-organ-gp">' + gp + '/' + gpMax + ' ' +
        UISvg.star('body-ico body-ico-gp') + '</span>');
      buf.add('<span class="body-organ-meta"><span class="body-organ-turns">' +
        UISvg.clockSmall('body-ico body-ico-time') + turns + '</span>' +
        (key > 0 ? '<span class="body-key">S-' + key + '</span>' : '') + '</span>');
      buf.add('</span>');
      buf.add('</span></div>');
      return buf.toString();
    }

// level-state prose for the current level (suppressed when empty/fluff/todo)
  function cleanLevelNote(imp: Improv, level: Int): String
    {
      var ln = imp.info.levelNotes[level];
      if (ln == null)
        return '';
      var low = ln.toLowerCase();
      if (ln == '' || low.indexOf('fluff') >= 0 || low.indexOf('todo') >= 0)
        return '';
      return ln;
    }

// delegate clicks: inventory actions + available-feature grow actions
  function wire()
    {
      window.addEventListener('click', function(e) {
        var t: Element = cast e.target;
        // inventory action
        var act = t.closest('.body-act');
        if (act != null && act.getAttribute('data-inv') != null)
          {
            var idx = Std.parseInt(act.getAttribute('data-inv'));
            var a = listInventoryActions[idx - 1];
            if (a != null)
              {
                game.scene.sounds.play('click-action');
                game.player.host.inventory.action(a);
                if (game.ui.state == UISTATE_BODY)
                  game.ui.closeWindow();
              }
            return;
          }
        // available feature -> grow action
        var organEl = t.closest('.body-organ.avail');
        if (organEl != null && !organEl.classList.contains('now'))
          {
            var id = organEl.getAttribute('data-organ');
            if (id != null)
              {
                game.scene.sounds.play('click-action');
                game.player.host.organs.action('set.' + id);
                // refresh the changed parts; reform replays the feature cascade
                updateFeatures(true);
                updateStats();
                game.ui.hud.update();
              }
          }
      });
    }

// set action prefix (inventory vs body) for keyboard hotkeys
  public function prefix(p: String)
    {
      actionPrefix = p;
    }

// keyboard action dispatch: prefix selects inventory (C-n) or features (S-n)
  public override function action(index: Int)
    {
      if (actionPrefix == null)
        game.actionFailed('No prefix selected.');
      else if (actionPrefix == 'inventory')
        {
          if (!game.player.vars.inventoryEnabled)
            return;
          var a = listInventoryActions[index - 1];
          if (a == null)
            return;
          game.player.host.inventory.action(a);
          if (game.ui.state == UISTATE_BODY)
            game.ui.closeWindow();
        }
      else if (actionPrefix == 'body')
        {
          var a = listOrgansActions[index - 1];
          if (a == null)
            return;
          game.player.host.organs.action(a.id);
          updateFeatures(true);
          updateStats();
          game.ui.hud.update();
        }
      actionPrefix = null;
    }

// dom element for the active prefix's nth hotkey, so keyboard clicks/animates it.
// consumes actionPrefix on a hit, mirroring action()'s reset
  public override function getButton(index: Int): js.html.Element
    {
      var el = null;
      if (actionPrefix == 'inventory')
        el = window.querySelector('.body-act[data-inv="' + index + '"]');
      else if (actionPrefix == 'body')
        {
          var a = listOrgansActions[index - 1];
          if (a != null)
            el = window.querySelector('.body-organ.avail:not(.now)[data-organ="' +
              (StringTools.startsWith(a.id, 'set.') ? a.id.substr(4) : a.id) + '"]');
        }
      if (el != null)
        actionPrefix = null;
      return el;
    }

  override function show(?skipAnimation: Bool = false)
    {
      // entrance rise is gated on .body-intro (added before update builds the
      // cards); drop it after the cascade so later refreshes don't re-animate
      window.classList.add('body-intro');
      super.show(skipAnimation);
      Browser.window.setTimeout(function() window.classList.remove('body-intro'), 1000);
    }

  override function hide(?skipAnimation: Bool = false)
    {
      animatedHide();
    }
}
