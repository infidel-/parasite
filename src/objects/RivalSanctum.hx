// rival cult mission objective
package objects;

import const.CultBaseConst;
import game.Game;

class RivalSanctum extends AreaObject
{
  public static inline var SANCTUM_W = 2;
  public static inline var SANCTUM_H = 2;
  static inline var SANCTUM_IMAGE_ROW = 4;
  static inline var SANCTUM_IMAGE_COL = 2;

  public var missionID: Int;
  public var health: Int;
  public var sanctumRootObjectID: Int;
  public var sanctumPartIndex: Int;
  public var sanctumPartObjectIDs: Array<Int>;

  public function new(g: Game, vaid: Int, vx: Int, vy: Int,
      missionID: Int, ?sanctumPartIndex: Int = 0)
    {
      super(g, vaid, vx, vy);
      init();
      this.missionID = missionID;
      this.sanctumPartIndex = sanctumPartIndex;
      updateSanctumIcon();
      initPost(false);
    }

// init object fields
  public override function init()
    {
      super.init();
      type = 'rival_sanctum';
      name = 'rival sanctum';
      health = 30;
      missionID = -1;
      sanctumRootObjectID = -1;
      sanctumPartIndex = 0;
      sanctumPartObjectIDs = [];
      imageName = CultBaseConst.IMAGE_NAME;
      updateSanctumIcon();
      isStatic = true;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
      updateSanctumIcon();
    }

// assign linked object IDs for a 2x2 sanctum group
  public function setSanctumGroup(rootObjectID: Int, partObjectIDs: Array<Int>)
    {
      sanctumRootObjectID = rootObjectID;
      sanctumPartObjectIDs = partObjectIDs.copy();
    }

// update icon frame for current sanctum part
  function updateSanctumIcon()
    {
      imageName = CultBaseConst.IMAGE_NAME;
      imageRow = SANCTUM_IMAGE_ROW + Std.int(sanctumPartIndex / SANCTUM_W);
      imageCol = SANCTUM_IMAGE_COL + sanctumPartIndex % SANCTUM_W;
      if (entity != null)
        updateImage();
    }

// resolve root sanctum object for this sanctum part
  function getRootSanctum(): RivalSanctum
    {
      if (sanctumRootObjectID < 0 ||
          sanctumRootObjectID == id)
        return this;
      var area = game.region.get(areaID);
      if (area == null)
        return this;
      var o = area.getObject(sanctumRootObjectID);
      if (o == null ||
          o.type != 'rival_sanctum')
        return this;
      return cast o;
    }

// resolve group object IDs from root sanctum
  function getGroupObjectIDs(): Array<Int>
    {
      var root = getRootSanctum();
      if (root.sanctumPartObjectIDs == null ||
          root.sanctumPartObjectIDs.length == 0)
        return [root.id];
      return root.sanctumPartObjectIDs;
    }

// remove every sanctum part object from its area
  function removeSanctumGroup()
    {
      var area = game.region.get(areaID);
      if (area == null)
        return;
      for (objectID in getGroupObjectIDs())
        {
          var o = area.getObject(objectID);
          if (o == null ||
              o.type != 'rival_sanctum')
            continue;
          area.removeObject(o);
        }
    }

// always known in rival attack mission
  public override function known(): Bool
    {
      return true;
    }

// can be activated near it
  public override function canActivateNear(): Bool
    {
      return true;
    }

// update action list
  override function updateActionList()
    {
      game.ui.hud.addAction({
        id: 'destroyRivalSanctum',
        type: ACTION_OBJECT,
        name: 'Destroy sanctum',
        energy: 10,
        obj: this
      });
    }

// damage sanctum and complete mission on destruction
  override function onAction(action: _PlayerAction): Bool
    {
      if (action.id != 'destroyRivalSanctum')
        return false;
      var root = getRootSanctum();
      if (root.id != id)
        return root.onAction(action);
      health -= Const.roll(6, 12);
      if (health > 0)
        {
          game.log('The sanctum shudders.');
          return true;
        }
      var mission = game.cults[0].ordeals.getMissionByID(missionID);
      if (mission != null &&
          !mission.isCompleted)
        mission.success();
      removeSanctumGroup();
      game.log('The rival sanctum collapses.');
      return true;
    }

// can actors walk through this object tile?
  public override function isWalkable(): Bool
    {
      return false;
    }
}
