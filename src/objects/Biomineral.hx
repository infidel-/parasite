// habitat - biomineral

package objects;

import game.Game;

class Biomineral extends HabitatObject
{
  public function new(g: Game, vx: Int, vy: Int, l: Int)
    {
      super(g, vx, vy, l);

      name = 'biomineral formation';
      spawnMessage = 'The biomineral formation is ready to feed the habitat.';

      createEntity(game.scene.entityAtlas[level][Const.ROW_BIOMINERAL]);
    }

// show additional info
  public override function onMoveTo()
    {
      var h = game.area.habitat;
      game.log(Const.col('gray', Const.small('[' +
        h.energyUsed + '/' + h.energy +
        ' habitat energy used. ' +
        'Each turn: host energy: +' + h.hostEnergyRestored +
        ', parasite energy: +' + h.parasiteEnergyRestored +
        ', parasite health: +' + h.parasiteHealthRestored +
        ']')));
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

