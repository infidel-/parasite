// book (clue)

package objects;

import game.Game;

class Book extends Pickup
{
  public var event: scenario.Event; // scenario event link

  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);

      type = 'book';
      createEntity(Const.ROW_OBJECT, Const.FRAME_BOOK);
    }
}
