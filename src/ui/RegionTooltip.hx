// region tooltip overlay for HUD (content + visibility; beam/placement in BeamTooltip)
package ui;

import game.*;

class RegionTooltip extends BeamTooltip
{
  public function new(g: Game, h: HUD)
    {
      super(g, h, 'hud-area-info', 'region-tip');
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

      // get mouse position and area
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

      // header: name + coords, alertness pip, situational tags
      var buf = new StringBuf();
      if (areaKnown)
        {
          buf.add('<div class="region-tip-head"><span class="region-tip-name">' + area.name + '</span>');
          buf.add('<span class="region-tip-xy">' + area.x + ',' + area.y + '</span></div>');
          var alertness = Std.int(area.alertness);
          buf.add('<div class="region-tip-alert alert-' + getAlertnessColor(alertness) + '">');
          buf.add('<span class="region-tip-pip"></span><span class="region-tip-alabel">alertness</span>');
          buf.add('<span class="region-tip-aval">' + getAlertnessLabel(alertness) + '</span></div>');
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
              buf.add('<div class="region-tip-tags">');
              for (t in tags)
                buf.add('<span class="region-tip-tag">' + t + '</span>');
              buf.add('</div>');
            }
        }
      else buf.add('<div class="region-tip-head"><span class="region-tip-name unknown">?</span></div>');

      // leads: timeline events / unknown npcs / cult ordeal, each a marked row
      if (eventLines.length > 0 ||
          npcLines.length > 0 ||
          missionLines.length > 0)
        {
          buf.add('<div class="region-tip-leads">');
          for (line in eventLines)
            buf.add('<div class="region-tip-row ev"><span class="region-tip-evpill">' + line + '</span></div>');
          for (line in npcLines)
            buf.add('<div class="region-tip-row npc">' + line + '</div>');
          for (line in missionLines)
            buf.add('<div class="region-tip-row ord">' + line + '</div>');
          buf.add('</div>');
        }

      showBeam(area.x, area.y, area.id, buf.toString());
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
            lines.push(Const.smallgray('[event ' + npc.event.num + ']') + ' <span class="region-tip-npcname">' + label + '</span>');
          }
      return lines;
    }

  // collect mission tooltip lines for region mode
  function getMissionLines(area: AreaGame): Array<String>
    {
      var lines = [];
      if (game.cults[0].state != CULT_STATE_ACTIVE)
        return lines;

      var mission = game.cults[0].ordeals.getMarkerMission(area);
      if (mission != null)
        lines.push(mission.coloredName());
      return lines;
    }
}
