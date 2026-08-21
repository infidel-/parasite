package render.sewer;

// one entry of PROP_MODELS: a wall-clutter glb and the two numbers that are its own rather than the
// scatter's. a drum stands tall on a small round footprint and a cable coil is flat on a wide one,
// so a single global height/standoff pair (which is what this replaced) either floats one prop off
// the wall or buries the other in it.
//
// `r` is a RATIO, not a distance, and that is the whole point. Models.instanced scales a prop by
// HEIGHT alone (targetH / native height), so its footprint is native radius * h / native height —
// i.e. r * h. A hand-typed standoff goes stale the moment h changes, which is exactly how the cable
// ended up 0.33 world units inside the masonry: it was authored at 0.5 for a footprint of 0.83.
// SewerProps derives the standoff from r instead, so it can never disagree with the mesh again
typedef SewerProp = {
  path:String,   // RenderConfig.MODELS entry
  h:Float,       // world height Models.instanced scales the prop to
  r:Float,       // footprint radius as a MULTIPLE of h — max XZ distance from the glb's bbox centre,
                 // divided by its native height. yaw-independent, so PROP_YAW_JITTER cannot break it
  corner:Bool,   // true = only ever placed where two perpendicular walls meet. this PARTITIONS the
                 // table: a corner spot deals only from the corner props and a flat run of wall only
                 // from the rest, so BOTH sides must stay non-empty
}

// art + dimensions for the 3D sewer tunnels — the render.world.CityStyle of underground areas.
// there is only one sewer look today, so this is plain constants rather than a swappable instance
class SewerStyle
{
  // wall variations, one picked PER FACE (SewerGeom). a clean/worn PAIR was tried this way before
  // and rejected — 47% of cell boundaries changed variant and every switch was a hard seam — but
  // that pair was two independently painted tiles with DIFFERENT block layouts, so a switch moved
  // the mortar. these four are repaints of one source: the courses line up across a switch and only
  // the wear differs, which is a discontinuity in the dirt rather than in the masonry
  public static var WALLS = [
    'textures/sewer/wall.png',
    'textures/sewer/wall-2.png',
    'textures/sewer/wall-3.png',
    'textures/sewer/wall-4.png',
  ];
  public static inline var FLOOR = 'textures/sewer/floor.png';   // wet concrete walkway
  public static inline var LEDGE = 'textures/sewer/ledge.png';   // flat top of a wall, seen from the overhead camera
  public static inline var GRIME = 'textures/sewer/grime.png';   // damp base band; alpha is hand-painted into the source
  // NO sludge gutter and NO ledge pipe run. both are switched off, so their paths are not listed
  // here — the art itself is still registered in textures-src/textures.json (sewer/sludge,
  // sewer/top-pipe-1) and still builds, so reviving either is a path plus its emit

  // wall detail decals. these ARE the old wall-worn variant, broken into pieces: everything that
  // used to justify a second whole-wall texture (fractures, seepage, moss, missing blocks) now
  // lands on individual faces, where it cannot seam
  public static inline var CRACK = 'textures/sewer/crack-1.png';
  public static inline var SEEPAGE = 'textures/sewer/seepage-1.png';
  public static inline var MOSS = 'textures/sewer/moss-1.png';
  public static inline var BROKEN = 'textures/sewer/broken-1.png';

  // world units per texture repeat. UVs are worldPos / these on BOTH axes, so nothing stretches
  // and the brick keeps one scale everywhere regardless of how long a tunnel run is
  // none of them a MULTIPLE OF CELL (4), on purpose: the floor and the cap are the two surfaces
  // that actually fill the screen, and at 8.0 their texture period was exactly two cells, so every
  // grid line landed on the same point of the tile and the repeat read as a pattern. at 7.0 the
  // echo only comes back around every 7 cells
  public static inline var WALL_TILE = 6.0;
  public static inline var FLOOR_TILE = 7.0;
  public static inline var LEDGE_TILE = 7.0;

