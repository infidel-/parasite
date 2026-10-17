package render.world;

import render.world.Pile.PileKind;

// medium-density residential render knobs — the single file to tune the default city look,
// the one every area that is not the downtown core or the low-density outskirts renders with.
// Masonry mid-rises (concrete/brick/stone) plus a metal-warehouse special slot, punched windows
// with a warm glow, parapet or gable roofs, single-story shop bays along the street.
// This is also the style the other two BORROW from: DowntownStyle and SlumsStyle read slots off
// CityStyle.get() for every facade they reuse verbatim, so a path fixed here fixes all three.
// Textures live under textures/city/.
class CityStyle {
  // the street dumpster (objects.Dumpster, models-src/city/kit/dumpster.py) at its world size. a model
  // half-metre is 0.77 world here, the scale that stands a 1.85 m bin beside a 1.75 m actor sprite;
  // each height is that glb's whole bbox, so the one scale serves the shut bin and the slums one whose
  // lid stands thrown back. BACK is how far off its cell centre a bin steps toward the wall behind it
  public static inline var DUMPSTER_H = 1.93;
  public static inline var DUMPSTER_SLUMS_H = 3.38;
  public static inline var DUMPSTER_BACK = 1.15;
  public static inline var DUMPSTER_SLUMS_BACK = 1.13;
  static var _s:AreaStyle;
  public static function get():AreaStyle {
    if (_s == null) {
      var s = new AreaStyle();
      s.asphalt = 'textures/city/ground-asphalt.png';             // road surface (no markings yet)
      s.walkway = 'textures/city/ground-walkway.png';             // sidewalk / plaza paving
      s.walkwayBorder = 'textures/city/ground-walkway-border.png'; // kerb-edging stripe on walkway outer edges
      s.roadPaint = 'textures/city/ground-road-paint.png';        // worn white traffic paint (scuffs chroma-keyed to alpha)
      s.alley = 'textures/city/ground-alley.png';                 // grimy back-alley ground
      // 4 types [0 concrete, 1 brick, 2 stone, 3 metal warehouse]
      s.walls = [
        'textures/city/wall-1.png',
        'textures/city/wall-2.png',
        'textures/city/wall-3.png',
        'textures/city/wall-4.png',
      ];
      s.wornWalls = [   // alley-facing back walls
        'textures/city/wall-1-worn.png',
        'textures/city/wall-2-worn.png',
        'textures/city/wall-3-worn.png',
        'textures/city/wall-4-worn.png',
      ];
      s.storefronts = [ // ground-floor storefront bay
        'textures/city/facade-concrete.png',
        'textures/city/facade-brick.png',
        'textures/city/facade-stone.png',
        'textures/city/facade-metal.png',
      ];
      // roof base by facade; stone + metal reuse the tar base
      s.roofBases = [
        'textures/city/roof-base-concrete.png',
        'textures/city/roof-base.png',
        'textures/city/roof-base.png',
        'textures/city/roof-base.png',
      ];
      // metal warehouses pick one of these corrugated-steel variants per-building (ridged rust-red,
      // galvanized grey-blue, olive box-profile, plus the base wall-4); clean/worn paired by index
      s.metalWalls = [
        'textures/city/wall-4.png',
        'textures/city/wall-5.png',
        'textures/city/wall-6.png',
        'textures/city/wall-7.png',
      ];
      s.metalWorn = [
        'textures/city/wall-4-worn.png',
        'textures/city/wall-5-worn.png',
        'textures/city/wall-6-worn.png',
        'textures/city/wall-7-worn.png',
      ];
      // window sprites by facade; stone has its own pale-stone sprite (window-3), metal reuses the
      // square concrete one (unused — a warehouse has no windows)
      s.windows = [
        'textures/city/window-1.png',
        'textures/city/window-2.png',
        'textures/city/window-3.png',
        'textures/city/window-1.png',
      ];
      s.litWindows = [
        'textures/city/window-lit-1.png',
        'textures/city/window-lit-2.png',
        'textures/city/window-lit-3.png',
        'textures/city/window-lit-1.png',
      ];
      // crop fraction of each cell that is just the window+frame (concrete = square, brick = tall)
      s.winCrop = [{ x: 0.42, y: 0.42 }, { x: 0.30, y: 0.52 }, { x: 0.46, y: 0.82 }, { x: 0.42, y: 0.42 }];
      s.litColor = 0xffcf8f;    // warm glow color for lit windows
      s.litRatio = 0.15;        // fraction of windows that are lit (warm glass)
      s.litIntensity = 2.2;     // emissive intensity (HDR > 1 so bloom picks it up)
      // pedestrian entrance doors per masonry facade [concrete, brick, stone]; clean = front/street
      // (edited from wall-N), worn = side/maintenance door (edited from wall-N-worn). picked by isWornFace
      s.doors = [
        'textures/city/door-concrete.png',
        'textures/city/door-brick.png',
        'textures/city/door-stone.png',
      ];
      s.doorsWorn = [
        'textures/city/door-concrete-worn.png',
        'textures/city/door-brick-worn.png',
        'textures/city/door-stone-worn.png',
      ];
      s.doorCovers = [ // entrance-cover lintel/cornice band (over FRONT doors)
        'textures/city/door-cover-concrete.png',
        'textures/city/door-cover-brick.png',
        'textures/city/door-cover-stone.png',
      ];
      s.coverShape = [0, 1, 2]; // concrete half-barrel, brick flat slab, stone inset cap
      s.specialSlot = 3;        // metal warehouse
      s.roofDowntown = false;
      s.penthouseWall = null;
      // scruffy weeds in the block interiors (Lawns.hx). no per-building yard ring: the medium profile
      // has no house slots (CityProfile houseMaxSide 0), so lawnFacades stays EMPTY on purpose — it must
      // be non-null or Lawns.build bails, but nothing matches it and lawnChance stays 0. only the
      // courtyard-centroid and stray-cell passes fire, at about a third of the slums coverage: a tuft
      // or two per yard, not the overgrown dead lot the outskirts get
      s.lawnTex = 'textures/city/grass.png';
      s.lawnFacades = [];
      s.lawnCourtPatches = 1;
      s.lawnPatchChance = 0.01;
      // the street litter: its own PACK64 (render.decals.Debris)
      s.debrisPack = 'debris-city';
      // each litter cell's drawn longest side in world units, a row of the pack per line: the art
      // draws every cell the same size, so this is what keeps a matchbox off the scale of a flattened
      // box. pocket things about twice life so they still read at the street camera, the big flat
      // ones (rows 6-7) about life size
      s.debrisSizes = [
        [0.25, 0.25, 0.2, 0.2, 0.32, 0.18, 0.3, 0.2],     // cans, caps, butts, coffee cup, lid, straw, gum
        [0.25, 0.35, 0.45, 0.18, 0.18, 0.25, 0.25, 0.15], // receipt, flyer, poster scrap, ticket, scratch card, envelope, napkin, wrapper
        [0.3, 0.25, 0.18, 0.25, 0.2, 0.2, 0.3, 0.18],     // burger wrapper, fries, sachets, crust, candy wrapper, fork, chopsticks, slip
        [0.25, 0.45, 0.3, 0.5, 0.45, 0.4, 0.32, 0.3],     // maple leaf, twigs, feathers, plastic bag, newspaper, magazine page, bottles
        [0.28, 0.2, 0.35, 0.12, 0.15, 0.15, 0.15, 0.12],  // glove, sunglasses, cable, earbud, keys, coins, rubber bands, clips
        [0.15, 0.12, 0.3, 0.4, 0.3, 0.3, 0, 0.2],         // cigarette packet, matchbook, six-pack ring, paper bag, leaves, needles, acorns (no oak on a street), tissue
        [0.6, 0.8, 1.0, 1.1, 0.6, 1.2, 0.8, 0.7],         // pizza box, newspaper spread, cardboard, oil stain, coffee spill, puddle, grit, skid rubber
        [0.9, 1.0, 0.6, 0.6, 0.6, 0.4, 0.35, 0.9],        // leaf pile, umbrella, spilled shopping, glass cubes, map, chips bag, cup carrier, tarp
      ];
      // black-iron fire escapes on a third of the windowed blocks, cast-iron downpipes on half
      s.wallKit = render.RenderConfig.MODELS.cityWallKit;
      s.fireEscapeChance = 0.35;
      s.downpipeChance = 0.5;
      // the kerb and the walls: bags out for collection, hydrants, meters, news boxes, the gas meters,
      // and now and then a steam stack puffing (SteamPuffs). heights are the glbs' (half-metre units
      // x 0.77, DUMPSTER_H's scale)
      // the bags are DEALT per cell from three separate ones (render.world.Pile), a heap of its own
      // on every wall or kerb that takes one
      var bags:Pile = {
        kind: HEAP,
        parts: [
          {
            path: render.RenderConfig.MODELS.cityBagBlack,
            h: 1.24,
            r: 0.47,
            weight: 3,
          },
          {
            path: render.RenderConfig.MODELS.cityBagGreen,
            h: 1.19,
            r: 0.45,
            weight: 2,
          },
          {
            path: render.RenderConfig.MODELS.cityBagSmall,
            h: 0.91,
            r: 0.35,
            weight: 2,
          },
        ],
        min: 4,
        max: 8,
      };
      s.groundProps = [
        {
          path: null,
          h: 1.24,
          depth: 1.55,
          spot: WALL,
          chance: 0.025,
          turn: 0.0,
          pile: bags,
        },
        {
          path: null,
          h: 1.24,
          depth: 1.55,
          spot: KERB,
          chance: 0.012,
          turn: 0.0,
          pile: bags,
        },
        {
          path: render.RenderConfig.MODELS.cityHydrant,
          h: 1.16,
          depth: 0.77,
          spot: KERB,
          chance: 0.025,
          turn: 0.3,
        },
        {
          path: render.RenderConfig.MODELS.cityMeter,
          h: 2.0,
          depth: 0.26,
          spot: KERB,
          chance: 0.04,
          turn: 0.0,
        },
        {
          path: render.RenderConfig.MODELS.cityNewsbox,
          h: 1.69,
          depth: 0.77,
          spot: WALL,
          chance: 0.012,
          turn: 0.0,
        },
        {
          path: render.RenderConfig.MODELS.citySteamStack,
          h: 2.77,
          depth: 1.85,
          spot: KERB,
          chance: 0.008,
          turn: 0.0,
          vent: true,
        },
        {
          path: render.RenderConfig.MODELS.cityMeters,
          h: 1.79,
          depth: 0.53,
          spot: WALL,
          chance: 0.015,
          turn: 0.0,
        },
      ];
      _s = s;
    }
    return _s;
  }
}
