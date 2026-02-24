---
name: report-weapons-and-armor
description: Use when asked to generate weapon and armor markdown tables from ItemsConst and referenced classes, including stats and special properties. Do not use for host or cult reports.
---

# Weapons And Armor Report Skill

## Shared rules
Read `.agents/skills/report-common/references/common-notes.md` and follow it.

## Instructions
Use the following prompt:

```md
read src/const/ItemsConst.hx
read the referenced classes to get weapon min and max damage, armor protection and generate two markdown tables (one for weapon and one for armor) with the following columns:
- Item Name: The name of the item
- Damage (for weapons) or Protection (for armor): The damage range for weapons and protection value for armor
- Special Properties: Any special properties or effects the item has, such as elemental damage, status effects, or unique abilities.

Write the generated response to reports/weapons-and-armor.md
```