  // wall height in world units (CELL is 4, an actor billboard is 3): tall enough to enclose, low
  // enough that the near-top-down sewer camera never has a wall between it and the player. at
  // actor height the walls read as a kerb the tunnel is cut into rather than as a deep shaft,
  // which is what keeps sightlines open on the steeper preset
  public static inline var WALL_H = 3.0;

  // --- the cap edge (render.sewer.SewerGeom) ---
  // a 45 degree chamfer between the wall face and the ledge cap, and the amount the cap is pulled
  // back on every edge that overlooks a floor cell so the wedge is what the camera meets at the
  // drop. ONE number for both, which is what makes it 45 degrees.
  //
  // this is the edge the whole look hangs on. wall FACES are 0.67% of the view and the cap tops
  // 14.68% (docs/3d-render.md), so what reads as "orthogonal" is not the masonry, it is the single
  // dead-straight high-contrast line where a bright cap meets a near-black face. a DARKENING BAND
  // painted along that rim was tried and rejected — nothing stands above a wall cap, so it read as
  // a stripe floating over a brighter surface. this is the opposite move: real geometry with a real
  // normal, so the lighting produces the rim instead of art faking it, and the silhouette becomes
  // two edges CAP_CHAMFER apart instead of one
  // 0.25 measured, not picked: swept live against the habitat. 0.15 was invisible at both camera
  // presets and 0.45 read as a chunky moulding rather than a worn edge. at 0.25 the wedge covers
  // ~0.25 world units of screen at either preset (the vertical drop and the horizontal setback
  // trade places as the pitch goes 53 -> 71 degrees), i.e. a dozen-odd pixels of bevel at a 4-unit
  // cell — enough to break the line, not enough to become a design feature
  public static inline var CAP_CHAMFER = 0.25;

  // how far the cap SAGS below WALL_H, hashed per lattice point (render.sewer.SewerGeom.capY).
  // the chamfer broke the silhouette into two edges; this stops those edges being LEVEL, which is
  // the other half of "orthogonal". the top of every wall now tilts between its two corners, so a
  // run of tunnel draws a shallow zigzag instead of a ruled line and no corner is a right angle in
  // elevation.
  // keyed off the lattice, not the cell, and that is what makes it free: a per-CELL height steps at
  // every boundary, and a step between two SOLID cells is a hole through the plateau unless a filler
  // quad is emitted on it — which then fights the CAP_CHAMFER inset at every corner. sharing the
  // corner heights instead welds the plateau by construction, with no extra geometry and no cases.
  // DOWNWARD only: WALL_H is the camera-clearance number and nothing may rise above it
  public static inline var CAP_SAG = 0.4;

  // --- per-vertex tint on the shell (render.sewer.SewerGeom.tint) ---
  // free unevenness: no art, no draw calls, no tris. keyed off the cell LATTICE, never off the face
  // — see SewerGeom.tint for why anything per-face seams
  public static inline var TINT_AMP = 0.15;     // +/- value swing of the lattice noise
  public static inline var TINT_FOOT = 0.80;    // darkening at the foot of a wall (the floor crease)
  // extra darkening down an inside corner's vertical line. WALL_SHADOW_W owns that corner now, with
  // a far tighter falloff than a vertex ramp across a whole 4-unit face can give, so this is only
  // the broad wash under it — and the one thing covering the chamfer and its stop triangle, which
  // stand above the strip's top (capY less the chamfer). it was 0.75 before the strips; stacked with
  // one that put the corner at 0.75 * (1 - SHADOW_ALPHA) = 0.34 of base, which is a hole
  public static inline var TINT_CORNER = 0.90;
  // lift on the chamfer, so the bevel still reads in the stretches of tunnel no lamp reaches. small
  // on purpose, because the hemisphere fill (SewerScene: sky 0x46536e over ground 0x141a22 at 1.89)
  // already ramps it: a flat cap takes the sky colour whole, a vertical face the midpoint and a 45
  // degree wedge 85% of the way up, which lands the chamfer ~11% over the face against a large
  // normal-blind AmbientLight. this roughly doubles that without pushing the wedge past the cap.
  // 1.0 = pure lighting, and is the value to fall back to if the edge reads as a drawn stripe
  public static inline var TINT_CHAMFER = 1.08;

