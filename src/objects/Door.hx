// door object

package objects;

import game.Game;

class Door extends AreaObject
{
  public var isOpen: Bool;
  var closeTimer: Int;

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
      closeTimer = 0;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

// open door if possible
// 0 - return false
// 1 - ok, continue
  public override function frob(isPlayer: Bool, ai: ai.AI): Int
    {
      if (isOpen)
        return 1;

      imageCol++; // opened door tile is right next to closed
      updateImage();
      game.scene.sounds.play('door-cabinet-open', true);
      isOpen = true;
      closeTimer = 2;
      return 1;
    }

// auto-close door after timeout
  public override function turn()
    {
      if (!isOpen)
        return;
      closeTimer--;
      if (closeTimer > 0)
        return;
      imageCol--; // closed door tile is to the left
      updateImage();
      isOpen = false;
      game.scene.sounds.play('door-cabinet-close', true);
    }
}
