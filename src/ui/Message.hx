// message window — narrative event dialog

package ui;

import js.Browser;
import js.html.DivElement;
import js.html.ImageElement;
import mods.AssetPath;

import game.Game;
import Const;
import _MessageParams;

class Message extends UIWindow
{
  var imgWrap: DivElement;
  var imgEl: ImageElement;
  var text: DivElement;

  public function new(g: Game)
    {
      super(g, 'window-message');
      addCorners();

      // image (with the infected-duotone glitch filter); hidden when no image
      imgWrap = Browser.document.createDivElement();
      imgWrap.className = 'message-img';
      imgEl = Browser.document.createImageElement();
      imgWrap.appendChild(imgEl);
      window.appendChild(imgWrap);

      text = Browser.document.createDivElement();
      text.className = 'message-text';
      window.appendChild(text);

      var close = Browser.document.createDivElement();
      close.className = 'message-close';
      close.innerHTML = 'CLOSE';
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
      imgWrap.style.display = (hasImage ? '' : 'none');
      if (hasImage)
        imgEl.src = AssetPath.resolve('img/' + o.img + '.jpg');

      var html = '';
      if (o.title != null)
        {
          var titleText = (o.titleCol != null ? Const.col(o.titleCol, o.title) : o.title);
          html += "<span class='message-heading'>" + titleText + "</span>";
        }
      if (o.col != null)
        html += "<span style='color:var(--text-color-" + o.col + ")'>" + o.text + "</span>";
      else html += o.text;

      text.innerHTML = html;
      game.scene.sounds.play('message-default');
    }

  override function hide(?skipAnimation: Bool = false)
    {
      animatedHide();
    }
}
