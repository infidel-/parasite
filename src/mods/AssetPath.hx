// engine-wide asset path resolver
// engine code requests asset by canonical key ('img/foo.png', 'sound/bark.mp3');
// AssetPath returns mod:// URL if any mod overrides that key, else original path.
// last-registered mod wins (matches ModRegistry toposorted load order)
package mods;

class AssetPath
{
  // key (canonical engine path, e.g. 'img/foo.png') → owning modID
  static var overrides: Map<String, String> = new Map();
  // every key ever registered (incl. ones engine doesn't bundle); used by sound enumeration
  // value is modID for traceability — same as overrides map but never overwritten
  // (overrides is mutable per resolve precedence; registered tracks all-ever-seen)
  static var registered: Map<String, String> = new Map();

// register one mod asset rel path under its mod id.
// relPath is forward-slash, no leading slash, e.g. 'img/foo.png'.
// last registration of same key wins resolve() lookup
  public static function register(modID: String, relPath: String)
    {
      overrides.set(relPath, modID);
      registered.set(relPath, modID);
    }

// canonical lookup: returns mod:// URL if overridden, else original path unchanged.
// engine call sites pass their existing path string (e.g. 'img/cursor.png')
  public static function resolve(path: String): String
    {
      var modID = overrides.get(path);
      if (modID == null)
        return path;
      return 'mod://' + modID + '/assets/' + path;
    }

// list all registered keys with given extension (lowercase, incl. dot, e.g. '.mp3').
// used by Sounds.hx to enumerate mod-added audio files beyond engine bundle
  public static function listByExt(ext: String): Array<String>
    {
      var out: Array<String> = [];
      var lower = ext.toLowerCase();
      for (k in registered.keys())
        if (StringTools.endsWith(k.toLowerCase(), lower))
          out.push(k);
      return out;
    }

// dump override map for debug / boot log
  public static function all(): Map<String, String>
    {
      return overrides;
    }

// clear on full reload (engine restart path; never called at runtime today)
  public static function reset()
    {
      overrides = new Map();
      registered = new Map();
    }
}
