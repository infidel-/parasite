import game.*;

class Const
{
  // mod API surface version (bump on breaking change)
  public static inline var MOD_API_VERSION = 1;

  // runtime debug flag — true when main resolved a sentinel (.debug file in cwd) at boot.
  // gates console cheats, hud debug overlay, profile timers, ai tooltip extras, etc.
  // populated by Main.init() from HostBridge.isDebug before any guarded code runs
  public static var isDebug: Bool = false;

  public static var FONTS = [ 16, 24, 32, 40 ];
  public static var LAYER_MOUSE = 10; // mouse cursor layer - highest
  public static var LAYER_UI = 9; // ui windows layer
  public static var LAYER_HUD = 8; // ui layer
  public static var LAYER_TILEMAP = 7; // tilemap view layer
  public static var LAYER_DOT = 5; // path doths layer
  public static var LAYER_EFFECT = 4; // visual effects layer
  public static var LAYER_PLAYER = 3; // player, enemies, etc layer
  public static var LAYER_AI = 2; // player, enemies, etc layer
  public static var LAYER_OBJECT = 1; // area - bodies, items, region - icons and objects
  public static var LAYER_TILES = 0; // tilemap layer

  public static var TILE_SIZE_CLEAN = 64; // file tile size
  public static var TILE_SIZE = TILE_SIZE_CLEAN; // screen tile size

  // text color strings
  public static var TEXT_COLORS: Map<_TextColor, String> = [
    COLOR_DEFAULT => '#FFFFFF',
    COLOR_DEBUG => '#a7a7a7',
    COLOR_ALERT => '#FC420E',
    COLOR_EVOLUTION => '#73f3ff',
    COLOR_ORGAN => '#e0e13a',
    COLOR_HINT => '#e36767',
    COLOR_TIMELINE => '#f7af46',
    COLOR_MESSAGE => '#74e088',
    COLOR_GOAL => '#92B9FF',
    COLOR_PEDIA => '#c8d8da',
    COLOR_SYMBIOSIS => '#98ff97',
    COLOR_CULT => '#fd97ff',
  ];

  // TODO: remove from here
  // entity spritemap indexes
  public static var ROW_ALERT = 0;
  public static var FRAME_EMPTY = 0;
  public static var FRAME_ALERT1 = 1;
  public static var FRAME_ALERT2 = 2;
  public static var FRAME_ALERT3 = 3;
  public static var FRAME_ALERTED = 4;
  public static var FRAME_PANIC = 5;
  public static var FRAME_PARALYSIS = 6;
  public static var FRAME_CALLING = 7;
  public static var FRAME_SLIME = 8;
  public static var FRAME_HIGH_CRIME = 9;
  public static var FRAME_BLEEDING = 10;
  public static var FRAME_BLACK_NOISE = 11;

  // region icons frames
  public static var ROW_REGION_ICON = 1;
  public static var FRAME_EVENT_UNKNOWN = 1;
  public static var FRAME_EVENT_KNOWN = 2;
  public static var FRAME_EVENT_NPC = 3;
  public static var FRAME_HABITAT = 4;
  public static var FRAME_EVENT_NPC_AREA = 5;
  public static var FRAME_HABITAT_AMBUSHED = 6;
  public static var FRAME_OVUM = 7;
  public static var FRAME_CORPHQ = 8;
  public static var FRAME_CULT_MISSION = 9;
  public static var FRAME_TARGET_RETICLE = 10;
  public static var FRAME_TARGET_FRAME = 11;

  // object row frames
  public static var ROW_OBJECT = 2;
  public static var FRAME_SEWER_HATCH = 0;
  public static var FRAME_PAPER = 1;
  public static var FRAME_BOOK = 2;
  public static var FRAME_EVENT_OBJECT = 3;
  public static var FRAME_PICKUP = 4;
  public static var FRAME_HUMAN_BODY = 5;
  public static var FRAME_DOG_BODY = 6;
  public static var FRAME_NUTRIENT = 7;
  public static var FRAME_SHIP_PART = 8;
  public static var FRAME_STAIRS = 9;
  public static var FRAME_LOCKED_ICON = 10;
  public static var FRAME_SEWER_EXIT = 11;

  // effect row frames
  public static var ROW_EFFECT = 3;
  public static var FRAME_PANIC_GAS = 0;
  public static var FRAME_PARALYSIS_GAS = 1;
  public static var FRAME_PARTICLE_MONEY = 2;
  public static var FRAME_EFFECT_MONEY = 3;
  public static var FRAME_CULTIST0 = 4;
  public static var FRAME_MULTIPLE_EFFECTS = 5;
  public static var FRAME_PARTICLE_ACID_SPIT = 6;
  public static var FRAME_PARTICLE_SLIME_SPIT = 7;
  public static var FRAME_PARTICLE_PARALYSIS_SPIT = 8;
  public static var FRAME_SEARCH = 9;
  public static var FRAME_CULTIST_UNKNOWN = 10;

  // parasite row frames
  public static var ROW_PARASITE = 4;
  public static var FRAME_PARASITE = 0;
  public static var FRAME_DOG = 1;
  public static var FRAME_MASK_CONTROL = 2;
  public static var FRAME_MASK_ATTACHED = 3;
  public static var FRAME_DOT = 4;
  public static var FRAME_MASK_DEFAULT = 5;
  public static var FRAME_CHOIR = 6;
  public static var FRAME_CHOIR_BODY = 7;

  // first growth row
  public static var ROW_GROWTH1 = 5;
  public static var FRAME_BIOMINERAL = 0;
  public static var FRAME_PRESERVATOR = 4;
  public static var ROW_ASSIMILATION = 6;
  public static var ROW_WATCHER = 7;

  // row 8 - chem laboratory decoration floor (high)
  public static var CHEM_LABS_DECO_FLOOR_HIGH = [
    { row: 8, amount: 12 },
    { row: 13, amount: 7 },
  ];

  // rows 9-11, 14 and 48-49 - chem laboratory decoration table.
  //
  // 43 frames became 64 with the pack16 sheets (FACILITY_DECO_HD below): row 14's five free columns
  // were filled, and rows 48-49 are NEW — entities64 grew from 48 rows to 50, which reaches nothing
  // else because no other family addresses down there. The 64 px icons for the 21 invented frames
  // are baked out of the pack art by tools/atlaspaste.py, so the 2D area view draws them too
  public static var CHEM_LABS_DECO_TABLE: Array<_TileRow> = [
    { row: 9, amount: 12 },
    { row: 10, amount: 12 },
    { row: 11, amount: 12 },
    { row: 14, amount: 12 },
    { row: 48, amount: 12 },
    { row: 49, amount: 4 },
  ];

  // row 12 - chem laboratory decoration floor (low)
  public static var CHEM_LABS_DECO_FLOOR_LOW = [
    { row: 12, amount: 11 },
  ];

