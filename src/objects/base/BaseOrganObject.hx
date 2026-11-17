// area object wrapper for cult base organs
package objects.base;

import l10n.Loc;
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
      name = N('base organ');
      isStatic = true;
      basePartIndex = 0;
      imageName = CultBaseConst.IMAGE_NAME;
      syncOrganImage();
    }

// base organs stand upright in the 3D view, not flat on the ground
  public override function isGroundDecal(): Bool
    { return false; }

// the 3D view's key: the organ type on its anchor (part 0) cell, `_part` on the others, which
// render.world.ObjModels keys to a row that hides their sprites. a type with no row keeps its sprite.
// a spine turret's, ribwall's or ribgate's key carries its direction, which the row turns it by.
// a broken organ's anchor key ends in `_broken`, the ruined twin of its row
  public override function getModelKey(): String
    {
      var organ = getOrgan();
      if (organ == null)
        return type;
      return 'cult_' + Std.string(organ.type).toLowerCase() +
        (organ.type == SPINE_TURRET ||
         organ.type == RIBWALL ||
         organ.type == RIBGATE ? '_' + organ.direction : '') +
        (basePartIndex != 0 ? '_part' : (organ.broken ? '_broken' : ''));
    }

// the cursor on any cell outlines the whole organ
  public override function getHoverGroup(): Array<AreaObject>
    {
      return [ for (o in game.region.get(areaID).getObjects())
        if (o.type == 'base_organ' &&
            cast(o, BaseOrganObject).organID == organID) o ];
    }

// refresh base organ atlas coordinates
  public function syncOrganImage()
    {
      imageName = CultBaseConst.IMAGE_NAME;
      var block = CultBaseConst.BLOCK_COR_NEFANDUM;
      var organ = getOrgan();
      if (organ != null)
        {
          if (organ.type == SPINE_TURRET)
            block = CultBaseConst.spineTurretBlock(organ.direction);
          else
            block = CultBaseConst.block(organ.type);
        }
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
      return CultBaseConst.name(organ.type);
    }

// organ names are Latin proper names: translated, never an article
  public override function getLocNoun(): _LocNoun
    {
      return {
        key: getName(),
        kind: LOC_PHRASE,
        gender: 'n',
      };
    }

// returns base organ name without an article
  public override function theName(): String
    {
      return getName();
    }

// update available object actions
  override function updateActionList()
    {
      var base = game.cults[0].base;
      if (base == null)
        return;
      var organ = getOrgan();
      if (organ == null ||
          !isFirstPartNearPlayer())
        return;
      if (organ.type == COR_NEFANDUM)
        {
          if (organ.level < CultBaseConst.info(organ.type).maxLevel)
            game.ui.hud.addAction({
              id: 'upgradeHeart',
              type: ACTION_OBJECT,
              name: T('Upgrade Cor Nefandum'),
              energy: 0,
              obj: this
            });
        }
      if (organ.type == SPINE_TURRET &&
          base.validateTurn(organ) == '')
        game.ui.hud.addAction({
          id: 'turnTurret',
          type: ACTION_OBJECT,
          name: T('Turn turret'),
          energy: 0,
          obj: this
        });
      if (organ.health < organ.maxHealth() || organ.broken)
        game.ui.hud.addAction({
          id: 'repairBaseOrgan',
          type: ACTION_OBJECT,
          name: T('Repair {organ}', { organ: Loc.tr(CultBaseConst.name(organ.type)) }),
          energy: 0,
          obj: this
        });
    }

// true when no lower part of this organ is next to the player, so a multi-tile organ lists its actions once
  function isFirstPartNearPlayer(): Bool
    {
      var px = game.playerArea.x;
      var py = game.playerArea.y;
      for (o in game.area.getObjects())
        if (o.type == 'base_organ')
          {
            var obj: BaseOrganObject = cast o;
            if (obj.organID == organID &&
                obj.basePartIndex < basePartIndex &&
                Std.int(Math.max(Math.abs(obj.x - px), Math.abs(obj.y - py))) <= 1)
              return false;
          }
      return true;
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
          case 'turnTurret':
            return base.turnTurret(getOrgan());
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

// returns true when hostile actors can attack this organ part
  public override function isAttackableByEnemy(): Bool
    {
      var organ = getOrgan();
      return organ != null && organ.isWorking();
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
