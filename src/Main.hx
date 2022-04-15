import game.Game;

#if js
import js.Browser;
#end

class Main extends hxd.App
{
  public var game: Game;


// engine init entry-point
  override function init()
    {
      hxd.Res.initEmbed();

      game = new Game();
      setScene(game.scene, true);
      game.scene.init();
      game.ui.state = UISTATE_MAINMENU;

#if js
      // focus window
      var canvas = Browser.document.getElementById("webgl");
      canvas.style.width = '100%';
      canvas.style.height = '100%';
      canvas.focus();
      game.scene.win.propagateKeyEvents = true;
#end
    }


// resize GUI
  override function onResize()
    {
      if (game != null && game.scene != null)
        game.scene.resize();
    }


// main update tick, check mouse cursor
  override function update(dt: Float)
    {
      game.scene.mouse.update();
      game.scene.checkPath();
      game.scene.hud.updateAnimation(dt);
    }


  public static function main()
    {
      var m = new Main();
    }
}