  // the floor decorations the 3D view draws as a REAL 3D OBJECT instead of an upright atlas quad
  // (render.facility.FacilityDeco). the generator asks gen.Deco for a decoration matching a MOUNT and
  // a BLOCK, and takes one of the matching entry's frames; the renderer reads the kind back out of
  // the frame with fittingOf below, which is what lets every save made before this table existed
  // light up as geometry with nothing migrated — the frames were already there.
  //
  // the place tags (`mount`, `blocks`) are the table's only selection rule — see _DecoPlace.hx.
  //
  // MOST are merged geometry and two are not: a drum and a bin are round, and FacilityGeom emits
  // axis-aligned quads only, so those two are instanced glbs the compound already ships. Being in
  // this table is what turns their sprite off and what stamps their cell, which is the same job for
  // both routes.
  //
  // the 2D area view is not affected at all: a fitting is still an objects.Decoration drawing the
  // same entities64 cell it always drew
  public static var FACILITY_DECO: Array<_DecoPlace> = [
    // the open metal shelving with boxes on it, the one kind emitted as a composite rather than a box
    {
      id: 'shelving',
      kind: FIT_SHELVING,
      mount: [ 'floor-high' ],
      // laboratory AND office. It was the lab's alone on the argument that a rack of unboxed kit is
      // not a researcher's furniture, and it came back reported as having stopped spawning: measured
      // end to end it was 0.70 (a slot is filled) x 0.50 (that slot is HIGH) x 0.60
      // (FACILITY_FITTING_PCT) x a uniform 1-in-5 over the entries a lab's floor-high list holds,
      // which is 4.2% of eligible wall cells and nothing at all next door
      blocks: [ 'lab', 'cabinet' ],
      // and WEIGHTED, which is the other half of the same number: three entries against a plain
      // one's one takes it to 3-in-7 of that roll. Storage is what a storage compound is made of
      weight: 3,
      frames: [
        { row: 8, col: 9 },
        { row: 8, col: 10 },
      ],
    },
    {
      id: 'bookcase',
      kind: FIT_BOOKCASE,
      mount: [ 'floor-high' ],
      blocks: [ 'lab', 'cabinet' ],
      frames: [
        { row: 13, col: 0 },
        { row: 13, col: 1 },
        { row: 13, col: 2 },
        // the wooden shelf of books and bottles: the same silhouette as the three above, so it
        // rides the same geometry rather than earning a fourth kind
        { row: 8, col: 11 },
      ],
    },
    {
      id: 'rack',
      kind: FIT_RACK,
      mount: [ 'floor-high' ],
      blocks: [ 'lab', 'cabinet' ],
      frames: [
        { row: 13, col: 3 },
        { row: 13, col: 4 },
        { row: 13, col: 5 },
        { row: 13, col: 6 },
      ],
    },
    // the top of the HIGH list, four frames on ONE kind: a fridge, a glass-door freezer, a twin-door
    // storage cabinet and a biohazard safety cabinet are the same tall two-door case seen from the
    // front, and what separates them in the atlas is a decal at 64 px. One emitted unit and one
    // authored front serves all four — see art/textures.json's facility/deco-cabinet-front
    {
      id: 'cabinet',
      kind: FIT_CABINET,
      mount: [ 'floor-high' ],
      blocks: [ 'lab', 'cabinet' ],
      frames: [
        { row: 8, col: 0 },
        { row: 8, col: 1 },
        { row: 8, col: 2 },
        { row: 8, col: 3 },
      ],
    },
    // the rest of the HIGH list, five frames on one kind: a hopper/conveyor filler, an analyser
    // console, a CNC enclosure, a gear press and a bench lathe are all one boxed machine casing at
    // this size, and what a lathe actually is — a bed, a headstock and a tailstock — is the composite
    // silhouette a mesh generator returns as mush (see docs/3d-render.md's sewer-pile row)
    {
      id: 'machine',
      kind: FIT_MACHINE,
      mount: [ 'floor-high' ],
      // laboratory only: a bench lathe against the wall of a researcher's room is the lab's furniture
      blocks: [ 'lab' ],
      frames: [
        { row: 8, col: 4 },
        { row: 8, col: 6 },
        { row: 8, col: 7 },
        { row: 8, col: 8 },
      ],
    },
    // and the fifth of those frames on its OWN kind, because the hangar needed a machine that is
    // not a cube. NO NEW ART AND NO RENUMBERED FRAME: row 8 col 5 is the analyser console the
    // entry above already listed among its five, and it moves here rather than being copied — a
    // frame is the persisted identity of a decoration and two kinds claiming one is a coin toss in
    // render.facility.FacilityModel. See render.facility.FacilityDeco's FIT_ANALYSER row
    {
      id: 'analyser',
      kind: FIT_ANALYSER,
      mount: [ 'floor-high' ],
      blocks: [ 'lab' ],
      frames: [
        { row: 8, col: 5 },
      ],
    },
    // and the two LOW frames that are the same casing knee-high: a radiation placard panel and a grey
    // appliance cabinet. They cost no new art at all — the machine's front TILES, so one image serves
    // both heights where an aspect-locked 0..1 front would have needed a second kind and a second sheet
    {
      id: 'machine-low',
      kind: FIT_MACHINE_LOW,
      mount: [ 'floor-low' ],
      blocks: [ 'lab' ],
      frames: [
        { row: 12, col: 0 },
        { row: 12, col: 6 },
      ],
    },
    // the LOW list's four stacked-server icons: the same cabinet as the rack above, one tile tall
    // rather than two, so they cost NO new art and NO new draw call — same three surfaces
    {
      id: 'rack-low',
      kind: FIT_RACK_LOW,
      mount: [ 'floor-low' ],
      blocks: [ 'lab' ],
      frames: [
        { row: 12, col: 7 },
        { row: 12, col: 8 },
        { row: 12, col: 9 },
        { row: 12, col: 10 },
      ],
    },
    // and the LOW list's round things, which are glbs and not geometry. they are in this table for
    // the same two reasons every kind above is: it is what turns the 2D sprite off (FacilityDeco
    // .draws) and what stamps the cell in FacilityModel.deco, which is the gate keeping the lab kit
    // out of an occupied tile
    // one kind per BARREL, because each livery is its own glb and the atlas really does draw three
    // different drums — a grey one with a hazard triangle, a yellow biohazard one and a red
    // radioactive one. Collapsing them onto one prop was the first build and it threw the marking
    // away, which is most of what those three icons ARE
    {
      id: 'drum-steel',
      kind: FIT_DRUM_STEEL,
      mount: [ 'floor-low' ],
      blocks: [ 'lab' ],
      frames: [
        { row: 12, col: 1 },
      ],
    },
    {
      id: 'drum-bio',
      kind: FIT_DRUM_BIO,
      mount: [ 'floor-low' ],
      blocks: [ 'lab' ],
      frames: [
        { row: 12, col: 2 },
      ],
    },
    {
      id: 'drum-rad',
      kind: FIT_DRUM_RAD,
      mount: [ 'floor-low' ],
      blocks: [ 'lab' ],
      frames: [
        { row: 12, col: 5 },
      ],
    },
    {
      id: 'bin',
      kind: FIT_BIN,
      mount: [ 'floor-low' ],
      blocks: [ 'lab' ],
      frames: [
        { row: 12, col: 3 },
        { row: 12, col: 4 },
      ],
    },
    // the washroom pair. `floor-high` because they are standing furniture and not a knee-high drum;
    // their BLOCK is the washroom and nothing else, which is all it takes to keep them off a
    // laboratory floor — gen.facility.FacilityToilet places them itself, by kind and in a run.
    // their frames are free cells of the HIGH row: the facility has no 2D view at all any more, so a
    // fitting frame is a KEY fittingOf reads back and nothing draws it
    {
      id: 'stall',
      kind: FIT_STALL,
      mount: [ 'floor-high' ],
      blocks: [ 'toilet' ],
      frames: [
        { row: 13, col: 7 },
      ],
    },
    {
      id: 'basin',
      kind: FIT_BASIN,
      mount: [ 'floor-high' ],
      blocks: [ 'toilet' ],
      frames: [
        { row: 13, col: 8 },
      ],
    },
    // and the washroom's dividing wall, on the same terms
    {
      id: 'partition',
      kind: FIT_PARTITION,
      mount: [ 'floor-high' ],
      blocks: [ 'toilet' ],
      frames: [
        { row: 13, col: 9 },
      ],
    },
    // and the lounge's two, on exactly the same terms. THEIR BLOCK IS `lounge` AND NOT `cabinet`,
    // which is the whole of what keeps them off the office's ordinary wall roll: a block name is
    // what gen.Deco.pick matches, and the office DOES call FacilityRooms.addFitting with its own
    // role — so listed under `cabinet` the sofa is dealt as a piece of random wall furniture.
    // Measured live before the fix: one compound came out with three sofas and one table, two of
    // them standing where a bookcase was asked for. The washroom's three never had the problem
    // because nothing ever asks Deco for a `toilet` fitting. Keys, not pictures — see the note above
    {
      id: 'sofa',
      kind: FIT_SOFA,
      mount: [ 'floor-high' ],
      blocks: [ 'lounge' ],
      frames: [
        { row: 13, col: 10 },
      ],
    },
    {
      id: 'table-low',
      kind: FIT_TABLE_LOW,
      mount: [ 'floor-low' ],
      blocks: [ 'lounge' ],
      frames: [
        { row: 12, col: 11 },
      ],
    },
  ];

