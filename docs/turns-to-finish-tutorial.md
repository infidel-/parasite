# Turns to Finish Tutorial

## Measured (headless goal bot, 2026-11-07, v1.1)

Played by the goal bot of the headless tests (`make test args="--suite tutorial --count 40"`, see
`tests/README.md`) on new games, seeds 1-40, normal difficulty rolls. It carries on past the tutorial
into the timeline and the habitat branch:

| goal | reached | turns min / median / max |
|---|---|---|
| `GOAL_INVADE_HUMAN` | 37/40 | 7 / 16 / 33 |
| `GOAL_LEARN_SOCIETY` (the end of the tutorial) | 22/40 (55%) | 68 / 95 / 169 |
| `GOAL_ENTER_SEWERS` | 20/40 | 83 / 115 / 171 |
| `GOAL_TRAVEL_EVENT` (the remembered event area) | 20/40 | 91 / 128 / 173 |
| `GOAL_LEARN_CLUE` | 13/40 | 109 / 185 / 281 |
| `GOAL_LEARN_NPC` | 9/40 | 109 / 287 / 430 |
| `GOAL_EVOLVE_ORGAN` | 22/40 | 47 / 92 / 136 |
| `GOAL_GROW_ORGAN` | 19/40 | 80 / 119 / 250 |
| `GOAL_EVOLVE_MICROHABITAT` | 16/40 | 85 / 147 / 270 |
| `GOAL_CREATE_HABITAT` | 16/40 | 85 / 150 / 274 |
| `GOAL_USE_COMPUTER` | 6/40 | 128 / 328 / 354 |
| `GOAL_PROGRESS_TIMELINE` | 0/40 | |
| `SCENARIO_ALIEN_FIND_SHIP` | 0/40 | |

The bot is no expert. It probes one host until its health is down to 3, then rides it to the next
calm human. It leaves an area at alertness 50, but a city can only be left through the sewer hatch,
which cannot be learned before LEARN_SOCIETY. So most of the seeds it fails on die before that, to
police called by witnesses. Once in the sewers it nearly always finds the event area. Read these
numbers as an upper bound for a cautious player, not the minimum. The estimate below (~40 turns)
assumes fewer host changes than LEARN_SOCIETY took the bot. Past USE_COMPUTER none got a note of
event 11 (PROGRESS_TIMELINE). Clues only lead one event back at a time: the bot goes to the lab that
holds events 12 and 11 and reads its papers, but its guards end the run first. Started at that
point from a fixture, 1 of 30 seeds found the ship all the same, through the agents of events 10-8
(`tests/README.md`, the timeline runs).

## Summary (estimated)

**Minimum turns:** ~35-40 turns  
**Approximate average:** ~40-45 turns  
**Maximum turns:** ~50-60 turns (with host deaths and replacements)

## Tutorial Flow

The tutorial starts with `GOAL_INVADE_HOST` and ends when completing `GOAL_LEARN_SOCIETY` (reaching 25% human society knowledge).

### Key Mechanics

- Each turn the parasite can make **2 actions** (ap = 2)
- After attaching to a host, need to harden grip to 100 before invading
- After invasion, host control starts at 10 and decreases by 1 per turn
- Host energy starts at ~250 (based on strength + constitution) and decreases by 1 per turn
- Evolution costs 5 energy per turn
- Brain probe level 2 is recommended for easier learning (humanSociety multiplier = 1.0)

## Detailed Breakdown

### Phase 1: Invade First Host (GOAL_INVADE_HOST)
- **Actions:** Attach (1) + Harden grip 3-5 times (3-5) + Invade (1)
- **Turns:** 3-4 turns
- **Notes:** Starting attach grip is ~15-25 (based on IMP_ATTACH level 0-3)

### Phase 2: Invade Human Host (GOAL_INVADE_HUMAN)
- **Actions:** Same as Phase 1
- **Turns:** 3-4 turns
- **Notes:** Completed automatically when invading human

