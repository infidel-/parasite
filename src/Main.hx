import game.Game;

import js.Browser;
import js.html.CanvasElement;

class Main extends hxd.App
{
  public var game: Game;


// engine init entry-point
  override function init()
    {
      hxd.Res.initEmbed();

      // new canvas (no heaps)
      var canvas2 = Browser.document.createCanvasElement();
      canvas2.id = 'canvas';
      canvas2.width = Math.ceil(Browser.window.innerWidth * Browser.window.devicePixelRatio);
      canvas2.height = Math.ceil(Browser.window.innerHeight * Browser.window.devicePixelRatio);
      canvas2.style.width = '100%';
      canvas2.style.height = '100%';
      canvas2.style.position = 'absolute';
      canvas2.style.top = '0px';
      canvas2.style.right = '0px';
      canvas2.style.opacity = '0.8';
      var ctx = canvas2.getContext('2d');
      ctx.textAlign = 'center';
      Browser.document.body.appendChild(canvas2);

      game = new Game();
      setScene(game.scene, true);
      game.scene.init();
      game.ui.state = UISTATE_MAINMENU;

      // focus window
      var canvas: CanvasElement = cast Browser.document.getElementById("webgl");
      canvas.style.width = '100%';
      canvas.style.height = '100%';
      canvas.focus();
      game.scene.win.propagateKeyEvents = true;
    }

// main update tick, check mouse cursor
  override function update(dt: Float)
    {
      game.scene.mouse.update();
      game.update();
      game.scene.blinkingText.update(dt);
    }


  public static function main()
    {
      var m = new Main();
    }
}
