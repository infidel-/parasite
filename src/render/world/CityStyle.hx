package render.world;

// medium-density residential render knobs — the single file to tune the default city look,
// the one every area that is not the downtown core or the low-density outskirts renders with.
// Masonry mid-rises (concrete/brick/stone) plus a metal-warehouse special slot, punched windows
// with a warm glow, parapet or gable roofs, single-story shop bays along the street.
// This is also the style the other two BORROW from: DowntownStyle and SlumsStyle read slots off
// CityStyle.get() for every facade they reuse verbatim, so a path fixed here fixes all three.
// Textures live under textures/city/.
class CityStyle {
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
      _s = s;
    }
    return _s;
  }
}
