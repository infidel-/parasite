// event definition for the vote vein political upgrade
package cult.events.upgrade;

import game.Game;
import cult.Cult;
import cult.EventHelper.*;
import cult.effects.*;
import Const.d100;

class VoteVein
{
// builds the vote vein event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: 'Vote Vein',
        text: 'In the chambers legislative, the newly appointed floor manager kneels before veins that pump votes through party arteries. Roll call throbs with living blood, each clot sending votes through arterial networks. Whips press palms to vein-walls, counting votes through arterial pressure. Outside observers never feel the true pulse, but trusted blood delivers the hidden tally.',
        choices: [
          {
            button: 'Pump Votes',
            text: 'Pump votes through party veins.',
            f: choice1
          },
          {
            button: 'Clot Tally',
            text: 'Count clot-bursts for passage.',
            f: choice2
          },
          {
            button: 'Vein Whip',
            text: 'Bind manager into vein-whip.',
            f: choice3
          }
        ]
      };
    }

// handles pump votes choice
  public static function choice1(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var failTurns = d100() < 5 ? 10 : 5;
          var drain = new LoseResource(game, failTurns, 'political');
          cult.effects.add(drain);
          cult.logsg('pump rupture bleeds ' + Const.col('cult-effect', drain.customName()) + '.');
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('political', amount);
      cult.logsg('pump flows +' + amount + ' political resource.');
    }

// handles clot tally choice
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var aiNeg = cult.getMemberByID(targetID);
          if (aiNeg != null &&
              aiNeg.addTrait(TRAIT_WEAK_WILLED))
            aiNeg.log('tally pressure spawns weak-willed flaw.');
          return;
        }
      var grantskill = addTrait(cult, targetID, 'skill', true);
      if (grantskill == null)
      {
        var grantmind = addTrait(cult, targetID, 'mind', true);
        if (grantmind == null)
          cult.logsg('clot tally counts without new insight.');
      }
    }

// handles vein whip choice
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new DecreasePower(game, penaltyTurns, 'political');
          cult.effects.add(setback);
          cult.logsg('whip snaps into ' + Const.col('cult-effect', setback.customName()) + '.');
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreasePower(game, turns, 'political');
      cult.effects.add(effect);
      cult.log('vein whip lashes ' + Const.col('cult-effect', effect.customName()) + ' for ' + turns + ' turns.');
    }
}
