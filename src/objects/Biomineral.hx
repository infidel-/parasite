// habitat - biomineral

package objects;

import game.Game;

class Biomineral extends HabitatObject
{
  public function new(g: Game, vx: Int, vy: Int, l: Int)
    {
      super(g, vx, vy, l);

      name = 'biomineral';

      createEntity(game.scene.entityAtlas[level][Const.ROW_BIOMINERAL]);
    }

/*
// update actions
  override function updateActionsList()
    {
      if (game.player.state != PLR_STATE_ATTACHED)
        addAction('enterSewers', 'Enter Sewers', 10);
    }


// activate sewers - leave area
  override function onAction(id: String)
    {
      game.log("You enter the damp fetid sewers, escaping the prying eyes.");
      game.turns++; // manually increase number of turns
      game.setLocation(LOCATION_REGION);
    }
*/
}

