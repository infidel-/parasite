// spoon mode options window

package jsui;

import js.Browser;
import js.html.DivElement;
import js.html.InputElement;
import js.html.SelectElement;
import js.html.OptionElement;
import js.html.PointerEvent;

import game.Game;

class Spoon extends UIWindow
{
  var contents: DivElement;
  var noteText: DivElement;

  public function new(g: Game)
    {
      super(g, 'window-spoon');
      window.style.borderImage = "url('./img/window-dialog.png') 100 fill / 1 / 0 stretch";

      var title = Browser.document.createDivElement();
      title.id = 'window-spoon-title';
      var titles = [
        'THERE IS NO SPOON',
        'THERE IS NO SPOON?',
        'THE SPOON IS THERE',
        'CERTAINLY SPOON',
        'NO SPOON AT ALL',
        'WHY SO SPOON?',
      ];
      title.innerHTML = titles[Std.random(titles.length)];
      window.appendChild(title);
      contents = Browser.document.createDivElement();
      contents.id = 'window-spoon-contents';
      window.appendChild(contents);

      addCloseButton();
      close.onclick = function (e) {
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
        game.scene.sounds.play('click-menu');
        game.scene.sounds.play('window-close');
        game.ui.state = UISTATE_MAINMENU;
      }

      addCheckbox(contents, 'All basic improvements available',
        'spoonEvolutionBasic', game.config.spoonEvolutionBasic, '-25.6%');
      addCheckbox(contents, 'No energy loss on habitat destruction',
        'spoonHabitats', game.config.spoonHabitats, '-16.7%');
      addCheckbox(contents, 'No ambushes in habitats',
        'spoonHabitatAmbush', game.config.spoonHabitatAmbush, '-42.4%');
      addCheckbox(contents, 'No saves limit',
        'spoonNoSavesLimit', game.config.spoonNoSavesLimit, '-63%');

      noteText = Browser.document.createDivElement();
      noteText.style.textAlign = 'center';
      noteText.style.paddingTop = '20px';
      noteText.innerHTML = Const.smallgray("As you can see there is not a lot here yet. If you want anything added, write on the forums and I'll see if I can make it happen.");
      contents.appendChild(noteText);
    }
}
