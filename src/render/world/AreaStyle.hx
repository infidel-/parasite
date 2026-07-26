package render.world;

import render.RenderConfig;

// per-facade entrance-cover geometry (Entrances.placeCover). `rise` is the cover's VERTICAL size and
// its meaning follows that facade's coverShape: 0 = half-barrel radius, 1 = slab thickness,
// 2 = eave→ridge rise. sizes are world units except the two fractions
typedef CoverDim = {
  widthFrac:Float,  // cover width as a fraction of the door quad side (~ door-panel width, not wall-wide)
  depth:Float,      // how far it juts OUT from the wall
  rise:Float,       // vertical size — read per coverShape (barrel radius / slab thickness / gable rise)
  yFrac:Float,      // cover BOTTOM sits at this fraction of the door quad height
  matTile:Float,    // world units per material-swatch tile (never stretch the swatch)
};

// per-area street-lamp prop: which lamp model to instance + where its bulb/post sit relative to the
// cell (SceneSetup places the post at pdx/pdz within the cell, the bulb at dx/dz out from the post).
// the bulb HEIGHT (LAMP_LIGHT.yMul), cone (angle) and the shared live-spotlight pool stay global —
// only the model geometry differs per area, so a swap never changes NUM_SPOT_LIGHTS (no recompile)
typedef LampProp = {
  model:String, // lamp prop glb (render.Models.instanced)
  dx:Float,     // bulb local +X offset from the post
  dz:Float,     // bulb local +Z (toward-road) offset from the post
  pdx:Float,    // post local +X nudge within its cell (slides along the road/wall)
  pdz:Float,    // post local +Z nudge (+toward road edge, -toward the wall)
};

