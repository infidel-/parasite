// habitat - biomineral

package objects;

import game.Game;

class Biomineral extends HabitatObject
{
  public function new(g: Game, vaid: Int, vx: Int, vy: Int, l: Int)
    {
      super(g, vaid, vx, vy, l);
      init();
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      name = 'biomineral formation';
      spawnMessage = 'The biomineral formation is ready to feed the habitat.';
      imageRow = Const.ROW_GROWTH1;
      imageCol = Const.FRAME_BIOMINERAL + level;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
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
        addAction('enterSewers', 'Enter sewers', 10);
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

