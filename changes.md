# Changes

## 1.0.2

### Changes
- art: the sewer summoning portal is 3D — rock pillars, a breathing skin hung between them and a ritual pool, broken into rubble when the ritual ends
- ui: changelog button on the main menu shows what changed in each version, with a glowing dot until the new version's changes are read
- ui: the mouse path shows the energy the move will cost the parasite or host at its end, red when the move would drain it dry

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