// per-area render knobs: the texture sets + facade behavior the world sub-builders
// (Ground/Buildings/Windows/Roofs) would otherwise hardcode. DEFAULT reuses the exact
// same TEXTURES arrays and RenderConfig constants the code reads today (identical
// references → residential output pixel-identical); DOWNTOWN (DowntownStyle) swaps them for
// the skyscraper look and SLUMS (SlumsStyle) for the run-down outskirts — each is the single
// file to tune its look. Selected per build from the area type (see forArea). Threaded via
// WorldCtx.style.
class AreaStyle {
  // --- ground tile textures (Ground.hx) ---
  public var asphalt:String;
  public var alley:String;
  public var walkway:String;
  public var walkwayBorder:String;
  public var roadPaint:String;
  // --- facade texture sets, indexed by Building.facade (Buildings.hx/Roofs.hx) ---
  public var walls:Array<String>;        // clean street-facing walls
  public var wornWalls:Array<String>;    // worn/back/buried faces (downtown: dark service back)
  public var storefronts:Array<String>;  // ground-floor band
  public var roofBases:Array<String>;    // flat-roof top
  public var metalWalls:Array<String>;   // per-building corrugated variants (special slot only)
  public var metalWorn:Array<String>;
  // --- windows (Windows.hx) ---
  public var windows:Array<String>;      // dark window/panel sprites by facade
  public var litWindows:Array<String>;   // lit variants
  public var winCrop:Array<{ x:Float, y:Float }>; // per-facade sprite crop
  public var litColor:Int;               // lit-window glow color
  public var litRatio:Float;             // fraction of windows lit
  public var litIntensity:Float;         // emissive intensity
  // --- facade behavior ---
  public var noWinSlots:Array<Int> = null;  // facade slots that skip the window overlay (glass curtain walls carry windows in the facade art); null = none
  public var winPerCell:Array<Int> = null;  // glass curtain slots: windows per CELL. locks the window grid to the cell grid (integer tiling → whole windows, identical pitch CELL/k on every tower); needs a seamless single-window texture. null/0 = normal tiling
  public var masonrySlots:Array<Int> = null; // facades whose parapet is the WALL texture continuing up (brick/stone look) instead of a thin coping rim; null = the historic [1, 2]
  public var noStoreSlots:Array<Int> = null; // facades that never grow a ground-floor storefront band, whatever their footprint rolls (a shack is not a shop); null = none
  public var gableSlots:Array<Int> = null;   // facades roofed with a pitched gable prism instead of a flat parapet, ON TOP of specialSlot (which always gables); null = none
  public var gableRoofs:Array<String> = null; // per facade: the gable SLOPE texture; null (or null entry) = the shared metal roof
  public var noBackWallsFloors:Int = 0;     // from this storey count up, a building has NO back: every face is clean + windowed, whatever it abuts (a blank worn wall a dozen storeys tall reads as a mistake). 0 = off, backs everywhere
  // --- glass-tower sparse accents (Windows.addGlassAccents), indexed by Building.facade ---
  public var glassAccents:Array<Array<String>> = null; // per facade: the tint-variant tiles scattered over that slot's baked glass grid; null (or null entry) = no accents
  public var glassAccentLit:Array<String> = null;      // per facade: lit/glowing single-window tile (emissive + bloom); null (or null entry) = no lit panes
  public var glassAccentRatio:Float = 0.15;     // fraction of glass cells that get a scattered tint accent
  public var glassLitRatio:Float = 0.05;        // fraction of glass cells that are lit/glowing
  public var glassLitIntensity:Float = 1.9;     // glow strength of lit glass panes — separate from the mid-rise window glow (litIntensity)
  public var glassLitColor:Array<Int> = null;   // per facade: glow tint of lit glass panes (multiplies the lit texture); null entry = white (texture colour only)
  // --- glass-tower opaque band (Buildings), indexed by Building.facade ---
  public var glassPodium:Array<String> = null;  // per facade: solid street-level plinth over the bottom CityConfig.GLASS_PODIUM_ROWS window rows; null (or null entry) = none
  // --- single-story shop bays (Buildings), indexed by Building.shop, NOT by facade ---
  // a whole-area override of the shared RenderConfig.TEXTURES.shopFront* set. non-null means every shop
  // in this area is dark: Building.shopOpen is ignored and there is no lit variant to pick, which is the
  // point for slums (boarded up, nobody home). null = the residential lit/unlit pair keyed on shopOpen
  public var shopFronts:Array<String> = null;   // per shop type: the bay carrying the entrance door
  public var shopFrontsNd:Array<String> = null; // per shop type: the door-less continuation bay
  // --- entrances (Entrances.hx), indexed by Building.facade ---
  public var doors:Array<String>;        // clean street-facing pedestrian door art
  public var doorsWorn:Array<String>;    // service/maintenance door art for worn faces
  public var doorCovers:Array<String>;   // material swatch for the lintel/canopy over a front door
  public var coverShape:Array<Int>;      // which cover geometry a facade uses: 0 half-barrel, 1 flat metal slab, 2 inset sloped cap
  public var coverDims:Array<CoverDim> = null; // per facade: that cover's size knobs; null array or null entry = the shape's RenderConfig defaults
  // --- bloom (post-process, per area) ---
  public var bloomThreshold:Float = RenderConfig.BLOOM_THRESHOLD; // luminance a pane must exceed before it visibly blooms — WHEN the glow starts. lower = glows sooner/easier. per-area (downtown can differ from residential); note bloom is one global pass, so this affects all glow in that area's scene
  // --- debug/editor naming ---
  // per-facade name used to build the Poly class strings (wall-$n, roof-$n, storefront-$n, door-$n,
  // door-cover-$n) and the BDump facade label. MUST describe what THIS style puts in that slot: the
  // classes are the UV editor's handles and Poly.info is first-write-wins across areas, so a style
  // that borrows the residential names for different art makes the editor claim the wrong texture
  // and silently share one class between two unrelated surfaces. defaults to the residential naming
  public var facadeNames:Array<String> = RenderConfig.FACADE_NAMES;
  public var specialSlot:Int;            // metal-warehouse facade slot (gable roof, roll-up door, no windows); -1 = none
  public var roofDowntown:Bool;          // flat roof + mechanical penthouse instead of residential parapet/gable
  public var penthouseWall:String;       // downtown rooftop bulkhead wall (roofDowntown only)
  // --- street lamp prop (SceneSetup.buildScene) ---
  public var lamp:LampProp = null;       // lamp model + bulb/post offsets; null = residential (RenderConfig.MODELS.streetLamp + LAMP_LIGHT offsets)
  // decided per lamp CELL, deterministic, no rng and nothing persisted. these change only WHICH lamps
  // burn, never LAMP_LIGHT.pool — so NUM_SPOT_LIGHTS stays constant and no lit material recompiles
  public var lampBrokenRatio:Float = 0;  // odds a lamp is dead: its post still stands, but it gets no light cone and never claims a spotlight slot
  public var lampFlickerRatio:Float = 0; // odds a WORKING lamp sputters (failing sodium) instead of burning steady
  // --- dead-lawn ground patches around houses (Lawns.hx) ---
  public var lawnTex:String = null;          // ragged dead-grass patch (alpha cutout); null = this area has no lawns
  public var lawnFacades:Array<Int> = null;  // facade slots whose buildings grow a lawn ring on the alley cells around them
  public var lawnChance:Float = 0;           // odds an eligible building gets one (deterministic per footprint, no rng)
  public var lawnPatchChance:Float = 0;      // odds any loose alley/courtyard cell seeds a stray patch, away from any building
  public var lawnCourtPatches:Int = 0;       // patches planted near the centroid of EVERY courtyard, so an open yard is never bare
  // --- rooftop helipad (Roofs.helipadRect), tall towers only ---
  public var helipadTex:String = null;   // top-down landing-deck marking; null = this area has no helipads
  public var helipadChance:Float = 0;    // odds an ELIGIBLE roof (tall + wide enough) gets one instead of its penthouse and detail decals
  public var helipadFacades:Array<Int> = null; // facade slots that may carry a pad; null = any (downtown limits it to the glass skyscrapers, not the mid-rises/sleek high-rise)

