// about GUI window

package jsui;

import js.Browser;
import js.html.DivElement;

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
      title.className = 'window-title';
      title.innerHTML = 'ABOUT';
      window.appendChild(title);
      var cont = Browser.document.createDivElement();
      cont.id = 'window-about-cont';
      window.appendChild(cont);

      var left = Browser.document.createDivElement();
      left.id = 'window-about-left';
      cont.appendChild(left);
      var right = Browser.document.createDivElement();
      right.id = 'window-about-right';
      cont.appendChild(right);

      left.innerHTML = 
        '<center>' +
        'Game design and programming<br>' +
        '<b>Infidel</b>' +
        '<br><br>' +
        'Music and sounds<br>' +
        '<b>MaxStack</b><br>' +
        'https://www.youtube.com/@MaxStackMusic<br>' +
        '<br>' +
        'Additional art and testing<br>' +
        '<b>iwanPlays</b><br>' +
        '<br>' +
        'This game uses free icons from www.flaticon.com. Full list is available in icons.txt. It also uses sounds from FreeSound (freesound.org) and ZapSplat (www.zapsplat.com). Full list of sounds is available in sounds.txt.<br>' +
        '<br>' +
        'This game uses various fonts from Pixel Sagas (www.pixelsagas.com)<br>' +
        '</center>';
      right.innerHTML = '<img class=message-img src="img/misc/about' + (1 + Std.random(6)) + '.jpg">';

      addCloseButton();
      close.onclick = function (e) {
        game.scene.sounds.play('click-menu');
        game.scene.sounds.play('window-close');
        game.ui.state = UISTATE_MAINMENU;
      }
    }
}
