---
name: report-host-table
description: Use when asked to generate host stats and AI effects tables from AI data and evolution constants, including improvement breakdowns and black ops team-level rows. Do not use for weapons/armor or cult report tasks.
---

# Host Table Report Skill

## Shared rules
Read `.agents/skills/report-common/references/common-notes.md` and follow it.

## Instructions
Use the following prompt:

```md
read src/ai/AIData.hx and src/ai/* classes, src/const/EvolutionConst.hx
read the referenced classes to get min and max strength, constitution, intellect, psyche, energy and life for human hosts.
The numbers format should be `min-max` for ranges.
Black ops agent stats depend on team level, add separate rows for each team level.

Generate a markdown table with the following columns:
- Host Name: The name of the host
- STR: The strength range for the host
- STR_MAX: Absolute strenth maximum with max IMP_MUSCLE bonus
- CON: The constitution range for the host
- INT: The intellect range for the host
- PSY: The psyche range for the host
- ENERGY: The energy range for the host
- ENERGY_MAX: Absolute energy maximum with max IMP_ENERGY bonus
- LIFE: The life range for the host
- LIFE_MAX: Absolute life maximum with max IMP_MUSCLE bonus

Generate additional table with ai effects:
- Effect name: The name of the effect
- Effect description: A brief description of the effect

Generate additional information:
- Put the improvement human-readable name into their section headers in parenthesis.
- IMP_MUSCLE - strength bonuses and life changes for each level.
- IMP_ENERGY - host energy mods for each level

Write the generated response to reports/host.md
```
