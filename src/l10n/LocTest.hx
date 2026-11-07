// self-check for loc.Loc (formatter, plural/select, English, French and German noun forms, pseudo):
// compiled and run under node by the src Makefile on every build; exits 1 on any failure
package l10n;

class LocTest
{
  static var fails = 0;
  static inline var STAB = '{attacker:The} tries to stab {target:the}, but misses.';
  static inline var STUN = '{attacker:The} stuns {target:the} for {rounds, plural, one{# round} other{# rounds}}.';

  static function main()
    {
      english();
      french();
      german();
      pseudo();
      out(fails == 0 ? 'loc-test: ok' : 'loc-test: ' + fails + ' FAILED');
      if (fails > 0)
        js.Syntax.code("process.exit(1)");
    }

// English: identity, plural, noun forms, select, colored spans, broken templates
  static function english()
    {
      Loc.init('en', null);
      eq(Loc.tr('Hello.'), 'Hello.');
      var turns = '{n, plural, one{# turn} other{# turns}}';
      eq(Loc.fmt(turns, { n: 1 }), '1 turn');
      eq(Loc.fmt(turns, { n: 3 }), '3 turns');
      eq(Loc.fmt('{n, plural, =0{none} one{one} other{#}}', { n: 0 }), 'none');
      eq(Loc.fmt('{s:The} hesitates to attack you.', { s: noun('soldier', 'm') }),
        'The soldier hesitates to attack you.');
      eq(Loc.fmt('You see {s:a}.', { s: noun('officer', 'f') }), 'You see an officer.');
      eq(Loc.fmt('{s:The} waits.', { s: name('John Smith', 'm') }), 'John Smith waits.');
      eq(Loc.fmt('{s:The} waits.', { s: phrase('your host', 'm') }), 'Your host waits.');
      var his = '{s, select, m{his} f{her} other{its}}';
      eq(Loc.fmt(his, { s: noun('dog', 'n') }), 'its');
      eq(Loc.fmt(his, { s: name('Ann', 'f') }), 'her');
      eq(Loc.fmt('{n, plural, one{# {what}} other{# {what}s}}', { n: 2, what: 'clue' }), '2 clues');
      eq(Loc.fmt('You find {i:a}.', { i: Loc.colored('inventory-item', noun('pistol', 'n')) }),
        "You find <span style='color:var(--text-color-inventory-item)'>a pistol</span>.");
      // real templates: a weapon line (items/Knife.hx), a stun count, a styled cult name
      eq(Loc.fmt(STAB, {
        attacker: phrase('your host', 'm'),
        target: noun('police officer', 'f'),
      }), 'Your host tries to stab the police officer, but misses.');
      eq(Loc.fmt(STUN, {
        attacker: noun('agent', 'm'),
        target: name('Ann', 'f'),
        rounds: 1,
      }), 'The agent stuns Ann for 1 round.');
      eq(Loc.fmt('You pick {i:the} up.', { i: Loc.thing('keycard') }), 'You pick the keycard up.');
      eq(Loc.fmt('{oops', { oops: 1 }), '{oops');
      // an alien ship part name: the article follows the bare noun, the span stays as written
      eq(Loc.fmt('You see {i:a}.', { i: noun('<span class=alien1>engine core</span>', 'n') }),
        'You see an <span class=alien1>engine core</span>.');
      eq(Loc.names('{a:The} {n, plural, one{# {b}} other{#}} {a}').join(','), 'a,n,b');
      // a damaged lang file boots in English
      Loc.init('fr', '{"strings": {');
      eq(Loc.lang(), 'en');
      eq(Loc.tr('Hello.'), 'Hello.');
    }

// French: table lookup, elision, articles, feminine variants, de/à contractions, names, plural
  static function french()
    {
      Loc.init('fr', haxe.Json.stringify({
        strings: {
          'Hello.': 'Bonjour.',
          '{s:The} hesitates.': '{s:Def} hésite.',
          'your host': 'votre hôte',
          '{attacker:The} tries to stab {target:the}, but misses.': '{attacker:Def} essaie de poignarder {target:def}, mais rate son coup.',
        },
        nouns: {
          'soldier': { g: 'm', s: 'soldat' },
          'agent': { g: 'm', s: 'agent' },
          'police officer': { g: 'm', s: 'policier', fs: 'policière' },
          'secretary': { g: 'f', s: 'secrétaire' },
          'hero': { g: 'm', s: 'héros', elide: false },
          'power battery': { g: 'f', s: 'batterie' },
        },
      }));
      eq(Loc.fmt(Loc.tr('{s:The} hesitates.'), { s: noun('<span class=alien1>power battery</span>', 'n') }),
        'La <span class=alien1>power battery</span> hésite.');
      eq(Loc.tr('Hello.'), 'Bonjour.');
      eq(Loc.fmt(Loc.tr('{s:The} hesitates.'), { s: noun('soldier', 'm') }), 'Le soldat hésite.');
      eq(Loc.fmt('{s:def}|{s:indef}|{s:de}|{s:a}', { s: noun('soldier', 'm') }),
        'le soldat|un soldat|du soldat|au soldat');
      eq(Loc.fmt('{s:Def}|{s:de}|{s:a}', { s: noun('agent', 'f') }), 'L’agent|de l’agent|à l’agent');
      eq(Loc.fmt('{s:def}|{s:def}', { s: noun('police officer', 'f') }), 'la policière|la policière');
      eq(Loc.fmt('{s:def}', { s: noun('police officer', 'm') }), 'le policier');
      eq(Loc.fmt('{s, select, m{il} f{elle} other{il}}', { s: noun('police officer', 'f') }), 'elle');
      eq(Loc.fmt('{s:def}|{s:de}|{s:a}', { s: noun('secretary', 'm') }),
        'la secrétaire|de la secrétaire|à la secrétaire');
      eq(Loc.fmt('{s:def}', { s: noun('hero', 'm') }), 'le héros');
      eq(Loc.fmt('{a:de}|{b:de}|{b:a}', { a: name('Alice', 'f'), b: name('Bob', 'm') }), 'd’Alice|de Bob|à Bob');
      eq(Loc.fmt(Loc.tr(STAB), {
        attacker: phrase('your host', 'm'),
        target: noun('police officer', 'f'),
      }), 'Votre hôte essaie de poignarder la policière, mais rate son coup.');
      var cult = name("<span class=cult>Ordo Carnis</span>", 'm');
      eq(Loc.fmt('{c:de}|{c:a}', { c: cult }),
        "d’<span class=cult>Ordo Carnis</span>|à <span class=cult>Ordo Carnis</span>");
      // an untranslated English template stays English, nouns included
      eq(Loc.fmt('{a:The} rips {t:the}.', { a: noun('soldier', 'm'), t: phrase('your host', 'm') }),
        'The soldier rips your host.');
      // whatever forms it uses: {x:a} is not the French à, a select goes by natural gender, plurals by English rules
      var mod = Loc.tr('You find {i:a}; {d, select, m{his} f{her} other{its}} {n, plural, one{# turn} other{# turns}}.');
      eq(Loc.fmt(mod, { i: noun('soldier', 'm'), d: noun('soldier', 'n'), n: 0 }), 'You find a soldier; its 0 turns.');
      // a colored value selects by what it wraps
      eq(Loc.fmt('{p, select, media{médias} other{autre}}', { p: Loc.colored('cult-power', 'media') }), 'médias');
      var tours = '{n, plural, one{# tour} other{# tours}}';
      eq(Loc.fmt(tours, { n: 0 }), '0 tour');
      eq(Loc.fmt(tours, { n: 2 }), '2 tours');
      Loc.tr('Not translated.');
      Loc.fmt('{s:def}', { s: noun('missing noun', 'm') });
      eq(Loc.missingList().join('|'), '1× ' + mod + '|1× Not translated.|1× noun: missing noun|1× missing noun');
    }

// German: articles by case and gender, weak nouns, genitive s, feminine forms, names, phrases
  static function german()
    {
      Loc.init('de', haxe.Json.stringify({
        strings: {
          'your host': 'dein Wirt',
          '{attacker:The} tries to stab {target:the}, but misses.': '{attacker:Der} versucht, {target:den} zu erstechen, verfehlt aber.',
        },
        nouns: {
          'police officer': { g: 'm', s: 'Polizist', fs: 'Polizistin', acc: 'Polizisten', dat: 'Polizisten', gen: 'Polizisten' },
          'dog': { g: 'm', s: 'Hund', gen: 'Hundes' },
          'knife': { g: 'n', s: 'Messer' },
          'glass': { g: 'n', s: 'Glas' },
          'keycard': { g: 'f', s: 'Schlüsselkarte' },
          'your host': { g: 'm', s: 'dein Wirt', acc: 'deinen Wirt', dat: 'deinem Wirt', gen: 'deines Wirts' },
          'dead agent': { g: 'm', s: 'toter Agent', forms: { der: 'der tote Agent', ein: 'ein toter Agent' } },
        },
      }));
      eq(Loc.fmt('{s:der}|{s:den}|{s:dem}|{s:des}', { s: noun('police officer', 'm') }),
        'der Polizist|den Polizisten|dem Polizisten|des Polizisten');
      eq(Loc.fmt('{s:Der}|{s:den}|{s:einem}|{s:zum}|{s:vom}', { s: noun('police officer', 'f') }),
        'Die Polizistin|die Polizistin|einer Polizistin|zur Polizistin|von der Polizistin');
      eq(Loc.fmt('{s:ein}|{s:einen}|{s:eines}|{s:beim}', { s: noun('dog', 'n') }), 'ein Hund|einen Hund|eines Hundes|beim Hund');
      eq(Loc.fmt('{s:den}|{s:des}|{s}', { s: noun('knife', 'n') }), 'das Messer|des Messers|Messer');
      eq(Loc.fmt('{s:des}', { s: noun('glass', 'n') }), 'des Glases');
      eq(Loc.fmt('{s:dem}|{s:des}', { s: noun('keycard', 'n') }), 'der Schlüsselkarte|der Schlüsselkarte');
      eq(Loc.fmt('{s:Der}|{s:ein}', { s: noun('dead agent', 'm') }), 'Der tote Agent|ein toter Agent');
      eq(Loc.fmt('{a:des}|{b:des}|{b:zum}', { a: name('Hans', 'm'), b: name('Anna', 'f') }), 'Hans’|Annas|zu Anna');
      eq(Loc.fmt('{p:Der}|{p:dem}|{p:beim}', { p: phrase('your host', 'f') }), 'Dein Wirt|deinem Wirt|bei deinem Wirt');
      eq(Loc.fmt('{s, select, m{er} f{sie} n{es} other{er}}', { s: noun('knife', 'm') }), 'es');
      eq(Loc.fmt(Loc.tr(STAB), {
        attacker: phrase('your host', 'm'),
        target: noun('police officer', 'm'),
      }), 'Dein Wirt versucht, den Polizisten zu erstechen, verfehlt aber.');
    }

// pseudo: letters accented, syntax and markup intact, marked and padded
  static function pseudo()
    {
      Loc.init('pseudo', null);
      var p = Loc.tr('Hello {n} <b class=x>bold</b> &rarr; %name%');
      eq(p.indexOf('{n}') > 0 &&
        p.indexOf('<b class=x>') > 0 &&
        p.indexOf('&rarr;') > 0 &&
        p.indexOf('%name%') > 0 &&
        p.indexOf('Ĥéļļö') == 1 &&
        StringTools.startsWith(p, '⟦') &&
        StringTools.endsWith(p, '~⟧'), true);
      eq(Loc.fmt('{s:The}', { s: phrase('your host', 'm') }).indexOf('⟦Ý'), 0);
      var t = Loc.fmt(Loc.tr('{n, plural, one{# turn} other{# turns}}'), { n: 2 });
      eq(t.indexOf('2 ţûŕñš') > 0, true);
    }

// noun argument helpers
  static function noun(key: String, gender: String): _LocNoun
    {
      return {
        key: key,
        kind: LOC_NOUN,
        gender: gender,
      };
    }

  static function name(key: String, gender: String): _LocNoun
    {
      return {
        key: key,
        kind: LOC_NAME,
        gender: gender,
      };
    }

  static function phrase(key: String, gender: String): _LocNoun
    {
      return {
        key: key,
        kind: LOC_PHRASE,
        gender: gender,
      };
    }

// compare and report
  static function eq(got: Dynamic, want: Dynamic, ?pos: haxe.PosInfos)
    {
      // got/want are strings or bools, compared as such
      if (got == want)
        return;
      fails++;
      out('FAIL line ' + pos.lineNumber + ': got [' + got + '] want [' + want + ']');
    }

// print one line to the node console
  static function out(s: String)
    {
      js.Syntax.code("console.log({0})", s);
    }
}
