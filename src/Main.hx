/*
import haxe.ui.HaxeUIApp;
import haxe.ui.Toolkit;
*/

import game.Game;

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
#end
      game.scene.win.propagateKeyEvents = true;

/*
      engine.backgroundColor = 0x202020;
      hxd.Window.getInstance().propagateKeyEvents = true;

      var console = new h2d.Console(hxd.res.DefaultFont.get(), s2d);
      console.addCommand("hello", "Prints the correct answer", [], function() console.log("World", 0xFF00FF));

/*
//      var tf = new h2d.Text(hxd.res.DefaultFont.get(), game.scene);
//      var tf = new h2d.Text(game.scene.font, game.scene);
      var tf = new h2d.HtmlText(hxd.Res.font.OrkneyRegular.toFont(), game.scene);
      tf.textColor = 0xffffff;
      tf.text = "Hello World 2!";
      tf.x = 200;
/*
      var res = hxd.Res.load('graphics/tileset64.png').toTile();
      var tiles = res.grid(64);
      new h2d.Bitmap(res, game.scene);
      var b = new h2d.Bitmap(tiles[3][0], game.scene);
      b.x = 200;
      b.y = 200;
/*
      var res = hxd.Res.load('graphics/entities64.png').toTile();
      var tiles = res.grid(64);
      var b = new h2d.Bitmap(tiles[0][4], game.scene);
      b.x = 0;
      b.y = 0;
*/
    }


/*
  override function update(dt: Float)
    {
//      game.scene.update();
      if (hxd.Key.isPressed(hxd.Key.CTRL))
        trace('press!');
    }
*/


  public static function main()
    {
      trace('todo main');
/*
      Toolkit.theme = "native";
      Toolkit.init();
*/

      var m = new Main();
    }
}