  // how often a high floor decoration comes out as one of the fittings above rather than as one of
  // the plain sprites. the nine fitting frames were already ~47% of CHEM_LABS_DECO_FLOOR_HIGH, so
  // this leans the mix toward 3D without emptying the rooms of the fridges, fume cabinets and
  // machines, which exist on floor cells and nowhere else
  public static inline var FACILITY_FITTING_PCT = 60;

// which fitting an atlas frame draws as, or -1 for a decoration that keeps its sprite. an Int and
// not a Null<_FittingKind> because every consumer stores it in an Int channel anyway — the render
// grid holds kind + 1 with 0 for "nothing here"
  public static function fittingOf(row: Int, col: Int): Int
    {
      var p = placeOf(row, col);
      return (p == null ? -1 : p.kind);
    }

// the whole table entry a frame belongs to, or null. fittingOf above is this one field of it, and
// gen.GenCheck.decoBlocks needs a SECOND one — `blocks`, i.e. where the entry was ever allowed to
// stand — which is the only way to ask, of a decoration already on the grid, whether the room it is
// standing in should have been offered it at all.
//
// unique by construction: gen.Deco.selfCheck asserts no frame appears on two entries, or this would
// stop being a function and a saved decoration would resolve to whichever the table listed first
  public static function placeOf(row: Int, col: Int): _DecoPlace
    {
      for (f in FACILITY_DECO)
        for (fr in f.frames)
          if (fr.row == row &&
              fr.col == col)
            return f;
      return null;
    }

// is this fitting kind dealt on the LOW list? read off FACILITY_DECO itself so the two can never
// drift apart, the same stateless shape fittingOf takes. render.facility.FacilityDeco asks it for one
// thing: a low fitting may stand against GLAZING where a high one may not
  public static function isLowFitting(kind: Int): Bool
    {
      for (f in FACILITY_DECO)
        if (f.kind == kind)
          return f.mount.indexOf('floor-low') >= 0;
      return false;
    }

// the frames one kind draws with, for a template placing that kind outright rather than rolling one
  public static function framesOf(kind: Int): Array<_FittingFrame>
    {
      for (f in FACILITY_DECO)
        if (f.kind == kind)
          return f.frames;
      return [];
    }

// does this atlas row draw a decoration that stands ON A BENCH rather than on the floor? read off
// CHEM_LABS_DECO_TABLE itself so the two can never drift apart. STATELESS, the same shape fittingOf
// takes: the answer is a property of the frame and of nothing else
  public static function isTableDeco(row: Int): Bool
    {
      for (t in CHEM_LABS_DECO_TABLE)
        if (t.row == row)
          return true;
      return false;
    }

  // the bench decorations the 3D view lays FLAT on the worktop instead of standing up as a
  // billboard. every icon in this family is painted in elevation, which is why objects.Decoration
  // stands them all up — but three of them are drawn looking DOWN at a thing lying on a bench, and
  // stood upright they read as a pair of gloves balanced on one cuff.
  //
  // PER FRAME AND NOT PER ROW, which is the whole reason this is its own table: the gloves sit at
  // 9/4 and 10/4 among eleven upright flasks and microscopes each, so the row-keyed shape
  // isTableDeco takes cannot express it. Const.fittingOf's shape instead — and, like that one, read
  // off this table alone so the two can never drift apart
  public static var FACILITY_FLAT_DECO: Array<_FittingFrame> = [
    // the yellow pair
    { row: 9, col: 4 },
    // and the blue
    { row: 10, col: 4 },
    // the calculator, which is drawn face-up already
    { row: 9, col: 9 },
  ];

  // ---- pack16: the hi-res bench decoration sheets --------------------------------------------
  //
  // one 1024 image carries SIXTEEN decorations at 256 px each, against the 64 an entities64 cell
  // gives one. A 3D-ONLY REDIRECTION, exactly the trade the 128 px actor atlases make: the 2D area
  // view still draws every decoration from entities64, and render.particles.Sprites.atlasFor swaps
  // the pack cell in underneath it for the sprite pool alone. So nothing is persisted, nothing is
  // migrated, and a save made before any of this lights up the moment it is drawn again.
  //
  // WHAT IT BUYS is texel density and nothing else. A bench sprite spans Sprites.SIZE 3.0 x
  // FacilityStyle.DECO_TABLE_SCALE 0.81 = 2.43 world units, so a 64 px cell is 26.3 texels per world
  // unit against facility/floor-tile's own 73 — reported from the game as blurry, the same complaint
  // art/textures.json's facility/floor-grate note records at 21.3. At 256 it is 105.3.
  //
  // it costs NO draw call: the pool binds one cached crop per quad either way (docs/3d-render.md:
  // "every pooled quad is a draw call"), and a sheet is only ever cropped, never bound whole
  public static inline var DECO_PACK_CELL = 256;
  public static inline var DECO_PACK_COLS = 4;
  public static inline var DECO_PACK_CELLS = DECO_PACK_COLS * DECO_PACK_COLS;

