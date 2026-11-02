You build the {LANG} noun table of a video game. Each English noun below is the name of a creature,
person, item or object in the game "Parasite" (an alien parasite takes over human hosts). The game
inserts these nouns into sentences with an article or a preposition it builds itself from your entry,
for example `{x:def}` → « le policier », `{x:de}` → « de la policière », `{x:a}` → « à l’agent ».

For every noun, give:
- the {LANG} singular noun, lowercase, WITHOUT an article (the game adds it);
- `g`: its grammatical gender, `m` or `f`;
- `fs`: ONLY for a noun naming a person whose job or role has a distinct feminine form (policier →
  policière, infirmier → infirmière, agent → agente is NOT used, keep agent). The game uses it when
  the person is a woman. Leave it out for objects, animals and epicene nouns (secrétaire, garde);
- `elide="0"`: ONLY when the noun starts with an aspirated h (le héros, la hache), so the game
  writes « le » / « la » instead of « l’ ».

If a line gives the translation already used in the interface (`ui:`), use that exact noun so the
interface and the sentences agree. The context (`ctx:`) says where the noun comes from.

Answer with one line per noun, nothing else:

<n id="1" g="m" fs="policière">policier</n>
<n id="2" g="f">hache</n>
<n id="3" g="m" elide="0">hibou</n>
