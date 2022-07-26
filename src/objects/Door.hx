// door object

package objects;

import game.Game;

class Door extends AreaObject
{
  public var isOpen: Bool;
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
      game.scene.sounds.play('door-' + sound + '-open', true);
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
      game.scene.sounds.play('door-' + sound + '-close', true);
    }

  public override function known(): Bool
    { return true; }

  public override function visible(): Bool
    { return false; }
}
