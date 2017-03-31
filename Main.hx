import openfl.Lib;
import com.haxepunk.Engine;
import com.haxepunk.HXP;
import com.haxepunk.Scene;
import com.haxepunk.Entity;
import com.haxepunk.graphics.Spritemap;
import com.haxepunk.masks.Circle;

import haxe.ui.HaxeUIApp;
import haxe.ui.Toolkit;

import game.Game;

class Main extends Engine
{
  var game: Game;

  override public function init()
    {
#if debug
      HXP.console.enable();
#end
      HXP.screen.scale = 1.0;

      game = new Game();
    }

  public static function main()
    {
      Toolkit.theme = "native";
      Toolkit.init();

      var m = new Main();
    }
}
