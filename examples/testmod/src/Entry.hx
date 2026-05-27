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
      testSaveData(parasite);
      testAssetOverride(parasite);
      testEvents(parasite);
      testFx(parasite);
      testRemoteFetch(parasite);
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

// savedata smoke — valid JSON-safe writes round-trip via typed getters;
// invalid writes (cycles, function refs, live class instances, NaN) must
// throw at set() time. exercised at boot, before any savegame exists —
// game.modData is allocated in Game.new() so writes are valid even from init
  static function testSaveData(parasite: ModRuntime)
    {
      var c = js.Browser.console;
      var sd = parasite.savedata;

      // clean slate so reruns within the same boot stay idempotent
      for (k in [ 'kills', 'tags', 'snapshot', 'cycle', 'fn',
            'gameRef', 'nan', 'gone' ])
        sd.remove(k);

      // valid writes — int, array, nested anon object
      sd.set('kills', 17);
      sd.set('tags', [ 'alpha', 'beta' ]);
      sd.set('snapshot', { hp: 42, name: 'boss' });
      c.log('[testmod] savedata kills typed read = ' + sd.getInt('kills', 0));
      var tags: Array<Dynamic> = sd.get('tags');
      c.log('[testmod] savedata tags length = ' +
        (tags != null ? tags.length : -1));
      var snap: Dynamic = sd.get('snapshot');
      c.log('[testmod] savedata snapshot.hp = ' +
        (snap != null ? snap.hp : 'null'));

      // missing key falls back to typed-getter default
      c.log('[testmod] savedata missing getInt def = ' +
        sd.getInt('missingKey', 99));

      // remove clears the value
      sd.set('gone', 1);
      sd.remove('gone');
      c.log('[testmod] savedata removed key reads null? ' +
        (sd.get('gone') == null));

      // negative — cyclic structure must throw
      var cyc: Dynamic = {};
      cyc.self = cyc;
      var caught = false;
      try { sd.set('cycle', cyc); }
      catch (e: Dynamic) caught = true;
      c.log('[testmod] savedata rejects cycle? ' + caught);

      // negative — function reference must throw
      caught = false;
      try { sd.set('fn', function() { return 1; }); }
      catch (e: Dynamic) caught = true;
      c.log('[testmod] savedata rejects function ref? ' + caught);

      // negative — live engine class instance must throw
      caught = false;
      try { sd.set('gameRef', parasite.game); }
      catch (e: Dynamic) caught = true;
      c.log('[testmod] savedata rejects live class instance? ' + caught);

      // negative — NaN must throw (Json.stringify would silently coerce to null)
      caught = false;
      try { sd.set('nan', Math.NaN); }
      catch (e: Dynamic) caught = true;
      c.log('[testmod] savedata rejects NaN? ' + caught);

      // all() returns a shallow copy carrying our valid keys
      var snapshot: Dynamic = sd.all();
      c.log('[testmod] savedata all() has kills key? ' +
        Reflect.hasField(snapshot, 'kills'));
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

// event-bus smoke — subscribe to all 5 hooks; logs every fire so we can confirm
// payloads are typed and the engine fires at the right moments
  static function testEvents(parasite: ModRuntime)
    {
      var c = js.Browser.console;
      parasite.events.onTurnPre(function(e) c.log('[testmod] event turn:pre: turn=' + e.turn));
      parasite.events.onTurnPost(function(e) c.log('[testmod] event turn:post: turn=' + e.turn));
      parasite.events.onAreaEnter(function(e) c.log('[testmod] event area:enter: area=' + e.area.id));
      parasite.events.onAreaLeave(function(e) c.log('[testmod] event area:leave: area=' + e.area.id));
      parasite.events.onAISpawn(function(e) c.log('[testmod] event ai:spawn: ' + e.ai.id + ' in ' + e.area.id));
      c.log('[testmod] subscribed to 5 events');
    }

// fx facade smoke — register a no-op fx, fire it, exercise primitives,
// verify prefix rejection + warn-once on missing id
  static function testFx(parasite: ModRuntime)
    {
      var c = js.Browser.console;

      // register a no-op fx; impl records that play() was called
      var played = { count: 0, lastParams: (null: Dynamic) };
      parasite.fx.register('mod-testmod-noop', {
        play: function(p: Dynamic): Void
          {
            played.count++;
            played.lastParams = p;
          },
      });
      parasite.fx.play('mod-testmod-noop', { hello: 'world' });
      c.log('[testmod] fx play count = ' + played.count +
        ', lastParams.hello = ' + played.lastParams.hello);

      // prefix-rejection smoke — should log a reject, NOT register
      parasite.fx.register('badprefix-fx', {
        play: function(_): Void {},
      });
      parasite.fx.play('badprefix-fx');

      // missing-id warn smoke — first play warns, second is silent (warn-once)
      parasite.fx.play('mod-testmod-doesnotexist');
      parasite.fx.play('mod-testmod-doesnotexist');

      // primitives — overlay() must be non-null, canvas() may be null pre-scene,
      // tick() runs one frame loop with channel for replace semantics
      var ov = parasite.fx.overlay();
      c.log('[testmod] fx.overlay() non-null? ' + (ov != null));
      var cv = parasite.fx.canvas();
      c.log('[testmod] fx.canvas() (may be null pre-scene) non-null? ' + (cv != null));

      var ticks = { frames: 0, done: false };
      parasite.fx.tick(50, function(t: Float): Void
        {
          ticks.frames++;
        }, function(): Void
        {
          ticks.done = true;
          c.log('[testmod] fx.tick done; frames=' + ticks.frames);
        }, 'mod-testmod-ticksmoke');
      c.log('[testmod] fx smoke scheduled');
    }

// remote fetch smoke — renderer CSP `connect-src 'self' mod:` must block
// arbitrary external hosts; fetch to example.com should reject, not resolve
  static function testRemoteFetch(parasite: ModRuntime)
    {
      var c = js.Browser.console;
      var url = 'https://example.com/';
      var p: Dynamic = untyped js.Browser.window.fetch(url);
      p.then(function(resp: Dynamic): Void
        {
          c.log('[testmod] remote fetch UNEXPECTEDLY resolved: status=' +
            resp.status + ' url=' + url);
        }).catchError(function(err: Dynamic): Void
        {
          c.log('[testmod] remote fetch blocked as expected: ' + err);
        });
      c.log('[testmod] remote fetch dispatched to ' + url);
    }
}
