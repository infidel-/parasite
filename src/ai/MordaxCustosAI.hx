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
      initCustosBase('mordax', N('mordax'));
      soundsID = 'mordax';
      strength = 10 + Std.random(3) - 1;
      constitution = 7 + Std.random(3) - 1;
      intellect = 2;
      psyche = 6;
      createIcon();
    }

// life 16 and energy 190 at the base stats (the strength and constitution roll moves the life)
  public override function recalc()
    {
      super.recalc();
      maxHealth -= 1;
      maxEnergy = 190;
    }

// the bite: 3-8 damage
  public override function getCurrentWeaponItemInfo(): ItemInfo
    {
      return CustosLogic.attackInfo(game, 3, 8, BITE,
        T('{attacker:The} bites {target:the} for {damage} damage.'),
        T('{attacker:The} bites you for {damage} damage.'));
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