  // index = the pack cell, counted across sheets in reading order (sheet DECO_PACK_CELLS at a time,
  // then row-major inside it); value = the entities64 bench frame that cell redraws.
  //
  // AUTHORED BESIDE THE GENERATION PROMPT — cell i's art IS the frame it names here, so the 2D icon
  // and the 3D sprite stay the same object and a decoration does not change identity between views.
  // The prompts are in art/textures.json under facility/bench-pack<n>, one numbered line per cell in
  // this same order
  public static var FACILITY_DECO_HD: Array<_FittingFrame> = [
    // sheet 1 — row 9 entire, then the head of row 10
    { row: 9, col: 0 },
    { row: 9, col: 1 },
    { row: 9, col: 2 },
    { row: 9, col: 3 },
    { row: 9, col: 4 },
    { row: 9, col: 5 },
    { row: 9, col: 6 },
    { row: 9, col: 7 },
    { row: 9, col: 8 },
    { row: 9, col: 9 },
    { row: 9, col: 10 },
    { row: 9, col: 11 },
    { row: 10, col: 0 },
    { row: 10, col: 1 },
    { row: 10, col: 2 },
    { row: 10, col: 3 },
    // sheet 2 — the rest of row 10, then the head of row 11
    { row: 10, col: 4 },
    { row: 10, col: 5 },
    { row: 10, col: 6 },
    { row: 10, col: 7 },
    { row: 10, col: 8 },
    { row: 10, col: 9 },
    { row: 10, col: 10 },
    { row: 10, col: 11 },
    { row: 11, col: 0 },
    { row: 11, col: 1 },
    { row: 11, col: 2 },
    { row: 11, col: 3 },
    { row: 11, col: 4 },
    { row: 11, col: 5 },
    { row: 11, col: 6 },
    { row: 11, col: 7 },
    // sheet 3 — the rest of row 11, then row 14. its last FIVE cells are decorations that did
    // not exist: 14/7-11 were free columns, which is why CHEM_LABS_DECO_TABLE's row 14 above
    // deals 12 and not 7. tools/atlaspaste.py bakes their 64 px icons into the atlas for the 2D view
    { row: 11, col: 8 },
    { row: 11, col: 9 },
    { row: 11, col: 10 },
    { row: 11, col: 11 },
    { row: 14, col: 0 },
    { row: 14, col: 1 },
    { row: 14, col: 2 },
    { row: 14, col: 3 },
    { row: 14, col: 4 },
    { row: 14, col: 5 },
    { row: 14, col: 6 },
    { row: 14, col: 7 },
    { row: 14, col: 8 },
    { row: 14, col: 9 },
    { row: 14, col: 10 },
    { row: 14, col: 11 },
    // sheet 4 — SIXTEEN decorations that never existed, on two atlas rows that never existed
    // either: entities64 grew from 48 rows to 50 for them. Nothing else in the game addresses
    // rows 48-49, so growing the sheet downward reaches only this family
    { row: 48, col: 0 },
    { row: 48, col: 1 },
    { row: 48, col: 2 },
    { row: 48, col: 3 },
    { row: 48, col: 4 },
    { row: 48, col: 5 },
    { row: 48, col: 6 },
    { row: 48, col: 7 },
    { row: 48, col: 8 },
    { row: 48, col: 9 },
    { row: 48, col: 10 },
    { row: 48, col: 11 },
    { row: 49, col: 0 },
    { row: 49, col: 1 },
    { row: 49, col: 2 },
    { row: 49, col: 3 },
  ];

  // ---- the clue pack: the reports and books a facility hands out --------------------------------
  //
  // THE SAME REDIRECTION ONE FAMILY OVER, and a second table rather than more rows on the one above,
  // because the cell SIZE differs and DECO_PACK_CELL is inline at 256. 24 subjects on a 6x4 sheet of
  // 170 px cells (art/textures.json facility/clue-pack carries why that grid and not a pack64's 8x8),
  // against the 64 px an entities64 cell gave them — the clue documents were the last family in the
  // compound still drawn straight off the atlas, i.e. at 26 texels per world unit.
  //
  // 3D-ONLY, like the bench packs: the 2D area view, the inventory and every window still draw the
  // entities64 frame, which tools/atlaspaste.py bakes from these same cells, so the two are one
  // object drawn twice. Nothing is persisted and nothing is migrated
  // and the sewer hatch's own hi-res cell, which is a whole IMAGE rather than a pack: one object, one
  // cell, so it needs no index table and no coordinate arithmetic (render.particles.Sprites.atlasFor
  // and art/textures.json city/sewer-hatch)
  public static inline var HATCH_HD_CELL = 256;

  public static inline var CLUE_PACK_CELL = 170;
  public static inline var CLUE_PACK_COLS = 6;
  // index = the pack cell in reading order; value = the entities64 frame it redraws. The DOCUMENTS
  // row first (CHEM_LABS_DOCUMENTS, row 17) and then the BOOKS row (CHEM_LABS_BOOKS, row 19), which
  // is the order the generation prompt lists its 24 subjects in.
  //
  // THREE CELLS ARE RETIRED and the order is what retires them: sheet cells 8 (the fanfold printout),
  // 9 (the photostat) and 15 (the stack of three books) came back in THREE-QUARTER PERSPECTIVE rather
  // than the top-down the prompt asked for, so they cannot lie on a worktop. A cell's pack coordinates
  // come from its INDEX here (clueHDCol/clueHDRow), so a cell cannot be deleted from this table —
  // instead the three are mapped to the TAIL frames of their own atlas row and the deal is shortened
  // to stop before them (CHEM_LABS_DOCUMENTS 12 -> 10, CHEM_LABS_BOOKS 12 -> 11). The good cells
  // behind them shift down to close the gap, so the dealt frames stay contiguous from col 0
  public static var CLUE_HD: Array<_FittingFrame> = [
    // cells 0-11 — row 17, the paperwork
    { row: 17, col: 0 },
    { row: 17, col: 1 },
    { row: 17, col: 2 },
    { row: 17, col: 3 },
    { row: 17, col: 4 },
    { row: 17, col: 5 },
    { row: 17, col: 6 },
    { row: 17, col: 7 },
    { row: 17, col: 10 },   // retired: the fanfold, drawn in perspective
    { row: 17, col: 11 },   // retired: the photostat, drawn in perspective
    { row: 17, col: 8 },
    { row: 17, col: 9 },
    // cells 12-23 — row 19, the books
    { row: 19, col: 0 },
    { row: 19, col: 1 },
    { row: 19, col: 2 },
    { row: 19, col: 11 },   // retired: the stack of three, drawn in perspective
    { row: 19, col: 3 },
    { row: 19, col: 4 },
    { row: 19, col: 5 },
    { row: 19, col: 6 },
    { row: 19, col: 7 },
    { row: 19, col: 8 },
    { row: 19, col: 9 },
    { row: 19, col: 10 },
  ];

// which clue pack cell redraws this frame, or -1. decoHD's own shape and its own reason for being a
// linear scan: it is asked once per sprite cache MISS
  public static function clueHD(row: Int, col: Int): Int
    {
      for (i in 0...CLUE_HD.length)
        if (CLUE_HD[i].row == row &&
            CLUE_HD[i].col == col)
          return i;
      return -1;
    }

  public static inline function clueHDCol(hd: Int): Int
    {
      return hd % CLUE_PACK_COLS;
    }

  public static inline function clueHDRow(hd: Int): Int
    {
      return Std.int(hd / CLUE_PACK_COLS);
    }

// how many pack sheets the table above spans — read off it so adding sixteen rows is the whole edit
  public static function decoPackCount(): Int
    {
      return Math.ceil(FACILITY_DECO_HD.length / DECO_PACK_CELLS);
    }

// which pack cell redraws this bench frame, or -1 for one that has no hi-res art yet (it keeps its
// entities64 cell and simply stays soft). STATELESS, the shape fittingOf and isTableDeco both take.
//
// a LINEAR SCAN and deliberately so: it is asked once per sprite CACHE MISS, not per frame — every
// reader in render.particles.Sprites keys its cache on the entities64 coordinates and returns before
// reaching this
  public static function decoHD(row: Int, col: Int): Int
    {
      for (i in 0...FACILITY_DECO_HD.length)
        if (FACILITY_DECO_HD[i].row == row &&
            FACILITY_DECO_HD[i].col == col)
          return i;
      return -1;
    }

// which sheet a pack cell lives on, and its column and row inside that sheet. three one-liners here
// rather than the arithmetic open at both call sites (Sprites.atlasFor and render.View.iconBox),
// which is where a 4 and a 16 would drift apart
  public static inline function decoHDPack(hd: Int): Int
    {
      return Std.int(hd / DECO_PACK_CELLS);
    }

  public static inline function decoHDCol(hd: Int): Int
    {
      return hd % DECO_PACK_COLS;
    }

  public static inline function decoHDRow(hd: Int): Int
    {
      return Std.int((hd % DECO_PACK_CELLS) / DECO_PACK_COLS);
    }

// does this atlas frame draw a bench decoration that LIES DOWN? STATELESS, the shape fittingOf and
// isTableDeco both take: the answer is a property of the frame and of nothing else
  public static function isFlatDeco(row: Int, col: Int): Bool
    {
      for (f in FACILITY_FLAT_DECO)
        if (f.row == row &&
            f.col == col)
          return true;
      return false;
    }

