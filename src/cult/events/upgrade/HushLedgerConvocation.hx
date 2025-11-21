// event definition for the hush ledger convocation lawfare upgrade
package cult.events.upgrade;

import cult.EventHelper.*;
import cult.effects.*;
import Const.d100;

class HushLedgerConvocation
{
// builds the hush ledger convocation event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: 'Hush Ledger Convocation',
        text: 'Night-shuttered policy cellar glows low as the newly ranked strategist stands amid racks of blood-warmed statutes. Analysts whisper precedent through gauze masks while flesh-bound ledgers inhale hush payments. Outside traffic drones past, unaware the verdict already beats beneath the floor.',
        choices: [
          {
            button: 'Proxy Net',
            text: 'Route sealed settlements through layered shell firms and skim reserves.',
            f: choice1
          },
          {
            button: 'Memo Choir',
            text: 'Sync the memo choir with encrypted dashboards to amplify unseen leverage.',
            f: choice2
          },
          {
            button: 'Vow Ledger',
            text: 'Tattoo the strategist with ledger sigils carrying clandestine doctrines.',
            f: choice3
          }
        ]
      };
    }

// handles the proxy net choice outcome
  public static function choice1(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var loss = rollMoneyPayout();
          cult.resources.dec('money', loss);
          cult.logsg('proxy net unravels ' + Const.col('cult-power', '-' + loss) + Icon.money + '.');
          return;
        }
      var amount = rollMoneyPayout();
      cult.resources.money += amount;
      cult.logsg('proxy net sluices ' + Const.col('cult-power', '+' + amount) + Icon.money + '.');
    }

// handles the memo choir choice outcome
  public static function choice2(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new DecreaseIncome(game, penaltyTurns);
          cult.effects.add(setback);
          cult.logsg('memo choir overload births ' + Const.col('cult-effect', setback.customName()) + '.');
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreaseIncome(game, turns);
      cult.effects.add(effect);
      cult.log('hush ledger convocation breathes ' + Const.col('cult-effect', effect.customName()) + ' for ' + turns + ' turns.');
    }

// handles the vow ledger choice outcome
  public static function choice3(game: game.Game, cult: cult.Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var aiNeg = cult.getMemberByID(targetID);
          if (aiNeg != null &&
              aiNeg.addTrait(TRAIT_DUMB))
            aiNeg.log('drowns in figures and takes on the dumb flaw.');
          return;
        }
      var granted = addTrait(cult, targetID, 'cultBasic', false);
      if (granted == null)
        {
          cult.logsg('vow ledger closes without granting fresh doctrine.');
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log('records ' + granted.name + ' into the hidden ledger vows.');
    }
}
