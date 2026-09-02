# Textures & image generation (3D art)

The gpt-image → `textures-src/` → `make tex` → `app/textures/` pipeline. Loaded on demand; the
`3d-art` skill triggers it. `CLAUDE.md` keeps only the two rules that fire unprompted ("new images"
means generate them, and never stretch a texture).

**New findings go here, not into `CLAUDE.md`.** One bullet per lesson, the number that proves it
inline. When a lesson invalidates an old bullet, replace it rather than appending a second.

See also [`3d-models.md`](3d-models.md) — a generated prop needs a reference image from this
pipeline, and an emitted box needs a tiling texture from it.

## The rules

- **"we need new images" / "new images" means GENERATE them with the gpt-image MCP tool** (not "the user will supply them"). Treat it as an instruction to run `generate_image`/`edit_image` yourself. Decals now come out of gpt already cut (see the transparent-background bullet); hand-cutting is only for what that route fumbles.
- **Default to 1k — do NOT ask.** Two MCP servers: `gpt-image-2` (1024 edge) and `gpt-image-2-2k` (up to 3840 edge). Use `gpt-image-2` unless the user explicitly asks for 2k. It is the right answer nearly always: outputs bake down to 512 (details/sprites 256), so a 1024 source is already oversampled. Reach for 2k only on the user's say-so.
- **One flat art style, from `style-flat.png`:** moody-night roguelike, matte flat colors, very dark/muted/desaturated palette, low contrast, even flat lighting, subtle fine grain, simple clean shapes, minimal detail. NO photorealism, NO realistic/volumetric lighting, NO glossy/specular reflections, NO camera/lens effects, NO soft photographic shadows — hand-painted, flat, like a 2D game tile. Append the canonical `style` string (top-level key in `textures-src/textures.json`) VERBATIM to EVERY gen/edit prompt; keep the two in sync.
- **Alpha comes from the API now: `background:"transparent"` (gpt-image-2 preview, on both MCP servers).** Send it with `output_format:"png"` (webp also carries alpha; **jpeg is rejected** — HTTP 400 `invalid_transparent_background_output_format`) and the drop has a real alpha channel. Measured on a test prop: 71.7% of pixels at alpha 0 and a 1–2px edge ramp — a cleaner cut than the `tol:24` chroma key. Two things ride along:
  - **Say NOTHING about a background in the prompt.** Describe one and the model paints one anyway. Still say the subject must not touch the frame edges.
  - Opaque pixels land at alpha **253, never 255**. Harmless here (`alphaTest` is 0.35–0.5 everywhere, `has_alpha` wants `lo < 255`) — just never write an `alpha == 255` test.

  Register the drop `class:"sprite"`, `needs_alpha:true`, NO chroma: `make tex` keeps the cut, and `bleed_alpha` scrubs the coloured glow gpt paints into the transparent texels. `edit_image` takes `background` too (verified re-cutting `decals/detail-ac.png`), so an opaque source can be re-emitted with alpha instead of hand-cut.
- **Fallback — the FLAT SOLID grey `#5a5d63` route**, for whatever transparent mode fumbles, and still MANDATORY for TRELLIS reference images (3D models section below). Generate on flat grey with the subject clear of the frame edges, register `class:"chroma"` (`chroma:"0x5a5d63"`, `tol:24`), and `make tex` bakes the key → alpha. On this route **NEVER ask the prompt for a "transparent background"** — with `background` unset gpt PAINTS A CHECKERBOARD as real pixels, a two-tone grid fused into the art that is strictly harder to cut than one flat colour.

  Windows/facades that must be transparent otherwise stay opaque and the tool warns until hand-edited.
- **Pipeline:** sources (1024²) in `textures-src/`; `textures-src/textures.json` is the source of truth (per label `{ src, class: tile|window|chroma|sprite, res?, needs_alpha, chroma?, tol?, prompt }`; `default_res` 512, details/sprites 256). Runtime outputs are build artifacts in `app/textures/<label>.png` (paths in `src/render/RenderConfig.hx` `TEXTURES`, loaded via `src/render/Textures.hx`) — never hand-place them. Subfolders are supported: a label/`src` like `decals/graffiti-1` nests both source and output (decals live under `textures-src/decals/` + `app/textures/decals/`). After generating/editing a source, update its `textures.json` entry (esp. `prompt`) and run **`make tex`** (→ `tools/textures.py`; also strips gpt prefixes and sweeps `*~` backups), then `make -C src` + reload.
- **Never manually `mv`/`cp` generated drops** (it trips a permission prompt). Generate straight into `textures-src/` (or a subdir) with `filename_prefix=<final-label>`, then run **`make adopt`** (`textures.py --rename`) — it strips the `image-<ts>-<hash>-` prefix in place (walks subdirs). Then `make tex`.
- **Batch gen in parallel:** issue independent `generate_image`/`edit_image` calls in ONE message (they're independent + slow). For lit/unlit pairs, make the unlit base first, then fan out lit edits.
- **NEVER stretch a texture** (any surface — walls, ground, roads, decals). World-aligned tiling on BOTH axes (`uv = worldPos/TILE` or `texture.repeat = faceLen/TILE`); accept a partial tile at a far edge. If stretching is ever unavoidable, STOP and notify the user. And NEVER put a flat solid-color material on visible geometry — always a texture.
