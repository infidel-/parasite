// media test profane ordeal sample
package cult.ordeals.profane;

import game.Game;
import cult.ProfaneOrdeal;
import cult.effects.*;
import cult.missions.*;
import cult.missions.Persuade;
import cult.missions.Kill;

class MediaTest extends ProfaneOrdeal
{
  public function new(g: Game)
    {
      super(g);
      init();
      initPost(false);
      addRandomMembers({
        level: 1,
        amount: 2
      });
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
      
      // add persuade mission
      var persuadeMission = new Persuade(game);
      missions.push(persuadeMission);
      
      // set power requirements
      power.media = 15;
      power.money = 50000;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }
}
