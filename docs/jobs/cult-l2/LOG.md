# Cult L2 worker log

One entry per iteration: phase, files, what changed, `make` result. Newest last.

## P1: unblock, save hygiene, L2 limits
- Files: `src/cult/ordeals/MetamorphosisPhaseI.hx`, `src/cult/base/CultBase.hx`, `src/cult/Cult.hx`,
  `src/console/Cult.hx`, `src/console/ConsoleCompletion.hx`.
- Phase I `initiateAction`: removed the 0.22 disable + `return`.
- `CultBase._ignoredFields`: + `income`, `cursorX`, `cursorY`, `selectedType`, `selectedDirection`. `init()`
  defaults them; the only readers are Forma build/tend actions, and `PlayerArea.hx` ~416 sets the cursor on entry.
- `Cult.maxSize()` / `getLevelLimit()`: level 2 → cap 15, L1 15, L2 5, L3 2 (level 1 unchanged).
- Console `cu meta 1|2`: handler `metamorphosis()` (needs an active cult; `1` sets `metamorphosisPhaseIComplete`;
  `2` refused when a base exists, else pushes a `MetamorphosisPhaseII` ordeal and runs its Perform action `f()`,
  which refuses outside a habitat and keeps the ordeal), help line, completion node `meta` + `[phase]` slot.
- Build: `cd src && make` passes (58 quick runs, 0 failed; loc-test ok). The `fr unreadable` line in loc-test
  predates this phase (`electron/lang/fr.json` JSON error), not touched.
- New math: none (only limit constants).
- P1 fix (controller review): `console/Cult.hx` `metamorphosis()`: when the Perform is refused (`cult.base == null`
  after `f()`), the ordeal is removed from `cult.ordeals.list` and `recalc()` runs, so repeats don't stack. A
  successful Perform already removes it (`Ordeals.success` → `list.remove`); members are locked only through the
  ordeal list, so removal frees them. Build: `cd src && make` passes (58 runs, 0 failed).