  public function new() {}

  // is this facade the metal-warehouse special slot (gable/door/windowless)?
  public inline function isSpecial(f:Int):Bool
    return specialSlot >= 0 && f == specialSlot;

// name of a facade slot in THIS style, for Poly class strings and debug labels
  public inline function facadeName(f:Int):String
    return facadeNames[f % facadeNames.length];

// does this facade's parapet continue the wall texture upward (brick/stone) instead of
// carrying a thin coping rim? defaults to the historic hardcoded brick+stone slots
  public inline function isMasonry(f:Int):Bool
    return masonrySlots == null ? (f == 1 || f == 2) : masonrySlots.indexOf(f) >= 0;

// is this facade roofed with a pitched gable prism? the metal-warehouse slot always is;
// a style may gable extra slots (the slums clapboard cottage)
  public inline function isGable(f:Int):Bool
    return isSpecial(f) || (gableSlots != null && gableSlots.indexOf(f) >= 0);

// entrance-cover size knobs for a facade slot, falling back to the shape's RenderConfig defaults
  public function coverDim(f:Int):CoverDim
    {
      if (coverDims != null && coverDims[f] != null)
        return coverDims[f];
      return defaultCoverDim(coverShape[f]);
    }

// the historic per-shape cover sizes, straight off the RenderConfig globals. a style that says
// nothing about a slot renders exactly what it did before coverDims existed
  public static function defaultCoverDim(shape:Int):CoverDim
    {
      return {
        widthFrac: RenderConfig.COVER_WIDTH_FRAC,
        depth: RenderConfig.COVER_DEPTH,
        rise: shape == 0 ? RenderConfig.COVER_BARREL_R
          : shape == 2 ? RenderConfig.COVER_SLOPE_RISE
          : RenderConfig.COVER_METAL_H,
        // the flat slab rides at the door top: a thin sheet can't hide a door poking above it,
        // so it sits higher than the thick covers' anchor
        yFrac: shape == 1 ? 0.85 : RenderConfig.COVER_Y_FRAC,
        matTile: RenderConfig.COVER_MAT_TILE,
      };
    }

  static var _default:AreaStyle;
  // the residential style — every field is the value/array the sub-builders use today
  public static var DEFAULT(get, null):AreaStyle;
  static function get_DEFAULT():AreaStyle {
    if (_default == null) {
      var s = new AreaStyle();
      var t = RenderConfig.TEXTURES;
      s.asphalt = t.asphalt;
      s.alley = t.alley;
      s.walkway = t.walkway;
      s.walkwayBorder = t.walkwayBorder;
      s.roadPaint = t.roadPaint;
      s.walls = t.walls;
      s.wornWalls = t.wornWalls;
      s.storefronts = t.storefronts;
      s.roofBases = t.roofBases;
      s.metalWalls = t.metalWalls;
      s.metalWorn = t.metalWorn;
      s.windows = t.windows;
      s.litWindows = t.litWindows;
      s.winCrop = RenderConfig.WINDOW_SPRITE_CROP;
      s.litColor = RenderConfig.WINDOW_LIT_COLOR;
      s.litRatio = RenderConfig.LIT_RATIO;
      s.litIntensity = RenderConfig.WINDOW_LIT_INTENSITY;
      s.doors = t.doors;
      s.doorsWorn = t.doorsWorn;
      s.doorCovers = t.doorCovers;
      s.coverShape = [0, 1, 2]; // concrete half-barrel, brick flat slab, stone inset cap
      s.specialSlot = 3;         // metal warehouse
      s.roofDowntown = false;
      s.penthouseWall = null;
      _default = s;
    }
    return _default;
  }

  // pick the render style for a build from the area type: downtown for the high-density
  // district, slums for the low-density outskirts, residential default for everything else.
  // MUST stay in step with citygen's CityProfile.Profiles.forArea — a style/profile mismatch
  // renders facade slots the generator never emitted
  public static function forArea(t:_AreaType):AreaStyle
    return switch (t) {
      case AREA_CITY_HIGH: DowntownStyle.get();
      case AREA_CITY_LOW: SlumsStyle.get();
      default: DEFAULT;
    };
}
