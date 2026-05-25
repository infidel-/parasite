// mods management window

package ui;

import mods.AssetPath;
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

  var contents: DivElement;

  public function new(g: Game)
    {
      super(g, 'window-mods');
      window.style.borderImage = "url('" + AssetPath.resolve('img/window-dialog.png') +
        "') 100 fill / 1 / 0 stretch";

      var title = Browser.document.createDivElement();
      title.id = 'window-mods-title';
      title.className = 'window-title';
      title.innerHTML = 'MODS';
      window.appendChild(title);

      contents = Browser.document.createDivElement();
      contents.id = 'window-mods-contents';
      window.appendChild(contents);

      addCloseButton();
      close.onclick = function (e) {
        game.scene.sounds.play('click-menu');
        game.scene.sounds.play('window-close');
        game.ui.state = UISTATE_MAINMENU;
      }

      rebuild();
    }

// re-render the list + footer; called on show() and after rescan
  function rebuild()
    {
      contents.innerHTML = '';

      var local = ModRegistry.all.filter(function(m) return m.source != 'workshop');
      var workshop = ModRegistry.all.filter(function(m) return m.source == 'workshop');

      if (local.length == 0 && workshop.length == 0)
        {
          var empty = Browser.document.createDivElement();
          empty.className = 'mods-empty';
          empty.innerHTML = 'No mods installed. Use the buttons below to add some.';
          contents.appendChild(empty);
        }

      if (local.length > 0)
        {
          addSection('LOCAL');
          for (m in local) addRow(m);
        }
      if (workshop.length > 0)
        {
          addSection('WORKSHOP');
          for (m in workshop) addRow(m);
        }

      // footer notice + buttons
      var notice = Browser.document.createDivElement();
      notice.className = 'mods-notice';
      notice.innerHTML = 'Toggle changes apply after restart.';
      contents.appendChild(notice);

      var bar = Browser.document.createDivElement();
      bar.className = 'mods-buttons';
      contents.appendChild(bar);

      addButton(bar, 'OPEN MODS FOLDER', function(e) {
        HostBridge.modsOpenFolder();
      });
      addButton(bar, 'BROWSE WORKSHOP', function(e) {
        HostBridge.shellOpenExternal(BROWSE_URL);
      });
    }

// section header (LOCAL / WORKSHOP)
  function addSection(label: String)
    {
      var sec = Browser.document.createDivElement();
      sec.className = 'mods-section';
      sec.innerHTML = label;
      contents.appendChild(sec);
    }

// single mod row: checkbox + name v0.0.0 + optional workshop arrow
// failed mods rendered grayed with reason on the next line
  function addRow(m: ModInfo)
    {
      var row = Browser.document.createDivElement();
      row.className = 'mods-row';
      contents.appendChild(row);

      var disabled = isDisabled(m.id);
      var failReason = ModRegistry.failed.get(m.id);
      var shadowed = (m.shadowedBy != null);
      if (failReason != null)
        row.classList.add('mods-row-failed');
      if (shadowed)
        row.classList.add('mods-row-shadowed');

      // checkbox: hidden input + faux `.checkbox-span` box (matches the
      // pattern used by addCheckbox in UIWindow; styled by app.css via the
      // global `[type=checkbox]:checked + span:before` rule). shadowed
      // entries share an id with the loaded mod, so toggling here would
      // silently disable the wrong source — disable it.
      var cbLabel = Browser.document.createLabelElement();
      cbLabel.className = 'mods-check';
      row.appendChild(cbLabel);
      var cb = Browser.document.createInputElement();
      cb.type = 'checkbox';
      cb.className = 'checkbox-element';
      cb.checked = !disabled && !shadowed;
      cb.disabled = shadowed;
      if (!shadowed)
        cb.onclick = function (e: PointerEvent) {
          toggle(m.id, cb.checked);
        };
      cbLabel.appendChild(cb);
      var cbSpan = Browser.document.createSpanElement();
      cbSpan.className = 'checkbox-span mods-check-span';
      cbLabel.appendChild(cbSpan);

      // name + version
      var label = Browser.document.createDivElement();
      label.className = 'mods-label';
      label.innerHTML = m.name + ' ' + Const.smallgray('v' + m.version);
      row.appendChild(label);

      // workshop "→" link
      if (m.source == 'workshop' && m.workshopID != null)
        {
          var link = Browser.document.createSpanElement();
          link.className = 'mods-link';
          link.innerHTML = '&rarr;';
          link.title = 'Open on Steam Workshop';
          link.onclick = function (e) {
            HostBridge.shellOpenExternal(
              'steam://url/CommunityFilePage/' + m.workshopID);
          };
          row.appendChild(link);
        }

      // failure reason on its own indented line
      if (failReason != null)
        {
          var reason = Browser.document.createDivElement();
          reason.className = 'mods-reason';
          reason.innerHTML = 'failed: ' + failReason;
          contents.appendChild(reason);
        }

      // shadow notice on its own indented line
      if (shadowed)
        {
          var reason = Browser.document.createDivElement();
          reason.className = 'mods-reason';
          reason.innerHTML = 'shadowed by ' + m.shadowedBy;
          contents.appendChild(reason);
        }
    }

  function isDisabled(id: String): Bool
    {
      for (d in game.profile.object.disabledMods)
        if (d == id) return true;
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

  function addButton(parent: DivElement, text: String, onclick: Dynamic -> Void)
    {
      var b = Browser.document.createDivElement();
      b.className = 'mods-button';
      b.innerHTML = text;
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
