package render.world;

// downtown (skyscraper) render knobs — the single file to tune the high-density look
// independently of residential. Glass office towers with a baked mullion facade, dark
// blanked service backs, a unique plaza walkway + clean service alley, flat roofs with a
// mechanical penthouse, cooler/sparser lit windows. Textures live under textures/downtown/.
class DowntownStyle {
  static var _s:AreaStyle;
  public static function get():AreaStyle {
    if (_s == null) {
      var s = new AreaStyle();
      // roads unchanged; unique plaza walkway + clean service alley (border reuses residential kerb)
      s.asphalt = 'textures/ground-asphalt.png';
      s.walkway = 'textures/downtown/ground-walkway.png';
      s.walkwayBorder = 'textures/ground-walkway-border.png';
      s.roadPaint = 'textures/ground-road-paint.png';
      s.alley = 'textures/downtown/ground-alley.png';
      // 4 types [0 concrete mid-rise, 1 stone mid-rise, 2 mostly-glass tower, 3 full-glass tallest].
      // 0/1 reuse the residential clean walls (medium-city look interspersed among the towers);
      // 2 gets the mullioned curtain art, 3 the dense edge-to-edge full-glass wall
      s.walls = [
        'textures/wall-1.png',
        'textures/wall-3.png',
        'textures/downtown/glass-light.png',
        'textures/downtown/glass-dark.png',
      ];
      // 0/1 keep their residential worn/alley backs; glass towers go to the dark spandrel service
      // back ("no back walls")
      var back = 'textures/downtown/facade-glass-back.png';
      s.wornWalls = [
        'textures/wall-1-worn.png',
        'textures/wall-3-worn.png',
        back,
        back,
      ];
      // ground floor: mid-rise bays reuse residential storefronts, glass towers get a glass lobby
      var lobby = 'textures/downtown/storefront-lobby.png';
      s.storefronts = [
        'textures/facade-concrete.png',
        'textures/facade-stone.png',
        lobby,
        lobby,
      ];
      // mid-rises keep a residential tar/concrete roof base; glass towers get the downtown base
      var roofBase = 'textures/downtown/roof-base.png';
      s.roofBases = [
        'textures/roof-base-concrete.png',
        'textures/roof-base.png',
        roofBase,
        roofBase,
      ];
      // no metal-warehouse slot downtown; keep the arrays non-null (unused)
      s.metalWalls = s.walls;
      s.metalWorn = s.wornWalls;
      // 0/1 use residential punched windows (medium look), 2/3 the glass curtain panels
      var win = 'textures/downtown/window-glass.png';
      var winLit = 'textures/downtown/window-glass-lit.png';
      s.windows = ['textures/window-1.png', 'textures/window-3.png', win, win];
      s.litWindows = ['textures/window-lit-1.png', 'textures/window-lit-3.png', winLit, winLit];
      var glassCrop = { x: 0.5, y: 0.86 };
      s.winCrop = [{ x: 0.42, y: 0.42 }, { x: 0.46, y: 0.82 }, glassCrop, glassCrop];
      s.litColor = 0xc8d6ec;   // neutral cool office glow (warm mid-rise + cool glass share one)
      s.litRatio = 0.12;
      s.litIntensity = 1.9;
      s.noWinSlots = [2, 3];   // glass towers: windows are in the curtain-wall art, no overlay quads
      s.winPerCell = [0, 0, 1, 1]; // glass towers (2/3): one window per cell, cell-locked → whole windows, constant scale
      // sparse scattered accents over the uniform baked glass grid (4 tint variants + 1 lit pane),
      // split into two distinct families so the two glass tower types read differently:
      // facade 2 (glass-1, silver base) → LIGHT family, facade 3 (glass-full, blue base) → DARK family
      var lightAccents = [
        'textures/downtown/glass-accent-light-1.png',
        'textures/downtown/glass-accent-light-2.png',
        'textures/downtown/glass-accent-light-3.png',
        'textures/downtown/glass-accent-light-4.png',
      ];
      var darkAccents = [
        'textures/downtown/glass-accent-dark-1.png',
        'textures/downtown/glass-accent-dark-2.png',
        'textures/downtown/glass-accent-dark-3.png',
        'textures/downtown/glass-accent-dark-4.png',
      ];
      s.glassAccents = [null, null, lightAccents, darkAccents];
      s.glassAccentLit = [
        null,
        null,
        'textures/downtown/glass-accent-light-lit.png',
        'textures/downtown/glass-accent-dark-lit.png',
      ];
      s.glassAccentRatio = 0.15;   // ~15% of panes get a tint variant
      s.glassLitRatio = 0.06;      // ~6% lit/glowing
      s.glassLitIntensity = 2.2;   // skyscraper glow strength (tune here, separate from mid-rise window glow)
      // per glass tower type: facade 2 (light) → emerald-green Tokyo glow, facade 3 (dark) → warm office
      s.glassLitColor = [0, 0, 0x9fe8c6, 0xffe6c2];
      // opaque bands over the baked curtain wall: a polished-granite plinth at street level
      // (the bottom two floors read solid, not glass) and a dark spandrel cap the parapet
      // coping sits on — the coping's overhang used to eat the top window row
      s.glassPodium = [
        null,
        null,
        'textures/downtown/podium-light.png',
        'textures/downtown/podium-dark.png',
      ];
      s.glassCap = [null, null, back, back];
      // entrances: 0 concrete + 1 STONE mid-rise reuse the residential masonry door art
      // (facade 1 is wall-3/stone downtown, not brick), the glass towers get lobby doors,
      // a shared steel service door on their blanked backs, and a flat metal canopy
      s.doors = [
        'textures/door-concrete.png',
        'textures/door-stone.png',
        'textures/downtown/entrance-glass-light.png',
        'textures/downtown/entrance-glass-dark.png',
      ];
      var service = 'textures/downtown/entrance-service.png';
      s.doorsWorn = [
        'textures/door-concrete-worn.png',
        'textures/door-stone-worn.png',
        service,
        service,
      ];
      var glassCover = 'textures/downtown/door-cover-glass.png';
      s.doorCovers = [
        'textures/door-cover-concrete.png',
        'textures/door-cover-stone.png',
        glassCover,
        glassCover,
      ];
      s.coverShape = [0, 2, 1, 1]; // concrete half-barrel, stone inset cap, glass towers flat canopy
      s.bloomThreshold = 0.5;     // WHEN the skyscraper glow starts (luminance cutoff); lower = glows sooner. per downtown-area, separate from residential
      s.specialSlot = -1;      // no metal warehouses
      s.roofDowntown = true;
      s.penthouseWall = 'textures/downtown/wall-mechanical.png';
      _s = s;
    }
    return _s;
  }
}
