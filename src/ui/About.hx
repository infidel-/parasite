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
      body.className = 'about-body';
      window.appendChild(body);

      // specimen hero: crimson-graded still + scan band + caption
      var hero = Browser.document.createDivElement();
      hero.className = 'about-hero';
      hero.innerHTML =
        '<img class="about-img" src="' + AssetPath.resolve('img/event/what_am_i.jpg') + '" alt="" draggable="false" ' +
        'onerror="this.closest(\'.about-hero\').classList.add(\'noimg\')">' +
        '<div class="about-scan" aria-hidden="true"></div>' +
        '<figcaption class="about-cap">' +
        '<span class="about-cap-k">specimen &middot; unclassified</span>' +
        '<span class="about-cap-q">WHAT AM I?</span></figcaption>';
      body.appendChild(hero);

      // credits column
      var credits = Browser.document.createDivElement();
      credits.className = 'about-credits';
      var tag = 'A biological organism learning to wear the city.';
      credits.innerHTML =
        '<header class="about-head">' +
        '<div class="about-titleline"><h2 class="about-game">PARASITE</h2>' +
        '<span class="about-ver">v' + Version.getVersion() + '</span></div>' +
        '<p class="about-tag" data-text="' + tag + '">' + tag + '</p></header>' +
        '<ul class="about-roll">' +
        '<li><span class="about-role">Game design &amp; programming</span><span class="about-name">Infidel</span></li>' +
        '<li><span class="about-role">Music &amp; sound</span><span class="about-name">MaxStack</span>' +
        '<a class="about-link" href="https://www.youtube.com/@MaxStackMusic" target="_blank" rel="noopener">youtube.com/@MaxStackMusic</a></li>' +
        '<li><span class="about-role">Additional art &amp; testing</span><span class="about-name">iwanPlays</span></li>' +
        '</ul>' +
        '<div class="about-colophon">' +
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
