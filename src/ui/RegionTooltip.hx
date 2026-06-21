// region tooltip overlay for HUD
package ui;

import js.Browser;
import js.html.DivElement;
import js.html.Element;
import game.*;

class RegionTooltip
{
  static inline var SVGNS = 'http://www.w3.org/2000/svg';
  // min clearance kept between the tooltip and any HUD panel / the viewport edge
  static inline var MARGIN = 10.0;

  var game: Game;
  var hud: HUD;
  public var overlay: DivElement;
  public var areaID: Int;
  public var visible: Bool;
  // full-screen svg holding the projection beam (line + tile dot + ping ring)
  var linkEl: Element;
  var beamLine: Element;
  // frozen snapshot of the previous tile's beam, animated out on a tile change
  var beamOld: Element;
  var beamDot: Element;
  var beamPing: Element;
  // hovered tile coords, for live geometry as the camera scrolls
  var tileX: Int;
  var tileY: Int;
  // pending fade-out timer (cancelled if the panel re-shows in time)
  var hideTimer: haxe.Timer;

  public function new(g: Game, h: HUD)
    {
      game = g;
      hud = h;

      areaID = -1;
      visible = false;
      tileX = 0;
      tileY = 0;

      overlay = Browser.document.createDivElement();
      overlay.className = 'text region-tip';
      overlay.id = 'hud-area-info';
      overlay.style.display = 'none';
      overlay.style.position = 'fixed';
      overlay.style.pointerEvents = 'none';
      hud.container.appendChild(overlay);

      // projection beam overlay: one diagonal line from the tile dot to the panel
      linkEl = Browser.document.createElementNS(SVGNS, 'svg');
      linkEl.setAttribute('class', 'region-tip-link');
      beamOld = Browser.document.createElementNS(SVGNS, 'line');
      beamOld.setAttribute('class', 'rt-old');
      beamOld.setAttribute('pathLength', '1');
      beamLine = Browser.document.createElementNS(SVGNS, 'line');
      beamLine.setAttribute('pathLength', '1');
      beamPing = Browser.document.createElementNS(SVGNS, 'circle');
      beamPing.setAttribute('class', 'rt-ping');
      beamPing.setAttribute('r', '3.5');
      beamDot = Browser.document.createElementNS(SVGNS, 'circle');
      beamDot.setAttribute('class', 'rt-dot');
      beamDot.setAttribute('r', '3.5');
      linkEl.appendChild(beamOld);
      linkEl.appendChild(beamLine);
      linkEl.appendChild(beamPing);
      linkEl.appendChild(beamDot);
      linkEl.style.display = 'none';
      hud.container.appendChild(linkEl);
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
      overlay.innerHTML = buf.toString();
      // cancel a pending fade-out so a quick re-hover keeps the panel alive
      if (hideTimer != null)
        {
          hideTimer.stop();
          hideTimer = null;
        }
      overlay.style.display = 'block';
      linkEl.style.display = 'block';
      // on a tile change, snapshot the current beam and animate it out at the old tile
      var wasVisible = visible;
      if (wasVisible)
        snapshotOldBeam();
      tileX = area.x;
      tileY = area.y;
      areaID = area.id;
      visible = true;
      updatePosition();
      // fade in from hidden; tile-to-tile keeps the panel and just redraws the beam
      if (!wasVisible)
        {
          overlay.classList.remove('visible');
          untyped overlay.offsetWidth;
        }
      overlay.classList.add('visible');
      // incoming beam draws in (old one animates out simultaneously)
      restartBeam();
    }

  // freeze the current (old-tile) beam into the outgoing line and play its draw-out
  function snapshotOldBeam()
    {
      beamOld.setAttribute('x1', beamLine.getAttribute('x1'));
      beamOld.setAttribute('y1', beamLine.getAttribute('y1'));
      beamOld.setAttribute('x2', beamLine.getAttribute('x2'));
      beamOld.setAttribute('y2', beamLine.getAttribute('y2'));
      untyped beamOld.style.animation = 'none';
      Browser.window.getComputedStyle(beamOld).getPropertyValue('animation-name');
      untyped beamOld.style.animation = 'region-beam-undraw 0.28s ease forwards';
    }