  // --- damp band at the foot of every wall (render.sewer.SewerDetail) ---
  // RenderConfig.GRIME_H is 3.0, which down here is the ENTIRE wall, so the sewer needs its own
  public static inline var GRIME_H = 1.2;       // band height in world units, from the floor up
  public static inline var GRIME_TILE = 3.0;    // world units per grime repeat along the wall
  public static inline var GRIME_OPACITY = 0.7; // band strength (0 = none .. 1 = the source's own alpha)

  // --- fake contact shadow where a wall meets the floor (render.sewer.SewerDetail) ---
  // the street equivalents are RenderConfig.ROOF_SHADOW_W / ROOF_SHADOW_ALPHA under a parapet
  public static inline var SHADOW_W = 1.1;      // how far the shadow reaches out from the wall
  public static inline var SHADOW_ALPHA = 0.55; // darkness right at the wall, fading to 0 outward
  public static inline var SHADOW_Y = 0.02;     // lift off the floor so it never z-fights the walkway

  // --- the same contact darkening stood UP an inside wall corner (render.sewer.SewerDetail) ---
  // nothing in the sewer lighting darkens a vertical corner, and that is structural rather than a
  // tuning gap: AmbientLight is normal-blind, the hemisphere fill keys on normal.y and BOTH faces of
  // a vertical corner are vertical (so they take byte-identical hemi), and a spotlight out in the
  // corridor sees both walls at once. the only engine answer is GTAO, which measured +140 calls and
  // ships off. these rides the floor strips' own InstancedMesh — same PlaneGeometry, same material,
  // same gradient — so a whole level of them costs no extra draw call and no extra program.
  // its alpha is therefore SHADOW_ALPHA by construction, not a knob of its own
  public static inline var WALL_SHADOW_W = 1.1;    // reach along each face, out from the corner
  // stand-off from the wall plane. must clear DECAL_EPS (0.05) or a crack decal in the corner draws
  // over the shadow instead of under it, and it is a PHYSICAL gap rather than polygonOffset — see
  // the standing note in docs/3d-render.md, where polygonOffset alone has failed three times.
  // it is also the distance the strip starts out from the corner itself, which is the same number
  // its perpendicular twin stands off by, so the two meet in plan instead of crossing
  public static inline var WALL_SHADOW_EPS = 0.07;

  // ledge-top clutter and floor decals, both TOP-DOWN art laid flat (render.sewer.SewerGround).
  // these dress the two surfaces that actually fill the screen: measured on the habitat, wall faces
  // are 0.67% of the 3D view against the ledge tops' 14.68%, with the floor taking most of the rest
  public static inline var TOP_VALVE = 'textures/sewer/top-valve-1.png';
  public static inline var TOP_RUBBLE = 'textures/sewer/top-rubble-1.png';
  public static inline var TOP_MOSS = 'textures/sewer/top-moss-1.png';
  public static inline var FLOOR_PUDDLE = 'textures/sewer/floor-puddle-1.png';
  public static inline var FLOOR_PUDDLE_2 = 'textures/sewer/floor-puddle-2.png';
  public static inline var FLOOR_GRATE = 'textures/sewer/floor-grate-1.png';
  public static inline var FLOOR_STAIN = 'textures/sewer/floor-stain-1.png';