  // row 15 - doors
  public static var ROW_DOORS = 15;
  public static var FRAME_DOOR_CABINET = 0;
  public static var FRAME_DOOR_CABINET_OPEN = 1;
  public static var FRAME_DOOR_DOUBLE = 2;
  public static var FRAME_DOOR_DOUBLE_OPEN = 3;
  public static var FRAME_DOOR_GLASS = 4;
  public static var FRAME_DOOR_GLASS_OPEN = 5;
  public static var FRAME_DOOR_METAL = 6;
  public static var FRAME_DOOR_METAL_OPEN = 7;
  public static var FRAME_DOOR_CORP = 8;
  public static var FRAME_DOOR_CORP_OPEN = 9;
  public static var FRAME_DOOR_ELEVATOR = 10;
  public static var FRAME_DOOR_ELEVATOR_OPEN = 11;
  // the solid-leaf door a PRIVATE room takes — a washroom or a researcher's office. the one facility
  // door that blocks line of sight when it is shut (objects.Door.canSeeThrough), which is why it has
  // no vision panel in its art either
  public static var FRAME_DOOR_PRIVATE = 12;
  public static var FRAME_DOOR_PRIVATE_OPEN = 13;

  // row 16 - objects
  public static var ROW_OBJECT2 = 16;
  public static var FRAME_FLOOR_DRAIN = 0;
  public static var FRAME_VENTILATION = 1;
  public static var FRAME_BURNING_BARREL = 2;
  public static var FRAME_SUMMONING_PORTAL = 3;
  public static var FRAME_BROKEN_PORTAL = 4;
  public static var FRAME_CLONE_VAT = FRAME_SUMMONING_PORTAL;
  public static var FRAME_CLONE_VAT_FLUSHED = FRAME_BROKEN_PORTAL;

  // row 17 - documents, row 19 - books. ONE ROW EACH and not the two they were dealt from: rows 17
  // and 19 are repainted from the clue pack (CLUE_HD, art/textures.json facility/clue-pack) and rows
  // 18 and 20 still hold the old 2D-era icons, so dealing those would mix two families of art in one
  // room. The 24 that are drawn is the whole deal; the two stale rows are left in the atlas rather
  // than cleared, because a save made before this holds documents pointing at them and an object
  // whose frame is blank is worse than one whose frame is old.
  //
  // 10 AND 11, NOT 12 AND 12: three of the sheet's 24 subjects came back in perspective and are
  // retired at the tail of their row (see CLUE_HD), so the deal stops one short of them
  public static var CHEM_LABS_DOCUMENTS = [
    { row: 17, amount: 10 },
  ];
  public static var CHEM_LABS_BOOKS = [
    { row: 19, amount: 11 },
  ];

  // row 21,22 - spaceship
  public static var SPACESHIP_BLOCK: _TileBlock = 
    { row: 21, col: 0, width: 3, height: 2 };

  public static var ROW_SPACESHIP1 = 21;
  public static var ACID_LARGE = 3;
  public static var ROW_SPACESHIP2 = 22;
  public static var SLIME_LARGE = 3;

  // row 23 - corpo decoration
  public static var CORP_COMPUTERS_BLOCK: _TileBlock =
    { row: 23, col: 0, width: 5, height: 1 };
  public static var CORP_COMPUTERS = [
    { row: 23, col: 0, amount: 5 },
  ];
  public static var CORP_TABLE_MISC = [
    { row: 23, col: 5, amount: 3 },
    { row: 27, col: 10, amount: 2 },
  ];
  public static var CORP_TABLE_LAMP = [
    { row: 23, col: 8, amount: 4 },
  ];
  public static var CORP_TABLE_PLANTS = [
    { row: 24, amount: 12 },
    { row: 25, amount: 6 },
  ];
  public static var CORP_TABLE_PHONE = [
    { row: 25, col: 6, amount: 4 },
  ];
  public static var CORP_TABLE_FILES = [
    { row: 26, amount: 11 },
  ];
  public static var CORP_TABLE_STATIONERY = [
    { row: 27, amount: 10 },
  ];
  public static var CORP_TABLE_COFFEE = [
    { row: 28, amount: 6 },
  ];
  public static var CORP_TABLE_PRINTER = [
    { row: 28, col:6, amount: 5 },
  ];
  public static var CORP_TABLE_PROJECTOR = [
    { row: 29, amount: 5 },
  ];
  public static var CORP_TABLE_ROUTER = [
    { row: 29, col: 5, amount: 3 },
  ];
  public static var CORP_TABLE_MISC_LARGE = [
    { row: 28, col: 11, amount: 1 },
    { row: 29, col: 8, amount: 4 },
  ];
  public static var CORP_CHAIR = [
    { row: 30, amount: 9 },
  ];
  public static var CORP_WHITEBOARD = [
    { row: 31, amount: 8 },
  ];
  public static var CORP_COOLER = [
    { row: 31, col: 8, amount: 2 },
  ];
  public static var CORP_PLANT = [
    { row: 31, col: 10, amount: 2 },
  ];
  public static var CORP_CABINET = [
    { row: 32, amount: 6 },
  ];
  public static var CORP_TRASH = [
    { row: 32, col: 6, amount: 5 },
  ];
  public static var CORP_TAP = [
    { row: 30, col: 9, amount: 2 },
    { row: 32, col: 11, amount: 1 },
  ];
  public static var CORP_MACHINERY = [
    { row: 33, amount: 7 },
  ];
  public static var CORP_FRIDGE = [
    { row: 33, col: 7, amount: 5 },
  ];
  public static var CORP_VENDING = [
    { row: 34, amount: 11 },
  ];
  public static var CORP_TABLE_CLEANING = [
    { row: 35, amount: 12 },
    { row: 36, amount: 4 },
  ];
  public static var CORP_TABLE_BLENDER = [
    { row: 36, col: 4, amount: 7 },
  ];
  public static var CORP_TABLE_FRUIT = [
    { row: 36, col: 11, amount: 1 },
  ];
  public static var CORP_TABLE_KETTLE = [
    { row: 37, amount: 8 },
  ];
  public static var CORP_TABLE_MICROWAVE = [
    { row: 37, col: 8, amount: 4 },
  ];
  public static var CORP_TABLE_TOILET_PAPER = [
    { row: 38, amount: 6 },
  ];
  public static var CORP_TABLE_CONTAINER = [
    { row: 38, col: 6, amount: 2 },
  ];
  public static var CORP_TABLE_TISSUE = [
    { row: 38, col: 8, amount: 4 },
  ];
  public static var CORP_TABLE_SAUCES = [
    { row: 39, amount: 5 },
  ];
  public static var CORP_TABLE_SALT = [
    { row: 39, col: 5, amount: 4 },
  ];
  public static var CORP_TABLE_MUG = [
    { row: 39, col: 9, amount: 3 },
  ];
  public static var ROW_BLOOD = 40;
  public static var BLOOD_LARGE = 0;
  public static var BLACK_BLOOD_LARGE = 5;

  public static var STREET_DEBRIS_TRANSFORMABLE = [
    { row: 41, col: 0, amount: 12 },
    { row: 42, col: 0, amount: 12 },
    { row: 43, col: 0, amount: 12 },
    { row: 44, col: 0, amount: 12 },
    { row: 45, col: 0, amount: 12 },
    { row: 46, col: 0, amount: 1 },
  ];
  public static var STREET_DEBRIS_STATIC = [
    { row: 46, col: 1, amount: 11 },
    { row: 47, col: 0, amount: 10 },
  ];

  // ==============================================
  // ==============================================
  // ==============================================

