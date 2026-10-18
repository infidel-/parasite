package render;

// single active "tool" so the poly UV editor (E) and the building inspector (B)
// are mutually exclusive — turning one on turns the other off. Modules read `mode`
// and register listen() to refresh their own HUD when it changes.
//
// each tool also registers the LEGEND for its mode here, and render.Debug swaps the
// bottom-left #help block to it on every mode change — one hardcoded block listing
// every key of every mode at once is unreadable the moment a tool has more than
// three of its own
class Tools {
  public static var enabled:Bool = false; // master gate: street-debug mode active?
  public static var mode:String = 'none'; // 'none' | 'select' | 'edit' | 'poly' | 'paint'
  public static var freeCam:FreeCam = null; // set when the debug tools attach (used by __check.goto)

  // per-mode control legend, shown in #help while that mode is active
  public static final legends:Map<String, String> = new Map();
  public static function legend(m:String, text:String):Void legends.set(m, text);

  static var listeners:Array<Void->Void> = [];
  public static function listen(f:Void->Void):Void listeners.push(f);
  public static function setMode(m:String):Void {
    if (mode == m) return;
    mode = m;
    for (l in listeners) l();
  }
}
