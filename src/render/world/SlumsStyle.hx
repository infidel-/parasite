package render.world;

import render.world.Pile.PileKind;

// slums (low-density outskirts) render knobs — the single file to tune the run-down look
// independently of the mid-density residential default. Facade slots 0-2 keep the residential
// MATERIALS (concrete/brick/stone — it is the same kind of city, just poorer) but on their own
// dilapidated street-facing art; slot 3 is still the residential warehouse verbatim. The two new
// slots are the dilapidated single-floor house types citygen remaps small leaves to: 4 clapboard
// cottage (pitched shingle gable, wooden porch canopy) and 5 cinderblock bungalow (flat tarpaper
// roof, rusted awning).
// Ground swaps to a holed sidewalk, a cracked/patched road and a dirt alley, and the houses grow
// dead-lawn patches. Textures live under textures/slums/.
class SlumsStyle {
  static var _s:AreaStyle;
  public static function get():AreaStyle {
    if (_s == null) {
      var s = new AreaStyle();
      var t = CityStyle.get();   // the medium-density style, borrowed slot by slot below
      // broken sidewalk + cracked/potholed road + dirt back alley; the kerb edging and the worn
      // road paint are already grimy enough to reuse
      s.asphalt = 'textures/slums/ground-asphalt.png';
      s.walkway = 'textures/slums/ground-walkway.png';
      s.alley = 'textures/slums/ground-alley.png';
      s.walkwayBorder = t.walkwayBorder;
      s.roadPaint = t.roadPaint;
      // 6 types [0 concrete, 1 brick, 2 stone, 3 metal warehouse, 4 clapboard cottage,
      // 5 cinderblock bungalow]. 0-2 are neglected editions of the residential art (same palette and
      // course pattern, plus soot/streaks/crumbling joints) so a masonry block reads as run-down as
      // the boarded storefront band under it; 3 stays the residential warehouse
      s.walls = [
        'textures/slums/wall-concrete.png',
        'textures/slums/wall-brick.png',
        'textures/slums/wall-stone.png',
        t.walls[3],
        'textures/slums/wall-clapboard.png',
        'textures/slums/wall-cinderblock.png',
      ];
      // the residential worn set is already a wrecked back-alley wall — no slums edition needed, and
      // it stays strictly more destroyed than the new fronts above
      s.wornWalls = [
        t.wornWalls[0],
        t.wornWalls[1],
        t.wornWalls[2],
        t.wornWalls[3],
        'textures/slums/wall-clapboard-worn.png',
        'textures/slums/wall-cinderblock-worn.png',
      ];
      // ground-floor band: boarded/grilled and dead, one per masonry slot. only 0-2 ever draw one
      // (3 is the special slot and skips the band, 4/5 are in noStoreSlots), but the array is loaded
      // eagerly — keep real paths in 3-5 so nothing 404s into the procedural fallback
      s.storefronts = [
        'textures/slums/facade-concrete.png',
        'textures/slums/facade-brick.png',
        'textures/slums/facade-stone.png',
        t.storefronts[3],
        t.storefronts[0],
        t.storefronts[0],
      ];
      // single-story shops, indexed by Building.shop [diner, corner, garage, laundromat]. all dark —
      // no lit pair, so shopOpen never applies here. the diner keeps its own wrecked front; the other
      // three share one boarded-up shopfront (a dead corner store reads the same as a dead laundromat)
      s.shopFronts = [
        'textures/slums/shop-diner-front.png',
        'textures/slums/shop-front.png',
        'textures/slums/shop-front.png',
        'textures/slums/shop-front.png',
      ];
      s.shopFrontsNd = [
        'textures/slums/shop-diner-front-nd.png',
        'textures/slums/shop-front-nd.png',
        'textures/slums/shop-front-nd.png',
        'textures/slums/shop-front-nd.png',
      ];
      // slot 4 is gabled (its flat top is hidden under the slopes); slot 5's flat tarpaper roof
      // reuses the residential tar base
      s.roofBases = [
        t.roofBases[0],
        t.roofBases[1],
        t.roofBases[2],
        t.roofBases[3],
        t.roofBases[1],
        t.roofBases[1],
      ];
      s.metalWalls = t.metalWalls;   // corrugated variants, special slot only
      s.metalWorn = t.metalWorn;
      // 4 a boarded double-hung sash, 5 a short window behind welded security bars
      s.windows = [
        t.windows[0],
        t.windows[1],
        t.windows[2],
        t.windows[3],
        'textures/slums/window-clapboard.png',
        'textures/slums/window-cinderblock.png',
      ];
      s.litWindows = [
        t.litWindows[0],
        t.litWindows[1],
        t.litWindows[2],
        t.litWindows[3],
        'textures/slums/window-clapboard-lit.png',
        'textures/slums/window-cinderblock-lit.png',
      ];
      // MUST cover every slot: Windows.add indexes winCrop by the raw slot, unwrapped. the crop is a
      // CENTRED window onto the source, so it has to be at least as large as that art's opaque extent
      // or the sash is sliced off — measure the source's alpha bounding box, do not trust the gen
      // prompt's stated size (4 came out 0.44 x 0.71, not the 0.40 x 0.48 asked for). values below are
      // the measured extents plus a small margin. the ratio IS the pane's aspect (winH = WIN_W * y/x),
      // so 4 reads as a tall double-hung sash and 5 as a squat barred one
      var wc = t.winCrop;
      s.winCrop = [wc[0], wc[1], wc[2], wc[3], { x: 0.48, y: 0.80 }, { x: 0.68, y: 0.46 }];
      s.litColor = 0xffd9a0;   // warmer + dingier than the residential glow: bare bulbs, not offices
      s.litRatio = 0.10;       // fewer lit windows — half these places are empty
      s.litIntensity = t.litIntensity;
      // entrances: 0-2 keep the residential masonry doors, 3 (warehouse) is driven by its own
      // roll-up art but still wants a real path here. 4 a torn screen door over peeling timber,
      // 5 a padlocked steel slab
      s.doors = [
        t.doors[0],
        t.doors[1],
        t.doors[2],
        t.doors[0],
        'textures/slums/door-clapboard.png',
        'textures/slums/door-cinderblock.png',
      ];
      s.doorsWorn = [
        t.doorsWorn[0],
        t.doorsWorn[1],
        t.doorsWorn[2],
        t.doorsWorn[0],
        'textures/slums/door-clapboard-worn.png',
        'textures/slums/door-cinderblock-worn.png',
      ];
      s.doorCovers = [
        t.doorCovers[0],
        t.doorCovers[1],
        t.doorCovers[2],
        t.doorCovers[0],
        'textures/slums/door-cover-clapboard.png',
        'textures/slums/door-cover-cinderblock.png',
      ];
      // 4 gets the sloped cap (a little porch roof), 5 the flat slab (a rusted sheet awning)
      s.coverShape = [0, 1, 2, 1, 2, 1];
      s.coverDims = [
        null,
        null,
        null,
        null,
        { widthFrac: 0.95, depth: 1.2, rise: 0.55, yFrac: 0.92, matTile: 2.0 }, // 4: wide sagging porch roof
        { widthFrac: 0.85, depth: 1.0, rise: 0.10, yFrac: 0.99, matTile: 2.0 }, // 5: bent sheet-metal awning
      ];
      // every slot but 3 draws art residential never draws, so every slot but 3 needs its OWN name:
      // Poly.info is first-write-wins across areas, so borrowing 'concrete'/'brick'/'stone' would make
      // the UV editor report the residential wall/storefront path for a slum surface and fold two
      // unrelated textures into one editable class (docs/3d-render.md, "Per-style facade names").
      // the -slum suffix covers the wall AND the storefront band, which was already slums-only art
      s.facadeNames = ['concrete-slum', 'brick-slum', 'stone-slum', 'metal', 'clapboard', 'cinderblock'];
      s.specialSlot = 3;          // metal warehouses stay
      s.masonrySlots = [1, 2];    // brick + stone parapets, as residential
      s.noStoreSlots = [4, 5];    // a shack is a home, not a shop
      s.gableSlots = [4];         // clapboard cottage: pitched shingle roof (the bungalow stays flat)
      s.gableRoofs = [null, null, null, null, 'textures/slums/roof-shingle.png', null];
      s.roofDowntown = false;
      s.penthouseWall = null;
      // half the street lamps are dead (post still standing, no cone, no light) and a third of the
      // survivors are failing sodium — long dark stretches with a burning barrel as the only steady light
      s.lampBrokenRatio = 0.5;
      s.lampFlickerRatio = 0.33;
      // overgrown dead yards around both house types, on about half of them
      s.lawnTex = 'textures/slums/grass-dead.png';
      s.lawnFacades = [4, 5];
      s.lawnChance = 0.5;
      s.lawnPatchChance = 0.03;
      s.lawnCourtPatches = 2;
      // the street litter: its own PACK64 (render.decals.Debris)
      s.debrisPack = 'debris-slums';
      // each litter cell's drawn longest side in world units, a row of the pack per line: the art
      // draws every cell the same size, so this is what keeps a matchbox off the scale of a flattened
      // box. pocket things about twice life so they still read at the street camera, the big flat
      // ones (rows 6-7) about life size
      s.debrisSizes = [
        [0.25, 0.25, 0.25, 0.2, 0.3, 0.3, 0.2, 0.2],      // cans, tin, bottle neck, green and clear shards, caps, butts
        [0.5, 0.5, 0.28, 0.5, 0.45, 0.35, 0.3, 0.25],     // plastic bag, bin-bag scrap, paper ball, newspaper, cardboard, flyer, wrapper, bones
        [0.15, 0.25, 0.2, 0.15, 0.25, 0.12, 0.15, 0.18],  // apple core, banana peel, crust, egg shells, noodles, matchsticks, blister pack, nails
        [0.4, 0.18, 0.4, 0.4, 0.6, 0.12, 0.45, 0.45],     // wire, bolts, brick, rubble, plank, can lid, tyre scrap, rag
        [0.32, 0.25, 0.16, 0.2, 0.1, 0.25, 0.15, 0.15],   // shoe, sock, comb, spoon and fork, batteries, cassette, cards, toy car
        [0.3, 0.32, 0.15, 0.12, 0.1, 0.15, 0.15, 0.35],   // brown bottle, plastic bottle, CD, cigarette packet, matchbox, wrappers, stubs, string
        [1.0, 0.8, 0.6, 1.1, 1.0, 1.0, 0.5, 0.7],         // flattened box, newspaper pages, foam, oil stain, puddle stain, scorch, screen glass, ash
        [0.9, 0.9, 1.0, 1.1, 1.3, 0.8, 0.9, 1.0],         // dead leaves, rubble, tarp, pallet slats, puddle, glass and gravel, blanket, garbage
      ];
      // rusted fire escapes on half the windowed buildings, and tin downpipes that have mostly lost
      // their feet
      s.wallKit = render.RenderConfig.MODELS.cityWallKitSlums;
      s.fireEscapeChance = 0.5;
      s.downpipeChance = 0.6;
      s.downpipeBroken = 0.6;
      // the junk: sacks heaped beside most dumpsters, and along the walls a cart, tyres, and in the
      // alleys a mattress. the heaps, the stacks and the cart's load are DEALT per cell from separate
      // pieces (render.world.Pile). heights are the glbs' (half-metre units x 0.77, CityStyle.DUMPSTER_H's
      // scale), a part's radius its footprint's
      var M = render.RenderConfig.MODELS;
      var sacks:Pile = {
        kind: HEAP,
        parts: [
          {
            path: M.citySackBurlap,
            h: 1.31,
            r: 0.45,
            weight: 3,
          },
          {
            path: M.citySackPlastic,
            h: 1.19,
            r: 0.38,
            weight: 2,
          },
          {
            path: M.citySackLying,
            h: 0.53,
            r: 0.42,
            weight: 1.5,
            front: true,
          },
          {
            path: M.cityCartonBox,
            h: 0.85,
            r: 0.55,
            weight: 1,
            turn: 0.5,
          },
          {
            path: M.cityCartonFlats,
            h: 0.12,
            r: 0.48,
            weight: 1.2,
            front: true,
            turn: 0.6,
          },
          {
            path: M.cityCartonLean,
            h: 1.04,
            r: 0.45,
            weight: 1.2,
            back: true,
            turn: 0.08,
          },
        ],
        min: 4,
        max: 8,
      };
      s.groundProps = [
        {
          path: null,
          h: 1.31,
          depth: 1.6,
          spot: BIN,
          chance: 0.7,
          turn: 0.0,
          pile: sacks,
        },
        {
          path: null,
          h: 1.31,
          depth: 1.6,
          spot: WALL,
          chance: 0.02,
          turn: 0.0,
          pile: sacks,
        },
        // kept off the street frontage, turned and leant a little each its own way
        {
          path: M.cityMattress,
          h: 2.82,
          depth: 1.12,
          spot: SERVICE,
          chance: 0.02,
          turn: 0.25,
          width: 1.62,
          lean: 0.06,
        },
        // empty, or loaded with sacks, flattened cartons, a bottle or two and the broken board, over
        // the basket's floor (cart.py's XB0..XB1 x YB at ZB, about the glb's centre)
        {
          path: M.cityCart,
          h: 1.55,
          depth: 1.4,
          spot: WALL,
          chance: 0.015,
          turn: 0.3,
          width: 1.54,
          pile: {
            kind: LOAD,
            parts: [
              {
                path: M.citySackBurlap,
                h: 0.7,
                r: 0.24,
                weight: 2,
              },
              {
                path: M.citySackPlastic,
                h: 0.62,
                r: 0.21,
                weight: 2,
              },
              {
                path: M.cityCartonFlats,
                h: 0.07,
                r: 0.3,
                weight: 1,
              },
              {
                path: M.cityCartBottle,
                h: 0.12,
                r: 0.2,
                weight: 2.5,
              },
              {
                path: M.cityCartBoard,
                h: 0.85,
                r: 0.3,
                weight: 1.2,
                at: [ -0.316, 0.774, -0.031 ],
              },
            ],
            min: 0,
            max: 4,
            bed: {
              x0: -0.52,
              x1: 0.53,
              z0: -0.34,
              z1: 0.34,
              y: 0.78,
            },
          },
        },
        // a stack of flat tyres at the wall's foot, the rest stood on edge against it or lying by it
        {
          path: null,
          h: 1.25,
          depth: 1.9,
          spot: WALL,
          chance: 0.02,
          turn: 0.0,
          pile: {
            kind: STACK,
            parts: [
              {
                path: M.cityTyre,
                h: 0.416,
                r: 0.504,
                weight: 2,
              },
              {
                path: M.cityTyreMud,
                h: 0.416,
                r: 0.504,
                weight: 1.5,
              },
              {
                path: M.cityTyreRim,
                h: 0.416,
                r: 0.504,
                weight: 1.2,
              },
            ],
            min: 1,
            max: 5,
          },
        },
      ];
      _s = s;
    }
    return _s;
  }
}
