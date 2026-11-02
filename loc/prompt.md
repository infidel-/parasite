# TASK: TRANSLATE THE GAME "PARASITE" FROM ENGLISH INTO {LANG}

You translate the user-interface and narrative strings of a released PC game into {LANG}. The
strings come in batches, grouped by the source file they live in, each with a context line. The
style sheet for {LANG} follows these rules and has the final word on terminology and register.

## The game

Parasite is a turn-based roguelike with body horror and a dark, dry tone. The player is an alien
parasite that crash-landed on Earth. It survives by invading human hosts, controlling their bodies,
draining them and moving on. It evolves organs and abilities, learns about human society through
its hosts' brains, and builds habitats in the sewers. A secret organization, the Group, hunts it
with teams of agents. Later, the parasite founds a cult of human followers who perform ordeals,
missions and rituals in its name.

- The log narrates to the player in the second person ("You slither through the drain.").
- The parasite's own voice in goal messages is first person: terse, alien, pragmatic ("This host
  is agitated, I need to flee to avoid trouble.").
- Pedia articles explain mechanics plainly. Cult texts are ritual, grotesque and liturgical.
- UI labels are short. Keep them short.

## Context line

`[N] file:line · Class.member · in <field or call> · vars: <placeholders> · <hints> · note: <…>`

- The file and class tell you where the string is shown. `ui/` is an interface window, `cult/` is
  cult content, `const/PediaConst` is an encyclopedia article, `const/Goals` is a goal, and so on.
- The field tells you what it is: `name`, `note`, `title`, `button`, `text`, `addCard` (a settings
  card heading), `addOptToggle` (a settings label), `actionFailed` (a refusal shown in the log),
  `message*` (a popup) and so on.
- "stored name" means the string is a noun shown alone (a label, a list) and is also used as a noun
  inside other sentences. Translate it as a bare noun in the base form (no article, singular
  nominative), unless it is a sentence.
- A `note:` is from the developer. Follow it.

## Placeholders, markup, tokens — never break them

- `{name}` and `{name:form}` are values inserted at runtime. Keep every placeholder name exactly
  (same spelling, same count). You may and should move them to where {LANG} grammar wants them.
- `{name:form}`: the value is a noun (a person, an item, an object). The form after the colon picks
  its article or case. The English forms are `the`, `The`, `a`, `A`. Replace them with the {LANG}
  forms listed in the style sheet. A capitalized form name capitalizes the result: use it at the
  start of a sentence.
- `{n, plural, one{# turn} other{# turns}}` is a plural. Keep the structure, write the case bodies
  in {LANG}, and use exactly the plural categories {LANG} needs (see the style sheet). `#` is the
  number. An `=0{…}` exact case may stay.
- `{x, select, m{…} f{…} other{…}}` chooses by the grammatical gender of noun `x` (or by a string
  value). Use it whenever {LANG} grammar has to agree with a noun: past participles, adjectives,
  pronouns.
- Keep HTML tags exactly as they are: `<b>`, `<br/>`, `<span class=…>`, `<p>`, `<ul><li>`. Translate
  the text between them, not inside them. Keep entities (`&rarr;`, `&#127282;`) and `%tokens%`
  exactly.
- Never add a placeholder, tag or token that the English does not have.

## Names and terms

- Character, place, organization and brand names that are made up stay as they are unless the
  style sheet says otherwise.
- The cult's Latin terms (Cultus Carnis, Vena Arcanum, Carnis Chorus, Os Nativitas, Cor Nefandum,
  …) stay in Latin, exactly as written.
- Game terms follow the style sheet glossary. One English term is always the same {LANG} term.
- Keep text in ALL CAPS in ALL CAPS.

## Output — strictly this, nothing outside it

```
<s id="1">translation</s>
<s id="2">translation</s>
…
<notes>
- [DOUBT] 7 | what is unclear and what you chose
- [TERM] English term = {LANG} term (why)
</notes>
```

- One `<s id="N">` for every string in the batch, in order, same ids. A string may span lines.
- `[DOUBT]`: only when the context really leaves the meaning open. `[TERM]`: a game term you had to
  coin and the glossary lacks. The `<notes>` block may be empty, but it must be there.