  // NO darkening band along the ledge rim. it was tried (a strip pass mirroring SewerDetail's floor
  // contact shadows, opaque at the drop and fading inward) and it looks wrong for a reason no tuning
  // fixes: nothing STANDS above a wall cap. a roof gets that band from its parapet; here the cap just
  // ends, so the darkening reads as a stripe floating over a BRIGHTER wall face, and its hard edge
  // lands exactly on the silhouette and shimmers. see docs/3d-changes.md
  // --- top-down clutter scattered on the two horizontal surfaces (render.sewer.SewerGround) ---
  // both rates are per CELL, unlike the wall decals' per-FACE roll, so they read much sparser than
  // the same number would on a wall: one cell shows a single 4x4 patch of ground
  public static inline var LEDGE_PCT = 22;      // % of solid cells that get a ledge-top prop
  public static inline var LEDGE_MARGIN = 0.3;  // keep a prop this far inside the cell (never overhangs the drop)
  public static inline var LEDGE_DECAL_Y = 0.03; // clear of the cap, so a prop never z-fights the ledge
  public static inline var FLOOR_PCT = 16;      // % of eligible floor cells that get a decal
  public static inline var FLOOR_MARGIN = 0.2;  // decals sit inside their own cell, never across a wall
  public static inline var FLOOR_DECAL_Y = 0.01; // UNDER the contact shadows at SHADOW_Y, so a puddle at a wall foot still darkens

  // --- wall detail decals (render.sewer.SewerDetail) ---
  // RenderConfig.WALLDECAL_PCT is 35, but that is per whole building FACE; a sewer face is a single
  // 4x3 cell, so the same rate covers the tunnel in graffiti-density clutter
  public static inline var DECAL_PCT = 18;      // % of wall faces that get a decal
  public static inline var DECAL_EPS = 0.05;    // proud of the wall face (avoid z-fight)
  public static inline var DECAL_MARGIN = 0.5;  // keep a decal this far inside the cell's edges

  // bloom threshold underground. was 0.75 (below the street's 0.9) so the few lamps would bloom
  // against near-black surroundings, but the lamps clear 0.9 on their own — their glow quads and
  // emissives run 2.6-3.2x over the amber. What lived in that 0.75-0.9 band was over-lit SURFACES:
  // a pale face straight under a bulb (the exit ladder's top rail) haloed onto the floor around it
  public static inline var BLOOM_THRESHOLD = 0.9;

  // --- overhead node/exit light shafts (render.LightCone via SewerScene) ---
  // a street shaft tapers to RenderConfig.LAMP_CONE.topR = 0.2, i.e. a point at the bulb, because it
  // IS a bulb. down here the light falls through a MANHOLE, so the shaft is already a manhole wide
  // where it starts and only spreads a little on the way down
  public static inline var CONE_TOP_R = 0.9;
  // and it is not lit like a street lamp either. this is the NIGHT SKY falling down a hole, so it is
  // cold and pale where the street's is sodium amber — which is also what tells it apart from the
  // wall fixtures at a glance. no bloom constraint: the shaft draws at LAMP_CONE.opacity 0.03, so
  // even at full luminance it lands three orders under BLOOM_THRESHOLD
  public static inline var SHAFT_COLOR = 0x9db4d4;

