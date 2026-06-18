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
  var flavor: String;   // flavor text shown under the image
}

class NewGame extends UIWindow
{
  var list: DivElement;
  var imgEl: ImageElement;
  var flavorEl: DivElement;
  var rows: Array<ButtonElement>;
  var scenarios: Array<ScenarioInfo>;
  var activeIndex: Int;

  public function new(g: Game)
    {
      super(g, 'window-newgame');
      rows = [];
      activeIndex = 0;
      scenarios = [
        {
          id: 'alien',
          name: 'Scenario A',
          tag: '<span class="newgame-redact" aria-label="redacted">REDACTED</span> Parasite',
          accent: '#a45fe0',
          img: './img/scenario/a.jpg',
          flavor: 'Something fell from the dark between stars. It wakes in the gut of the city &mdash; hungry, hunted, learning to wear men like coats.'
        },
        {
          id: 'sandbox',
          name: 'Sandbox',
          tag: 'Open World',
          accent: '#3fd6c0',
          img: './img/scenario/sandbox.jpg',
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
      activeIndex = i;
      var s = scenarios[i];
      for (n in 0...rows.length)
        rows[n].classList.toggle('active', n == i);
      imgEl.src = s.img;
      flavorEl.innerHTML = s.flavor;
      window.style.setProperty('--newgame-accent', s.accent);
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

  override function show(?skipAnimation: Bool = false)
    {
      super.show(skipAnimation);
      select(activeIndex);
    }
}
