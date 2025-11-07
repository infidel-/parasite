// event definition for the backchannel litany media upgrade
package cult.events.upgrade;

import game.Game;
import cult.Cult;
import cult.EventHelper.*;
import cult.effects.*;
import Const.d100;

class BackchannelLitany
{
// builds the backchannel litany event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: 'Backchannel Litany',
        text: 'Basement newsroom sinks into red standby as the newly lifted herald stands before a living broadcast rack. Flesh-cooled routers bead condensation while editors whisper instructions through respirator foam. The outside airwaves never catch the pulse, but trusted backchannels await new directives.',
        choices: [
          {
            button: 'Signal Fog',
            text: 'Release decoy traffic across private mesh channels to cloak the real drop.',
            f: choice1
          },
          {
            button: 'Covert Ad',
            text: 'Bill sympathetic agencies through shell vendors and reroute the spend into war funds.',
            f: choice2
          },
          {
            button: 'Litany Seal',
            text: 'Fold the new rank into a hidden mantra archive for vetted ears only.',
            f: choice3
          }
        ]
      };
    }

// handles the signal fog choice outcome
  public static function choice1(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new DecreasePower(game, penaltyTurns, 'media');
          cult.effects.add(setback);
          cult.logsg('masking storm overreaches into ' + Const.col('cult-effect', setback.customName()) + '.');
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreasePower(game, turns, 'media');
      cult.effects.add(effect);
      cult.log('signal fog crowns ' + Const.col('cult-effect', effect.customName()) + ' for ' + turns + ' turns.');
    }

// handles the covert ad choice outcome
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var loss = rollMoneyPayout();
          cult.resources.dec('money', loss);
          cult.logsg('audit ghost clips ' + Const.col('cult-power', '-' + loss) + Icon.money + '.');
          return;
        }
      var amount = rollMoneyPayout();
      cult.resources.money += amount;
      cult.logsg('backchannel invoices clear ' + Const.col('cult-power', '+' + amount) + Icon.money + '.');
    }

// handles the litany seal choice outcome
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var ai = cult.getMemberByID(targetID);
          if (ai != null &&
              ai.addTrait(TRAIT_WEAK_WILLED))
            ai.log('buckles under the sealed refrain, inheriting the weak-willed flaw.');
          return;
        }
      var granted = addTrait(cult, targetID, 'mind', true);
      if (granted == null)
        {
          cult.logsg('litany seal flares without gifting new insight.');
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log('holds ' + granted.name + ' close, sworn to the hidden litany.');
    }
}
