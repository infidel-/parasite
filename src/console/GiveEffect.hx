// console give effect command
package console;

import game.Effect;

class GiveEffect extends GiveBase
{
// gives an effect to the current host
  public function run(args: String)
    {
      var entries = buildEntries();
      if (args == '')
        {
          log('Effects: ' + listEntryNames(entries));
          return;
        }
      var match = selectMatch('effect', args, entries);
      if (match == null)
        return;
      if (game.player.state != PLR_STATE_HOST)
        {
          log('Not on host.');
          return;
        }
      var effect: Effect = null;
      switch (match.value)
        {
          case EFFECT_PARALYSIS:
            effect = new effects.Paralysis(game, 10);
          case EFFECT_SLIME:
            effect = new effects.Slime(game, 10);
          case EFFECT_PANIC:
            effect = new effects.Panic(game, 10);
          case EFFECT_CANNOT_TEAR_AWAY:
            effect = new effects.CannotTearAway(game, 10);
          case EFFECT_CRYING:
            effect = new effects.Crying(game, 10);
          case EFFECT_BERSERK:
            effect = new effects.Berserk(game, 10);
          case EFFECT_SMASH:
            effect = new effects.Smash(game, 10);
          case EFFECT_BLEEDING:
            effect = new effects.Bleeding(game, 10);
          case EFFECT_BLACK_NOISE:
            effect = new effects.BlackNoise(game, 10);
          case EFFECT_WHITE_POWDER:
            effect = new effects.WhitePowder(game, 10);
          case EFFECT_WITHDRAWAL:
            effect = new effects.Withdrawal(game, 10);
          case EFFECT_DRUNK:
            effect = new effects.Drunk(game, 10);
        }
      if (effect == null)
        {
          log('Effect handler not implemented: ' + match.name + '.');
          return;
        }
      game.player.host.onEffect(effect);
      log('Added effect: ' + match.name + '.');
    }

// builds effect entries for selection
  public function buildEntries(): Array<ConsoleAddEntry<_AIEffectType>>
    {
      var all: Array<_AIEffectType> = [
        EFFECT_PARALYSIS, EFFECT_SLIME, EFFECT_PANIC, EFFECT_CANNOT_TEAR_AWAY,
        EFFECT_CRYING, EFFECT_BERSERK, EFFECT_SMASH, EFFECT_BLEEDING,
        EFFECT_BLACK_NOISE, EFFECT_WHITE_POWDER, EFFECT_WITHDRAWAL, EFFECT_DRUNK
      ];
      var list = [];
      for (effect in all)
        {
          var name = (effect: String).substr(7).toLowerCase();
          list.push({
            name: name,
            searchKey: normalizeKey(name),
            value: effect
          });
        }
      list.sort(function(a, b)
        {
          return compareStrings(a.name, b.name);
        });
      return list;
    }
}
