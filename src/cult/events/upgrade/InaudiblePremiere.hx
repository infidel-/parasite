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
        title: T('Inaudible Premiere'),
        text: T('Decommissioned amphitheater lies dark as the newly promoted anchor sits in a ring of whispering projectors. Warm mist coats their suit while techs layer pre-recorded testimonies into encrypted playlists. Above ground, rush-hour chatter unwittingly ferries the inaudible instructions.'),
        choices: [
          {
            button: T('Silent Cut'),
            text: T('Release the premiere as timed bursts in private feeds keyed to sleeper phrases.'),
            f: choice1
          },
          {
            button: T('Echo Vault'),
            text: T('Store the testimonies in a sealed cache that pulses morale to loyal cells.'),
            f: choice2
          },
          {
            button: T('Script Brand'),
            text: T('Brand the anchor\'s psyche with mnemonic cuts for future underground sermons.'),
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
          cult.logsg(T('{cult} silent cut misfires and sheds {n, plural, one{-# media resource} other{-# media resources}}.', {
            cult: cult,
            n: penalty,
          }));
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('media', amount);
      cult.logsg(T('{cult} silent cut returns {n, plural, one{+# media resource} other{+# media resources}}.', {
        cult: cult,
        n: amount,
      }));
    }

// handles the echo vault choice outcome
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new LoseResource(game, penaltyTurns, 'media');
          cult.effects.add(setback);
          cult.logsg(T('{cult} echo vault strains into {effect}.', {
            cult: cult,
            effect: Const.col('cult-effect', setback.customName()),
          }));
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new GainResource(game, turns, 'media');
      cult.effects.add(effect);
      cult.log(T('{cult} inaudible premiere sanctifies {effect} for {turns, plural, one{# turn} other{# turns}}.', {
        cult: cult,
        effect: Const.col('cult-effect', effect.customName()),
        turns: turns,
      }));
    }

// handles the script brand choice outcome
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var ai = cult.getMemberByID(targetID);
          if (ai != null &&
              ai.addTrait(TRAIT_WEAK_WILLED))
            ai.log(T('{ai:The} reels from fractured edits and gains the weak-willed flaw.', { ai: ai }));
          return;
        }
      var granted = addTrait(cult, targetID, 'mind', true);
      if (granted == null)
        {
          cult.logsg(T('{cult} script brand glows without sowing a new recall.', { cult: cult }));
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log(T('{ai:The} lets {trait} echo across future clandestine sermons.', {
          ai: ai,
          trait: granted.name,
        }));
    }
}