  public static var FRAME_DEFAULT = 0;
  // tiles spritemap indexes
  // row 0
  public static var TILE_HIDDEN = 0;
  public static var TILE_GROUND = 1;
  public static var TILE_BUILDING = 2;
  public static var TILE_ROCK = 3;
  public static var TILE_WALL = 4;
  public static var TILE_TREE1 = 5;
  public static var TILE_BUSH = 9;
  public static var TILE_GRASS = 10;
  public static var TILE_GRASS_UNWALKABLE = 11;
  // the two wilderness LARGE obstacles, each covering a rect of cells rather than one
  // (game.AreaGenerator.generateWilderness stamps them, render.wild.WildProps draws them). they are
  // the only tiles out there that block SIGHT as well as movement — every rock and tree beside them
  // is see-through — and tiles.Default already reads 12-15 as unwalkable and opaque, so naming them
  // is the whole gameplay half. no 2D art needed: a wilderness area always renders in 3D
  public static var TILE_ROCK_LARGE = 12;
  public static var TILE_TREE_CLUSTER = 13;

  // row 1
  public static var OFFSET_REGION = 16;
  public static var TILE_REGION_GROUND = OFFSET_REGION + 0;
  public static var TILE_CITY_LOW = OFFSET_REGION + 1;
  public static var TILE_CITY_MEDIUM = OFFSET_REGION + 2;
  public static var TILE_CITY_HIGH = OFFSET_REGION + 3;
  public static var TILE_FACILITY1 = OFFSET_REGION + 4;
  public static var TILE_MILITARY_BASE1 = OFFSET_REGION + 8;
  public static var TILE_SPACESHIP = OFFSET_REGION + 10;

  // row 2
  public static var OFFSET_AREA = 32;
  public static var TILE_ROAD = OFFSET_AREA + 0;
  public static var TILE_ALLEY = OFFSET_AREA + 1;
  public static var TILE_WALKWAY = OFFSET_AREA + 2;
  public static var TILE_WINDOW1 = OFFSET_AREA + 3;
  public static var TILE_WINDOWH1 = OFFSET_AREA + 4;
  public static var TILE_WINDOWH2 = OFFSET_AREA + 5;
  public static var TILE_WINDOWH3 = OFFSET_AREA + 6;
  public static var TILE_WINDOWV1 = OFFSET_AREA + 7;
  public static var TILE_WINDOWV2 = OFFSET_AREA + 8;
  public static var TILE_WINDOWV3 = OFFSET_AREA + 9;
  // a HIGH window: a small light well set near the ceiling, the washroom's own glazing. unwalkable
  // like every other window tile and, unlike them, NOT see-through (tiles.Default.TILE_SEETHROUGH) —
  // that is the whole point of it, a room that is lit and still private. it took the dead TILE_XXX
  // slot, which had one declaration and no use anywhere in the tree
  public static var TILE_WINDOW_HIGH = OFFSET_AREA + 10;
  public static var TILE_ROAD_UNWALKABLE = OFFSET_AREA + 11;
  public static var TILE_ALLEY_UNWALKABLE = OFFSET_AREA + 12;
  public static var TILE_WALKWAY_UNWALKABLE = OFFSET_AREA + 13;
  public static var TILE_CROSSWALKV = OFFSET_AREA + 14;
  public static var TILE_CROSSWALKH = OFFSET_AREA + 15;

  // row 3
  public static var OFFSET_CITY = 48;

  // row 7 - chem lab
  public static var OFFSET_CHEM_LAB = 112;
  public static var TILE_FLOOR_TILE = OFFSET_CHEM_LAB + 0;
  public static var TILE_FLOOR_TILE_GRATE1 = OFFSET_CHEM_LAB + 1;
  public static var TILE_FLOOR_TILE_GRATE2 = OFFSET_CHEM_LAB + 2;
  public static var TILE_FLOOR_TILE_GRATE3 = OFFSET_CHEM_LAB + 3;
  public static var TILE_FLOOR_LINO = OFFSET_CHEM_LAB + 4;
  public static var TILE_FLOOR_TILE_UNWALKABLE = OFFSET_CHEM_LAB + 5;
  public static var TILE_FLOOR_CONCRETE = OFFSET_CHEM_LAB + 6;
  public static var TILE_HANGAR_DOOR = OFFSET_CHEM_LAB + 7;
  public static var TILE_FLOOR_TILE_CANNOTSEE = OFFSET_CHEM_LAB + 8;
  public static var TILE_FLOOR_CONCRETE_UNWALKABLE = OFFSET_CHEM_LAB + 9;
  // the car park, and the one piece of open asphalt in a compound you can drive into. the yard and
  // the gaps between plots are Const.TILE_ALLEY and stay that way — the generator blanks the whole
  // grid to alley before it cuts anything, so "open lot" cannot tell a car park from a back yard and
  // render.facility.FacilityPaint was striping bays onto both. It resolves to Surf.LOT exactly like
  // the alley does, so debris, lamps and every other lot-gated pass keep working untouched; only the
  // two passes that mean THE CAR PARK gate on the raw mark.
  //
  // NO NEW ATLAS CELL: tiles.Default aliases its icon to TILE_ALLEY's. The asphalt is the same
  // asphalt and the bay lines are emitted geometry rather than tile art
  public static var TILE_PARKING = OFFSET_CHEM_LAB + 10;
  // A PARKED CAR'S OWN FOOTPRINT, and the second piece of the compound's render furniture to get a
  // tile of its own after the boom barrier's row (TILE_ALLEY_UNWALKABLE). render.facility.FacilityCars
  // stands one glb in a bay BAY_SPACING by BAY_CELLS cells, and it was pure decoration — a car the
  // player walked straight through. Both ids are the car park's own asphalt with the walk taken off
  // it, and both alias to TILE_ALLEY's icon like TILE_PARKING does; they resolve to Surf.LOT so every
  // lot-gated render pass is untouched.
  //
  // TWO IDS AND NOT ONE, and the second is the whole reason this works without the renderer
  // re-deriving anything: a bay's cells are stamped TILE_PARKING_CAR and its LOW CORNER ON THE KERB
  // is stamped TILE_PARKING_CAR_ORIGIN. Two bays standing side by side along one kerb are a single
  // 2x4 block of marks with no seam in it, so one id alone cannot say where a car begins — the
  // renderer would have to walk the run and agree with the generator's phase to find out. The origin
  // says it outright, and the car's yaw comes off which of the four neighbours is pavement
  public static var TILE_PARKING_CAR = OFFSET_CHEM_LAB + 11;
  public static var TILE_PARKING_CAR_ORIGIN = OFFSET_CHEM_LAB + 12;

  // === row 8-10 - tables
  public static var OFFSET_ROW8 = 128;
  public static var OFFSET_ROW9 = 144;
  public static var OFFSET_ROW10 = 160;
  // NOTE: first table tile! important for clue spawn!
  public static var TILE_LABS_TABLE_3X3_7 = OFFSET_ROW8 + 0;
  public static var TILE_LABS_TABLE_3X3_8 = OFFSET_ROW8 + 1;
  public static var TILE_LABS_TABLE_3X3_9 = OFFSET_ROW8 + 2;
  public static var TILE_LABS_TABLE_3X3_4 = OFFSET_ROW9 + 0;
  public static var TILE_LABS_TABLE_3X3_5 = OFFSET_ROW9 + 1;
  public static var TILE_LABS_TABLE_3X3_6 = OFFSET_ROW9 + 2;
  public static var TILE_LABS_TABLE_3X3_1 = OFFSET_ROW10 + 0;
  public static var TILE_LABS_TABLE_3X3_2 = OFFSET_ROW10 + 1;
  public static var TILE_LABS_TABLE_3X3_3 = OFFSET_ROW10 + 2;
  public static var LABS_TABLE_2X3 = [
    [ TILE_LABS_TABLE_3X3_7, TILE_LABS_TABLE_3X3_8, TILE_LABS_TABLE_3X3_9, ],
    [ TILE_LABS_TABLE_3X3_1, TILE_LABS_TABLE_3X3_2, TILE_LABS_TABLE_3X3_3, ],
  ];
  public static var LABS_TABLE_3X2 = [
    [ TILE_LABS_TABLE_3X3_7, TILE_LABS_TABLE_3X3_9 ],
    [ TILE_LABS_TABLE_3X3_4, TILE_LABS_TABLE_3X3_6 ],
    [ TILE_LABS_TABLE_3X3_1, TILE_LABS_TABLE_3X3_3 ],
  ];

