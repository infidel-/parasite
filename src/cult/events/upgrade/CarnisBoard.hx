// event definition for the carnis board corporate upgrade
package cult.events.upgrade;

import game.Game;
import cult.Cult;
import cult.EventHelper.*;
import cult.effects.*;
import Const.d100;

class CarnisBoard
{
// builds the carnis board event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: 'Carnis Board',
        text: 'Mahogany paneling bleeds at the edges as the newly promoted director kneels before a boardroom table of living flesh. The surface pulses with buried arteries. Around the slab, other executives press ears to the membrane, listening to dividends whispered through capillary channels. The outside shareholders never hear the true votes, but trusted tissue carries the quorum.',
        choices: [
          {
            button: 'Pulp Agenda',
            text: 'Inject enzyme into the board-table to digest old minutes and spawn new motions.',
            f: choice1
          },
          {
            button: 'Vein Quorum',
            text: 'Suture rival directors into the board-flesh, merging their voting rights into our tissue.',
            f: choice2
          },
          {
            button: 'Seal Minutes',
            text: 'Carve the promoted director into a hidden board-node for executive sessions only.',
            f: choice3
          }
        ]
      };
    }

// handles the case draw choice outcome
  public static function choice1(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var penalty = rollResourcePayout();
          cult.resources.dec('corporate', penalty);
          cult.logsg('case draw leaks -' + penalty + ' corporate resource.');
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('corporate', amount);
      cult.logsg('case draw locks +' + amount + ' corporate resource.');
    }

// handles the echo seal choice outcome
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var failTurns = d100() < 5 ? 10 : 5;
          var drain = new DecreasePower(game, failTurns, 'corporate');
          cult.effects.add(drain);
          cult.logsg('echo seal overreaches into ' + Const.col('cult-effect', drain.customName()) + '.');
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreasePower(game, turns, 'corporate');
      cult.effects.add(effect);
      cult.log('memorandum veil channels ' + Const.col('cult-effect', effect.customName()) + ' for ' + turns + ' turns.');
    }

// handles the script lash choice outcome
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      // 5% setback check
      if (d100() < 5)
        {
          var aiNeg = cult.getMemberByID(targetID);
          if (aiNeg != null &&
              aiNeg.addTrait(TRAIT_WEAK_WILLED))
            aiNeg.log('flinches from the lashes and gains the weak-willed flaw.');
          return;
        }
      var granted = addTrait(cult, targetID, 'mind', true);
      if (granted == null)
        {
          cult.logsg('script lash fades without etching new recall.');
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log('feels ' + granted.name + ' sear along the clandestine charter.');
    }
}