  // --- weak bracketed lamps on the tunnel walls (render.sewer.SewerLamps) ---
  // these are the between-junctions lighting: the node lamps only land on 3x3 corridor corners and
  // intersections, so without these a whole run of corridor has no light source of its own
  public static inline var WALL_LAMP_PCT = 12;         // % of wall faces that get a fixture
  // cells of clearance a fixture keeps from any overhead shaft (render.sewer.SewerLamps.nearShaft).
  // a bracket standing inside a manhole column is two light sources lighting one pool of floor, and
  // the weak one only muddies it. derived, not picked: the shaft's ground radius is
  // bulbY * tan(LAMP_LIGHT.angle) * LAMP_CONE.radiusMul = 3.66 world units (0.92 cells), and a
  // bracket throws its own pool WALL_LAMP_AIM = 5.0 (1.25 cells) out from the wall — so they stop
  // touching at ~2.2 cells apart. rejecting a cell also shrinks the block's `faces` count, which the
  // density gate multiplies by, so blocks near a shaft thin out on their own
  public static inline var WALL_LAMP_CLEAR = 2;
  public static inline var WALL_LAMP_BROKEN_PCT = 30;  // % of those permanently dead (housing only, no light)
  public static inline var WALL_LAMP_FLICKER_PCT = 35; // % of the SURVIVORS that sputter (failing-sodium)
  // bracket height on the wall face. DOWN at the foot of the wall, not up under the cap: a fixture at
  // head height pooled its light straight beneath itself and nothing in the tunnel cast a shadow worth
  // seeing. from here the beam rakes the walkway (see WALL_LAMP_AIM) and everything it touches throws
  // a long one. the glow quad is WALL_LAMP_H tall, so its bottom edge still clears the floor
  public static inline var WALL_LAMP_Y = 0.6;
  public static inline var WALL_LAMP_OUT = 0.6;        // how far the SPOTLIGHT stands off the wall, so its
                                                       // cone starts in open air instead of half inside masonry
  // how far out along the wall normal the spotlight AIMS (LampPost.tx/tz). the bulb is WALL_LAMP_Y
  // high and aims at the floor this far away, i.e. a ~7 degree grazing beam — which is the whole
  // point of dropping it down here. shorten this to pull the lit pool back off the opposite wall
  public static inline var WALL_LAMP_AIM = 5.0;
  public static inline var WALL_LAMP_W = 0.75;         // glow quad width in world units
  public static inline var WALL_LAMP_H = 0.5;          // glow quad height
  public static inline var WALL_LAMP_HOUSING = 2.6;    // housing/soot quad size, as a multiple of the glow
  public static inline var WALL_LAMP_MUL = 0.35;       // pooled-spotlight intensity multiplier — a weak fixture
  // fixture tint, and NOT the street's amber (RenderConfig.LAMP_CONE.color): these are bolted-on
  // tubes gone bad, not sodium street lighting, and they must read apart from the manhole shafts
  // overhead. pale olive — deliberately clear of the flame/ember/alert warm band, of the saturated
  // UI greens (OBJMARK 0x35dd7a, path/slime 0x7ddc46, acid 0x58ff3c) and of the cool UI blues.
  // CHECK THE BLOOM MATH BEFORE CHANGING IT: the glow quad is this * WALL_LAMP_GLOW, unclamped, and
  // UnrealBloomPass thresholds LINEAR Rec.709 luminance where blue weighs only 0.0722 — a cool hue
  // can look bright and silently stop blooming. this one is Y_linear 0.627, so 0.627 * 2.6 = 1.63
  // against BLOOM_THRESHOLD 0.9 (the amber it replaced was 1.47)
  public static inline var WALL_LAMP_COLOR = 0xc8d69a;
  public static inline var WALL_LAMP_GLOW = 2.6;       // HDR multiplier on WALL_LAMP_COLOR so the quad clears BLOOM_THRESHOLD
  public static inline var WALL_LAMP_SOOT = 0.18;      // housing darkness (opacity of the black smudge behind the glow)

