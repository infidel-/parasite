// mods management window — extensions registry

package ui;

import mods.ModInfo;
import mods.ModRegistry;
import js.Browser;
import js.html.DivElement;
import js.html.PointerEvent;

import game.Game;

#if electron
class Mods extends UIWindow
{
  static inline var BROWSE_URL = 'steam://url/SteamWorkshop/1920320';

  var body: DivElement;       // .mods-body (cards)
  var stat: DivElement;       // .mods-stat LOADED count

  public function new(g: Game)
    {
      super(g, 'window-mods');

      addCorners();

      // titlebar: MODS + subtitle + loaded-count stat
      var titlebar = Browser.document.createDivElement();
      titlebar.className = 'mods-titlebar';
      titlebar.innerHTML = '<span class="mods-title">MODS</span>' +
        '<span class="mods-sub">extensions registry</span>';
      stat = Browser.document.createDivElement();
      stat.className = 'mods-stat';
      titlebar.appendChild(stat);
      window.appendChild(titlebar);

      body = Browser.document.createDivElement();
      body.className = 'mods-body';
      window.appendChild(body);

      // footer: restart notice + action buttons
      var foot = Browser.document.createDivElement();
      foot.className = 'mods-foot';
      window.appendChild(foot);
      var notice = Browser.document.createDivElement();
      notice.className = 'mods-notice';
      notice.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><line x1="12" y1="8" x2="12" y2="13"/><line x1="12" y1="16" x2="12" y2="16"/></svg>' +
        'Toggle changes apply after restart.';
      foot.appendChild(notice);
      var actions = Browser.document.createDivElement();
      actions.className = 'mods-actions';
      foot.appendChild(actions);
      addButton(actions,
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"><path d="M3 7h6l2 2h10v9H3z"/></svg>OPEN MODS FOLDER',
        function(e) { HostBridge.modsOpenFolder(); });
      addButton(actions,
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M7 17 17 7"/><path d="M8 7h9v9"/></svg>BROWSE WORKSHOP',
        function(e) { HostBridge.shellOpenExternal(BROWSE_URL); });

      addWinClose(function (e) {
        game.scene.sounds.play('click-menu');
        game.scene.sounds.play('window-close');
        game.ui.state = UISTATE_MAINMENU;
      });

      rebuild();
    }

// re-render the card list; called on show() and after rescan
  function rebuild()
    {
      body.innerHTML = '';
      var local = ModRegistry.all.filter(function(m) return m.source != 'workshop');
      var workshop = ModRegistry.all.filter(function(m) return m.source == 'workshop');

      if (local.length == 0 &&
          workshop.length == 0)
        {
          var empty = Browser.document.createDivElement();
          empty.className = 'win-empty';
          empty.innerHTML = 'No mods installed. Use the buttons below to add some.';
          body.appendChild(empty);
        }

      if (local.length > 0)
        {
          var bd = addCard('LOCAL', local.length);
          for (m in local)
            addRow(bd, m);
        }
      if (workshop.length > 0)
        {
          var bd = addCard('WORKSHOP', workshop.length);
          for (m in workshop)
            addRow(bd, m);
        }
      refreshStat();
    }

// a registry section card; returns its body element for rows
  function addCard(label: String, count: Int): DivElement
    {
      var card = Browser.document.createDivElement();
      card.className = 'win-card';
      var hd = Browser.document.createDivElement();
      hd.className = 'win-card-hd mods-card-hd';
      hd.innerHTML = '<span class="win-cname">' + label + '</span>' +
        '<span class="win-count">' + (count < 10 ? '0' : '') + count + '</span>';
      var wrap = Browser.document.createDivElement();
      wrap.className = 'win-card-wrap';
      var bd = Browser.document.createDivElement();
      bd.className = 'win-card-bd';
      wrap.appendChild(bd);
      card.appendChild(hd);
      card.appendChild(wrap);
      body.appendChild(card);
      return bd;
    }

// one mod row: toggle + name/version (+reason) + status pill + workshop link
  function addRow(parent: DivElement, m: ModInfo)
    {
      var disabled = isDisabled(m.id);
      var failReason = ModRegistry.failed.get(m.id);
      var shadowed = (m.shadowedBy != null);
      var locked = (failReason != null || shadowed);

      var row = Browser.document.createDivElement();
      row.className = 'mods-row';
      if (failReason != null)
        row.classList.add('failed');
      else if (shadowed)
        row.classList.add('shadowed');
      else if (disabled)
        row.classList.add('off');
      parent.appendChild(row);

      // toggle (reuses .win-switch; #window-mods sets --win-accent green)
      var sw = Browser.document.createDivElement();
      sw.className = 'win-switch';
      if (!disabled && !locked)
        sw.classList.add('on');
      if (locked)
        sw.classList.add('mods-sw-lock');
      row.appendChild(sw);

      // name + version (+ optional reason line)
      var main = Browser.document.createDivElement();
      main.className = 'mods-main';
      var line = Browser.document.createDivElement();
      line.className = 'mods-line';
      line.innerHTML = '<span class="mods-name">' + m.name + '</span>' +
        '<span class="mods-ver">v' + m.version + '</span>';
      main.appendChild(line);
      if (failReason != null)
        addReason(main, 'failed: ' + failReason);
      else if (shadowed)
        addReason(main, 'shadowed by ' + m.shadowedBy);
      row.appendChild(main);

      // status pill
      var status = Browser.document.createDivElement();
      status.className = 'mods-status';
      if (failReason != null)
        setStatusClass(status, 'st-failed', 'FAILED');
      else if (shadowed)
        setStatusClass(status, 'st-shadowed', 'SHADOWED');
      else
        setStatus(status, !disabled);
      row.appendChild(status);

      // wire the toggle now that the status pill exists
      if (!locked)
        sw.onclick = function (e: PointerEvent) {
          var on = !sw.classList.contains('on');
          sw.classList.toggle('on', on);
          row.classList.toggle('off', !on);
          toggle(m.id, on);
          setStatus(status, on);
          refreshStat();
        };

      // workshop link
      if (m.source == 'workshop' &&
          m.workshopID != null)
        {
          var link = Browser.document.createDivElement();
          link.className = 'mods-link';
          link.title = 'Open on Steam Workshop';
          link.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M7 17 17 7"/><path d="M8 7h9v9"/></svg>';
          link.onclick = function (e) {
            HostBridge.shellOpenExternal('steam://url/CommunityFilePage/' + m.workshopID);
          };
          row.appendChild(link);
        }
    }

// indented reason / shadow line
  function addReason(main: DivElement, text: String)
    {
      var reason = Browser.document.createDivElement();
      reason.className = 'mods-reason';
      reason.innerHTML = text;
      main.appendChild(reason);
    }

// set the status pill to active/off (with flip animation)
  function setStatus(status: DivElement, on: Bool)
    {
      setStatusClass(status, (on ? 'st-active' : 'st-off'), (on ? 'ACTIVE' : 'OFF'));
    }

// apply a status pill class + label, replaying the flip animation
  function setStatusClass(status: DivElement, cls: String, label: String)
    {
      status.className = 'mods-status ' + cls;
      status.innerHTML = label;
      status.classList.remove('flip');
      untyped status.offsetWidth;
      status.classList.add('flip');
    }

// update the titlebar LOADED count (active = enabled, not failed/shadowed)
  function refreshStat()
    {
      var total = ModRegistry.all.length;
      var loaded = 0;
      for (m in ModRegistry.all)
        if (!isDisabled(m.id) &&
            ModRegistry.failed.get(m.id) == null &&
            m.shadowedBy == null)
          loaded++;
      stat.innerHTML = loaded + ' / ' + total + ' LOADED';
    }

  function isDisabled(id: String): Bool
    {
      for (d in game.profile.object.disabledMods)
        if (d == id)
          return true;
      return false;
    }

// toggle mod in profile.disabledMods; mirrors console/Mods.hx logic
  function toggle(id: String, enable: Bool)
    {
      var list = game.profile.object.disabledMods;
      var idx = list.indexOf(id);
      if (enable && idx >= 0)
        list.splice(idx, 1);
      else if (!enable && idx < 0)
        list.push(id);
      game.profile.save();
    }

  function addButton(parent: DivElement, html: String, onclick: Dynamic -> Void)
    {
      var b = Browser.document.createDivElement();
      b.className = 'mods-btn';
      b.innerHTML = html;
      b.onclick = function (e) {
        game.scene.sounds.play('click-menu');
        onclick(e);
      };
      parent.appendChild(b);
    }

  override function update()
    {
      rebuild();
    }
}
#end
