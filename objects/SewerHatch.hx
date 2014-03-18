// sewer hatch - leads to sewers when activated

package objects;

class SewerHatch extends AreaObject
{
  public function new(g: Game, vx: Int, vy: Int, parentType: String)
    {
      super(g, vx, vy);

      type = 'sewer_hatch';

      createEntity(parentType);
    }
}
