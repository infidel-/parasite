# Code review — silent scream (7137275) + uncommitted tactical view

Scope: `git diff HEAD~1` (committed 3D silent scream work) + uncommitted work tree (CameraRig, Occlusion, StreetView, HUD, new TacticalGrid.hx). 10 finder angles, ~35 candidates, each verified. Ranked most-severe first.

Refuted during verification (not bugs): `host.entity` null deref in the new TARGET_PLAYER switches (state/host transition ordering makes it impossible), scream shaking the wrong player entity (host is shaken via the AI loop; player block only touches the hidden parasite), Occlusion `isSelected` out-of-bounds (CityGen SETBACK bounds all footprints), one-frame camera-matrix lag in Shockwave (Models.cull refreshes matrixWorldInverse first).

## Bugs

### 1. Tactical toggle during exit outro kills teardown — `src/render/StreetView.hx:118`
`toggleTactical()` guards only `!running`, not `exiting`. During the area-exit outro (exiting=true, running=true) pressing Space passes HUD.toggle's running-only gate and calls `rig.setTactical(true)`, which nulls `zt`/`ztDone` (CameraRig.hx:162-163) — the sole, fallback-free driver of `onOutroDone` → `teardown()`. The street view renders forever and `running` stays true.

### 2. HUD visibility / tactical flag desync — `src/ui/HUD.hx:313`
`HUD.toggle()` couples HUD visibility with `city3d.toggleTactical()`, but `UI.set_state` calls `hud.show()`/`hide()` without touching tactical. Tactical on (HUD hidden) → open+close main menu: `set_state(DEFAULT)` calls `hud.show()` (UI.hx:782), tactical stays ON — HUD sits over the top-down view; the next Space flips both together, permanently inverted. `StreetView.hide()` similarly exits tactical without restoring the HUD.

### 3. Player state change during tactical swallowed → stale zoom — `src/render/CameraRig.hx:203`
`update()` gates the zoom retarget on `!tactical` but still advances `lastState`; `setTactical(false)` restores the zoomTarget saved at entry. Enter tactical as host, host dies during tactical, exit: restores stale hostZoom, `st != lastState` never re-fires — camera stuck pulled-out for the parasite until the next state change.

### 4. Live scream freezes through exit outro — `src/render/StreetView.hx:770`
The exiting branch skips `actors.update()`/`shockwave.update()` but keeps `composer.render()`. A scream live at exit leaves `shockwave.pass` enabled with frozen uniforms and the dome mesh un-ticked in actorGroup — frozen distorted ripple + static dome over the entire outro.

### 5. Tactical camera orbits/drifts — `src/render/CameraRig.hx:198`
sideAngle easing (`sideAngleTarget = targetSideAngle(); updateSideAngle`) is not gated on tactical; tactical is the same follow-cam path with zoom pinned to 1.0 (line 209). Player on a walkway → nonzero orbit target → overhead camera swings sideways, and the shifting camera-side direction feeds `Occlusion.updateTacticalSelection`, flipping the selected block.

### 6. Tactical drops LOS occlusion outside selected block — `src/render/Occlusion.hx:151`
Tactical mode replaces the `occludes()` line-of-sight fade entirely with selected-block membership. The tactical camera is not top-down (zoom=1 offset {y:60, z:22} ≈ 70° pitch, ~5.5 cells horizontal): a tall building in an adjacent unselected block on the camera→player sightline keeps fade 1.0 and hides the player. (Plausible — layout/height-dependent.)

### 7. Ring side points projected without behind-camera guard — `src/render/Shockwave.hx:111`
Only the center checks `c.z > 1`; the `cz+r` side point can project behind the camera when zoomed in with a scream a few cells south. Huge z self-cancels in the shader (smoothstep saturates → ripple vanishes that frame), but w≈0 produces NaN uv → rare one-frame black/garbage flash. (Plausible, low.)

## Altitude / reuse

### 8. isHost guard is effect-local bandaid — `src/effects/BlackNoise.hx:57`
The invariant (AI logic must never move the player host — position owned by playerArea) belongs in `Attacker.canMoveToTarget`, which returns true for a host via `fromAI(game, ai, false)` (Attacker.hx:142). Any future effect driving the host through CommonLogic re-desyncs the same way and must re-add its own guard.

### 9. Target-entity switch duplicated — `src/abilities/BasicMelee.hx:78`
The TARGET_AI/TARGET_PLAYER/TARGET_OBJECT → entity switch is verbatim-duplicated from CommonLogic.hx:194-202. AttackTarget already hosts type-switch helpers (theName/onDamage/x/y) — add an `entity` accessor there, use from both. Otherwise the player-body rule drifts between the two copies.

### 10. Scream radius literal duplicated — `src/abilities/ChoirSilentScream.hx:38`
Gameplay radius hardcoded as `5` in `getAIinRadius` while the visual radius lives in `RenderConfig.SCREAM.radiusCells` (5.0). Tuning one drifts the other; the render particle also re-derives its own membership rule (skips center cell, includes player) that differs from the ability's (skips self/dead).

### 11. 4th copy of the hit-shake expression — `src/render/Actors.hx:296`
`playFx(e, new Shake(RenderConfig.MELEE.shakeMs, RenderConfig.MELEE.shakeAmp * CityConfig.CELL, 0))` now at four sites (StreetView.hx:330, 389, 559 + scream onTouch). Extract `hitShake(e)` on Actors.

## Efficiency

### 12. touchActors rescans all AI every frame — `src/render/particles/ScreamPulse3D.hx:105`
Every AI checked ~72 frames per cast with no radius pre-filter or early-out, fresh cellToWorld allocation per unshaken AI per frame; the player block (119-130) copy-pastes the AI loop body. Cheaper: collect in-radius candidates once at construction, pop as the monotonic front passes; share one `tryTouch(entity, col, row)` helper.

### 13. TacticalGrid built eagerly per area — `src/render/StreetView.hx:181`
Geometry built + GPU-uploaded on every area build even if tactical is never toggled. Build lazily on first `toggleTactical()` and reuse (only visibility flips afterwards).

### 14. Per-cast dome geometry — `src/render/particles/ScreamPulse3D.hx:79`
Each cast allocates SphereGeometry(1, 48, 24) and disposes on death; scale is per-instance anyway. Share one static unit-hemisphere geometry, keep only the ShaderMaterial per-instance for uniforms.

## Dead code

### 15. Unreachable post-loop re-check — `src/render/Occlusion.hx:214`
The scan loop only exits via break at an in-bounds Building (out-of-bounds returns null inside; scan=rows+cols can never exhaust stepping one axis by 1). Six lines of unreachable defensive branching on an internal invariant path — delete.

## Cut for the 15-cap (real but minor)

- Mid-pulse teardown leaks ScreamPulse3D geometry + compiled shader program — but teardown() disposes nothing scene-wide already (pre-existing pattern).
- `setTactical(true)` sets zoom=zoomTarget=1.0 redundantly (update() forces it every frame).
- TacticalGrid flat-color LineBasicMaterial vs CLAUDE.md texture rule — Editor.hx/PolyProbe.hx already set the overlay-helper precedent.
- Shockwave allocates 3 Vector3/pulse/frame — static scratch vectors (Gizmo.hx precedent).

## Root cause note

Findings 1–4 all cluster on the uncommitted tactical-view work: the tactical flag lives in three places (HUD visibility, StreetView.tactical, CameraRig.tactical) with no single owner. One owner + derived state kills the whole cluster.
