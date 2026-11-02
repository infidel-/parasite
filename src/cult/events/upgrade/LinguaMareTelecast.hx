// event definition for the lingua mare telecast media upgrade
package cult.events.upgrade;

import game.Game;
import cult.Cult;
import cult.EventHelper.*;
import cult.effects.*;
import Const;
import Const.d100;

class LinguaMareTelecast
{
// builds the lingua mare telecast event descriptor
  public static function create(): _CultEvent
    {
      return {
        type: TYPE_OCCASIO,
        title: T('Lingua Mare Telecast'),
        text: T('Windowless relay chapel hums as the freshly elevated anchor kneels before a living teleprompter of plated flesh. Lingua Mare membranes ripple beneath blackout visors while editors splice riot surveillance for covert drops. Only verified cells receive the muted feed. Encrypted carriers pulse once before vanishing beyond the city grid.'),
        choices: [
          {
            button: T('Hot Take'),
            text: T('Flood sealed trend clusters with sanctified clips and let outrage cycle unseen.'),
            f: choice1
          },
          {
            button: T('Echo Sync'),
            text: T('Phase confession mics with hijacked siren tests so fear loops never name us.'),
            f: choice2
          },
          {
            button: T('Vox Seal'),
            text: T('Press a living sigil across the anchor\'s throat to bind clandestine sermons.'),
            f: choice3
          }
        ]
      };
    }

// handles the hot take choice outcome
  public static function choice1(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penalty = rollResourcePayout();
          cult.resources.dec('media', penalty);
          cult.logsg(T('{cult} internal scrubbers strip {n, plural, one{-# media resource} other{-# media resources}}.', {
            cult: cult,
            n: penalty,
          }));
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('media', amount);
      cult.logsg(T('{cult} lingua mare cascade grants {n, plural, one{+# media resource} other{+# media resources}}.', {
        cult: cult,
        n: amount,
      }));
    }

// handles the echo sync choice outcome
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new DecreasePower(game, penaltyTurns, 'media');
          cult.effects.add(setback);
          cult.logsg(T('{cult} feedback howl births {effect}.', {
            cult: cult,
            effect: Const.col('cult-effect', setback.customName()),
          }));
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreasePower(game, turns, 'media');
      cult.effects.add(effect);
      cult.log(T('{cult} shadow broadcast choirs weave {effect} for {turns, plural, one{# turn} other{# turns}}.', {
        cult: cult,
        effect: Const.col('cult-effect', effect.customName()),
        turns: turns,
      }));
    }

// handles the vox seal choice outcome
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var ai = cult.getMemberByID(targetID);
          if (ai != null &&
              ai.addTrait(TRAIT_WEAK_WILLED))
            ai.log(T('{ai:The} buckles as static scars the creed, inheriting the weak-willed flaw.', { ai: ai }));
          return;
        }
      var granted = addTrait(cult, targetID, 'mind', true);
      if (granted == null)
        {
          cult.logsg(T('{cult} vox seal hovers without imprinting insight.', { cult: cult }));
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log(T('{ai:The} lets {trait} echo inside the upgraded voice.', {
          ai: ai,
          trait: granted.name,
        }));
    }
}
