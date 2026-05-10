// mordax - fleshcrafted base guardian AI
package ai;

import game.Game;

class MordaxCustosAI extends BaseCustosAI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      init();
      finishCustosInit();
      initPost(false);
    }

// init mordax metadata, stats, and sprite
  public override function init()
    {
      super.init();
      initCustosBase('mordax', 'mordax');
      strength = 10 + Std.random(3) - 1;
      constitution = 7 + Std.random(3) - 1;
      intellect = 2;
      psyche = 6;
      createIcon();
    }

// select mordax sprite
  public override function createIcon()
    {
      var icon = game.scene.images.getMordaxCustosIcon();
      tileAtlasX = icon.col;
      tileAtlasY = icon.row;
    }

// set mordax entity icon
  public override function setIcon(): Bool
    {
      entity.setIcon('creatures', tileAtlasX, tileAtlasY);
      return true;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }
}
