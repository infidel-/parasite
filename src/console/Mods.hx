// console mods command helper — list/enable/disable/errors for sideload + workshop mods
package console;

import game.Game;
import mods.ModRegistry;
import mods.ModInfo;
import HostBridge;

class Mods
{
  public var console: Console;
  var game: Game;

// sets up mods command helper
  public function new(c: Console)
    {
      console = c;
      game = console.game;
    }

// handles mods command routing: list (default) / enable / disable / errors
  public function run(arr: Array<String>): Bool
    {
      if (arr[0] != 'mods' && arr[0] != 'mo')
        return false;

      if (arr.length == 1)
        {
          printMods();
          return true;
        }
      var sub = arr[1];
      if (sub == 'list')
        printMods();
      else if (sub == 'errors' || sub == 'err')
        printModErrors();
      else if (sub == 'rescan')
        rescanMods();
      else if (sub == 'savedata' || sub == 'sd')
        printSaveData(arr.length >= 3 ? arr[2] : null);
      else if (sub == 'enable' || sub == 'disable')
        {
          if (arr.length < 3)
            {
              log('Usage: mods ' + sub + ' <id>');
              return true;
            }
          toggleMod(arr[2], sub == 'enable');
        }
      else
        log('Usage: mods [list|enable &lt;id&gt;|disable &lt;id&gt;|errors|rescan|savedata [&lt;id&gt;]]');
      return true;
    }

// dump per-mod savedata bucket(s) to the BROWSER devtools console as
// structured objects (interactive tree, expandable). game console gets a
// short text pointer so the player knows where the output went. no arg →
// summary (every bucket); arg → that mod's bucket only
  function printSaveData(modID: String)
    {
      if (game.modData == null
          || Reflect.fields(game.modData).length == 0)
        {
          log('No mod savedata.');
          return;
        }
      var bc = js.Browser.console;
      // summary mode
      if (modID == null)
        {
          var ids = Reflect.fields(game.modData);
          var summary: Dynamic = {};
          for (id in ids)
            {
              var bucket = Reflect.field(game.modData, id);
              var keyCount = Reflect.fields(bucket).length;
              try
                {
                  var size = haxe.Json.stringify(bucket).length;
                  Reflect.setField(summary, id, {
                    keys: keyCount,
                    bytes: size,
                    bucket: bucket,
                  });
                }
              catch (e: Dynamic)
                {
                  Reflect.setField(summary, id, {
                    keys: keyCount,
                    error: '' + e,
                    bucket: bucket,
                  });
                }
            }
          bc.log('[mods savedata] buckets:', summary);
          log('Mod savedata summary (' + ids.length +
            ' bucket(s)) printed to browser devtools console.');
          return;
        }
      // single-mod dump
      if (!Reflect.hasField(game.modData, modID))
        {
          log('No savedata for mod [' + modID + '].');
          return;
        }
      var bucket = Reflect.field(game.modData, modID);
      bc.log('[mods savedata] ' + modID + ':', bucket);
      try
        {
          var bytes = haxe.Json.stringify(bucket).length;
          log('Savedata for [' + modID + '] (' + bytes +
            ' bytes) printed to browser devtools console.');
        }
      catch (e: Dynamic)
        {
          log('Savedata for [' + modID +
            '] printed to browser devtools console — UNSERIALIZABLE: ' + e);
        }
    }

// re-scan dev/ + mods/ + workshop in main; diff vs current renderer registry
// (added/removed mods + per-mod asset file changes).
// reload (Ctrl-F5) still needed to actually load/unload mods or re-init asset
// caches (sound list, AssetPath overrides) — this just refreshes the main-process
// cache so the next renderer reload sees fresh state
  function rescanMods()
    {
      var oldByID = new Map<String, ModInfo>();
      for (info in ModRegistry.all)
        oldByID.set(info.id, info);
      var fresh: Array<ModInfo> = HostBridge.modsRescan();
      if (fresh == null)
        {
          log('Rescan failed (host bridge returned null).');
          return;
        }
      var newByID = new Map<String, ModInfo>();
      for (info in fresh)
        newByID.set(info.id, info);

      // build added / removed id lists
      var added = [];
      for (info in fresh)
        if (!oldByID.exists(info.id))
          added.push(info.id);
      var removed = [];
      for (id in oldByID.keys())
        if (!newByID.exists(id))
          removed.push(id);

      // per-mod asset diff for mods that exist on both sides
      var assetChanges: Array<String> = [];
      for (info in fresh)
        {
          var prev = oldByID.get(info.id);
          if (prev == null)
            continue;
          var oldSet = new Map<String, Bool>();
          if (prev.assets != null)
            for (a in prev.assets) oldSet.set(a, true);
          var newSet = new Map<String, Bool>();
          if (info.assets != null)
            for (a in info.assets) newSet.set(a, true);
          var addedAssets = [];
          if (info.assets != null)
            for (a in info.assets)
              if (!oldSet.exists(a)) addedAssets.push(a);
          var removedAssets = [];
          if (prev.assets != null)
            for (a in prev.assets)
              if (!newSet.exists(a)) removedAssets.push(a);
          if (addedAssets.length == 0 && removedAssets.length == 0)
            continue;
          var line = '    ' + info.id + ':';
          if (addedAssets.length > 0)
            line += ' +' + addedAssets.length + ' (' + addedAssets.join(', ') + ')';
          if (removedAssets.length > 0)
            line += ' -' + removedAssets.length + ' (' + removedAssets.join(', ') + ')';
          assetChanges.push(line);
        }

      var buf = new StringBuf();
      buf.add('Rescan: ' + fresh.length + ' mod(s) discovered.');
      if (added.length > 0)
        buf.add('<br/>  added: ' + added.join(', '));
      if (removed.length > 0)
        buf.add('<br/>  removed: ' + removed.join(', '));
      if (assetChanges.length > 0)
        {
          buf.add('<br/>  asset changes:');
          for (line in assetChanges)
            buf.add('<br/>' + line);
        }
      if (added.length == 0 &&
          removed.length == 0 &&
          assetChanges.length == 0)
        buf.add(' No changes.');
      else
        buf.add('<br/>Reload (Ctrl-F5) to apply.');
      log(buf.toString());
    }

// print mod status table (all discovered mods with enabled/disabled/failed)
  function printMods()
    {
      if (ModRegistry.all.length == 0)
        {
          log('No mods discovered.');
          return;
        }
      var disabled = new Map<String, Bool>();
      for (id in game.profile.object.disabledMods)
        disabled.set(id, true);
      var enabledSet = new Map<String, Bool>();
      for (info in ModRegistry.enabled)
        enabledSet.set(info.id, true);
      var buf = new StringBuf();
      buf.add('Mods (' + ModRegistry.all.length + '):<br/>');
      for (info in ModRegistry.all)
        {
          var status =
            if (ModRegistry.failed.exists(info.id)) 'failed';
            else if (disabled.exists(info.id)) 'disabled';
            else if (enabledSet.exists(info.id)) 'enabled';
            else 'inactive';
          buf.add('  ' + info.id + ' v' + info.version +
            ' [' + status + '] (' + info.source + ')<br/>');
        }
      log(buf.toString());
    }

// toggle mod in profile.disabledMods; takes effect on next renderer reload
  function toggleMod(id: String, enable: Bool)
    {
      if (ModRegistry.byID(id) == null)
        {
          log('Mod [' + id + '] not found.');
          return;
        }
      var list = game.profile.object.disabledMods;
      var idx = list.indexOf(id);
      if (enable)
        {
          if (idx < 0)
            {
              log('Mod [' + id + '] already enabled.');
              return;
            }
          list.splice(idx, 1);
        }
      else
        {
          if (idx >= 0)
            {
              log('Mod [' + id + '] already disabled.');
              return;
            }
          list.push(id);
        }
      game.profile.save();
      log('Mod [' + id + '] ' + (enable ? 'enabled' : 'disabled') +
        '. Reload (Ctrl-F5) to apply.');
    }

// print per-mod failure reasons recorded during scan/load/init
  function printModErrors()
    {
      if (Lambda.count(ModRegistry.failed) == 0)
        {
          log('No mod errors.');
          return;
        }
      var buf = new StringBuf();
      buf.add('Mod errors:<br/>');
      for (id in ModRegistry.failed.keys())
        buf.add('  ' + id + ': ' + ModRegistry.failed.get(id) + '<br/>');
      log(buf.toString());
    }

// log helper — delegates to owning console
  inline function log(s: String)
    {
      console.log(s);
    }
}
