// door object

package objects;

import game.Game;
import tiles.UndergroundLab;

class Door extends AreaObject
{
  public var isOpen: Bool;
  public var isLocked: Bool;
  public var lockID: String;
  public var linkedDoorID: Int;
  public var closedRow: Int;
  public var closedCol: Int;
  public var openRow: Int;
  public var openCol: Int;
  var closeTimer: Int;
  var sound: String;

  public function new(g: Game, vaid: Int, vx: Int, vy: Int,
      closed: _Icon, open: _Icon, ?imgName: String = 'entities')
    {
      super(g, vaid, vx, vy);
      init();
      imageName = imgName;
      closedRow = closed.row;
      closedCol = closed.col;
      openRow = open.row;
      openCol = open.col;
      applyClosedIcon();
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      imageCol = Const.FRAME_SEWER_HATCH;
      type = 'door';
      name = 'door';
      isStatic = true;
      isOpen = false;
      isLocked = false;
      lockID = null;
      linkedDoorID = -1;
      closedRow = Const.ROW_DOORS;
      closedCol = Const.FRAME_DOOR_CABINET;
      openRow = Const.ROW_DOORS;
      openCol = Const.FRAME_DOOR_CABINET_OPEN;
      closeTimer = 0;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
      if (onLoad)
        initLegacyIconsOnLoad();
      sound = resolveDoorSound();
    }

// open door if possible
// 0 - return false
// 1 - ok, continue
  public override function frob(isPlayer: Bool, ai: ai.AI): Int
    {
      if (isOpen)
        {
          closeTimer = 2;
          return 1;
        }
      // door locked, check for key card
      if (isPlayer && isLocked)
        {
          // check if player has correct key card
          var cards = game.player.host.inventory.getAll('keycard');
          for (item in cards)
            {
              if (game.player.knowsItem(item.id) &&
                  item.lockID == lockID)
                {
                  isLocked = false;
                  syncLinkedLockState();
                  game.log('You command the host to unlock the door.');
                  game.scene.sounds.play('door-keycard-unlock');
                  return 0;
                }
            }
          // no card found
          if (isLocked)
            {
              if (isPlayer)
                game.actionFailed('The door is locked.');
              return 0;
            }
        }

      setOpenState(true, true, true);
      if (isPlayer)
        {
          game.area.updateVisibility();
          return 0;
        }
      return 1;
    }

// auto-close door after timeout
  public override function turn()
    {
      if (!isOpen)
        return;
      if (isBlockedByOccupant())
        return;
      closeTimer--;
      if (closeTimer > 0)
        return;
      setOpenState(false, true, true);
    }

// restore old save icon values for legacy single-tile doors
  function initLegacyIconsOnLoad()
    {
      if (closedRow != Const.ROW_DOORS ||
          closedCol != Const.FRAME_DOOR_CABINET ||
          openRow != Const.ROW_DOORS ||
          openCol != Const.FRAME_DOOR_CABINET_OPEN)
        return;
      closedRow = imageRow;
      closedCol = imageCol;
      if (isOpen)
        closedCol--;
      openRow = imageRow;
      openCol = closedCol + 1;
    }

// resolve door sound type from closed icon style
  function resolveDoorSound(): String
    {
      if (closedRow != Const.ROW_DOORS)
        return 'double';
      if (closedCol < 2)
        return 'cabinet';
      else if (closedCol < 4)
        return 'double';
      else if (closedCol < 6)
        return 'glass';
      else if (closedCol < 8)
        return 'metal';
      else if (closedCol < 10)
        return 'glass';
      else if (closedCol < 12)
        return 'elevator';
      return 'metal';
    }

// set this door state and optionally propagate to linked half
  function setOpenState(newOpen: Bool, propagate: Bool, playSound: Bool)
    {
      // opening door
      var changed = false;
      if (newOpen)
        {
          if (!isOpen)
            {
              applyOpenIcon();
              updateImage();
              isOpen = true;
              changed = true;
            }
          closeTimer = 2;
        }
      // closing door, check if occupied
      else
        {
          if (!isOpen)
            return;
          applyClosedIcon();
          updateImage();
          isOpen = false;
          closeTimer = 0;
          changed = true;
        }

      // recalc tile visibility if state changed
      if (changed)
        game.region.get(areaID).recalcTileCanSeeThrough(x, y);

      // propagate state change to linked door half
      if (propagate)
        {
          var linked = getLinkedDoor();
          if (linked != null)
            linked.setOpenState(newOpen, false, false);
        }

      // play sound
      if (playSound)
        game.scene.sounds.play('door-' + sound + '-' +
          (newOpen ? 'open' : 'close'), {
            x: x,
            y: y,
            canDelay: true,
            always: true,
          });
    }

// copy lock fields to the linked door half
  function syncLinkedLockState()
    {
      var linked = getLinkedDoor();
      if (linked == null)
        return;
      linked.isLocked = isLocked;
      linked.lockID = lockID;
    }

// check whether any door half is occupied by player or AI
  function isBlockedByOccupant(): Bool
    {
      if (game.area.hasAI(x, y) ||
          (game.playerArea.x == x &&
           game.playerArea.y == y))
        return true;

      // check linked door half
      var linked = getLinkedDoor();
      if (linked == null)
        return false;
      if (game.area.hasAI(linked.x, linked.y) ||
          (game.playerArea.x == linked.x &&
           game.playerArea.y == linked.y))
        return true;
      return false;
    }

// resolve linked door by saved linked door ID
  function getLinkedDoor(): Door
    {
      if (linkedDoorID < 0)
        return null;
      var area = game.region.get(areaID);
      var o = area.getObject(linkedDoorID);
      if (o == null)
        return null;
      return cast o;
    }

// apply closed icon frame to this door entity
  function applyClosedIcon()
    {
      imageRow = closedRow;
      imageCol = closedCol;
    }

// apply open icon frame to this door entity
  function applyOpenIcon()
    {
      imageRow = openRow;
      imageCol = openCol;
    }

// check if line of sight can pass through this door object
  public override function canSeeThrough(): Bool
    {
      if (imageName != UndergroundLab.OBJECTS_IMAGE)
        return true;
      return (imageRow == openRow &&
        imageCol == openCol);
    }

  public override function known(): Bool
    { return true; }

  public override function visible(): Bool
    { return false; }
}
