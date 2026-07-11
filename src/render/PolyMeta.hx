package render;

// per-polygon-class texture UV offset overrides (ADDITIONAL offset, in UV
// fractions: 1.0 = one full texture width; wraps mod 1 under RepeatWrapping).
//
// Tuned live in-browser: edit mode (E) → click a polygon → mouse wheel scrolls V,
// alt+wheel scrolls U, shift = 1/10 step. Live edits live in localStorage and
// survive reload; Ctrl+C copies an `update info: <json>` prompt — paste it back and
// it gets merged in here. Once merged, the matching localStorage edit auto-clears
class PolyMeta {
  public static final OVERRIDES:Map<String, { offset:{ u:Float, v:Float } }> = [
    // "coping-top" => { offset: { u: 0, v: 0.012 } },
  ];
}
