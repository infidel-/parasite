---
name: report-cult-ordeals-table
description: Use when asked to generate markdown tables for cult ordeals from src/cult/ordeals, including communal and profane ordeal requirements. Do not use for cult income or balance calculations.
---

# Cult Ordeals Table Skill

## Shared rules
Read `.agents/skills/report-common/references/common-notes.md` and follow it.

## Instructions
Use the following prompt:

```md
read files in src/cult/ordeals/
Generate two markdown table listing all cult ordeals (one for communal and one for profane) defined in the src/cult/ordeals/ directory. The tables should have the following columns:
- Ordeal Name: The name in the ordeal class
- Required Members: The number of members required to undertake the ordeal and their levels
- Power Requirements: A summary of the power and resource requirements for the ordeal. Money should be on the next line.

Write the generated response to reports/cult-ordeals.md
```