  // --- the vision mask: what the player cannot see (render.sewer.SewerMask) ---
  // how far a hidden fragment sinks toward the fog colour. 0.0 is the 2D view's flat black, and this
  // is deliberately NOT that: underground the whole screen is tunnel, so blacking out everything past
  // a corner leaves a mostly-empty frame. at 0.18 the masonry still reads as a silhouette — the
  // LAYOUT stays legible, which the minimap gives away anyway (AreaView.generateMinimap is not
  // fog-aware) — while nothing standing in it does, since render.Actors already hides the AI and the
  // objects outright on the same predicate
  public static inline var MASK_HIDDEN = 0.18;
  // the same floor for ADDITIVE emissives: the wall-lamp glow quads and the manhole shafts. harder
  // than the surfaces they sit on, and not as a taste call — an additive quad adds its colour on top
  // of whatever is behind it, so an 18% glow is still a bright dot floating in a corridor nobody can
  // see, which is the one thing that would give the whole effect away
  public static inline var MASK_HIDDEN_ADD = 0.0;
  // mask texels per cell. the shape painted into it is a real visibility POLYGON, so this is only how
  // finely that polygon is sampled. it does NOT soften anything on its own — MASK_BLUR does that now.
  // that hard case was briefly blamed on this and it was dropped to 2 — wrong lever, twice over: the
  // 90-degree lines were the per-cell WALL REVEAL rects (MASK_WALL_FADE ramps those), and the jagged
  // floor boundary was the blur that did not exist yet. so this is back at 4, where a revealed cell
  // has enough texels across it to carry a ramp.
  // 8 puts a habitat at 168x112 and a whole 75x60 level at 600x480. it was 4, and doubling it is only
  // affordable because fadeCell stopped painting texel by texel — measured 3.78ms of a 3.90ms rebuild
  // at 8, against 0.02ms for the polygon and 0.10ms for the composite, which is why the strip path in
  // SewerMask.fadeCell exists. everything else here is resolution-INDEPENDENT: uScale/uOrigin are
  // normalized, MASK_BLUR is in world units and converts at the filter, and the rest are in cells
  public static inline var MASK_PX = 8;
  // gaussian sigma the visibility plane is blurred by on its way into the mask, in WORLD UNITS —
  // SewerMask.update converts to texels at the filter, so MASK_PX can move without rescaling the
  // softness. the numbers below were swept at MASK_PX 4, where one texel WAS one world unit, so they
  // carry over unchanged.
  // without it the entire lit/dark transition on open floor is ONE antialiased texel — measured: 55
  // intermediate texels over a whole habitat boundary, i.e. one per unit of boundary length — and a
  // texel is ~30-38 screen pixels at the sewer camera, so bilinear reconstruction of that single
  // coverage value puts a staircase of that same period along the edge. that is what read as jagged.
  // it blurs the RED plane ALONE — the green masonry channel the wobble gates on is composited in
  // separately and stays crisp, or the wobble would bleed a texel out onto open floor.
  //
  // THIS IS A CONVOLUTION, so widening the band has to come out of one side or the other: it eats
  // into the lit region (a narrow corridor stops reaching full brightness) and it spills onto the
  // hidden one (a wall's far side lifts off MASK_HIDDEN). there is no setting that only softens.
  // measured on a habitat, live canvas — band is intermediate texels, dim is the share of genuinely
  // lit texels that fall under 200, bleed is the mean red over texels the sweep never reached:
  //   0.75 -> band  867, dim  1.5%, bleed  1.9   (the first version, still visibly a straight edge)
  //   1.5  -> band 1485, dim  5.6%, bleed  5.2
  //   2.0  -> HERE
  //   2.5  -> band 2149, dim 18.8%, bleed  9.8
  //   4.0  -> band 2874, dim 39.1%, bleed 17.4   (lit ground washes out, hidden walls glow)
  // 2.0 is the knee: roughly twice the band of the first version, before the dim column runs away.
  // push it if the boundary still reads as an edge, but check a ONE-CELL corridor when you do —
  // that is where the dimming shows first, and it is why plain sigma cannot go much past this.
  // 0 turns it off
  public static inline var MASK_BLUR = 0.5;
  // how deep into a lit wall cell the mask fades where it touches masonry the sweep never reached, in
  // CELLS. this is what stops a run of lit wall ending on a right angle at a cell boundary. the
  // unreached cell itself is never painted at all, which is what keeps it fully dark — a linear filter
  // only bleeds half a texel, and holding the last lit texel a texel clear of the shared edge puts the
  // whole ramp inside the cell that can actually be seen. 0 gives the old hard per-cell reveal back
  public static inline var MASK_WALL_FADE = 0.5;
  // how far the LEVEL'S OUTER RIM fades out, in cells — the mask's BLUE channel, which multiplies
  // sewerVis after everything else.
  // this is the one edge no amount of MASK_BLUR can soften, and not for want of trying: the blur is a
  // convolution over the red plane, so it can only average the rim UP toward the lit interior (a sigma
  // 2 kernel spans ~8 texels against fadeCell's 4, measured: rim vis 0.434 -> 0.511), and even a mask
  // of exactly 0 still renders at MASK_HIDDEN. SewerGeom caps EVERY solid cell and insets only edges
  // overlooking floor, so the area border's cap runs flush to the boundary and then there is NO
  // GEOMETRY — a lit ledge against the clear colour, which is what "you can see where it just ends"
  // was. blue is static, painted once per level and composited UNBLURRED, so it survives any sigma.
  // it reaches zero, which is the whole point: SewerScene sets scene.background and scene.fog to the
  // same DARK, and the opaque branch fades toward fogColor — so vis 0 lands EXACTLY on the background
  // and the silhouette stops existing rather than merely dimming.
  // 1.0 = the always-solid border ring and nothing else, so no playable floor is touched. RAISING IT
  // PAST 1 EATS INTO FLOOR (the ring is one cell thick), which dims ground the player walks on
  public static inline var MASK_EDGE_FADE = 1.0;
  // how far the mask boundary wanders from where the polygon actually put it, in WORLD units (a cell
  // is CityConfig.CELL = 4). WALL CELLS ONLY — the shader gates it on the mask's green channel, so an
  // open-floor shadow edge keeps the exact polygon the sweep computed. purely cosmetic either way: it
  // never moves what the player can see, and the actors do not read the mask at all. 0 turns it off
  public static inline var MASK_WOBBLE = 0.3;
  // how far the SMOOTHED origin must travel, in cells, before the polygon is rebuilt. the mask
  // follows the player's sliding position rather than their logical cell, so this is what stops it
  // rebuilding on motion nobody can see: one mask texel is 1 / MASK_PX = 0.125 cells, so this is two
  // fifths of a texel. a move slides one cell over BASE_MS (150ms, ~9 frames at 60Hz) and smoothstep
  // peaks at ~0.17 cells per frame, so it never merges frames through the middle of a slide — only at
  // its slow ends, which is exactly where nothing is happening. measured cost of one rebuild: 0.30ms
  // in the habitat (0.1 cell scan + 0.2 sweep/fill, upload under the timer's resolution at both mask
  // sizes), ~1.5ms projected on a full 75x60 level, against a 16.6ms frame with 14.5ms idle
  public static inline var MASK_STEP = 0.05;
  // radius in cells the polygon is built over. the sweep is O(rays * segments) and both grow with
  // this, so it is the cost knob. DERIVED, not picked: at the sewer preset pinned to full zoom-out
  // (CameraRig.maxFootprintCells, 180 cells) the ground the camera can show reaches 5.7 cells ahead of
  // the player, 3.9 behind and 10.8 to the side — 12.2 at the far corner. 14 covers that with margin,
  // and the square range bound reaches 19.8 at ITS corners. anything past this is hidden, which is
  // right for gameplay and visible only under the street-debug free cam, where p.los turns it off
  public static inline var MASK_R = 14;

