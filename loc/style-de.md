# STYLE SHEET — GERMAN (de)

Register („du“) confirmed by the developer. The glossary is corrected by hand after review.

## Register and voice

- **The player is addressed with „du“** everywhere: log, interface, pedia, popups. Never „Sie“
  for the player. du/dich/dir/dein are written lowercase.
  "You slither through the drain." → „Du schlüpfst durch den Abfluss.“
  Instructions as du-imperatives: „Wähle“, „Drücke“.
- **The parasite's goal messages** (first person, `const/Goals`, `messageComplete` and so on) stay
  in short, cold, practical first-person sentences. Use „ich“. No exclamations, no softening.
  „Dieser Wirt ist unruhig, ich muss fliehen, um Ärger zu vermeiden.“
- **Log lines:** present tense, compact, neutral. The game reports facts.
- **Pedia:** plain, explanatory German, du.
- **Cult texts** (`cult/events`, ordeals): ritual and grotesque, biological imagery. Keep the
  rhythm, use precise anatomical words, no slang.
- **UI labels and buttons:** infinitive or noun phrase, short, sentence case (nouns capitalized as
  German grammar wants, other words lowercase): „Musiklautstärke“, „Bildrate anzeigen“. Prefer
  compounds to genitive chains. Stay within about 130 % of the English length.

## Typography

- German quotation marks: „so“ (low-high). Nested: ‚so‘.
- No space before `:` `;` `!` `?`.
- Use `…` (one character) for ellipses.
- ß as in Germany (not Swiss spelling).
- English loanwords in compounds take a hyphen: „Blackops-Agent“, „BazaarNet-Konto“.
- Numbers: a plain number, as in the English.
- ALL CAPS stays ALL CAPS („EVOLUTION“); ß in caps is „SS“.

## Noun forms in placeholders

A `{x:form}` placeholder is a noun (person, item, object). The game builds the article AND the case
ending of the noun for you (den Polizisten, des Hundes), so NEVER write „der“, „die“, „das“, „ein“,
„einen“, „dem“, „zum“ … before a noun placeholder. Pick the form by the case the sentence needs:

| form | case | gives (m / f / n) |
|---|---|---|
| `{x:der}` | nominative, definite | der Polizist / die Polizistin / das Messer |
| `{x:den}` | accusative, definite | den Polizisten / die Polizistin / das Messer |
| `{x:dem}` | dative, definite | dem Polizisten / der Polizistin / dem Messer |
| `{x:des}` | genitive, definite | des Polizisten / der Polizistin / des Messers |
| `{x:ein}` | nominative, indefinite | ein Polizist / eine Polizistin / ein Messer |
| `{x:einen}` | accusative, indefinite | einen Polizisten / eine Polizistin / ein Messer |
| `{x:einem}` | dative, indefinite | einem Polizisten / einer Polizistin / einem Messer |
| `{x:eines}` | genitive, indefinite | eines Polizisten / einer Polizistin / eines Messers |
| `{x:zum}` | zu + dative | zum Polizisten / zur Polizistin / zum Messer |
| `{x:vom}` | von + dative | vom Polizisten / von der Polizistin / vom Messer |
| `{x:beim}` | bei + dative | beim Polizisten / bei der Polizistin / beim Messer |
| `{x}` | bare, nominative | Polizist |

- The form names are the masculine article of the case; the game swaps in die/das/der/eine… for a
  feminine or neuter noun. Other prepositions take the case form: „mit {x:dem}“, „auf {x:den}“,
  „für {x:einen}“.
- An English placeholder with no form can still be a noun: when its value is an item, an object, a
  person or a cult (the context says), give it the case form German needs:
  `You find {item} in {obj:the}.` → `Du findest {item:einen} in {obj:dem}.` On a plain value (an
  effect name, a sum, a number) a form does nothing: write the sentence so it needs no article there.
- Capitalize the form name at the start of a sentence: `{x:Der} zögert, dich anzugreifen.` →
  „Der Soldat zögert…“, „Die Polizistin zögert…“. `{x:Ein}` gives „Ein Soldat…“.
- People's names and phrases such as „dein Wirt“ never get an article, but the form still picks the
  case: `{x:den}` gives „Anna“ or „deinen Wirt“, `{x:des}` gives „Annas“ or „deines Wirts“,
  `{x:zum}` gives „zu Anna“. The forms above stay correct for every value.
