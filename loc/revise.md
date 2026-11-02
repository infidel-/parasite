# TASK: REVISE THE {LANG} TRANSLATION OF THE GAME "PARASITE"

You review a first-pass translation of a PC game's strings into {LANG}, against the English
source and the style sheet below. You get batches of strings, each with its context line, the
English (`<en>`) and the current translation (`<s id="N">`).

## The game (same as the first pass)

Parasite is a turn-based roguelike with body horror and a dark, dry tone. The player is an alien
parasite that invades human hosts, evolves, builds habitats and finally founds a cult. A secret
organization, the Group, hunts it. The log speaks to the player in the second person. The
parasite's own goal messages are terse first person. Pedia articles are plain explanations. Cult
texts are ritual and grotesque. UI labels are short.

## What to fix

1. **Meaning.** Anything mistranslated, dropped, added or softened.
2. **Terminology.** The style sheet glossary, and consistency across the batch: one English term,
   one {LANG} term.
3. **Grammar with placeholders.**
   - Does the sentence still read correctly for every value a placeholder can take?
   - Are noun forms (`{x:form}`) the ones the style sheet lists, capitalized at the start of a
     sentence?
   - Do participles and adjectives agree with a noun through `{x, select, m{…} f{…} other{…}}`?
   - Are the plural categories right for {LANG}?
4. **Register and voice.**
   - Per the style sheet: the address form, the narrator's tone, the parasite's voice.
   - Labels short.
   - No calques of English word order.
5. **Typography.** The style sheet's rules: spaces, quotes, apostrophes, capitalization of labels.
6. **Markup.** Every `{placeholder}` name, HTML tag, entity and `%token%` of the English kept
   exactly, none added.

Do NOT rewrite what is already right. Taste is not a defect. When a translation is correct, leave
it out of your answer.

## Output — strictly this, nothing outside it

```
<s id="4">corrected translation</s>
<s id="9">corrected translation</s>
<notes>
- [DOUBT] 12 | what stays unclear
- [TERM] English term = {LANG} term (why)
</notes>
```

- Only the strings you change, with their ids. Nothing for a string you keep.
- The `<notes>` block may be empty, but it must be there.
