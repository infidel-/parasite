// testmod entry — verifies init() runs and ModContentApi.registerItem works via SDK externs
package;

import mods.ModRuntime;

// custom item class — extends engine ItemInfo via window.parasiteHx.ItemInfo (SDK extern)
class ModTestItem extends ItemInfo
{
  public function new(game: Dynamic)
    {
      super(game);
      id = 'mod-testmod-modtest';
      type = 'misc';
      name = 'mod test trinket';
      unknown = 'odd trinket';
    }
}

@:expose("testmod_Entry")
class Entry
{
  public static function main() {}

// boot hook — receives per-mod parasite runtime object
// runs each smoke test in turn; one method per API surface under test
  public static function init(parasite: ModRuntime)
    {
      testRuntimeInfo(parasite);
      testItemRegistration(parasite);
      testPediaRegistration(parasite);
      testTraitRegistration(parasite);
      testSkillRegistration(parasite);
      testEvolutionRegistration(parasite);
      testGoalRegistration(parasite);
      testSettings(parasite);
      testAssetOverride(parasite);
    }

// logs the runtime fields handed to the mod so we can eyeball what the host wired up
  static function testRuntimeInfo(parasite: ModRuntime)
    {
      var c = js.Browser.console;
      c.log('[testmod] init() called');
      c.log('[testmod] parasite.modID = ' + parasite.modID);
      c.log('[testmod] parasite.modVersion = ' + parasite.modVersion);
      c.log('[testmod] parasite.modApiVersion = ' + parasite.modApiVersion);
      c.log('[testmod] parasite.version = ' + parasite.version);
      c.log('[testmod] parasite.game? ' + (parasite.game != null));
      c.log('[testmod] parasite.host? ' + (parasite.host != null));
    }

// registers a custom item class, then confirms it landed in ItemsConst.infos
  static function testItemRegistration(parasite: ModRuntime)
    {
      var c = js.Browser.console;
      parasite.api.registerItem(ModTestItem);

      var ItemsConst: Dynamic = Reflect.field(parasite.hxClasses, 'const.ItemsConst');
      c.log('[testmod] mod-testmod-modtest in infos? ' +
        ItemsConst.infos.exists('mod-testmod-modtest'));
    }

// registers a pedia group + article, confirms presence,
// then fires a bad-prefix entry that the host must reject
  static function testPediaRegistration(parasite: ModRuntime)
    {
      var c = js.Browser.console;

      // ids must both start with `mod-testmod-`; missing prefix = rejection
      parasite.api.registerPediaEntry({
        id: 'mod-testmod-group',
        name: 'Testmod',
        articles: [
          {
            id: 'mod-testmod-hello',
            name: 'Hello from testmod',
            text: 'this article was added at runtime by testmod via ' +
              'parasite.api.registerPediaEntry()',
          },
        ],
      });
      var PediaConst: Dynamic = Reflect.field(parasite.hxClasses,
        'const.PediaConst');
      c.log('[testmod] pedia group present? ' +
        (PediaConst.getGroup('mod-testmod-group') != null));
      c.log('[testmod] pedia article present? ' +
        (PediaConst.getArticle('mod-testmod-hello') != null));

      // prefix-rejection smoke — should log a reject, NOT register
      parasite.api.registerPediaEntry({
        id: 'badprefix-group',
        name: 'Bad',
        articles: [{ id: 'badprefix-art', name: 'x', text: 'x' }],
      });
    }

// registers a marker trait into the 'misc' group,
// confirms it landed, then fires a bad-prefix trait the host must reject
  static function testTraitRegistration(parasite: ModRuntime)
    {
      var c = js.Browser.console;

      // appended to the 'misc' builtin group so `console add trait test-bravery`
      // can grant it on a host
      parasite.api.registerTrait('misc', {
        id: 'mod-testmod-bravery',
        name: 'test-bravery',
        note: 'Mod-registered marker trait. No mechanical effect.',
        isNegative: false,
      });
      var TraitsConst: Dynamic = Reflect.field(parasite.hxClasses,
        'const.TraitsConst');
      var miscGroup: Array<Dynamic> = TraitsConst.traits.get('misc');
      var found = false;
      for (t in miscGroup)
        if (t.id == 'mod-testmod-bravery')
          { found = true; break; }
      c.log('[testmod] trait mod-testmod-bravery in misc group? ' + found);

      // prefix-rejection smoke for trait — should log a reject, NOT register
      parasite.api.registerTrait('misc', {
        id: 'badtrait',
        name: 'bad',
        note: 'x',
        isNegative: false,
      });
    }

// registers a mod skill, confirms it landed in SkillsConst.skills,
// then fires a bad-prefix skill the host must reject
  static function testSkillRegistration(parasite: ModRuntime)
    {
      var c = js.Browser.console;

      // grantable via `console give skill mod-lockpicking <amount>`
      parasite.api.registerSkill({
        id: 'mod-testmod-lockpicking',
        group: 'Combat',
        name: 'mod lockpicking',
        defaultLevel: 10,
      });
      var SkillsConst: Dynamic = Reflect.field(parasite.hxClasses,
        'const.SkillsConst');
      var skills: Array<Dynamic> = SkillsConst.skills;
      var found = false;
      for (s in skills)
        if (s.id == 'mod-testmod-lockpicking')
          { found = true; break; }
      c.log('[testmod] skill mod-testmod-lockpicking in skills? ' + found);

      // prefix-rejection smoke for skill — should log a reject, NOT register
      parasite.api.registerSkill({
        id: 'badskill',
        name: 'bad',
        defaultLevel: 0,
      });
    }

// registers a mod evolution improvement, confirms it landed in
// EvolutionConst.improvements, then fires a bad-prefix one the host must reject
  static function testEvolutionRegistration(parasite: ModRuntime)
    {
      var c = js.Browser.console;

      // grantable via `console give evolution mod-thickskin <level>`
      // levelNotes/levelParams must cover indices 0..maxLevel (the evolution
      // UI reads levelNotes[level]); too-short arrays crash on level-up
      parasite.api.registerEvolution({
        id: 'mod-testmod-thickskin',
        type: TYPE_BASIC,
        name: 'mod thick skin',
        note: 'Mod-registered marker improvement. No mechanical effect.',
        maxLevel: 2,
        levelNotes: [ 'tougher hide', 'thick hide', 'armored hide' ],
        levelParams: [ {}, {}, {} ],
      });
      var EvolutionConst: Dynamic = Reflect.field(parasite.hxClasses,
        'const.EvolutionConst');
      var improvements: Array<Dynamic> = EvolutionConst.improvements;
      var found = false;
      for (i in improvements)
        if (i.id == 'mod-testmod-thickskin')
          { found = true; break; }
      c.log('[testmod] improvement mod-testmod-thickskin present? ' + found);

      // prefix-rejection smoke — should log a reject, NOT register
      parasite.api.registerEvolution({
        id: 'badimprov',
        type: TYPE_BASIC,
        name: 'bad',
        note: 'x',
        maxLevel: 1,
        levelNotes: [ 'x' ],
        levelParams: [ {} ],
      });
    }

// registers a mod goal, confirms it landed in const.Goals.map,
// then fires a bad-prefix one the host must reject
  static function testGoalRegistration(parasite: ModRuntime)
    {
      var c = js.Browser.console;

      // marker goal; presence verified via Goals.map below (no console grant
      // command exists — `goal complete` only finishes active goals)
      parasite.api.registerGoal({
        id: 'mod-testmod-firstcontact',
        isStarting: true,
        name: 'mod first contact',
        note: 'Mod-registered marker goal. No mechanical effect.',
      });
      var Goals: Dynamic = Reflect.field(parasite.hxClasses, 'const.Goals');
      c.log('[testmod] goal mod-testmod-firstcontact in map? ' +
        Goals.map.exists('mod-testmod-firstcontact'));

      // prefix-rejection smoke for goal — should log a reject, NOT register
      parasite.api.registerGoal({
        id: 'badgoal',
        name: 'bad',
        note: 'x',
      });
    }

// boot counter persisted via mod settings; first launch = 1, subsequent = N+1
  static function testSettings(parasite: ModRuntime)
    {
      var c = js.Browser.console;
      var n = parasite.settings.getInt('boots');
      parasite.settings.set('boots', n + 1);
      c.log('[testmod] settings.boots was ' + n + ', now ' +
        parasite.settings.getInt('boots'));
    }

// asset override smoke — resolve() should return mod:// URLs for assets we shipped
  static function testAssetOverride(parasite: ModRuntime)
    {
      var c = js.Browser.console;
      var AP: Dynamic = Reflect.field(parasite.hxClasses, 'mods.AssetPath');
      c.log('[testmod] resolve(img/mouse0.png) = ' + AP.resolve('img/mouse0.png'));
      c.log('[testmod] resolve(img/mouse1.png) = ' + AP.resolve('img/mouse1.png'));
      c.log('[testmod] resolve(sound/action-fail.mp3) = ' + AP.resolve('sound/action-fail.mp3'));
    }
}
