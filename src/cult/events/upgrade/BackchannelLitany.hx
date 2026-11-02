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
        title: T('Backchannel Litany'),
        text: T('Basement newsroom sinks into red standby as the newly lifted herald stands before a living broadcast rack. Flesh-cooled routers bead condensation while editors whisper instructions through respirator foam. The outside airwaves never catch the pulse, but trusted backchannels await new directives.'),
        choices: [
          {
            button: T('Signal Fog'),
            text: T('Release decoy traffic across private mesh channels to cloak the real drop.'),
            f: choice1
          },
          {
            button: T('Covert Ad'),
            text: T('Bill sympathetic agencies through shell vendors and reroute the spend into war funds.'),
            f: choice2
          },
          {
            button: T('Litany Seal'),
            text: T('Fold the new rank into a hidden mantra archive for vetted ears only.'),
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
          cult.logsg(T('{cult} masking storm overreaches into {effect}.', {
            cult: cult,
            effect: Const.col('cult-effect', setback.customName()),
          }));
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreasePower(game, turns, 'media');
      cult.effects.add(effect);
      cult.log(T('{cult} signal fog crowns {effect} for {turns, plural, one{# turn} other{# turns}}.', {
        cult: cult,
        effect: Const.col('cult-effect', effect.customName()),
        turns: turns,
      }));
    }

// handles the covert ad choice outcome
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var loss = rollMoneyPayout();
          cult.resources.dec('money', loss);
          cult.logsg(T('{cult} audit ghost clips {money}.', {
            cult: cult,
            money: Const.col('cult-power', '-' + loss) + Icon.money,
          }));
          return;
        }
      var amount = rollMoneyPayout();
      cult.resources.money += amount;
      cult.logsg(T('{cult} backchannel invoices clear {money}.', {
        cult: cult,
        money: Const.col('cult-power', '+' + amount) + Icon.money,
      }));
    }

// handles the litany seal choice outcome
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var ai = cult.getMemberByID(targetID);
          if (ai != null &&
              ai.addTrait(TRAIT_WEAK_WILLED))
            ai.log(T('{ai:The} buckles under the sealed refrain, inheriting the weak-willed flaw.', { ai: ai }));
          return;
        }
      var granted = addTrait(cult, targetID, 'mind', true);
      if (granted == null)
        {
          cult.logsg(T('{cult} litany seal flares without gifting new insight.', { cult: cult }));
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log(T('{ai:The} holds {trait} close, sworn to the hidden litany.', {
          ai: ai,
          trait: granted.name,
        }));
    }
}
