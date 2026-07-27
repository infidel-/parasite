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
      var c = CityStyle.get();   // the medium-density style, borrowed slot by slot below
      // roads unchanged; unique plaza walkway + clean service alley (border reuses residential kerb)
      s.asphalt = c.asphalt;
      s.walkway = 'textures/downtown/ground-walkway.png';
      s.walkwayBorder = c.walkwayBorder;
      s.roadPaint = c.roadPaint;
      s.alley = 'textures/downtown/ground-alley.png';
      // 5 types [0 concrete mid-rise, 1 stone mid-rise, 2 mostly-glass tower, 3 full-glass tallest,
      // 4 sleek modern high-rise]. 0/1 reuse the residential clean walls (medium-city look
      // interspersed among the towers, low only); 2 gets the mullioned curtain art, 3 the dense
      // edge-to-edge full-glass wall, 4 pale precast piers alternating with dark vertical glass ribbons
      s.walls = [
        c.walls[0],
        c.walls[2],
        'textures/downtown/glass-light.png',
        'textures/downtown/glass-dark.png',
        'textures/downtown/glass-sleek.png',
      ];
      // 0/1 keep their residential worn/alley backs; glass towers go to the dark spandrel service
      // back ("no back walls")
      var back = 'textures/downtown/facade-glass-back.png';
      s.wornWalls = [
        c.wornWalls[0],
        c.wornWalls[2],
        back,
        back,
        back,
      ];
      // ground floor: mid-rise bays reuse residential storefronts, glass towers get a glass lobby
      var lobby = 'textures/downtown/storefront-lobby.png';
      s.storefronts = [
        c.storefronts[0],
        c.storefronts[2],
        lobby,
        lobby,
        lobby,
      ];
      // mid-rises keep a residential tar/concrete roof base; glass towers get the downtown base
      var roofBase = 'textures/downtown/roof-base.png';
      s.roofBases = [
        c.roofBases[0],
        c.roofBases[1],
        roofBase,
        roofBase,
        roofBase,
      ];
      // no metal-warehouse slot downtown; keep the arrays non-null (unused)
      s.metalWalls = s.walls;
      s.metalWorn = s.wornWalls;
      // 0/1 use residential punched windows (medium look), 2/3 the glass curtain panels
      var win = 'textures/downtown/window-glass.png';
      var winLit = 'textures/downtown/window-glass-lit.png';
      s.windows = [c.windows[0], c.windows[2], win, win, win];
      s.litWindows = [c.litWindows[0], c.litWindows[2], winLit, winLit, winLit];
      var glassCrop = { x: 0.5, y: 0.86 };
      s.winCrop = [c.winCrop[0], c.winCrop[2], glassCrop, glassCrop, glassCrop];
      s.litColor = 0xc8d6ec;   // neutral cool office glow (warm mid-rise + cool glass share one)
      s.litRatio = 0.12;
      s.litIntensity = 1.9;
      s.noWinSlots = [2, 3, 4];   // glass + sleek: windows are in the curtain-wall art, no overlay quads
      s.winPerCell = [0, 0, 1, 1, 1]; // glass (2/3) + sleek (4): one window per cell, cell-locked → whole windows, constant scale
      s.noBackWallsFloors = 6;     // a downtown high-rise is windowed on all four sides — office towers don't have alley backs
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
      // sleek (4) carries NO tint variants (empty set, not null → the lit path still runs; the
      // nVar==0 guard in Windows.addGlassAccents makes it lit-panes-only)
      s.glassAccents = [null, null, lightAccents, darkAccents, []];
      s.glassAccentLit = [
        null,
        null,
        'textures/downtown/glass-accent-light-lit.png',
        'textures/downtown/glass-accent-dark-lit.png',
        'textures/downtown/window-sleek-lit.png',
      ];
      s.glassAccentRatio = 0.15;   // ~15% of panes get a tint variant
      s.glassLitRatio = 0.06;      // ~6% lit/glowing
      s.glassLitIntensity = 2.2;   // skyscraper glow strength (tune here, separate from mid-rise window glow)
      // per glass tower type: facade 2 (light) → emerald-green Tokyo glow, facade 3 (dark) → warm
      // office, facade 4 (sleek) → cool-white
      s.glassLitColor = [0, 0, 0x9fe8c6, 0xffe6c2, 0xdfe8f2];
      // opaque band over the baked curtain wall: a polished-granite plinth at street level, so
      // the bottom two floors read solid, not glass
      s.glassPodium = [
        null,
        null,
        'textures/downtown/podium-light.png',
        'textures/downtown/podium-dark.png',
        'textures/downtown/podium-sleek.png',
      ];
      // entrances: 0 concrete + 1 STONE mid-rise reuse the residential masonry door art
      // (facade 1 is wall-3/stone downtown, not brick), the glass towers get lobby doors,
      // a shared steel service door on their blanked backs, and a flat metal canopy
      s.doors = [
        c.doors[0],
        c.doors[2],
        'textures/downtown/entrance-glass-light.png',
        'textures/downtown/entrance-glass-dark.png',
        'textures/downtown/entrance-sleek.png',
      ];
      var service = 'textures/downtown/entrance-service.png';
      s.doorsWorn = [
        c.doorsWorn[0],
        c.doorsWorn[2],
        service,
        service,
        service,
      ];
      // canopy swatches: light tower gets the gunmetal sheet, dark tower its own near-black
      // blackened-bronze one (the shared sheet read too pale against the blue-glass wall)
      s.doorCovers = [
        c.doorCovers[0],
        c.doorCovers[2],
        'textures/downtown/door-cover-glass.png',
        'textures/downtown/door-cover-glass-dark.png',
        'textures/downtown/door-cover-sleek.png',
      ];
      s.coverShape = [0, 2, 1, 1, 1]; // concrete half-barrel, stone inset cap, glass + sleek flat canopy
      // per-slot cover sizes — `rise` means barrel radius (shape 0), gable rise (shape 2) or slab
      // thickness (shape 1). the mid-rise slots hold the residential values; the three tower slots
      // are the tunable ones (a 0.07 slab on a 30-storey lobby is the current, thin, look)
      s.coverDims = [
        { widthFrac: 0.7, depth: 0.8, rise: 0.5,  yFrac: 0.9,  matTile: 2.5 }, // 0 concrete: half-barrel
        { widthFrac: 0.7, depth: 0.8, rise: 0.5,  yFrac: 0.9,  matTile: 2.5 }, // 1 stone: sloped cap
        { widthFrac: 0.7, depth: 0.8, rise: 0.07, yFrac: 0.89, matTile: 2.5 }, // 2 glass-light: flat canopy
        { widthFrac: 0.7, depth: 0.8, rise: 0.07, yFrac: 0.85, matTile: 2.5 }, // 3 glass-dark: flat canopy
        { widthFrac: 0.7, depth: 0.8, rise: 0.07, yFrac: 0.85, matTile: 2.5 }, // 4 sleek: flat canopy
      ];
      // downtown reuses the facade indices for different art than residential, so it must name its
      // own slots: slot 1 IS stone here (wall-3, residential's index 2) and slots 2/3 are the glass
      // curtain walls. without this the UV editor labels a glass tower 'wall-stone' and folds it into
      // the residential stone class
      s.facadeNames = ['concrete', 'stone', 'glass-light', 'glass-dark', 'sleek'];
      s.bloomThreshold = 0.5;     // WHEN the skyscraper glow starts (luminance cutoff); lower = glows sooner. per downtown-area, separate from residential
      s.specialSlot = -1;      // no metal warehouses
      s.roofDowntown = true;
      s.penthouseWall = 'textures/downtown/wall-mechanical.png';
      // downtown swaps the residential lamp for the PBR street-lamp2 prop. NOTE the offsets below are
      // rotated by the lamp yaw ONLY — Models.yawFix's extra -PI/2 for this prop turns the MODEL, not
      // the offset frame, so local +Z is still "toward the road" here: the arm reach belongs in dz.
      // the post sits one CELL/2 back from the cell centre, i.e. exactly on the walkway/road edge
      // (residential pdz 2.6 overhangs the kerb by 0.6; a downtown post standing in the gutter reads
      // wrong against the wide pavements). height/cone + the shared live-spotlight pool stay on
      // RenderConfig.LAMP_LIGHT
      s.lamp = {
        model: render.RenderConfig.MODELS.streetLamp2,
        dx: 0.0,
        dz: 0.8,
        pdx: 2.0,
        pdz: 2.45,
      };
      // roughly a third of the roofs big and tall enough for one trade their bulkhead + AC clutter
      // for a landing deck — rare enough that a lit pad still reads as a landmark from the street
      s.helipadTex = 'textures/downtown/helipad.png';
      s.helipadChance = 0.35;
      s.helipadFacades = [2, 3]; // glass skyscrapers only (light + dark); not concrete/stone mid-rises or the sleek high-rise
      _s = s;
    }
    return _s;
  }
}
