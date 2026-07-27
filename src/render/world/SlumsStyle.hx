package render.world;

import render.RenderConfig;

// slums (low-density outskirts) render knobs — the single file to tune the run-down look
// independently of the mid-density residential default. Facade slots 0-3 reuse the residential
// art verbatim (it is the same kind of city, just poorer); the two new slots are the dilapidated
// single-floor house types citygen remaps small leaves to: 4 clapboard cottage (pitched shingle
// gable, wooden porch canopy) and 5 cinderblock bungalow (flat tarpaper roof, rusted awning).
// Ground swaps to a holed sidewalk, a cracked/patched road and a dirt alley, and the houses grow
// dead-lawn patches. Textures live under textures/slums/.
class SlumsStyle {
  static var _s:AreaStyle;
  public static function get():AreaStyle {
    if (_s == null) {
      var s = new AreaStyle();
      var t = RenderConfig.TEXTURES;
      // broken sidewalk + cracked/potholed road + dirt back alley; the kerb edging and the worn
      // road paint are already grimy enough to reuse
      s.asphalt = 'textures/slums/ground-asphalt.png';
      s.walkway = 'textures/slums/ground-walkway.png';
      s.alley = 'textures/slums/ground-alley.png';
      s.walkwayBorder = t.walkwayBorder;
      s.roadPaint = t.roadPaint;
      // 6 types [0 concrete, 1 brick, 2 stone, 3 metal warehouse, 4 clapboard cottage,
      // 5 cinderblock bungalow]. 0-3 are the residential set unchanged
      s.walls = [
        t.walls[0],
        t.walls[1],
        t.walls[2],
        t.walls[3],
        'textures/slums/wall-clapboard.png',
        'textures/slums/wall-cinderblock.png',
      ];
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
      var wc = RenderConfig.WINDOW_SPRITE_CROP;
      s.winCrop = [wc[0], wc[1], wc[2], wc[3], { x: 0.48, y: 0.80 }, { x: 0.68, y: 0.46 }];
      s.litColor = 0xffd9a0;   // warmer + dingier than the residential glow: bare bulbs, not offices
      s.litRatio = 0.10;       // fewer lit windows — half these places are empty
      s.litIntensity = RenderConfig.WINDOW_LIT_INTENSITY;
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
      // this style reuses the residential indices for the same art, but adds two slots of its own —
      // it must name all six or the UV editor labels a cottage 'sleek' (Poly.info is first-write-wins)
      s.facadeNames = ['concrete', 'brick', 'stone', 'metal', 'clapboard', 'cinderblock'];
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
      _s = s;
    }
    return _s;
  }
}
