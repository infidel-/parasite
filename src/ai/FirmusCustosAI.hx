// firmus - fleshcrafted base guardian AI
package ai;

import game.Game;

class FirmusCustosAI extends BaseCustosAI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      init();
      finishCustosInit();
      initPost(false);
    }

// init firmus metadata, stats, and sprite
  public override function init()
    {
      super.init();
      initCustosBase('firmus', 'firmus');
      strength = 8 + Std.random(3) - 1;
      constitution = 12 + Std.random(3) - 1;
      intellect = 2;
      psyche = 7;
      createIcon();
    }

// select firmus sprite
  public override function createIcon()
    {
      var icon = game.scene.images.getFirmusCustosIcon();
      tileAtlasX = icon.col;
      tileAtlasY = icon.row;
    }

// set firmus entity icon
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
