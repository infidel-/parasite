// about window — credits roll + specimen hero

package ui;

import mods.AssetPath;
import js.Browser;
import js.html.DivElement;

import game.Game;

class About extends UIWindow
{
  public function new (g: Game)
    {
      super(g, 'window-about');

      addCorners();

      var body = Browser.document.createDivElement();
      body.className = 'ab-body';
      window.appendChild(body);

      // specimen hero: crimson-graded still + scan band + caption
      var hero = Browser.document.createDivElement();
      hero.className = 'ab-hero';
      hero.innerHTML =
        '<img class="ab-img" src="' + AssetPath.resolve('img/event/what_am_i.jpg') + '" alt="" draggable="false" ' +
        'onerror="this.closest(\'.ab-hero\').classList.add(\'noimg\')">' +
        '<div class="ab-scan" aria-hidden="true"></div>' +
        '<figcaption class="ab-cap">' +
        '<span class="ab-cap-k">specimen &middot; unclassified</span>' +
        '<span class="ab-cap-q">WHAT AM I?</span></figcaption>';
      body.appendChild(hero);

      // credits column
      var credits = Browser.document.createDivElement();
      credits.className = 'ab-credits';
      var tag = 'A biological organism learning to wear the city.';
      credits.innerHTML =
        '<header class="ab-head">' +
        '<div class="ab-titleline"><h2 class="ab-game">PARASITE</h2>' +
        '<span class="ab-ver">v' + Version.getVersion() + '</span></div>' +
        '<p class="ab-tag" data-text="' + tag + '">' + tag + '</p></header>' +
        '<ul class="ab-roll">' +
        '<li><span class="ab-role">Game design &amp; programming</span><span class="ab-name">Infidel</span></li>' +
        '<li><span class="ab-role">Music &amp; sound</span><span class="ab-name">MaxStack</span>' +
        '<a class="ab-link" href="https://www.youtube.com/@MaxStackMusic" target="_blank" rel="noopener">youtube.com/@MaxStackMusic</a></li>' +
        '<li><span class="ab-role">Additional art &amp; testing</span><span class="ab-name">iwanPlays</span></li>' +
        '</ul>' +
        '<div class="ab-colophon">' +
        '<p>Free icons &mdash; <b>flaticon.com</b> <span>(icons.txt)</span></p>' +
        '<p>Sounds &mdash; <b>FreeSound</b> &amp; <b>ZapSplat</b> <span>(sounds.txt)</span></p>' +
        '<p>Fonts &mdash; <b>Pixel Sagas</b></p></div>';
      body.appendChild(credits);

      addWinClose(function (e) {
        game.scene.sounds.play('click-menu');
        game.scene.sounds.play('window-close');
        game.ui.state = UISTATE_MAINMENU;
      });
    }
}