- English `{x:The}` as subject → `{x:Der}`; `{x:the}` as object → `{x:den}` or `{x:dem}` as the verb
  or preposition governs; `{x:a}`/`{x:A}` → `{x:ein}`/`{x:einen}`/`{x:einem}` and capitalized.
  Never keep an English form.
- Never put an adjective or a determiner of your own between the article and the noun
  („der tote {x}“ is impossible): rephrase („{x:der}, jetzt tot,“ or a relative clause).
- Agreement: predicative adjectives and participles do not change in German, so they need no
  select. Pronouns, possessives and relative pronouns that refer to the noun go in a select on that
  same placeholder; the gender is the grammatical one (`n` exists):
  `{x, select, m{er} f{sie} n{es} other{er}}`, `{x, select, m{sein} f{ihr} n{sein} other{sein}}`
  (the possessive still takes its own ending: „seinen“, „ihrem“).

## Plurals

German categories are `one` (1) and `other`: `{n, plural, one{# Runde} other{# Runden}}`.
Write both cases, even where the English only needs `other`.

## Glossary (game terms)

| English | German | note |
|---|---|---|
| parasite | Parasit (m) | |
| host | Wirt (m) | the biological term, for a man or a woman alike; „dein Wirt“ for the player's host; never „Wirtin“ (innkeeper) |
| invade (a host) | befallen | „einen Wirt befallen“ |
| affinity | Affinität | |
| consent | Zustimmung | |
| assimilation | Assimilation | |
| expiry (host expiring) | Verfall / der Wirt verfällt | the host is used up |
| energy | Energie | |
| evolution | Evolution | |
| improvement (evolution) | Verbesserung | |
| organ | Organ | |
| body features | Körpermerkmale | |
| brain probe | Hirnsondierung | verb „das Gehirn sondieren“ |
| engram | Engramm | |
| clue | Hinweis | |
| habitat | Habitat (n) | |
| microhabitat | Mikrohabitat | |
| assimilation cavity | Assimilationshöhle | |
| biomineral (formation) | Biomineral(formation) | |
| preservator | Präservator | |
| watcher | Wächter | |
| ovum | Ovum | Latin, kept |
| parthenogenesis | Parthenogenese | |
| the Group | die Gruppe | the secret organization |
| team (Group agents) | Team (n) | |
| alertness | Wachsamkeit | how alert NPCs are |
| area | Gebiet | |
| region | Region | |
| sewers | Kanalisation | |
| event timeline | Ereigniszeitleiste | |
| conversation / chat | Gespräch | |
| follower (cult) | Anhänger / Anhängerin | |
| cult | Kult (m) | |
| ordeal | Prüfung | „gemeinschaftliche Prüfung“, „profane Prüfung“ |
| combat mission | Kampfeinsatz | |
| power / resources (cult) | Macht / Ressourcen | |
| combat / media / lawfare / corporate / political (resource kinds) | Kampf / Medien / Justiz / Wirtschaft / Politik | |
| BazaarNet | BazaarNet | brand, kept |
| occasio | occasio | Latin, kept |
| pseudocampus | pseudocampus | Latin-like organ name, kept |
| false memories | falsche Erinnerungen | |
| Spoon mode / Sandbox mode | Spoon-Modus / Sandbox-Modus | |
| goal | Ziel | |
| HUD | HUD (n) | |
| grip (on a host) | Griff | |
| habitat growth | Habitatwucherung | |
| striker (cult rank) | Angreifer / Angreiferin | |
| growth points | Wachstumspunkte | |
| slot (body feature) | Platz | |
| job (host) | Beruf | |
| Strength / Constitution / Intellect / Psyche | Stärke / Konstitution / Intellekt / Psyche | host attributes |
| trait / attribute / effect / skill | Eigenschaft / Attribut / Effekt / Fertigkeit | |
| log | Protokoll | the message log |
| pedia | Enzyklopädie | |

Keep in Latin, exactly: Cultus Carnis, Carnis Chorus, Uterus Susurro, Sudor Sigillum, Viscus
Evangelium, Vena Arcanum, Lingua Mare, Os Nativitas, Ora Mens, Massa Liturgia, Carnis Speculum, Cor
Nefandum and every other Latin cult or organ name.