  public static var TILE_LABS_TABLE2_3X3_7 = OFFSET_ROW8 + 4;
  public static var TILE_LABS_TABLE2_3X3_8 = OFFSET_ROW8 + 5;
  public static var TILE_LABS_TABLE2_3X3_9 = OFFSET_ROW8 + 6;
  public static var TILE_LABS_TABLE2_3X3_4 = OFFSET_ROW9 + 4;
  public static var TILE_LABS_TABLE2_3X3_5 = OFFSET_ROW9 + 5;
  public static var TILE_LABS_TABLE2_3X3_6 = OFFSET_ROW9 + 6;
  public static var TILE_LABS_TABLE2_3X3_1 = OFFSET_ROW10 + 4;
  public static var TILE_LABS_TABLE2_3X3_2 = OFFSET_ROW10 + 5;
  public static var TILE_LABS_TABLE2_3X3_3 = OFFSET_ROW10 + 6;

  public static var TILE_LABS_TABLE_1X3_1 = OFFSET_ROW8 + 3;
  public static var TILE_LABS_TABLE_1X3_2 = OFFSET_ROW9 + 3;
  public static var TILE_LABS_TABLE_1X3_3 = OFFSET_ROW10 + 3;
  public static var TILE_LABS_TABLE2_1X3_1 = OFFSET_ROW8 + 7;
  public static var TILE_LABS_TABLE2_1X3_2 = OFFSET_ROW9 + 7;
  public static var TILE_LABS_TABLE2_1X3_3 = OFFSET_ROW10 + 7;
  public static var LABS_TABLE_1X3 = [
    TILE_LABS_TABLE_1X3_1,
    TILE_LABS_TABLE_1X3_2,
    TILE_LABS_TABLE_1X3_3,
  ];

  // === row 11 - tables
  public static var OFFSET_ROW11 = 176;
  public static var TILE_LABS_TABLE_3X1_1 = OFFSET_ROW11 + 0;
  public static var TILE_LABS_TABLE_3X1_2 = OFFSET_ROW11 + 1;
  public static var TILE_LABS_TABLE_3X1_3 = OFFSET_ROW11 + 2;
  public static var TILE_LABS_TABLE_1X1 = OFFSET_ROW11 + 3;
  public static var TILE_CORP_TABLE_3X1_1 = OFFSET_ROW11 + 8;
  public static var TILE_CORP_TABLE_3X1_2 = OFFSET_ROW11 + 9;
  public static var TILE_CORP_TABLE_3X1_3 = OFFSET_ROW11 + 10;
  public static var TILE_DARK_TABLE_WOOD2_1X1 = OFFSET_ROW11 + 11;
  public static var TILE_LIGHT_TABLE_WOOD1_1X1 = OFFSET_ROW11 + 12;
  public static var TILE_DARK_TABLE_CARPET_1X1 = OFFSET_ROW11 + 13;
  public static var TILE_DARK_TABLE_MARBLE1_1X1 = OFFSET_ROW11 + 14;
  public static var CORP_TABLE_3X1 = [
    TILE_CORP_TABLE_3X1_1,
    TILE_CORP_TABLE_3X1_2,
    TILE_CORP_TABLE_3X1_3,
  ];
  public static var LIGHT_TABLE_WOOD1_2X2 = [
    [ OFFSET_ROW8 + 8, OFFSET_ROW8 + 10 ],
    [ OFFSET_ROW10 + 8, OFFSET_ROW10 + 10 ],
  ];
  public static var DARK_TABLE_CARPET_2X2 = [
    [ OFFSET_ROW8 + 11, OFFSET_ROW8 + 13 ],
    [ OFFSET_ROW10 + 11, OFFSET_ROW10 + 13 ],
  ];
  public static var DARK_TABLE_CARPET_3X3 = [
    [ OFFSET_ROW8 + 11, OFFSET_ROW8 + 12, OFFSET_ROW8 + 13 ],
    [ OFFSET_ROW9 + 11, OFFSET_ROW9 + 12, OFFSET_ROW9 + 13 ],
    [ OFFSET_ROW10 + 11, OFFSET_ROW10 + 12, OFFSET_ROW10 + 13 ],
  ];

  public static var TILE_LABS_TABLE2_3X1_1 = OFFSET_ROW11 + 4;
  public static var TILE_LABS_TABLE2_3X1_2 = OFFSET_ROW11 + 5;
  public static var TILE_LABS_TABLE2_3X1_3 = OFFSET_ROW11 + 6;
  // NOTE: last table tile! important for clue spawn!
  // change check in AreaGame.initSpawnPoints() if you add more tables
  public static var TILE_LABS_TABLE2_1X1 = OFFSET_ROW11 + 3;

  // === row 12 - corpo
  public static var OFFSET_ROW12 = 192;
  public static var TILE_CORP_WINDOW1 = OFFSET_ROW12 + 0;
  public static var TILE_CORP_WINDOWH1 = OFFSET_ROW12 + 1;
  public static var TILE_CORP_WINDOWH2 = OFFSET_ROW12 + 2;
  public static var TILE_CORP_WINDOWH3 = OFFSET_ROW12 + 3;
  public static var TILE_CORP_WINDOWV1 = OFFSET_ROW12 + 4;
  public static var TILE_CORP_WINDOWV2 = OFFSET_ROW12 + 5;
  public static var TILE_CORP_WINDOWV3 = OFFSET_ROW12 + 6;
  public static var TILE_FLOOR_CARPET = OFFSET_ROW12 + 7;
  public static var TILE_FLOOR_WOOD1 = OFFSET_ROW12 + 8;
  public static var TILE_FLOOR_WOOD2 = OFFSET_ROW12 + 9;
  public static var TILE_FLOOR_MARBLE1 = OFFSET_ROW12 + 10;
  public static var TILE_FLOOR_MARBLE2 = OFFSET_ROW12 + 11;
  public static var TILE_FLOOR_CARPET_MEETING = OFFSET_ROW12 + 12;

  // === row 13 - corpo
  public static var OFFSET_ROW13 = 208;
  public static var TILE_CORP_INNER_WINDOW1 = OFFSET_ROW13 + 0;
  public static var TILE_CORP_INNER_WINDOWH1 = OFFSET_ROW13 + 1;
  public static var TILE_CORP_INNER_WINDOWH2 = OFFSET_ROW13 + 2;
  public static var TILE_CORP_INNER_WINDOWH3 = OFFSET_ROW13 + 3;
  public static var TILE_CORP_INNER_WINDOWV1 = OFFSET_ROW13 + 4;
  public static var TILE_CORP_INNER_WINDOWV2 = OFFSET_ROW13 + 5;
  public static var TILE_CORP_INNER_WINDOWV3 = OFFSET_ROW13 + 6;
  public static var TILE_FLOOR_CARPET_UNWALKABLE = OFFSET_ROW12 + 7;
  public static var TILE_FLOOR_WOOD1_UNWALKABLE = OFFSET_ROW12 + 8;
  public static var TILE_FLOOR_WOOD2_UNWALKABLE = OFFSET_ROW12 + 9;
  public static var TILE_FLOOR_MARBLE1_UNWALKABLE = OFFSET_ROW12 + 10;
  public static var TILE_FLOOR_MARBLE2_UNWALKABLE = OFFSET_ROW12 + 11;

