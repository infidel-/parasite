# 3D render changes — running log

Append-only. One entry per experiment, ~25 lines: what changed, the measured numbers, the trap, the
verdict. Settled outcomes only. Every entry needs a matching row in
[`3d-render.md`](3d-render.md)'s verdict table, or it is invisible. Earlier entries are in
`3d-changes-2026-11.md` and its predecessors.

## Cult base: the other ten organs as Meshy 6 cuts (`ObjModel.turns` for the spine turret)

**Changed:** the remaining organs (flesh block, rat nest, crusher, garbage heap, body storage, cauldron,
rib wall, rib gate, spine turret, blood trap) went through the Cor's route. Each source was keyed off
its grey backdrop, re-laid on black and lifted to subject p50 72 (`ref_black.py`), then sent to
`meshy_image_to_3d` with poly_count 100k. That cost $8 for 10 runs, all fired in parallel and all
done in ~10 min. Each run is labelled `cult/base-<name>` in `art/models.json`: the 2x2 organs are cut
to 20,000 tris and the 1x1 ones to 8,000 (a quarter of the screen area), all at tex 1024, error 0.05,
roughness 0.3 and baseColor 0.7 (the rib gate at 0.55).
`ObjModels.cultOrgan()` builds each row: FRONTAL, the Cor's sheen-only `anim`, and for 2x2 organs the
Cor's swell + twist + billow plus `off` [2,2]. The 1x1 bone pieces and the puddle hold still. Their
`_part` keys join the Cor's skip row.

Numbers:
- Meshy returned 790k–1.98M tris per model, each 1 mesh (it ignores poly_count, as with the Cor).
  Albedo luminance was 76–86, against the Cor's 79. Outliers: the rib gate at 103 (bone-heavy, hence
  baseColor 0.55) and the blood trap at 62.
- Heights come from the Cor's ratio of model width to atlas width (8.4 world per 120 px), capped at
  the Cor's 6.2: flesh block 4.3, rat nest 5.8, crusher 5.9, garbage heap 4.8, body storage 6.2
  (capped from 7.9), cauldron 5.1, rib wall 2.6, rib gate 3.2, turret 2.4, trap 1.6.
- Built glbs are 2.8–3.7 MB each.

Traps:
- The body storage's pale hanging bodies sit within 30 of the grey backdrop, so the default key
  (30/50) half-erased them to dark grey. That source keys at 12/18 instead.
- Meshy baked green specks (5.7% of the crusher sheet, mostly in the maw) that the drawing never had.
  `texSrc` is that sheet with hue 60..200 recoloured to dark flesh red at the same luminance.
- The spine turret faces one of four ways. `getModelKey` appends the direction, and one row carries
  `turns` [π, π/2, 0, -π/2], indexed like its keys and added to the yaw in `build()`: one batch for
  all four facings. The Meshy barrel faces +Z (south, toward the camera). Live check: north shows its
  back, east and west point sideways.
- Organs built mid-area appear at once: `buildSelected` → handover rebuild, no reload needed.

**Verdict:** landed. Every organ reads off its drawing. The scale-by-atlas-width rule held live with
no per-organ refit.
