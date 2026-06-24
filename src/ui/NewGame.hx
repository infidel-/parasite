// new game window — scenario / sandbox selector

package ui;

import js.Browser;
import js.html.DivElement;
import js.html.ImageElement;
import js.html.ButtonElement;

import game.Game;

// one selectable scenario row
typedef ScenarioInfo =
{
  var id: String;       // scenarioStringID passed to newGame()
  var name: String;     // display name
  var tag: String;      // small label under the name (may contain markup)
  var accent: String;   // per-scenario accent color
  var img: String;      // preview image url
  var filter: String;   // css filter applied to the preview image (svg grade)
  var grid: Bool;       // play the recon-grid wave overlay on selection
  var flavor: String;   // flavor text shown under the image
}

class NewGame extends UIWindow
{
  var list: DivElement;
  var imgEl: ImageElement;
  var gridEl: DivElement;
  var flavorEl: DivElement;
  var rows: Array<ButtonElement>;
  var scenarios: Array<ScenarioInfo>;
  var activeIndex: Int;
  var gridTimer: Int;

  public function new(g: Game)
    {
      super(g, 'window-newgame');
      rows = [];
      activeIndex = 0;
      gridTimer = -1;
      scenarios = [
        {
          id: 'alien',
          name: 'Scenario A',
          tag: '<span class="newgame-redact" aria-label="redacted">REDACTED</span> Parasite',
          accent: '#a45fe0',
          img: './img/scenario/a.jpg',
          filter: 'url(#msgEngram)',
          grid: false,
          flavor: 'Something fell from the dark between stars. It wakes in the gut of the city &mdash; hungry, hunted, learning to wear men like coats.'
        },
        {
          id: 'sandbox',
          name: 'Sandbox',
          tag: 'Open World',
          accent: '#3fd6c0',
          img: './img/scenario/sandbox.jpg',
          filter: 'url(#msgRecon)',
          grid: true,
          flavor: 'No script. No leash. The whole city to infest at your own pace &mdash; every alley, every host, every quiet experiment.'
        },
      ];

      addCorners();

      var title = Browser.document.createDivElement();
      title.id = 'window-newgame-title';
      title.className = 'win-title';
      title.innerHTML = 'SELECT SCENARIO';
      window.appendChild(title);

      // body: scenario list (left) + preview image & flavor (right)
      var body = Browser.document.createDivElement();
      body.className = 'newgame-body';
      window.appendChild(body);

      list = Browser.document.createDivElement();
      list.className = 'newgame-list';
      body.appendChild(list);
      for (i in 0...scenarios.length)
        addRow(i);

      var preview = Browser.document.createDivElement();
      preview.className = 'newgame-preview';
      body.appendChild(preview);
      var imgWrap = Browser.document.createDivElement();
      imgWrap.className = 'newgame-img-wrap';
      preview.appendChild(imgWrap);
      imgEl = Browser.document.createImageElement();
      imgEl.className = 'newgame-img';
      imgWrap.appendChild(imgEl);
      gridEl = Browser.document.createDivElement();
      gridEl.className = 'newgame-grid';
      imgWrap.appendChild(gridEl);
      flavorEl = Browser.document.createDivElement();
      flavorEl.className = 'newgame-flavor';
      preview.appendChild(flavorEl);

      // footer: START launches the selected scenario
      var foot = Browser.document.createDivElement();
      foot.className = 'newgame-foot';
      window.appendChild(foot);
      var start = Browser.document.createButtonElement();
      start.className = 'newgame-start';
      start.innerHTML = 'START';
      start.onclick = function (e) {
        game.scene.sounds.play('click-menu');
        newGame(scenarios[activeIndex].id);
      };
      foot.appendChild(start);

      // corner-X returns to the main menu
      addWinClose(function (e) {
        game.scene.sounds.play('click-menu');
        game.ui.state = UISTATE_MAINMENU;
      });
    }

// add a scenario row (button) to the list
  function addRow(i: Int)
    {
      var s = scenarios[i];
      var row = Browser.document.createButtonElement();
      row.className = 'newgame-row';
      row.style.setProperty('--newgame-color', s.accent);
      row.innerHTML = '<span class="newgame-row-bar"></span>' +
        '<span class="newgame-row-txt"><span class="newgame-name">' + s.name + '</span>' +
        '<span class="newgame-tag">' + s.tag + '</span></span>';
      row.onclick = function (e) {
        game.scene.sounds.play('click-menu');
        select(i);
      };
      list.appendChild(row);
      rows.push(row);
    }

// select a scenario: swap the preview image / flavor / accent and mark the row
  function select(i: Int)
    {
      i = (i + scenarios.length) % scenarios.length;
      var changed = (i != activeIndex);
      activeIndex = i;
      var s = scenarios[i];
      for (n in 0...rows.length)
        rows[n].classList.toggle('active', n == i);
      imgEl.src = s.img;
      imgEl.style.filter = s.filter;
      flavorEl.innerHTML = s.flavor;
      window.style.setProperty('--newgame-accent', s.accent);
      // recon-grid wave only when the selection actually changes
      if (s.grid && changed)
        gridWave();
      else
        gridEl.innerHTML = '';
    }

// build the sandbox recon-grid and run a diagonal flash wave across its cells
  function gridWave()
    {
      var wrap = gridEl.parentElement;
      var w = wrap.clientWidth;
      var h = wrap.clientHeight;
      // wait for layout if the window hasn't sized yet
      if (w < 4 || h < 4)
        {
          Browser.window.requestAnimationFrame(function(_) gridWave());
          return;
        }
      var cell = 40;
      var cols = Std.int(Math.max(1, Math.round(w / cell)));
      var rowN = Std.int(Math.max(1, Math.round(h / cell)));
      gridEl.style.gridTemplateColumns = 'repeat(' + cols + ',1fr)';
      gridEl.style.gridTemplateRows = 'repeat(' + rowN + ',1fr)';
      gridEl.innerHTML = '';
      var span = Std.int(Math.max(1, cols + rowN - 2));
      for (r in 0...rowN)
        for (c in 0...cols)
          {
            var gc = Browser.document.createDivElement();
            gc.className = 'gc';
            var delay = Math.round((c + r) / span * 93) / 100;
            gc.style.animation = 'newgame-gc-flash .33s ease-out ' + delay + 's both';
            gridEl.appendChild(gc);
          }
      // clear cells once the wave finishes (cancel a pending clear from a prior wave)
      if (gridTimer != -1)
        Browser.window.clearTimeout(gridTimer);
      gridTimer = Browser.window.setTimeout(function() gridEl.innerHTML = '', 1800);
    }

// start new game
  function newGame(scenarioID: String)
    {
      game.scenarioStringID = scenarioID;
      game.isStarted = true;
      game.ui.closeWindow();
      game.restart();
      game.ui.canvas.style.visibility = 'visible';
    }

// in-window keys: arrows pick a scenario, Enter starts the selected one
  public override function handleKey(key: String, code: String, altKey: Bool, ctrlKey: Bool): Bool
    {
      if (code == 'ArrowDown')
        select(activeIndex + 1);
      else if (code == 'ArrowUp')
        select(activeIndex - 1);
      else if (key == 'Enter' ||
          key == 'NumpadEnter')
        newGame(scenarios[activeIndex].id);
      else return false;
      return true;
    }

// action handling (number-key dispatch selects a scenario)
  public override function action(index: Int)
    {
      if (index >= 1 &&
          index <= scenarios.length)
        select(index - 1);
    }

// dom row for a 1-based index, so keyboard shortcuts click/animate it
  public override function getButton(index: Int): js.html.Element
    {
      if (index < 1 ||
          index > rows.length)
        return null;
      return rows[index - 1];
    }

  override function show(?skipAnimation: Bool = false)
    {
      super.show(skipAnimation);
      select(activeIndex);
    }

  override function hide(?skipAnimation: Bool = false)
    {
      animatedHide();
    }
}
