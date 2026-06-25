// spoon mode options window — garnet specimen hero + toggle deck

package ui;

import mods.AssetPath;
import js.Browser;
import js.html.DivElement;

import game.Game;

class Spoon extends UIWindow
{
  public function new(g: Game)
    {
      super(g, 'window-spoon');

      addCorners();

      var body = Browser.document.createDivElement();
      body.className = 'spoon-body';
      window.appendChild(body);

      // garnet specimen hero: graded still + scan band + caption
      var hero = Browser.document.createDivElement();
      hero.className = 'spoon-hero';
      hero.innerHTML =
        '<img class="spoon-img" src="' + AssetPath.resolve('img/pedia/spoon.jpg') + '" alt="" draggable="false" ' +
        'onerror="this.closest(\'.spoon-hero\').classList.add(\'noimg\')">' +
        '<div class="spoon-scan" aria-hidden="true"></div>' +
        '<figcaption class="spoon-cap">' +
        '<span class="spoon-cap-k">anomaly &middot; do not bend</span>' +
        '<span class="spoon-cap-q">THERE IS NO SPOON</span></figcaption>';
      body.appendChild(hero);

      // panel: random title + toggle deck + forum note
      var panel = Browser.document.createDivElement();
      panel.className = 'spoon-panel';
      body.appendChild(panel);

      var titles = [
        'THERE IS NO SPOON',
        'THERE IS NO SPOON?',
        'THE SPOON IS THERE',
        'CERTAINLY SPOON',
        'NO SPOON AT ALL',
        'WHY SO SPOON?',
      ];
      var title = Browser.document.createDivElement();
      title.className = 'spoon-title';
      title.innerHTML = titles[Std.random(titles.length)];
      panel.appendChild(title);

      var deck = Browser.document.createDivElement();
      deck.className = 'spoon-deck';
      panel.appendChild(deck);
      addToggle(deck, 'All basic improvements available',
        'spoonEvolutionBasic', game.config.spoonEvolutionBasic);
      addToggle(deck, 'No energy loss on habitat destruction',
        'spoonHabitats', game.config.spoonHabitats);
      addToggle(deck, 'No ambushes in habitats',
        'spoonHabitatAmbush', game.config.spoonHabitatAmbush);
      addToggle(deck, 'No saves limit',
        'spoonNoSavesLimit', game.config.spoonNoSavesLimit);

      var note = Browser.document.createDivElement();
      note.className = 'spoon-note';
      note.innerHTML = "Not a lot here yet. Want anything added? Write on the forums and I'll see if I can make it happen.";
      panel.appendChild(note);

      addWinClose(function (e) {
        game.scene.sounds.play('click-menu');
        game.scene.sounds.play('window-close');
        game.ui.state = UISTATE_MAINMENU;
      });
    }

// toggle switch row (win-switch, mirrors Options)
  function addToggle(deck: DivElement, label: String, id: String, value: Bool)
    {
      var row = Browser.document.createDivElement();
      row.className = 'spoon-row';
      var lab = Browser.document.createDivElement();
      lab.className = 'spoon-label';
      lab.innerHTML = label;
      row.appendChild(lab);
      var sw = Browser.document.createDivElement();
      sw.className = 'win-switch' + (value ? ' on' : '');
      sw.onclick = function (e) {
        var on = !sw.classList.contains('on');
        sw.classList.toggle('on', on);
        game.config.set(id, (on ? '1' : '0'), true);
      };
      row.appendChild(sw);
      deck.appendChild(row);
    }

// run spoon side-effects on any close path (X / ESC / Enter), then animate out
  override function hide(?skipAnimation: Bool = false)
    {
      // if spoon mode was at all enabled, mark the game as spooned
      if (game.config.isSpoonMode())
        {
          if (!game.player.vars.isSpoonGame)
            game.log('Oh no. You have absolutely spooned the game.', COLOR_ALERT);
          game.player.vars.isSpoonGame = true;
        }
      if (game.config.spoonEvolutionBasic)
        game.player.evolutionManager.giveAllBasic();
      game.ui.hud.update();
      game.config.save(false);
      animatedHide();
    }
}