  // keep the beam visible across tiles; replay only the draw-in (no opacity blink).
  // getComputedStyle forces a style flush (offsetWidth is a no-op on SVG nodes)
  function restartBeam()
    {
      linkEl.classList.add('show');
      untyped beamLine.style.animation = 'none';
      Browser.window.getComputedStyle(beamLine).getPropertyValue('animation-name');
      untyped beamLine.style.animation = 'region-beam-draw 0.42s ease forwards';
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

  // collect screen rects of visible HUD panels, inflated by the clearance margin
  function panelRects(): Array<{ l: Float, t: Float, r: Float, b: Float }>
    {
      var out = [];
      var nodes = hud.container.querySelectorAll('.hud-panel');
      for (i in 0...nodes.length)
        {
          var el: Element = cast nodes.item(i);
          var rc = el.getBoundingClientRect();
          if (rc.width <= 0 ||
              rc.height <= 0)
            continue;
          out.push({ l: rc.left - MARGIN, t: rc.top - MARGIN, r: rc.right + MARGIN, b: rc.bottom + MARGIN });
        }
      return out;
    }

  // position the panel in free space beside the hovered tile and aim the beam at it
  public function updatePosition()
    {
      if (!visible)
        return;
      var ratio = Browser.window.devicePixelRatio;
      var ts = Const.TILE_SIZE;
      // tile center in viewport css px (mouseX/cameraX are device px)
      var cx = (tileX * ts + ts / 2 - game.scene.cameraX) / ratio;
      var cy = (tileY * ts + ts / 2 - game.scene.cameraY) / ratio;
      var half = (ts / 2) / ratio;
      var vw = Browser.window.innerWidth;
      var vh = Browser.window.innerHeight;
      var w: Float = overlay.offsetWidth;
      var h: Float = overlay.offsetHeight;
      var gap = 20.0;
      var rects = panelRects();

      // ideal: beside the tile (right, flip left near the edge) with a diagonal lift
      var dir = (cy < vh / 2 ? -1.0 : 1.0);
      var idealLeft = cx + half + gap;
      var idealTop = cy - h / 2 + dir * half;
      if (idealLeft + w > vw - MARGIN)
        idealLeft = cx - half - gap - w;

      // pick the clear position nearest the ideal: overlap dominates, then distance.
      // exhaustive grid guarantees we find free space when it exists (no margin touch)
      var bestL = idealLeft;
      var bestT = idealTop;
      var bestScore = 1e30;
      var tryPos = function(l: Float, t: Float) {
        if (l < MARGIN) l = MARGIN;
        if (l > vw - MARGIN - w) l = vw - MARGIN - w;
        if (t < MARGIN) t = MARGIN;
        if (t > vh - MARGIN - h) t = vh - MARGIN - h;
        var area = 0.0;
        for (p in rects)
          {
            var ox = Math.min(l + w, p.r) - Math.max(l, p.l);
            var oy = Math.min(t + h, p.b) - Math.max(t, p.t);
            if (ox > 0 && oy > 0)
              area += ox * oy;
          }
        var dx = l - idealLeft;
        var dy = t - idealTop;
        var score = area * 1e6 + dx * dx + dy * dy;
        if (score < bestScore)
          {
            bestScore = score;
            bestL = l;
            bestT = t;
          }
      };
      // exact preferred placements first (precise when clear), then a coarse grid
      tryPos(idealLeft, idealTop);
      tryPos(cx - half - gap - w, cy - h / 2 + dir * half);
      tryPos(cx - w / 2, cy + half + gap);
      tryPos(cx - w / 2, cy - half - gap - h);
      var step = 48.0;
      var gy = MARGIN;
      while (gy <= vh - MARGIN - h)
        {
          var gx = MARGIN;
          while (gx <= vw - MARGIN - w)
            {
              tryPos(gx, gy);
              gx += step;
            }
          gy += step;
        }
      var left = bestL;
      var top = bestT;
      overlay.style.left = Math.round(left) + 'px';
      overlay.style.top = Math.round(top) + 'px';

      // beam endpoint: midpoint of the tooltip edge facing the tile (diagonal via offset)
      var px = left;
      var py = top + h / 2;
      if (left >= cx)
        { px = left; py = top + h / 2; }
      else if (left + w <= cx)
        { px = left + w; py = top + h / 2; }
      else if (top >= cy)
        { px = left + w / 2; py = top; }
      else
        { px = left + w / 2; py = top + h; }
      linkEl.setAttribute('width', '' + vw);
      linkEl.setAttribute('height', '' + vh);
      beamLine.setAttribute('x1', '' + cx);
      beamLine.setAttribute('y1', '' + cy);
      beamLine.setAttribute('x2', '' + px);
      beamLine.setAttribute('y2', '' + py);
      beamDot.setAttribute('cx', '' + cx);
      beamDot.setAttribute('cy', '' + cy);
      beamPing.setAttribute('cx', '' + cx);
      beamPing.setAttribute('cy', '' + cy);
    }

  // hide region tooltip overlay (fade out, then detach after the transition)
  public function hide()
    {
      if (!visible)
        return;
      visible = false;
      areaID = -1;
      overlay.classList.remove('visible');
      linkEl.classList.remove('show');
      if (hideTimer != null)
        hideTimer.stop();
      hideTimer = haxe.Timer.delay(function() {
        hideTimer = null;
        overlay.style.display = 'none';
        linkEl.style.display = 'none';
      }, 180);
    }
}
