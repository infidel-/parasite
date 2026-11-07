# Changes

## 1.1.1

### Changes
- console: `bot` lets a test bot play the game (debug build)

### Fixes
- cult: an Elevate the faithful that fails on its target's death no longer names it "null"
- game: a host whose attributes drop no longer keeps energy above its new maximum
- game: a load no longer lets a new ovum or mission NPC take an id already in use
- game: a parasite with no host walking into a locked door no longer crashes
- game: a resisting host boxed in by walls or followers no longer crashes the game
- game: a save no longer stores habitat formation messages in the player's language
- game: an organ gives its strength, energy or health bonus only once it is grown
- mods: a mod weapon missing some of its attack texts no longer crashes the attack

## 1.1

### Changes
- mods: mods can ship translations (lang/<code>.json) and translate their text through l10n.Loc
- ui: French translation, and a language option in Options (Interface)
- ui: Cyrillic, Chinese, Japanese and Korean text shows in a sans face sized to match the chosen font

### Fixes
- cult: a member death fails only the ordeals that member takes part in
- cult: a Stakeholder Flesh log line named the wrong choice
- game: a dog host's bark costs its energy and a turn, and barks when repeated
- game: a host that dies on the region map (ovum, expiry) now leaves the cult and counts as a Group death
- game: ship parts left behind or dropped no longer vanish, and lost ones reappear in the lab
- ui: an action key pressed twice quickly no longer crashes when the first press loses the host
- ui: log lines read "1 turn" / "5 resources", use "a"/"an" correctly and no longer end in a double full stop

## 1.0.2

### Changes
- art: -redacted- in the sewers cult mission is now 3D 
- audio: -redacted- ai and mission sounds
- ui: changelog button on the main menu shows what changed in each version
- ui: the mouse path shows the energy the move will cost the parasite or host at its end

### Fixes
- ai: a body already reported is not reported again by every passer-by
- ai: an alerted team member calls for backup once, not again every time it loses and re-finds its target
- ai: fights between NPCs no longer close the team distance — calls about them only bring the police, and undercover team members stay out of them and do not report them or the bodies they leave
- ai: NPCs caught up in a fight leave a host standing nearby alone
- game: hosts given false memories by the pseudocampus are never reported to the Group, and the pseudocampus organ no longer counts as a body anomaly

## 1.0.1

### Changes
- boot: borderless fullscreen is picked at launch instead of chromium fullscreen, F11 dropped
- game: full affinity host death costs 5 max energy only on Normal/Hard conversation difficulty, the same in every death path

### Fixes
- game: custom difficulty presets read their settings instead of falling back to Easy
