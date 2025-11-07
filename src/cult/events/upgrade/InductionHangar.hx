// event definition for the induction hangar combat upgrade
package cult.events.upgrade;

import game.Game;
import cult.Cult;
import cult.EventHelper.*;
import cult.effects.*;
import Const;
import Const.d100;
import Icon;
import _CultEvent;
import _CultEventType;
import _AITraitType;

class InductionHangar
{
// builds the induction hangar event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: 'Induction Hangar',
        text: 'Cargo drones idle over the repurposed hangar while the elevation banquet hisses on induction grills. Veteran cantors tape reinforced grips, rookies laser-etch ordeal sigils into riot shields, and the council waits to hear if this vigil yields new tactics, lean logistics, or dangers disguised as applause.',
        choices: [
          {
            button: 'Cash Grab',
            text: 'Auction ritual trophies through darknet brokers and launder the bids straight into hardened gear budgets.',
            f: choice1
          },
          {
            button: 'Share Docs',
            text: 'Swap encrypted playbooks with allied cells so squads can cross-train on each other\'s breach patterns.',
            f: choice2
          },
          {
            button: 'Peer Audit',
            text: 'Pair veterans with recruits for a brutal after-action autopsy, annotating every flaw from the ordeal footage.',
            f: choice3
          }
        ]
      };
    }

// handles the cash grab choice outcome
  public static function choice1(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var loss = rollMoneyPayout();
          cult.resources.dec('money', loss);
          cult.logsg('a bribed inspector skims ' + Const.col('cult-power', '-' + loss) + Icon.money + '.');
          return;
        }
      var amount = rollMoneyPayout();
      cult.resources.money += amount;
      cult.logsg('coffers take ' + Const.col('cult-power', '+' + amount) + Icon.money + '.');
    }

// handles the share docs choice outcome
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var effTurns = d100() < 5 ? 10 : 5;
          var eff = new IncreaseTradeCost(game, effTurns);
          cult.effects.add(eff);
          cult.logsg('misprints leak, causing ' + Const.col('cult-effect', eff.customName()) + '.');
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreaseIncome(game, turns);
      cult.effects.add(effect);
      cult.logsg('shares schematics, enabling ' + Const.col('cult-effect', effect.customName()) + ' for ' + turns + ' turns.');
    }

// handles the peer audit choice outcome
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var ai = cult.getMemberByID(targetID);
          if (ai != null &&
              ai.addTrait(TRAIT_DRUG_ADDICT))
            ai.logsg('slips into stim dependence during the long debrief.');
          return;
        }
      var awarded = addTrait(cult, targetID, 'cultBasic', false);
      if (awarded == null)
        {
          cult.logsg('evaluations end with respect but no new trait.');
        }
    }
}
