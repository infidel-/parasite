package render.world;

import render.RenderConfig;

// per-area render knobs: the texture sets + facade behavior the world sub-builders
// (Ground/Buildings/Windows/Roofs) would otherwise hardcode. DEFAULT reuses the exact
// same TEXTURES arrays and RenderConfig constants the code reads today (identical
// references → residential output pixel-identical); DOWNTOWN (DowntownStyle) swaps them
// for the skyscraper look and is the single file to tune it. Selected per build from the
// area's downtownGen flag (see forDowntown). Threaded via WorldCtx.style.
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
  // --- glass-tower sparse accents (Windows.addGlassAccents), indexed by Building.facade ---
  public var glassAccents:Array<Array<String>> = null; // per facade: the tint-variant tiles scattered over that slot's baked glass grid; null (or null entry) = no accents
  public var glassAccentLit:Array<String> = null;      // per facade: lit/glowing single-window tile (emissive + bloom); null (or null entry) = no lit panes
  public var glassAccentRatio:Float = 0.15;     // fraction of glass cells that get a scattered tint accent
  public var glassLitRatio:Float = 0.05;        // fraction of glass cells that are lit/glowing
  public var glassLitIntensity:Float = 1.9;     // glow strength of lit glass panes — separate from the mid-rise window glow (litIntensity)
  public var glassLitColor:Array<Int> = null;   // per facade: glow tint of lit glass panes (multiplies the lit texture); null entry = white (texture colour only)
  // --- bloom (post-process, per area) ---
  public var bloomThreshold:Float = RenderConfig.BLOOM_THRESHOLD; // luminance a pane must exceed before it visibly blooms — WHEN the glow starts. lower = glows sooner/easier. per-area (downtown can differ from residential); note bloom is one global pass, so this affects all glow in that area's scene
  public var specialSlot:Int;            // metal-warehouse facade slot (gable roof, roll-up door, no windows); -1 = none
  public var roofDowntown:Bool;          // flat roof + mechanical penthouse instead of residential parapet/gable
  public var penthouseWall:String;       // downtown rooftop bulkhead wall (roofDowntown only)

  public function new() {}

  // is this facade the metal-warehouse special slot (gable/door/windowless)?
  public inline function isSpecial(f:Int):Bool
    return specialSlot >= 0 && f == specialSlot;

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
      s.specialSlot = 3;         // metal warehouse
      s.roofDowntown = false;
      s.penthouseWall = null;
      _default = s;
    }
    return _default;
  }

  // pick the render style for a build: downtown for high-density areas generated under the
  // downtown code (AreaGame.downtownGen), else residential default
  public static function forDowntown(downtown:Bool):AreaStyle
    return downtown ? DowntownStyle.get() : DEFAULT;
}