  // --- the exit ladder prop (RenderConfig.MODELS.sewerExit via render.world.ObjModels) ---
  // its height lives in the ObjModels table beside every other object prop's, so one place decides
  // how tall each of them stands (4.0 there, taller than WALL_H so the ladder visibly climbs PAST the
  // ledge toward the hole we do not render)
  // the exit's light steps SOUTH (+Z, screen-DOWN under CAMERA_SEWER) off the ladder's own cell, so
  // the prop is not standing in the middle of its own shaft and the lit pool lands on the walkway in
  // FRONT of it. the SpotLight moves with the cone — a shaft whose lit floor pool sat somewhere else
  // would read as two different lights. the lamp's col/row stay the exit cell: that is what
  // LampLights gates player distance on
  public static inline var EXIT_LAMP_SOUTH = 2.0;

  // --- 3D clutter scattered against the walls (render.sewer.SewerProps) ---
  // the first CONVEX geometry down here. the shell is a concave box and everything dressing it is
  // flat, so until these a wall bracket's raking beam had nothing to throw a shadow off.
  // one entry = one glb = one draw call for however many the level places
  // r is measured off the baked glb, NOT guessed — max XZ radius from the bbox centre over native
  // height. re-measure it whenever a source model is regenerated
  public static var PROP_MODELS:Array<SewerProp> = [
    // the two CORNER props: a big upright drum or a crate stack standing against a flat run of wall
    // reads as dropped in the walkway, while tucked into the angle of two walls it reads as stored
    // there. corners are ~14% of spots and these two share them, so expect 1-2 of each per level
    { path: render.RenderConfig.MODELS.sewerDrum, h: 1.8, r: 0.34, corner: true },
    { path: render.RenderConfig.MODELS.sewerCrates, h: 1.65, r: 0.52, corner: true },
    { path: render.RenderConfig.MODELS.sewerCable, h: 0.24, r: 2.77, corner: false },
    // h 1.0 rather than the 0.7 the flat-wide first generation wanted: the charcoal-reference regen
    // came back a proper pyramid (aspect 1.23 against 1.98), so the old height shrank its footprint
    // from 1.38 world units across to 0.86 and it read as a pebble
    { path: render.RenderConfig.MODELS.sewerBags, h: 1.0, r: 0.73, corner: false },
    // the three the old sewer-pile-1 heap was split into. heights read off the drum as a ruler — it
    // ships at h 1.8 for a real 0.88m 200L drum, so one world unit is ~0.49m and these are a 0.34m
    // block, a 0.22m-tall heap 0.75m across, and a 0.39m-bore pipe 0.72m long.
    // the block is the smallest prop down here by design (it is what the "single brick" idea became
    // once a real brick measured 0.44 world units, under the 2D litter's own 0.46 floor) — but 0.55
    // made it a speck beside the others on screen, the same mistake bags started with
    { path: render.RenderConfig.MODELS.sewerBlock, h: 0.7, r: 0.80, corner: false },
    { path: render.RenderConfig.MODELS.sewerBricks, h: 0.45, r: 2.06, corner: false },
    { path: render.RenderConfig.MODELS.sewerPipe, h: 0.8, r: 1.02, corner: false },
  ];
  // breathing room between the prop's footprint circle and the wall plane, on top of r * h. small
  // on purpose: these are meant to look dumped against the wall, not parked a pace off it
  public static inline var PROP_CLEAR = 0.05;
  // one prop per 2x2 block, gated per eligible wall FACE exactly as WALL_LAMP_PCT is. was 14 while
  // all four wall directions were eligible; SewerProps now rejects the camera-side one, which takes
  // roughly a quarter of the faces out of the gate, so this is scaled up to hold the same density
  public static inline var PROP_PCT = 18;
  // +/- yaw wobble (radians) around the face's outward facing, so two props on parallel walls are
  // not the same silhouette twice
  public static inline var PROP_YAW_JITTER = 0.5;

