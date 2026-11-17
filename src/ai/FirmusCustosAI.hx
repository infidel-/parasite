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
      initCustosBase('firmus', N('firmus'));
      soundsID = 'firmus';
      strength = 8 + Std.random(3) - 1;
      constitution = 12 + Std.random(3) - 1;
      intellect = 2;
      psyche = 7;
      createIcon();
    }

// life 26 and energy 240 at the base stats (the strength and constitution roll moves the life)
  public override function recalc()
    {
      super.recalc();
      maxHealth += 6;
      maxEnergy = 240;
    }

// the slam: 1-4 damage
  public override function getCurrentWeaponItemInfo(): ItemInfo
    {
      return CustosLogic.attackInfo(game, 1, 4, BLUNT,
        T('{attacker:The} slams {target:the} for {damage} damage.'),
        T('{attacker:The} slams you for {damage} damage.'));
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
