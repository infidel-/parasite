// one AI entity badge: atlas cell (col,row) for the 2D view + PNG 3D badges; svg is a UISvg
// glyph key when the 3D view should render it as a scalable SVG instead (null = PNG atlas cell).
// count = live active-effect number baked into the 'multieffect' triangle glyph (null otherwise)
typedef _Badge = { col: Int, row: Int, ?svg: String, ?count: Int };
