// clone vat object used by underground lab mission

package objects.mission;

import cult.missions.CombatUndergroundLabPurge;
import game.Game;
import objects.AreaObject;
import tiles.UndergroundLab;

class CloneVat extends AreaObject
{
  public var missionID: Int;
  public var isFlushed: Bool;
  public var vatRootObjectID: Int;
  public var vatPartIndex: Int;
  public var vatPartObjectIDs: Array<Int>;

  public function new(g: Game, vaid: Int, vx: Int, vy: Int, vmissionID: Int,
      ?vvatPartIndex: Int = 0)
    {
      super(g, vaid, vx, vy);
      init();
      missionID = vmissionID;
      vatPartIndex = vvatPartIndex;
      updateVatIcon();
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      missionID = -1;
      isFlushed = false;
      vatRootObjectID = -1;
      vatPartIndex = 0;
      vatPartObjectIDs = [];
      type = 'clone_vat';
      name = 'cloning vat';
      imageName = UndergroundLab.OBJECTS_IMAGE;
      updateVatIcon();
      isStatic = true;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
      updateVatIcon();
    }

// assign linked object IDs for a 2x3 vat group
  public function setVatGroup(rootObjectID: Int, partObjectIDs: Array<Int>)
    {
      vatRootObjectID = rootObjectID;
      vatPartObjectIDs = partObjectIDs.copy();
    }

// update icon frame for current part and flush state
  function updateVatIcon()
    {
      var block = UndergroundLab.CLONING_VAT;
      imageRow = block.row + Std.int(vatPartIndex / block.width);
      imageCol = block.col + vatPartIndex % block.width + (isFlushed ? 2 : 0);
      if (entity != null)
        updateImage();
    }

// resolve root vat object for this vat part
  function getRootVat(): CloneVat
    {
      if (vatRootObjectID < 0 ||
          vatRootObjectID == id)
        return this;
      var o = game.area.getObject(vatRootObjectID);
      if (o == null ||
          o.type != 'clone_vat')
        return this;
      return cast o;
    }

// resolve group object IDs from root vat
  function getGroupObjectIDs(): Array<Int>
    {
      var root = getRootVat();
      if (root.vatPartObjectIDs == null ||
          root.vatPartObjectIDs.length == 0)
        return [root.id];
      return root.vatPartObjectIDs;
    }

// set flushed state and icon for every vat part in this group
  function flushVatGroup()
    {
      for (objectID in getGroupObjectIDs())
        {
          var o = game.area.getObject(objectID);
          if (o == null ||
              o.type != 'clone_vat')
            continue;
          var vat: CloneVat = cast o;
          vat.isFlushed = true;
          vat.updateVatIcon();
        }
      if (game != null &&
          game.area != null &&
          game.scene != null &&
          game.scene.areaLighting != null)
        game.scene.areaLighting.invalidateArea(game.area);
    }

// allow using the vat from adjacent tiles
  public override function canActivateNear(): Bool
    {
      return true;
    }

// block movement onto vat tiles
  public override function isWalkable(): Bool
    {
      return false;
    }

// block stepping onto vat even if walkability cache is stale
  public override function frob(isPlayer: Bool, ai: ai.AI): Int
    {
      return 0;
    }

// expose mission action for vat flushing
  override function updateActionList()
    {
      if (isFlushed ||
          vatPartIndex < 4)
        return;

      game.ui.hud.addAction({
        id: 'flushCloneVat',
        type: ACTION_OBJECT,
        name: 'Purge growth medium',
        energy: 10,
        obj: this,
      });
    }

// handle clone vat action
  override function onAction(action: _PlayerAction): Bool
    {
      if (action.id != 'flushCloneVat')
        return false;

      if (vatPartIndex < 4)
        return true;

      var rootVat = getRootVat();
      if (rootVat.isFlushed)
        {
          game.actionFailed('This vat is already draining.');
          return true;
        }

      rootVat.flushVatGroup();
      game.scene.draw();

      game.log('You trigger a purge cycle. Green slurry hisses into the drains.');

      var mission = game.cults[0].ordeals.getMissionByID(missionID);
      if (mission == null ||
          mission.isCompleted ||
          mission.type != MISSION_COMBAT)
        return true;

      var labMission: CombatUndergroundLabPurge = cast mission;
      labMission.onVatFlushed(rootVat.id);
      return true;
    }

  public override function known(): Bool
    {
      return true;
    }
}
