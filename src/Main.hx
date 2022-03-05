import game.Game;

#if js
import js.Browser;
#end

class Main extends hxd.App
{
  var game: Game;


// engine init entry-point
  override function init()
    {
      hxd.Res.initEmbed();

      game = new Game();
      setScene(game.scene, true);
      game.scene.init();

#if js
      // focus window
      js.Browser.document.getElementById("webgl").focus();
      game.scene.win.propagateKeyEvents = true;
      var canvas = Browser.document.getElementById("webgl");
      canvas.style.width = '100%';
      canvas.style.height = '100%';
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
