// body object (human, animal, etc)

package objects;

class BodyObject extends AreaObject
{
  public var isHumanBody: Bool; // is this a human body?
  public var organPoints: Int; // amount of organs on this body

  public function new(g: Game, vx: Int, vy: Int, parentType: String)
    {
      super(g, vx, vy);

      type = 'body';
      isHumanBody = false;
      organPoints = 0;

      createEntity(parentType);
    }


// TURN: despawn bodies and generate area events
  public override function turn()
    {
      // not enough time has passed
      if (game.turns - creationTime < DESPAWN_TURNS)
        return;

      // notify world about body discovery by authorities
      Const.todo('check if body despawns after player leaves the area');
      game.worldManager.onBodyDiscovered(game.world.area, organPoints);

      game.area.removeObject(this);
    }


  static var DESPAWN_TURNS = 20; // turns until body is despawned (picked up by law etc)
}
