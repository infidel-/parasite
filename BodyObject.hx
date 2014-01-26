// body object (human, animal, etc)

class BodyObject extends AreaObject
{
  public var isHumanBody: Bool; // is this a human body?

  public function new(g: Game, vx: Int, vy: Int, parentType: String)
    {
      super(g, vx, vy);

      type = 'body';
      isHumanBody = false;

      createEntity(parentType);
    }
}
