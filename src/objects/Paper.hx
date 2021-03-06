// piece of paper (clue)

package objects;

import game.Game;

class Paper extends Pickup
{
  public var event: scenario.Event; // scenario event link

  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);

      type = 'paper';
      name = 'paper';
      createEntity(game.scene.entityAtlas
        [Const.FRAME_PAPER][Const.ROW_OBJECT]);
    }
}
