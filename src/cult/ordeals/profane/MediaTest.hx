// media test profane ordeal sample
package cult.ordeals.profane;

import game.Game;
import cult.ProfaneOrdeal;
import cult.effects.DecreaseIncome;

class MediaTest extends ProfaneOrdeal
{
  public function new(g: Game)
    {
      super(g);
      init();
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      name = 'Media Scrutiny';
      note = 'The media has taken notice of your activities. You must respond quickly or face consequences.';
      timer = 10;
      
      // add negative effect
      var effect = new DecreaseIncome(game, timer);
      effects.push(effect);
      
      // set power requirements
      power.media = 15;
      power.money = 50000;
    }
}