  // 14-16 - table
  public static var OFFSET_ROW14 = 224;
  public static var OFFSET_ROW15 = 240;
  public static var OFFSET_ROW16 = 256;
  public static var DARK_TABLE_MARBLE1_3X2 = [
    [ OFFSET_ROW14 + 0, OFFSET_ROW14 + 1, OFFSET_ROW14 + 2 ],
    [ OFFSET_ROW16 + 0, OFFSET_ROW16 + 1, OFFSET_ROW16 + 2 ],
  ];

// is this tile a window tile?
  public static inline function isWindowTile(tile: Int) {
    return 
      (tile >= TILE_WINDOW1 && tile <= TILE_WINDOWV3) ||
      (tile >= TILE_CORP_WINDOW1 && tile <= TILE_CORP_WINDOWV3) ||
      (tile >= TILE_CORP_INNER_WINDOW1 && tile <= TILE_CORP_INNER_WINDOWV3);
  }

  public static var TILE_CITY_WALKABLE = [ true ];
  public static var TILE_TYPE = [ 'hidden', 'ground', 'building', 'rock',
    'wall', 'tree', 'tree', 'tree', 'tree', 'grass', 'grass', 'grass',
    'largeRock', 'treeCluster' ];
//  public static var TILE_WALKABLE_REGION = [ true, true, true, true, true, true ];
//  public static var TILE_TYPE_REGION = [ 'ground', 'cityLow', 'cityMed', 'cityHigh' ];

  // player stuff

  // movement directions
  public static var dirx = [ -1, -1, -1, 0, 0, 1, 1, 1 ];
  public static var diry = [ -1, 0, 1, -1, 1, -1, 0, 1 ];
  public static var dir4x = [ -1, 0, 0, 1 ];
  public static var dir4y = [ 0, -1, 1, 0 ];
  public static var dirdiagx = [ -1, -1, 1, 1 ];
  public static var dirdiagy = [ -1, 1, -1, 1 ];
  // dir4 opposites
  public static var opposite4 = [
    0 => 3,
    3 => 0,
    1 => 2,
    2 => 1,
  ];
  public static var dirnames = [
    'NW', 'W', 'SW', 'N', 'S', 'NE', 'E', 'SE'
  ];
  public static function dirToName(dx: Int, dy: Int): String
    {
      for (i in 0...dirx.length)
        if (dirx[i] == dx && diry[i] == dy)
          return dirnames[i];
      return '?';
    }

// log all object string and int properties
  public static inline function debugObject(o: Dynamic)
    {
      var list: Array<Dynamic> = [ Inventory, Skills, Organs, Effects ];
      var classes: Array<String> = [ 'String' ];
      var fields = Reflect.fields(o);
      fields.sort(sortFunc);
      for (f in fields)
        {
          var ff = Reflect.field(o, f);
          var cl = Type.getClass(ff);
          if (cl == null)
            continue;
          var className = Type.getClassName(cl);
          if ((ff + '').indexOf('function') == 0)
            continue;

          // library classes and anonymous objects
          if (!Reflect.isFunction(ff) &&
              (!Reflect.isObject(ff) ||
               className == null || Lambda.has(classes, className)))
            Const.p(f + ': ' + ff);

          // lists
          else if (className == 'List')
            {
              var l: List<Dynamic> = cast ff;
              var tmp = [];
              for (x in l)
                tmp.push(x);

              Const.p(f + ': ' + tmp.join(', '));
            }

          // ingame classes
          else if (Lambda.has(list, Type.getClass(ff)))
            Const.p(f + ': ' + ff);
        }
    }


  static function sortFunc(a: String, b: String)
    {
      if (a < b) return -1;
      if (a > b) return 1;
      return 0;
    }



// todo display
  public static inline function todo(s: String)
    {
      trace('TODO: ' + s);
    }


// return clamped value between min and max
  public static inline function clamp(v: Int, min: Int, ?max: Int): Int
    {
      if (v < min)
        v = min;
      else if (max != null && v > max)
        v = max;
      return v;
    }


// return clamped value between min and max (float)
  public static inline function clampFloat(v: Float, min: Float, ?max: Float): Float
    {
      if (v < min)
        v = min;
      else if (max != null && v > max)
        v = max;
      return v;
    }


// roll between X and Y
  public static inline function roll(min: Int, max: Int): Int
    {
      return min + Std.random(max - min + 1);
    }

// roll d100
  public static inline function d100(): Int
    {
      return Std.random(100);
    }


// round to 1 decimal
  public static inline function round(x: Float): Float
    {
      return Math.round(x * 10) / 10;
    }

// calc distance squared
  public static inline function distanceSquared(x1: Int, y1: Int, x2: Int, y2: Int)
    {
      return (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1);
    }

// get distance between two points
  public static inline function distance(x1: Int, y1: Int, x2: Int, y2: Int): Int
    {
      return Std.int(Math.sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1)));
    }

// get sign of distance between x1,y1 and x2,y2
  public static inline function distanceSign(x1: Int, y1: Int, x2: Int, y2: Int): { x: Int, y: Int }
    {
      var dx = x2 - x1;
      var dy = y2 - y1;
      if (dx < 0)
        dx = -1;
      else if (dx > 0)
        dx = 1;
      if (dy < 0)
        dy = -1;
      else if (dy > 0)
        dy = 1;
      return { x: dx, y: dy };
    }

// print stuff
  public static inline function p(s: Dynamic)
    {
#if js
      js.Browser.console.log(s);
#else
      Sys.println(s);
#end
    }

  public static inline function hl(s: String)
    {
      return '<span class=highlight-text>' + s + '</span>';
    }

  public static inline function small(s: String)
    {
      return '<span class=small>' + s + '</span>';
    }

  public static inline function smallgray(s: String)
    {
      return '<span class="small gray">' + s + '</span>';
    }

// return the small string wrapped into color marker
  public static inline function smallcol(col: String, s: Dynamic)
    {
      return "<span class=small style='color:var(--text-color-" + col + ")'>" +
        s + '</span>';
    }

  public static inline function smalldebug(s: String)
    {
      return '<span style="color:var(--text-color-debug)" class=small>' + s + '</span>';
    }

  public static inline function narrative(s: String)
    {
      return '<span class=narrative>' + s + '</span>';
    }

// return the string wrapped into color marker
  public static inline function col(col: String, s: Dynamic)
    {
      return "<span style='color:var(--text-color-" + col + ")'>" +
        s + '</span>';
    }

// trace call stack for debug
  public static inline function traceStack()
    {
      trace(haxe.CallStack.toString(haxe.CallStack.callStack()));
    }

// round to 2 decimals
  public static inline function round2(num: Float)
    {
      return Math.round(num * 100) / 100;
    }

// capitalize string
  public static inline function capitalize(s: String): String
    {
      return s.charAt(0).toUpperCase() + s.substr(1);
    }
}

typedef _TileGroup = Array<_TileRow>;
typedef _TileRow = { row: Int, ?col: Int, amount: Int }
// one entities64 cell (_DecoPlace.frames)
typedef _FittingFrame = {
  // atlas row
  row: Int,
  // and column
  col: Int,
}
typedef _TileBlock = { row: Int, col: Int, width: Int, height: Int }
