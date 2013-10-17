import com.haxepunk.Scene;
import com.haxepunk.HXP;
import com.haxepunk.graphics.atlas.TileAtlas;

import entities.HUD;
  
class GameScene extends Scene
{
  public var game: Game; // game state link
  public var hud: HUD; // ingame HUD
  public var entityAtlas: TileAtlas; // entity graphics


  public function new(g: Game)
    {
      super();
      game = g;
    }


  public override function begin()
    {
      // load all entity images into atlas
      entityAtlas = new TileAtlas("gfx/entities.png", Const.TILE_WIDTH, Const.TILE_HEIGHT);

      // init HUD
      hud = new HUD(game);

      // init game state
      game.init();
    }


// update camera position
  public function updateCamera()
    {
      HXP.camera.x = game.player.entity.x - HXP.halfWidth;
      HXP.camera.y = game.player.entity.y - HXP.halfHeight;

      if (HXP.camera.x + HXP.windowWidth > Const.TILE_WIDTH * game.map.width)
        HXP.camera.x = Const.TILE_WIDTH * game.map.width - HXP.windowWidth;
      if (HXP.camera.y + HXP.windowHeight > Const.TILE_HEIGHT * game.map.height)
        HXP.camera.y = Const.TILE_HEIGHT * game.map.height - HXP.windowHeight;

      if (HXP.camera.x < 0)
        HXP.camera.x = 0;
      if (HXP.camera.y < 0)
        HXP.camera.y = 0;

//      var gameScene: scenes.GameScene = untyped scene;
//      gameScene.mouse.update();
//      trace(HXP.camera.x + ',' + HXP.camera.y);
    }
}