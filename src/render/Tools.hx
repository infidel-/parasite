package render;

// single active "tool" so the poly UV editor (E) and the building inspector (B)
// are mutually exclusive — turning one on turns the other off. Modules read `mode`
// and register listen() to refresh their own HUD when it changes.
class Tools {
  public static var enabled:Bool = false; // master gate: street-debug mode active?
  public static var mode:String = 'none'; // 'select' | 'edit' | 'none'

  static var listeners:Array<Void->Void> = [];
  public static function listen(f:Void->Void):Void listeners.push(f);
  public static function setMode(m:String):Void {
    if (mode == m) return;
    mode = m;
    for (l in listeners) l();
  }
}
