# STYLE SHEET — FRENCH (fr)

Draft for the probe: the register, the voice and the glossary below are to be confirmed or
corrected by the developer after reading the probe output.

## Register and voice

- **The player is addressed with « vous »** everywhere: log, interface, pedia, popups.
  "You slither through the drain." → « Vous vous glissez dans la canalisation. »
- **The parasite's goal messages** (first person, `const/Goals`, `messageComplete` and so on) stay
  in short, cold, practical first-person sentences. Use « je ». No exclamations, no softening.
  « Cet hôte est agité, je dois fuir pour éviter les ennuis. »
- **Log lines:** present tense, compact, neutral. The game reports facts.
- **Pedia:** plain, explanatory French, vous.
- **Cult texts** (`cult/events`, ordeals): ritual and grotesque, biological imagery. Keep the
  rhythm, use precise anatomical words, no slang.
- **UI labels and buttons:** infinitive or noun phrase, short, sentence case (capital on the first
  word only: « Volume de la musique », « Afficher le compteur d’images »). Stay within about 130 %
  of the English length.

## Typography

- Put a plain space before `:` `;` `!` `?` and inside « guillemets » (« comme ceci »). The build
  turns these spaces into non-breaking ones; just write the space.
- Apostrophe: `’` (typographic) is preferred. `'` is accepted; the build normalizes it.
- Use « … » for quotations, not "…".
- Use `…` (one character) for ellipses.
- Numbers: a plain number, as in the English.
- ALL CAPS stays ALL CAPS, and keeps its accents (« ÉVOLUTION »).

## Noun forms in placeholders

A `{x:form}` placeholder is a noun (person, item, object). The game builds the article for you, so
NEVER write « le », « la », « l’ », « un », « du », « au » before a noun placeholder. Pick the form:

| form | gives | English equivalent |
|---|---|---|
| `{x:def}` | le soldat / la secrétaire / l’agent | the |
| `{x:indef}` | un soldat / une secrétaire | a |
| `{x:de}` | du soldat / de la secrétaire / de l’agent / de Marc / d’Alice | of the / from the |
| `{x:a}` | au soldat / à la secrétaire / à l’agent / à Marc | to the |
| `{x}` | soldat (bare) | bare noun |

- Capitalize the form name at the start of a sentence: `{x:Def} hésite à vous attaquer.` →
  « Le soldat hésite… ». `{x:Indef}` gives « Un soldat… ».
- People's names and phrases such as « votre hôte » never get an article: `{x:def}` gives just
  « Marc » or « votre hôte ». The forms above stay correct for every case.
- English `{x:The}` → French `{x:Def}`, `{x:the}` → `{x:def}`, `{x:a}`/`{x:A}` → `{x:indef}`/`{x:Indef}`.
- Agreement: anything that agrees with the noun goes in a select on that same placeholder:
  `{x:Def} est {x, select, f{blessée} other{blessé}}.` Pronouns too:
  `{x, select, f{elle} other{il}}`.

## Plurals

French categories are `one` (0 and 1) and `other`: `{n, plural, one{# tour} other{# tours}}`.
Write both cases, even where the English only needs `other`.

## Glossary (game terms)

| English | French | note |
|---|---|---|
| parasite | parasite (m) | |
| host | hôte (m) | « votre hôte » for the player's host |
| invade (a host) | envahir | |
| affinity | affinité | |
| consent | consentement | |
| assimilation | assimilation | |
| expiry (host expiring) | dépérissement / l’hôte dépérit | the host is used up |
| energy | énergie | |
| evolution | évolution | |
| improvement (evolution) | amélioration | |
| organ | organe | |
| body features | caractéristiques corporelles | |
| brain probe | sonde cérébrale | |
| engram | engramme | |
| clue | indice | |
| habitat | habitat | |
| microhabitat | microhabitat | |
| assimilation cavity | cavité d’assimilation | |
| biomineral (formation) | (formation) biominérale | |
| preservator | préservateur | |
| watcher | veilleur | |
| ovum | ovum | Latin, kept |
| parthenogenesis | parthénogenèse | |
| the Group | le Groupe | the secret organization; capital G |
| team (Group agents) | équipe | |
| alertness | vigilance | how alert NPCs are |
| area | zone | |
| region | région | |
| sewers | égouts | |
| event timeline | chronologie des événements | |
| conversation / chat | conversation | |
| follower (cult) | fidèle | |
| cult | culte | |
| ordeal | épreuve | « épreuve communale », « épreuve profane » |
| combat mission | mission de combat | |
| power / resources (cult) | pouvoir / ressources | |
| combat / media / lawfare / corporate / political (resource kinds) | combat / médias / guérilla judiciaire / entreprise / politique | |
| BazaarNet | BazaarNet | brand, kept |
| occasio | occasio | Latin, kept |
| pseudocampus | pseudocampus | Latin-like organ name, kept |
| false memories | faux souvenirs | |
| Spoon mode / Sandbox mode | mode Spoon / mode bac à sable | |
| goal | objectif | |
| log | journal | the message log |
| pedia | encyclopédie | |

Keep in Latin, exactly: Cultus Carnis, Carnis Chorus, Uterus Susurro, Sudor Sigillum, Viscus
Evangelium, Vena Arcanum, Lingua Mare, Os Nativitas, Ora Mens, Massa Liturgia, Carnis Speculum, Cor
Nefandum and every other Latin cult or organ name.
