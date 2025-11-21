// event definition for the carnis speculum feed media upgrade
package cult.events.upgrade;

import cult.EventHelper.*;
import cult.effects.*;
import Const.d100;

class CarnisSpeculumFeed
{
// builds the carnis speculum feed event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: 'Carnis Speculum Feed',
        text: 'Repurposed news bunker glows only by emergency strips as the newly ranked voice stands waist-deep in a plexiglass baptistry lined with murmuring flesh cables. A Carnis Speculum mirrors encrypted overlays while drones circle out of sight, relaying packets to sleeper accounts. Accounting ghosts mask the spend.',
        choices: [
          {
            button: 'Ad Buy',
            text: 'Bundle the rite as a midnight shell slot and invoice brands through proxy trusts.',
            f: choice1
          },
          {
            button: 'Pulse Loop',
            text: 'Wire syndicate servers into the reliquary to skim devotion from sealed loopbacks.',
            f: choice2
          },
          {
            button: 'Saint Clip',
            text: 'Cut a relic reel for the vault to script future testimonies and training.',
            f: choice3
          }
        ]
      };
    }

// handles the ad buy choice outcome
  public static function choice1(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var loss = rollMoneyPayout();
          cult.resources.dec('money', loss);
          cult.logsg('forensic flags freeze ' + Const.col('cult-power', '-' + loss) + Icon.money + '.');
          return;
        }
      var amount = rollMoneyPayout();
      cult.resources.money += amount;
      cult.logsg('shell sponsors ghost in ' + Const.col('cult-power', '+' + amount) + Icon.money + '.');
    }

// handles the pulse loop choice outcome
  public static function choice2(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new DecreaseIncome(game, penaltyTurns);
          cult.effects.add(setback);
          cult.logsg('loop fatigue breeds ' + Const.col('cult-effect', setback.customName()) + '.');
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreaseIncome(game, turns);
      cult.effects.add(effect);
      cult.log('silent reliquary hum stacks ' + Const.col('cult-effect', effect.customName()) + ' for ' + turns + ' turns.');
    }

// handles the saint clip choice outcome
  public static function choice3(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var ai = cult.getMemberByID(targetID);
          if (ai != null &&
              ai.addTrait(TRAIT_DUMB))
            ai.log('blank stares replace brilliance, submitting to the dumb flaw.');
          return;
        }
      var granted = addTrait(cult, targetID, 'cultBasic', false);
      if (granted == null)
        {
          cult.logsg('saint clip edits clean without sealing a new devotion.');
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log('records the upgrade with ' + granted.name + ' stitched beneath the skin.');
    }
}
