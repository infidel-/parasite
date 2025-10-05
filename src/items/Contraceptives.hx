// defines contraceptives junk item
package items;

import game.Game;
import ItemInfo;

class Contraceptives extends ItemInfo
{
// builds contraceptives info
  public function new(game: Game)
    {
      super(game);
      id = 'contraceptives';
      name = 'pack of contraceptives';
      type = 'junk';
      unknown = 'small container';
    }

// grants ovum improv and message when learned
  public override function onLearn(): Void
    {
      var player = game.player;
      game.message('Humans use these to control their breeding habits. However, there is a way that I can reproduce as well.', 'event/goal_evolve_dopamine_receive');
      player.evolutionManager.addImprov(IMP_OVUM);
      game.profile.addPediaArticle('impOvum');
    }
}
