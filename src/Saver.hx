// game save serialization and file storage

import haxe.Json;

import game.Game;
import mods.ModRegistry;

class Saver
{
  // v3: _AITraitType / _Skill / _Improv converted enum -> enum-abstract over
  // String, so those fields now serialize as bare strings instead of
  // {_classID,val,_isEnum} wrappers. Loader.initEnum migrates pre-v3 wrappers
  // (gated on formatVersion < 3). also carries the _activeMods array
  static var SAVE_FORMAT_VERSION = 3;

// save current game to a slot
  public static function save(game: Game, slotID: Int)
    {
      var o: _SaveGame = {
        game: null,
        version: SAVE_FORMAT_VERSION,
      };
      o.game = saveObject('game', game, 0);
      o.game.regionID = game.region.id;
      o.game.areaID = game.area.id;
      o._activeMods = [
        for (m in ModRegistry.enabled)
          { id: m.id, version: m.version }
      ];
#if electron
      HostBridge.saveWrite(slotID, Json.stringify(o, null, '  '));
#end
    }

// check if save file exists for slot
  public static function exists(slotID: Int): Bool
    {
#if electron
      return HostBridge.saveExists(slotID);
#end
      return false;
    }

// save object recursively into dynamic structure
  static function saveObject(name: String, o: Dynamic, depth: Int): Dynamic
    {
      if (depth > 20)
        throw 'Depth too high: ' + depth + ' ' + name;

      // handle scalar primitives
      if (Std.isOfType(o, Int) ||
          Std.isOfType(o, Float) ||
          Std.isOfType(o, Bool) ||
          Std.isOfType(o, String))
        return o;

      // handle plain arrays
      if (Std.isOfType(o, Array))
        {
          var val = [];
          var tmp: Array<Dynamic> = o;
          for (el in tmp)
            val.push(saveObject(name + '[]', el, depth + 1));
          return val;
        }

      // handle enum wrappers
      switch (Type.typeof(o)) {
        case TEnum(e):
          return {
            _classID: Type.getEnumName(e),
            _isEnum: true,
            val: '' + o,
          }
        default:
      }

      // prepare class metadata and ignored fields
      var ret: Dynamic = {};
      var cl = Type.getClass(o);
      var clname: String = null;
      if (cl != null)
        clname = untyped cl.__name__;
      ret._classID = clname;
      if (clname != null &&
          (StringTools.startsWith(clname, 'ai') ||
           StringTools.startsWith(clname, 'objects') ||
           StringTools.endsWith(clname, 'FSM')))
        {
          cl = Type.getSuperClass(cl);
          if (cl != null)
            {
              clname = untyped cl.__name__;
              if (clname != 'ai.AI' &&
                  clname != 'objects.AreaObject')
                cl = Type.getSuperClass(cl);
            }
        }
      var ignoredFields: Array<String> =
        Reflect.field(cl, '_ignoredFields');

      // allow objects to override selected fields before default mapping
      var customFields: Dynamic = null;
      var savePreHook = Reflect.field(o, 'savePreHook');
      if (savePreHook != null)
        {
          var custom = Reflect.callMethod(o, savePreHook,
            [SAVE_FORMAT_VERSION]);
          if (custom != null &&
              Type.typeof(custom) == TObject)
            customFields = custom;
        }

      // walk object fields
      for (f in Reflect.fields(o))
        {
          // mark circular references
          if (f == 'game')
            {
              ret._hasGame = true;
              continue;
            }
          if (f == 'ui')
            {
              ret._hasUI = true;
              continue;
            }
          var fobj: Dynamic = Reflect.field(o, f);
          if (ignoredFields != null && Lambda.has(ignoredFields, f))
            continue;

          // use hook-provided serialized override for this field
          if (customFields != null &&
              Reflect.hasField(customFields, f))
            {
              Reflect.setField(ret, f,
                Reflect.field(customFields, f));
              continue;
            }

          // map field into serializable value
          var fval: Dynamic = null;
          switch (Type.typeof(fobj)) {
            case TEnum(e):
              fval = {
                _classID: Type.getEnumName(e),
                _isEnum: true,
                val: '' + fobj,
              }
            case TObject:
              fval = saveObject(f, fobj, depth + 1);
            default:
          }
          if (fval != null)
            1;
          else if (Std.isOfType(fobj, Int) ||
              Std.isOfType(fobj, Float) ||
              Std.isOfType(fobj, Bool) ||
              Std.isOfType(fobj, String))
            fval = fobj;
          else if (Std.isOfType(fobj, Array))
            {
              fval = [];
              var tmp: Array<Dynamic> = fobj;
              for (el in tmp)
                fval.push(saveObject(f + '[]', el, depth + 1));
            }
          else if (Std.isOfType(fobj, List))
            {
              fval = [];
              var tmp: List<Dynamic> = fobj;
              for (el in tmp)
                fval.push(saveObject(f + '[]', el, depth + 1));
            }
          else if (Std.isOfType(fobj, haxe.ds.IntMap))
            {
              fval = {};
              var tmp: Map<Int, Dynamic> = fobj;
              for (key => el in tmp)
                Reflect.setField(fval, '' + key,
                  saveObject(f + '[]', el, depth + 1));
            }
          else if (Std.isOfType(fobj, haxe.ds.StringMap))
            {
              fval = {};
              var tmp: Map<String, Dynamic> = fobj;
              for (key => el in tmp)
                Reflect.setField(fval, key,
                  saveObject(f + '[]', el, depth + 1));
            }
          else if (Std.isOfType(fobj, _SaveObject))
            fval = saveObject(f, fobj, depth + 1);
          else continue;
          Reflect.setField(ret, f, fval);
        }

      return ret;
    }
}