  // --- ground litter (render.sewer.SewerDebris), per 1000 floor cells ---
  // rooms stay tidier than the tunnels as the old 2D pass had it, but only just: a habitat is pinned
  // to 4-5 rooms of 5x5, so 62-77% of its floor IS room and the low rate was the one underfoot. these
  // were 20/8, then 60/24 — a whole habitat level came to ~9-11 fragments, which reads as swept
  public static inline var DEBRIS_PCT_TUNNEL = 180;
  public static inline var DEBRIS_PCT_ROOM = 120;
  // smallest fragment scale the tunnels will keep. render.world.Debris rolls 0.1 + 0.9 * rng for a
  // cluster fragment, and the drawn size is Sprites.SIZE (3.0) * contentFraction * scale — so a 0.1
  // roll on a half-content sprite draws 0.15 world units against a CELL of 4, i.e. a pixel. measured
  // in the habitat before this: 0.15 / 0.73 / 0.86 / 0.88 / 1.21
  public static inline var DEBRIS_MIN_SCALE = 0.5;
  // sub-cell jitter for a STATIC fragment, which render.world.Debris leaves dead-centre and unrotated
  // (only transformable ones get an offset). stays inside Debris.canPlace's free band, so a fragment
  // can never end up over a wall and no ground test is needed
  public static inline var DEBRIS_JITTER = 0.25;
}
