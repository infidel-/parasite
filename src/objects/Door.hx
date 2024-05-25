// door object

package objects;

import game.Game;

class Door extends AreaObject
{
  public var isOpen: Bool;
  public var isLocked: Bool;
  public var lockID: String;
  var closeTimer: Int;
  var sound: String;

  public function new(g: Game, vaid: Int, vx: Int, vy: Int, row: Int, col: Int)
    {
      super(g, vaid, vx, vy);
      init();
      imageRow = row;
      imageCol = col;
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
      closeTimer = 0;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
      if (imageCol < 2)
        sound = 'cabinet';
      else if (imageCol < 4)
        sound = 'double';
      else if (imageCol < 6)
        sound = 'glass';
      else if (imageCol < 8)
        sound = 'metal';
      else if (imageCol < 10)
        sound = 'glass';
      else if (imageCol < 12)
        sound = 'elevator';
    }

// open door if possible
// 0 - return false
// 1 - ok, continue
  public override function frob(isPlayer: Bool, ai: ai.AI): Int
    {
      if (isOpen)
        return 1;
      // door locked, check for key card
      if (isLocked)
        {
          // check if player has correct key card
          var cards = game.player.host.inventory.getAll('keycard');
          for (item in cards)
            {
              if (item.lockID == lockID)
                {
                  isLocked = false;
                  game.log('You command the host to unlock the door.');
                  return 0;
                }
            }
          // no card found
          if (isLocked)
            {
              if (isPlayer)
                game.log('The door is locked.', COLOR_HINT);
              return 0;
            }
        }

      imageCol++; // opened door tile is right next to closed
      updateImage();
      game.scene.sounds.play('door-' + sound + '-open', {
        x: x,
        y: y,
        canDelay: true,
        always: true,
      });
      isOpen = true;
      closeTimer = 2;
      return 1;
    }

// auto-close door after timeout
  public override function turn()
    {
      if (!isOpen)
        return;
      if (game.area.hasAI(x, y) ||
          (game.playerArea.x == x && game.playerArea.y == y))
        return;
      closeTimer--;
      if (closeTimer > 0)
        return;
      imageCol--; // closed door tile is to the left
      updateImage();
      isOpen = false;
      game.scene.sounds.play('door-' + sound + '-close', {
        x: x,
        y: y,
        canDelay: true,
        always: true,
      });
    }

  public override function known(): Bool
    { return true; }

  public override function visible(): Bool
    { return false; }
}
