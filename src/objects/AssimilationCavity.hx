// habitat - assimilation cavity

package objects;

import game.Game;

class AssimilationCavity extends HabitatObject
{
  public function new(g: Game, vx: Int, vy: Int, l: Int)
    {
      super(g, vx, vy, l);

      name = 'assimilation cavity';
      spawnMessage = 'The assimilation cavity opens its maw.';

      createEntity(game.scene.entityAtlas[level][Const.ROW_ASSIMILATION]);
    }


// update actions
  override function updateActionList()
    {
      if (game.player.state == PLR_STATE_HOST &&
          !game.player.host.hasTrait(TRAIT_ASSIMILATED))
        game.ui.hud.addAction({
          id: 'assimilate',
          type: ACTION_OBJECT,
          name: 'Assimilate Host',
          energy: 0,
          obj: this
        });
    }


// assimilate host
  override function onAction(id: String): Bool
    {
      game.narrative("Twisting tendrils wrap around the host, starting the assimilation process.", COLOR_ORGAN);
      game.player.host.emitSound({
        text: '*GASP*',
        radius: 5,
        alertness: 10
      });
      game.player.host.addTrait(TRAIT_ASSIMILATED);

      return true;
    }
}

