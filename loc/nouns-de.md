You build the {LANG} noun table of a video game. Each English noun below is the name of a creature,
person, item or object in the game "Parasite" (an alien parasite takes over human hosts). The game
inserts these nouns into sentences with an article and a case ending it builds itself from your
entry, for example `{x:der}` → „der Polizist“, `{x:den}` → „den Polizisten“, `{x:einem}` → „einer
Polizistin“, `{x:des}` → „des Messers“.

For every noun, give:
- the {LANG} singular noun in the nominative, capitalized as German nouns are, WITHOUT an article
  (the game adds it). Prefer one word or a compound (Sturmgewehr, Blackops-Agent) to an adjective
  and a noun, and a real noun to a nominalized adjective (Mitarbeiter rather than Angestellter);
- `g`: its grammatical gender, `m`, `f` or `n`;
- `fs`: for EVERY noun naming a person (a job, a rank, a role, a kind of person): the form for a
  woman, which the game uses when the person is one (Polizist → Polizistin, Agent → Agentin, Soldat
  → Soldatin, Wachmann → Wachfrau). Leave it out for objects and animals, and for a noun whose
  gender stays the same whoever it names (die Geisel, das Opfer, der Wirt);
- `acc`, `dat`, `gen`: the noun's own accusative, dative and genitive singular, ONLY where they are
  not the plain rule. The rule is: masculine and neuter add -s in the genitive (-es after s, ß, x, z),
  everything else stays as the nominative. So give all three for a weak masculine noun (Polizist →
  Polizisten, Soldat → Soldaten, Agent → Agenten, Mensch → Menschen, Herr → Herrn), and only `gen`
  where you want -es or an irregular genitive (Hund → Hundes);
- when the noun has an adjective in it that cannot be avoided (or is a nominalized adjective), give
  instead every article form whole, as attributes: `der`, `den`, `dem`, `des`, `ein`, `einen`,
  `einem`, `eines`, `zum`, `vom`, `beim`.

Phrases that take no article (`your host`, `you`) are given the same way, lowercase as in running
text, with their `acc`, `dat`, `gen` (dein Wirt → deinen Wirt / deinem Wirt / deines Wirts; du →
dich / dir / deiner).

If a line gives the translation already used in the interface (`ui:`), use that exact noun so the
interface and the sentences agree. The context (`ctx:`) says where the noun comes from.

Answer with one line per noun, nothing else:

<n id="1" g="m" fs="Polizistin" acc="Polizisten" dat="Polizisten" gen="Polizisten">Polizist</n>
<n id="2" g="n">Messer</n>
<n id="3" g="m" gen="Hundes">Hund</n>
<n id="4" g="f">Schlüsselkarte</n>
<n id="5" g="m" der="der Tote" den="den Toten" dem="dem Toten" des="des Toten" ein="ein Toter" einen="einen Toten" einem="einem Toten" eines="eines Toten" zum="zum Toten" vom="vom Toten" beim="beim Toten">Toter</n>
<n id="6" g="m" acc="deinen Wirt" dat="deinem Wirt" gen="deines Wirts">dein Wirt</n>
