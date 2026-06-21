// hud info block: core stats as bars, the rest as text below
package ui.hud;

import js.Browser.document;
import js.html.DivElement;

import game.*;

class InfoHud
{
  var game: Game;
  var hud: HUD;
  public var info: DivElement; // exposed: region tooltip measures against it

  public function new(g: Game, h: HUD)
    {
      game = g;
      hud = h;
      info = document.createDivElement();
      info.className = 'hud-panel hud-text hud-stats';
      info.id = 'hud-info';
      h.container.appendChild(info);
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
  public function update()
    {
      var buf = new StringBuf();
      if (hud.state == HUD_BASE_BUILDING &&
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
      if (hud.regionTooltip.visible)
        hud.regionTooltip.updatePosition();
      if (hud.aiTooltip.visible)
        hud.aiTooltip.updatePosition();
      // low parasite energy pulses the panel when not hosting
      if (game.player.state != PLR_STATE_HOST)
        info.className =
          (game.player.energy <= 0.5 * game.player.maxEnergy ?
           'hud-panel hud-text hud-stats highlight-text' : 'hud-panel hud-text hud-stats');
      else info.className = 'hud-panel hud-text hud-stats';
    }
}
