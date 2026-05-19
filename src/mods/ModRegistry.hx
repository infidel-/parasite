// renderer-side mod registry
package mods;

import game.Game;
import js.Browser.console;

class ModRegistry
{
  public static var all: Array<ModInfo> = [];
  public static var enabled: Array<ModInfo> = [];
  public static var failed: Map<String, String> = new Map();

// receive scanned mod list from main, validate compat + deps, toposort by load order
  public static function init(game: Game, raw: Array<ModInfo>)
    {
      all = [];
      enabled = [];
      failed = new Map();
      if (raw == null)
        {
          console.warn('[mods] host:mods:list returned null');
          return;
        }

      // log raw list from main
      console.log('[mods] registry init: ' + raw.length + ' mod(s) from main');
      for (info in raw)
        {
          all.push(info);
          console.log('[mods]   found: ' + info.id + ' v' + info.version +
            ' (api ' + info.modApiVersion + ', source ' + info.source + ')');
        }

      // build disabled-set from profile
      var disabled = new Map<String, Bool>();
      for (id in game.profile.object.disabledMods)
        disabled.set(id, true);

      // first pass: per-mod compatibility (modApiVersion + minGameVersion) + disabled
      var candidates: Array<ModInfo> = [];
      var engineVer = Version.getVersion();
      for (info in all)
        {
          // shadowed entries stay in `all` for UI visibility only; not loaded.
          // the shadowing mod (same id, different source) carries the load.
          if (info.shadowedBy != null)
            {
              console.log('[mods]   skip ' + info.id + ' (shadowed by ' + info.shadowedBy + ')');
              continue;
            }
          if (disabled.exists(info.id))
            {
              console.log('[mods]   skip ' + info.id + ' (disabled in profile)');
              continue;
            }
          if (info.modApiVersion != Const.MOD_API_VERSION)
            {
              reject(info, 'mod targets API v' + info.modApiVersion +
                ', engine is v' + Const.MOD_API_VERSION);
              continue;
            }
          if (info.minGameVersion != null &&
              versionCompare(engineVer, info.minGameVersion) < 0)
            {
              reject(info, 'requires engine >= ' + info.minGameVersion +
                ', current is ' + engineVer);
              continue;
            }
          candidates.push(info);
        }

      // second pass: dependency resolution (missing or version-mismatch = reject)
      var candByID = new Map<String, ModInfo>();
      for (c in candidates) candByID.set(c.id, c);
      var depFiltered: Array<ModInfo> = [];
      for (info in candidates)
        {
          var depOK = true;
          if (info.dependencies != null)
            {
              for (d in info.dependencies)
                {
                  if (!candByID.exists(d.id))
                    {
                      reject(info, 'missing dependency: ' + d.id + ' ' + d.version);
                      depOK = false;
                      break;
                    }
                  var have = candByID.get(d.id).version;
                  if (!versionSatisfies(have, d.version))
                    {
                      reject(info, 'dependency ' + d.id + ' v' + have +
                        ' does not satisfy ' + d.version);
                      depOK = false;
                      break;
                    }
                }
            }
          if (depOK) depFiltered.push(info);
        }

      // third pass: toposort by loadAfter/loadBefore (cycles rejected)
      enabled = toposort(depFiltered);

      console.log('[mods] registry: ' + all.length + ' found, ' +
        enabled.length + ' enabled, ' + Lambda.count(failed) + ' failed');
    }

// record per-mod failure reason; subsequent integrations skip this mod
  public static function markFailed(id: String, err: String)
    {
      failed.set(id, err);
    }

// engine bundled sound basenames (e.g. 'music1.mp3') ∪ mod-registered sound assets.
// Sounds.init enumerates this to discover all available sound keys at boot.
// mod assets stored under canonical key 'sound/<basename>.mp3'; we strip the prefix
  public static function mergedSoundList(): Array<String>
    {
      var out: Array<String> = [];
      var seen = new Map<String, Bool>();
#if electron
      var engineFiles = HostBridge.listSounds();
      if (engineFiles != null)
        for (f in engineFiles)
          {
            if (!seen.exists(f))
              {
                seen.set(f, true);
                out.push(f);
              }
          }
#end
      for (key in AssetPath.listByExt('.mp3'))
        {
          if (!StringTools.startsWith(key, 'sound/'))
            continue;
          var base = key.substr(6);
          if (!seen.exists(base))
            {
              seen.set(base, true);
              out.push(base);
            }
        }
      return out;
    }

// diff save-time mod snapshot vs currently-enabled set
  public static function diffSaveMods(
    saveMods: Array<{ id: String, version: String }>):
    Array<{ kind: String, id: String, saveVersion: String, activeVersion: String }>
    {
      var out = [];
      if (saveMods == null) saveMods = [];
      var saveByID = new Map<String, String>();
      for (m in saveMods) saveByID.set(m.id, m.version);
      var activeByID = new Map<String, String>();
      for (m in enabled) activeByID.set(m.id, m.version);

      for (m in saveMods)
        {
          if (!activeByID.exists(m.id))
            out.push({
              kind: 'missing',
              id: m.id,
              saveVersion: m.version,
              activeVersion: null
            });
          else if (activeByID.get(m.id) != m.version)
            out.push({
              kind: 'mismatch',
              id: m.id,
              saveVersion: m.version,
              activeVersion: activeByID.get(m.id)
            });
        }
      for (m in enabled)
        if (!saveByID.exists(m.id))
          out.push({
            kind: 'added',
            id: m.id,
            saveVersion: null,
            activeVersion: m.version
          });
      return out;
    }

// look up mod info by id; returns null if unknown
  public static function byID(id: String): ModInfo
    {
      for (info in all)
        if (info.id == id)
          return info;
      return null;
    }

// record rejection (compat / dep / cycle); logs to devtools + session log
  static function reject(info: ModInfo, reason: String)
    {
      failed.set(info.id, reason);
      console.warn('[mods]   reject ' + info.id + ': ' + reason);
#if electron
      try { HostBridge.logAppend('MOD REJECT [' + info.id + '] ' + reason + '\n'); }
      catch (e: Dynamic) {}
#end
    }

// parse "1.2.3" → [1,2,3]; non-numeric tail (e.g. "-beta") stops parsing
  static function parseVersion(s: String): Array<Int>
    {
      var out = [];
      if (s == null) return out;
      for (part in s.split('.'))
        {
          var n = Std.parseInt(part);
          if (n == null) break;
          out.push(n);
        }
      return out;
    }

// returns -1 if a<b, 0 if equal, 1 if a>b (semver-ish, missing parts = 0)
  static function versionCompare(a: String, b: String): Int
    {
      var pa = parseVersion(a);
      var pb = parseVersion(b);
      var n = pa.length > pb.length ? pa.length : pb.length;
      for (i in 0...n)
        {
          var ai = i < pa.length ? pa[i] : 0;
          var bi = i < pb.length ? pb[i] : 0;
          if (ai < bi) return -1;
          if (ai > bi) return 1;
        }
      return 0;
    }

// have-version satisfies want-spec; supports exact "1.2.0", ">=1.2.0", "*"
  static function versionSatisfies(have: String, want: String): Bool
    {
      if (want == null || want == '*') return true;
      if (StringTools.startsWith(want, '>='))
        return versionCompare(have, StringTools.trim(want.substr(2))) >= 0;
      return have == want;
    }

// Kahn's toposort by loadAfter/loadBefore; cycle members rejected + dropped
  static function toposort(items: Array<ModInfo>): Array<ModInfo>
    {
      var byID = new Map<String, ModInfo>();
      for (m in items) byID.set(m.id, m);

      // edges[a] = list of b such that a must come before b
      var edges = new Map<String, Array<String>>();
      var inDeg = new Map<String, Int>();
      for (m in items)
        {
          edges.set(m.id, []);
          inDeg.set(m.id, 0);
        }

      // build edges; ignore hints to ids not in candidate set
      for (m in items)
        {
          if (m.loadAfter != null)
            for (other in m.loadAfter)
              addEdge(edges, inDeg, byID, other, m.id);
          if (m.loadBefore != null)
            for (other in m.loadBefore)
              addEdge(edges, inDeg, byID, m.id, other);
        }

      // zero-in-deg queue, stable id sort for determinism
      var queue: Array<ModInfo> = [];
      for (m in items)
        if (inDeg.get(m.id) == 0) queue.push(m);
      queue.sort(function(a, b) return Reflect.compare(a.id, b.id));

      var out: Array<ModInfo> = [];
      while (queue.length > 0)
        {
          var m = queue.shift();
          out.push(m);
          var nextBatch: Array<ModInfo> = [];
          for (to in edges.get(m.id))
            {
              var d = inDeg.get(to) - 1;
              inDeg.set(to, d);
              if (d == 0) nextBatch.push(byID.get(to));
            }
          nextBatch.sort(function(a, b) return Reflect.compare(a.id, b.id));
          for (n in nextBatch) queue.push(n);
        }

      // any node with in-deg > 0 = cycle member
      if (out.length < items.length)
        for (m in items)
          if (inDeg.get(m.id) > 0)
            reject(m, 'load order cycle (loadAfter/loadBefore)');
      return out;
    }

// add directed edge from→to if both ids present and not self-loop
  static function addEdge(edges: Map<String, Array<String>>,
    inDeg: Map<String, Int>, byID: Map<String, ModInfo>,
    from: String, to: String)
    {
      if (!byID.exists(from) || !byID.exists(to)) return;
      if (from == to) return;
      edges.get(from).push(to);
      inDeg.set(to, inDeg.get(to) + 1);
    }
}
