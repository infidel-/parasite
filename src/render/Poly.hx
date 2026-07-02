package render;

import three.Three;

typedef PolyInfo = { name:String, tex:String, res:Int };

// polygon class registry for the in-browser texture-UV editor. Every tunable face
// material is tagged with a class string; its texture is registered here so editing
// a class shifts that texture's UV offset on EVERY polygon of that kind at once.
// baseOff remembers each texture's original offset so class edits are ADDITIONAL
class Poly {
  public static final tex:Map<String, Array<Texture>> = new Map();
  public static final info:Map<String, PolyInfo> = new Map();
  // base offset per texture, keyed by uuid (so class edits stack on the original)
  static final baseOff:Map<String, { u:Float, v:Float }> = new Map();

  public static function tag(mat:Dynamic, cls:String, name:String, texPath:String, res:Int = 512):Dynamic {
    if (mat == null || mat.map == null) return mat;
    mat.userData.cls = cls;
    if (!tex.exists(cls)) tex.set(cls, []);
    tex.get(cls).push(mat.map);
    if (!info.exists(cls)) info.set(cls, { name: name, tex: texPath, res: res });
    baseOff.set(mat.map.uuid, { u: mat.map.offset.x, v: mat.map.offset.y });
    return mat;
  }

  public static function applyClassOffset(cls:String, u:Float, v:Float):Void {
    var arr = tex.get(cls);
    if (arr == null) return;
    for (t in arr) {
      var bo = baseOff.get(t.uuid);
      var bu = bo != null ? bo.u : 0.0;
      var bv = bo != null ? bo.v : 0.0;
      t.offset.set(bu + u, bv + v);
    }
  }
}
