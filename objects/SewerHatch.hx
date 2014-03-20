// sewer hatch - leads to sewers when activated

package objects;

class SewerHatch extends AreaObject
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);

      type = 'sewer_hatch';

      createEntity(Const.ROW_OBJECT, Const.FRAME_SEWER_HATCH);
    }
}
