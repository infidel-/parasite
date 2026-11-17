# Changes

## 1.2

### Changes
- art: cult base buildings are now 3D
- art: the cult base grows flesh and pulsing vessels across its habitat floor
- art: a habitat turns a cult pink once its base starts
- cult: a level 2 cult holds 15 members, up to 5 at level 2 and 2 at level 3
- cult: a member's death fails any ordeal it is locked in, profane ones too
- cult: base walls and gates can run north-south as well as east-west
- cult: the Metamorphosis ordeals are open again
- game: a parasite reborn after its final habitat shock leaves its host behind
- game: the host's status effects keep running on the region map
- mods: `ai:die-region` event when the host dies on the region map
- ui: [beta] German translation
- ui: Forma has its own build screen

### Fixes
- boot: a damaged language file starts the game in English instead of not at all
- cult: a base defense whose attackers vanished without dying sends a fresh wave instead of never ending
- cult: a cult destroyed during a base defense no longer freezes the base and the team attacking it
- cult: a Kill or Persuade target no longer wanders off and returns elsewhere
- cult: base organ actions are listed once, not once per tile of a large organ
- cult: a load no longer lets a new cult mission take an id already in use
- cult: a mission target keeps its marker after a load
- cult: a profane ordeal running out of time no longer makes the next ordeal skip its turn
- cult: a summoned cultist taken over by the parasite grows organs on its own body
- cult: a team ambush set before the base grew no longer burns the base habitat
- cult: custodes no longer keep the player inside the base habitat
- cult: the second metamorphosis performed outside a habitat is refused instead of used up
- game: a despawned AI no longer stays the attack target
- game: a former NPC host reported dead after getting away stays dead
- game: a host grown into a habitat organ no longer comes back as its NPC
- game: a parasite attached to a host that gets killed falls off instead of crashing the invade
- game: a parasite with no host on a spaceship slot no longer crashes
- game: a save made on the region map keeps the host's organ growing
- game: a save that fails to load returns to the main menu instead of a broken game
- game: a second new game in one session starts its log at turn 0
- game: an NPC host walking back into its own area no longer spawns a second copy of that NPC
- game: an old save's never-visited city area is built at full size
- game: loading or restarting during a habitat ambush no longer burns the habitat
- game: sex workers and blackops agents spawn with their own stats, not ones a load later changes
- game: stepping off a host into a wall no longer crashes the next action
- game: the corp mission target can be placed in any office, not only the left part of the area
- mods: a mod weapon missing some of its attack texts no longer crashes the attack
- ui: alien ship part names take the right article in log lines
- ui: Ballistospores shows its paralysis time instead of a panic time
- ui: German and French translation fixes
- ui: news of what became of a former host is translated
- ui: one missing system font no longer stops the other fallback fonts from scaling
- ui: save slot labels show the area in the current language
- ui: the language switch no longer promises an autosave in chat or a mission area
- ui: the pedia no longer says a beaten habitat ambush still burns the habitat

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

## 1.1

### Changes
- mods: mods can ship translations (lang/<code>.json) and translate their text through l10n.Loc
- ui: [beta] French translation, and a language option in Options (Interface)
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
