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
        title: 'Lingua Mare Telecast',
        text: 'Windowless relay chapel hums as the freshly elevated anchor kneels before a living teleprompter of plated flesh. Lingua Mare membranes ripple beneath blackout visors while editors splice riot surveillance for covert drops. Only verified cells receive the muted feed. Encrypted carriers pulse once before vanishing beyond the city grid.',
        choices: [
          {
            button: 'Hot Take',
            text: 'Flood sealed trend clusters with sanctified clips and let outrage cycle unseen.',
            f: choice1
          },
          {
            button: 'Echo Sync',
            text: 'Phase confession mics with hijacked siren tests so fear loops never name us.',
            f: choice2
          },
          {
            button: 'Vox Seal',
            text: 'Press a living sigil across the anchor\'s throat to bind clandestine sermons.',
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
          cult.logsg('internal scrubbers strip -' + penalty + ' media resource.');
          return;
        }
      var amount = rollResourcePayout();
      cult.resources.inc('media', amount);
      cult.logsg('lingua mare cascade grants +' + amount + ' media resource.');
    }

// handles the echo sync choice outcome
  public static function choice2(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var penaltyTurns = d100() < 5 ? 10 : 5;
          var setback = new DecreasePower(game, penaltyTurns, 'media');
          cult.effects.add(setback);
          cult.logsg('feedback howl births ' + Const.col('cult-effect', setback.customName()) + '.');
          return;
        }
      var turns = d100() < 5 ? 10 : 5;
      var effect = new IncreasePower(game, turns, 'media');
      cult.effects.add(effect);
      cult.log('shadow broadcast choirs weave ' + Const.col('cult-effect', effect.customName()) + ' for ' + turns + ' turns.');
    }

// handles the vox seal choice outcome
  public static function choice3(game: Game, cult: Cult, targetID: Int): Void
    {
      if (d100() < 5)
        {
          var ai = cult.getMemberByID(targetID);
          if (ai != null &&
              ai.addTrait(TRAIT_WEAK_WILLED))
            ai.log('buckles as static scars the creed, inheriting the weak-willed flaw.');
          return;
        }
      var granted = addTrait(cult, targetID, 'mind', true);
      if (granted == null)
        {
          cult.logsg('vox seal hovers without imprinting insight.');
          return;
        }
      var ai = cult.getMemberByID(targetID);
      if (ai != null)
        ai.log('lets ' + granted.name + ' echo inside the upgraded voice.');
    }
}
