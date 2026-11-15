# Forma worker log

One entry per iteration: phase, files, what changed, `make` result. Newest last.

## Phase 1: one refusal function per action
- Files: `src/cult/base/CultBase.hx`, `src/const/CultBaseConst.hx`.
- `validateUpgrade(organ)`, `validateRepair(organ)`, `validateCustos(x, y)` return '' or the existing `T()` reason; `upgradeAtCursor`, `repairAtCursor`, `createCustos` call them then `game.actionFailed(reason)`. "No base organ at cursor." stays in the `*AtCursor` functions. Same check order as before.
- `CultBaseConst.custosCost` (10/8/0) used by `validateCustos` and `createCustos`.
- `custosCap()` is public.
- `incomePerTurn(): CultBaseIncome` (typedef `{ income, bodies }` at the top of CultBase.hx) is pure: body draws run on a local copy of `storedBodies`. `turn()` sets `income = res.income` and `storedBodies -= res.bodies`; per-organ numbers unchanged.
- `CultBaseOrganInfo` gained `shortName` and `desc` (`N()` strings, the preview's `does` lines; Murus/Porta/Turris short names, full name for the rest).
- Note: `meta()` already took 9 positional args. Not converted to an Opts typedef (would be a new file outside the phase list); `info()` fills the two new fields through a small `text(meta(...), shortName, desc)` helper instead. Controller to decide if an Opts typedef is wanted.
- Build: `cd src && make` passes; quick tests 54 runs, 0 failed; loc check +14 strings.
- Review fix: `text(data, desc, ?shortName)`; `shortName` overrides the `meta()` default (the name) only for Murus/Porta/Turris. Build: `cd src && make` passes.
