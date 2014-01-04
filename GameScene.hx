import com.haxepunk.Scene;
import com.haxepunk.HXP;
import com.haxepunk.graphics.atlas.TileAtlas;

import entities.HUD;
import entities.MouseEntity;
import entities.EvolutionWindow;
import entities.DebugWindow;

class GameScene extends Scene
{
  public var game: Game; // game state link
  public var mouse: MouseEntity; // mouse cursor entity
  public var hud: HUD; // ingame HUD
  public var hudState: String; // current HUD state (default, evolution, etc)
  public var evolutionWindow: EvolutionWindow; // evolution window
  public var debugWindow: DebugWindow; // debug window
  public var entityAtlas: TileAtlas; // entity graphics


  public function new(g: Game)
    {
      super();
      game = g;
      hudState = HUDSTATE_DEFAULT;
    }


  public override function begin()
    {
      // load all entity images into atlas
      entityAtlas = new TileAtlas("gfx/entities.png", Const.TILE_WIDTH, Const.TILE_HEIGHT);

      // init GUI
      mouse = new MouseEntity(game);
      add(mouse);
      hud = new HUD(game);
      evolutionWindow = new EvolutionWindow(game);
      debugWindow = new DebugWindow(game);

      // init game state
      game.init();
    }


// update camera position
  public function updateCamera()
    {
      HXP.camera.x = game.player.entity.x - HXP.halfWidth;
      HXP.camera.y = game.player.entity.y - HXP.halfHeight;

      if (HXP.camera.x + HXP.windowWidth > Const.TILE_WIDTH * game.area.width)
        HXP.camera.x = Const.TILE_WIDTH * game.area.width - HXP.windowWidth;
      if (HXP.camera.y + HXP.windowHeight > Const.TILE_HEIGHT * game.area.height)
        HXP.camera.y = Const.TILE_HEIGHT * game.area.height - HXP.windowHeight;

      if (HXP.camera.x < 0)
        HXP.camera.x = 0;
      if (HXP.camera.y < 0)
        HXP.camera.y = 0;

//      var gameScene: scenes.GameScene = untyped scene;
//      mouse.update();
//      trace(mouse.scene);
//      trace(HXP.camera);
//      trace(HXP.camera.x + ',' + HXP.camera.y);
    }


  // hud state constants
  public static var HUDSTATE_DEFAULT = 'default'; // default
  public static var HUDSTATE_EVOLUTION = 'evolution'; // evolution window open
  public static var HUDSTATE_DEBUG = 'debug'; // debug window open
}
