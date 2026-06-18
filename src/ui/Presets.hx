// custom difficulty presets window

package ui;

import game.Game;
import js.Browser;
import js.html.DivElement;
import js.html.InputElement;
import js.html.SelectElement;

class Presets extends UIWindow
{
  static var LVL = [ 'easy', 'norm', 'hard' ];
  static var LVLNAME = [ 'EASY', 'NORMAL', 'HARD' ];
  // verdict thresholds on the 0..2 average severity
  static var VERDICTS: Array<{ t: Float, n: String }> = [
    { t: 0.4, n: 'MERCIFUL' }, { t: 0.9, n: 'LENIENT' }, { t: 1.4, n: 'BALANCED' },
    { t: 1.85, n: 'RUTHLESS' }, { t: 99, n: 'LETHAL' },
  ];

  var grid: DivElement;
  var select: SelectElement;
  var nameInput: InputElement;
  var noteTxt: DivElement;
  var sevMarker: DivElement;
  var sevVerdict: DivElement;
  var current: Int;        // index into difficultyPresets, -1 = none
  var noteTimer: Int;

  public function new(g: Game)
    {
      super(g, 'window-presets');
      current = -1;
      noteTimer = 0;

      addCorners();

      var titlebar = Browser.document.createDivElement();
      titlebar.className = 'presets-titlebar';
      titlebar.innerHTML = '<span class="presets-title">CUSTOM DIFFICULTY</span>' +
        '<span class="presets-sub">presets</span>';
      window.appendChild(titlebar);

      // preset bar: select + name + new/save/delete
      var bar = Browser.document.createDivElement();
      bar.className = 'presets-bar';
      window.appendChild(bar);
      var selwrap = Browser.document.createDivElement();
      selwrap.className = 'presets-selwrap';
      select = Browser.document.createSelectElement();
      select.className = 'presets-select';
      select.onchange = function (e) load(select.selectedIndex);
      selwrap.appendChild(select);
      bar.appendChild(selwrap);
      nameInput = Browser.document.createInputElement();
      nameInput.type = 'text';
      nameInput.className = 'presets-name';
      nameInput.placeholder = 'Preset name...';
      bar.appendChild(nameInput);
      addBtn(bar, 'presets-new', 'New preset',
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>',
        newPreset);
      addBtn(bar, 'presets-save', 'Save preset',
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"><path d="M5 4h11l3 3v13H5z"/><path d="M8 4v5h7V4"/><rect x="8" y="13" width="8" height="6"/></svg>',
        savePreset);
      addBtn(bar, 'presets-del', 'Delete preset',
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="6" y1="6" x2="18" y2="18"/><line x1="18" y1="6" x2="6" y2="18"/></svg>',
        deletePreset);

      // severity meter
      var sev = Browser.document.createDivElement();
      sev.className = 'presets-sev';
      sev.innerHTML = '<div class="presets-sev-hd"><span class="presets-sev-lbl">SEVERITY</span>' +
        '<span class="presets-sev-verdict">&mdash;</span></div>' +
        '<div class="presets-sev-track"><div class="presets-sev-marker"></div></div>';
      window.appendChild(sev);
      sevVerdict = cast sev.querySelector('.presets-sev-verdict');
      sevMarker = cast sev.querySelector('.presets-sev-marker');

      // category grid
      grid = Browser.document.createDivElement();
      grid.className = 'presets-grid';
      window.appendChild(grid);
      buildGrid();

      // terminal note panel
      var note = Browser.document.createDivElement();
      note.className = 'presets-note';
      note.innerHTML = '<span class="presets-note-pre">&gt;</span>' +
        '<span class="presets-note-txt">Hover a level to read what it changes.</span>';
      window.appendChild(note);
      noteTxt = cast note.querySelector('.presets-note-txt');

      addWinClose(function (e) {
        savePreset(null);
        game.scene.sounds.play('click-menu');
        game.scene.sounds.play('window-close');
        game.ui.state = UISTATE_OPTIONS;
      });
    }

// add an icon button to the preset bar
  function addBtn(bar: DivElement, cls: String, title: String, svg: String, f: Dynamic -> Void)
    {
      var b = Browser.document.createButtonElement();
      b.className = 'presets-btn ' + cls;
      b.title = title;
      b.innerHTML = svg;
      b.onclick = function (e) {
        game.scene.sounds.play('click-menu');
        f(e);
      };
      bar.appendChild(b);
    }

// build the header + per-category graded selector rows
  function buildGrid()
    {
      grid.innerHTML = '';
      var head = Browser.document.createDivElement();
      head.className = 'presets-head';
      head.innerHTML = '<span></span><div class="presets-head-cols">' +
        '<span class="lv-easy">EASY</span><span class="lv-norm">NORMAL</span><span class="lv-hard">HARD</span></div>';
      grid.appendChild(head);

      for (key in Difficulty.choices.keys())
        {
          var choice = Difficulty.choices.get(key);
          var row = Browser.document.createDivElement();
          row.className = 'presets-row';
          var name = Browser.document.createDivElement();
          name.className = 'presets-cat';
          name.textContent = choice.title;
          row.appendChild(name);
          var seg = Browser.document.createDivElement();
          seg.className = 'presets-seg';
          for (i in 0...3)
            {
              var opt = Browser.document.createLabelElement();
              opt.className = 'presets-opt lv-' + LVL[i];
              opt.innerHTML = '<input type="radio" name="preset-' + key + '" value="' + i + '">' + LVLNAME[i];
              var ii = i;
              var kk = key;
              cast(opt.querySelector('input'), InputElement).onchange = function (e) setSeg(kk, ii);
              opt.addEventListener('pointerenter', function(e) note(choice.notes[ii]));
              opt.addEventListener('pointerleave', function(e) note(null));
              seg.appendChild(opt);
            }
          row.appendChild(seg);
          grid.appendChild(row);
        }
    }

// select a level for a category, store it (1-based) on the current preset
  function setSeg(key: String, i: Int)
    {
      var inputs = grid.querySelectorAll('input[name="preset-' + key + '"]');
      for (n in 0...inputs.length)
        {
          var inp: InputElement = cast inputs.item(n);
          inp.checked = (n == i);
          inp.parentElement.classList.toggle('sel', n == i);
        }
      if (current >= 0)
        game.profile.object.difficultyPresets[current].settings.set(key, i + 1);
      severity();
    }

// clear a category's selection
  function clearSeg(key: String)
    {
      var inputs = grid.querySelectorAll('input[name="preset-' + key + '"]');
      for (n in 0...inputs.length)
        {
          var inp: InputElement = cast inputs.item(n);
          inp.checked = false;
          inp.parentElement.classList.remove('sel');
        }
    }

// load a preset's settings into the grid (settings are 1-based)
  function load(idx: Int)
    {
      current = idx;
      if (idx < 0)
        {
          nameInput.value = '';
          for (key in Difficulty.choices.keys())
            clearSeg(key);
          severity();
          return;
        }
      var p = game.profile.object.difficultyPresets[idx];
      nameInput.value = p.name;
      for (key in Difficulty.choices.keys())
        {
          var v = p.settings.get(key);
          if (v == null)
            clearSeg(key);
          else setSeg(key, v - 1);
        }
      severity();
    }

// recompute the aggregate-severity marker + verdict (avg of 0-based picks, 0..2)
  function severity()
    {
      if (current < 0)
        {
          sevMarker.style.left = '0%';
          sevVerdict.textContent = '—';
          sevVerdict.style.color = 'var(--blue-gray)';
          return;
        }
      var s = game.profile.object.difficultyPresets[current].settings;
      var sum = 0.0;
      var c = 0;
      for (key in Difficulty.choices.keys())
        {
          var v = s.get(key);
          if (v != null)
            {
              sum += (v - 1);
              c++;
            }
        }
      var avg = (c > 0 ? sum / c : 0);
      var col = 'hsl(' + Math.round(120 * (1 - avg / 2)) + ',60%,62%)';
      sevMarker.style.left = (avg / 2 * 100) + '%';
      sevMarker.style.background = col;
      sevMarker.style.boxShadow = '0 0 12px 2px ' + col;
      var label = 'LETHAL';
      for (vd in VERDICTS)
        if (avg < vd.t)
          {
            label = vd.n;
            break;
          }
      sevVerdict.textContent = label;
      sevVerdict.style.color = col;
    }

// fast typewriter reveal of the hovered level's description
  function note(txt: String)
    {
      Browser.window.clearInterval(noteTimer);
      var has = (txt != null);
      noteTxt.classList.toggle('has', has);
      var full = (has ? txt : 'Hover a level to read what it changes.');
      noteTxt.textContent = '';
      var i = 0;
      noteTimer = Browser.window.setInterval(function() {
        i += 2;
        noteTxt.textContent = full.substr(0, i);
        if (i >= full.length)
          {
            Browser.window.clearInterval(noteTimer);
            noteTxt.textContent = full;
          }
      }, 9);
    }

// rebuild the preset dropdown, keep selection
  function refreshSelect(keep: Int)
    {
      select.innerHTML = '';
      var presets = game.profile.object.difficultyPresets;
      for (p in presets)
        {
          var op = Browser.document.createOptionElement();
          op.text = p.name;
          select.appendChild(op);
        }
      if (presets.length > 0)
        select.selectedIndex = Std.int(Math.min((keep < 0 ? 0 : keep), presets.length - 1));
    }

// new all-easy preset
  function newPreset(e)
    {
      var presets = game.profile.object.difficultyPresets;
      var p = { name: 'PRESET ' + (presets.length + 1), settings: new haxe.DynamicAccess<Int>() };
      for (key in Difficulty.choices.keys())
        p.settings.set(key, 1);
      presets.push(p);
      game.profile.save();
      refreshSelect(presets.length - 1);
      load(presets.length - 1);
      nameInput.focus();
      nameInput.select();
    }

// persist current preset name + settings
  function savePreset(e)
    {
      if (current < 0)
        return;
      var p = game.profile.object.difficultyPresets[current];
      var nm = StringTools.trim(nameInput.value);
      if (nm != '')
        p.name = nm;
      game.profile.save();
      refreshSelect(current);
    }

// delete current preset, reselect a neighbor
  function deletePreset(e)
    {
      if (current < 0)
        return;
      var presets = game.profile.object.difficultyPresets;
      presets.splice(current, 1);
      game.profile.save();
      if (presets.length > 0)
        {
          var ni = Std.int(Math.max(0, current - 1));
          refreshSelect(ni);
          load(ni);
        }
      else
        {
          refreshSelect(-1);
          load(-1);
        }
    }

  override function hide(?skipAnimation: Bool = false)
    {
      animatedHide();
    }

  override function update()
    {
      refreshSelect(current < 0 ? 0 : current);
      var presets = game.profile.object.difficultyPresets;
      load(presets.length > 0 ? select.selectedIndex : -1);
      note(null);
    }
}
