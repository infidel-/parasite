// console give command router (give <entity> ...)
package console;

class Give extends GiveBase
{
  var effect: GiveEffect;
  var item: GiveItem;
  var organ: GiveOrgan;
  var skill: GiveSkill;
  var trait: GiveTrait;
  var evolution: GiveEvolution;

// sets up give command router and sub-handlers
  public function new(c: Console)
    {
      super(c);
      effect = new GiveEffect(c);
      item = new GiveItem(c);
      organ = new GiveOrgan(c);
      skill = new GiveSkill(c);
      trait = new GiveTrait(c);
      evolution = new GiveEvolution(c);
    }

// returns the selectable entry names for a give entity (for tab completion)
  public function names(sub: String): Array<String>
    {
      var entries: Array<{ name: String }> = switch (sub)
        {
          case 'effect': cast effect.buildEntries();
          case 'item': cast item.buildEntries();
          case 'organ': cast organ.buildEntries();
          case 'skill': cast skill.buildEntries();
          case 'trait': cast trait.buildEntries();
          case 'evolution': cast evolution.buildEntries();
          default: [];
        };
      var out = [];
      for (e in entries)
        out.push(e.name);
      return out;
    }

// routes a give command to its entity handler; returns false if not a give command
  public function run(cmd: String): Bool
    {
      var arr = cmd.split(' ');
      if (arr[0] != 'give')
        return false;
      var sub = (arr.length > 1 ? arr[1] : '');
      // everything after "give <entity>" is the entity-specific argument string
      var args = (arr.length > 2 ? StringTools.trim(arr.slice(2).join(' ')) : '');
      switch (sub)
        {
          case 'effect':
            effect.run(args);
          case 'item':
            item.run(args);
          case 'organ':
            organ.run(args);
          case 'skill':
            skill.run(args);
          case 'trait':
            trait.run(args);
          case 'evolution':
            evolution.run(args);
          case '':
            log('Usage: give [effect|item|organ|skill|trait|evolution] ...');
          default:
            log('Unknown give target: ' + sub + '.');
        }
      return true;
    }
}
