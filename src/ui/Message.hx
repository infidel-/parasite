// message window

package ui;

import js.Browser;
import js.html.DivElement;
import mods.AssetPath;

import game.Game;
import Const;
import _MessageParams;

class Message extends UIWindow
{
  var text: DivElement;

  public function new(g: Game)
    {
      super(g, 'window-message');
      window.className += ' window-dialog';
      window.style.borderImage = "url('" + AssetPath.resolve('img/window-dialog.png') + "') 100 fill / 1 / 0 stretch";

      text = Browser.document.createDivElement();
      text.className = 'window-dialog-text';
      window.appendChild(text);

      var close = Browser.document.createDivElement();
      close.className = 'hud-button window-dialog-button';
      close.innerHTML = 'CLOSE';
      close.style.borderImage = "url('" + AssetPath.resolve('img/window-dialog-button.png') + "') 14 fill / 1 / 0 stretch";
      close.onclick = function (e) {
        game.scene.sounds.play('click-menu');
        game.ui.closeWindow();
      }
      window.appendChild(close);
    }

// set parameters
  public override function setParams(obj: Dynamic)
    {
      var o: _MessageParams = cast obj;
      o.text = '<span class=narrative>' + o.text + '</span>';

      // preload image if present. onerror fallback keeps the window from
      // showing prior message content when the image 404s (mod assets, typos)
      if (o.img != null)
        {
          var img = new js.html.Image();
          img.onload = function() {
            setParamsInternal(o, true);
          };
          img.onerror = function(_) {
            setParamsInternal(o, false);
          };
          img.src = AssetPath.resolve('img/' + o.img + '.jpg');
        }
      else setParamsInternal(o, false);
    }

// internal method to set html content
  function setParamsInternal(o: _MessageParams, hasImage: Bool)
    {
      var html = '';
      if (hasImage)
        html += '<img class=message-img src="' + AssetPath.resolve('img/' + o.img + '.jpg') + '"><p>';
      if (o.title != null)
        {
          var titleText = o.title;
          if (o.titleCol != null)
            titleText = Const.col(o.titleCol, o.title);
          html += "<h3 class='message-title'>" + titleText + "</h3>";
        }
      if (o.col != null)
        html += "<font style='color:var(--text-color-" + o.col + ")'>"  + o.text + "</font>";
      else html += o.text;
      if (hasImage)
        html += '</p>';

      text.innerHTML = html;
      game.scene.sounds.play('message-default');
    }
}
