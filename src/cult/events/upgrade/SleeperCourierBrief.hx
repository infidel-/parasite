// event definition for the sleeper courier brief media upgrade
package cult.events.upgrade;

import game.Game;
import cult.Cult;
import cult.EventHelper.*;
import cult.effects.*;
import Const.d100;

class SleeperCourierBrief
{
// builds the sleeper courier brief event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: 'Sleeper Courier Brief',
        text: 'Forgotten telecom exchange throbs as the upgraded voice posts watch within a ring of skin-bound terminals. Frosted glass hides the glow while analysts queue muted briefings into private inboxes. No bulletin leaks; only card-carrying congregants feel the vibration in their pockets.',
        choices: [
          {
            button: 'Pulse Lists',
            text: 'Cleanse subscriber rolls and prime vetted couriers for synchronized alerts.',
            f: choice1
          },
          {
            button: 'Inbox Hex',
            text: 'Embed disposable malware into enemy tip lines to choke their monitoring grids.',
            f: choice2
          },
          {
            button: 'Courier Vow',
            text: 'Bind the promoted voice to encrypted pledgewords reserved for sleeper hubs.',
            f: choice3
          }
        ]
      };
    }

// handles the pulse lists choice outcome
  public static function choice1(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penalty = rollResourcePayout();
          cult.resources.dec('media', penalty);
          cult.logsg('subscriber purge scrapes -' + penalty + ' media resource.');
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('media', amount);
      cult.logsg('pulse lists fortify +' + amount + ' media resource.');
    }

// handles the inbox hex choice outcome
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new IncreaseTradeCost(game, penaltyTurns);
          cult.effects.add(setback);
          cult.logsg('counter-ops rebound into ' + Const.col('cult-effect', setback.customName()) + '.');
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreaseIncome(game, turns);
      cult.effects.add(effect);
      cult.log('inbox hex spawns ' + Const.col('cult-effect', effect.customName()) + ' for ' + turns + ' turns.');
    }

// handles the courier vow choice outcome
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var ai = cult.getMemberByID(targetID);
          if (ai != null &&
              ai.addTrait(TRAIT_DUMB))
            ai.log('loses sharpness under vow pressure, adopting the dumb flaw.');
          return;
        }
      var granted = addTrait(cult, targetID, 'cultBasic', false);
      if (granted == null)
        {
          cult.logsg('courier vow settles without revealing new devotion.');
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log('signs the vow and absorbs ' + granted.name + ' into the mission brief.');
    }
}
