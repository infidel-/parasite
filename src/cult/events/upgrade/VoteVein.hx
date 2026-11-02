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
        title: T('Vote Vein'),
        text: T('In the chambers legislative, the newly appointed floor manager kneels before veins that pump votes through party arteries. Roll call throbs with living blood, each clot sending votes through arterial networks. Whips press palms to vein-walls, counting votes through arterial pressure. Outside observers never feel the true pulse, but trusted blood delivers the hidden tally.'),
        choices: [
          {
            button: T('Pump Votes'),
            text: T('Pump votes through party veins.'),
            f: choice1
          },
          {
            button: T('Clot Tally'),
            text: T('Count clot-bursts for passage.'),
            f: choice2
          },
          {
            button: T('Vein Whip'),
            text: T('Bind manager into vein-whip.'),
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
          cult.logsg(T('{cult} pump rupture bleeds {effect}.', {
            cult: cult,
            effect: Const.col('cult-effect', drain.customName()),
          }));
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('political', amount);
      cult.logsg(T('{cult} pump flows {n, plural, one{+# political resource} other{+# political resources}}.', {
        cult: cult,
        n: amount,
      }));
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
            aiNeg.log(T('{ai:The} tally pressure spawns weak-willed flaw.', { ai: aiNeg }));
          return;
        }
      var grantskill = addTrait(cult, targetID, 'skill', true);
      if (grantskill == null)
      {
        var grantmind = addTrait(cult, targetID, 'mind', true);
        if (grantmind == null)
          cult.logsg(T('{cult} clot tally counts without new insight.', { cult: cult }));
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
          cult.logsg(T('{cult} whip snaps into {effect}.', {
            cult: cult,
            effect: Const.col('cult-effect', setback.customName()),
          }));
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreasePower(game, turns, 'political');
      cult.effects.add(effect);
      cult.log(T('{cult} vein whip lashes {effect} for {turns, plural, one{# turn} other{# turns}}.', {
        cult: cult,
        effect: Const.col('cult-effect', effect.customName()),
        turns: turns,
      }));
    }
}
