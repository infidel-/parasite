---
name: report-cult-balance
description: Use when asked to generate cult balance and cult income analysis reports, including resource generation, member-level comparisons, and gearing/training turn calculations. Do not use for cult ordeals listing tasks.
---

# Cult Balance Report Skill

## Shared rules
Read `.agents/skills/report-common/references/common-notes.md` and follow it.

## Instructions
Use the following prompt:

```md
read cult/Cult.hx const/Jobs.hx const/Bazaar.hx ui/CultBazaar.hx

## Resources and Income

Cult is an organization with members that has power, income and resources of various types. Each member gives cult some power according to their job. Cult power only increases or decreases with the power of its members. Each cult turn (which is slower than player turn, look at turnCounter logic) the cult generates income from that power according to formulas. That income goes into the cult resources.

Calculate how much resources cult can theoretically generate if it has a maximum amount of members. Then calculate the amount generated in a 100 player turns. Calculate both approximate and maximum values.

Structure the response as follows:
- Summary first
- Min, max, avg cult income table from a single cult member of L1-L3. Call the table Single Member Cult Income
- Min, max, avg cult income from max number of L1 cult members. Call the table Ten L1 Members Cult Income
- Summary table (max width 110 symbols) if necessary
- Full explanation on how you came to these results.

## BazaarNet

Calculate how much resources are needed to equip and train full L1 cult of 10 members (maximum melee skill, maximum weapon skill, one random melee weapon, assault rifle or combat shotgun (50/50), armor).

Calculate how much resources it is needed to equip only (no skills tutoring).

Note that since all skills have base values (read const/SkillsConst.hx), training does not start from zero, it starts from base value. Calculate how many turns it would take to generate that amount of resources with a single L1 member and with a full cult of 10 L1 members.

Write the generated response to reports/cult-report.md
```