### Phase 3: Evolve Brain Probe to Level 1 (GOAL_EVOLVE_PROBE)
- **EP needed:** 100
- **EP per turn:** 10 (base)
- **Time:** 10 turns
- **Energy cost:** 5 per turn (50 total)
- **Control:** Need to reinforce ~1 time during evolution
- **Turns:** ~11 turns (10 + 1 reinforce action)

### Phase 4: Probe Brain (GOAL_PROBE_BRAIN)
- **Actions:** 1 probe action
- **Turns:** 1 turn
- **Notes:** First probe unlocks inventory system

### Phase 5: Learn Item (GOAL_LEARN_ITEMS)
- **Actions:** 1 learn action
- **Turns:** 1 turn
- **Notes:** Unlocks skills system

### Phase 6: Evolve Brain Probe to Level 2 (GOAL_PROBE_BRAIN_ADVANCED)
- **EP needed:** 200
- **EP per turn:** 10
- **Time:** 20 turns
- **Energy cost:** 5 per turn (100 total)
- **Control:** Need to reinforce ~2 times during evolution
- **Turns:** ~22 turns (20 + 2 reinforce actions)
- **Notes:** Level 2 gives humanSociety multiplier = 1.0 (vs 0.5 for level 1)

### Phase 7: Learn Skill (GOAL_LEARN_SKILLS)
- **Actions:** 1 probe action
- **Turns:** 1 turn
- **Notes:** Requires level 2 brain probe

### Phase 8: Learn Society to 25% (GOAL_LEARN_SOCIETY)
- **Knowledge per probe:** 1.0 * host.intellect (level 2 brain probe)
- **Average intellect:** ~10-15
- **Knowledge per probe:** ~10-15%
- **Probes needed:** 2-3 probes
- **Turns:** 2-3 turns
- **Notes:** Each probe costs energy and damages host

## Total Calculation

**Minimum scenario (optimal play):**
- Phases 1-2: 6 turns
- Phase 3: 11 turns
- Phases 4-5: 2 turns
- Phase 6: 22 turns
- Phase 7: 1 turn
- Phase 8: 2 turns
- **Total: ~44 turns**

**Average scenario (with some inefficiency):**
- Phases 1-2: 7 turns
- Phase 3: 11 turns
- Phases 4-5: 2 turns
- Phase 6: 22 turns
- Phase 7: 1 turn
- Phase 8: 3 turns
- **Total: ~46 turns**

**Maximum scenario (host deaths, multiple hosts):**
- May need to replace hosts 1-2 times
- Each replacement adds ~5-10 turns
- **Total: ~55-65 turns**

## Energy and Control Management

### Host Energy
- Starting energy: ~250 (based on strength + constitution)
- Loss per turn: 1 (default) or 5 (during evolution)
- Host dies when energy reaches 0

### Host Control
- Starting control: 10 (HOST_CONTROL_BASE)
- Loss per turn: 1 (unless in habitat or has dopamine/consent)
- Need to reinforce when control < 90
- Reinforce gives: 20-35 control (based on IMP_REINFORCE level)

### Evolution Energy Cost
- Base cost: 5 energy per turn (evolutionEnergyPerTurn)
- During evolution: host loses 5 energy per turn
- Host can survive ~50 turns with evolution active

## Assumptions

1. Player finds hosts quickly (no movement time)
2. Hosts have average stats (strength ~10, constitution ~10, intellect ~10-15)
3. Player uses level 2 brain probe for learning society
4. Player manages control efficiently (reinforces when needed)
5. No host deaths during tutorial (optimistic scenario)
6. All actions are performed optimally

## Code References

- `PlayerArea.hx`: Attach, harden grip, invade mechanics
- `EvolutionManager.hx`: Evolution system (10 EP per turn, costs 100/200 EP)
- `const/EvolutionConst.hx`: Brain probe parameters (humanSociety multipliers)
- `const/Goals.hx`: Tutorial goal chain
- `game/Skills.hx`: Knowledge gain system
- `__Math.hx`: Energy and control calculations
