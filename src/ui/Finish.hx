// game finish (game over) window

package ui;

import mods.AssetPath;
import js.Browser;
import js.html.DivElement;
import js.html.ImageElement;

import game.Game;

class Finish extends UIWindow
{
  var card: DivElement;
  var hero: DivElement;
  var image: ImageElement;
  var titleEl: DivElement;
  var text: DivElement;

  // filter-name -> svg filter id used to grade the finish image
  static var filters: Map<String, String> = [
    'lose' => 'imgFinishLose',
    'alien' => 'msgGlitch',
    'cult' => 'imgCult',
  ];

  public function new(g: Game)
    {
      super(g, 'window-finish');
      window.className += ' window-dialog finish-win';

      // glass card holding the whole game-over screen
      card = Browser.document.createDivElement();
      card.className = 'finish-card';
      window.appendChild(card);

      // hero: filtered image + scrim + overlaid title
      hero = Browser.document.createDivElement();
      hero.className = 'finish-hero';
      image = Browser.document.createImageElement();
      image.className = 'finish-img';
      hero.appendChild(image);
      var grad = Browser.document.createDivElement();
      grad.className = 'finish-hero-grad';
      hero.appendChild(grad);
      titleEl = Browser.document.createDivElement();
      titleEl.className = 'finish-title';
      hero.appendChild(titleEl);
      card.appendChild(hero);

      // body: outcome prose + restart hint + close
      var body = Browser.document.createDivElement();
      body.className = 'finish-body';
      card.appendChild(body);

      text = Browser.document.createDivElement();
      text.className = 'finish-text';
      body.appendChild(text);

      var hint = Browser.document.createDivElement();
      hint.className = 'finish-hint';
      hint.innerHTML = 'Close the window to restart the game.';
      body.appendChild(hint);

      var close = Browser.document.createDivElement();
      close.className = 'finish-close';
      close.innerHTML = 'CLOSE';
      close.onclick = function (e) {
        game.scene.sounds.play('click-menu');
        game.scene.sounds.play('window-close');
        game.ui.closeWindow();
      }
      body.appendChild(close);
    }

// set parameters
  public override function setParams(obj: Dynamic)
    {
      var p: _FinishParams = cast obj;

      // title by outcome; cult death gets the psychedelic swanky font
      titleEl.innerHTML = (p.result == 'lose') ? 'GAME OVER' : 'THE END';
      titleEl.className = 'finish-title' + (p.filter == 'cult' ? ' finish-title-cult' : '');

      // hero image, graded by the requested filter
      if (p.img != null && p.img != '')
        {
          image.src = AssetPath.resolve('img/' + p.img + '.jpg');
          var fid = (p.filter != null) ? filters[p.filter] : null;
          // default lose grade when no explicit filter is given
          if (fid == null && p.result == 'lose')
            fid = filters['lose'];
          image.style.filter = (fid != null) ? 'url(#' + fid + ')' : '';
          hero.style.display = 'block';
        }
      else
        hero.style.display = 'none';

      text.innerHTML = (p.text != null) ? p.text : '';
    }

// action
  public override function action(index: Int)
    {
      game.ui.closeWindow();
    }

// animated pop-out close
  override function hide(?skipAnimation: Bool = false)
    {
      animatedHide();
    }
}
