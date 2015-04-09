import com.haxepunk.Engine;
import com.haxepunk.HXP;

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

  public static function main() { new Main(); }
}
