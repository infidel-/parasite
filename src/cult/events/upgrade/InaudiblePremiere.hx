// event definition for the inaudible premiere media upgrade
package cult.events.upgrade;

import game.Game;
import cult.Cult;
import cult.EventHelper.*;
import cult.effects.*;
import Const.d100;

class InaudiblePremiere
{
// builds the inaudible premiere event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: 'Inaudible Premiere',
        text: 'Decommissioned amphitheater lies dark as the newly promoted anchor sits in a ring of whispering projectors. Warm mist coats their suit while techs layer pre-recorded testimonies into encrypted playlists. Above ground, rush-hour chatter unwittingly ferries the inaudible instructions.',
        choices: [
          {
            button: 'Silent Cut',
            text: 'Release the premiere as timed bursts in private feeds keyed to sleeper phrases.',
            f: choice1
          },
          {
            button: 'Echo Vault',
            text: 'Store the testimonies in a sealed cache that pulses morale to loyal cells.',
            f: choice2
          },
          {
            button: 'Script Brand',
            text: 'Brand the anchor\'s psyche with mnemonic cuts for future underground sermons.',
            f: choice3
          }
        ]
      };
    }

// handles the silent cut choice outcome
  public static function choice1(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penalty = rollResourcePayout();
          cult.resources.dec('media', penalty);
          cult.logsg('silent cut misfires and sheds -' + penalty + ' media resource.');
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('media', amount);
      cult.logsg('silent cut returns +' + amount + ' media resource.');
    }

// handles the echo vault choice outcome
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new LoseResource(game, penaltyTurns, 'media');
          cult.effects.add(setback);
          cult.logsg('echo vault strains into ' + Const.col('cult-effect', setback.customName()) + '.');
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new GainResource(game, turns, 'media');
      cult.effects.add(effect);
      cult.log('inaudible premiere sanctifies ' + Const.col('cult-effect', effect.customName()) + ' for ' + turns + ' turns.');
    }

// handles the script brand choice outcome
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var ai = cult.getMemberByID(targetID);
          if (ai != null &&
              ai.addTrait(TRAIT_WEAK_WILLED))
            ai.log('reels from fractured edits and gains the weak-willed flaw.');
          return;
        }
      var granted = addTrait(cult, targetID, 'mind', true);
      if (granted == null)
        {
          cult.logsg('script brand glows without sowing a new recall.');
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log('lets ' + granted.name + ' echo across future clandestine sermons.');
    }
}
