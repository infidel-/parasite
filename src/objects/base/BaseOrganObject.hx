// area object wrapper for cult base organs
package objects.base;

import ai.AI;
import const.CultBaseConst;
import cult.base.CultBaseOrgan;
import game.Game;
import objects.AreaObject;

class BaseOrganObject extends AreaObject
{
  public var organID: Int;
  public var basePartIndex: Int;

  public function new(g: Game, vaid: Int, vx: Int, vy: Int, organID: Int,
      ?basePartIndex: Int = 0)
    {
      super(g, vaid, vx, vy);
      this.organID = organID;
      init();
      this.basePartIndex = basePartIndex;
      syncOrganImage();
      initPost(false);
    }

// init base organ object fields
  public override function init()
    {
      super.init();
      type = 'base_organ';
      name = 'base organ';
      isStatic = true;
      basePartIndex = 0;
      imageName = CultBaseConst.IMAGE_NAME;
      syncOrganImage();
    }

// refresh base organ atlas coordinates
  public function syncOrganImage()
    {
      imageName = CultBaseConst.IMAGE_NAME;
      var block = CultBaseConst.BLOCK_COR_NEFANDUM;
      var organ = getOrgan();
      if (organ != null)
        block = CultBaseConst.block(organ.type);
      imageRow = block.row + Std.int(basePartIndex / block.width);
      imageCol = block.col + basePartIndex % block.width;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      syncOrganImage();
      super.initPost(onLoad);
    }

// base organs are known after base unlock
  public override function known(): Bool
    {
      return game.cults[0].base != null;
    }

// can be activated when player is next to it?
  public override function canActivateNear(): Bool
    {
      return true;
    }

// returns display name with durability
  public override function getName(): String
    {
      var organ = getOrgan();
      if (organ == null)
        return name;
      return CultBaseConst.name(organ.type) + ' (level ' + organ.level +
        ', ' + organ.health + '/' + organ.maxHealth() +
        (organ.broken ? ', broken' : '') + ')';
    }

// update available object actions
  override function updateActionList()
    {
      var base = game.cults[0].base;
      if (base == null)
        return;
      var organ = getOrgan();
      if (organ == null)
        return;
      if (organ.type == COR_NEFANDUM)
        {
          if (organ.level < CultBaseConst.info(organ.type).maxLevel)
            game.ui.hud.addAction({
              id: 'upgradeHeart',
              type: ACTION_OBJECT,
              name: 'Upgrade Cor Nefandum',
              energy: 0,
              obj: this
            });
        }
      if (organ.health < organ.maxHealth() || organ.broken)
        game.ui.hud.addAction({
          id: 'repairBaseOrgan',
          type: ACTION_OBJECT,
          name: 'Repair ' + CultBaseConst.name(organ.type),
          energy: 0,
          obj: this
        });
    }

// handles object actions
  override function onAction(action: _PlayerAction): Bool
    {
      var base = game.cults[0].base;
      if (base == null)
        return false;
      base.cursorX = x;
      base.cursorY = y;
      switch (action.id)
        {
          case 'upgradeHeart':
            return base.upgradeAtCursor();
          case 'repairBaseOrgan':
            return base.repairAtCursor();
          default:
            return false;
        }
    }

// damages the linked organ
  public function damage(damage: Int)
    {
      onDamage(damage);
    }

// damages the linked organ through combat
  public override function onDamage(damage: Int, ?attacker: AI)
    {
      var base = game.cults[0].base;
      var organ = getOrgan();
      if (base != null && organ != null)
        base.damageOrgan(organ, damage);
    }

// can actors walk through this object tile?
  public override function isWalkable(): Bool
    {
      var organ = getOrgan();
      if (organ == null)
        return false;
      if (organ.broken &&
          (organ.type == RIBWALL ||
           organ.type == RIBGATE))
        return true;
      return organ.type == RIBGATE;
    }

// returns linked organ record
  public function getOrgan(): CultBaseOrgan
    {
      var base = game.cults[0].base;
      if (base == null)
        return null;
      for (organ in base.organs)
        if (organ.id == organID)
          return organ;
      return null;
    }
}
