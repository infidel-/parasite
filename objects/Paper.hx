// piece of paper (clue)

package objects;

class Paper extends Pickup
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);

      type = 'paper';
      createEntity(Const.ROW_OBJECT, Const.FRAME_PAPER);
    }
}
