// about GUI window

package jsui;

import js.Browser;
import js.html.DivElement;
import js.html.FieldSetElement;
import js.html.LegendElement;

import game.Game;

class About extends UIWindow
{
  var text: DivElement;

  public function new (g: Game)
    {
      super(g, 'window-about');
      window.style.borderImage = "url('./img/window-dialog.png') 100 fill / 1 / 0 stretch";

      var title = Browser.document.createDivElement();
      title.id = 'window-about-title';
      title.innerHTML = 'ABOUT';
      window.appendChild(title);
      var cont = Browser.document.createDivElement();
      cont.id = 'window-about-text';
      window.appendChild(cont);
      cont.innerHTML = 
        '<center>' +
        '<br>' +
        '<br>' +
        'Game design and programming<br>' +
        '<b>Infidel</b> (www.infidel.rocks)<br>' +
        '<br>' +
        'Music and sounds<br>' +
        '<b>MaxStack</b> (www.maxstack.rocks)<br>' +
        '<br>' +
        'Additional art and testing<br>' +
        '<b>iwanPlays</b><br>' +
        '<br>' +
        'This game uses free icons from www.flaticon.com. Full list is available in icons.txt. It also uses sounds from FreeSound (freesound.org) and ZapSplat (www.zapsplat.com). Full list of sounds is available in sounds.txt.<br>' +
        '<br>' +
        'This game uses fonts from Pixel Sagas (www.pixelsagas.com)<br>' +
        '</center>';

      addCloseButton();
      close.onclick = function (e) {
        game.scene.sounds.play('click-menu');
        game.scene.sounds.play('window-close');
        game.ui.state = UISTATE_MAINMENU;
      }
    }
}
