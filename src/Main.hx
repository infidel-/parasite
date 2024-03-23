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
      var canvas = Browser.document.createCanvasElement();
      canvas.id = 'canvas';
      canvas.width = Math.ceil(Browser.window.innerWidth * Browser.window.devicePixelRatio);
      canvas.height = Math.ceil(Browser.window.innerHeight * Browser.window.devicePixelRatio);
      var ctx = canvas.getContext('2d');
      ctx.textAlign = 'center';
      Browser.document.body.appendChild(canvas);
      canvas.focus();

      game = new Game();
      setScene(game.scene, true);
      game.scene.init();
      game.ui.state = UISTATE_MAINMENU;
    }

// main update tick, check mouse cursor
  override function update(dt: Float)
    {

      // TODO
      var oldcanvas = cast Browser.document.getElementById('webgl');
      oldcanvas.style.visibility = 'hidden';
      game.scene.mouse.update();
      game.update();
    }


  public static function main()
    {
      var m = new Main();
    }
}
