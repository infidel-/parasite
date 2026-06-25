// player timeline GUI window — declassified case-file dossier
package ui;

import js.Browser;
import js.html.DivElement;

import game.Game;

class Timeline extends UIWindow
{
  var titlebar: DivElement;
  var tlScroll: DivElement;

  public function new (g: Game)
    {
      super(g, 'window-timeline');

      // shared HUD chrome: scrim + clock glyph, frame, corners, veins, "TIME" watermark
      addHudChrome('TIME', UISvg.clock());

      titlebar = Browser.document.createDivElement();
      titlebar.className = 'win-title win-titlebar';
      window.appendChild(titlebar);

      tlScroll = Browser.document.createDivElement();
      tlScroll.className = 'hud-scroll timeline-scroll';
      window.appendChild(tlScroll);

      addWinClose();
    }

// update the dossier from the timeline data (each field independently redactable)
  override function update()
    {
      var buf = new StringBuf();
      var eventsShown = 0;
      var totalLeads = 0;
      var i = 0;
      for (event in game.timeline)
        {
          if (event.isHidden)
            continue;
          var npcKnown = event.npcSomethingKnown();
          var notesKnown = event.notesSomethingKnown();
          // nothing known at all -> skip
          if (!event.locationKnown && !npcKnown && !notesKnown)
            continue;

          // event state: fully-redacted (location + notes blacked out) / open leads
          var redactedEv = !event.locationKnown && !notesKnown;
          var hasLeads = false;
          for (n in event.notes)
            if (!n.isKnown && n.clues > 0)
              {
                hasLeads = true;
                totalLeads++;
              }

          var cls = 'timeline-event';
          if (redactedEv)
            cls += ' redacted-ev';
          if (hasLeads)
            cls += ' has-leads';
          buf.add("<li class='" + cls + "' style='--i:" + i + "'>");
          buf.add("<span class='timeline-node'></span><div class='timeline-card'><div class='timeline-fx'></div>");
          if (redactedEv)
            buf.add("<div class='timeline-stamp'>SEALED</div>");

          // header: event id + location (name + coords, or blackout bar + (?,?))
          buf.add("<div class='timeline-ehead'><span class='timeline-en'>EVENT " + event.num + "</span><span class='timeline-loc'>");
          if (event.location != null)
            {
              if (event.locationKnown)
                {
                  if (event.location.hasName)
                    buf.add(event.location.name + " ");
                  buf.add("<span class='timeline-xy'>(" + event.location.area.x + "," + event.location.area.y + ")</span>");
                }
              else buf.add("<span class='timeline-bar wide'></span> <span class='timeline-xy'>(?,?)</span>");
            }
          buf.add("</span></div>");

          // notes: known = bullet text; unknown w/ clues = ? + 4-pip clue meter
          buf.add("<ul class='timeline-notes'>");
          for (n in event.notes)
            {
              if (n.isKnown)
                buf.add("<li class='timeline-note'>" + n.text + "</li>");
              else if (n.clues > 0)
                {
                  buf.add("<li class='timeline-note redacted'><span class='timeline-q'>?</span><span class='timeline-clues'>");
                  for (c in 0...4)
                    buf.add(c < n.clues ? "<i class='on'></i>" : "<i></i>");
                  buf.add("</span><span class='timeline-cn'>" + n.clues + "/4</span></li>");
                }
            }
          buf.add("</ul>");

          // participants: per-field redactable ID tags; alive-probed / deceased rolled up
          buf.add("<div class='timeline-parts'><div class='timeline-ptitle'>Participants</div>");
          var numProbed = 0;
          var numDeceased = 0;
          if (npcKnown)
            for (npc in event.npc)
              {
                if (!npc.nameKnown && !npc.jobKnown && !npc.areaKnown && !npc.statusKnown)
                  continue;
                if (npc.isDead && npc.statusKnown)
                  {
                    numDeceased++;
                    continue;
                  }
                if (!npc.isDead && npc.memoryKnown)
                  {
                    numProbed++;
                    continue;
                  }
                buf.add("<div class='timeline-row" + (npc.nameKnown ? "" : " redacted") + "'>");
                buf.add(npc.jobKnown ? "<span class='timeline-photo'>" + UISvg.face() + "</span>" : "<span class='timeline-photo none'></span>");
                buf.add("<span class='timeline-pname'>" + (npc.nameKnown ? npc.name : "<span class='timeline-bar'></span>") + "</span>");
                buf.add("<span class='timeline-job'>" + (npc.jobKnown ? npc.job : "?") + "</span>");
                buf.add("<span class='timeline-pxy'>" + (npc.areaKnown ? "(" + npc.area.x + "," + npc.area.y + ")" : "(?,?)") + "</span>");
                if (!npc.statusKnown)
                  buf.add("<span class='timeline-status unknown'>status ?</span>");
                else if (npc.isDead)
                  buf.add("<span class='timeline-status deceased'>deceased</span>");
                else buf.add("<span class='timeline-status ok'>active</span>");
                buf.add("</div>");
              }
          if (!npcKnown && event.npc.length > 0)
            buf.add("<div class='timeline-none'>unknown</div>");
          else if (event.npc.length == 0)
            buf.add("<div class='timeline-none'>none</div>");
          if (numProbed > 0 || numDeceased > 0)
            {
              buf.add("<div class='timeline-roll'>");
              if (numProbed > 0)
                buf.add("<span class='timeline-chip'>+" + numProbed + " probed</span>");
              if (numDeceased > 0)
                buf.add("<span class='timeline-chip dead'>+" + numDeceased + " deceased</span>");
              buf.add("</div>");
            }
          buf.add("</div></div></li>");
          eventsShown++;
          i++;
        }

      tlScroll.innerHTML = "<ol class='timeline-spine'>" + buf.toString() + "</ol>";
      // titlebar with live event/lead counts
      var clk = "<svg viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><circle cx='12' cy='12' r='9'/><path d='M12 7v5l3.5 2'/></svg>";
      var mag = "<svg viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><circle cx='11' cy='11' r='7'/><line x1='16' y1='16' x2='21' y2='21'/></svg>";
      titlebar.innerHTML = "<span class='wt'>TIMELINE</span><span class='win-stats'>" +
        "<span class='timeline-live'>LIVE</span>" +
        "<span class='statchip evolution-tip timeline-ev' data-tip='Timeline events revealed'>" + clk + eventsShown + "</span>" +
        "<span class='statchip evolution-tip timeline-leads' data-tip='Leads still open to investigate'>" + mag + totalLeads + "</span></span>";
    }

  override function hide(?skipAnimation: Bool = false)
    {
      animatedHide();
    }
}
