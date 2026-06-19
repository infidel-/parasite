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
      tlScroll.className = 'hud-scroll tl-scroll';
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

          var cls = 'tl-event';
          if (redactedEv)
            cls += ' redacted-ev';
          if (hasLeads)
            cls += ' has-leads';
          buf.add("<li class='" + cls + "' style='--i:" + i + "'>");
          buf.add("<span class='tl-node'></span><div class='tl-card'><div class='tl-fx'></div>");
          if (redactedEv)
            buf.add("<div class='tl-stamp'>SEALED</div>");

          // header: event id + location (name + coords, or blackout bar + (?,?))
          buf.add("<div class='tl-ehead'><span class='tl-en'>EVENT " + event.num + "</span><span class='tl-loc'>");
          if (event.location != null)
            {
              if (event.locationKnown)
                {
                  if (event.location.hasName)
                    buf.add(event.location.name + " ");
                  buf.add("<span class='tl-xy'>(" + event.location.area.x + "," + event.location.area.y + ")</span>");
                }
              else buf.add("<span class='tl-bar wide'></span> <span class='tl-xy'>(?,?)</span>");
            }
          buf.add("</span></div>");

          // notes: known = bullet text; unknown w/ clues = ? + 4-pip clue meter
          buf.add("<ul class='tl-notes'>");
          for (n in event.notes)
            {
              if (n.isKnown)
                buf.add("<li class='tl-note'>" + n.text + "</li>");
              else if (n.clues > 0)
                {
                  buf.add("<li class='tl-note redacted'><span class='tl-q'>?</span><span class='tl-clues'>");
                  for (c in 0...4)
                    buf.add(c < n.clues ? "<i class='on'></i>" : "<i></i>");
                  buf.add("</span><span class='tl-cn'>" + n.clues + "/4</span></li>");
                }
            }
          buf.add("</ul>");

          // participants: per-field redactable ID tags; alive-probed / deceased rolled up
          buf.add("<div class='tl-parts'><div class='tl-ptitle'>Participants</div>");
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
                buf.add("<div class='tl-row" + (npc.nameKnown ? "" : " redacted") + "'>");
                buf.add(npc.jobKnown ? "<span class='tl-photo'>" + UISvg.face() + "</span>" : "<span class='tl-photo none'></span>");
                buf.add("<span class='tl-pname'>" + (npc.nameKnown ? npc.name : "<span class='tl-bar'></span>") + "</span>");
                buf.add("<span class='tl-job'>" + (npc.jobKnown ? npc.job : "?") + "</span>");
                buf.add("<span class='tl-pxy'>" + (npc.areaKnown ? "(" + npc.area.x + "," + npc.area.y + ")" : "(?,?)") + "</span>");
                if (!npc.statusKnown)
                  buf.add("<span class='tl-status unknown'>status ?</span>");
                else if (npc.isDead)
                  buf.add("<span class='tl-status deceased'>deceased</span>");
                else buf.add("<span class='tl-status ok'>active</span>");
                buf.add("</div>");
              }
          if (!npcKnown && event.npc.length > 0)
            buf.add("<div class='tl-none'>unknown</div>");
          else if (event.npc.length == 0)
            buf.add("<div class='tl-none'>none</div>");
          if (numProbed > 0 || numDeceased > 0)
            {
              buf.add("<div class='tl-roll'>");
              if (numProbed > 0)
                buf.add("<span class='tl-chip'>+" + numProbed + " probed</span>");
              if (numDeceased > 0)
                buf.add("<span class='tl-chip dead'>+" + numDeceased + " deceased</span>");
              buf.add("</div>");
            }
          buf.add("</div></div></li>");
          eventsShown++;
          i++;
        }

      tlScroll.innerHTML = "<ol class='tl-spine'>" + buf.toString() + "</ol>";
      // titlebar with live event/lead counts
      var clk = "<svg viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><circle cx='12' cy='12' r='9'/><path d='M12 7v5l3.5 2'/></svg>";
      var mag = "<svg viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><circle cx='11' cy='11' r='7'/><line x1='16' y1='16' x2='21' y2='21'/></svg>";
      titlebar.innerHTML = "<span class='wt'>TIMELINE</span><span class='win-stats'>" +
        "<span class='tl-live'>LIVE</span>" +
        "<span class='statchip tl-ev'>" + clk + eventsShown + "</span>" +
        "<span class='statchip tl-leads'>" + mag + totalLeads + "</span></span>";
    }

  override function hide(?skipAnimation: Bool = false)
    {
      animatedHide();
    }
}
