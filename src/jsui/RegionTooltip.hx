// region tooltip overlay for HUD
package jsui;

import js.Browser;
import js.html.DivElement;
import game.*;

class RegionTooltip
{
  var game: Game;
  var hud: HUD;
  public var overlay: DivElement;
  public var areaID: Int;
  public var visible: Bool;

  public function new(g: Game, h: HUD)
    {
      game = g;
      hud = h;

      areaID = -1;
      visible = false;
      overlay = Browser.document.createDivElement();
      overlay.className = 'text';
      overlay.id = 'hud-area-info';
      overlay.style.display = 'none';
      overlay.style.position = 'fixed';
      overlay.style.pointerEvents = 'none';
      overlay.style.borderImage = "url('./img/hud-log-border.png') 15 fill / 1 / 0 stretch";
      hud.container.appendChild(overlay);
    }

  // show region tooltip when hovering known tiles
  public function update()
    {
      // only show in region mode
      if (game.location != LOCATION_REGION)
        {
          hide();
          return;
        }

      // get mouse position and aread
      var pos = game.scene.mouse.getXY();
      if (pos == null)
        {
          hide();
          return;
        }
      var area = game.region.getXY(pos.x, pos.y);
      if (area == null)
        {
          hide();
          return;
        }

      // get tooltip text
      var areaKnown = game.scene.region.isKnown(area);
      var eventLines = getEventLines(area);
      var npcLines = getNPCLines(area);
      var missionLines = getMissionLines(area);
      if (!areaKnown &&
          eventLines.length == 0 &&
          npcLines.length == 0 &&
          missionLines.length == 0)
        {
          hide();
          return;
        }

      // update tooltip content
      var buf = new StringBuf();
      if (areaKnown)
        {
          buf.add('<span class=hud-name>' + area.name + '</span> ');
          buf.add(Const.smallgray('(' + area.x + ',' + area.y + ') ') + '<br/>');
          var alertness = Std.int(area.alertness);
          var alertColor = getAlertnessColor(alertness);
          buf.add('Alertness: ' +
            Const.col(alertColor,
            getAlertnessLabel(alertness)) + '<br/>');
          var tags: Array<String> = [];
          if (area.highCrime)
            tags.push('high crime');
          if (area.hasHabitat)
            tags.push('habitat');
          if (!area.info.canEnter)
            tags.push('inaccessible');
          if (area.info.isHighRisk)
            tags.push('high risk');
          if (missionLines.length > 0)
            tags.push('ordeal');
          if (tags.length > 0)
            {
              buf.add(Const.smallgray('[' + tags.join('] [') + ']'));
              buf.add('<br/>');
            }
        }
      else
        {
          buf.add('<span class=hud-name>?</span><br/>');
        }
      for (line in eventLines)
        buf.add(line + '<br/>');
      for (line in npcLines)
        buf.add(line + '<br/>');
      for (line in missionLines)
        buf.add(line + '<br/>');
      overlay.innerHTML = buf.toString();
      overlay.style.display = 'block';
      overlay.style.visibility = 'hidden';
      areaID = area.id;
      visible = true;
      updatePosition();
      overlay.style.visibility = 'visible';
    }

  // get alertness color for tooltip
  inline function getAlertnessColor(alertness: Int): String
    {
      if (alertness >= 75)
        return 'red';
      if (alertness >= 50)
        return 'yellow';
      if (alertness > 0)
        return 'white';
      return 'gray';
    }

  // get alertness label for tooltip
  inline function getAlertnessLabel(alertness: Int): String
    {
      if (alertness >= 75)
        return 'high';
      if (alertness >= 50)
        return 'medium';
      if (alertness > 0)
        return 'low';
      return 'none';
    }

  // collect timeline event tooltip lines for region mode
  function getEventLines(area: AreaGame): Array<String>
    {
      var lines = [];
      var oneLocationKnown = false;
      for (event in area.events)
        {
          if (event.locationKnown)
            oneLocationKnown = true;
        }
      if (!oneLocationKnown)
        return lines;
      for (event in area.events)
        if (event.locationKnown)
          lines.push('event ' + event.num);
      return lines;
    }

  // collect npc tooltip lines for region mode
  function getNPCLines(area: AreaGame): Array<String>
    {
      var lines = [];
      if (!game.player.vars.timelineEnabled)
        return lines;
      var len = 0;
      for (_ in area.npc)
        len++;
      if (len == 0)
        return lines;
      var ok = true;

      // check if there are any unknown npcs
      for (npc in area.npc)
        if (!npc.isDead &&
            npc.areaKnown &&
            !npc.memoryKnown)
          ok = false;
      if (ok)
        return lines;

      // collect unknown npc lines
      for (npc in area.npc)
        if (!npc.isDead &&
            npc.areaKnown &&
            !npc.memoryKnown)
          {
            var label = '';
            if (npc.nameKnown)
              label = npc.name;
            else if (npc.jobKnown && npc.job != null)
              label = npc.job;
            else label = 'unknown contact';
            lines.push(Const.smallgray('[event ' + npc.event.num + ']') + ' ' + label);
          }
      return lines;
    }

  // collect mission tooltip lines for region mode
  function getMissionLines(area: AreaGame): Array<String>
    {
      var lines = [];
      if (game.cults[0].state != CULT_STATE_ACTIVE)
        return lines;

      for (ordeal in game.cults[0].ordeals.list)
        for (mission in ordeal.missions)
          if (mission.x == area.x &&
              mission.y == area.y)
            lines.push(mission.coloredName());
      return lines;
    }

  // align region tooltip above the info panel
  public function updatePosition()
    {
      if (!visible)
        return;
      var infoRect = hud.info.getBoundingClientRect();
      if (infoRect == null)
        return;
      var width: Float = hud.info.offsetWidth;
      if (width <= 0)
        width = infoRect.width;
      if (width <= 0)
        width = hud.info.scrollWidth;
      if (width <= 0)
        return;
      overlay.style.width = Std.string(Math.round(width)) + 'px';
      overlay.style.left = Std.string(Math.round(infoRect.left)) + 'px';
      var overlayHeight: Float = overlay.offsetHeight;
      var top: Float = infoRect.top - overlayHeight - 8;
      if (top < 10)
        top = 10;
      overlay.style.top = Std.string(Math.round(top)) + 'px';
    }

  // hide region tooltip overlay
  public function hide()
    {
      if (!visible)
        return;
      visible = false;
      areaID = -1;
      overlay.style.display = 'none';
      overlay.style.visibility = 'hidden';
    }
}
