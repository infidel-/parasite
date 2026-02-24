---
name: report-turns-to-finish-tutorial
description: Use when asked to generate or analyze a report about how many turns are needed to complete the tutorial from GOAL_INVADE_HOST through GOAL_LEARN_SOCIETY. Do not use for other report types.
---

# Tutorial Turns Report Skill

## Shared rules
Read `.agents/skills/report-common/references/common-notes.md` and follow it.

## Instructions
Use the following prompt:

```md
read src/__Math.hx, src/PlayerArea.hx, src/const/Goals.hx, src/const/EvolutionConst.hx

Each turn the parasite can make two actions. Let's assume the player in parasite form has no trouble of finding a host. After attaching to host the parasite need to hardenGrip to 100 until in can invadeHost. After the host is under control, the control will fall each turn making the parasite spend energy to restore it. The host dies after its energy comes down to zero so the player will need to find a new one. Take that into consideration.

All of the tutorial happens in the same area, no exit to region mode. Assume we want a level two brain probe to learn KNOW_SOCIETY easier.

Tutorial starts with the GOAL_INVADE_HOST and ends when completing GOAL_LEARN_SOCIETY. Pick all the goals that are from this tutorial line and check out the code for game.goals.receive/complete(<goal id>) to have an understanding.

Carefully evaluate how many turns does it take for the player to finish the tutorial. Give a mininum and approximate numbers first, then full explanation on how you came to these results. Write the generated response to reports/turns-to-finish-tutorial.md
```
