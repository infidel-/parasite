// habitat - biomineral

package objects;

import game.Game;

class Biomineral extends AreaObject
{
  public var level: Int;

  public function new(g: Game, vx: Int, vy: Int, l: Int)
    {
      super(g, vx, vy);

      type = 'habitat';
      name = 'biomineral';
      isStatic = true;
      level = l;

      createEntity(Const.ROW_BIOMINERAL, level);
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

