// habitat - assimilation cavity

package objects;

import game.Game;

class AssimilationCavity extends AreaObject
{
  public var level: Int;

  public function new(g: Game, vx: Int, vy: Int, l: Int)
    {
      super(g, vx, vy);

      type = 'habitat';
      name = 'assimilation cavity';
      isStatic = true;
      level = l;

      createEntity(Const.ROW_ASSIMILATION, level);
    }


// update actions
  override function updateActionsList()
    {
      if (game.player.state == PLR_STATE_HOST)
        addAction('assimilate', 'Assimilate', 0);
    }


// assimilate host
  override function onAction(id: String)
    {
      game.log("Twisting tendrils wrap around the host, starting the assimilation process.");
    }
}

